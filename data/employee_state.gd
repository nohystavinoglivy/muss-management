class_name EmployeeState
extends RefCounted
## Runtime state for one employee. Pure data + small helpers; no scene dependencies.

const NEED_KEYS: Array[String] = ["morale", "stress", "fatigue", "satisfaction", "engagement", "stability"]
const TRAIT_KEYS: Array[String] = [
	"conscientiousness", "sociability", "patience", "empathy", "ambition", "anxiety",
	"stubbornness", "adaptability", "loyalty", "work_ethic", "sensitivity",
]
const NEED_DEFAULTS := {
	"morale": 70.0, "stress": 15.0, "fatigue": 10.0,
	"satisfaction": 65.0, "engagement": 55.0, "stability": 85.0,
}
const FIRST_NAMES: Array[String] = [
	"Marisol", "Dennis", "Tamsin", "Okonkwo", "Ilse", "Rafferty", "Junia", "Caspian", "Odalys",
	"Bram", "Lenore", "Thaddeus", "Priya", "Emeric", "Noor", "Gideon", "Soledad", "Felix",
]
const LAST_NAMES: Array[String] = [
	"Vance", "Okafor", "Lindqvist", "Marsh", "Delacroix", "Whitlock", "Nakamura", "Brandt",
	"Quillfeather", "Osei", "Ferreira", "Holloway", "Castellan", "Pruitt", "Adeyemi", "Sorensen",
]
const ROLES: Array[String] = ["Clerk", "Coordinator", "Counselor", "Mediator", "Associate"]
const TINTS: Array[String] = ["85BAEA", "767865", "6F8FB0", "A3A58E", "5F7A94", "B7CBD6", "8C6F6B"]

var id := ""
var display_name := "Unnamed"
var role := "Associate"
var is_named := false
var player_assignable := true
var bio := ""
var sprite_key := "generic"
var tint_html := "85BAEA"
var competence := 50.0
var needs: Dictionary = {}
var traits: Dictionary = {}
var relationships: Dictionary = {}  # other_id -> {"personal": float, "professional": float}
var memories: Array = []            # [{"day": int, "text": String}]
var assignment_room := ""
var break_at := -1                  # sim minute of day, -1 = none
var location_room := ""             # resolved each sim minute by SimulationKernel
var away_until := -1
var discovered := true


func _init() -> void:
	needs = NEED_DEFAULTS.duplicate()
	for k in TRAIT_KEYS:
		traits[k] = 50.0


func need(key: String) -> float:
	return float(needs.get(key, 0.0))


func add_need(key: String, delta: float) -> void:
	needs[key] = clampf(need(key) + delta, 0.0, 100.0)


func trait_n(key: String) -> float:
	return clampf(float(traits.get(key, 50.0)), 0.0, 100.0) / 100.0


func tint() -> Color:
	return Color.html(tint_html) if Color.html_is_valid(tint_html) else Palette.SKY


func rel(other_id: String) -> Dictionary:
	if relationships.has(other_id):
		return relationships[other_id]
	return {"personal": 0.0, "professional": 0.0}


func shift_rel(other_id: String, d_personal: float, d_professional: float) -> void:
	var r: Dictionary = rel(other_id).duplicate()
	r["personal"] = clampf(float(r.get("personal", 0.0)) + d_personal, -100.0, 100.0)
	r["professional"] = clampf(float(r.get("professional", 0.0)) + d_professional, -100.0, 100.0)
	relationships[other_id] = r


func set_rel(other_id: String, personal: float, professional: float) -> void:
	relationships[other_id] = {"personal": clampf(personal, -100.0, 100.0), "professional": clampf(professional, -100.0, 100.0)}


func add_memory(day: int, text: String) -> void:
	memories.append({"day": day, "text": text})
	var cap := 24 if is_named else 8
	while memories.size() > cap:
		memories.pop_front()


func strain() -> float:
	return maxf(need("stress"), need("fatigue"))


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "role": role, "is_named": is_named,
		"player_assignable": player_assignable, "bio": bio, "sprite_key": sprite_key,
		"tint_html": tint_html, "competence": competence, "needs": needs.duplicate(),
		"traits": traits.duplicate(), "relationships": relationships.duplicate(true),
		"memories": memories.duplicate(true), "assignment_room": assignment_room,
		"break_at": break_at, "location_room": location_room, "away_until": away_until,
		"discovered": discovered,
	}


static func from_dict(d: Dictionary) -> EmployeeState:
	var e := EmployeeState.new()
	e.id = str(d.get("id", ""))
	e.display_name = str(d.get("display_name", "Unnamed"))
	e.role = str(d.get("role", "Associate"))
	e.is_named = bool(d.get("is_named", false))
	e.player_assignable = bool(d.get("player_assignable", true))
	e.bio = str(d.get("bio", ""))
	e.sprite_key = str(d.get("sprite_key", "generic"))
	e.tint_html = str(d.get("tint_html", "85BAEA"))
	e.competence = float(d.get("competence", 50.0))
	var n: Variant = d.get("needs", {})
	if n is Dictionary:
		for k in NEED_KEYS:
			if n.has(k):
				e.needs[k] = clampf(float(n[k]), 0.0, 100.0)
	var t: Variant = d.get("traits", {})
	if t is Dictionary:
		for k in TRAIT_KEYS:
			if t.has(k):
				e.traits[k] = clampf(float(t[k]), 0.0, 100.0)
	var r: Variant = d.get("relationships", {})
	if r is Dictionary:
		for other in r.keys():
			var entry: Variant = r[other]
			if entry is Dictionary:
				e.set_rel(str(other), float(entry.get("personal", 0.0)), float(entry.get("professional", 0.0)))
	var m: Variant = d.get("memories", [])
	if m is Array:
		for item in m:
			if item is Dictionary:
				e.memories.append({"day": int(item.get("day", 0)), "text": str(item.get("text", ""))})
	e.assignment_room = str(d.get("assignment_room", ""))
	e.break_at = int(d.get("break_at", -1))
	e.location_room = str(d.get("location_room", ""))
	e.away_until = int(d.get("away_until", -1))
	e.discovered = bool(d.get("discovered", true))
	return e


static func generate(rng: RandomNumberGenerator, index: int) -> EmployeeState:
	var e := EmployeeState.new()
	e.id = "gen_%02d" % index
	e.display_name = "%s %s" % [FIRST_NAMES[(index * 5 + rng.randi() % 3) % FIRST_NAMES.size()], LAST_NAMES[(index * 3 + rng.randi() % 4) % LAST_NAMES.size()]]
	e.role = ROLES[index % ROLES.size()]
	e.sprite_key = "generic_%d" % (index % 4)
	e.tint_html = TINTS[index % TINTS.size()]
	e.competence = clampf(rng.randfn(55.0, 14.0), 25.0, 90.0)
	for k in TRAIT_KEYS:
		e.traits[k] = clampf(rng.randfn(50.0, 22.0), 5.0, 95.0)
	e.needs["morale"] = clampf(rng.randfn(68.0, 8.0), 40.0, 90.0)
	e.needs["satisfaction"] = clampf(rng.randfn(62.0, 8.0), 35.0, 90.0)
	return e
