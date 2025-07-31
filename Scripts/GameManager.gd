# GameManager.gd (AutoLoad Singleton)
extends Node

# --- Signals ---
# Emitted when a new game loop starts.
signal loop_started()
# Emitted when the current game loop ends.
signal loop_ended()
# Emitted regularly to update the timer display.
signal timer_updated(current_time: float, total_time: float)
# Emitted when an item's quantity in the current inventory changes.
signal inventory_changed(item_id: String, new_quantity: int)
# Emitted when the current active milestone changes.
signal milestone_updated(milestone_data: Dictionary)
# Emitted when a new plant type is unlocked.
signal plant_unlocked(plant_id: String)
# Emitted when a game upgrade is unlocked.
signal upgrade_unlocked(upgrade_id: String)
# Emitted when the time capsule capacity changes.
signal time_capsule_capacity_changed(new_capacity: int)
# Emitted when soil properties on a specific tile change.
signal soil_properties_changed(grid_x: int, grid_y: int, new_properties: Dictionary)
# Emitted when the total loop duration changes (e.g., from an upgrade).
signal loop_duration_changed(new_duration: float)


# --- Constants ---
const DATA_PATH_CROPS: String = "res://Data/crops.json"
const DATA_PATH_ITEMS: String = "res://Data/items.json"
const DATA_PATH_MILESTONES: String = "res://Data/milestones.json"

const DEFAULT_GRID_WIDTH: int = 5
const DEFAULT_GRID_HEIGHT: int = 5
const DEFAULT_LOOP_DURATION: float = 120.0 # seconds
const DEFAULT_TIME_CAPSULE_CAPACITY: int = 3
const DEFAULT_STARTING_SEEDS_ID: String = "basic_seed"
const DEFAULT_STARTING_SEEDS_QUANTITY: int = 3

# --- Game Data Definitions (Loaded from JSON files) ---
# Stores all crop/plant definitions, keyed by their 'id'.
var crop_data_map: Dictionary = {}
# Stores all general item definitions, keyed by their 'id'.
var item_data_map: Dictionary = {}
# Stores all milestone definitions in the order they should be progressed.
var milestone_stages: Array[Dictionary] = []

# --- Persistent Game State ---
# No longer using total_temporal_energy.
# List of plant IDs that the player has permanently unlocked.
var unlocked_plant_types: Array[String] = [DEFAULT_STARTING_SEEDS_ID] # Starts with basic seed unlocked.
# List of upgrade IDs that the player has permanently unlocked.
var unlocked_upgrades: Array[String] = []
# The current maximum number of unique item stacks that can be sent to the next loop.
var time_capsule_capacity: int = DEFAULT_TIME_CAPSULE_CAPACITY
# The contents to be transferred to the NEXT loop (item_id: quantity). Cleared at start of each loop.
var time_capsule_contents: Dictionary = {}
# Persistent dictionary storing the current properties of each soil tile (e.g., {"0,0": {"fertility": 50, ...}}).
var soil_grid_data: Dictionary = {}
# The current total duration of a single time loop. Can be upgraded.
var loop_duration: float = DEFAULT_LOOP_DURATION
# Index of the current active milestone in `milestone_stages`.
var current_milestone_index: int = 0


# --- Volatile / Current Loop State ---
# The remaining time in the current loop.
var current_loop_time: float = 0.0
# Dictionary holding the data for the active milestone.
var current_milestone_data: Dictionary = {}
# Items available in the current loop's inventory (item_id: quantity). Resets each loop.
var current_inventory: Dictionary = {}
# Tracks harvested crops/generated resources *within the current loop* for milestone requirements. Resets each loop.
var current_loop_score: Dictionary = {}


func _ready() -> void:
	_load_all_game_data()

	# Initialize soil grid if it's the first run (no saved data loaded).
	if soil_grid_data.is_empty():
		_initialize_default_soil_grid(DEFAULT_GRID_WIDTH, DEFAULT_GRID_HEIGHT)

	# Set the initial milestone.
	if not milestone_stages.is_empty():
		_set_current_milestone()
	else:
		push_error("ERROR: No milestone stages loaded from '%s'. Game may not progress." % DATA_PATH_MILESTONES)

	start_loop()


