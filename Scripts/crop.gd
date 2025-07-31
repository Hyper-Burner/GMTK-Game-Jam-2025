extends Sprite2D
class_name Crop

static var crop = preload("res://Scenes/crop.tscn")
static var crops = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))

var growth_duration: int
var max_growth_stage: int
var current_growth_stage: int = 0
var frame_coordinates: Vector2i

static func create(crop_name: String, optimal_conditions: bool):
	var instance = crop.instantiate()
	if optimal_conditions:
		instance.growth_duration = crops[crop_name]["optimal_growth_duration"]
	else:
		instance.growth_duration = crops[crop_name]["growth_duration"]
	instance.max_growth_stage = crops[crop_name]["growth_stages"]
	instance.frame_coords = crops[crop_name]["frame_coords"]
	return instance

func _ready() -> void:
	$GrowthStageDuration.wait_time = growth_duration / max_growth_stage
	self.frame_coords = frame_coordinates

func _on_growth_stage_duration_timeout() -> void:
	current_growth_stage += 1
	frame += 1
	if current_growth_stage == max_growth_stage:
		$GrowthStageDuration.stop()
