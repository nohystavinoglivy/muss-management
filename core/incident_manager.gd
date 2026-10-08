extends Node
## Autoload "Incidents" - generic stateful incident framework. Incidents are only surfaced to the
## player once the "incidents_panel" reveal is active; before that, kernel events become log lines.

signal incident_added(inc: Dictionary)
signal incident_resolved(inc: Dictionary, outcome: String)
signal incidents_changed

var active: Array = []   # Array[Dictionary]
var _uid := 0
var _scripted: Array = []


func prepare_day(day: int) -> void:
	active.clear()
	_scripted = IESContent.scripted_incidents(day).duplicate(true)
	incidents_changed.emit()


func enabled() -> bool:
	return GameState.is_revealed("incidents_panel")


func has_incident_in_room(room_id: String) -> bool:
	for inc in active:
		if str(inc.get("room_id", "")) == room_id:
			return true
	return false


func tick(minute: int) -> void:
	for s in _scripted.duplicate():
		if minute >= int(s.get("minute", 0)):
			_scripted.erase(s)
			spawn(str(s.get("id", "")), s)
	for inc in active.duplicate():
		if minute >= int(inc["deadline"]):
			_expire(inc)


func handle_kernel_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"warning":
			GameState.post_log(str(ev.get("text", "")), 1)
		"incident":
			if enabled():
				spawn(str(ev.get("id", "")), ev)
			else:
				var e := GameState.get_employee(str(ev.get("employee_id", "")))
				var who := e.display_name if e != null else "Someone"
				GameState.post_log("%s is struggling. (Incident handling is not yet part of your duties.)" % who, 1)


func spawn(def_id: String, params: Dictionary = {}) -> Dictionary:
	var def: Dictionary = IncidentLibrary.DEFS.get(def_id, {})
	if def.is_empty():
		push_warning("Incidents.spawn: unknown incident '%s'" % def_id)
		return {}
	_uid += 1
	var emp_id := str(params.get("employee_id", ""))
	if emp_id == "":
		emp_id = _pick_employee(str(def.get("pick", "none")))
	var emp := GameState.get_employee(emp_id)
	var other_id := str(params.get("other_id", ""))
	var room_id := str(params.get("room_id", ""))
	if room_id == "":
		room_id = str(def.get("room", ""))
	if room_id == "" and emp != null:
		room_id = emp.location_room
	var other := GameState.get_employee(other_id)
	var text := str(def.get("text", ""))
	text = text.replace("{emp}", emp.display_name if emp != null else "An employee")
	text = text.replace("{other}", other.display_name if other != null else "a coworker")
	text = text.replace("{room}", GameState.room_name(room_id).to_lower())
	var inc := {
		"uid": _uid, "def_id": def_id, "title": str(def.get("title", def_id)), "severity": int(def.get("severity", 0)),
		"text": text, "room_id": room_id, "emp_id": emp_id, "other_id": other_id,
		"deadline": Workday.minute + int(def.get("duration", 120)), "pause": bool(def.get("pause", false)),
		"responses": (def.get("responses", []) as Array).duplicate(true),
		"ignore": (def.get("ignore", []) as Array).duplicate(true),
	}
	active.append(inc)
	GameState.post_log("INCIDENT: %s" % inc["title"], 2)
	incident_added.emit(inc)
	incidents_changed.emit()
	if inc["pause"]:
		Workday.enter_incident_response()
	GameState.game_event.emit("incident_spawned", {"uid": _uid})
	return inc


func find(uid: int) -> Dictionary:
	for inc in active:
		if int(inc["uid"]) == uid:
			return inc
	return {}


func resolve(uid: int, response_index: int) -> void:
	var inc := find(uid)
	if inc.is_empty():
		return
	var responses: Array = inc["responses"]
	if response_index < 0 or response_index >= responses.size():
		return
	var resp: Dictionary = responses[response_index]
	_apply_effects(resp.get("effects", []), inc)
	Workday.day_stats["incidents_resolved"] = int(Workday.day_stats.get("incidents_resolved", 0)) + 1
	GameState.incident_history.append({"day": GameState.current_day(), "title": inc["title"], "outcome": str(resp.get("label", ""))})
	GameState.post_log("Resolved: %s - %s" % [inc["title"], resp.get("label", "")], 0)
	active.erase(inc)
	incident_resolved.emit(inc, str(resp.get("label", "")))
	incidents_changed.emit()
	GameState.game_event.emit("incident_resolved", {"uid": uid})
	_release_if_clear()
	GameState.state_changed.emit()


