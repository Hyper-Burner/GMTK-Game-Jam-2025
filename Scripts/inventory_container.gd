# Hotbar.gd
# This script manages the main hotbar UI and its connection to the global inventory.
extends HBoxContainer

# All signals are now handled by the Signals autoload.

# The number of slots to create in the hotbar.
const NUM_SLOTS: int = 8

# A reference to the loaded hotbar slot scene.
var hotbar_slot_scene: PackedScene = preload("res://Scenes/inventory_slot.tscn")
# An array to hold references to the instantiated hotbar slot nodes.
var hotbar_slots: Array = []


	
func _ready() -> void:
	_create_hotbar_slots()
	Signals.inventory_changed.connect(_update_hotbar)
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
		add_child(new_slot)
		hotbar_slots.append(new_slot)

func _clear_hotbar_slots() -> void:
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
			
func on_slot_clicked(item_id: String, slot_index: int) -> void:
	Signals.slot_selected.emit(item_id, slot_index)
	for x in hotbar_slots:
		print(x.current_item_id)
		if(x.current_item_id == item_id):
			x._set_select_visible()
		else:
			x._set_select_invisible()
	
