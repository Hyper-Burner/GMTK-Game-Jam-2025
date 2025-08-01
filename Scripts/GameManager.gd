# GameManager.gd (AutoLoad Singleton)
extends Node

# --- Constants ---
const DATA_PATH_CROPS: String = "res://TextFiles/crops.json"
const DATA_PATH_ITEMS: String = "res://TextFiles/items.json"
const DATA_PATH_MILESTONES: String = "res://TextFiles/milestones.json"

const DEFAULT_LOOP_DURATION: float = 120.0 # seconds
const DEFAULT_TIME_CAPSULE_CAPACITY: int = 100
const DEFAULT_STARTING_SEEDS_ID: String = "Potato" # Now a String ID
const DEFAULT_STARTING_SEEDS_QUANTITY: int = 100

# --- Game Data Definitions (Loaded from JSON files) ---
# Now a Dictionary, where key is the item ID (String).
var crop_data_map: Dictionary = {}
# Now a Dictionary, where key is the item ID (String).
var item_data_map: Dictionary = {}
# Stores all milestone definitions in the order they should be progressed.
var milestone_stages: Array[Dictionary] = []

# --- Persistent Game State ---
# Stores String IDs.
var unlocked_plant_types: Array[String] = [DEFAULT_STARTING_SEEDS_ID] # Starts with basic seed unlocked.
# List of upgrade IDs that the player has permanently unlocked.
var unlocked_upgrades: Array[String] = [] # Assuming upgrade IDs remain strings
# The current maximum number of unique item stacks that can be sent to the next loop.
var time_capsule_capacity: int = DEFAULT_TIME_CAPSULE_CAPACITY
# The contents to be transferred to the NEXT loop (item_id: quantity).
# Cleared at start of each loop. Keys are now String.
var time_capsule_contents: Dictionary = {}
# Persistent dictionary storing which items are placed on each grid tile (e.g., {"0,0": item_id_string}).
# This data also persists across loops. Values are now String (or "" for empty).
var placed_items_grid: Dictionary = {}
# The current total duration of a single time loop. Can be upgraded.
var loop_duration: float = DEFAULT_LOOP_DURATION
# Index of the current active milestone in `milestone_stages`.
var current_milestone_index: int = 0


# --- Volatile / Current Loop State ---
# The remaining time in the current loop.
var current_loop_time: float = 0.0
# Dictionary holding the data for the active milestone.
var current_milestone_data: Dictionary = {}

# Tracks harvested crops/generated resources *within the current loop* for milestone requirements.
# Resets each loop.
# Keys are now String.
var current_loop_score: Dictionary = {}
# The ID of the item currently selected for placement (only relevant in PLACEMENT mode).
var selected_item_for_placement: String = "" # Now a String ("" for no item selected)
# Reference to the separate preview controller instance.
var placement_preview_controller: Node2D = null # Now a direct reference to the controller

var seconds_passed: int = 0


func _ready() -> void:
	# --- IMPORTANT: REMOVED ALL LOCAL SIGNAL DECLARATIONS.
	# They should be only in Signals.gd. ---

	_load_all_game_data()

	# Set the initial milestone.
	if not milestone_stages.is_empty():
		_set_current_milestone()
	else:
		push_error("ERROR: No milestone stages loaded from '%s'. Game may not progress." % DATA_PATH_MILESTONES)
	start_loop()


func _process(delta: float) -> void: # Changed to _process for smoother mouse following
	# Update game loop timer
	if current_loop_time > 0:
		current_loop_time -= delta
		# EMIT GLOBAL SIGNAL
		Signals.timer_updated.emit(current_loop_time, loop_duration) # Corrected to use .emit() and pass loop_duration
		if current_loop_time <= 0:
			current_loop_time = 0.0 # Ensure it doesn't go negative
			_end_loop()

