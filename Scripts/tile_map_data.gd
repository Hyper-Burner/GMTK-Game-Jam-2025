extends Node

var crop = preload("res://Scenes/crop.tscn")
var tile_map = []
var farm_width = 5
var farm_height = 5

func create_matrix(shape: Array, fill_value) -> Array:
	var matrix = []
	for x in shape[0]:
		var row = []
		for y in shape[1]:
			row.append(fill_value)
		matrix.append(row)
	return matrix

func plant_seed(tile_position: Vector2i, seed: String):
	var tile = tile_map[tile_position[0]][tile_position[1]]
	if !tile["Plant"]:
		#if Inventory.subtract_seed(seed, 1):
		tile["Plant"] = {
			"Name": seed,
			"Harvestable": false,
			"Instance": crop.instance(seed, false)
		}

func harvest_crop(tile_position: Vector2i):
	var tile = tile_map[tile_position[0]][tile_position[1]]
	if tile["Plant"] and tile["Plant"]["Harvestable"]:
		Signals.harvest_crop.emit(tile["Plant"]["Name"])
		# Inventory.ha
		tile["Plant"] = false

func inspect(tile_position: Vector2i) -> Dictionary:
	var tile = tile_map[tile_position[0]][tile_position[1]]
	return tile

func _ready() -> void:
	tile_map = create_matrix([farm_width, farm_height], {
		"Hydration": 50,
		"Nutrients": 50,
		"Soil PH": 50,
		"Plant": false
	})
