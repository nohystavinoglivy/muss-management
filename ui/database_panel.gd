class_name DatabasePanel
extends PanelContainer
## The "database-style" side of the UI. Shows either a room or an employee. Sections appear only
## when GameState.is_revealed(key) says the player has learned to read them (progressive disclosure).
## Widgets are built once per selection and refreshed in place via _updaters (no rebuild per tick).

signal employee_requested(emp_id: String)

const TRAIT_HIGH := {
	"conscientiousness": "Meticulous", "sociability": "Sociable", "patience": "Patient", "empathy": "Empathic",
	"ambition": "Ambitious", "anxiety": "Anxious", "stubbornness": "Stubborn", "adaptability": "Adaptable",
	"loyalty": "Loyal", "work_ethic": "Hard-working", "sensitivity": "Sensitive",
}
const TRAIT_LOW := {
	"conscientiousness": "Careless", "sociability": "Reserved", "patience": "Short-tempered", "empathy": "Detached",
	"ambition": "Unambitious", "anxiety": "Calm", "stubbornness": "Flexible", "adaptability": "Set in their ways",
	"loyalty": "Uncommitted", "work_ethic": "Unmotivated", "sensitivity": "Thick-skinned",
}
const FUNCTION_LABEL := {
	"office": "Administrative", "break": "Short recovery", "lounge": "Long recovery / social",
	"interview": "Private conversation", "mediation": "Formal conflict resolution", "locked": "Restricted",
}
const WORK_FUNCTIONS := ["office", "interview", "mediation"]
const BREAK_OPTIONS := [-1, 600, 660, 720, 780, 840, 900]

var read_only := false

var _mode := ""
var _room_id := ""
var _emp_id := ""
var _title: Label
var _subtitle: Label
var _tab_room: Button
var _tab_emp: Button
var _content: VBoxContainer
var _updaters: Array[Callable] = []
var _occ_box: VBoxContainer
var _occ_sig := ""
var _assign_opt: OptionButton
var _break_opt: OptionButton
var _rel_box: VBoxContainer
var _rel_sig := ""
var _mem_box: VBoxContainer
var _mem_sig := ""


func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	if not read_only:
		var tabs := HBoxContainer.new()
		_tab_room = Button.new()
		_tab_room.text = "ROOM"
		_tab_room.toggle_mode = true
		_tab_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_room.pressed.connect(func() -> void:
			if _room_id != "":
				show_room(_room_id))
		_tab_emp = Button.new()
		_tab_emp.text = "EMPLOYEE"
		_tab_emp.toggle_mode = true
		_tab_emp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_emp.pressed.connect(func() -> void:
			if _emp_id != "":
				show_employee(_emp_id))
		tabs.add_child(_tab_room)
		tabs.add_child(_tab_emp)
		v.add_child(tabs)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Palette.SKY)
	v.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_color_override("font_color", Palette.TEXT_DIM)
	v.add_child(_subtitle)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)
	GameState.state_changed.connect(refresh)
	_rebuild()


func show_room(id: String) -> void:
	_mode = "room"
	_room_id = id
	_rebuild()


func show_employee(id: String) -> void:
	_mode = "employee"
	_emp_id = id
	_rebuild()


func clear_selection() -> void:
	_mode = ""
	_rebuild()


func current_employee_id() -> String:
	return _emp_id


# ---------------------------------------------------------------- build helpers

func _rebuild() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		c.queue_free()
	_updaters.clear()
	_occ_box = null
	_assign_opt = null
	_break_opt = null
	_rel_box = null
	_mem_box = null
	_occ_sig = ""
	_rel_sig = ""
	_mem_sig = ""
	if _tab_room != null:
		_tab_room.set_pressed_no_signal(_mode == "room")
		_tab_room.disabled = _room_id == ""
		_tab_emp.set_pressed_no_signal(_mode == "employee")
		_tab_emp.disabled = _emp_id == ""
	match _mode:
		"room":
			_build_room()
		"employee":
			_build_employee()
		_:
			_title.text = "DATABASE"
			_subtitle.text = ""
			_add_label("Select a room or a person.", true)
	if not read_only and GameState.has_hidden_info():
		_content.add_child(HSeparator.new())
		_add_label("// More records will become available as you progress.", true)
	refresh()


func refresh() -> void:
	for u in _updaters:
		u.call()


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Palette.MOSS.lightened(0.3))
	_content.add_child(l)


