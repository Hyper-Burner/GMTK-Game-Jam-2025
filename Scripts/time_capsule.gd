extends Control

@onready var time_capsule_panel : TextureRect = $TimeCapsuleMenu
@onready var time_capsule_grid : GridContainer = $TimeCapsuleMenu/GridContainer

const INVENTORY_SLOT = preload("res://Scenes/inventory_slot.tscn")

var seed_inventory = Inventory.seed_inventory
var time_capsule_inventory = Inventory.time_capsule_inventory

func _on_ready():
	Signals.loop_started.connect(_on_loop_started)
	Signals.loop_ended.connect(_on_loop_ended)
	var inventory_item = INVENTORY_SLOT.instantiate()
	time_capsule_grid.add_child(inventory_item)
	
func _on_loop_started():
	pass
	
func _on_loop_ended():
	pass
	
	
func _on_time_capsule_button_pressed() -> void:
	time_capsule_panel.visible = !time_capsule_panel.visible
	
	
	
	
