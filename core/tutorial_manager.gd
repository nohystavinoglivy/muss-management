extends Node
## Autoload "Tutorial" - drives Brandy's coaching steps. Steps come from IESContent.tutorial_steps(day).
## A step waits either for the player ("next") or for a GameState.game_event with a given name.

signal step_changed(step: Dictionary)   # empty dictionary = no active step
signal highlight_requested(target: String)

var steps: Array = []
var index := -1
var active := false


func _ready() -> void:
	GameState.game_event.connect(_on_game_event)


func start_day(day: int) -> void:
	steps.clear()
	index = -1
	active = false
	if not GameState.tutorial_enabled or not bool(SettingsStore.get_value("coach_hints")):
		_finish()
		return
	steps = IESContent.tutorial_steps(day).duplicate(true)
	if steps.is_empty():
		_finish()
		return
	active = true
	_advance()


func current() -> Dictionary:
	if active and index >= 0 and index < steps.size():
		return steps[index]
	return {}


func next_pressed() -> void:
	if str(current().get("wait", "next")) == "next":
		_advance()


func skip_day() -> void:
	active = false
	steps.clear()
	_finish()


func _on_game_event(event_name: String, _payload: Dictionary) -> void:
	var step := current()
	if not step.is_empty() and str(step.get("wait", "next")) == event_name:
		_advance()


func _advance() -> void:
	index += 1
	if index >= steps.size():
		active = false
		_finish()
		return
	var step: Dictionary = steps[index]
	step_changed.emit(step)
	highlight_requested.emit(str(step.get("highlight", "")))


func _finish() -> void:
	step_changed.emit({})
	highlight_requested.emit("")
