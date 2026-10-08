class_name RoomArtView
extends Control
## Draws one room: real art from res://art/rooms/<art_key>.* when available, otherwise a procedural
## placeholder, plus every employee currently present (real sprite or placeholder figure).
## In full (non-thumbnail) mode people are clickable and idle-bob. room_id == GameState.HALL_ID draws the hall.

signal employee_clicked(employee_id: String)

var room_id := ""
var thumbnail := false
var selected_employee_id := ""

var _t := 0.0
var _hit: Array = []      # [{"id": String, "rect": Rect2}]
var _hover_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if thumbnail else Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(not thumbnail)
	GameState.state_changed.connect(queue_redraw)


func set_room(id: String) -> void:
	room_id = id
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if thumbnail:
		return
	if event is InputEventMouseMotion:
		var h := _id_at(event.position)
		if h != _hover_id:
			_hover_id = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var h := _id_at(event.position)
		if h != "":
			employee_clicked.emit(h)


func _id_at(p: Vector2) -> String:
	for i in range(_hit.size() - 1, -1, -1):
		if (_hit[i]["rect"] as Rect2).has_point(p):
			return str(_hit[i]["id"])
	return ""


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var is_hall := room_id == GameState.HALL_ID
	var room: RoomState = null if is_hall else GameState.get_room(room_id)
	var fn := "hall" if is_hall or room == null else room.function
	var tex: Texture2D = ArtLoader.room("hall") if is_hall else (ArtLoader.room(room.art_key) if room != null else null)
	if tex != null:
		draw_texture_rect(tex, rect, false)
	else:
		_draw_placeholder(rect, fn, room)
	_draw_occupants(rect, is_hall)


# ---------------------------------------------------------------- placeholder room

func _draw_placeholder(rect: Rect2, fn: String, room: RoomState) -> void:
	var base := Palette.room_tint(fn)
	var wall_h := rect.size.y * 0.62
	draw_rect(Rect2(0, 0, rect.size.x, wall_h), base.darkened(0.35))
	draw_rect(Rect2(0, wall_h, rect.size.x, rect.size.y - wall_h), base.darkened(0.62))
	draw_rect(Rect2(0, wall_h - 3, rect.size.x, 3), base.lightened(0.1))
	# perspective floor lines
	for i in range(1, 8):
		var x := rect.size.x * float(i) / 8.0
		var vx := rect.size.x * 0.5 + (x - rect.size.x * 0.5) * 1.8
		draw_line(Vector2(x, wall_h), Vector2(vx, rect.size.y), base.darkened(0.45), 1.0)
	var w := rect.size.x
	var fl := wall_h
	match fn:
		"office":
			var n := 4
			for i in n:
				var x := w * (0.08 + 0.22 * i)
				draw_rect(Rect2(x, fl - rect.size.y * 0.16, w * 0.16, rect.size.y * 0.16), base.lightened(0.15))
				draw_rect(Rect2(x + w * 0.05, fl - rect.size.y * 0.27, w * 0.06, rect.size.y * 0.1), Palette.SKY.darkened(0.3))
			draw_rect(Rect2(w * 0.86, fl - rect.size.y * 0.5, w * 0.1, rect.size.y * 0.5), Palette.INK)  # filing cabinet
		"break":
			draw_rect(Rect2(w * 0.05, fl - rect.size.y * 0.42, w * 0.14, rect.size.y * 0.42), Palette.BLOOD)       # vending machine
			draw_rect(Rect2(w * 0.38, fl - rect.size.y * 0.1, w * 0.26, rect.size.y * 0.1), base.lightened(0.2))  # table
			draw_rect(Rect2(w * 0.74, fl - rect.size.y * 0.2, w * 0.22, rect.size.y * 0.2), base.lightened(0.1))  # counter
		"lounge":
			draw_rect(Rect2(w * 0.1, fl - rect.size.y * 0.14, w * 0.3, rect.size.y * 0.14), Palette.SLATE.lightened(0.1))
			draw_rect(Rect2(w * 0.55, fl - rect.size.y * 0.14, w * 0.3, rect.size.y * 0.14), Palette.SLATE.lightened(0.1))
			draw_circle(Vector2(w * 0.93, fl - rect.size.y * 0.1), rect.size.y * 0.09, Palette.MOSS)
		"interview":
			draw_rect(Rect2(w * 0.3, fl - rect.size.y * 0.1, w * 0.4, rect.size.y * 0.1), base.lightened(0.2))
			draw_rect(Rect2(w * 0.1, fl - rect.size.y * 0.16, w * 0.12, rect.size.y * 0.16), Palette.MOSS)
			draw_rect(Rect2(w * 0.78, fl - rect.size.y * 0.16, w * 0.12, rect.size.y * 0.16), Palette.MOSS)
		"mediation":
			draw_rect(Rect2(w * 0.15, fl - rect.size.y * 0.1, w * 0.7, rect.size.y * 0.1), base.lightened(0.2))
			for i in 4:
				draw_rect(Rect2(w * (0.2 + 0.18 * i), fl - rect.size.y * 0.2, w * 0.08, rect.size.y * 0.1), Palette.MOSS)
		"locked":
			for i in range(-int(rect.size.y), int(rect.size.x), 18):
				draw_line(Vector2(i, rect.size.y), Vector2(i + rect.size.y, 0), Palette.SLATE, 2.0)
		"hall":
			for i in 5:
				draw_rect(Rect2(w * (0.06 + 0.2 * i), fl - rect.size.y * 0.5, w * 0.08, rect.size.y * 0.5), Palette.INK_DEEP)
				draw_rect(Rect2(w * (0.06 + 0.2 * i) + w * 0.03, fl - rect.size.y * 0.58, w * 0.02, rect.size.y * 0.03), Palette.ALERT)
	if not thumbnail:
		var font := ThemeDB.fallback_font
		var key := room.art_key if room != null else "hall"
		draw_string(font, Vector2(14, rect.size.y - 12), "PLACEHOLDER ART  -  res://art/rooms/%s.png" % key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.TEXT_DIM)


