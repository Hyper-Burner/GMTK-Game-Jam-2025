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
# --- New Signals for Game Modes ---
# Emitted when the current active game interaction mode changes.
signal game_mode_changed(new_mode: int)
# Emitted when placement mode is activated for a specific item.
signal placement_mode_active(item_id: String)
# Emitted when placement mode is exited (e.g., by canceling or placing).
signal placement_mode_exited()
# Emitted when Harvest mode is activated (useful for UI cursor changes).
signal harvest_mode_active()
# Emitted when Inspect mode is activated (useful for UI cursor changes).
signal inspect_mode_active()


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

# --- Game Modes (Updated Enum for interaction states) ---
enum GameMode {
	NORMAL,        # Default interaction mode (e.g., general observation, or simple click for inspect)
	PLACEMENT,     # Player is actively placing objects on the grid
	HARVEST,       # Player is actively clicking on mature plants/resources to harvest them
	INSPECT        # Player is actively clicking on objects to view detailed information
}

# --- Game Data Definitions (Loaded from JSON files) ---
# Stores all crop/plant definitions, keyed by their 'id'.
var crop_data_map: Dictionary = {}
# Stores all general item definitions, keyed by their 'id'.
var item_data_map: Dictionary = {}
# Stores all milestone definitions in the order they should be progressed.
var milestone_stages: Array[Dictionary] = []

# --- Persistent Game State ---
# List of plant IDs that the player has permanently unlocked.
var unlocked_plant_types: Array[String] = [DEFAULT_STARTING_SEEDS_ID] # Starts with basic seed unlocked.
# List of upgrade IDs that the player has permanently unlocked.
var unlocked_upgrades: Array[String] = []
# The current maximum number of unique item stacks that can be sent to the next loop.
var time_capsule_capacity: int = DEFAULT_TIME_CAPSULE_CAPACITY
# The contents to be transferred to the NEXT loop (item_id: quantity). Cleared at start of each loop.
var time_capsule_contents: Dictionary = {}
# Persistent dictionary storing the current properties of each soil tile (e.g., {"0,0": {"fertility": 50, ...}}).
# This data persists across loops.
var soil_grid_data: Dictionary = {}
# Persistent dictionary storing which items are placed on each grid tile (e.g., {"0,0": "plant_id"}).
# This data also persists across loops.
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
var current_inventory: Dictionary = {}
# Tracks harvested crops/generated resources *within the current loop* for milestone requirements. Resets each loop.
var current_loop_score: Dictionary = {}
# The current active interaction mode of the game.
var current_game_mode: int = GameMode.NORMAL
# The ID of the item currently selected for placement (only relevant in PLACEMENT mode).
var selected_item_for_placement: String = ""
# Reference to the visual preview instance (ghost object) shown during placement.
var placement_preview_instance: Node3D = null

# --- Preload Scene for Placement Preview ---
# Make sure to create this scene! It's a visual cue for placing objects.
# Example: a Node3D with a MeshInstance3D (e.g., CubeMesh) and a transparent material.
#const PLACEMENT_PREVIEW_SCENE: PackedScene = preload("res://Scenes/PlacementPreview.tscn")


func _ready() -> void:
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


func _physics_process(delta: float) -> void:
	# Update game loop timer
	if current_loop_time > 0:
		current_loop_time -= delta
		emit_signal("timer_updated", current_loop_time, loop_duration)
		if current_loop_time <= 0:
			current_loop_time = 0.0 # Ensure it doesn't go negative
			_end_loop()

	# Update placement preview position if in placement mode
	if current_game_mode == GameMode.PLACEMENT and placement_preview_instance:
		_update_placement_preview_position()


func _input(event: InputEvent) -> void:
	# Handle mouse input for grid interaction
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()
	
	# Example keyboard input for mode switching
	if event.is_action_pressed("ui_cancel"): # Escape key is typically mapped to "ui_cancel"
		# If we're in any mode other than NORMAL, pressing Escape goes back to NORMAL.
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
	
	# Your UI buttons would call set_game_mode(GameMode.PLACEMENT, "item_id") directly.
	# This section is just for example keyboard triggers if you need them during development.