func _physics_process(delta: float) -> void:
	if current_loop_time > 0:
		current_loop_time -= delta
		emit_signal("timer_updated", current_loop_time, loop_duration)
		if current_loop_time <= 0:
			current_loop_time = 0.0 # Ensure it doesn't go negative
			_end_loop()

#--- Load Json Data ---
func _load_json_data(path: String) -> Variant: # Changed return type to Variant
	"""
	Loads and parses a JSON file from the given path.
	Returns a Dictionary or Array if successful, otherwise an empty Dictionary/Array and logs an error.
	"""
	if not FileAccess.file_exists(path):
		push_error("ERROR: JSON file not found: %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ERROR: Could not open JSON file for reading: %s" % path)
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var json_parser = JSON.new() # Create an instance of the JSON utility class
	var parse_result = json_parser.parse_string(json_string) # Use the instance to parse

	if parse_result != OK: # Check if the parsing itself failed (e.g., malformed JSON)
		push_error("ERROR: Could not parse JSON from %s. Parse Error: %s at line %d" % [path, json_parser.get_error_message(), json_parser.get_error_line()])
		return {} # Return empty dict/array based on your expectation of the root type, or null

	# The actual parsed data is stored in the 'data' property of the parser instance
	var parsed_data = json_parser.data

	if parsed_data == null:
		push_error("ERROR: JSON file '%s' parsed successfully but resulted in a null data object. Content might be 'null'." % path)
		return {} # Assuming most config JSONs will be objects/arrays, returning empty dict is safer.

	return parsed_data


func _load_all_game_data() -> void:
	"""Loads all game data (crops, items, milestones) from JSON files."""
	# Load Crop Data
	var loaded_crops: Array = _load_json_data(DATA_PATH_CROPS)
	if loaded_crops is Array:
		for crop_def in loaded_crops:
			if crop_def is Dictionary and crop_def.has("id"):
				crop_data_map[crop_def["id"]] = crop_def
			else:
				push_warning("Crop definition in '%s' missing 'id' or invalid format: %s" % [DATA_PATH_CROPS, crop_def])
	
	# Load Item Data
	var loaded_items: Array = _load_json_data(DATA_PATH_ITEMS)
	if loaded_items is Array:
		for item_def in loaded_items:
			if item_def is Dictionary and item_def.has("id"):
				item_data_map[item_def["id"]] = item_def
			else:
				push_warning("Item definition in '%s' missing 'id' or invalid format: %s" % [DATA_PATH_ITEMS, item_def])

	# Load Milestone Data
	var loaded_milestones: Array = _load_json_data(DATA_PATH_MILESTONES)
	if loaded_milestones is Array:
		milestone_stages = loaded_milestones
	
	print("Loaded %d crop definitions." % crop_data_map.size())
	print("Loaded %d item definitions." % item_data_map.size())
	print("Loaded %d milestone stages." % milestone_stages.size())


# --- Loop Management ---
func start_loop() -> void:
	"""Initiates a new game loop, resetting transient states and delivering time-capsuled items."""
	current_loop_time = loop_duration # Reset timer
	current_inventory.clear()       # Clear transient inventory
	current_loop_score.clear()      # Reset loop score for milestone checks

	# Add default starting seeds for the loop.
	if crop_data_map.has(DEFAULT_STARTING_SEEDS_ID):
		add_item_to_inventory(DEFAULT_STARTING_SEEDS_ID, DEFAULT_STARTING_SEEDS_QUANTITY)
	else:
		push_error("ERROR: Default starting seed '%s' not found in crop_data_map!" % DEFAULT_STARTING_SEEDS_ID)
	
	# Transfer time-capsuled items from the previous loop.
	for item_id in time_capsule_contents:
		add_item_to_inventory(item_id, time_capsule_contents[item_id])
	time_capsule_contents.clear() # Clear capsule contents for the current loop's packing.

	emit_signal("loop_started")
	print("Loop Started! Duration: %.1f sec, Capsule Capacity: %d" % [loop_duration, time_capsule_capacity])


