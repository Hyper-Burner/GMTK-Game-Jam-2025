# GameManager.gd (AutoLoad Singleton)
extends Node

# --- Constants ---
const DATA_PATH_CROPS: String = "res://TextFiles/crops.json"
const DATA_PATH_ITEMS: String = "res://TextFiles/items.json"
const DATA_PATH_MILESTONES: String = "res://TextFiles/milestones.json"

const DEFAULT_GRID_WIDTH: int = 5
const DEFAULT_GRID_HEIGHT: int = 5
const DEFAULT_LOOP_DURATION: float = 120.0 # seconds
const DEFAULT_TIME_CAPSULE_CAPACITY: int = 3
const DEFAULT_STARTING_SEEDS_ID: String = "Potato" # Now a String ID
const DEFAULT_STARTING_SEEDS_QUANTITY: int = 3

# --- Game Modes (Updated Enum for interaction states) ---
enum GameMode {
	NORMAL,        # Default interaction mode (e.g., general observation, or simple click for inspect)
	PLANTING,     # Player is actively planting objects on the grid
	HARVEST,    
	# Player is actively clicking on mature plants/resources to harvest them
	INSPECT        # Player is actively clicking on objects to view detailed information
}

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
# Persistent dictionary storing the current properties of each soil tile (e.g., {"0,0": {"fertilizer": 50, ...}}).
# This data persists across loops.
var soil_grid_data: Dictionary = {}
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
# Items available in the current loop's inventory (item_id: quantity). Resets each loop.
# Keys are now String.
var current_inventory: Dictionary = {}
# Tracks harvested crops/generated resources *within the current loop* for milestone requirements.
# Resets each loop.
# Keys are now String.
var current_loop_score: Dictionary = {}
# The current active interaction mode of the game.
var current_game_mode: int = GameMode.NORMAL
# The ID of the item currently selected for placement (only relevant in PLACEMENT mode).
var selected_item_for_placement: String = "" # Now a String ("" for no item selected)
# Reference to the separate preview controller instance.
var placement_preview_controller: Node2D = null # Now a direct reference to the controller

var seconds_passed: int = 0

const TILE_SIZE: int = 32 # Example: 32x32 pixel tiles


func _ready() -> void:
	# --- IMPORTANT: REMOVED ALL LOCAL SIGNAL DECLARATIONS.
	# They should be only in Signals.gd. ---

	_load_all_game_data()

	# Initialize soil grid if it's the first run (no saved data loaded).
	if soil_grid_data.is_empty():
		_initialize_default_soil_grid(DEFAULT_GRID_WIDTH, DEFAULT_GRID_HEIGHT)
	
	# Initialize placed items grid if it's the first run (no saved data loaded).
	if placed_items_grid.is_empty():
		_initialize_default_placed_items_grid(DEFAULT_GRID_WIDTH, DEFAULT_GRID_HEIGHT)

	# Set the initial milestone.
	if not milestone_stages.is_empty():
		_set_current_milestone()
	else:
		push_error("ERROR: No milestone stages loaded from '%s'. Game may not progress." % DATA_PATH_MILESTONES)

	# Set the initial game mode.
	set_game_mode(GameMode.NORMAL)
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


func _input(event: InputEvent) -> void:
	# Handle mouse input for grid interaction
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()
	
	# Example keyboard input for mode switching
	if event.is_action_pressed("ui_cancel"): # Escape key is typically mapped to "ui_cancel"
		# If we're in any mode other than
		# NORMAL, pressing Escape goes back to NORMAL.
		if current_game_mode != GameMode.NORMAL:
			set_game_mode(GameMode.NORMAL)
			print("Exited current mode via Escape (ui_cancel).")
	
	# Add keyboard shortcuts for new modes (Remember to define these in Project Settings -> Input Map!)
	if event.is_action_pressed("harvest_mode_key"): # Example: Assign 'H' key
		if current_game_mode != GameMode.HARVEST: # Prevent re-entering if already in mode
			set_game_mode(GameMode.HARVEST)
			print("Switched to Harvest Mode.")

	if event.is_action_pressed("inspect_mode_key"): # Example: Assign 'I' key
		if current_game_mode != GameMode.INSPECT: # Prevent re-entering if already in mode
			set_game_mode(GameMode.INSPECT)
			print("Switched to Inspect Mode.")
	
	# Your UI buttons would call set_game_mode(GameMode.PLANTING, item_id_int) directly.
	# This section is just for example keyboard triggers if you need them during development.
	if event.is_action_pressed("plant_mode_key"):
		# Use DEFAULT_STARTING_SEEDS_ID (which is now String "Potato")
		set_game_mode(GameMode.PLANTING, DEFAULT_STARTING_SEEDS_ID)

