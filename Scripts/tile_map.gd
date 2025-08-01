extends Node2D

@onready var ground = $Ground
@onready var highlight = $Highlight

var seeds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))
var crops = preload("res://Scenes/crop.tscn")

var selected_seed: String = "Strawberry"
var instance

func _physics_process(delta: float) -> void:
	if State.current_action == State.Actions.PLANTING:
		if crops.get_cell_tile_data(get_tile_position(get_global_mouse_position())):
			highlight.modulate = Color(1, 0, 0, 0.5)
		else:
			highlight.modulate = Color(0, 1, 0, 0.5)
		highlight.clear()
		highlight.set_cell(get_tile_position(get_global_mouse_position()), 0, Vector2i(0, 0))
	elif State.current_action == State.Actions.HARVESTING:
		pass
	elif State.current_action == State.Actions.INSPECTING:
		pass

func get_tile_position(global_position: Vector2) -> Vector2i:
	var local_position = ground.to_local(global_position)
	var tile_position = ground.local_to_map(local_position)
	return tile_position

func get_world_position(tile_position: Vector2i) -> Vector2:
	var local_position = ground.map_to_local(tile_position)
	var global_postion = ground.to_global(local_position)
	return global_postion

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_position = event.global_position
			if true:
				instance = TileMapData.plant_seed(get_tile_position(mouse_position), selected_seed)
				if instance:
					instance.position = get_world_position(get_tile_position(mouse_position))
					add_child(instance)
			elif State.current_action == State.Actions.HARVESTING:
				TileMapData.harvest_crop(get_tile_position(mouse_position))
			elif State.current_action == State.Actions.INSPECTING:
				var tile_position = get_tile_position(get_global_mouse_position())
				TileMapData.inspect(get_tile_position(mouse_position))
				Signals.inspect.emit(get_world_position(tile_position), TileMapData.tile_map_data[tile_position[0]][tile_position[1]])