# --- Input Handling Helpers ---
func _get_grid_coords_under_mouse(mouse_pos: Vector2) -> Vector2i:
	"""
	Performs a raycast from the camera through the mouse position to the 3D world.
	Assumes a flat ground plane or a `CollisionShape3D` on your grid objects.
	Returns Vector2i(grid_x, grid_y) or Vector2i(-1, -1) if no valid grid hit.
	Adjust `hit_position.x` and `hit_position.z` conversion if your grid origin/cell size differs.
	"""
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return Vector2i(-1, -1)

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	# Ray length; adjust based on your scene scale.
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 1000

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collide_with_areas = true # Ray will detect Area3Ds
	query.collide_with_bodies = true # Ray will detect PhysicsBody3Ds (e.g., StaticBody3D for ground)

	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		var hit_position: Vector3 = result.position
		# Convert world position to grid coordinates (assuming 1x1 grid cells centered at integers)
		var grid_x: int = round(hit_position.x)
		var grid_y: int = round(hit_position.z) # Assuming Z is your 'depth' axis for a top-down view
		return Vector2i(grid_x, grid_y)
	
	return Vector2i(-1, -1)


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
	var placed_item_id: String = placed_items_grid.get(coords_key, "") # Get ID of item on this tile, if any
	
	match current_game_mode:
		GameMode.NORMAL:
			print("Normal mode click at (%d,%d)." % [grid_x, grid_y])
			# In normal mode, clicking on a tile might default to inspect if an item is present.
			if placed_item_id:
				_inspect_item(grid_x, grid_y, placed_item_id)
			else:
				_inspect_soil(grid_x, grid_y) # Inspect soil if no item

		GameMode.PLACEMENT:
			if selected_item_for_placement:
				_place_item(grid_x, grid_y)
			else:
				push_warning("Attempted to click in placement mode but no item selected. Reverting to NORMAL.")
				set_game_mode(GameMode.NORMAL) # Auto-exit if no item is selected for placement

		GameMode.HARVEST:
			print("Harvest mode click at (%d,%d)." % [grid_x, grid_y])
			if placed_item_id:
				_harvest_item(grid_x, grid_y, placed_item_id)
			else:
				print("Nothing to harvest at (%d,%d)." % [grid_x, grid_y])
		
		GameMode.INSPECT:
			print("Inspect mode click at (%d,%d)." % [grid_x, grid_y])
			if placed_item_id:
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
func _harvest_item(grid_x: int, grid_y: int, item_id: String) -> void:
	"""
	Handles the harvesting of an item (e.g., a plant) at the given grid coordinates.
	This is a placeholder; you'll need actual plant/resource logic.
	"""
	print("Attempting to harvest %s at (%d,%d)." % [item_id, grid_x, grid_y])
	
	# Retrieve crop data. Assume only crops are harvestable in this example.
	var crop_data = crop_data_map.get(item_id)
	
	# Check if the item is recognized as a crop and has harvest data.
	if crop_data and crop_data.has("harvest_yield"):
		# In a real game, you'd check the plant's current growth stage here.
		# For now, we assume it's always ready to harvest if it has harvest_yield.
		
		# 1. Determine harvested yield.
		var yield_item_id = crop_data.get("harvest_yield_item", item_id) # Default to harvesting itself if no specific item defined
		var yield_quantity = crop_data.get("harvest_yield", 1) # Default to 1 if quantity not defined

		# 2. Add harvested items to inventory and current loop score.
		add_item_to_inventory(yield_item_id, yield_quantity)
		add_harvested_crop_to_score(yield_item_id, yield_quantity)

		# 3. Remove the plant from the grid (or revert it to a 'seedling' state, or make it regrow).
		# For simplicity, we'll remove it entirely.
		_remove_item_from_grid(grid_x, grid_y)

		print("Successfully harvested %d x %s from (%d,%d)." % [yield_quantity, yield_item_id, grid_x, grid_y])
	else:
		print("Item '%s' at (%d,%d) is not recognized as a harvestable crop or has no harvest yield defined." % [item_id, grid_x, grid_y])


