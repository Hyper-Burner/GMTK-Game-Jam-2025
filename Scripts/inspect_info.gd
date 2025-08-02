extends CanvasLayer

@onready var panel : ColorRect = $TextureRect
@onready var crop_name : Label = $TextureRect/CropName
@onready var crop_desc : Label = $TextureRect/CropDescription
@onready var harvestable : Label = $TextureRect/Harvestable
@onready var growth : TextureProgressBar = $TextureRect/Growth
@onready var fertilizer : TextureProgressBar = $TextureRect/Fertilizer
@onready var hydration : TextureProgressBar = $TextureRect/Hydration
@onready var ph : TextureProgressBar = $TextureRect/PH

func _ready():
	panel.visible = false
	Signals.inspect.connect(_on_inspecting_mode_entered)

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
	print(tile_data)
	panel.visible = true
	panel.set_position(position)
	
	crop_name.text = tile_data["Name"]
	crop_desc.text = tile_data["Plant"].crop_description

	growth.value = tile_data["Plant"].current_growth_stage
	hydration.value = tile_data["Hydration"]
	fertilizer.value = tile_data["Nutrients"]
	ph.value = tile_data["Soil PH"]
	
	harvestable.text = tile_data["Harvestable"]

	
