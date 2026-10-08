class_name CoachPanel
extends PanelContainer
## Brandy's tutorial prompt. Floats at the bottom of the centre area.

signal next_pressed
signal skip_pressed

var _text: RichTextLabel
var _next: Button
var _portrait: PortraitBox


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(560, 0)
	add_theme_stylebox_override("panel", ThemeFactory.box(Palette.INK_DEEP, Palette.SKY, 2, 3, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	_portrait = PortraitBox.new(Vector2(76, 76))
	_portrait.setup("brandy", Palette.SKY, "B")
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var who := Label.new()
	who.text = "BRANDY"
	who.add_theme_color_override("font_color", Palette.SKY)
	v.add_child(who)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_next = Button.new()
	_next.text = "Next"
	_next.pressed.connect(func() -> void: next_pressed.emit())
	row.add_child(_next)
	var skip := Button.new()
	skip.text = "Skip hints today"
	skip.pressed.connect(func() -> void: skip_pressed.emit())
	row.add_child(skip)
	v.add_child(row)


func show_step(step: Dictionary) -> void:
	if step.is_empty():
		visible = false
		return
	_text.text = str(step.get("text", ""))
	_next.visible = str(step.get("wait", "next")) == "next"
	visible = true
