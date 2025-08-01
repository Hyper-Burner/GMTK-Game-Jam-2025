extends Node

var crop = preload("res://Scripts/crop.gd")
var tile_map_data = []
var farm_width = 20
var farm_height = 12

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
			y["Plant"] = false

func plant_seed(tile_position: Vector2i, seed: String):
	var tile = tile_map_data[tile_position[0]][tile_position[1]]
	if !tile["Plant"]:
		tile_map_data[tile_position[0]][tile_position[1]]["Plant"] = crop.instance(seed, false)
		return tile_map_data[tile_position[0]][tile_position[1]]["Plant"]
	else:
		return false

func harvest_crop(tile_position: Vector2i):
	var tile = tile_map_data[tile_position[0]][tile_position[1]]
	if tile["Plant"] and tile["Plant"]["Harvestable"]:
		Signals.harvest_crop.emit(tile["Plant"]["Name"])
		# Inventory.ha
		tile["Plant"] = false

func inspect(tile_position: Vector2i) -> Dictionary:
	var tile = tile_map_data[tile_position[0]][tile_position[1]]
	return tile

func _ready() -> void:
	tile_map_data = create_matrix([farm_width, farm_height], {
		"Hydration": 50,
		"Nutrients": 50,
		"Soil PH": 50,
		"Plant": false
	})