# --- Load Json Data ---
func _load_json_data(path: String) -> Variant:
	"""
	Loads and parses a JSON file from the given path.
	Returns a Dictionary or Array if successful, otherwise an empty Dictionary/Array and logs an error.
	"""
	if not FileAccess.file_exists(path):
		push_error("ERROR: JSON file not found: %s" % path)
		return [] # Still returning Array from this helper, as the JSON structure is an Array.

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ERROR: Could not open JSON file for reading: %s" % path)
		return [] # Still returning Array from this helper.

	var json_string: String = file.get_as_text()
	file.close()

	var json_parser = JSON.new() # Create an instance of the JSON utility class for parsing.
	
	# In Godot 4, parse_string returns the parsed data on success, or null on failure.
	# Error details are retrieved from the JSON parser object itself.
	var parsed_data = json_parser.parse_string(json_string)

	if parsed_data == null: # Check if parsing failed (result is null)
		push_error("ERROR: Could not parse JSON from %s. Parse Error: %s at line %d" % [path, json_parser.get_error_message(), json_parser.get_error_line()])
		return [] # Return empty array on parsing error.

	# This check is useful if the JSON *parsed* successfully but the content itself was just "null".
	# However, it's harmless and can act as a fallback.
	# Removed the `push_error` for null data object, as it's not strictly an error if the user provides an empty array.
	return parsed_data

func _load_all_game_data() -> void:
	# Load Crop Data
	var loaded_crops_array: Dictionary = _load_json_data(DATA_PATH_CROPS)
	if loaded_crops_array is Dictionary:
		crop_data_map.clear() # Clear existing data
		for crop_def in loaded_crops_array:
			if crop_def is Dictionary and crop_def.has("name"):
				var crop_id_str: String = crop_def["name"] # Use 'name' as the ID
				if crop_data_map.has(crop_id_str):
					push_warning("Duplicate crop 'name' ID found: %s in %s. Skipping." % [crop_id_str, DATA_PATH_CROPS])
					continue
				crop_data_map[crop_id_str] = crop_def # Use 'name' as the key
			else:
				push_warning("Crop definition in '%s' is missing 'name' or invalid format: %s" % [DATA_PATH_CROPS, crop_def])
	else:
		push_warning("Crop data in '%s' is not an Array, expecting Array. Received: %s" % [DATA_PATH_CROPS, typeof(loaded_crops_array)])

	# Load Item Data
	var loaded_items_array: Dictionary = _load_json_data(DATA_PATH_ITEMS)
	if loaded_items_array is Dictionary:
		item_data_map.clear() # Clear existing data
		for item_def in loaded_items_array:
			if item_def is Dictionary and item_def.has("name"):
				var item_id_str: String = item_def["name"] # Use 'name' as the ID
				if item_data_map.has(item_id_str):
					push_warning("Duplicate item 'name' ID found: %s in %s. Skipping." % [item_id_str, DATA_PATH_ITEMS])
					continue
				item_data_map[item_id_str] = item_def # Use 'name' as the key
			else:
				push_warning("Item definition in '%s' is missing 'name' or invalid format: %s" % [DATA_PATH_ITEMS, item_def])
	else:
		push_warning("Item data in '%s' is not an Array, expecting Array. Received: %s" % [DATA_PATH_ITEMS, typeof(loaded_items_array)])

	# Load Milestone Data - (no changes needed here related to item IDs, remains as array)
	var loaded_milestones_raw: Dictionary = _load_json_data(DATA_PATH_MILESTONES)
	if loaded_milestones_raw is Dictionary:
		milestone_stages.clear()
		for milestone_def in loaded_milestones_raw:
			if milestone_def is Dictionary:
				milestone_stages.append(milestone_def)
			else:
				push_warning("Invalid milestone definition found in '%s': Expected Dictionary, but found %s. Skipping this entry." % [DATA_PATH_MILESTONES, typeof(loaded_milestones_raw)])
	else:
		push_warning("Milestone data in '%s' is not an Array, expecting Array. Received: %s" % [DATA_PATH_MILESTONES, typeof(loaded_milestones_raw)])

	print("Loaded %d crop definitions." % crop_data_map.size())
	print("Loaded %d item definitions." % item_data_map.size())
	print("Loaded %d milestone stages." % milestone_stages.size())