func _end_loop() -> void:
	"""Handles the end-of-loop processes, including milestone checks and rewards."""
	if _check_milestone_met():
		_apply_milestone_reward()
	
	# No longer accumulating Temporal Energy from harvested crops here.
	# Any crop-specific value should be handled directly when harvested or sold.
	# The 'temporal_energy_changed' signal and 'total_temporal_energy' variable are removed.

	emit_signal("loop_ended")
	print("Loop Ended!") # Removed temporal energy display

	# Start the next loop after a brief delay for UI/summary display.
	get_tree().create_timer(1.0).timeout.connect(start_loop)


# --- Inventory & Item Management ---
func add_item_to_inventory(item_id: String, quantity: int = 1) -> void:
	"""Adds items to the current loop's inventory."""
	if not (crop_data_map.has(item_id) or item_data_map.has(item_id)):
		push_warning("Attempted to add unknown item/crop ID to inventory: %s" % item_id)
		return

	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to inventory: %s, quantity: %d" % [item_id, quantity])
		return

	current_inventory[item_id] = current_inventory.get(item_id, 0) + quantity
	emit_signal("inventory_changed", item_id, current_inventory[item_id])
	print("Added %d %s to inventory. Current: %s" % [quantity, item_id, current_inventory])


func remove_item_from_inventory(item_id: String, quantity: int = 1) -> bool:
	"""
	Removes items from the current loop's inventory.
	Returns true if successful, false otherwise (e.g., not enough items).
	"""
	if not (crop_data_map.has(item_id) or item_data_map.has(item_id)):
		push_warning("Attempted to remove unknown item/crop ID from inventory: %s" % item_id)
		return false

	if quantity <= 0:
		push_warning("Attempted to remove non-positive quantity of item from inventory: %s, quantity: %d" % [item_id, quantity])
		return false

	if current_inventory.get(item_id, 0) >= quantity:
		current_inventory[item_id] -= quantity
		if current_inventory[item_id] <= 0:
			current_inventory.erase(item_id)
		emit_signal("inventory_changed", item_id, current_inventory.get(item_id, 0))
		print("Removed %d %s from inventory. Current: %s" % [quantity, item_id, current_inventory])
		return true
	
	print("Not enough %s in inventory to remove %d. Have: %d" % [item_id, quantity, current_inventory.get(item_id, 0)])
	return false # Not enough items


func add_item_to_time_capsule(item_id: String, quantity: int = 1) -> bool:
	"""
	Adds an item to the time capsule for transfer to the next loop.
	Returns true if successful, false if capsule is full or item is invalid.
	"""
	if not (crop_data_map.has(item_id) or item_data_map.has(item_id)):
		push_warning("Attempted to time capsule unknown item/crop ID: %s" % item_id)
		return false

	if quantity <= 0:
		push_warning("Attempted to time capsule non-positive quantity of item: %s, quantity: %d" % [item_id, quantity])
		return false

	# Check capacity based on unique item stacks
	var current_capsule_unique_items: int = time_capsule_contents.size()
	var is_new_stack: bool = not time_capsule_contents.has(item_id)

	if is_new_stack and current_capsule_unique_items >= time_capsule_capacity:
		print("Time capsule is full! Cannot add new unique item stack.")
		return false
	
	time_capsule_contents[item_id] = time_capsule_contents.get(item_id, 0) + quantity
	print("Added %d %s to time capsule. Contents: %s" % [quantity, item_id, time_capsule_contents])
	return true


