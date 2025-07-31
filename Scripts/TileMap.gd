extends Node2D

@onready var ground = $Ground
@onready var highlight = $Highlight

var seeds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))
var crops = preload("res://Scenes/crop.tscn")
var source_id: int
var selected_tile: Vector2i
var placement_mode: bool = false

var ground_properties = []

func _ready() -> void:
	Signals.planting_mode_entered.connect(planting_mode_entered)
	Signals.planting_mode_exited.connect(placement_mode_exited)
	Signals.plant_seed.connect(plant_seed)
	
	ground_properties = create_matrix([5, 5], {
		"Hydration": 50,
		"Nutrients": 50,
		"Soil PH": 50,
		"Planted": 0
	})
	
	print(ground_properties)

func _physics_process(delta: float) -> void:
	if placement_mode:
		if crops.get_cell_tile_data(get_tile_position(get_global_mouse_position())):
			highlight.modulate = Color(1, 0, 0, 0.5)
		else:
			highlight.modulate = Color(0, 1, 0, 0.5)

		highlight.clear()
		highlight.set_cell(get_tile_position(get_global_mouse_position()), 0, Vector2i(0, 0))

func get_tile_position(global_position: Vector2) -> Vector2i:
	var local_position = ground.to_local(global_position)
	var tile_position = ground.local_to_map(local_position)
	return tile_position
	
func is_optimal_condition(tile, seed):
	pass
	
func create_matrix(shape: Array, fill_value) -> Array:
	var matrix = []
	for x in shape[0]:
		var row = []
		for y in shape[1]:
			row.append(fill_value)
		matrix.append(row)
	return matrix

func planting_mode_entered(seed: String) -> void:
	placement_mode = true

func placement_mode_exited() -> void:
	placement_mode = false
	highlight.clear()

func plant_seed(seed: String) -> void:
	var atlas_coords = Vector2i(seeds[seed]["atlas_coords_x"],seeds[seed]["atlas_coords_y"] )
	crops.create()