func _inspect_item(grid_x: int, grid_y: int, item_id: String) -> void:
	"""
	Displays detailed information about an item (plant or machine) at the given grid coordinates.
	You'd typically open a UI panel here with dynamic data.
	"""
	print("Inspecting item '%s' at (%d,%d)." % [item_id, grid_x, grid_y])
	
	# Try to get data from crop_data_map first, then item_data_map.
	var item_data = crop_data_map.get(item_id)
	if not item_data:
		item_data = item_data_map.get(item_id)

	if item_data:
		print("--- %s Details ---" % item_data.get("display_name", item_id))
		for key in item_data:
			print("  %s: %s" % [key, item_data[key]])
		
		# You could add runtime properties here, e.g., if it's a plant, its current growth stage.
		# Example:
		# var plant_instance_node = _get_3d_instance_at_grid(grid_x, grid_y)
		# if plant_instance_node and plant_instance_node.has_method("get_growth_stage"):
		#     print("  Growth Stage: %s" % plant_instance_node.get_growth_stage())

		print("--------------------")
		# Future: Emit a signal to your UI to open an info panel:
		# emit_signal("display_item_info", item_id, item_data, grid_x, grid_y)
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
		# emit_signal("display_soil_info", grid_x, grid_y, soil_props)
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
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ERROR: Could not open JSON file for reading: %s" % path)
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var json_parser = JSON.new() # Create an instance of the JSON utility class for parsing.
	var parse_result = json_parser.parse_string(json_string) # Use the instance to parse.

	if parse_result != OK: # Check if the parsing process itself failed (e.g., malformed JSON syntax).
		push_error("ERROR: Could not parse JSON from %s. Parse Error: %s at line %d" % [path, json_parser.get_error_message(), json_parser.get_error_line()])
		return {} # Return empty dict/array on parsing error.

	# The actual parsed data is stored in the 'data' property of the parser instance.
	var parsed_data = json_parser.data

	# This check is useful if the JSON *parsed* successfully but the content itself was just "null".
	if parsed_data == null:
		push_error("ERROR: JSON file '%s' parsed successfully but resulted in a null data object. Content might be 'null'." % path)
		# Assuming most config JSONs will be objects/arrays, returning empty dict is a safer default.
		return {}

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
	current_loop_time = loop_duration # Reset timer for the new loop.
	current_inventory.clear()       # Clear transient inventory for the new loop.
	current_loop_score.clear()      # Reset loop score for milestone checks (progress must be made in current loop).

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
	"""
	Handles the end-of-loop processes, including milestone checks and rewards.
	Soil stats persist automatically as they are not reset here.
	"""
	# Check if the current milestone's requirements have been met.
	if _check_milestone_met():
		_apply_milestone_reward()
	
	# The accumulation of Temporal Energy from harvested crops has been removed.
	# Any value from crops would now be handled via direct inventory/currency systems.

	emit_signal("loop_ended")
	print("Loop Ended!") # Removed Temporal Energy display as it's no longer tracked.

	# Start the next loop after a brief delay (e.g., for showing a summary screen).
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
	"""
	Updates the current loop's score for milestone tracking.
	This score is reset at the start of each new loop.
	"""
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


