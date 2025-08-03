extends Control

@onready var time_capsule_panel : Control = $TimeCapsulePanel
@onready var seed_inventory_grid : GridContainer = $TimeCapsulePanel/SeedInventorySection/GridContainer
@onready var time_capsule_grid : GridContainer = $TimeCapsulePanel/TimeCapsuleSection/GridContainer
@onready var seed_inventory_label : Label = $TimeCapsulePanel/SeedInventorySection/Label
@onready var time_capsule_label : Label = $TimeCapsulePanel/TimeCapsuleSection/Label
@onready var time_capsule_button : TextureButton = $TimeCapsuleButton  # Add reference to the button

const INVENTORY_SLOT = preload("res://Scenes/time_capsule_inventory_slot.tscn")
const MAX_TIME_CAPSULE_CAPACITY = 5

# Store references to current inventory slot UI elements
var seed_inventory_slots : Array[Control] = []
var time_capsule_slots : Array[Control] = []

func _ready():
	# Add to time_capsule group for easy reference
	add_to_group("time_capsule")
	
	Signals.loop_started.connect(_on_loop_started)
	Signals.loop_ended.connect(_on_loop_ended)
	Signals.inventory_changed.connect(_on_inventory_changed)
	
	# Start with time capsule panel hidden
	time_capsule_panel.visible = false
	
	# Set up labels
	if seed_inventory_label:
		seed_inventory_label.text = "Current Inventory"
	if time_capsule_label:
		update_time_capsule_label()

func _on_loop_started():
	# Refresh display if time capsule is open
	if time_capsule_panel.visible:
		update_inventory_display()
	
func _on_loop_ended():
	# Close time capsule when loop ends
	time_capsule_panel.visible = false

func _on_inventory_changed(item_id: String, new_quantity: int):
	# Only update display if time capsule is currently visible
	if time_capsule_panel.visible:
		update_inventory_display()
	
func _on_time_capsule_button_pressed() -> void:
	# Toggle the time capsule panel visibility
	toggle_time_capsule_panel()

func toggle_time_capsule_panel():
	time_capsule_panel.visible = !time_capsule_panel.visible
	
	# Update the display when opening
	if time_capsule_panel.visible:
		update_inventory_display()

func update_inventory_display():
	clear_inventory_slots()
	populate_seed_inventory()
	populate_time_capsule_inventory()
	update_time_capsule_label()

func get_time_capsule_total_seeds() -> int:
	var total = 0
	for item_id in Inventory.time_capsule_inventory:
		total += Inventory.time_capsule_inventory[item_id]
	return total

func update_time_capsule_label():
	if time_capsule_label:
		var current_count = get_time_capsule_total_seeds()
		time_capsule_label.text = "Time Capsule (%d/%d)" % [current_count, MAX_TIME_CAPSULE_CAPACITY]

func clear_inventory_slots():
	# Clear seed inventory slots
	for slot in seed_inventory_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	seed_inventory_slots.clear()
	
	# Clear time capsule slots
	for slot in time_capsule_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	time_capsule_slots.clear()

func populate_seed_inventory():
	if not seed_inventory_grid:
		push_error("Cannot populate seed inventory: seed_inventory_grid is null")
		return
		
	for item_id in Inventory.seed_inventory:
		var quantity = Inventory.seed_inventory[item_id]
		if quantity > 0:
			create_inventory_slot(item_id, quantity, seed_inventory_grid, true)

func populate_time_capsule_inventory():
	if not time_capsule_grid:
		push_error("Cannot populate time capsule inventory: time_capsule_grid is null")
		return
		
	for item_id in Inventory.time_capsule_inventory:
		var quantity = Inventory.time_capsule_inventory[item_id]
		if quantity > 0:
			create_inventory_slot(item_id, quantity, time_capsule_grid, false)

func create_inventory_slot(item_id: String, quantity: int, parent_grid: GridContainer, is_seed_inventory: bool):
	# Check if parent_grid is valid
	if not parent_grid:
		push_error("Cannot create inventory slot: parent_grid is null for item %s" % item_id)
		return
	
	var slot = INVENTORY_SLOT.instantiate()
	parent_grid.add_child(slot)
	
	# Set up the slot with item information using the time capsule inventory slot script
	if slot.has_method("setup_slot"):
		slot.setup_slot(item_id, quantity)
		# Connect the item_clicked signal if it exists
		if slot.has_signal("item_clicked"):
			slot.item_clicked.connect(_on_slot_item_clicked.bind(is_seed_inventory))
	else:
		push_error("time_capsule_inventory_slot.tscn must have setup_slot method!")
	
	# Store reference
	if is_seed_inventory:
		seed_inventory_slots.append(slot)
	else:
		time_capsule_slots.append(slot)

func _on_slot_item_clicked(item_id: String, slot: Control, is_from_seed_inventory: bool):
	# Add visual feedback if the slot supports it
	if slot.has_method("animate_transfer"):
		slot.animate_transfer()
	
	if is_from_seed_inventory:
		move_item_to_time_capsule(item_id, 1)
	else:
		move_item_from_time_capsule(item_id, 1)

func move_item_to_time_capsule(item_id: String, quantity: int = 1):
	# Check if adding this quantity would exceed the time capsule limit
	var current_total = get_time_capsule_total_seeds()
	if current_total + quantity > MAX_TIME_CAPSULE_CAPACITY:
		return
	
	if Inventory.seed_inventory.has(item_id) and Inventory.seed_inventory[item_id] >= quantity:
		# Remove from seed inventory
		var success = Inventory.remove_item_from_inventory(Inventory.seed_inventory, item_id, quantity)
		if success:
			# Add to time capsule
			Inventory.add_item_to_inventory(Inventory.time_capsule_inventory, item_id, quantity)
			
			# Emit time capsule update signal
			Signals.time_capsule_updated.emit(item_id, quantity, true)
			
			# Update display after a brief delay to ensure inventory changes are processed
			call_deferred("update_inventory_display")

func move_item_from_time_capsule(item_id: String, quantity: int = 1):
	if Inventory.time_capsule_inventory.has(item_id) and Inventory.time_capsule_inventory[item_id] >= quantity:
		# Remove from time capsule
		Inventory.time_capsule_inventory[item_id] -= quantity
		if Inventory.time_capsule_inventory[item_id] <= 0:
			Inventory.time_capsule_inventory.erase(item_id)
		
		# Add to seed inventory
		Inventory.add_item_to_inventory(Inventory.seed_inventory, item_id, quantity)
		
		# Emit time capsule update signal
		Signals.time_capsule_updated.emit(item_id, quantity, false)
		
		# Update display after a brief delay to ensure inventory changes are processed
		call_deferred("update_inventory_display")

# Public function to open/close time capsule (can be called from other scripts)
func open_time_capsule():
	time_capsule_panel.visible = true
	update_inventory_display()

func close_time_capsule():
	time_capsule_panel.visible = false

# Check if time capsule is currently open
func is_time_capsule_open() -> bool:
	return time_capsule_panel.visible	
