extends Node
## Root: owns the global theme and swaps whole screens. Screens emit navigate(screen_name).

var _current: Control = null
var _theme: Theme


func _ready() -> void:
	SettingsStore.load_settings()
	SettingsStore.apply(get_tree())
	_theme = ThemeFactory.build()
	RenderingServer.set_default_clear_color(Palette.INK_DEEP)
	show_screen("menu")


func show_screen(screen: String) -> void:
	if is_instance_valid(_current):
		_current.queue_free()
		_current = null
	var node: Control = null
	match screen:
		"menu":
			node = MainMenu.new()
		"management":
			node = ManagementScreen.new()
		"database":
			node = DatabaseScreen.new()
		"options":
			node = OptionsScreen.new()
		_:
			push_warning("Main.show_screen: unknown screen '%s'" % screen)
			node = MainMenu.new()
	node.theme = _theme
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.connect("navigate", show_screen)
	add_child(node)
	_current = node