func _add_label(text: String, dim: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dim:
		l.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_content.add_child(l)
	return l


func _kv(key: String, getter: Callable) -> void:
	var h := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(104, 0)
	k.add_theme_color_override("font_color", Palette.TEXT_DIM)
	var val := Label.new()
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(k)
	h.add_child(val)
	_content.add_child(h)
	_updaters.append(func() -> void: val.text = str(getter.call()))


func _bar(label: String, bad_high: bool, getter: Callable, neutral: bool = false) -> void:
	var b := StatBar.new(label, bad_high)
	b.neutral = neutral
	_content.add_child(b)
	_updaters.append(func() -> void: b.set_value(float(getter.call())))


func _emp() -> EmployeeState:
	return GameState.get_employee(_emp_id)


func _emp_need(key: String) -> float:
	var e := _emp()
	return e.need(key) if e != null else 0.0


# ---------------------------------------------------------------- room view

func _build_room() -> void:
	var is_hall := _room_id == GameState.HALL_ID
	var room := GameState.get_room(_room_id)
	if not is_hall and room == null:
		_title.text = "UNKNOWN"
		return
	_title.text = "Hall" if is_hall else room.display_name
	_subtitle.text = "Unassigned staff wait here" if is_hall else str(FUNCTION_LABEL.get(room.function, room.function))
	_add_label("Staff with no assignment idle in the hall. They are not working and they are not recovering." if is_hall else room.description, true)
	_section("Occupancy")
	if is_hall:
		_kv("Present", func() -> String: return str(GameState.employees_in_room(_room_id).size()))
	else:
		_kv("Present", func() -> String: return "%d / %d" % [GameState.employees_in_room(_room_id).size(), room.capacity])
	_occ_box = VBoxContainer.new()
	_content.add_child(_occ_box)
	_updaters.append(_sync_occupants)
	if not is_hall:
		if GameState.is_revealed("preferred_roles") and not room.preferred_roles.is_empty():
			_section("Best suited")
			_add_label(", ".join(PackedStringArray(room.preferred_roles)))
		if GameState.is_revealed("room_output") and WORK_FUNCTIONS.has(room.function):
			_kv("Output today", func() -> String:
				var r := GameState.get_room(_room_id)
				return "%.1f tasks" % (r.output_today if r != null else 0.0))
		if GameState.is_revealed("room_condition"):
			_section("Condition")
			for key in ["comfort", "safety", "cleanliness", "efficiency", "equipment"]:
				_bar(key.capitalize(), false, func() -> float:
					var r := GameState.get_room(_room_id)
					return r.cond(key) if r != null else 0.0)
	if not read_only and _emp_id != "" and GameState.get_employee(_emp_id) != null:
		_content.add_child(HSeparator.new())
		var btn := Button.new()
		_content.add_child(btn)
		btn.pressed.connect(func() -> void:
			GameState.assign_employee(_emp_id, "" if is_hall else _room_id))
		_updaters.append(func() -> void:
			var e := _emp()
			if e == null:
				btn.visible = false
				return
			btn.visible = true
			if is_hall:
				btn.text = "Unassign %s" % e.display_name
				btn.disabled = not e.player_assignable or e.assignment_room == ""
			else:
				var full: bool = GameState.assigned_count(_room_id, e.id) >= room.capacity
				btn.text = "Assign %s here" % e.display_name
				btn.disabled = not e.player_assignable or e.assignment_room == _room_id or full or not room.unlocked)


func _sync_occupants() -> void:
	if _occ_box == null:
		return
	var people: Array = GameState.employees_in_room(_room_id)
	var ids: Array = []
	for e in people:
		ids.append((e as EmployeeState).id)
	var sig := ",".join(PackedStringArray(ids))
	if sig == _occ_sig:
		return
	_occ_sig = sig
	for c in _occ_box.get_children():
		c.queue_free()
	if people.is_empty():
		var l := Label.new()
		l.text = "Nobody is here."
		l.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_occ_box.add_child(l)
		return
	for e in people:
		var emp: EmployeeState = e
		var b := Button.new()
		b.text = "%s  -  %s" % [emp.display_name, emp.role] if GameState.is_revealed("role") else emp.display_name
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: employee_requested.emit(emp.id))
		_occ_box.add_child(b)


# ---------------------------------------------------------------- employee view

