# GameManager.gd (AutoLoad Singleton)
extends Node

# --- Constants ---
const DATA_PATH_CROPS: String = "res://TextFiles/crops.json"
const DATA_PATH_ITEMS: String = "res://TextFiles/items.json"
const DATA_PATH_MILESTONES: String = "res://TextFiles/milestones.json"

const DEFAULT_LOOP_DURATION: float = 5 # seconds
const DEFAULT_TIME_CAPSULE_CAPACITY: int = 4

const DEFAULT_STARTING_SEEDS_ID: String = "Potato"

# --- Game Data Definitions (Loaded from JSON files) ---
# Now a Dictionary, where key is the item ID (String).
var crop_data_map: Dictionary = {}
# Now a Dictionary, where key is the item ID (String).
var item_data_map: Dictionary = {}
# Stores all milestone definitions. Key is the milestone name (String), value is the milestone data Dictionary.
var milestone_stages: Dictionary = {} # <--- CHANGED THIS TO DICTIONARY

# --- Persistent Game State ---
# Stores String IDs.
var unlocked_plant_types: Array[String] = [DEFAULT_STARTING_SEEDS_ID] # Starts with basic seed unlocked.
# List of upgrade IDs that the player has permanently unlocked.
var unlocked_upgrades: Array[String] = [] # Assuming upgrade IDs remain strings
# The current maximum number of unique item stacks that can be sent to the next loop.
var time_capsule_capacity: int = DEFAULT_TIME_CAPSULE_CAPACITY
# The contents to be transferred to the NEXT loop (item_id: quantity).

# Persistent dictionary storing which items are placed on each grid tile (e.g., {"0,0": item_id_string}).
# This data also persists across loops. Values are now String (or "" for empty).
var placed_items_grid: Dictionary = {}
# The current total duration of a single time loop. Can be upgraded.
var loop_duration: float = DEFAULT_LOOP_DURATION


# --- Volatile / Current Loop State ---
# The remaining time in the current loop.
var current_loop_time: float = 0.0
var pre_loop_done: bool

# The ID of the item currently selected for placement (only relevant in PLACEMENT mode).
var selected_item_for_placement: String = "" # Now a String ("" for no item selected)
# Reference to the separate preview controller instance.
var seconds_passed: int = 0


func _ready() -> void:
	# --- IMPORTANT: REMOVED ALL LOCAL SIGNAL DECLARATIONS.
	# They should be only in Signals.gd. ---

	_load_all_game_data()
	Inventory.reset_inventory()
	Signals.loop_continued.connect(_pre_loop)
	Signals.pre_loop_ready.connect(_pre_loop)
	Signals.pre_loop_done.connect(start_loop)
	# Set the initial milestone.
	if not milestone_stages.is_empty():
		# IMPORTANT: We need to set the initial milestone by its key (e.g., "First Harvest")
		# You'll need a way to determine the starting milestone key.
		# For simplicity, let's assume the first key in the loaded dictionary.
		var first_milestone_key = milestone_stages.keys()[0] if not milestone_stages.is_empty() else ""
		if not first_milestone_key.is_empty():
			Milestone.current_milestone_index = 0 # This will still be used to track progress
			Milestone._set_current_milestone_by_key(first_milestone_key) # <--- NEW FUNCTION CALL
		else:
			push_error("ERROR: No starting milestone found in '%s'. Game may not progress." % DATA_PATH_MILESTONES)
	else:
		push_error("ERROR: No milestone stages loaded from '%s'. Game may not progress." % DATA_PATH_MILESTONES)
	
	
func _pre_loop():
	pre_loop_done = false
	current_loop_time = loop_duration
	Signals.timer_updated.emit(current_loop_time,loop_duration)
	Signals.in_pre_loop.emit()

func _process(delta: float) -> void: # Changed to _process for smoother mouse following
	# Update game loop timer
	if current_loop_time > 0 && pre_loop_done:
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
		return {} # <--- Return empty Dictionary for milestone_stages, which is now a Dict
	var file: FileAccess = FileAccess.open(path, FileAccess.READ) #
	if not file:
		push_error("ERROR: Could not open JSON file for reading: %s" % path)
		return {} # <--- Return empty Dictionary
	var json_string: String = file.get_as_text() #
	file.close()

	var json_parser = JSON.new() # Create an instance of the JSON utility class for parsing.
	# In Godot 4, parse_string returns the parsed data on success, or null on failure.
	# Error details are retrieved from the JSON parser object itself.
	var parsed_data = json_parser.parse_string(json_string) #

	if parsed_data == null: # Check if parsing failed (result is null)
		push_error("ERROR: Could not parse JSON from %s. Parse Error: %s at line %d" % [path, json_parser.get_error_message(), json_parser.get_error_line()])
		return {} # Return empty Dictionary on parsing error.
	# This check is useful if the JSON *parsed* successfully but the content itself was just "null".
	# However, it's harmless and can act as a fallback.
	# Removed the `push_error` for null data object, as it's not strictly an error if the user provides an empty array.
	return parsed_data #

