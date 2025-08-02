extends Node
# Items available in the current loop's inventory (item_id: quantity). Resets each loop.
# Keys are now String.
var current_inventory: Dictionary = {}
var starting_inventory: Dictionary = {"Strawberry": 1}
func _ready() -> void:
	Signals.plant_unlocked.connect(plant_unlocked)
# --- Inventory & Item Management ---
# item_id is now a String.
func add_item_to_current_inventory(item_id: String, quantity: int = 1) -> void:
	"""Adds items to the current loop's inventory."""
	# No validation if user doesn't want it.
	# The `if not (...) return` block is entirely removed.
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to inventory: ID %s, quantity: %d" % [item_id, quantity])
		return

	current_inventory[item_id] = current_inventory.get(item_id, 0) + quantity
	print(current_inventory)
	# EMIT GLOBAL SIGNAL
	Signals.inventory_changed.emit(item_id, current_inventory[item_id])
	print("Added %d x ID %s to inventory. Current: %s" % [quantity, item_id, current_inventory])

# item_id is now a String.
func remove_item_from_current_inventory(item_id: String, quantity: int = 1) -> bool:
	"""Removes items from the current loop's inventory."""
	if not current_inventory.has(item_id) or current_inventory[item_id] < quantity:
		push_warning("Not enough of item ID %s in inventory to remove %d. Current: %d" % [item_id, quantity, current_inventory.get(item_id, 0)])
		return false
	
	current_inventory[item_id] -= quantity	
	# EMIT GLOBAL SIGNAL
	Signals.inventory_changed.emit(item_id, current_inventory.get(item_id, 0))
	print("Removed %d x ID %s from inventory. Current: %s" % [quantity, item_id, current_inventory])
	return true
	
func add_item_to_starting_inventory(item_id: String, quantity: int = 1):
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to inventory: ID %s, quantity: %d" % [item_id, quantity])
		return
	starting_inventory[item_id] = current_inventory.get(item_id, 0) + quantity
	
func set_inventory_to(new_inventory: Dictionary):
	current_inventory = new_inventory.duplicate()
	
func reset_inventory():
	print("inside reset", starting_inventory)
	set_inventory_to(starting_inventory)
	
func plant_unlocked(new_seed: String, quantity: int):
	add_item_to_starting_inventory(new_seed, quantity)
	pass