func _build_employee() -> void:
	var e := _emp()
	if e == null:
		_title.text = "UNKNOWN"
		_add_label("No record found.", true)
		return
	_title.text = e.display_name
	_subtitle.text = (e.role if GameState.is_revealed("role") else "Employee") + ("   [KEY PERSONNEL]" if e.is_named else "")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var portrait := PortraitBox.new(Vector2(96, 96))
	portrait.setup(e.sprite_key, e.tint(), e.display_name)
	top.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loc := Label.new()
	loc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(loc)
	top.add_child(info)
	_content.add_child(top)
	_updaters.append(func() -> void:
		var emp := _emp()
		if emp == null:
			return
		if emp.location_room == SimulationKernel.OFFSITE:
			loc.text = "Currently: off-site"
		elif emp.location_room == "":
			loc.text = "Currently: in the hall"
		else:
			loc.text = "Currently: %s" % GameState.room_name(emp.location_room))
	if e.bio != "":
		_add_label(e.bio, true)

	if GameState.is_revealed("assignment"):
		_section("Assignment")
		if read_only or not e.player_assignable:
			_kv("Posted to", func() -> String:
				var emp := _emp()
				return GameState.room_name(emp.assignment_room) if emp != null and emp.assignment_room != "" else "Unassigned")
			if not e.player_assignable and not read_only:
				_add_label("Keeps their own schedule.", true)
		else:
			_build_assign_option()

	_section("Condition")
	if GameState.is_revealed("morale"):
		_bar("Morale", false, func() -> float: return _emp_need("morale"))
	if GameState.is_revealed("fatigue"):
		_bar("Fatigue", true, func() -> float: return _emp_need("fatigue"))
	if GameState.is_revealed("stress"):
		_bar("Stress", true, func() -> float: return _emp_need("stress"))
	if GameState.is_revealed("satisfaction"):
		_bar("Satisfaction", false, func() -> float: return _emp_need("satisfaction"))
	if GameState.is_revealed("engagement"):
		_bar("Engagement", false, func() -> float: return _emp_need("engagement"))
	if GameState.is_revealed("stability"):
		_bar("Stability", false, func() -> float: return _emp_need("stability"))

	if GameState.is_revealed("break_schedule"):
		_section("Schedule")
		if read_only or not e.player_assignable:
			_kv("Break", func() -> String:
				var emp := _emp()
				return "None" if emp == null or emp.break_at < 0 else Workday.format_clock(emp.break_at))
		else:
			_build_break_option()

	if GameState.is_revealed("personality_summary"):
		_section("Personality")
		_add_label(_personality_summary(e))
		if GameState.is_revealed("personality_full"):
			for key in EmployeeState.TRAIT_KEYS:
				_bar(key.replace("_", " ").capitalize(), true, func() -> float:
					var emp := _emp()
					return float(emp.traits.get(key, 50.0)) if emp != null else 0.0, true)

	if GameState.is_revealed("relationships"):
		_section("Relationships")
		_rel_box = VBoxContainer.new()
		_content.add_child(_rel_box)
		_updaters.append(_sync_relationships)

	if GameState.is_revealed("memories"):
		_section("Recent memories")
		_mem_box = VBoxContainer.new()
		_content.add_child(_mem_box)
		_updaters.append(_sync_memories)


func _personality_summary(e: EmployeeState) -> String:
	var scored: Array = []
	for key in EmployeeState.TRAIT_KEYS:
		var v := float(e.traits.get(key, 50.0))
		scored.append({"key": key, "v": v, "d": absf(v - 50.0)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] > b["d"])
	var words: Array = []
	for item in scored:
		if words.size() >= 3 or float(item["d"]) < 15.0:
			break
		words.append(TRAIT_HIGH[item["key"]] if float(item["v"]) > 50.0 else TRAIT_LOW[item["key"]])
	return "Tends to be: %s." % ", ".join(PackedStringArray(words)) if not words.is_empty() else "Unremarkable temperament."


func _build_assign_option() -> void:
	_assign_opt = OptionButton.new()
	_assign_opt.add_item("Unassigned")
	_assign_opt.set_item_metadata(0, "")
	var ids: Array = GameState.rooms.keys()
	ids.sort()
	for id in ids:
		var r: RoomState = GameState.rooms[id]
		if r.unlocked:
			_assign_opt.add_item(r.display_name)
			_assign_opt.set_item_metadata(_assign_opt.item_count - 1, r.id)
	_assign_opt.item_selected.connect(func(idx: int) -> void:
		var rid := str(_assign_opt.get_item_metadata(idx))
		if not GameState.assign_employee(_emp_id, rid):
			_sync_assign())
	_content.add_child(_assign_opt)
	_updaters.append(_sync_assign)


