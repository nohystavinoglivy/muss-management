class_name RoomState
extends RefCounted
## Runtime state for one room. Condition is persistent between days (no daily reset).

const COND_KEYS: Array[String] = ["comfort", "safety", "cleanliness", "efficiency", "equipment"]

var id := ""
var display_name := ""
var function := "office"   # key into SimulationKernel.ROOM_EFFECTS / RoomArtView placeholders
var department_id := "ies"
var art_key := ""
var description := ""
var capacity := 1
var grid_rect := Rect2()   # position on the facility grid (see FacilityView)
var preferred_roles: Array = []
var condition: Dictionary = {}
var unlocked := true
var discovered := true
var output_today := 0.0


func _init() -> void:
	for k in COND_KEYS:
		condition[k] = 85.0


func cond(key: String) -> float:
	return float(condition.get(key, 0.0))


func add_cond(key: String, delta: float) -> void:
	condition[key] = clampf(cond(key) + delta, 0.0, 100.0)


func min_condition() -> float:
	var m := 100.0
	for k in COND_KEYS:
		m = minf(m, cond(k))
	return m


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "function": function,
		"department_id": department_id, "art_key": art_key, "description": description,
		"capacity": capacity,
		"grid_rect": [grid_rect.position.x, grid_rect.position.y, grid_rect.size.x, grid_rect.size.y],
		"preferred_roles": preferred_roles.duplicate(), "condition": condition.duplicate(),
		"unlocked": unlocked, "discovered": discovered, "output_today": output_today,
	}


static func from_dict(d: Dictionary) -> RoomState:
	var r := RoomState.new()
	r.id = str(d.get("id", ""))
	r.display_name = str(d.get("display_name", ""))
	r.function = str(d.get("function", "office"))
	r.department_id = str(d.get("department_id", "ies"))
	r.art_key = str(d.get("art_key", ""))
	r.description = str(d.get("description", ""))
	r.capacity = maxi(1, int(d.get("capacity", 1)))
	var g: Variant = d.get("grid_rect", [0, 0, 1, 1])
	if g is Array and g.size() >= 4:
		r.grid_rect = Rect2(float(g[0]), float(g[1]), float(g[2]), float(g[3]))
	var p: Variant = d.get("preferred_roles", [])
	if p is Array:
		r.preferred_roles = p.duplicate()
	var c: Variant = d.get("condition", {})
	if c is Dictionary:
		for k in COND_KEYS:
			if c.has(k):
				r.condition[k] = clampf(float(c[k]), 0.0, 100.0)
	r.unlocked = bool(d.get("unlocked", true))
	r.discovered = bool(d.get("discovered", true))
	r.output_today = float(d.get("output_today", 0.0))
	return r
