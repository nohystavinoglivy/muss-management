extends Node
## Autoload "Workday" - the WorkdayManager: day state machine, simulation clock,
## snapshot/restart, finalization. Simulation time only; pausing freezes everything.

signal phase_changed(phase: int)
signal clock_changed(minute: int)
signal day_finalized(report: Dictionary)
signal department_completed(dept_id: String)

enum Phase { NOT_STARTED, BRIEFING, PREPARATION, ACTIVE, PAUSED, INCIDENT_RESPONSE, DAY_REVIEW, FINALIZED }

const DAY_START := 480  # 08:00
const DAY_END := 960    # 16:00
const SECONDS_PER_MINUTE := 0.25
const MAX_TICKS_PER_FRAME := 40

var phase: int = Phase.NOT_STARTED
var minute: int = DAY_START
var speed_multiplier := 1.0
var day_stats: Dictionary = SimulationKernel.new_stats()
var last_report: Dictionary = {}

var _resume_phase: int = Phase.ACTIVE
var _snapshot: Dictionary = {}
var _accum := 0.0
var _rng := RandomNumberGenerator.new()


static func format_clock(m: int) -> String:
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


# ---------------------------------------------------------------- day flow

func begin_day() -> void:
	if not GameState.campaign_active:
		return
	var day := GameState.current_day()
	IESContent.prepare_day(day, GameState)   # persistent seeding happens BEFORE the snapshot
	for rid in GameState.rooms.keys():
		(GameState.rooms[rid] as RoomState).output_today = 0.0
	minute = DAY_START
	day_stats = SimulationKernel.new_stats()
	last_report = {}
	_accum = 0.0
	_rng.seed = hash([GameState.rng_seed, day])
	SimulationKernel.update_locations(GameState.employees, GameState.rooms, minute)
	_snapshot = GameState.serialize()
	Incidents.prepare_day(day)
	_set_phase(Phase.BRIEFING)
	clock_changed.emit(minute)
	GameState.state_changed.emit()


func advance_from_briefing() -> void:
	if phase == Phase.BRIEFING:
		_set_phase(Phase.PREPARATION)


func start_shift() -> void:
	if phase != Phase.PREPARATION:
		return
	_set_phase(Phase.ACTIVE)
	GameState.game_event.emit("shift_started", {})


func toggle_pause() -> void:
	if phase == Phase.ACTIVE:
		_set_phase(Phase.PAUSED)
		GameState.game_event.emit("shift_paused", {})
	elif phase == Phase.PAUSED:
		_set_phase(Phase.ACTIVE)


func enter_incident_response() -> void:
	if phase == Phase.ACTIVE or phase == Phase.PAUSED:
		_resume_phase = phase
		_set_phase(Phase.INCIDENT_RESPONSE)


func exit_incident_response() -> void:
	if phase == Phase.INCIDENT_RESPONSE:
		_set_phase(_resume_phase)


func finish_shift_early() -> void:
	if phase == Phase.ACTIVE or phase == Phase.PAUSED:
		_enter_review()


## Restores the complete start-of-day snapshot (never tries to reverse individual changes).
func restart_day() -> void:
	if phase == Phase.NOT_STARTED or phase == Phase.FINALIZED or phase == Phase.BRIEFING or _snapshot.is_empty():
		return
	if not GameState.deserialize(_snapshot.duplicate(true)):
		push_error("Workday.restart_day: snapshot failed to restore")
		return
	minute = DAY_START
	day_stats = SimulationKernel.new_stats()
	last_report = {}
	_accum = 0.0
	SimulationKernel.update_locations(GameState.employees, GameState.rooms, minute)
	Incidents.prepare_day(GameState.current_day())
	_set_phase(Phase.PREPARATION)
	clock_changed.emit(minute)
	GameState.game_event.emit("day_restarted", {})
	GameState.state_changed.emit()


