class_name SimulationKernel
extends RefCounted
## Headless, scene-free simulation step. Everything operates on plain dictionaries of
## EmployeeState / RoomState so it can be unit-tested without any UI.
## Units: one tick = one simulated minute. Needs are 0..100.

const BREAK_LENGTH := 30
const OFFSITE := "__offsite"
const BASE_OUTPUT := 0.022  # tasks per minute for a competence-50 employee

## Per-minute deltas by room function. "work" rooms generate output.
const ROOM_EFFECTS := {
	"office": {"work": true, "fatigue": 0.045, "stress": 0.020, "morale": -0.004},
	"interview": {"work": true, "fatigue": 0.050, "stress": 0.035, "morale": -0.004},
	"mediation": {"work": true, "fatigue": 0.055, "stress": 0.050, "morale": -0.006},
	"break": {"fatigue": -0.25, "stress": -0.20, "morale": 0.06},
	"lounge": {"fatigue": -0.12, "stress": -0.18, "morale": 0.08, "satisfaction": 0.02},
}


static func new_stats() -> Dictionary:
	return {
		"tasks_done": 0.0, "idle_minutes": 0, "strain_minutes": 0,
		"incidents_resolved": 0, "incidents_ignored": 0, "breakdowns": 0,
		"warned": {}, "triggered": {}, "tension": {},
	}


static func find_room_by_function(rooms: Dictionary, function_key: String) -> String:
	var ids: Array = rooms.keys()
	ids.sort()
	for rid in ids:
		var r: RoomState = rooms[rid]
		if r.function == function_key and r.unlocked:
			return str(rid)
	return ""


## Resolves where everyone physically is this minute, respecting capacity. Deterministic
## (sorted by id). People who cannot be placed idle in the hall (location "").
static func update_locations(employees: Dictionary, rooms: Dictionary, minute: int) -> void:
	var counts: Dictionary = {}
	var ids: Array = employees.keys()
	ids.sort()
	var break_room_id := find_room_by_function(rooms, "break")
	var deferred: Array = []
	for id in ids:
		var e: EmployeeState = employees[id]
		if e.away_until > minute:
			e.location_room = OFFSITE
			continue
		var on_break: bool = e.break_at >= 0 and minute >= e.break_at and minute < e.break_at + BREAK_LENGTH and break_room_id != "" and e.assignment_room != break_room_id
		if on_break:
			deferred.append(e)
		else:
			e.location_room = _try_place(e.assignment_room, rooms, counts)
	for e in deferred:
		var placed := _try_place(break_room_id, rooms, counts)
		if placed == "":
			placed = _try_place(e.assignment_room, rooms, counts)
		e.location_room = placed


static func _try_place(room_id: String, rooms: Dictionary, counts: Dictionary) -> String:
	if room_id == "" or not rooms.has(room_id):
		return ""
	var r: RoomState = rooms[room_id]
	if not r.unlocked or int(counts.get(room_id, 0)) >= r.capacity:
		return ""
	counts[room_id] = int(counts.get(room_id, 0)) + 1
	return room_id


## Advances one minute. Returns events for IncidentManager/log:
## {"type": "warning", "text": ..., "employee_id": ...} or {"type": "incident", "id": ..., ...}
static func tick(employees: Dictionary, rooms: Dictionary, minute: int, stats: Dictionary, rng: RandomNumberGenerator) -> Array:
	var events: Array = []
	update_locations(employees, rooms, minute)
	var ids: Array = employees.keys()
	ids.sort()
	for id in ids:
		_apply_employee_minute(employees[id], rooms, stats, events)
	if minute % 10 == 0:
		_drift_relationships(employees, rooms, ids, stats, events)
	return events


