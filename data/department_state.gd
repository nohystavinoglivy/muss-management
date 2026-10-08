class_name DepartmentState
extends RefCounted
## Department progress. A department normally certifies after `required_days` finalized days.

var id := ""
var display_name := ""
var tier := 0
var required_days := 6
var current_day := 1          # the day currently being played (1-based)
var completed := false
var mentor_id := ""
var description := ""
var history: Array = []       # finalized day results: [{"day","grade","performance"}]


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "tier": tier, "required_days": required_days,
		"current_day": current_day, "completed": completed, "mentor_id": mentor_id,
		"description": description, "history": history.duplicate(true),
	}


static func from_dict(d: Dictionary) -> DepartmentState:
	var s := DepartmentState.new()
	s.id = str(d.get("id", ""))
	s.display_name = str(d.get("display_name", ""))
	s.tier = int(d.get("tier", 0))
	s.required_days = maxi(1, int(d.get("required_days", 6)))
	s.current_day = clampi(int(d.get("current_day", 1)), 1, s.required_days)
	s.completed = bool(d.get("completed", false))
	s.mentor_id = str(d.get("mentor_id", ""))
	s.description = str(d.get("description", ""))
	var h: Variant = d.get("history", [])
	if h is Array:
		for item in h:
			if item is Dictionary:
				s.history.append(item.duplicate(true))
	return s
