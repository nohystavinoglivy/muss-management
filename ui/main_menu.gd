class_name MainMenu
extends Control
## Resume (day N) / Tutorial / Database / Options / Exit.

signal navigate(screen: String)

var _note: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.INK_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.draw.connect(func() -> void: _draw_backdrop(art))
	add_child(art)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.text = "MUSS"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Palette.SKY)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "COMPANY MANAGEMENT"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	v.add_child(gap)

	var save := GameState.peek_save() if GameState.has_save() else {}
	var resume := _button("Resume  -  Day %d" % int(save.get("day", 1)) if not save.is_empty() else "Resume")
	resume.disabled = save.is_empty()
	resume.pressed.connect(_on_resume)
	v.add_child(resume)
	var tut := _button("Tutorial")
	tut.pressed.connect(func() -> void:
		GameState.start_new_campaign(true)
		navigate.emit("management"))
	v.add_child(tut)
	var db := _button("Database")
	db.pressed.connect(func() -> void: navigate.emit("database"))
	v.add_child(db)
	var opt := _button("Options")
	opt.pressed.connect(func() -> void: navigate.emit("options"))
	v.add_child(opt)
	var quit := _button("Exit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)

	_note = Label.new()
	_note.add_theme_color_override("font_color", Palette.ALERT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	var foot := Label.new()
	foot.text = "Pre-production build"
	foot.add_theme_color_override("font_color", Palette.MOSS)
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	v.add_child(foot)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(0, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	return b


func _on_resume() -> void:
	if GameState.load_from_disk():
		navigate.emit("management")
	else:
		_note.text = "The save file could not be read. Start the Tutorial to begin a new campaign."


func _draw_backdrop(c: Control) -> void:
	var tex := ArtLoader.ui("menu_background")
	if tex != null:
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, c.size), false)
		return
	# placeholder: stacked facility cross-section silhouette on the right
	var s := c.size
	var x0 := s.x * 0.52
	for row in 5:
		var y := 80.0 + row * (s.y - 160.0) / 5.0
		var h := (s.y - 160.0) / 5.0 - 10.0
		var x := x0
		var i := 0
		while x < s.x - 60.0:
			var w := 120.0 + float((i * 37 + row * 53) % 100)
			w = minf(w, s.x - 60.0 - x)
			var col := Palette.SLATE.darkened(0.55 + 0.05 * float((i + row) % 3))
			c.draw_rect(Rect2(x, y, w - 6.0, h), col)
			c.draw_rect(Rect2(x, y, w - 6.0, h), Palette.SLATE.darkened(0.2), false, 1.0)
			x += w
			i += 1
	c.draw_rect(Rect2(x0 - 14, 70, 4, s.y - 140), Palette.ALERT)
