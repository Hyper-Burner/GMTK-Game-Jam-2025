extends Node

# Dictionary holding the data for the active milestone.
var current_milestone_data: Dictionary = {}

# Tracks harvested crops/generated resources *within the current loop* for milestone requirements.
# Resets each loop.
var current_loop_score: Dictionary = Inventory.crop_inventory

# Index of the current active milestone in `milestone_stages`.
# This will now represent the numerical progression,
# and we'll use a mapping or ordered keys to get the actual milestone data.
var current_milestone_index: int = 0
var current_milestone_key: String = "" # New: Store the key of the current milestone

# --- Milestone Management ---
# New function to set milestone by key
func _set_current_milestone_by_key(milestone_key: String) -> void:
	if Global.milestone_stages.has(milestone_key):
		current_milestone_key = milestone_key
		current_milestone_data = Global.milestone_stages[milestone_key]

		# Update current_milestone_index based on the order of keys in Global.milestone_stages
		var milestone_keys_ordered = Global.milestone_stages.keys()
		var index_found = milestone_keys_ordered.find(milestone_key)
		if index_found != -1:
			current_milestone_index = index_found
		else:
			push_warning("Milestone key '%s' not found in ordered keys, index might be off." % milestone_key)

		print("Current Milestone: %s (Key: %s)" % [current_milestone_data.get("description", "Unnamed Milestone"), current_milestone_key])
		Signals.milestone_updated.emit(current_milestone_data)
	else:
		push_error("ERROR: Milestone key '%s' not found in Global.milestone_stages." % milestone_key)
		current_milestone_data = {}
		current_milestone_key = ""
		# You might want to signal "all milestones completed" here if this means the end.

# Modified _set_current_milestone to use the index to find the next key
func _set_current_milestone() -> void:
	"""Sets the current milestone data based on `current_milestone_index`."""
	var milestone_keys_ordered = Global.milestone_stages.keys()
	if current_milestone_index < milestone_keys_ordered.size():
		current_milestone_key = milestone_keys_ordered[current_milestone_index]
		current_milestone_data = Global.milestone_stages[current_milestone_key]
		print("Current Milestone: %s (Key: %s)" % [current_milestone_data.get("description", "Unnamed Milestone"), current_milestone_key])
		# EMIT GLOBAL SIGNAL
		Signals.milestone_updated.emit(current_milestone_data)
	else:
		print("All milestones completed!")
		current_milestone_data = {} # Ensure it's empty if all are completed
		current_milestone_key = ""


func _check_milestone_met() -> bool:
	"""Checks if the requirements for the current milestone have been met."""
	if current_milestone_data.is_empty():
		return false
	
	var requirements: Dictionary = current_milestone_data.get("requirements", {})
	var met_all: bool = true

	# [cite_start]Check harvested crop requirements [cite: 8]
	if requirements.has("harvested_crops"):
		var required_crops: Dictionary = requirements["harvested_crops"]
		for crop_id_str in required_crops: # Keys in JSON requirements are now strings
			var required_quantity: int = required_crops[crop_id_str]
			# No conversion needed, crop_id_str is already the key
			
			var current_quantity: int = current_loop_score.get(crop_id_str, 0) # Use String ID

			if current_quantity < required_quantity:
				met_all = false
				print("Milestone not met: Need %d x ID %s, have %d." % [required_quantity, crop_id_str, current_quantity])
				break

	#If all checked requirements were met, then the milestone is completed. [cite: 9]
	if met_all:
		print("Milestone '%s' Met!" % current_milestone_data.get("description", "Unknown Milestone"))
	
	return met_all
	
func _apply_milestone_reward() -> void:
	"""Applies rewards for completing the current milestone."""
	print("Applying milestone reward...")
	
	var rewards: Dictionary = current_milestone_data.get("rewards", {})
	
	var new_plants_raw = rewards.get("unlocked_plants", null) # [cite: 10]
	var new_plants: Array = []
	if typeof(new_plants_raw) == TYPE_STRING:
		new_plants.append(new_plants_raw)
	elif typeof(new_plants_raw) == TYPE_ARRAY:
		new_plants = new_plants_raw
	# If it's null, new_plants remains empty.

	for plant_id_str in new_plants:
		if not Global.unlocked_plant_types.has(plant_id_str):
			Global.unlocked_plant_types.append(plant_id_str)
			# EMIT GLOBAL SIGNAL
			Signals.plant_unlocked.emit(plant_id_str) # Emit String ID
			print("Unlocked new plant: ID %s" % plant_id_str)

	# Unlock upgrades (e.g., increase time capsule capacity, loop duration).
	var new_upgrades: Array = rewards.get("unlocked_upgrades", [])
	for upgrade_item in new_upgrades:
		if upgrade_item is Dictionary and upgrade_item.has("type"):
			match upgrade_item["type"]:
				"time_capsule_expansion":
					var capacity_increase = int(upgrade_item.get("value", 0))
					Global.time_capsule_capacity += capacity_increase
					# EMIT GLOBAL SIGNAL
					Signals.time_capsule_capacity_changed.emit(Global.time_capsule_capacity)
					print("Time capsule capacity increased by %d to %d." % [capacity_increase, Global.time_capsule_capacity])
				"seed": # Handle new "seed" type for unlocks
					var seed_name = upgrade_item.get("seed_name", "")
					var quantity = int(upgrade_item.get("quantity", 1)) # Assuming 'quantity' is used for seed type
					if not seed_name.is_empty():
						# You'll need a way to add these seeds to the player's inventory or unlocked seeds list
						# Example: Global.add_unlocked_seed(seed_name, quantity)
						Inventory.add_item_to_starting_inventory(seed_name,quantity)
						print("Unlocked seed: %d x %s" % [quantity, seed_name])
						# EMIT GLOBAL SIGNAL if you have one for seed unlocks
				"item": # Handle new "item" type for unlocks
					var item_name = upgrade_item.get("item_name", "")
					if not item_name.is_empty():
						# You'll need a way to add this item to the player's inventory
						# Example: Global.add_item_to_inventory(item_name)
						print("Unlocked item: %s" % item_name)
						# EMIT GLOBAL SIGNAL if you have one for item unlocks
					push_warning("Unknown upgrade type in milestone reward: %s" % upgrade_item["type"])
	current_milestone_index += 1
	_set_current_milestone() 
