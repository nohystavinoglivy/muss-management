class_name PortraitBox
extends Control
## Bust portrait. Uses res://art/portraits/<key>.png if present, else a placeholder silhouette.

var sprite_key := ""
var tint := Palette.SKY
var initial := "?"


func _init(size_px: Vector2 = Vector2(96, 96)) -> void:
	custom_minimum_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(key: String, color: Color, letter: String) -> void:
	sprite_key = key
	tint = color
	initial = letter.substr(0, 1).to_upper()
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.INK_DEEP)
	var tex := ArtLoader.portrait(sprite_key)
	if tex != null:
		draw_texture_rect(tex, r, false)
	else:
		draw_rect(Rect2(0, 0, size.x, size.y), Palette.SLATE.darkened(0.4))
		var cx := size.x * 0.5
		draw_circle(Vector2(cx, size.y * 0.42), size.y * 0.2, tint.lightened(0.25))
		draw_rect(Rect2(cx - size.x * 0.3, size.y * 0.66, size.x * 0.6, size.y * 0.34), tint)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(cx - 6, size.y * 0.47), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.2), Palette.INK_DEEP)
	draw_rect(r, Palette.SLATE, false, 1.0)
