extends Node
## Autoload "GameState" - the CompanyManager: owns all persistent company state, serialization,
## progressive-disclosure ("reveal") rules, and save/load. UI never owns authoritative state.

signal state_changed
signal game_event(event_name: String, payload: Dictionary)
signal log_posted(text: String, severity: int)

const HALL_ID := "__hall"
const SAVE_PATH := "user://campaign_save.json"
const SAVE_VERSION := 1

var employees: Dictionary = {}   # id -> EmployeeState
var rooms: Dictionary = {}       # id -> RoomState
var departments: Dictionary = {} # id -> DepartmentState
var current_department_id := "ies"
var player: Dictionary = {}
var resources: Dictionary = {}
var policies: Array = []
var narrative_flags: Dictionary = {}
var records: Array = []          # discovered company records [{"id","title","body","day"}]
var incident_history: Array = []
var company_history: Array = []
var tutorial_enabled := true
var campaign_active := false
var rng_seed := 0


# ---------------------------------------------------------------- campaign lifecycle

func start_new_campaign(with_tutorial: bool) -> void:
	_clear()
	tutorial_enabled = with_tutorial
	rng_seed = int(Time.get_unix_time_from_system()) % 1000000
	player = {"name": "New Hire", "authority": 0, "clearance": 0, "reputation": 0,
		"institutional_knowledge": 0, "certifications": []}
	resources = {"budget": 500.0, "supplies": 100.0, "personnel_capacity": 12.0}
	IESContent.populate(self, rng_seed)
	campaign_active = true
	state_changed.emit()


func _clear() -> void:
	employees.clear()
	rooms.clear()
	departments.clear()
	policies.clear()
	narrative_flags.clear()
	records.clear()
	incident_history.clear()
	company_history.clear()
	campaign_active = false


# ---------------------------------------------------------------- accessors

func dept() -> DepartmentState:
	return departments.get(current_department_id) as DepartmentState


func current_day() -> int:
	var d := dept()
	return d.current_day if d != null else 1


func get_room(id: String) -> RoomState:
	return rooms.get(id) as RoomState


func get_employee(id: String) -> EmployeeState:
	return employees.get(id) as EmployeeState


func room_name(id: String) -> String:
	if id == HALL_ID or id == "":
		return "Hall"
	var r := get_room(id)
	return r.display_name if r != null else "Unknown"


## Employees physically present (by resolved location). HALL_ID returns the unplaced.
func employees_in_room(room_id: String) -> Array:
	var out: Array = []
	var want := "" if room_id == HALL_ID else room_id
	for id in employees.keys():
		var e: EmployeeState = employees[id]
		if e.location_room == want and e.discovered:
			out.append(e)
	out.sort_custom(func(a: EmployeeState, b: EmployeeState) -> bool: return a.id < b.id)
	return out


func assigned_count(room_id: String, excluding: String = "") -> int:
	var n := 0
	for id in employees.keys():
		var e: EmployeeState = employees[id]
		if e.assignment_room == room_id and e.id != excluding:
			n += 1
	return n


func staff_sorted() -> Array:
	var out: Array = []
	for id in employees.keys():
		var e: EmployeeState = employees[id]
		if e.discovered:
			out.append(e)
	out.sort_custom(func(a: EmployeeState, b: EmployeeState) -> bool:
		if a.is_named != b.is_named:
			return a.is_named
		return a.display_name < b.display_name)
	return out


# ---------------------------------------------------------------- progressive disclosure

func is_revealed(key: String) -> bool:
	if bool(SettingsStore.get_value("reveal_all")):
		return true
	var d := dept()
	if d != null and d.completed:
		return true
	return current_day() >= int(IESContent.REVEAL_DAY.get(key, 1))


func has_hidden_info() -> bool:
	if bool(SettingsStore.get_value("reveal_all")):
		return false
	var d := dept()
	if d != null and d.completed:
		return false
	for k in IESContent.REVEAL_DAY.keys():
		if int(IESContent.REVEAL_DAY[k]) > current_day():
			return true
	return false


# ---------------------------------------------------------------- management actions

func assign_employee(emp_id: String, room_id: String) -> bool:
	var e := get_employee(emp_id)
	if e == null:
		return false
	if not e.player_assignable:
		post_log("%s keeps their own schedule." % e.display_name, 1)
		return false
	if room_id != "":
		var r := get_room(room_id)
		if r == null or not r.unlocked:
			return false
		if assigned_count(room_id, emp_id) >= r.capacity:
			post_log("%s is at capacity." % r.display_name, 1)
			return false
	e.assignment_room = room_id
	SimulationKernel.update_locations(employees, rooms, Workday.minute)
	game_event.emit("employee_assigned", {"employee_id": emp_id, "room_id": room_id})
	state_changed.emit()
	return true


