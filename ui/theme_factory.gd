class_name ThemeFactory
extends RefCounted
## Builds the global Theme from Palette. Screens receive it from main.gd.


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 2, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_color("default_color", "RichTextLabel", Palette.TEXT)
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Palette.INK_DEEP)
	t.set_color("font_focus_color", "Button", Palette.TEXT)
	t.set_color("font_disabled_color", "Button", Palette.MOSS)
	t.set_stylebox("normal", "Button", box(Palette.PANEL_LIGHT, Palette.SLATE, 1, 2, 8))
	t.set_stylebox("hover", "Button", box(Palette.SLATE, Palette.SKY, 1, 2, 8))
	t.set_stylebox("pressed", "Button", box(Palette.SKY, Palette.SKY, 1, 2, 8))
	t.set_stylebox("disabled", "Button", box(Palette.INK, Palette.PANEL, 1, 2, 8))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, Palette.SKY, 1, 2, 8))
	t.set_stylebox("panel", "PanelContainer", box(Palette.PANEL, Palette.SLATE, 1, 2, 10))
	t.set_stylebox("panel", "Panel", box(Palette.PANEL, Palette.SLATE, 1, 2, 10))
	t.set_stylebox("background", "ProgressBar", box(Palette.INK_DEEP, Palette.SLATE, 1, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.SKY, Color.TRANSPARENT, 0, 1, 0))
	t.set_stylebox("panel", "PopupMenu", box(Palette.INK_DEEP, Palette.SKY, 1, 2, 6))
	t.set_stylebox("hover", "PopupMenu", box(Palette.SLATE, Color.TRANSPARENT, 0, 2, 4))
	t.set_color("font_color", "PopupMenu", Palette.TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_color", "CheckBox", Palette.TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_stylebox("separator", "HSeparator", box(Palette.SLATE, Color.TRANSPARENT, 0, 0, 0))
	return t
