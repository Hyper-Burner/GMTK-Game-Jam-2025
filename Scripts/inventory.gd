extends Node
# Items available in the current loop's inventory (item_id: quantity). Resets each loop.
# Keys are now String.
@export var starting_inventory: Dictionary = {"Tuloop": 5}
@export var seed_inventory: Dictionary = {}
@export var crop_inventory: Dictionary = {}
@export var time_capsule_inventory: Dictionary = {}

func _ready() -> void:
	Signals.plant_unlocked.connect(plant_unlocked)
# --- Inventory & Item Management ---
# item_id is now a String.
func add_item_to_inventory(inventory: Dictionary, item_id: String, quantity: int = 1) -> void:
	"""Adds items to the current loop's inventory."""
	# No validation if user doesn't want it.
	# The `if not (...) return` block is entirely removed.
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to inventory: ID %s, quantity: %d" % [item_id, quantity])
		return

	inventory[item_id] = inventory.get(item_id, 0) + quantity
	print(inventory)
	# EMIT GLOBAL SIGNAL
	Signals.inventory_changed.emit(item_id, inventory[item_id])
	print("Added %d x ID %s to inventory. Current: %s" % [quantity, item_id, inventory])

# item_id is now a String.
func remove_item_from_inventory(inventory:Dictionary, item_name: String, quantity: int = 1) -> bool:
	"""Removes items from the current loop's inventory."""
	if not inventory.has(item_name) or inventory[item_name] < quantity:
		push_warning("Not enough of item ID %s in inventory to remove %d. Current: %d" % [item_name, quantity, inventory.get(item_name, 0)])
		return false
	
	inventory[item_name] -= quantity	
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	
	# EMIT GLOBAL SIGNAL
	Signals.inventory_changed.emit(item_name, inventory.get(item_name, 0))
	print("Removed %d x ID %s from inventory. Current: %s" % [quantity, item_name, inventory])
	return true
	
func add_item_to_starting_inventory(item_id: String, quantity: int = 1):
	if quantity <= 0:
		push_warning("Attempted to add non-positive quantity of item to inventory: ID %s, quantity: %d" % [item_id, quantity])
		return
	starting_inventory[item_id] = seed_inventory.get(item_id, 0) + quantity
	
func set_inventory_to(new_inventory: Dictionary):
	seed_inventory = new_inventory.duplicate()
	for i in Inventory.starting_inventory.size():
		Signals.inventory_changed.emit(Inventory.starting_inventory.keys()[i], Inventory.starting_inventory.values()[i])
	
func reset_inventory():
	set_inventory_to(starting_inventory)
	
func plant_unlocked(new_seed: String, quantity: int):
	add_item_to_starting_inventory(new_seed, quantity)
	pass
