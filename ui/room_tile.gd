class_name RoomTile
extends Control
## One clickable room on the facility map: thumbnail art + name strip + occupancy + status border.

signal pressed(room_id: String)

var room_id := ""
var selected := false:
	set(v):
		selected = v
		if _overlay != null:
			_overlay.queue_redraw()

var _art: RoomArtView
var _overlay: Control
var _hover := false
var _pulse := 0.0


func setup(id: String) -> void:
	room_id = id


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_art = RoomArtView.new()
	_art.thumbnail = true
	_art.room_id = room_id
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_art)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	mouse_entered.connect(func() -> void:
		_hover = true
		_overlay.queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_overlay.queue_redraw())
	GameState.state_changed.connect(_overlay.queue_redraw)


func _process(delta: float) -> void:
	if Incidents.has_incident_in_room(room_id):
		_pulse += delta
		_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var room := GameState.get_room(room_id)
		if room_id == GameState.HALL_ID or (room != null and room.unlocked):
			pressed.emit(room_id)


func _draw_overlay() -> void:
	var room := GameState.get_room(room_id)
	var locked := room != null and not room.unlocked
	var font := ThemeDB.fallback_font
	var strip := Rect2(0, 0, _overlay.size.x, 24)
	_overlay.draw_rect(strip, Color(Palette.INK_DEEP, 0.88))
	var title := "RESTRICTED" if locked else GameState.room_name(room_id).to_upper()
	if room_id == GameState.HALL_ID:
		title = "HALL / UNASSIGNED"
	_overlay.draw_string(font, Vector2(8, 17), title, HORIZONTAL_ALIGNMENT_LEFT, _overlay.size.x - 60, 13, Palette.TEXT_DIM if locked else Palette.TEXT)
	if room != null and not locked:
		var here := GameState.employees_in_room(room_id).size()
		_overlay.draw_string(font, Vector2(_overlay.size.x - 52, 17), "%d/%d" % [here, room.capacity], HORIZONTAL_ALIGNMENT_RIGHT, 44, 13, Palette.SKY)
	var border := Palette.SLATE
	var width := 2.0
	if _hover and not locked:
		border = Palette.SKY
	if selected:
		border = Palette.SKY
		width = 4.0
	if Incidents.has_incident_in_room(room_id):
		var a := 0.55 + 0.45 * sin(_pulse * 6.0)
		border = Palette.ALERT.lerp(Palette.BLOOD, 1.0 - a)
		width = 4.0
	_overlay.draw_rect(Rect2(Vector2.ZERO, _overlay.size), border, false, width)
	if room != null and not locked and GameState.is_revealed("room_condition") and room.min_condition() < 35.0:
		_overlay.draw_rect(Rect2(_overlay.size.x - 24, _overlay.size.y - 24, 20, 20), Palette.BLOOD)
		_overlay.draw_string(font, Vector2(_overlay.size.x - 18, _overlay.size.y - 8), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.TEXT)