func _load_all_game_data() -> void:
	# Load Crop Data
	var loaded_crops_dict: Dictionary = _load_json_data(DATA_PATH_CROPS)
	if loaded_crops_dict is Dictionary:
		crop_data_map.clear() # Clear existing data
		for crop_id_str in loaded_crops_dict.keys(): # Iterate keys for dict
			var crop_def = loaded_crops_dict[crop_id_str]
			if crop_def is Dictionary: # Removed the .has("name") check if the key IS the name
				if crop_data_map.has(crop_id_str):
					push_warning("Duplicate crop ID found: %s in %s. Skipping." % [crop_id_str, DATA_PATH_CROPS])
					continue
				crop_data_map[crop_id_str] = crop_def # Use key as the ID
			else:
				push_warning("Crop definition in '%s' for ID '%s' is invalid format: %s" % [DATA_PATH_CROPS, crop_id_str, typeof(crop_def)])
	else:
		push_warning("Crop data in '%s' is not a Dictionary, expecting Dictionary. Received: %s" % [DATA_PATH_CROPS, typeof(loaded_crops_dict)])


	# Load Item Data
	var loaded_items_dict: Dictionary = _load_json_data(DATA_PATH_ITEMS)
	if loaded_items_dict is Dictionary:
		item_data_map.clear() # Clear existing data
		for item_id_str in loaded_items_dict.keys(): # Iterate keys for dict
			var item_def = loaded_items_dict[item_id_str]
			if item_def is Dictionary: # Removed the .has("name") check if the key IS the name
				if item_data_map.has(item_id_str):
					push_warning("Duplicate item ID found: %s in %s. Skipping." % [item_id_str, DATA_PATH_ITEMS]) #
					continue
				item_data_map[item_id_str] = item_def # Use key as the ID
			else:
				push_warning("Item definition in '%s' for ID '%s' is invalid format: %s" % [DATA_PATH_ITEMS, item_id_str, typeof(item_def)])
	else:
		push_warning("Item data in '%s' is not a Dictionary, expecting Dictionary. Received: %s" % [DATA_PATH_ITEMS, typeof(loaded_items_dict)])

	# Load Milestone Data
	var loaded_milestones_dict: Dictionary = _load_json_data(DATA_PATH_MILESTONES)
	if loaded_milestones_dict is Dictionary: # <--- Expecting Dictionary
		milestone_stages.clear()
		milestone_stages = loaded_milestones_dict # <--- Assign the whole dictionary
	else:
		push_warning("Milestone data in '%s' is not a Dictionary, expecting Dictionary. Received: %s" % [DATA_PATH_MILESTONES, typeof(loaded_milestones_dict)]) #

	print("Loaded %d crop definitions." % crop_data_map.size())
	print("Loaded %d item definitions." % item_data_map.size())
	print("Loaded %d milestone stages." % milestone_stages.size())


# --- Loop Management ---
func start_loop() -> void:
	"""Initiates a new game loop, resetting transient states and delivering time-capsuled items."""
	pre_loop_done = true
	print("before reset",Inventory.seed_inventory)
	Inventory.reset_inventory()       # Clear transient inventory for the new loop.
	Milestone.current_loop_score.clear()
	
	#test time_capsule items
	#Inventory.time_capsule_inventory = { "sig" : 69 }
	# Transfer time-capsuled items from the previous loop.
	for key in Inventory.time_capsule_inventory:
		Inventory.add_item_to_inventory(Inventory.seed_inventory, str(key), Inventory.time_capsule_inventory[key])

	print(Inventory.seed_inventory)
	print(Inventory.time_capsule_inventory)
	Inventory.time_capsule_inventory.clear() # Clear capsule contents for the current loop's packing.
	# EMIT GLOBAL SIGNAL
	Signals.loop_started.emit()

func _end_loop() -> void:
	"""
	Handles the end-of-loop processes, including milestone checks and rewards.
	Soil stats persist automatically as they are not reset here.
	"""
	# Check if the current milestone's requirements have been met.
	if Milestone._check_milestone_met():
		Milestone._apply_milestone_reward()
	
	# EMIT GLOBAL SIGNAL
	Signals.loop_ended.emit()
	print("Loop Ended!")

	# Start the next loop after a brief delay (e.g., for showing a summary screen).
	# get_tree().create_timer(1.0).timeout.connect(start_loop)

# item_id is now a String.


func _on_timeout():
	seconds_passed += 1
	emit_signal("time_updated", seconds_passed, seconds_passed)