# --- Loop Management ---
func start_loop() -> void:
	"""Initiates a new game loop, resetting transient states and delivering time-capsuled items."""
	current_loop_time = loop_duration # Reset timer for the
	# new loop.
	Inventory.current_inventory.reset()       # Clear transient inventory for the new loop.
	current_loop_score.clear()      # Reset loop score for milestone checks (progress must be made
	# in current loop).
	# Add default starting seeds for the loop.
	# No validation if user doesn't want it.
	# Assumes DEFAULT_STARTING_SEEDS_ID is always valid.
	Inventory.add_item_to_inventory(DEFAULT_STARTING_SEEDS_ID, DEFAULT_STARTING_SEEDS_QUANTITY)
	
	# Transfer time-capsuled items from the previous loop.
	# time_capsule_contents keys are now String.
	for item_id_str in time_capsule_contents:
		Inventory.add_item_to_inventory(item_id_str, time_capsule_contents[item_id_str])
	time_capsule_contents.clear() # Clear capsule contents for the current loop's packing.
	# EMIT GLOBAL SIGNAL
	Signals.loop_started.emit()
	print("Loop Started! Duration: %.1f sec, Capsule Capacity: %d" % [loop_duration, time_capsule_capacity])


func _end_loop() -> void:
	"""
	Handles the end-of-loop processes, including milestone checks and rewards.
	Soil stats persist automatically as they are not reset here.
	"""
	# Check if the current milestone's requirements have been met.
	if _check_milestone_met():
		_apply_milestone_reward()
	
	# EMIT GLOBAL SIGNAL
	Signals.loop_ended.emit()
	print("Loop Ended!")

	# Start the next loop after a brief delay (e.g., for showing a summary screen).
	get_tree().create_timer(1.0).timeout.connect(start_loop)



# item_id is now a String.
func add_item_to_time_capsule(item_id: String, quantity: int = 1) -> bool:
	"""
	Adds an item to the time capsule, provided there's capacity.
	Items in the time capsule are carried over to the next loop.
	"""
	# No validation if user doesn't want it.
	# The `if not (...) return false` block is entirely removed.
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to time capsule: ID %s, quantity: %d" % [item_id, quantity])
		return false
	
	# Check if adding this item would exceed capacity for unique item stacks.
	# Only if it's a new item in the capsule OR capacity is full.
	if not time_capsule_contents.has(item_id) and time_capsule_contents.size() >= time_capsule_capacity:
		push_warning("Time capsule is full! Cannot add new item ID %s. Current unique items: %d, Capacity: %d" % [item_id, time_capsule_contents.size(), time_capsule_capacity])
		return false
	return false

# crop_id is now a String.
func add_harvested_crop_to_score(crop_id: String, quantity: int = 1) -> void:
	"""Adds harvested crops to the current loop's score for milestone tracking."""
	# No validation if user doesn't want it.
	# The `if not (...) return` block is entirely removed.
	if quantity <= 0:
		return

	current_loop_score[crop_id] = current_loop_score.get(crop_id, 0) + quantity
	print("Added %d x ID %s to loop score. Current score: %s" % [quantity, crop_id, current_loop_score])



# item_id_to_remove is now a String.
func _remove_item_from_grid(grid_x: int, grid_y: int) -> void:
	"""
	Removes an item from the logical grid data.
	Also attempts to remove its corresponding 2D instance from the scene tree.
	"""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	# Default to empty string for an empty slot.
	var item_id_to_remove: String = placed_items_grid.get(coords_key, "")

	if not item_id_to_remove.is_empty(): # Check for empty string
		# Find and remove the 2D instance by its expected name.
		# This might need refinement for more complex scenes (e.g., if items are parented differently).
		# Item name includes the String ID.
		var expected_2d_name = "item_%s_%d_%d" % [item_id_to_remove, grid_x, grid_y]
		var item_found = false
		
		# Assuming placement_preview_controller (your tile_maps.gd instance) is
		# also responsible for holding the 2D instances of crops/items.
		# You might need to add tile_maps.gd to a group like "item_visuals_group"
		# and retrieve it using get_tree().get_first_node_in_group("item_visuals_group")
		# if it's not directly assigned to placement_preview_controller.
		if placement_preview_controller: # This is the Node2D script (tile_maps.gd)
			for child in placement_preview_controller.get_children():
				if child is Node2D and child.name == expected_2d_name:
					child.queue_free() # Safely delete the 2D node.
					print("Removed 2D instance of '%s' (ID %s) at (%d,%d)." % [expected_2d_name, item_id_to_remove, grid_x, grid_y])
					item_found = true
					break
		
		if item_found:
			placed_items_grid[coords_key] = "" # Clear the grid data after successful removal with empty string.
		else:
			push_warning("Could not find 2D instance for '%s' (ID %s) at (%d,%d) to remove." % [expected_2d_name, item_id_to_remove, grid_x, grid_y])
	else:
		print("No item to remove at (%d,%d)." % [grid_x, grid_y])