func _initialize_default_placed_items_grid(width: int, height: int) -> void:
	"""
	Initializes the placed items grid, typically empty or with permanent fixtures.
	Each cell's value is the ID of the item placed there, or an empty string if nothing.
	"""
	for y in range(height):
		for x in range(width):
			var coords_key: String = str(x) + "," + str(y)
			placed_items_grid[coords_key] = "" # Empty string means no item placed
	print("Default placed items grid initialized.")


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
		for crop_id in required_crops: # Iterate over crop IDs required for the milestone.
			# Check if the harvested quantity for this crop in the current loop meets the requirement.
			if current_loop_score.get(crop_id, 0) < required_crops[crop_id]:
				met_all = false
				print("Milestone requirement not met: Need %d of %s, have %d." % [required_crops[crop_id], crop_id, current_loop_score.get(crop_id, 0)])
				# Optimization: If a crop requirement isn't met, no need to check other crops for this milestone.
				break
		if not met_all: # If harvested_crops check already failed, return early.
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
			met_all = false # Cannot meet soil quality without any tiles.
			print("Milestone requirement not met: No soil tiles to check average quality.")
		if not met_all:
			return false

	# If all checked requirements were met, then the milestone is completed.
	if met_all:
		print("Milestone '%s' Met!" % current_milestone_data.get("display_name", "Unknown Milestone"))
	
	return met_all


func _apply_milestone_reward() -> void:
	"""Applies the rewards defined in the `current_milestone_data`."""
	var rewards: Dictionary = current_milestone_data.get("rewards", {})
	
	# The "temporal_energy" reward type has been removed as per the new design.
	# If you want a different form of 'currency' or direct item reward, add it here.
	# Example:
	# if rewards.has("granted_items"):
	#     for item_id in rewards["granted_items"]:
	#         var quantity_to_grant = rewards["granted_items"][item_id]
	#         add_item_to_inventory(item_id, quantity_to_grant)


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
				_handle_specific_upgrade_effect(upgrade_id) # Handle immediate effects of upgrades.
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
		emit_signal("loop_duration_changed", loop_duration) # Emit signal for UI updates.
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

# --- Game Mode Management ---
func set_game_mode(mode: int, item_id_for_placement: String = "") -> void:
	"""
	Sets the current game interaction mode.
	@param mode: The desired GameMode enum value (e.g., GameMode.NORMAL, GameMode.PLACEMENT).
	@param item_id_for_placement: Required if setting mode to GameMode.PLACEMENT, specifies which item to place.
	"""
	if current_game_mode == mode:
		return # No change needed if already in this mode.

	# Clean up logic for the OLD mode before transitioning.
	# Clean up placement mode visuals/state if we're leaving it.
	if current_game_mode == GameMode.PLACEMENT:
		_clear_placement_preview() # Remove the visual preview.
		selected_item_for_placement = "" # Clear the selected item.
		emit_signal("placement_mode_exited") # Notify UI/other systems.
	
	# Add cleanup for Harvest/Inspect modes if they had specific visual cues (e.g., a cursor change, highlight)
	# if current_game_mode == GameMode.HARVEST:
	#    emit_signal("harvest_mode_exited") # You might add this signal in your UI script
	# if current_game_mode == GameMode.INSPECT:
	#    emit_signal("inspect_mode_exited") # You might add this signal in your UI script


	# Transition to the NEW mode.
	current_game_mode = mode
	emit_signal("game_mode_changed", current_game_mode) # Notify UI/other systems of mode change.

	match current_game_mode:
		GameMode.NORMAL:
			print("Game Mode: NORMAL")
		GameMode.PLACEMENT:
			if not item_id_for_placement:
				push_warning("Attempted to enter PLACEMENT mode without an item_id. Reverting to NORMAL.")
				set_game_mode(GameMode.NORMAL) # Cannot enter placement without an item.
				return
			
			selected_item_for_placement = item_id_for_placement
			#_create_placement_preview() # Create the visual preview.
			emit_signal("placement_mode_active", selected_item_for_placement) # Notify UI.
			print("Game Mode: PLACEMENT for item '%s'" % selected_item_for_placement)
		GameMode.HARVEST:
			print("Game Mode: HARVEST")
			emit_signal("harvest_mode_active") # Inform UI about new mode.
		GameMode.INSPECT:
			print("Game Mode: INSPECT")
			emit_signal("inspect_mode_active") # Inform UI about new mode.


