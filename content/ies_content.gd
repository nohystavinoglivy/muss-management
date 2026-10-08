class_name IESContent
extends RefCounted
## All Interactions & Employee Satisfaction (IES) content: layout, staff, day scripts, progressive
## disclosure schedule, tutorial steps. Other departments should get their own content class
## with the same function names so the managers stay generic.

## Day (of the department) on which each piece of UI/data becomes visible to the player.
const REVEAL_DAY := {
	"role": 1, "assignment": 1, "morale": 1, "room_function": 1, "room_occupancy": 1, "preferred_roles": 1,
	"fatigue": 2, "stress": 2, "break_schedule": 2, "room_output": 2, "speed_controls": 2,
	"satisfaction": 3, "personality_summary": 3, "relationships": 3,
	"room_condition": 4, "incidents_panel": 4, "engagement": 4, "memories": 4,
	"stability": 5, "interdepartment": 5,
	"personality_full": 6,
}

const DAYS: Array = [
	{
		"title": "Introduction", "demand": 14,
		"brief": [
			"Welcome to Interactions & Employee Satisfaction. Today is about the basics.",
			"Staff the IES Office. Click a room tile to see it, click a person to see who they are, then give them somewhere to work.",
			"Press Start Shift when you are ready. You can pause at any time.",
		],
	},
	{
		"title": "Application", "demand": 32,
		"brief": [
			"People get tired. Today you can see fatigue and stress, and you can schedule breaks.",
			"The Break Room and Employee Lounge are where people recover. A short break costs output now and buys it back later.",
		],
	},
	{
		"title": "Complication", "demand": 48,
		"brief": [
			"Personalities and relationships are now visible. Some people work well together. Some do not.",
			"Watch who shares a room. Friendships form in the break room. Friction builds at the desks.",
		],
	},
	{
		"title": "Expansion", "demand": 44,
		"brief": [
			"Incidents are now part of your job. They show up on the tray at the bottom of the screen.",
			"You will not be able to fix everything. Decide what matters most.",
		],
	},
	{
		"title": "Stress Test", "demand": 38,
		"brief": [
			"Another department has noticed IES is the place to ask for favours. Staffing requests will come in.",
			"Keep the floor stable while you help where you can.",
		],
	},
	{
		"title": "Evaluation", "demand": 52,
		"brief": [
			"Today is your evaluation. Everything is visible. Several problems will overlap.",
			"Brandy will be observing. She will not be stepping in.",
		],
	},
]

const SCRIPTED := {
	4: [{"minute": 630, "id": "break_room_malfunction"}, {"minute": 690, "id": "employee_complaint"}, {"minute": 780, "id": "staffing_request"}],
	5: [{"minute": 570, "id": "staffing_request"}, {"minute": 660, "id": "equipment_fault"}, {"minute": 840, "id": "employee_complaint"}],
	6: [{"minute": 540, "id": "employee_complaint"}, {"minute": 570, "id": "break_room_malfunction"}, {"minute": 600, "id": "staffing_request"},
		{"minute": 660, "id": "equipment_fault"}, {"minute": 720, "id": "employee_complaint"}],
}


static func day_def(day: int) -> Dictionary:
	return DAYS[clampi(day, 1, DAYS.size()) - 1]


static func scripted_incidents(day: int) -> Array:
	return SCRIPTED.get(day, [])


# ---------------------------------------------------------------- initial company population

