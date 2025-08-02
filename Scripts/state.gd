extends Node

enum Actions {
	NONE = 0,
	PLANTING = 1,
	HARVESTING = 2,
	INSPECTING = 3
}

var cursor = preload("res://Textures/cursor.png")
var planting_cursor = preload("res://Textures/planting_cursor.png")
var harvesting_cursor = preload("res://Textures/harvesting_cursor.png")
var inspecting_cursor = preload("res://Textures/inspecting_cursor.png")

var current_action = Actions.NONE

func set_current_action(action: String):
	match action:
		"None":
			current_action = Actions.NONE
			Input.set_custom_mouse_cursor(cursor)
		"Planting":
			current_action = Actions.PLANTING
			Input.set_custom_mouse_cursor(planting_cursor)
		"Harvesting":
			current_action = Actions.HARVESTING
			Input.set_custom_mouse_cursor(harvesting_cursor)
		"Inspecting":
			current_action = Actions.INSPECTING
			Input.set_custom_mouse_cursor(inspecting_cursor)