# --- Input Handling Helpers ---
func _get_grid_coords_under_mouse(mouse_pos: Vector2) -> Vector2i:
	"""
	Converts global mouse position to grid coordinates.
	Assumes a TileMap or a custom grid system where (0,0) is the top-left of the grid
	and cells are TILE_SIZE by TILE_SIZE.
	If you're using a TileMap, you can use `tilemap.local_to_map(tilemap.to_local(mouse_pos))`
	for more robust tile coordinate conversion.
	"""
	# If you have a TileMap, get its reference and use its methods:
	# var tilemap: TileMap = get_node_or_null("/root/MainScene/TileMap") # Adjust path to your TileMap
	# if tilemap:
	#    var local_mouse_pos = tilemap.to_local(mouse_pos)
	#    var map_coords = tilemap.local_to_map(local_mouse_pos)
	#   
	# Validate map_coords against your game's grid size (DEFAULT_GRID_WIDTH/HEIGHT) if necessary
	#    if map_coords.x >= 0 and map_coords.x < DEFAULT_GRID_WIDTH and map_coords.y >= 0 and map_coords.y < DEFAULT_GRID_HEIGHT:
	#        return map_coords
	#    else:
	#        return Vector2i(-1, -1)

	# Simple direct conversion (assumes global coords map directly to grid, considering TILE_SIZE)
	var grid_x: int = floor(mouse_pos.x / TILE_SIZE)
	var grid_y: int = floor(mouse_pos.y / TILE_SIZE)

	# Validate if within your defined grid bounds (DEFAULT_GRID_WIDTH/HEIGHT)
	if grid_x >= 0 and grid_x < DEFAULT_GRID_WIDTH and grid_y >= 0 and grid_y < DEFAULT_GRID_HEIGHT:
		return Vector2i(grid_x, grid_y)
	
	return Vector2i(-1, -1) # Invalid coordinates


func _handle_left_click(mouse_pos: Vector2) -> void:
	"""Handles left mouse clicks based on the current game mode."""
	var grid_coords: Vector2i = _get_grid_coords_under_mouse(mouse_pos)
	if grid_coords == Vector2i(-1, -1):
		# No valid grid cell under mouse, might be UI click or outside playable area
		print("Left click: No valid grid coordinates under mouse. (Possibly UI click)")
		return

	var grid_x: int = grid_coords.x
	var grid_y: int = grid_coords.y
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	# Now expects String value from placed_items_grid
	var placed_item_id: String = placed_items_grid.get(coords_key, "") # Get ID of item on this tile, if any, use "" for empty
	
	match current_game_mode:
		GameMode.NORMAL:
			print("Normal mode click at (%d,%d)." % [grid_x, grid_y])
			# In normal mode, clicking on a tile might default to inspect if an item is present.
			if not placed_item_id.is_empty(): # Check for empty string instead of -1
				_inspect_item(grid_x, grid_y, placed_item_id)
			else:
				_inspect_soil(grid_x, grid_y) # Inspect soil if no item

		GameMode.PLANTING:
			if not selected_item_for_placement.is_empty(): # Check for empty string
				_place_item(grid_x, grid_y)
			else:
				push_warning("Attempted to click in placement mode but no item selected. Reverting to NORMAL.")
				set_game_mode(GameMode.NORMAL) # Auto-exit if no item is selected for placement

		GameMode.HARVEST:
			print("Harvest mode click at (%d,%d)." % [grid_x, grid_y])
			if not placed_item_id.is_empty(): # Check for empty string
				_harvest_item(grid_x, grid_y, placed_item_id)
			else:
				print("Nothing to harvest at (%d,%d)." % [grid_x, grid_y])
		
		GameMode.INSPECT:
			print("Inspect mode click at (%d,%d)." % [grid_x, grid_y])
			if not placed_item_id.is_empty(): # Check for empty string
				_inspect_item(grid_x, grid_y, placed_item_id)
			else:
				_inspect_soil(grid_x, grid_y)


func _handle_right_click() -> void:
	"""Handles right mouse clicks, typically used for canceling actions or exiting modes."""
	# Right-click cancels the current specific mode and returns to normal.
	if current_game_mode != GameMode.NORMAL:
		set_game_mode(GameMode.NORMAL)
		print("Current mode cancelled via right-click.")
	# No specific action for right-click in normal mode currently, but you could add one.
