# InventorySlot.gd
# This script is for the individual slots in the hotbar.
# It manages displaying the item's icon, quantity, and state.
extends Control

# Signals are now handled by the Signals autoload, so we can remove the declarations here.

@export var slot_index: int = 0
@onready var item_icon: TextureRect = $Background/ItemIcon
@onready var item_quantity: Label = $Background/ItemQuantity
@onready var panel: Panel = $Background # Reference to the Panel node for visual feedback

var current_item_id: String = ""

func _ready() -> void:
	# Hide the slot content by default.
	_clear_slot()

func _clear_slot() -> void:
	# Resets the slot to an empty state.
	item_icon.texture = null
	item_icon.visible = false
	item_quantity.text = ""
	item_quantity.visible = false
	current_item_id = ""
	panel.modulate = Color(1, 1, 1, 1) # Reset panel color

func set_item(item_id: String, quantity: int) -> void:
	# Sets the item icon and quantity for this slot.
	if item_id.is_empty():
		_clear_slot()
		return

	current_item_id = item_id
	var item_data = Global.item_data_map.get(item_id)
	
	if item_data and item_data.has("icon"):
		item_icon.texture = load(item_data["icon"])
		item_icon.visible = true
	else:
		item_icon.texture = null
		item_icon.visible = true
		push_warning("Icon not found for item: %s" % item_id)
		
	item_quantity.text = str(quantity)
	item_quantity.visible = true

func set_selected(is_selected: bool) -> void:
	# Visually highlights or un-highlights the slot.
	if is_selected:
		panel.modulate = Color(0.8, 1, 0.8, 1) # Greenish tint for selected
	else:
		panel.modulate = Color(1, 1, 1, 1) # Reset to white

func _on_gui_input(event: InputEvent) -> void:
	# Check for a left mouse button press.
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if not current_item_id.is_empty():
			# *** FIX: Set the slot as selected instantly. ***
			set_selected(true)
			# Emit the signal from the central Signals autoload.
			Signals.planting_mode_entered.emit(current_item_id)
			Signals.slot_selected.emit(current_item_id, slot_index)
		else:
			# If the slot is empty, we emit the deselection signal.
			set_selected(false) # *** FIX: Clear the selection state. ***
			Signals.planting_mode_exited.emit()