# --- Milestone Management ---
func _set_current_milestone() -> void:
	"""Sets the current milestone data based on `current_milestone_index`."""
	current_milestone_data = milestone_stages.get(current_milestone_index) # Use .get() with default
	if not current_milestone_data.is_empty(): # Check if a milestone was actually retrieved
		print("Current Milestone: %s" % current_milestone_data.get("display_name", "Unnamed Milestone"))
		# EMIT GLOBAL SIGNAL
		Signals.milestone_updated.emit(current_milestone_data)
	else:
		print("All milestones completed!")
		# current_milestone_data is already {} from .get() if index was invalid

func _check_milestone_met() -> bool:
	"""Checks if the requirements for the current milestone have been met."""
	if current_milestone_data.is_empty():
		return false
	
	var requirements: Dictionary = current_milestone_data.get("requirements", {})
	var met_all: bool = true

	# --- Check harvested crop requirements ---
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

	# If all checked requirements were met, then the milestone is completed.
	if met_all:
		print("Milestone '%s' Met!" % current_milestone_data.get("display_name", "Unknown Milestone"))
	
	return met_all


func _apply_milestone_reward() -> void:
	"""Applies rewards for completing the current milestone."""
	print("Applying milestone reward...")
	
	var rewards: Dictionary = current_milestone_data.get("rewards", {})
	
	# Unlock new plant types.
	var new_plants: Array = rewards.get("unlocked_plants", []) # Corrected key
	for plant_id_str in new_plants: # Assuming rewards JSON gives String IDs
		if not unlocked_plant_types.has(plant_id_str): # 'has' works on Array
			unlocked_plant_types.append(plant_id_str)
			# EMIT GLOBAL SIGNAL
			Signals.plant_unlocked.emit(plant_id_str) # Emit String ID
			print("Unlocked new plant: ID %s" % plant_id_str)

	# Unlock upgrades (e.g., increase time capsule capacity, loop duration).
	var new_upgrades: Array = rewards.get("unlocked_upgrades", []) # Corrected key
	for upgrade_item in new_upgrades: # Assuming upgrade_item is a dictionary {type: "capacity", value: 5} or {type: "duration", value: 30.0}
		if upgrade_item is Dictionary and upgrade_item.has("type"):
			match upgrade_item["type"]:
				"time_capsule_capacity_increase": # Corrected type name
					var capacity_increase = int(upgrade_item.get("value", 0))
					time_capsule_capacity += capacity_increase
					# EMIT GLOBAL SIGNAL
					Signals.time_capsule_capacity_changed.emit(time_capsule_capacity)
					print("Time capsule capacity increased by %d to %d." % [capacity_increase, time_capsule_capacity])
				"loop_duration_increase": # Corrected type name
					var duration_increase = float(upgrade_item.get("value", 0.0))
					loop_duration += duration_increase
					# EMIT GLOBAL SIGNAL
					Signals.loop_duration_changed.emit(loop_duration)
					print("Loop duration increased by %.1f to %.1f seconds." % [duration_increase, loop_duration])
				_:
					push_warning("Unknown upgrade type in milestone reward: %s" % upgrade_item["type"])
		# No global signal for generic 'upgrade_unlocked' as it's handled by specific types above.
	# If you need a generic one, ensure it's emitted here.

	# Progress to the next milestone.
	current_milestone_index += 1
	_set_current_milestone() # Call to set the next milestone or signal completion.
# --- Game Mode Management (Interaction State) ---
# item_id_for_placement is now a String.

func _on_timeout():
	seconds_passed += 1
	emit_signal("time_updated", seconds_passed, seconds_passed)