# --- New Interaction Functions for Harvest/Inspect ---
# item_id is now a String.
func _harvest_item(grid_x: int, grid_y: int, item_id: String) -> void:
	"""
	Handles the harvesting of an item (e.g., a plant) at the given grid coordinates.
	This is a placeholder; you'll need actual plant/resource logic.
	"""
	print("Attempting to harvest item ID %s at (%d,%d)." % [item_id, grid_x, grid_y])
	
	# Retrieve crop data from the dictionary using the String ID.
	var crop_data = get_crop_data(item_id) # Using the helper function
	
	# Check if the item is recognized as a crop and has harvest data.
	if crop_data and crop_data.has("harvest_yield"):
		# In a real game, you'd check the plant's current growth stage here.
		# For now, we assume it's always ready to harvest if it has harvest_yield.
		
		# 1. Determine harvested yield.
		# harvest_yield_item could still be a string ID in JSON, convert to String if needed or handle it here
		var yield_item_display_name = crop_data.get("harvest_yield_item_display_name", crop_data.get("display_name", "Unknown Item"))
		var yield_item_id_str: String = crop_data.get("harvest_yield_item_id", item_id) # Assuming JSON can now have harvest_yield_item_id (String) or default to original item_id
		var yield_quantity = crop_data.get("harvest_yield", 1)

		# 2. Add harvested items to inventory and current loop score.
		add_item_to_inventory(yield_item_id_str, yield_quantity) # Pass String ID
		add_harvested_crop_to_score(yield_item_id_str, yield_quantity) # Pass String ID

		# 3. Remove the plant from the grid (or revert it to a 'seedling' state, or make it regrow).
		# For simplicity, we'll remove it entirely.
		_remove_item_from_grid(grid_x, grid_y)

		print("Successfully harvested %d x %s (ID %s) from (%d,%d)." % [yield_quantity, yield_item_display_name, yield_item_id_str, grid_x, grid_y])
	else:
		print("Item ID %s at (%d,%d) is not recognized as a harvestable crop or has no harvest yield defined." % [item_id, grid_x, grid_y])

# item_id is now a String.
func _inspect_item(grid_x: int, grid_y: int, item_id: String) -> void:
	"""
	Displays detailed information about an item (plant or machine) at the given grid coordinates.
	You'd typically open a UI panel here with dynamic data.
	"""
	print("Inspecting item ID %s at (%d,%d)." % [item_id, grid_x, grid_y])
	
	# Retrieve data using the String ID.
	var item_data = get_item_data(item_id) # Using helper function

	if item_data:
		print("--- %s Details (ID: %s) ---" % [item_data.get("display_name", "Unknown Item"), item_id])
		for key in item_data:
			print("  %s: %s" % [key, item_data[key]])
		
		# You could add runtime properties here, e.g., if it's a plant, its current growth stage.
		# Example:
		# var plant_instance_node = _get_2d_instance_at_grid(grid_x, grid_y) # You'd need to implement this
		# if plant_instance_node and plant_instance_node.has_method("get_growth_stage"):
		#     print("  Growth Stage: %s" % plant_instance_node.get_growth_stage())

		print("--------------------")
		# Future: Emit a signal to your UI to open an info panel:
		# Signals.display_item_info.emit(item_id, item_data, grid_x, grid_y) # Corrected emit syntax
	else:
		print("No data found for item ID: %s." % item_id)

func _inspect_soil(grid_x: int, grid_y: int) -> void:
	"""
	Displays detailed information about the soil at the given grid coordinates.
	You'd typically open a UI panel here with soil properties.
	"""
	print("Inspecting soil at (%d,%d)." % [grid_x, grid_y])
	var soil_props = get_soil_properties(grid_x, grid_y)
	if soil_props:
		print("--- Soil Details (%d,%d) ---" % [grid_x, grid_y])
		for key in soil_props:
			print("  %s: %s" % [key, soil_props[key]])
		print("-------------------------")
		# Future: Emit a signal to your UI to open a soil info panel:
		# Signals.display_soil_info.emit(grid_x, grid_y, soil_props) # Corrected emit syntax
	else:
		print("No soil data found for (%d,%d)." % [grid_x, grid_y])

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
	current_inventory.clear()       # Clear transient inventory for the new loop.
	current_loop_score.clear()      # Reset loop score for milestone checks (progress must be made
	# in current loop).
	# Add default starting seeds for the loop.
	# No validation if user doesn't want it.
	# Assumes DEFAULT_STARTING_SEEDS_ID is always valid.
	add_item_to_inventory(DEFAULT_STARTING_SEEDS_ID, DEFAULT_STARTING_SEEDS_QUANTITY)
	
	# Transfer time-capsuled items from the previous loop.
	# time_capsule_contents keys are now String.
	for item_id_str in time_capsule_contents:
		add_item_to_inventory(item_id_str, time_capsule_contents[item_id_str])
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


