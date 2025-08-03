extends Control
class_name TimeCapsuleInventorySlot

# UI References - adjust these paths based on your scene structure
@onready var item_button: Button = $Button
@onready var item_label: Label = $Label
@onready var quantity_label: Label = $QuantityLabel
@onready var item_icon: TextureRect = $Icon

# Item data
var item_id: String = ""
var quantity: int = 0

signal item_clicked(item_id: String, slot: TimeCapsuleInventorySlot)

func _ready():
	if item_button:
		item_button.pressed.connect(_on_button_pressed)

func setup_slot(new_item_id: String, new_quantity: int):
	item_id = new_item_id
	quantity = new_quantity
	update_display()

func update_display():
	if item_label:
		item_label.text = ""  # Clear label text since button shows the name
	if quantity_label:
		quantity_label.text = "x" + str(quantity)
	if item_button:
		item_button.text = item_id  # Only show item name, not quantity
	
	# Update icon if available
	if item_icon:
		load_and_set_icon(item_id)

func load_and_set_icon(item_id: String):
	# Load crop data for icon
	var crop_data = load_crop_data(item_id)
	var seeds_texture = load("res://Textures/seeds-Sheet.png")
	
	if not seeds_texture:
		print("Could not load seeds-Sheet.png texture")
		return
	
	if crop_data.has("frame_coords"):
		var frame_coords = crop_data["frame_coords"]
		if frame_coords is Array and frame_coords.size() >= 2:
			# For seeds sheet, we want to use only the seed sprites
			# Try using just the Y coordinate from frame_coords for the row
			var frame_size = Vector2(32, 32)  # Use larger frame size for better visibility
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = seeds_texture
			# Use only the Y coordinate for seed selection, X should be 0 for seeds
			atlas_texture.region = Rect2(
				Vector2(0, frame_coords[1]) * frame_size,
				frame_size
			)
			item_icon.texture = atlas_texture
		else:
			# Fallback to full texture
			item_icon.texture = seeds_texture
	else:
		# Use full texture as fallback
		item_icon.texture = seeds_texture

func load_crop_data(item_id: String) -> Dictionary:
	# Load crop data from JSON file
	var file = FileAccess.open("res://TextFiles/crops.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if data.has(item_id):
				return data[item_id]
	
	return {}

func _on_button_pressed():
	item_clicked.emit(item_id, self)

func animate_transfer():
	# Optional: add animation when item is transferred
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
