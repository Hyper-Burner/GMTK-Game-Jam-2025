extends CanvasLayer

@onready var panel : ColorRect = $TextureRect
@onready var crop_name : Label = $TextureRect/CropName
@onready var crop_desc : Label = $TextureRect/CropDescription
@onready var harvestable : Label = $TextureRect/Harvestable
@onready var growth : ProgressBar = $TextureRect/Growth
@onready var fertilizer : ProgressBar = $TextureRect/Fertilizer
@onready var hydration : ProgressBar = $TextureRect/Hydration
@onready var ph : ProgressBar = $TextureRect/PH

const TILE_SIZE = 32
var previous_inspect_position : Vector2
var in_loop : bool
var vp_size : Vector2

func _ready():
	vp_size = get_viewport().size
	previous_inspect_position = Vector2(-99,-99)
	panel.visible = false
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
		

# assumned data structure for tile_data
#{
	#"Name": seed,
	#"Harvestable": false,
	#"Hydration": 50,
	#"Nutrients": 50,
	#"Soil PH": 50,
	#"Plant":  {
		#"Instance": crop.instance(seed, false)
	#}
#}
func _on_inspecting_mode_entered(position : Vector2, tile_data):
	# if the loop is not active do not show
	if !in_loop:
		panel.visible = false
		return
	# if same tile, toggle the panel visibility.
	if position == previous_inspect_position:
		panel.visible = !panel.visible
		return
	
	previous_inspect_position = position
	panel.visible = true

	# if the inspect position is in the bottom half of the screen, place it above the inspect position
	if (position.y >= vp_size.y / 2):
		position.y -= panel.size.y + TILE_SIZE / 2
		
	# inspect position is in the top half -> place it below the inspect position
	else:
		position.y += TILE_SIZE / 2
		
	position.x -= panel.size.x / 2
	panel.set_position(position)
	
	if tile_data["crop"]:
		crop_name.text = tile_data["crop"].crop_name
		growth.visible = true
		growth.value = tile_data["crop"].current_growth_stage
		crop_desc.text = tile_data["crop"].crop_desc
		harvestable.text = "Harvestable " + str(tile_data["crop"].harvestable)
	else:
		crop_name.text = "Soil"
		crop_desc.text = "Its soil lol"
		growth.visible = false
		crop_desc.text = ""
		harvestable.text = ""
	
	hydration.value = tile_data["hydration"]
	fertilizer.value = tile_data["nutrients"]
	ph.value = tile_data["soil_ph"]
	
	
	

	