func _sync_assign() -> void:
	var e := _emp()
	if _assign_opt == null or e == null:
		return
	for i in _assign_opt.item_count:
		var rid := str(_assign_opt.get_item_metadata(i))
		if rid == "":
			_assign_opt.set_item_text(i, "Unassigned")
		else:
			var r := GameState.get_room(rid)
			if r != null:
				_assign_opt.set_item_text(i, "%s  (%d/%d)" % [r.display_name, GameState.assigned_count(rid), r.capacity])
		if rid == e.assignment_room and not _assign_opt.get_popup().visible:
			_assign_opt.select(i)


func _build_break_option() -> void:
	_break_opt = OptionButton.new()
	for m in BREAK_OPTIONS:
		_break_opt.add_item("No break" if int(m) < 0 else "Break at %s" % Workday.format_clock(int(m)))
		_break_opt.set_item_metadata(_break_opt.item_count - 1, int(m))
	_break_opt.item_selected.connect(func(idx: int) -> void:
		GameState.set_break(_emp_id, int(_break_opt.get_item_metadata(idx))))
	_content.add_child(_break_opt)
	_updaters.append(func() -> void:
		var e := _emp()
		if _break_opt == null or e == null or _break_opt.get_popup().visible:
			return
		for i in _break_opt.item_count:
			if int(_break_opt.get_item_metadata(i)) == e.break_at:
				_break_opt.select(i))


func _sync_relationships() -> void:
	var e := _emp()
	if _rel_box == null or e == null:
		return
	var rows: Array = []
	for other_id in e.relationships.keys():
		var other := GameState.get_employee(str(other_id))
		if other == null:
			continue
		var r: Dictionary = e.relationships[other_id]
		var p := float(r.get("personal", 0.0))
		var q := float(r.get("professional", 0.0))
		if absf(p) < 8.0 and absf(q) < 8.0:
			continue
		rows.append({"id": other.id, "name": other.display_name, "p": p, "q": q, "mag": absf(p) + absf(q)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["mag"] > b["mag"])
	if rows.size() > 6:
		rows.resize(6)
	var parts: Array = []
	for row in rows:
		parts.append("%s:%s:%s" % [row["id"], _personal_word(float(row["p"])), _professional_word(float(row["q"]))])
	var sig := "|".join(PackedStringArray(parts))
	if sig == _rel_sig:
		return
	_rel_sig = sig
	for c in _rel_box.get_children():
		c.queue_free()
	if rows.is_empty():
		var l := Label.new()
		l.text = "No notable relationships yet."
		l.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_rel_box.add_child(l)
		return
	for row in rows:
		var b := Button.new()
		b.text = "%s  -  %s / %s" % [row["name"], _personal_word(float(row["p"])), _professional_word(float(row["q"]))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var oid := str(row["id"])
		b.pressed.connect(func() -> void: employee_requested.emit(oid))
		_rel_box.add_child(b)


static func _personal_word(p: float) -> String:
	if p > 55.0:
		return "close"
	if p > 20.0:
		return "friendly"
	if p < -55.0:
		return "hostile"
	if p < -20.0:
		return "tense"
	return "neutral"


static func _professional_word(q: float) -> String:
	if q > 40.0:
		return "respected"
	if q > 15.0:
		return "reliable"
	if q < -40.0:
		return "distrusted"
	if q < -15.0:
		return "doubted"
	return "working terms"


func _sync_memories() -> void:
	var e := _emp()
	if _mem_box == null or e == null:
		return
	var sig := str(e.memories.size())
	if sig == _mem_sig:
		return
	_mem_sig = sig
	for c in _mem_box.get_children():
		c.queue_free()
	if e.memories.is_empty():
		var l := Label.new()
		l.text = "Nothing of note."
		l.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_mem_box.add_child(l)
		return
	var start := maxi(0, e.memories.size() - 5)
	for i in range(e.memories.size() - 1, start - 1, -1):
		var m: Dictionary = e.memories[i]
		var l := Label.new()
		l.text = "Day %d: %s" % [int(m.get("day", 0)), str(m.get("text", ""))]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_mem_box.add_child(l)