func finalize_day() -> void:
	if phase != Phase.DAY_REVIEW:
		return
	var dep := GameState.dept()
	if dep == null:
		return
	var day := dep.current_day
	dep.history.append({"day": day, "grade": last_report.get("grade", "D"), "performance": last_report.get("performance", 0.0)})
	GameState.company_history.append({"department": dep.id, "day": day, "grade": last_report.get("grade", "D")})
	SimulationKernel.overnight(GameState.employees)
	IESContent.on_day_finalized(day, GameState, last_report)
	var completed := day >= dep.required_days
	if completed:
		dep.completed = true
		IESContent.completion_rewards(GameState, last_report)
	else:
		dep.current_day = day + 1
	GameState.save_to_disk()
	_set_phase(Phase.FINALIZED)
	var report := last_report.duplicate(true)
	report["completed"] = completed
	day_finalized.emit(report)
	if completed:
		department_completed.emit(dep.id)
	GameState.state_changed.emit()


## Called when leaving the management screen.
func halt() -> void:
	_set_phase(Phase.NOT_STARTED)


# ---------------------------------------------------------------- ticking

func _process(delta: float) -> void:
	if phase != Phase.ACTIVE:
		return
	var step := SECONDS_PER_MINUTE / maxf(0.1, speed_multiplier * float(SettingsStore.get_value("sim_speed")))
	_accum += delta
	var guard := 0
	while _accum >= step and phase == Phase.ACTIVE and guard < MAX_TICKS_PER_FRAME:
		_accum -= step
		guard += 1
		_tick()
	if guard >= MAX_TICKS_PER_FRAME:
		_accum = 0.0


func _tick() -> void:
	minute += 1
	var events := SimulationKernel.tick(GameState.employees, GameState.rooms, minute, day_stats, _rng)
	for ev in events:
		Incidents.handle_kernel_event(ev)
	Incidents.tick(minute)
	clock_changed.emit(minute)
	GameState.state_changed.emit()
	if minute >= DAY_END and phase != Phase.DAY_REVIEW:
		_enter_review()


func _enter_review() -> void:
	Incidents.expire_all()
	last_report = _build_report()
	_set_phase(Phase.DAY_REVIEW)
	GameState.game_event.emit("day_review_opened", {})


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func _build_report() -> Dictionary:
	var day := GameState.current_day()
	var def := IESContent.day_def(day)
	var demand := maxi(1, int(def.get("demand", 20)))
	var tasks := float(day_stats.get("tasks_done", 0.0))
	var perf := tasks / float(demand)
	var grade_idx := 0 if perf >= 1.0 else (1 if perf >= 0.85 else (2 if perf >= 0.65 else 3))
	var breakdowns := int(day_stats.get("breakdowns", 0))
	if breakdowns > 0 or int(day_stats.get("incidents_ignored", 0)) >= 3:
		grade_idx = mini(grade_idx + 1, 3)
	var grade: String = ["A", "B", "C", "D"][grade_idx]
	var lines: Array = []
	lines.append("Completed %d of %d requested tasks (%d%%)." % [roundi(tasks), demand, roundi(perf * 100.0)])
	var poor := 0
	var worst_name := ""
	var worst_drop := 0.0
	var snap_emp: Dictionary = _snapshot.get("employees", {})
	for id in GameState.employees.keys():
		var e: EmployeeState = GameState.employees[id]
		if e.need("stress") >= 70.0 or e.need("fatigue") >= 75.0:
			poor += 1
		if snap_emp.has(id):
			var before := float(snap_emp[id].get("needs", {}).get("morale", e.need("morale")))
			var drop := before - e.need("morale")
			if drop > worst_drop:
				worst_drop = drop
				worst_name = e.display_name
	if poor > 0:
		lines.append("%d staff finished the day in poor condition." % poor)
	if worst_drop >= 4.0:
		lines.append("Largest morale drop: %s (-%d)." % [worst_name, roundi(worst_drop)])
	var idle_hours: float = float(day_stats.get("idle_minutes", 0)) / 60.0
	if idle_hours >= 1.0:
		lines.append("%.1f staff-hours were spent unassigned." % idle_hours)
	lines.append("Incidents: %d handled, %d left unanswered." % [int(day_stats.get("incidents_resolved", 0)), int(day_stats.get("incidents_ignored", 0))])
	if breakdowns > 0:
		lines.append("%d employee breakdown(s) occurred." % breakdowns)
	return {
		"day": day, "performance": perf, "tasks": tasks, "demand": demand, "grade": grade,
		"lines": lines, "brandy": IESContent.brandy_comment(day, grade),
	}
