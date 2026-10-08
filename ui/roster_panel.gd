class_name RosterPanel
extends PanelContainer
## Left-hand staff list. Rows are updated in place; the status dot teaches the player to read
## strain gradually (morale on day 1, stress/fatigue from day 2).

signal employee_selected(employee_id: String)

class RosterRow extends PanelContainer:
	signal clicked(employee_id: String)
	var emp_id := ""
	var selected := false:
		set(v):
			selected = v
			_restyle()
	var _swatch: ColorRect
	var _name: Label
	var _sub: Label
	var _dot: ColorRect

	func _init(id: String) -> void:
		emp_id = id
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_swatch = ColorRect.new()
		_swatch.custom_minimum_size = Vector2(8, 36)
		_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_swatch)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		_name = Label.new()
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(_name)
		_sub = Label.new()
		_sub.add_theme_font_size_override("font_size", 12)
		_sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(_sub)
		_dot = ColorRect.new()
		_dot.custom_minimum_size = Vector2(12, 12)
		_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_dot)
		_restyle()

	func _restyle() -> void:
		var border := Palette.SKY if selected else Palette.SLATE
		add_theme_stylebox_override("panel", ThemeFactory.box(Palette.PANEL_LIGHT if selected else Palette.PANEL, border, 2 if selected else 1, 2, 6))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(emp_id)

	func refresh() -> void:
		var e := GameState.get_employee(emp_id)
		if e == null:
			return
		_name.text = e.display_name
		_swatch.color = e.tint()
		var loc := "Unassigned"
		if e.location_room == SimulationKernel.OFFSITE:
			loc = "Off-site"
		elif e.assignment_room != "":
			loc = GameState.room_name(e.assignment_room)
			if e.location_room != e.assignment_room:
				loc += " (away)" if e.location_room != "" else " (waiting)"
		_sub.text = ("%s  -  %s" % [e.role, loc]) if GameState.is_revealed("role") else loc
		if e.assignment_room == "" and e.player_assignable:
			_sub.add_theme_color_override("font_color", Palette.ALERT.lerp(Palette.TEXT_DIM, 0.4))
		else:
			_sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
		if GameState.is_revealed("stress"):
			_dot.color = Palette.meter_color(e.strain(), true)
		else:
			_dot.color = Palette.meter_color(e.need("morale"), false)


var selected_id := ""

var _rows: Dictionary = {}
var _list: VBoxContainer
var _count: Label


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = "STAFF"
	t.add_theme_color_override("font_color", Palette.SKY)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_count = Label.new()
	_count.add_theme_color_override("font_color", Palette.TEXT_DIM)
	head.add_child(_count)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	GameState.state_changed.connect(refresh)
	refresh()


func set_selected(id: String) -> void:
	selected_id = id
	for rid in _rows.keys():
		(_rows[rid] as RosterRow).selected = (rid == id)


func refresh() -> void:
	if _list == null:
		return
	var staff: Array = GameState.staff_sorted()
	var wanted: Dictionary = {}
	for e in staff:
		wanted[(e as EmployeeState).id] = true
	for id in _rows.keys():
		if not wanted.has(id):
			(_rows[id] as Node).queue_free()
			_rows.erase(id)
	var assigned := 0
	for i in staff.size():
		var e: EmployeeState = staff[i]
		if not _rows.has(e.id):
			var row := RosterRow.new(e.id)
			row.clicked.connect(func(id: String) -> void: employee_selected.emit(id))
			_list.add_child(row)
			_rows[e.id] = row
			row.selected = (e.id == selected_id)
		var r: RosterRow = _rows[e.id]
		_list.move_child(r, i)
		r.refresh()
		if e.assignment_room != "":
			assigned += 1
	_count.text = "%d / %d posted" % [assigned, staff.size()]