static func populate(gs: Node, seed_value: int) -> void:
	var dep := DepartmentState.new()
	dep.id = "ies"
	dep.display_name = "Interactions & Employee Satisfaction"
	dep.tier = 0
	dep.required_days = DAYS.size()
	dep.mentor_id = "brandy"
	dep.description = "IES keeps the company's people functioning: scheduling, morale, complaints, mediation, and the quiet logistics of employee satisfaction. Informally led by Brandy."
	gs.departments["ies"] = dep

	_add_room(gs, "ies_office", "IES Office", "office", 4, Rect2(0, 0, 5, 3), ["Coordinator", "Clerk"],
		"The administrative hub. Requests, complaints and schedules all pass through here.")
	_add_room(gs, "interview_room", "Interview Room", "interview", 1, Rect2(5, 0, 3, 3), ["Counselor"],
		"A private room for one-on-one conversations. Concerns are easier to voice here.")
	_add_room(gs, "mediation_room", "Mediation Room", "mediation", 2, Rect2(8, 0, 4, 3), ["Mediator", "Counselor"],
		"Formal conflict resolution. Hard conversations are held here on neutral ground.")
	_add_room(gs, "break_room", "Break Room", "break", 5, Rect2(0, 4, 4, 3), [],
		"Short recovery and casual conversation. Friendships and gossip both start here.")
	_add_room(gs, "employee_lounge", "Employee Lounge", "lounge", 4, Rect2(4, 4, 5, 3), [],
		"A quieter space for longer decompression and the occasional unexpected conversation.")
	var locked := RoomState.new()
	locked.id = "restricted_1"
	locked.display_name = "Restricted"
	locked.function = "locked"
	locked.art_key = "restricted"
	locked.capacity = 1
	locked.grid_rect = Rect2(9, 4, 3, 3)
	locked.unlocked = false
	locked.discovered = false
	locked.description = "Access denied."
	gs.rooms[locked.id] = locked

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var brandy := EmployeeState.new()
	brandy.id = "brandy"
	brandy.display_name = "Brandy"
	brandy.role = "Coordinator"
	brandy.is_named = true
	brandy.player_assignable = false
	brandy.sprite_key = "brandy"
	brandy.tint_html = "85BAEA"
	brandy.competence = 90.0
	brandy.bio = "Cheerful, warm, and unfailingly friendly to new hires. Considerably higher in the company than her manner suggests. Your guide in IES."
	brandy.traits.merge({"empathy": 92.0, "sociability": 88.0, "patience": 85.0, "conscientiousness": 75.0, "anxiety": 15.0, "work_ethic": 80.0}, true)
	brandy.assignment_room = "ies_office"
	brandy.break_at = 720
	brandy.needs["morale"] = 90.0
	gs.employees[brandy.id] = brandy

	var wren := EmployeeState.new()
	wren.id = "wren"
	wren.display_name = "Wren Calloway"
	wren.role = "Counselor"
	wren.is_named = true
	wren.sprite_key = "wren"
	wren.tint_html = "A3A58E"
	wren.competence = 68.0
	wren.bio = "[PLACEHOLDER NAMED EMPLOYEE] Quiet, observant, takes things personally. Reserved for the day 3-5 relationship / event chain."
	wren.traits.merge({"empathy": 80.0, "sensitivity": 82.0, "anxiety": 62.0, "sociability": 35.0}, true)
	gs.employees[wren.id] = wren

	for i in range(1, 10):
		var e := EmployeeState.generate(rng, i)
		gs.employees[e.id] = e
	# Ensure generated names are unique
	var seen: Dictionary = {}
	for id in gs.employees.keys():
		var e: EmployeeState = gs.employees[id]
		if seen.has(e.display_name):
			e.display_name += " Jr."
		seen[e.display_name] = true
	SimulationKernel.update_locations(gs.employees, gs.rooms, Workday.DAY_START)


static func _add_room(gs: Node, id: String, display_name: String, function_key: String, capacity: int, rect: Rect2, roles: Array, description: String) -> void:
	var r := RoomState.new()
	r.id = id
	r.display_name = display_name
	r.function = function_key
	r.art_key = id
	r.capacity = capacity
	r.grid_rect = rect
	r.preferred_roles = roles
	r.description = description
	gs.rooms[id] = r


# ---------------------------------------------------------------- per-day hooks

## Runs at the start of each day BEFORE the restart snapshot, so seeded state persists across restarts.
static func prepare_day(day: int, gs: Node) -> void:
	if day == 3 and not gs.narrative_flags.has("day3_seeded"):
		gs.narrative_flags["day3_seeded"] = true
		var a: EmployeeState = gs.get_employee("gen_01")
		var b: EmployeeState = gs.get_employee("gen_02")
		if a != null and b != null:
			a.set_rel(b.id, -35.0, 5.0)
			b.set_rel(a.id, -35.0, 5.0)
			a.add_memory(3, "Had words with %s over a missed handoff." % b.display_name)
			b.add_memory(3, "Had words with %s over a missed handoff." % a.display_name)
		var c: EmployeeState = gs.get_employee("gen_03")
		var d: EmployeeState = gs.get_employee("gen_04")
		if c != null and d != null:
			c.set_rel(d.id, 30.0, 15.0)
			d.set_rel(c.id, 30.0, 15.0)


static func on_day_finalized(day: int, gs: Node, report: Dictionary) -> void:
	var brandy: EmployeeState = gs.get_employee("brandy")
	if brandy != null:
		brandy.add_memory(day, "Watched the new hire run Day %d (grade %s)." % [day, report.get("grade", "?")])
	if day == 1:
		gs.add_record("ies_overview", "IES: Departmental Overview", "Interactions & Employee Satisfaction coordinates employee scheduling, welfare and conflict resolution across the company. Staff are encouraged to treat the department as a first point of contact for anything that is not strictly operational.")
	elif day == 3:
		gs.add_record("ies_dynamics", "Memo: On Working Relationships", "A good colleague is not always a good friend, and a good friend is not always a good colleague. Assign accordingly.")
	elif day == 5:
		gs.add_record("ies_requests", "Memo: Interdepartmental Favours", "IES is frequently asked to lend staff. Doing so builds goodwill. Refusing too often is also noted.")
	gs.player["experience_days"] = int(gs.player.get("experience_days", 0)) + 1


