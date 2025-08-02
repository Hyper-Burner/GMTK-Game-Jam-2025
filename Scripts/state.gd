extends Node

enum Actions {
	NONE = 0,
	PLANTING = 1,
	HARVESTING = 2,
	INSPECTING = 3
}

var current_action = Actions.NONE

func set_current_action(action: String):
	match action:
		"None":
			current_action = Actions.NONE
		"Planting":
			current_action = Actions.PLANTING
		"Harvesting":
			current_action = Actions.HARVESTING
		"Inspecting":
			current_action = Actions.INSPECTING