#func _create_placement_preview() -> void:
	#"""Instantiates and sets up the visual preview for placement."""
	#if PLACEMENT_PREVIEW_SCENE:
		#if placement_preview_instance: # Ensure any old preview is removed first.
			#_clear_placement_preview()
		#
		#placement_preview_instance = PLACEMENT_PREVIEW_SCENE.instantiate()
		## Add the preview to the scene tree (e.g., as a child of the root viewport or a dedicated Node3D).
		#get_tree().get_root().add_child(placement_preview_instance)
		#_update_placement_preview_position() # Set its initial position.
	#else:
		#push_error("Placement preview scene not loaded! Check PLACEMENT_PREVIEW_SCENE path constant.")


func _update_placement_preview_position() -> void:
	"""Updates the position of the placement preview to follow the mouse on the grid."""
	if placement_preview_instance and get_viewport():
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var grid_coords: Vector2i = _get_grid_coords_under_mouse(mouse_pos)
		
		if grid_coords != Vector2i(-1, -1): # If mouse is over a valid grid cell.
			# Position the preview. Adjust offset (Y=0.01) to avoid Z-fighting with ground.
			# Assumes 1x1 grid cells, centered on integer coordinates for x and z.
			placement_preview_instance.global_position = Vector3(grid_coords.x, 0.01, grid_coords.y)
			placement_preview_instance.visible = true
			# Future improvement: Change preview color/material based on `_is_valid_placement(grid_coords)`
		else:
			placement_preview_instance.visible = false # Hide preview if mouse is not over a valid grid cell.


func _clear_placement_preview() -> void:
	"""Removes the placement preview instance from the scene."""
	if placement_preview_instance and is_instance_valid(placement_preview_instance):
		placement_preview_instance.queue_free() # Safely delete the node.
		placement_preview_instance = null


func _is_valid_placement(grid_x: int, grid_y: int) -> bool:
	"""
	Checks if the current selected item can be placed at the given grid coordinates.
	Expand this with more game-specific rules (e.g., must be soil, specific soil type).
	"""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	
	# Rule 1: Is the tile within the initialized grid bounds?
	if not soil_grid_data.has(coords_key):
		print("Invalid placement: Outside grid bounds at (%d,%d)." % [grid_x, grid_y])
		return false
	
	# Rule 2: Is the tile already occupied by another item?
	if placed_items_grid.get(coords_key, "") != "":
		print("Invalid placement: Tile (%d,%d) already occupied by '%s'." % [grid_x, grid_y, placed_items_grid[coords_key]])
		return false
	
	# Rule 3: Does the player have enough of the item in inventory?
	if not current_inventory.get(selected_item_for_placement, 0) > 0:
		print("Invalid placement: Not enough '%s' in inventory." % selected_item_for_placement)
		return false

	# Add more specific rules here, e.g.:
	# - If placing a plant, check if the soil_grid_data for this tile has suitable properties.
	#   var soil_props = get_soil_properties(grid_x, grid_y)
	#   if selected_item_for_placement.ends_with("seed") and soil_props.get("fertility", 0) < 30:
	#       print("Invalid placement: Soil too infertile for planting.")
	#       return false
	# - Check if the item type (e.g., "machine" vs "plant") can be placed on that tile type.

	print("Valid placement at (%d,%d)." % [grid_x, grid_y])
	return true


