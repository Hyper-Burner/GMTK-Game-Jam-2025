extends Node2D

@onready var ground = $Ground
@onready var preview = $Preview
@onready var highlight = $Highlight

var seeds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))
var crops = preload("res://Scenes/crop.tscn")

var selected_seed: String = "Tuloop"

func _ready():
	Signals.slot_selected.connect(change_selected_seed)

func _physics_process(delta: float) -> void:
	if State.current_action == State.Actions.PLANTING:
		if ground.get_cell_tile_data(get_tile_position(get_global_mouse_position())):
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
	
func planting(tile_position: Vector2i):
	if ground.get_cell_tile_data(tile_position).get_custom_data("Farmland"):
		var instance = TileMapData.plant_seed(tile_position, selected_seed)
		if instance:
			instance.global_position = get_world_position(tile_position) - Vector2(0, 25)
			add_child(instance)
	
func harvesting(tile_position: Vector2i):
	TileMapData.harvest_crop(tile_position)
	
func inspecting(tile_position: Vector2i):
	if ground.get_cell_tile_data(tile_position).get_custom_data("Farmland"):
		TileMapData.inspect(tile_position, get_world_position(tile_position))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var tile_position = get_tile_position(event.global_position)
			if State.current_action == State.Actions.PLANTING:
				planting(tile_position)
			elif State.current_action == State.Actions.HARVESTING:
				harvesting(tile_position)
			elif State.current_action == State.Actions.INSPECTING:
				inspecting(tile_position)
func change_selected_seed(item_id: String, slot_index:int):
	print(item_id)
	selected_seed = item_id
