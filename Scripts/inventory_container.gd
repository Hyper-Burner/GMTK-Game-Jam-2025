# Hotbar.gd
# This script manages the main hotbar UI and its connection to the global inventory.
extends HBoxContainer

# All signals are now handled by the Signals autoload.

# The number of slots to create in the hotbar.
const NUM_SLOTS: int = 8
# Path to the InventorySlot scene file.
const HOTBAR_SLOT_SCENE_PATH: String = "res://scenes/inventory_slot.tscn"

# A reference to the loaded hotbar slot scene.
var hotbar_slot_scene: PackedScene = preload(HOTBAR_SLOT_SCENE_PATH)
# An array to hold references to the instantiated hotbar slot nodes.
var hotbar_slots: Array = []

func _ready() -> void:

	_create_hotbar_slots()

	Signals.inventory_changed.connect(_update_hotbar)
	# Connect to the new planting mode signals to visually update the hotbar.
	Signals.planting_mode_entered.connect(_on_planting_mode_entered)
	Signals.planting_mode_exited.connect(_on_planting_mode_exited)

	# Initial update of the hotbar.
	for i in Inventory.starting_inventory.size():
		_update_hotbar(Inventory.starting_inventory.keys()[i], Inventory.starting_inventory.values()[i])

func _create_hotbar_slots() -> void:
	# Clear existing slots before creating new ones.
	_clear_hotbar_slots()
	for i in range(NUM_SLOTS):
		# Create a new instance of the slot scene.
		var new_slot = hotbar_slot_scene.instantiate()
		new_slot.slot_index = i
		
		# We don't need to connect slot signals to the Hotbar.gd anymore because
		# the slots now emit directly to the Signals autoload.
		
		# Add the slot directly to the HBoxContainer root node.
		add_child(new_slot)
		hotbar_slots.append(new_slot)

func _clear_hotbar_slots() -> void:
	# Remove all child nodes from the container and clear the array.
	for child in get_children():
		child.queue_free()
	hotbar_slots.clear()
		
func _update_hotbar(item_id: String, new_quantity: int) -> void:

		
	var inventory_to_display = Inventory.seed_inventory
	var inventory_keys = inventory_to_display.keys()
	
	for i in range(NUM_SLOTS):
		var slot_node = hotbar_slots[i]
		if i < inventory_keys.size():
			var item_id_to_check = inventory_keys[i]
			var quantity = inventory_to_display[item_id_to_check]
			slot_node.set_item(item_id_to_check, quantity)
		else:
			slot_node._clear_slot()

func _on_planting_mode_entered(item_id: String) -> void:
	# Highlight the slot that corresponds to the selected item.
	for slot in hotbar_slots:
		slot.set_selected(slot.current_item_id == item_id)

func _on_planting_mode_exited() -> void:
	# Un-highlight all slots when planting mode is exited.
	for slot in hotbar_slots:
		slot.set_selected(false)
