class_name StatBar
extends HBoxContainer
## Label + coloured bar + number. Colour is recomputed from the value (SKY good -> ALERT bad).

var bad_when_high := true
var neutral := false   # true = always SKY (for traits, which are not good/bad)
var _name: Label
var _bar: ProgressBar
var _val: Label
var _last_color := Color.TRANSPARENT


func _init(label_text: String = "", bad_high: bool = true) -> void:
	bad_when_high = bad_high
	add_theme_constant_override("separation", 8)
	_name = Label.new()
	_name.text = label_text
	_name.custom_minimum_size = Vector2(104, 0)
	_name.add_theme_color_override("font_color", Palette.TEXT_DIM)
	add_child(_name)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(110, 14)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_bar)
	_val = Label.new()
	_val.custom_minimum_size = Vector2(32, 0)
	_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_val)


func set_value(v: float) -> void:
	_bar.value = v
	_val.text = str(roundi(v))
	var c := Palette.SKY if neutral else Palette.meter_color(v, bad_when_high)
	if c != _last_color:
		_last_color = c
		_bar.add_theme_stylebox_override("fill", ThemeFactory.box(c, Color.TRANSPARENT, 0, 1, 0))