static func _apply_employee_minute(e: EmployeeState, rooms: Dictionary, stats: Dictionary, events: Array) -> void:
	if e.location_room == OFFSITE:
		e.add_need("fatigue", 0.03)
		return
	var stress_mult := 0.7 + 0.6 * e.trait_n("anxiety")
	var fatigue_mult := 1.15 - 0.3 * e.trait_n("work_ethic")
	var room: RoomState = rooms.get(e.location_room) as RoomState
	if room == null:
		e.add_need("fatigue", -0.02)
		e.add_need("morale", -0.02)
		e.add_need("engagement", -0.03)
		stats["idle_minutes"] = int(stats["idle_minutes"]) + 1
	else:
		var fx: Dictionary = ROOM_EFFECTS.get(room.function, {})
		var comfort_f := 1.0 + (50.0 - room.cond("comfort")) / 100.0
		var d_fatigue := float(fx.get("fatigue", 0.0))
		var d_stress := float(fx.get("stress", 0.0))
		if d_fatigue > 0.0:
			d_fatigue *= fatigue_mult * comfort_f
		if d_stress > 0.0:
			d_stress *= stress_mult * comfort_f
		else:
			d_stress *= 1.2 - 0.4 * e.trait_n("anxiety")
		e.add_need("fatigue", d_fatigue)
		e.add_need("stress", d_stress)
		e.add_need("morale", float(fx.get("morale", 0.0)))
		e.add_need("satisfaction", float(fx.get("satisfaction", 0.0)))
		if bool(fx.get("work", false)):
			e.add_need("engagement", 0.012 if e.need("morale") > 50.0 else -0.012)
			var role_mult := 1.0 if room.preferred_roles.is_empty() or room.preferred_roles.has(e.role) else 0.75
			var fatigue_pen := 1.0 - clampf((e.need("fatigue") - 40.0) / 100.0, 0.0, 0.5)
			var morale_f := 0.7 + 0.3 * e.need("morale") / 100.0
			var out := BASE_OUTPUT * (e.competence / 50.0) * role_mult * fatigue_pen * morale_f * (room.cond("efficiency") / 100.0)
			room.output_today += out
			stats["tasks_done"] = float(stats["tasks_done"]) + out
	# Cross-effects and precursors
	if e.need("stress") > 60.0:
		e.add_need("morale", -0.01)
	var warned: Dictionary = stats["warned"]
	if e.need("stress") >= 70.0 and not warned.has(e.id + ":stress"):
		warned[e.id + ":stress"] = true
		events.append({"type": "warning", "employee_id": e.id, "text": "%s is showing signs of strain." % e.display_name})
	if e.need("fatigue") >= 75.0 and not warned.has(e.id + ":fatigue"):
		warned[e.id + ":fatigue"] = true
		events.append({"type": "warning", "employee_id": e.id, "text": "%s looks exhausted." % e.display_name})
	if e.need("stress") > 80.0 or e.need("fatigue") > 85.0:
		e.add_need("stability", -0.06)
		stats["strain_minutes"] = int(stats["strain_minutes"]) + 1
	elif e.need("stress") < 50.0 and e.need("fatigue") < 60.0:
		e.add_need("stability", 0.02)
	var triggered: Dictionary = stats["triggered"]
	if e.need("stability") < 25.0 and not triggered.has("breakdown:" + e.id):
		triggered["breakdown:" + e.id] = true
		stats["breakdowns"] = int(stats["breakdowns"]) + 1
		events.append({"type": "incident", "id": "employee_breakdown", "employee_id": e.id})


static func _drift_relationships(employees: Dictionary, rooms: Dictionary, ids: Array, stats: Dictionary, events: Array) -> void:
	var by_room: Dictionary = {}
	for id in ids:
		var e: EmployeeState = employees[id]
		if e.location_room != "" and e.location_room != OFFSITE and rooms.has(e.location_room):
			if not by_room.has(e.location_room):
				by_room[e.location_room] = []
			by_room[e.location_room].append(e)
	var triggered: Dictionary = stats["triggered"]
	for rid in by_room.keys():
		var room: RoomState = rooms[rid]
		var group: Array = by_room[rid]
		var social: bool = room.function == "break" or room.function == "lounge"
		var working: bool = bool(ROOM_EFFECTS.get(room.function, {}).get("work", false))
		for i in group.size():
			for j in range(i + 1, group.size()):
				var a: EmployeeState = group[i]
				var b: EmployeeState = group[j]
				var soc := a.trait_n("sociability") + b.trait_n("sociability")
				var pat := a.trait_n("patience") + b.trait_n("patience")
				var base := 0.5 if social else (0.1 if working else 0.0)
				var dp := base * (soc - 0.8) + (pat - 1.0) * 0.25
				var cur := float(a.rel(b.id).get("personal", 0.0))
				if cur < -20.0:
					dp -= (1.4 - pat) * 0.3
				var dpro := 0.0
				if working:
					dpro = (a.trait_n("conscientiousness") + b.trait_n("conscientiousness") - 0.9) * 0.2
				a.shift_rel(b.id, dp, dpro)
				b.shift_rel(a.id, dp, dpro)
				if cur < -30.0 and working:
					a.add_need("stress", 0.4)
					b.add_need("stress", 0.4)
					var key := "conflict:%s:%s" % [a.id, b.id]
					var tension: Dictionary = stats["tension"]
					tension[key] = int(tension.get(key, 0)) + 1
					if (int(tension[key]) >= 6 or a.need("stress") > 50.0 or b.need("stress") > 50.0) and not triggered.has(key):
						triggered[key] = true
						events.append({"type": "incident", "id": "conflict_flare", "employee_id": a.id, "other_id": b.id, "room_id": str(rid)})


## End-of-day recovery. Called once when a day is finalized.
static func overnight(employees: Dictionary) -> void:
	for id in employees.keys():
		var e: EmployeeState = employees[id]
		e.needs["fatigue"] = maxf(0.0, e.need("fatigue") * 0.45 - 6.0)
		e.needs["stress"] = e.need("stress") * 0.6
		e.add_need("morale", (e.need("satisfaction") - e.need("morale")) * 0.25)
		e.add_need("satisfaction", clampf((e.need("morale") - 55.0) * 0.05 - (e.need("stress") - 30.0) * 0.03, -4.0, 4.0))
		e.add_need("stability", 6.0)
		e.away_until = -1
