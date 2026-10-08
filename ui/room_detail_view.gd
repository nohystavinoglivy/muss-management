class_name RoomDetailView
extends HBoxContainer
## Room art on one side, database on the other. Clicking a person in the art selects them.

signal back_pressed
signal employee_clicked(employee_id: String)

var art: RoomArtView
var database: DatabasePanel
var _title: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.0
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	var head := HBoxContainer.new()
	var back := Button.new()
	back.text = "<  FACILITY"
	back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(back)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Palette.SKY)
	head.add_child(_title)
	lv.add_child(head)
	art = RoomArtView.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size = Vector2(320, 260)
	art.employee_clicked.connect(func(id: String) -> void: employee_clicked.emit(id))
	lv.add_child(art)
	var hint := Label.new()
	hint.text = "Click a person to inspect them."
	hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
	hint.add_theme_font_size_override("font_size", 12)
	lv.add_child(hint)
	database = DatabasePanel.new()
	database.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	database.size_flags_stretch_ratio = 2.0
	add_child(database)


func set_room(id: String) -> void:
	art.set_room(id)
	database.show_room(id)
	_title.text = GameState.room_name(id).to_upper() if id != GameState.HALL_ID else "HALL"


func set_selected_employee(id: String) -> void:
	art.selected_employee_id = id