func add_harvested_crop_to_score(crop_id: String, quantity: int = 1) -> void:
	"""Updates the current loop's score for milestone tracking."""
	if not crop_data_map.has(crop_id):
		push_warning("Attempted to add unknown crop ID to loop score: %s" % crop_id)
		return
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of crop to score: %s, quantity: %d" % [crop_id, quantity])
		return

	current_loop_score[crop_id] = current_loop_score.get(crop_id, 0) + quantity
	print("Harvested %d %s. Current loop score: %s" % [quantity, crop_id, current_loop_score])


# --- Soil Management ---
func _initialize_default_soil_grid(width: int, height: int) -> void:
	"""Initializes the soil grid with default properties."""
	for y in range(height):
		for x in range(width):
			var coords_key: String = str(x) + "," + str(y) # Using string as dictionary key for grid coords
			soil_grid_data[coords_key] = {
				"fertility": 50,
				"moisture": 50,
				"purity": 50
			}
	print("Default soil grid initialized (%dx%d)." % [width, height])


func get_soil_properties(grid_x: int, grid_y: int) -> Dictionary:
	"""Returns the persistent soil properties for a given grid coordinate."""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	return soil_grid_data.get(coords_key, {}) # Return empty dict if coords don't exist


func update_soil_properties(grid_x: int, grid_y: int, changes: Dictionary) -> void:
	"""
	Updates the persistent soil properties for a given grid coordinate.
	Clamps stat values between 0 and 100.
	"""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	if not soil_grid_data.has(coords_key):
		push_warning("Attempted to update soil at non-existent coordinates: (%d,%d)" % [grid_x, grid_y])
		return

	var current_properties: Dictionary = soil_grid_data[coords_key]
	for stat_name: String in changes:
		var new_value: int = current_properties.get(stat_name, 0) + changes[stat_name]
		current_properties[stat_name] = clampi(new_value, 0, 100) # Ensure stats stay within 0-100 bounds
	
	emit_signal("soil_properties_changed", grid_x, grid_y, current_properties)
	print("Soil at (%d,%d) updated: %s" % [grid_x, grid_y, current_properties])


# --- Milestone Management ---
func _set_current_milestone() -> void:
	"""Sets the current active milestone based on `current_milestone_index`."""
	if current_milestone_index < milestone_stages.size():
		current_milestone_data = milestone_stages[current_milestone_index]
		emit_signal("milestone_updated", current_milestone_data)
		print("Current Milestone set: '%s'" % current_milestone_data.get("display_name", "Unknown Milestone"))
	else:
		current_milestone_data.clear() # No more milestones to set.
		print("All defined milestones completed!")


func _check_milestone_met() -> bool:
	"""
	Checks if the requirements for the `current_milestone_data` have been met.
	Returns true if all requirements are fulfilled, false otherwise.
	"""
	if current_milestone_data.is_empty():
		return false # No milestone to check.

	var requirements: Dictionary = current_milestone_data.get("requirements", {})
	var met_all: bool = true

	# --- Check harvested crop requirements ---
	if requirements.has("harvested_crops"):
		var required_crops: Dictionary = requirements["harvested_crops"]
		for crop_id in required_crops:
			if current_loop_score.get(crop_id, 0) < required_crops[crop_id]:
				met_all = false
				print("Milestone requirement not met: Need %d of %s, have %d." % [required_crops[crop_id], crop_id, current_loop_score.get(crop_id, 0)])
				break
		if not met_all:
			return false

	# --- Check average soil quality requirement (remains) ---
	if requirements.has("soil_quality_target_avg"):
		var target_soil_avg: Dictionary = requirements["soil_quality_target_avg"]
		var soil_stat_sums: Dictionary = {"fertility": 0, "moisture": 0, "purity": 0}
		var tile_count: int = soil_grid_data.size()

		if tile_count > 0:
			for coords_key: String in soil_grid_data:
				var props: Dictionary = soil_grid_data[coords_key]
				soil_stat_sums["fertility"] += props.get("fertility", 0)
				soil_stat_sums["moisture"] += props.get("moisture", 0)
				soil_stat_sums["purity"] += props.get("purity", 0)

			for stat_name: String in target_soil_avg:
				var avg_value: float = float(soil_stat_sums.get(stat_name, 0)) / tile_count
				if avg_value < target_soil_avg[stat_name]:
					met_all = false
					print("Milestone requirement not met: Average %s (%.1f) below target (%d)." % [stat_name, avg_value, target_soil_avg[stat_name]])
					break
		else:
			met_all = false # Cannot meet soil quality without any tiles
			print("Milestone requirement not met: No soil tiles to check average quality.")
		if not met_all:
			return false


	if met_all:
		print("Milestone '%s' Met!" % current_milestone_data.get("display_name", "Unknown Milestone"))
	
	return met_all


