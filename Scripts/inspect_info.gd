extends CanvasLayer

@onready var panel : ColorRect = $TextureRect
@onready var crop_name : Label = $TextureRect/CropName
@onready var crop_desc : Label = $TextureRect/CropDescription
@onready var harvestable : Label = $TextureRect/Harvestable
@onready var growth : ProgressBar = $TextureRect/Growth
@onready var fertilizer : ProgressBar = $TextureRect/Fertilizer
@onready var hydration : ProgressBar = $TextureRect/Hydration
@onready var ph : ProgressBar = $TextureRect/PH

var previous_inspect_position : Vector2

func _ready():
	previous_inspect_position = Vector2(-99,-99)
	panel.visible = false
	Signals.inspect.connect(_on_inspecting_mode_entered)
	crop_name.text = ""
	crop_desc.text = ""
	

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
func _on_inspecting_mode_entered(position, tile_data):
	# if same tile, toggle the panel visibility.
	if position == previous_inspect_position:
		panel.visible = !panel.visible
		return
	
	previous_inspect_position = position
	panel.visible = true
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
	
	

	
