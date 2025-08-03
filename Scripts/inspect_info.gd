extends Control

@onready var panel : TextureRect = $TextureRect
@onready var crop_name : Label = $TextureRect/List/CropName
@onready var crop_desc : Label = $TextureRect/List/CropDescription
@onready var harvestable : Label = $TextureRect/List/Harvestable
@onready var growth : TextureProgressBar = $TextureRect/List/GrowthBar
@onready var fertilizer : TextureProgressBar = $TextureRect/List/Fertilizer/FertilizerBar
@onready var hydration : TextureProgressBar = $TextureRect/List/Hydration/HydrationBar
@onready var ph : TextureProgressBar = $TextureRect/List/SoilPH/SoilPHBar
@onready var animation: AnimationPlayer = $TextureRect/Animation

const TILE_SIZE = 32
var previous_inspect_position : Vector2
var in_loop : bool
var vp_size : Vector2

func _ready():
	panel.visible = false
	
	vp_size = get_viewport().size
	previous_inspect_position = Vector2(-99,-99)
	Signals.inspect.connect(_on_inspecting_mode_entered)
	Signals.loop_started.connect(_on_loop_started)
	Signals.loop_ended.connect(_on_loop_ended)
	crop_name.text = ""
	crop_desc.text = ""
	in_loop = true

func _on_loop_started():
	in_loop = true
	
func _on_loop_ended():
	in_loop = false

func show_panel():
	animation.play("show")
	
func hide_panel():
	animation.play("hide")
	
func _on_inspecting_mode_entered(position : Vector2, tile_data):
	# if the loop is not active do not show
	if !in_loop:
		panel.visible = false
		return
	
	# Check if time capsule is open - if so, don't show inspect
	var time_capsule_node = get_tree().get_first_node_in_group("time_capsule")
	if time_capsule_node and time_capsule_node.has_method("is_time_capsule_open"):
		if time_capsule_node.is_time_capsule_open():
			panel.visible = false
			return
	
	# if same tile, toggle the panel visibility.
	if position == previous_inspect_position:
		if panel.visible:
			hide_panel()
		else:
			show_panel()
		#panel.visible = !panel.visible
		return
	
	previous_inspect_position = position
	

	# if the inspect position is in the bottom half of the screen, place it above the inspect position
	if (position.y >= vp_size.y / 2):
		position.y -= panel.size.y + TILE_SIZE / 2
		
	# inspect position is in the top half -> place it below the inspect position
	else:
		position.y += TILE_SIZE / 2
		
	position.x -= panel.size.x / 2
	panel.set_position(position)
	#panel.visible = true
	show_panel()
	
	if tile_data["crop"]:
		crop_name.text = tile_data["crop"].crop_name
		growth.visible = true
		growth.max_value = tile_data["crop"].max_growth_stage
		growth.value = tile_data["crop"].current_growth_stage
		crop_desc.text = tile_data["crop"].crop_desc
		if tile_data["crop"].harvestable:
			harvestable.text = "Harvestable: Yes"
		else:
			harvestable.text = "Harvestable: No"
	else:
		crop_name.text = "Soil"
		crop_desc.text = "Its soil lol"
		growth.visible = false
		crop_desc.text = ""
		harvestable.text = ""
	
	hydration.value = tile_data["hydration"]
	fertilizer.value = tile_data["nutrients"]
	ph.value = tile_data["soil_ph"]
	
	
	

	
