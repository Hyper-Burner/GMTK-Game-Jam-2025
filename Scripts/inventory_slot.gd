# InventorySlot.gd
# This script is for the individual slots in the hotbar.
# It manages displaying the item's icon, quantity, and state from a spritesheet.
extends Control

@export var slot_index: int = 0
@onready var item_icon: TextureRect = $Background/ItemIcon
@onready var item_quantity: Label = $Background/ItemQuantity
@onready var background: TextureRect = $Background # Reference to the Panel node for visual feedback

# MAPPING: This links item names to their index on the spritesheet.
const SEED_SPRITESHEET_MAPPING: Dictionary = {
	"Tuloop": 0,
	"Ringshroom": 1,
	"Hoopberry": 2,
	"Daffotwirl": 3,
	"Curlbush": 4, 
	" Twirlvine Plant": 5, 
	"Sproot Loop": 6,
	"Sparkly Ringflower": 7
}
var current_item_id: String = ""

func _ready() -> void:
	# Ensure the panel handles clicks and doesn't let them pass through.
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_slot()
	# Connect to the input event to handle clicks directly on this Control node.
	connect("gui_input", Callable(self, "_on_gui_input"))


func _clear_slot() -> void:
	# Resets the slot to an empty state.
	item_icon.visible = false
	item_quantity.text = ""
	item_quantity.visible = false
	current_item_id = ""
	background.modulate = Color(1, 1, 1, 1) # Reset panel color

func set_item(item_id: String, quantity: int) -> void:
	# Sets the item icon and quantity for this slot using a spritesheet.
	if item_id.is_empty():
		_clear_slot()
		return

	current_item_id = item_id
	var texture_index = SEED_SPRITESHEET_MAPPING.get(item_id, -1)

	if texture_index != -1 :
		var rect = Rect2(Vector2(texture_index * 32, 0), Vector2(32, 32))
		print(item_icon)
		item_icon.texture.region = rect
		item_icon.visible = true
	else:
		_clear_slot()
		push_warning("No spritesheet mapping or texture for item: %s" % item_id)
		
	item_quantity.text = str(quantity)
	item_quantity.visible = true

func set_selected(is_selected: bool) -> void:
	# Visually highlights or un-highlights the slot.
	if is_selected:
		background.modulate = Color(0.8, 1, 0.8, 1) # Greenish tint for selected
	else:
		background.modulate = Color(1, 1, 1, 1) # Reset to white

func _on_background_gui_input(event: InputEvent) -> void:
	# Check for a left mouse button press.
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if not current_item_id.is_empty():
			# Call the parent container's method directly to handle the selection logic.
			get_parent().on_slot_clicked(current_item_id, slot_index)
		else:
			print("Empty slot clicked.")
func _set_select_visible():
	$Select.visible = true
func _set_select_invisible():
	$Select.visible = false