# --- Inventory & Item Management ---
# item_id is now a String.
func add_item_to_inventory(item_id: String, quantity: int = 1) -> void:
	"""Adds items to the current loop's inventory."""
	# No validation if user doesn't want it.
	# The `if not (...) return` block is entirely removed.
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to inventory: ID %s, quantity: %d" % [item_id, quantity])
		return

	current_inventory[item_id] = current_inventory.get(item_id, 0) + quantity
	# EMIT GLOBAL SIGNAL
	Signals.inventory_changed.emit(item_id, current_inventory[item_id])
	print("Added %d x ID %s to inventory. Current: %s" % [quantity, item_id, current_inventory])

# item_id is now a String.
func remove_item_from_inventory(item_id: String, quantity: int = 1) -> bool:
	"""Removes items from the current loop's inventory."""
	if not current_inventory.has(item_id) or current_inventory[item_id] < quantity:
		push_warning("Not enough of item ID %s in inventory to remove %d. Current: %d" % [item_id, quantity, current_inventory.get(item_id, 0)])
		return false
	
	current_inventory[item_id] -= quantity
	if current_inventory[item_id] <= 0:
		current_inventory.erase(item_id)
	
	# EMIT GLOBAL SIGNAL
	Signals.inventory_changed.emit(item_id, current_inventory.get(item_id, 0))
	print("Removed %d x ID %s from inventory. Current: %s" % [quantity, item_id, current_inventory])
	return true

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
	
	# If we have enough in inventory, move it to time capsule.
	# This emits inventory_changed.
	if remove_item_from_inventory(item_id, quantity):
		time_capsule_contents[item_id] = time_capsule_contents.get(item_id, 0) + quantity
		print("Added %d x ID %s to time capsule. Current capsule: %s" % [quantity, item_id, time_capsule_contents])
		return true
	
	print("Failed to add %d x ID %s to time capsule (insufficient inventory)." % [quantity, item_id])
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

# --- Soil Management ---
func _initialize_default_soil_grid(width: int, height: int) -> void:
	"""Initializes a default soil grid with basic properties."""
	soil_grid_data.clear()
	for y in range(height):
		for x in range(width):
			var coords_key: String = str(x) + "," + str(y)
			soil_grid_data[coords_key] = {"fertilizer": 100, "hydration": 100, "nitrogen": 100} # Added hydration, nitrogen
	print("Initialized default soil grid (%dx%d)." % [width, height])


func _initialize_default_placed_items_grid(width: int, height: int) -> void:
	"""Initializes a default grid for placed items, all empty."""
	placed_items_grid.clear()
	for y in range(height):
		for x in range(width):
			var coords_key: String = str(x) + "," + str(y)
			placed_items_grid[coords_key] = "" # Use empty string for empty, instead of -1 if items are strings
	print("Initialized default placed items grid (%dx%d)." % [width, height])


func get_soil_properties(grid_x: int, grid_y: int) -> Dictionary:
	"""Returns the soil properties for a given grid cell."""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	return soil_grid_data.get(coords_key, {}) # Return empty dict if not found

# item_id is now a String.
func get_crop_data(item_id: String) -> Dictionary:
	"""Returns crop data for a given String ID."""
	return crop_data_map.get(item_id, {}) # Use .get() with default to prevent error

# item_id is now a String.
func get_item_data(item_id: String) -> Dictionary:
	"""Returns general item data for a given String ID."""
	return item_data_map.get(item_id, {}) # Use .get() with default to prevent error

func update_soil_properties(grid_x: int, grid_y: int, new_properties: Dictionary) -> void:
	"""Updates soil properties for a tile and emits a signal."""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	var current_props = soil_grid_data.get(coords_key, {})
	current_props.update(new_properties) # Merge new properties
	soil_grid_data[coords_key] = current_props
	# EMIT GLOBAL SIGNAL
	Signals.soil_properties_changed.emit(grid_x, grid_y, current_props)
	print("Soil properties updated at (%d,%d): %s" % [grid_x, grid_y, current_props])

