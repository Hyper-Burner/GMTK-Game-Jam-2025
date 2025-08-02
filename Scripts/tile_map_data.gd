extends Node

var crop_text_file = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))
var crop_script = preload("res://Scripts/crop.gd")
var tile_map_data = []
var farm_width: int = 20
var farm_height: int = 12

func create_matrix(shape: Array, fill_value: Variant) -> Array:
	var matrix = []
	for x in shape[0]:
		var row = []
		for y in shape[1]:
			row.append(fill_value.duplicate(true))
		matrix.append(row)
	return matrix

func clear_crops():
	for x in tile_map_data:
		for y in x:
			if y["crop"]:
				y["crop"].queue_free()
				y["crop"] = false

func plant_seed(tile_position: Vector2i, seed: String):
	var tile = tile_map_data[tile_position[0]][tile_position[1]]
	if !tile["crop"] and Inventory.remove_item_from_current_inventory(seed):
		var instance = crop_script.instance(seed, false)
		tile["crop"] = instance
		return instance
	else:
		return false

func harvest_crop(tile_position: Vector2i):
	var tile = tile_map_data[tile_position[0]][tile_position[1]]
	if tile["crop"] and tile["crop"].harvastable:
		var crop_name = tile["crop"].crop_name
		tile["hydration"] = crop_text_file[crop_name]["hydration"]
		tile["nutrients"] = crop_text_file[crop_name]["nutrients"]
		tile["soil_ph"] = crop_text_file[crop_name]["soil_ph"]
		tile["crop"] = false
		Signals.harvest_crop.emit(tile["crop"].crop_name)

func inspect(tile_position: Vector2i, world_position) -> Dictionary:
	var tile = tile_map_data[tile_position[0]][tile_position[1]]
	Signals.inspect.emit(world_position, tile)
	return tile

func _ready() -> void:
	tile_map_data = create_matrix([farm_width, farm_height], {
		"hydration": 50,
		"nutrients": 50,
		"soil_ph": 50,
		"crop": false
	})
	Signals.loop_ended.connect(clear_crops)
