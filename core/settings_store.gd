class_name SettingsStore
extends RefCounted
## Player options, persisted to user://settings.cfg. All access is defensive: bad or
## missing values fall back to DEFAULTS.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"fullscreen": false,
	"master_volume": 0.8,
	"coach_hints": true,
	"reveal_all": false,
	"ui_scale": 1.0,
	"sim_speed": 1.0,
}

static var values: Dictionary = DEFAULTS.duplicate()


static func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in DEFAULTS.keys():
		if cfg.has_section_key("settings", key):
			var v: Variant = cfg.get_value("settings", key)
			if typeof(v) == typeof(DEFAULTS[key]):
				values[key] = v


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values.keys():
		cfg.set_value("settings", key, values[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsStore: could not save settings (error %d)" % err)


static func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
	if DEFAULTS.has(key):
		values[key] = value


static func apply(tree: SceneTree) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_value("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(get_value("master_volume")), 0.0001, 1.0)))
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = clampf(float(get_value("ui_scale")), 0.75, 1.5)