# selected_item_for_placement is now a String.
func _place_item(grid_x: int, grid_y: int) -> void:
	"""
	Handles placing an item on the grid.
	Assumes `selected_item_for_placement` (now a String ID) is set.
	"""
	if selected_item_for_placement.is_empty(): # No item selected
		push_warning("Cannot place: No item selected for placement.")
		return
	
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	
	if not placed_items_grid.get(coords_key, "").is_empty(): # Cell already occupied (check for empty string)
		print("Cannot place: Cell at (%d,%d) is already occupied by ID %s." % [grid_x, grid_y, placed_items_grid[coords_key]])
		return

	# Check inventory for the item (now a String ID).
	if not current_inventory.has(selected_item_for_placement) or current_inventory[selected_item_for_placement] <= 0:
		print("Cannot place: Item ID %s not in inventory or insufficient quantity." % selected_item_for_placement)
		return

	# Deduct from inventory.
	# This emits inventory_changed.
	if not remove_item_from_inventory(selected_item_for_placement, 1):
		print("Failed to place item ID %s at (%d,%d): Inventory deduction failed." % [selected_item_for_placement, grid_x, grid_y])
		return

	# Place the item (its ID) in the grid data.
	placed_items_grid[coords_key] = selected_item_for_placement
	print("Placed item ID %s at (%d,%d)." % [selected_item_for_placement, grid_x, grid_y])

	# After successful placement, emit the signal for visual placement
	# This signal will be received by tile_maps.gd to instantiate the visual
	Signals.plant_seed.emit(selected_item_for_placement) # Emitting with item_id, grid_x, grid_y

	# After successful placement, you typically remain in placement mode to allow rapid placement.
	# To revert to normal automatically after one placement: set_game_mode(GameMode.NORMAL)
	# For now, let's assume one placement per click, then back to normal or pick a new item.
	# set_game_mode(GameMode.NORMAL) # Removed this line to allow continuous placement


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
		if not met_all:
			return false

	# --- Check average soil
	# quality requirement (remains) ---
	if requirements.has("soil_quality_target_avg"):
		var target_soil_avg: Dictionary = requirements["soil_quality_target_avg"] # Corrected from soil_soil_quality_target_avg
		var soil_stat_sums: Dictionary = {"fertilizer": 0, "hydration": 0, "nitrogen": 0}
		var tile_count: int = soil_grid_data.size()

		if tile_count > 0:
			for coords_key: String in soil_grid_data:
				var props: Dictionary = soil_grid_data[coords_key]
				soil_stat_sums["fertilizer"] += props.get("fertilizer", 0)
				soil_stat_sums["hydration"] += props.get("hydration", 0)
				soil_stat_sums["nitrogen"] += props.get("nitrogen", 0)

			for stat_name: String in target_soil_avg:
				var avg_value: float = float(soil_stat_sums.get(stat_name, 0)) / tile_count
				if avg_value < target_soil_avg[stat_name]:
					met_all = false
					print("Milestone requirement not met: Average %s (%.1f) below target (%d)." % [stat_name, avg_value, target_soil_avg[stat_name]])
					break
		else:
			met_all = false # Cannot meet soil quality without any tiles.
			print("Milestone requirement not met: No soil tiles to check average quality.")
		if not met_all:
			return false

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
func set_game_mode(mode: int, item_id_for_placement: String = "") -> void: # item_id_for_placement is String, default ""
	"""
	Sets the current game interaction mode.
	If mode is PLANTING, `item_id_for_placement` should be the ID of the item to plant.
	"""
	if current_game_mode == mode and selected_item_for_placement == item_id_for_placement: # Compare String
		return # Already in this mode with this item

	var old_mode = current_game_mode
	current_game_mode = mode
	selected_item_for_placement = item_id_for_placement # Store the String ID

	# EMIT GLOBAL SIGNAL
	Signals.game_mode_changed.emit(current_game_mode)

	match current_game_mode:
		GameMode.NORMAL:
			# Emit the GLOBAL signal
			Signals.planting_mode_exited.emit()
			print("Game Mode: NORMAL")
		GameMode.PLANTING:
			# Emit the GLOBAL signal, passing the item_id (now String)
			if not selected_item_for_placement.is_empty(): # Ensure a valid item is selected
				Signals.planting_mode_entered.emit(selected_item_for_placement)
				print("Game Mode: PLANTING with item ID: %s" % selected_item_for_placement)
			else:
				push_warning("Attempted to enter PLANTING mode without a valid item ID. Reverting to NORMAL.")
				set_game_mode(GameMode.NORMAL) # Revert if no item provided for planting
		GameMode.HARVEST:
			Signals.harvest_mode_active.emit()
			print("Game Mode: HARVEST")
		GameMode.INSPECT:
			Signals.inspect_mode_active.emit()
			print("Game Mode: INSPECT")
		_:
			push_warning("Attempted to set unrecognized game mode: %s" % mode)


