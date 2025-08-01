extends CanvasLayer

@onready var panel : ColorRect = $TextureRect
@onready var crop_name : Label = $TextureRect/CropName
@onready var crop_desc : Label = $TextureRect/CropDescription
@onready var juiced : Label = $TextureRect/Juiced
@onready var growth : TextureProgressBar = $TextureRect/Growth
@onready var fertilizer : TextureProgressBar = $TextureRect/Fertilizer
@onready var hydration : TextureProgressBar = $TextureRect/Hydration
@onready var purity : TextureProgressBar = $TextureRect/Purity

func _ready():
	panel.visible = false
	Signals.inspect.connect(_on_inspecting_mode_entered)
	
func _on_inspecting_mode_entered(position, tile_data):
	print(tile_data)
	panel.visible = true
	panel.set_position(position)
	
	crop_name.text = tile_data
	crop_desc.text = tile_data
	
	growth.value = tile_data
	fertilizer.value = tile_data
	purity.value = tile_data
	juiced.value = tile_data

	