func _apply_milestone_reward() -> void:
	"""Applies the rewards defined in the `current_milestone_data`."""
	var rewards: Dictionary = current_milestone_data.get("rewards", {})
	
	# No longer applying Temporal Energy reward.
	# Any other form of reward should be specified here.
	# Example: If a milestone simply provides new items, add them directly:
	# if rewards.has("granted_items"):
	#     for item_id: String in rewards["granted_items"]:
	#         add_item_to_inventory(item_id, rewards["granted_items"][item_id])

	# Unlock new plants
	if rewards.has("unlocked_plants"):
		for plant_id: String in rewards["unlocked_plants"]:
			if not unlocked_plant_types.has(plant_id):
				unlocked_plant_types.append(plant_id)
				emit_signal("plant_unlocked", plant_id)
				print("Unlocked plant: %s" % plant_id)

	# Unlock upgrades
	if rewards.has("unlocked_upgrades"):
		for upgrade_id: String in rewards["unlocked_upgrades"]:
			if not unlocked_upgrades.has(upgrade_id):
				unlocked_upgrades.append(upgrade_id)
				emit_signal("upgrade_unlocked", upgrade_id)
				_handle_specific_upgrade_effect(upgrade_id) # Handle immediate effects of upgrades
				print("Unlocked upgrade: %s" % upgrade_id)

	# Increase Time Capsule Capacity
	if rewards.has("time_capsule_capacity_increase"):
		var capacity_increase: int = rewards["time_capsule_capacity_increase"]
		time_capsule_capacity += capacity_increase
		emit_signal("time_capsule_capacity_changed", time_capsule_capacity)
		print("Time Capsule capacity increased to %d." % time_capsule_capacity)
		
	# Increase Loop Duration
	if rewards.has("loop_duration_increase"):
		var duration_increase: float = rewards["loop_duration_increase"]
		loop_duration += duration_increase
		emit_signal("loop_duration_changed", loop_duration)
		print("Loop duration increased to %.1f seconds." % loop_duration)

	# Advance to the next milestone.
	current_milestone_index += 1
	_set_current_milestone()


func _handle_specific_upgrade_effect(upgrade_id: String) -> void:
	"""Handles immediate effects for specific upgrades."""
	match upgrade_id:
		"merger_unlocked":
			print("Merger machine unlocked! (Implement its instantiation/activation)")
		# Add more cases for other specific upgrades (e.g., auto-harvester, new grid size)
		_:
			pass # No specific immediate effect for this upgrade ID


# --- Public Data Accessors ---
func get_crop_data(crop_id: String) -> Dictionary:
	"""Returns the data dictionary for a specific crop ID."""
	return crop_data_map.get(crop_id, {})

func get_item_data(item_id: String) -> Dictionary:
	"""Returns the data dictionary for a specific item ID."""
	return item_data_map.get(item_id, {})

# --- Placeholder for future save/load ---
func save_game() -> void:
	# Implement saving soil_grid_data,
	# unlocked_plant_types, unlocked_upgrades, current_milestone_index,
	# time_capsule_contents, loop_duration, time_capsule_capacity.
	# Use JSON.stringify or Godot's built-in save methods.
	push_warning("Save game functionality not yet implemented.")
	pass

func load_game() -> void:
	# Implement loading logic.
	push_warning("Load game functionality not yet implemented.")
	pass
