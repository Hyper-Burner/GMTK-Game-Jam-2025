extends Control

@onready var time_capsule_panel : TextureRect = $TimeCapsuleMenu
@onready var time_capsule_inventory : GridContainer = $TimeCapsuleMenu/GridContainer

const INVENTORY_SLOT = preload("res://Scenes/inventory_slot.tscn")

var inv = Inventory.seed_inventory

func _on_ready():
	var inventory_item = INVENTORY_SLOT.instantiate()
	time_capsule_inventory.add_child(inventory_item)
	
	
func _on_time_capsule_button_pressed() -> void:
	time_capsule_panel.visible = !time_capsule_panel.visible