func _place_item(grid_x: int, grid_y: int) -> void:
	"""
	Instantiates and places the `selected_item_for_placement` at the given grid coordinates.
	Consumes item from inventory and updates the `placed_items_grid`.
	"""
	if not _is_valid_placement(grid_x, grid_y):
		print("Cannot place '%s' at (%d,%d): Invalid placement." % [selected_item_for_placement, grid_x, grid_y])
		return

	# Deduct item from inventory (this function also emits inventory_changed signal)
	if not remove_item_from_inventory(selected_item_for_placement, 1):
		push_error("Failed to remove item '%s' from inventory during placement despite _is_valid_placement check." % selected_item_for_placement)
		set_game_mode(GameMode.NORMAL) # Auto-exit placement mode on this critical error.
		return

	var coords_key: String = str(grid_x) + "," + str(grid_y)
	# Store the placed item in the persistent grid data.
	placed_items_grid[coords_key] = selected_item_for_placement
	print("Placed '%s' at (%d,%d)." % [selected_item_for_placement, grid_x, grid_y])

	# Instantiate the actual 3D model for the item.
	# You will need to ensure your `crop_data_map` or `item_data_map` contains a path
	# to the PackedScene for each item, e.g., "scene_path": "res://Scenes/Plants/basic_plant.tscn".
	var item_data = crop_data_map.get(selected_item_for_placement) if crop_data_map.has(selected_item_for_placement) else item_data_map.get(selected_item_for_placement)
	var item_scene_path: String = item_data.get("scene_path", "") # Assumes your JSON has "scene_path" for visuals.

	if item_scene_path:
		var item_scene: PackedScene = load(item_scene_path)
		if item_scene:
			var item_instance: Node3D = item_scene.instantiate()
			# Give it a unique name for easier debugging/lookup in scene tree.
			item_instance.name = "%s_%d_%d" % [selected_item_for_placement, grid_x, grid_y]
			# Position the item instance correctly on the grid (centered on cell).
			item_instance.global_position = Vector3(grid_x, 0, grid_y) # Adjust Y based on your model's pivot.
			
			# Add the item to a logical parent in your scene tree (e.g., a "PlacedItems" Node3D).
			# For simplicity, adding to root, but consider a dedicated parent for organization.
			get_tree().get_root().add_child(item_instance)
			print("Instantiated 3D item: %s" % item_instance.name)
		else:
			push_error("Could not load scene for item: '%s' at path '%s'." % [selected_item_for_placement, item_scene_path])
	else:
		push_warning("No 'scene_path' defined for item '%s' in data. No 3D model will be placed." % selected_item_for_placement)

	# After successful placement, you typically remain in placement mode to allow rapid placement.
	# To revert to normal automatically after one placement: set_game_mode(GameMode.NORMAL)


func _remove_item_from_grid(grid_x: int, grid_y: int) -> void:
	"""
	Removes an item visually from the scene and clears its entry from the placed_items_grid.
	This is used for harvesting, or future 'deconstruction' modes.
	"""
	var coords_key: String = str(grid_x) + "," + str(grid_y)
	var item_id_to_remove: String = placed_items_grid.get(coords_key, "")

	if item_id_to_remove:
		# Find and remove the 3D instance by its expected name.
		# This might need refinement for more complex scenes (e.g., if items are parented differently).
		var item_found = false
		for child in get_tree().get_root().get_children():
			# Check if the child is a Node3D and matches the name pattern
			if child is Node3D and child.name == "%s_%d_%d" % [item_id_to_remove, grid_x, grid_y]:
				child.queue_free() # Safely delete the 3D node.
				print("Removed 3D instance of '%s' at (%d,%d)." % [item_id_to_remove, grid_x, grid_y])
				item_found = true
				break
		
		if item_found:
			placed_items_grid[coords_key] = "" # Clear the grid data after successful removal.
		else:
			push_warning("Could not find 3D instance for '%s' at (%d,%d) to remove." % [item_id_to_remove, grid_x, grid_y])
	else:
		print("No item to remove at (%d,%d)." % [grid_x, grid_y])


# --- Placeholder for future save/load ---
func save_game() -> void:
	"""
	Placeholder for saving game state.
	Implement logic to save: soil_grid_data, unlocked_plant_types, unlocked_upgrades,
	current_milestone_index, time_capsule_contents, loop_duration,
	time_capsule_capacity, and NEW: placed_items_grid.
	"""
	push_warning("Save game functionality not yet implemented.")
	pass

func load_game() -> void:
	"""Placeholder for loading game state."""
	push_warning("Load game functionality not yet implemented.")
	pass