static func completion_rewards(gs: Node, report: Dictionary) -> void:
	var certs: Array = gs.player.get("certifications", [])
	if not certs.has("IES"):
		certs.append("IES")
	gs.player["certifications"] = certs
	gs.player["authority"] = int(gs.player.get("authority", 0)) + 1
	gs.player["clearance"] = int(gs.player.get("clearance", 0)) + 1
	gs.player["institutional_knowledge"] = int(gs.player.get("institutional_knowledge", 0)) + 1
	var total := 0.0
	for h in gs.dept().history:
		total += float(h.get("performance", 0.0))
	var avg := total / maxf(1.0, float(gs.dept().history.size()))
	var rel := "impressed" if avg >= 0.95 else ("supportive" if avg >= 0.7 else "concerned")
	gs.narrative_flags["brandy_relationship"] = rel
	gs.narrative_flags["ies_final_grade"] = str(report.get("grade", "C"))
	gs.add_record("ies_certification", "IES Certification Record", "Certified to oversee Interactions & Employee Satisfaction. Evaluating manager's note: Brandy appears %s." % rel)
	gs.add_record("company_map_prelim", "Company Map (Preliminary)", "Further departments are now visible on the company map: Facilities & Infrastructure, Personnel / Human Resources. Their doors are not yet open.")


static func brandy_comment(day: int, grade: String) -> String:
	var tone := {"A": "Well, that went beautifully.", "B": "That was a good day, sugar.", "C": "Rough edges, but you'll get there.", "D": "Hard day. We all have them."}
	var base: String = tone.get(grade, "")
	match day:
		1: return base + " Next we'll look at how folks wear down."
		2: return base + " Mind how much you ask of people. Next, we'll look at who works well together."
		3: return base + " Tomorrow, things start happening that you can't predict."
		4: return base + " You can't fix everything. Tomorrow someone will want something from us."
		5: return base + " Tomorrow's your evaluation. I won't be helping, you understand."
		6: return base + " I think you're ready for more than this office."
	return base


# ---------------------------------------------------------------- tutorial

static func tutorial_steps(day: int) -> Array:
	match day:
		1:
			return [
				{"text": "Well, hey there! Come on in, don't be shy. I'm Brandy, and I'll be showing you around IES.", "wait": "next"},
				{"text": "This is our floor. Each block is a room. Go on and click the [b]IES Office[/b].", "wait": "room_selected", "highlight": "facility"},
				{"text": "Art on the left, records on the right. Everything about a room lives over there. Now click one of the [b]people[/b] on the left of the screen.", "wait": "employee_selected", "highlight": "roster"},
				{"text": "Use the [b]Assignment[/b] box to put them to work. Anyone with no assignment is just standing in the hall. Get at least a few folks into the office.", "wait": "employee_assigned", "highlight": "database"},
				{"text": "That's the idea. Assign a few more, then press [b]Start Shift[/b] up top when you're ready.", "wait": "shift_started", "highlight": "topbar_start"},
				{"text": "There we go. You can pause any time. Keep an eye on the clock, and the day's task total once it's over.", "wait": "next"},
			]
		2:
			return [
				{"text": "Folks wear down, sugar. You can see [b]Fatigue[/b] and [b]Stress[/b] now.", "wait": "next"},
				{"text": "Pick someone and set a [b]Break[/b] time. People recover in the Break Room, and the Lounge helps too.", "wait": "break_set", "highlight": "database"},
				{"text": "Employee satisfaction is partly just logistics. Start the shift when you're ready.", "wait": "shift_started", "highlight": "topbar_start"},
			]
		3:
			return [
				{"text": "People aren't interchangeable. Take a look at a person's [b]Relationships[/b] and personality.", "wait": "employee_selected", "highlight": "database"},
				{"text": "Some folks work well together and some really don't. Think about who shares a room.", "wait": "next"},
			]
		4:
			return [
				{"text": "Things happen here. The [b]tray along the bottom[/b] shows problems that need someone's attention.", "wait": "next", "highlight": "tray"},
				{"text": "Handle what you can. Don't try to fix everything, honey. I won't be fixing it for you.", "wait": "next"},
			]
		5:
			return [
				{"text": "Other departments will start asking IES for help. You're a colleague now, not a trainee.", "wait": "next"},
			]
		6:
			return [
				{"text": "Today's your evaluation. I'm going to stand back and watch.", "wait": "next"},
			]
	return []
