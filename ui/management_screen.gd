class_name ManagementScreen
extends Control
## The main play screen: top bar, staff roster, facility map / room detail, log + incident tray,
## and modals (briefing, incident, day report, completion). Holds only UI state (selection);
## all authoritative state lives in GameState / Workday / Incidents.

signal navigate(screen: String)

const PHASE_NAMES := ["--", "BRIEFING", "PREPARATION", "ACTIVE SHIFT", "PAUSED", "INCIDENT", "DAY REVIEW", "DAY COMPLETE"]

var _day_label: Label
var _phase_label: Label
var _clock_label: Label
var _budget_label: Label
var _btn_primary: Button
var _btn_pause: Button
var _btn_restart: Button
var _speed_box: HBoxContainer
var _roster: RosterPanel
var _facility: FacilityView
var _detail: RoomDetailView
var _center: Control
var _log: RichTextLabel
var _log_lines := 0
var _tray: HBoxContainer
var _tray_panel: PanelContainer
var _coach: CoachPanel
var _highlight: Panel
var _hl_tween: Tween
var _selected_room := ""
var _selected_emp := ""
var _modal: ModalCard = null


func _ready() -> void:
	if not GameState.campaign_active:
		navigate.emit.call_deferred("menu")
		return
	var bg := ColorRect.new()
	bg.color = Palette.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_ui()
	_connect_signals()
	Workday.begin_day()
	_refresh_controls()
	_open_briefing()


func _exit_tree() -> void:
	Workday.halt()
	Tutorial.skip_day()


# ---------------------------------------------------------------- construction

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	root.add_child(_build_topbar())

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	root.add_child(mid)
	_roster = RosterPanel.new()
	_roster.custom_minimum_size = Vector2(270, 0)
	_roster.employee_selected.connect(_select_employee)
	mid.add_child(_roster)

	_center = Control.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_center)
	_facility = FacilityView.new()
	_facility.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_facility.room_selected.connect(_on_room_selected)
	_center.add_child(_facility)
	_detail = RoomDetailView.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.visible = false
	_detail.back_pressed.connect(_on_back)
	_detail.employee_clicked.connect(_select_employee)
	_center.add_child(_detail)
	_coach = CoachPanel.new()
	_coach.anchor_left = 0.5
	_coach.anchor_right = 0.5
	_coach.anchor_top = 1.0
	_coach.anchor_bottom = 1.0
	_coach.offset_bottom = -14.0
	_coach.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_coach.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coach.next_pressed.connect(func() -> void: Tutorial.next_pressed())
	_coach.skip_pressed.connect(func() -> void: Tutorial.skip_day())
	_center.add_child(_coach)

	root.add_child(_build_bottom())

	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.visible = false
	_highlight.add_theme_stylebox_override("panel", ThemeFactory.box(Color.TRANSPARENT, Palette.ALERT, 3, 3, 0))
	add_child(_highlight)