# ---------------------------------------------------------------- people

func _draw_occupants(rect: Rect2, is_hall: bool) -> void:
	_hit.clear()
	var people: Array = GameState.employees_in_room(room_id)
	if people.is_empty():
		return
	var n := people.size()
	var floor_y := rect.size.y * (0.9 if is_hall else 0.86)
	var h := rect.size.y * (0.72 if is_hall else (0.36 if thumbnail else 0.42))
	var show_stress := GameState.is_revealed("stress")
	var font := ThemeDB.fallback_font
	for i in n:
		var e: EmployeeState = people[i]
		var x := rect.size.x * float(i + 1) / float(n + 1)
		var bob := 0.0 if thumbnail else sin(_t * 2.0 + float(i) * 1.7) * 2.0
		var feet := Vector2(x, floor_y + bob)
		var tex := ArtLoader.employee(e.sprite_key)
		var body_w := h * 0.36
		if tex != null:
			var tw := h * float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
			draw_texture_rect(tex, Rect2(feet.x - tw * 0.5, feet.y - h, tw, h), false)
			body_w = tw
		else:
			_draw_figure(feet, h, e.tint())
		_hit.append({"id": e.id, "rect": Rect2(feet.x - body_w * 0.6, feet.y - h * 1.05, body_w * 1.2, h * 1.1)})
		if show_stress and e.need("stress") >= 70.0:
			draw_circle(feet + Vector2(0, -h * 1.1), maxf(3.0, h * 0.06), Palette.ALERT)
		elif show_stress and e.need("fatigue") >= 75.0:
			draw_circle(feet + Vector2(0, -h * 1.1), maxf(3.0, h * 0.06), Palette.MOSS)
		if not thumbnail:
			if e.id == selected_employee_id:
				draw_rect(Rect2(feet.x - body_w * 0.8, feet.y + 2, body_w * 1.6, 3), Palette.SKY)
			elif e.id == _hover_id:
				draw_rect(Rect2(feet.x - body_w * 0.8, feet.y + 2, body_w * 1.6, 2), Palette.TEXT_DIM)
			draw_string(font, Vector2(feet.x - 60, feet.y + 20), e.display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Palette.TEXT)


func _draw_figure(feet: Vector2, h: float, tint: Color) -> void:
	var w := h * 0.36
	draw_circle(feet + Vector2(0, -h * 0.07), h * 0.05, Color(0, 0, 0, 0.25))  # shadow
	draw_rect(Rect2(feet.x - w * 0.5, feet.y - h * 0.62, w, h * 0.62), tint.darkened(0.15))
	draw_rect(Rect2(feet.x - w * 0.5, feet.y - h * 0.62, w, h * 0.12), tint.lightened(0.1))
	draw_circle(feet + Vector2(0, -h * 0.76), h * 0.14, tint.lightened(0.3))
