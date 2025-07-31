extends Node2D

@onready var ground = $Ground
@onready var crops = $Crops
@onready var highlight = $Highlight

var seeds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))
var source_id: int
var selected_tile: Vector2i
var placement_mode: bool = false

func _ready() -> void:
	Signals.planting_mode_entered.connect(planting_mode_entered)
	Signals.planting_mode_exited.connect(placement_mode_exited)
	Signals.plant_seed.connect(plant_seed)

func _physics_process(delta: float) -> void:
	if placement_mode:
		if !crops.get_cell_tile_data(get_tile_position(get_global_mouse_position())):
			highlight.modulate = Color(1, 0, 0, 1)
		else:
			highlight.modulate = Color(1, 0, 0, 0.5)

		highlight.clear()
		highlight.set_cell(get_tile_position(get_global_mouse_position()), 0, Vector2i(0, 0))

func get_tile_position(global_position: Vector2) -> Vector2i:
	var local_position = ground.to_local(global_position)
	var tile_position = ground.local_to_map(local_position)
	
	return tile_position

func planting_mode_entered(seed: String):
	print("smol sproot - planting mode entered for seed:", seed)
	placement_mode = true

func placement_mode_exited():
	placement_mode = false

func plant_seed(seed: String):
	crops.set_cell(get_tile_position(get_global_mouse_position()), 0, seeds[seed]["atlas_coords"])