## Player closed the popup without choosing: the incident stays, but stops pausing the sim.
func release_pause(uid: int) -> void:
	var inc := find(uid)
	if not inc.is_empty():
		inc["pause"] = false
	_release_if_clear()


func expire_all() -> void:
	for inc in active.duplicate():
		_expire(inc)


func _expire(inc: Dictionary) -> void:
	_apply_effects(inc.get("ignore", []), inc)
	Workday.day_stats["incidents_ignored"] = int(Workday.day_stats.get("incidents_ignored", 0)) + 1
	GameState.incident_history.append({"day": GameState.current_day(), "title": inc["title"], "outcome": "ignored"})
	GameState.post_log("Unanswered: %s" % inc["title"], 2)
	active.erase(inc)
	incident_resolved.emit(inc, "ignored")
	incidents_changed.emit()
	_release_if_clear()


func _release_if_clear() -> void:
	for inc in active:
		if bool(inc["pause"]):
			return
	Workday.exit_incident_response()


func _pick_employee(mode: String) -> String:
	var candidates: Array = []
	for e in GameState.staff_sorted():
		if e.player_assignable and e.location_room != SimulationKernel.OFFSITE:
			candidates.append(e)
	if candidates.is_empty() or mode == "none":
		return ""
	if mode == "highest_stress":
		candidates.sort_custom(func(a: EmployeeState, b: EmployeeState) -> bool: return a.need("stress") > b.need("stress"))
		return (candidates[0] as EmployeeState).id
	var working: Array = candidates.filter(func(e: EmployeeState) -> bool: return e.location_room != "")
	var pool: Array = working if not working.is_empty() else candidates
	return (pool[(_uid * 7) % pool.size()] as EmployeeState).id


func _targets(who: String, inc: Dictionary) -> Array:
	var out: Array = []
	var emp := GameState.get_employee(str(inc.get("emp_id", "")))
	var other := GameState.get_employee(str(inc.get("other_id", "")))
	match who:
		"emp":
			if emp != null:
				out.append(emp)
		"other":
			if other != null:
				out.append(other)
		"both":
			if emp != null:
				out.append(emp)
			if other != null:
				out.append(other)
		"room_occupants":
			out = GameState.employees_in_room(str(inc.get("room_id", "")))
		"all_staff":
			out = GameState.staff_sorted()
	return out


func _apply_effects(effects: Array, inc: Dictionary) -> void:
	var day := GameState.current_day()
	var room := GameState.get_room(str(inc.get("room_id", "")))
	for fx in effects:
		if not (fx is Dictionary):
			continue
		match str(fx.get("t", "")):
			"need":
				for e in _targets(str(fx.get("who", "emp")), inc):
					(e as EmployeeState).add_need(str(fx.get("key", "")), float(fx.get("delta", 0.0)))
			"room":
				if room != null:
					room.add_cond(str(fx.get("key", "")), float(fx.get("delta", 0.0)))
			"resource":
				var k := str(fx.get("key", ""))
				GameState.resources[k] = maxf(0.0, float(GameState.resources.get(k, 0.0)) + float(fx.get("delta", 0.0)))
			"rel":
				var a := GameState.get_employee(str(inc.get("emp_id", "")))
				var b := GameState.get_employee(str(inc.get("other_id", "")))
				if a != null and b != null:
					a.shift_rel(b.id, float(fx.get("dp", 0.0)), float(fx.get("dpro", 0.0)))
					b.shift_rel(a.id, float(fx.get("dp", 0.0)), float(fx.get("dpro", 0.0)))
			"flag":
				GameState.narrative_flags[str(fx.get("key", ""))] = fx.get("value", true)
			"memory":
				for e in _targets(str(fx.get("who", "emp")), inc):
					(e as EmployeeState).add_memory(day, str(fx.get("text", "")))
			"loan":
				var target := GameState.get_employee(str(inc.get("emp_id", "")))
				if target != null:
					target.away_until = Workday.minute + int(fx.get("minutes", 60))
				if str(fx.get("who", "")) == "" and GameState.get_employee(str(inc.get("other_id", ""))) != null and inc.get("def_id") == "conflict_flare":
					GameState.get_employee(str(inc["other_id"])).away_until = Workday.minute + int(fx.get("minutes", 60))
				SimulationKernel.update_locations(GameState.employees, GameState.rooms, Workday.minute)
			"knowledge":
				GameState.player["institutional_knowledge"] = int(GameState.player.get("institutional_knowledge", 0)) + int(fx.get("delta", 0))
