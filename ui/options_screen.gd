class_name OptionsScreen
extends Control

signal navigate(screen: String)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.INK_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := Label.new()
	t.text = "OPTIONS"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Palette.SKY)
	v.add_child(t)
	v.add_child(HSeparator.new())

	_check(v, "Fullscreen", "fullscreen")
	_slider(v, "Master volume", "master_volume", 0.0, 1.0, 0.05)
	_slider(v, "Interface scale", "ui_scale", 0.75, 1.5, 0.05)
	_slider(v, "Simulation speed", "sim_speed", 0.5, 3.0, 0.1)
	v.add_child(HSeparator.new())
	_check(v, "Show Brandy's hints (tutorial)", "coach_hints")
	_check(v, "Show all information from the start (skips gradual reveal)", "reveal_all")

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void:
		SettingsStore.save_settings()
		navigate.emit("menu"))
	v.add_child(back)


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(SettingsStore.get_value(key))
	c.toggled.connect(func(on: bool) -> void:
		SettingsStore.set_value(key, on)
		SettingsStore.apply(get_tree()))
	parent.add_child(c)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(SettingsStore.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(220, 20)
	h.add_child(s)
	var val := Label.new()
	val.custom_minimum_size = Vector2(48, 0)
	val.text = "%.2f" % s.value
	h.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%.2f" % x
		SettingsStore.set_value(key, x)
		SettingsStore.apply(get_tree()))
	parent.add_child(h)
