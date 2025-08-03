extends TextureRect

var currently_breeding: String
var currently_breeding_amount: int
@onready var breed_button = $Panel/Button
@onready var selected_seed_image = $Panel/TextureRect
@onready var timer = $Timer

func breed_seed():
	timer.start()

func _on_seed_1_pressed() -> void:
	selected_seed_image.texture.region = Rect2(171, 55, 9, 9)

func _on_seed_2_pressed() -> void:
	selected_seed_image.texture.region = Rect2(331, 55, 9, 9)

func _on_seed_3_pressed() -> void:
	selected_seed_image.texture.region = Rect2(491, 55, 9, 9)

func _on_seed_4_pressed() -> void:
	selected_seed_image.texture.region = Rect2(651, 55, 9, 9)

func _on_seed_5_pressed() -> void:
	selected_seed_image.texture.region = Rect2(811, 55, 9, 9)

func _on_seed_6_pressed() -> void:
	selected_seed_image.texture.region = Rect2(971, 55, 9, 9)

func _on_seed_7_pressed() -> void:
	selected_seed_image.texture.region = Rect2(1131, 55, 9, 9) 

func _on_button_pressed() -> void:
	breed_seed()

func _on_timer_timeout() -> void:
	#Inventory.remove_item_from_inventory(Inventory.seed_inventory)
	#Inventory.add_item_to_inventory(Inventory.seed_inventory)
	currently_breeding_amount -= 1
	if currently_breeding_amount <= 0:
		timer.stop()
