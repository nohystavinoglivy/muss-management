class_name DatabaseScreen
extends Control
## Main-menu database: employees, rooms, department info and records, limited to what the
## campaign has revealed so far. Reuses DatabasePanel in read-only mode.

signal navigate(screen: String)

var _tab := "employees"
var _list: VBoxContainer
var _panel: DatabasePanel
var _text: RichTextLabel
var _right: Control
var _tab_buttons: Dictionary = {}


func _ready() -> void:
	if not GameState.campaign_active and GameState.has_save():
		GameState.load_from_disk()
	var bg := ColorRect.new()
	bg.color = Palette.INK_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 24)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = "DATABASE"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Palette.SKY)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func() -> void: navigate.emit("menu"))
	head.add_child(back)
	v.add_child(head)

	var tabs := HBoxContainer.new()
	for key in ["employees", "rooms", "department", "records"]:
		var b := Button.new()
		b.text = key.to_upper()
		b.toggle_mode = true
		b.pressed.connect(func() -> void: _set_tab(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
	v.add_child(tabs)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	v.add_child(body)
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_right = Control.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_right)
	_panel = DatabasePanel.new()
	_panel.read_only = true
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.employee_requested.connect(func(id: String) -> void:
		_set_tab("employees")
		_panel.show_employee(id))
	_right.add_child(_panel)
	var tp := PanelContainer.new()
	tp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	tp.add_child(_text)
	tp.visible = false
	_right.add_child(tp)
	_text.set_meta("holder", tp)
	_set_tab("employees")


func _set_tab(tab: String) -> void:
	_tab = tab
	for k in _tab_buttons.keys():
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == tab)
	for c in _list.get_children():
		c.queue_free()
	var holder: Control = _text.get_meta("holder")
	holder.visible = (tab == "department" or tab == "records")
	_panel.visible = not holder.visible
	if not GameState.campaign_active:
		_empty("No campaign data yet. Start the Tutorial to begin accumulating records.")
		holder.visible = false
		_panel.visible = false
		return
	match tab:
		"employees":
			for e in GameState.staff_sorted():
				var emp: EmployeeState = e
				_entry(emp.display_name, func() -> void: _panel.show_employee(emp.id))
			_panel.clear_selection()
		"rooms":
			var ids: Array = GameState.rooms.keys()
			ids.sort()
			for id in ids:
				var r: RoomState = GameState.rooms[id]
				if r.discovered and r.unlocked:
					var rid: String = r.id
					_entry(r.display_name, func() -> void: _panel.show_room(rid))
				else:
					_entry("[CLASSIFIED]", Callable(), true)
			_panel.clear_selection()
		"department":
			_entry("Overview", func() -> void: _show_department())
			_show_department()
		"records":
			if GameState.records.is_empty():
				_empty("No records recovered yet.")
				_text.text = ""
			for r in GameState.records:
				var rec: Dictionary = r
				_entry(str(rec.get("title", "Untitled")), func() -> void:
					_text.text = "[b]%s[/b]\n\n%s" % [rec.get("title", ""), rec.get("body", "")])
			if not GameState.records.is_empty():
				_text.text = "Select a record."


func _entry(text: String, on_press: Callable, disabled: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = disabled
	if on_press.is_valid():
		b.pressed.connect(on_press)
	_list.add_child(b)


func _empty(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_list.add_child(l)


func _show_department() -> void:
	var d := GameState.dept()
	if d == null:
		return
	var lines: Array = []
	lines.append("[b]%s[/b]" % d.display_name)
	lines.append("Tier %d   -   %s" % [d.tier, "Certified" if d.completed else "Day %d of %d" % [d.current_day, d.required_days]])
	lines.append("")
	lines.append(d.description)
	lines.append("")
	if not d.history.is_empty():
		lines.append("[b]Completed days[/b]")
		for h in d.history:
			lines.append("Day %d  -  grade %s" % [int(h.get("day", 0)), str(h.get("grade", "?"))])
	_text.text = "\n".join(PackedStringArray(lines))