func set_break(emp_id: String, minute_of_day: int) -> void:
	var e := get_employee(emp_id)
	if e == null or not e.player_assignable:
		return
	e.break_at = minute_of_day
	game_event.emit("break_set", {"employee_id": emp_id})
	state_changed.emit()


func post_log(text: String, severity: int = 0) -> void:
	log_posted.emit(text, severity)


func add_record(id: String, title: String, body: String) -> void:
	for r in records:
		if r is Dictionary and r.get("id") == id:
			return
	records.append({"id": id, "title": title, "body": body, "day": current_day()})


# ---------------------------------------------------------------- serialization

func serialize() -> Dictionary:
	var emp: Dictionary = {}
	for id in employees.keys():
		emp[id] = (employees[id] as EmployeeState).to_dict()
	var rms: Dictionary = {}
	for id in rooms.keys():
		rms[id] = (rooms[id] as RoomState).to_dict()
	var deps: Dictionary = {}
	for id in departments.keys():
		deps[id] = (departments[id] as DepartmentState).to_dict()
	return {
		"version": SAVE_VERSION, "current_department_id": current_department_id,
		"player": player.duplicate(true), "resources": resources.duplicate(true),
		"policies": policies.duplicate(true), "narrative_flags": narrative_flags.duplicate(true),
		"records": records.duplicate(true), "incident_history": incident_history.duplicate(true),
		"company_history": company_history.duplicate(true), "tutorial_enabled": tutorial_enabled,
		"rng_seed": rng_seed, "employees": emp, "rooms": rms, "departments": deps,
	}


## Returns false (and leaves current state untouched) if the data is unusable.
func deserialize(d: Dictionary) -> bool:
	if int(d.get("version", -1)) != SAVE_VERSION:
		return false
	if not (d.get("employees") is Dictionary and d.get("rooms") is Dictionary and d.get("departments") is Dictionary):
		return false
	var new_emp: Dictionary = {}
	for id in d["employees"].keys():
		if d["employees"][id] is Dictionary:
			var e := EmployeeState.from_dict(d["employees"][id])
			if e.id != "":
				new_emp[e.id] = e
	var new_rooms: Dictionary = {}
	for id in d["rooms"].keys():
		if d["rooms"][id] is Dictionary:
			var r := RoomState.from_dict(d["rooms"][id])
			if r.id != "":
				new_rooms[r.id] = r
	var new_deps: Dictionary = {}
	for id in d["departments"].keys():
		if d["departments"][id] is Dictionary:
			var ds := DepartmentState.from_dict(d["departments"][id])
			if ds.id != "":
				new_deps[ds.id] = ds
	var dept_id := str(d.get("current_department_id", "ies"))
	if new_emp.is_empty() or new_rooms.is_empty() or not new_deps.has(dept_id):
		return false
	employees = new_emp
	rooms = new_rooms
	departments = new_deps
	current_department_id = dept_id
	player = d.get("player", {}).duplicate(true) if d.get("player") is Dictionary else {}
	resources = d.get("resources", {}).duplicate(true) if d.get("resources") is Dictionary else {}
	policies = d.get("policies", []).duplicate(true) if d.get("policies") is Array else []
	narrative_flags = d.get("narrative_flags", {}).duplicate(true) if d.get("narrative_flags") is Dictionary else {}
	records = d.get("records", []).duplicate(true) if d.get("records") is Array else []
	incident_history = d.get("incident_history", []).duplicate(true) if d.get("incident_history") is Array else []
	company_history = d.get("company_history", []).duplicate(true) if d.get("company_history") is Array else []
	tutorial_enabled = bool(d.get("tutorial_enabled", true))
	rng_seed = int(d.get("rng_seed", 0))
	for k in ["authority", "clearance", "reputation", "institutional_knowledge", "experience_days"]:
		if player.has(k):
			player[k] = int(player[k])
	campaign_active = true
	state_changed.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func peek_save() -> Dictionary:
	var data := _read_save_file()
	if data.is_empty() or not (data.get("departments") is Dictionary):
		return {}
	var dep: Variant = data["departments"].get(str(data.get("current_department_id", "ies")))
	if dep is Dictionary:
		return {"day": int(dep.get("current_day", 1)), "department": str(dep.get("display_name", ""))}
	return {}


func save_to_disk() -> bool:
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: cannot open save file (error %d)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(serialize(), "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, SAVE_PATH)
	if err != OK:
		push_warning("GameState: could not finalize save (error %d)" % err)
		return false
	return true


func load_from_disk() -> bool:
	var data := _read_save_file()
	if data.is_empty():
		return false
	return deserialize(data)


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