func _build_topbar() -> Control:
	var p := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	_day_label = Label.new()
	_day_label.add_theme_font_size_override("font_size", 20)
	_day_label.add_theme_color_override("font_color", Palette.SKY)
	h.add_child(_day_label)
	_phase_label = Label.new()
	_phase_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	h.add_child(_phase_label)
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 28)
	h.add_child(_clock_label)
	_budget_label = Label.new()
	_budget_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	h.add_child(_budget_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	_btn_primary = Button.new()
	_btn_primary.custom_minimum_size = Vector2(140, 0)
	_btn_primary.pressed.connect(_on_primary)
	h.add_child(_btn_primary)
	_btn_pause = Button.new()
	_btn_pause.text = "Pause"
	_btn_pause.pressed.connect(func() -> void: Workday.toggle_pause())
	h.add_child(_btn_pause)
	_speed_box = HBoxContainer.new()
	var group := ButtonGroup.new()
	for s in [1, 2, 4]:
		var b := Button.new()
		b.text = "%dx" % s
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (s == 1)
		b.pressed.connect(func() -> void: Workday.speed_multiplier = float(s))
		_speed_box.add_child(b)
	h.add_child(_speed_box)
	_btn_restart = Button.new()
	_btn_restart.text = "Restart Day"
	_btn_restart.pressed.connect(_on_restart)
	h.add_child(_btn_restart)
	var menu := Button.new()
	menu.text = "Menu"
	menu.pressed.connect(_on_menu)
	h.add_child(menu)
	return p


func _build_bottom() -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 130)
	h.add_theme_constant_override("separation", 8)
	var lp := PanelContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp.add_child(_log)
	h.add_child(lp)
	_tray_panel = PanelContainer.new()
	_tray_panel.custom_minimum_size = Vector2(440, 0)
	var tv := VBoxContainer.new()
	var tl := Label.new()
	tl.text = "INCIDENTS"
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", Palette.MOSS.lightened(0.3))
	tv.add_child(tl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tray = HBoxContainer.new()
	scroll.add_child(_tray)
	tv.add_child(scroll)
	_tray_panel.add_child(tv)
	h.add_child(_tray_panel)
	return h


func _connect_signals() -> void:
	Workday.phase_changed.connect(_on_phase_changed)
	Workday.clock_changed.connect(_on_clock)
	Workday.day_finalized.connect(_on_day_finalized)
	GameState.state_changed.connect(_refresh_labels)
	GameState.log_posted.connect(_on_log)
	Incidents.incident_added.connect(_on_incident_added)
	Incidents.incidents_changed.connect(_rebuild_tray)
	Tutorial.step_changed.connect(func(step: Dictionary) -> void: _coach.show_step(step))
	Tutorial.highlight_requested.connect(_on_highlight)


# ---------------------------------------------------------------- top bar / phase

func _refresh_labels() -> void:
	var d := GameState.dept()
	if d != null:
		_day_label.text = "IES  -  DAY %d / %d" % [d.current_day, d.required_days]
	_clock_label.text = Workday.format_clock(Workday.minute)
	_budget_label.visible = GameState.is_revealed("incidents_panel")
	_budget_label.text = "Budget  %d" % roundi(float(GameState.resources.get("budget", 0.0)))
	_speed_box.visible = GameState.is_revealed("speed_controls")


func _on_clock(_m: int) -> void:
	_clock_label.text = Workday.format_clock(Workday.minute)


func _on_phase_changed(_p: int) -> void:
	_refresh_controls()
	if Workday.phase == Workday.Phase.DAY_REVIEW:
		_open_report()


func _refresh_controls() -> void:
	var p: int = Workday.phase
	_phase_label.text = PHASE_NAMES[clampi(p, 0, PHASE_NAMES.size() - 1)]
	if p == Workday.Phase.DAY_REVIEW:
		_btn_primary.text = "Day Report"
		_btn_primary.disabled = false
	else:
		_btn_primary.text = "Start Shift"
		_btn_primary.disabled = p != Workday.Phase.PREPARATION
	_btn_pause.disabled = p != Workday.Phase.ACTIVE and p != Workday.Phase.PAUSED
	_btn_pause.text = "Resume" if p == Workday.Phase.PAUSED else "Pause"
	var can_restart: bool = p == Workday.Phase.PREPARATION or p == Workday.Phase.ACTIVE or p == Workday.Phase.PAUSED or p == Workday.Phase.INCIDENT_RESPONSE or p == Workday.Phase.DAY_REVIEW
	_btn_restart.disabled = not can_restart
	_refresh_labels()


func _on_primary() -> void:
	match Workday.phase:
		Workday.Phase.PREPARATION:
			Workday.start_shift()
		Workday.Phase.DAY_REVIEW:
			_open_report()


func _on_restart() -> void:
	if _modal != null:
		return
	var m := ModalCard.create("Restart this day?", "The department returns to exactly how it was at the start of the day. Nothing from this attempt is kept.", [{"label": "Restart Day"}, {"label": "Cancel"}], 480.0)
	_show_modal(m)
	m.choice_made.connect(func(i: int) -> void:
		_close_modal()
		if i == 0:
			Workday.restart_day()
			_after_restore())


func _after_restore() -> void:
	_on_back()
	_roster.refresh()
	_rebuild_tray()
	_refresh_controls()
	GameState.post_log("Day restarted from the beginning.", 1)


func _on_menu() -> void:
	if _modal != null:
		return
	var m := ModalCard.create("Leave to main menu?", "Progress from this day is lost. You will resume at the start of Day %d." % GameState.current_day(), [{"label": "Leave"}, {"label": "Stay"}], 480.0)
	_show_modal(m)
	m.choice_made.connect(func(i: int) -> void:
		_close_modal()
		if i == 0:
			navigate.emit("menu"))


# ---------------------------------------------------------------- selection

func _on_room_selected(id: String) -> void:
	_show_room(id)
	GameState.game_event.emit("room_selected", {"room_id": id})


func _show_room(id: String) -> void:
	_selected_room = id
	_facility.set_selected(id)
	_detail.set_room(id)
	if _selected_emp != "":
		_detail.set_selected_employee(_selected_emp)
	_detail.visible = true
	_facility.visible = false
	_detail.database.employee_requested.connect(_select_employee, CONNECT_REFERENCE_COUNTED)


func _on_back() -> void:
	_selected_room = ""
	_detail.visible = false
	_facility.visible = true
	_facility.set_selected("")


func _select_employee(id: String) -> void:
	var e := GameState.get_employee(id)
	if e == null:
		return
	_selected_emp = id
	_roster.set_selected(id)
	var target := e.location_room
	if target == "" or target == SimulationKernel.OFFSITE:
		target = GameState.HALL_ID
	if not _detail.visible or _selected_room != target:
		_show_room(target)
	_detail.database.show_employee(id)
	_detail.set_selected_employee(id)
	GameState.game_event.emit("employee_selected", {"employee_id": id})


# ---------------------------------------------------------------- log + incidents

func _on_log(text: String, severity: int) -> void:
	var color := "#E4ECEE"
	if severity == 1:
		color = "#A3A58E"
	elif severity >= 2:
		color = "#EB271C"
	_log.append_text("[color=#94A8AC][%s][/color] [color=%s]%s[/color]\n" % [Workday.format_clock(Workday.minute), color, text])
	_log_lines += 1
	if _log_lines > 150:
		_log.clear()
		_log_lines = 0


func _rebuild_tray() -> void:
	if _tray == null:
		return
	for c in _tray.get_children():
		c.queue_free()
	if Incidents.active.is_empty():
		var l := Label.new()
		l.text = "All quiet." if Incidents.enabled() else "No incident reports."
		l.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_tray.add_child(l)
		return
	for inc in Incidents.active:
		var incident: Dictionary = inc
		var b := Button.new()
		b.text = "%s  (by %s)" % [incident["title"], Workday.format_clock(int(incident["deadline"]))]
		var sev := int(incident["severity"])
		b.add_theme_stylebox_override("normal", ThemeFactory.box(Palette.BLOOD if sev >= 1 else Palette.PANEL_LIGHT, Palette.ALERT if sev >= 1 else Palette.SLATE, 2, 2, 8))
		b.pressed.connect(func() -> void: _open_incident(int(incident["uid"])))
		_tray.add_child(b)


func _on_incident_added(inc: Dictionary) -> void:
	if bool(inc.get("pause", false)) and _modal == null:
		_open_incident(int(inc["uid"]))


func _open_incident(uid: int) -> void:
	if _modal != null:
		return
	var inc := Incidents.find(uid)
	if inc.is_empty():
		return
	var choices: Array = []
	for r in inc["responses"]:
		choices.append({"label": str(r.get("label", "?")), "tip": str(r.get("tip", ""))})
	choices.append({"label": "Decide later"})
	var body := "%s\n\n[color=#94A8AC]Respond by %s.[/color]" % [inc["text"], Workday.format_clock(int(inc["deadline"]))]
	var m := ModalCard.create(str(inc["title"]), body, choices, 600.0)
	_show_modal(m)
	GameState.game_event.emit("incident_opened", {"uid": uid})
	m.choice_made.connect(func(i: int) -> void:
		_close_modal()
		if i < (inc["responses"] as Array).size():
			Incidents.resolve(uid, i)
		else:
			Incidents.release_pause(uid))


# ---------------------------------------------------------------- modals

func _show_modal(m: ModalCard) -> void:
	_modal = m
	add_child(m)


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


func _open_briefing() -> void:
	_close_modal()
	var day := GameState.current_day()
	var def := IESContent.day_def(day)
	var lines: Array = []
	for l in def["brief"]:
		lines.append(str(l))
	var body := "[b]Day %d: %s[/b]\n\n%s\n\n[color=#94A8AC]Target: %d tasks completed.[/color]" % [day, def["title"], "\n\n".join(PackedStringArray(lines)), int(def["demand"])]
	var m := ModalCard.create("Morning Briefing", body, [{"label": "Begin"}], 620.0)
	_show_modal(m)
	m.choice_made.connect(func(_i: int) -> void:
		_close_modal()
		Workday.advance_from_briefing()
		GameState.game_event.emit("briefing_closed", {})
		Tutorial.start_day(day))


func _open_report() -> void:
	if _modal != null or Workday.phase != Workday.Phase.DAY_REVIEW:
		return
	var r := Workday.last_report
	var lines: Array = []
	for l in r.get("lines", []):
		lines.append(str(l))
	var body := "[b]Grade: %s[/b]\n\n%s\n\n[i]\"%s\"[/i]  - Brandy" % [r.get("grade", "?"), "\n".join(PackedStringArray(lines)), r.get("brandy", "")]
	var m := ModalCard.create("Day %d Report" % int(r.get("day", 1)), body, [{"label": "Finalize Day"}, {"label": "Look around first"}], 620.0)
	_show_modal(m)
	m.choice_made.connect(func(i: int) -> void:
		_close_modal()
		if i == 0:
			Workday.finalize_day())


func _on_day_finalized(report: Dictionary) -> void:
	_close_modal()
	_refresh_controls()
	if bool(report.get("completed", false)):
		var p := GameState.player
		var body := "You are now certified to oversee Interactions & Employee Satisfaction.\n\n[b]Authority[/b] %d    [b]Clearance[/b] %d    [b]Institutional knowledge[/b] %d\n\nBrandy appears %s.\n\nNew entries are available in the Database. Further departments are visible on the company map, but their doors are not yet open." % [int(p.get("authority", 0)), int(p.get("clearance", 0)), int(p.get("institutional_knowledge", 0)), GameState.narrative_flags.get("brandy_relationship", "pleased")]
		var m := ModalCard.create("IES Certified", body, [{"label": "Return to Main Menu"}], 620.0)
		_show_modal(m)
		m.choice_made.connect(func(_i: int) -> void:
			_close_modal()
			navigate.emit("menu"))
	else:
		var body2 := "Day %d finalized with grade %s. Progress has been saved." % [int(report.get("day", 1)), report.get("grade", "?")]
		var m2 := ModalCard.create("Day Complete", body2, [{"label": "Continue to Day %d" % GameState.current_day()}, {"label": "Return to Main Menu"}], 520.0)
		_show_modal(m2)
		m2.choice_made.connect(func(i: int) -> void:
			_close_modal()
			if i == 0:
				_on_back()
				Workday.begin_day()
				_roster.refresh()
				_refresh_controls()
				_open_briefing()
			else:
				navigate.emit("menu"))


# ---------------------------------------------------------------- tutorial highlight

func _on_highlight(target: String) -> void:
	if _hl_tween != null:
		_hl_tween.kill()
	if target == "":
		_highlight.visible = false
		return
	var node: Control = null
	match target:
		"roster":
			node = _roster
		"facility":
			node = _facility if _facility.visible else _detail
		"topbar_start":
			node = _btn_primary
		"database":
			node = _detail.database if _detail.visible else _facility
		"tray":
			node = _tray_panel
	if node == null:
		_highlight.visible = false
		return
	await get_tree().process_frame
	if not is_instance_valid(node) or not is_inside_tree():
		return
	var r := node.get_global_rect()
	_highlight.global_position = r.position - Vector2(3, 3)
	_highlight.size = r.size + Vector2(6, 6)
	_highlight.modulate.a = 1.0
	_highlight.visible = true
	_hl_tween = create_tween().set_loops()
	_hl_tween.tween_property(_highlight, "modulate:a", 0.25, 0.7)
	_hl_tween.tween_property(_highlight, "modulate:a", 1.0, 0.7)
