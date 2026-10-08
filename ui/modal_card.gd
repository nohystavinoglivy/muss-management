class_name ModalCard
extends Control
## Generic dimmed modal: title, BBCode body, and a column of choice buttons.
## choices: Array of {"label": String, "tip": String (optional), "disabled": bool (optional)}

signal choice_made(index: int)

var _body: RichTextLabel


static func create(title_text: String, body_bbcode: String, choices: Array, width: float = 640.0) -> ModalCard:
	var m := ModalCard.new()
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	m.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", ThemeFactory.box(Palette.PANEL, Palette.SKY, 2, 3, 18))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Label.new()
	t.text = title_text.to_upper()
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Palette.SKY)
	v.add_child(t)
	v.add_child(HSeparator.new())
	m._body = RichTextLabel.new()
	m._body.bbcode_enabled = true
	m._body.fit_content = true
	m._body.scroll_active = false
	m._body.text = body_bbcode
	v.add_child(m._body)
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := Button.new()
		b.text = str(c.get("label", "OK"))
		b.tooltip_text = str(c.get("tip", ""))
		b.disabled = bool(c.get("disabled", false))
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(func() -> void: m.choice_made.emit(i))
		v.add_child(b)
		if str(c.get("tip", "")) != "":
			var tip := Label.new()
			tip.text = str(c.get("tip", ""))
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip.add_theme_color_override("font_color", Palette.TEXT_DIM)
			tip.add_theme_font_size_override("font_size", 12)
			v.add_child(tip)
	return m