# --- Placement Preview Management ---
func _send_placement_preview_update() -> void:
	"""
	Communicates with the placement preview controller (e.g., your tile_maps.gd)
	to update the visual preview of where an item would be placed.
	"""
	if not placement_preview_controller:
		# Search for the controller if not set, assuming a common node structure
		# You might need to adjust the path to your tile_maps.gd instance
		# It's good practice to add your tile_maps.gd node to a group, e.g., "placement_visuals"
		placement_preview_controller = get_tree().get_first_node_in_group("placement_visuals")
		if not placement_preview_controller:
			push_error("Placement Preview Controller not found! Add your tile_maps.gd instance to 'placement_visuals' group.")
			return

	var mouse_pos = get_viewport().get_mouse_position()
	var grid_coords = _get_grid_coords_under_mouse(mouse_pos)
	
	var is_valid_placement = false
	if grid_coords != Vector2i(-1, -1):
		var coords_key: String = str(grid_coords.x) + "," + str(grid_coords.y)
		# Valid if cell is empty.
		is_valid_placement = placed_items_grid.get(coords_key, "").is_empty() # Check for empty string

	# EMIT GLOBAL SIGNAL
	Signals.update_placement_preview.emit(grid_coords, is_valid_placement) # Emitting with new ID logic implicitly


# --- Placeholder for future save/load ---
func save_game() -> void:
	"""
	Placeholder for saving game state.
	Implement logic to save: soil_grid_data, unlocked_plant_types, unlocked_upgrades,
	time_capsule_contents, loop_duration, current_milestone_index.
	You'll need to convert these to a savable format (e.g., JSON).
	"""
	var save_data: Dictionary = {
		"soil_grid_data": soil_grid_data,
		"placed_items_grid": placed_items_grid, # Also needs to be saved/loaded
		"unlocked_plant_types": unlocked_plant_types,
		"unlocked_upgrades": unlocked_upgrades,
		"time_capsule_contents": time_capsule_contents,
		"loop_duration": loop_duration,
		"current_milestone_index": current_milestone_index,
		"current_inventory": current_inventory, # Optionally save current inventory
		"current_loop_score": current_loop_score # Optionally save current score
	}
	
	var file_path: String = "user://game_save.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("Game saved to %s" % file_path)
	else:
		push_error("Could not open file for saving: %s" % file_path)

func load_game() -> void:
	"""
	Placeholder for loading game state.
	Implement logic to load from a save file.
	"""
	var file_path: String = "user://game_save.json"
	if not FileAccess.file_exists(file_path):
		print("No save game found at %s." % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var parsed_data = JSON.parse_string(json_string)
		
		if parsed_data is Dictionary:
			# Load data into your variables. Ensure type safety.
			soil_grid_data = parsed_data.get("soil_grid_data", {})
			placed_items_grid = parsed_data.get("placed_items_grid", {}) # Load this
			unlocked_plant_types = parsed_data.get("unlocked_plant_types", [])
			unlocked_upgrades = parsed_data.get("unlocked_upgrades", [])
			time_capsule_contents = parsed_data.get("time_capsule_contents", {})
			loop_duration = parsed_data.get("loop_duration", DEFAULT_LOOP_DURATION)
			current_milestone_index = parsed_data.get("current_milestone_index", 0)
			current_inventory = parsed_data.get("current_inventory", {})
			current_loop_score = parsed_data.get("current_loop_score", {})
			
			print("Game loaded from %s." % file_path)
			# Re-initialize game based on loaded state (e.g., restart loop, update UI).
			_set_current_milestone() # Refresh milestone display
			# You might need to set game mode based on loaded state or simply start loop.
			start_loop()
		else:
			push_error("Error parsing save file: Invalid JSON format.")
	else:
		push_error("Could not open file for loading: %s" % file_path)

func _on_timeout():
	seconds_passed += 1
	emit_signal("time_updated", seconds_passed, seconds_passed)
