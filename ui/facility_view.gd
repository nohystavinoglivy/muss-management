class_name FacilityView
extends Control
## Lobotomy-Corporation-style cross-section: dark facility, rooms as tiles on a grid, a hall in the
## middle where unassigned staff wait. Grid size matches IESContent room rects (12 x 7).

signal room_selected(room_id: String)

const GRID_COLS := 12.0
const GRID_ROWS := 7.0
const MARGIN := 28.0
const GAP := 6.0
const HALL_ROW := 3.0

var selected_room_id := ""
var _tiles: Dictionary = {}
var _signature := ""


func _ready() -> void:
	clip_contents = true
	resized.connect(_layout)
	GameState.state_changed.connect(_ensure_tiles)
	_ensure_tiles()


func _ensure_tiles() -> void:
	var ids: Array = GameState.rooms.keys()
	ids.sort()
	var sig := ",".join(PackedStringArray(ids))
	if sig == _signature:
		return
	_signature = sig
	for t in _tiles.values():
		(t as Node).queue_free()
	_tiles.clear()
	var all_ids: Array = ids.duplicate()
	all_ids.append(GameState.HALL_ID)
	for id in all_ids:
		var tile := RoomTile.new()
		tile.setup(str(id))
		tile.pressed.connect(func(rid: String) -> void: room_selected.emit(rid))
		add_child(tile)
		_tiles[id] = tile
	_layout()


func set_selected(id: String) -> void:
	selected_room_id = id
	for rid in _tiles.keys():
		(_tiles[rid] as RoomTile).selected = (rid == id)


func _layout() -> void:
	var cw := (size.x - MARGIN * 2.0) / GRID_COLS
	var ch := (size.y - MARGIN * 2.0 - 20.0) / GRID_ROWS
	var top := MARGIN + 20.0
	for rid in _tiles.keys():
		var tile: RoomTile = _tiles[rid]
		var rect := Rect2(0, HALL_ROW, GRID_COLS, 1.0)
		if rid != GameState.HALL_ID:
			var r := GameState.get_room(str(rid))
			if r == null:
				continue
			rect = r.grid_rect
		tile.position = Vector2(MARGIN + rect.position.x * cw + GAP * 0.5, top + rect.position.y * ch + GAP * 0.5)
		tile.size = Vector2(rect.size.x * cw - GAP, rect.size.y * ch - GAP)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK_DEEP)
	var font := ThemeDB.fallback_font
	var d := GameState.dept()
	var label := "FLOOR 1  -  %s" % (d.display_name.to_upper() if d != null else "")
	draw_string(font, Vector2(MARGIN, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEXT_DIM)
	var step := 40.0
	var x := step
	while x < size.x:
		var y := step
		while y < size.y:
			draw_circle(Vector2(x, y), 1.0, Palette.SLATE.darkened(0.5))
			y += step
		x += step
