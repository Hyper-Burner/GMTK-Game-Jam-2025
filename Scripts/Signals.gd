extends Node
signal plant_seed(seed: String)
signal harvesting_mode_entered()
signal harvesting_mode_exited
signal harvest_crop(crop: String)
signal inspecting_mode_entered()
signal inspecting_mode_exited()
signal inspect(Vector2i)
 
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
signal plant_unlocked(plant_id: String,quantity: int)
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
signal planting_mode_entered(item: String)
# Emitted when placement mode is exited (e.g., by canceling or placing).
signal planting_mode_exited()
# Emitted when Harvest mode is activated (useful for UI cursor changes).
signal harvest_mode_active()
# Emitted when Inspect mode is activated (useful for UI cursor changes).
signal inspect_mode_active()

# --- NEW SIGNAL FOR PREVIEW CONTROLLER COMMUNICATION ---
# Emitted when the mouse moves over a grid cell while in placement mode.
signal update_placement_preview(grid_coords: Vector2i, is_valid: bool)
