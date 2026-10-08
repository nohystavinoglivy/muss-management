class_name ArtLoader
extends RefCounted
## Looks for real art on disk and returns null when absent, so every caller can fall back to
## procedural placeholders. Drop files in res://art/<folder>/<key>.png (or .webp/.jpg).
##   rooms/<art_key>.png        - full room scene (see RoomState.art_key; "hall" for corridor)
##   employees/<sprite_key>.png - standing figure, transparent background, feet at bottom edge
##   portraits/<sprite_key>.png - bust for database / dialogue
##   ui/<name>.png              - e.g. menu_background

const EXTS := ["png", "webp", "jpg"]

static var _cache: Dictionary = {}


static func _find(folder: String, key: String) -> Texture2D:
	if key == "":
		return null
	var cache_key := folder + "/" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex: Texture2D = null
	for ext in EXTS:
		var path := "res://art/%s/%s.%s" % [folder, key, ext]
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Texture2D:
				tex = res
				break
	_cache[cache_key] = tex
	return tex


static func room(key: String) -> Texture2D:
	return _find("rooms", key)


static func employee(key: String) -> Texture2D:
	return _find("employees", key)


static func portrait(key: String) -> Texture2D:
	return _find("portraits", key)


static func ui(key: String) -> Texture2D:
	return _find("ui", key)


static func clear_cache() -> void:
	_cache.clear()
