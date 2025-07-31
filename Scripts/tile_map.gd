extends Node2D

@onready var ground = $Ground
@onready var highlight = $Highlight

var seeds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))
var crops = preload("res://Scenes/crop.tscn")

enum Modes {
	NONE = 0,
	PLANTING = 1,
	HARVESTING = 2,
	INSPECTING = 3
}

var current_mode = Modes.NONE
var selected_seed: String = "Potato"

func _ready() -> void:
	Signals.planting_mode_entered.connect(func():
		current_mode = Modes.PLANTING
	)
	Signals.planting_mode_exited.connect(func():
		current_mode = Modes.NONE
	)
	Signals.harvesting_mode_entered.connect(func():
		current_mode = Modes.HARVESTING
	)
	Signals.harvesting_mode_exited.connect(func():
		current_mode = Modes.NONE
	)
	Signals.inspect_mode_entered.connect(func():
		current_mode = Modes.INSPECTING
	)
	Signals.inspect_mode_exited.connect(func():
		current_mode = Modes.NONE
	)

func _physics_process(delta: float) -> void:
	if current_mode == Modes.PLANTING:
		if crops.get_cell_tile_data(get_tile_position(get_global_mouse_position())):
			highlight.modulate = Color(1, 0, 0, 0.5)
		else:
			highlight.modulate = Color(0, 1, 0, 0.5)
	elif current_mode == Modes.HARVESTING:

		highlight.clear()
		highlight.set_cell(get_tile_position(get_global_mouse_position()), 0, Vector2i(0, 0))

func get_tile_position(global_position: Vector2) -> Vector2i:
	var local_position = ground.to_local(global_position)
	var tile_position = ground.local_to_map(local_position)
	return tile_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_position = event.global_position
			if current_mode == Modes.PLANTING:
				TileMapData.plant_seed(get_tile_position(mouse_position), selected_seed)
			elif current_mode == Modes.HARVESTING:
				TileMapData.harvest_crop(get_tile_position(mouse_position))
			elif current_mode == Modes.INSPECTING:
				TileMapData.inspect(get_tile_position(mouse_position))
