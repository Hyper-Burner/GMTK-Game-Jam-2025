extends Sprite2D

static var crop_scene = preload("res://Scenes/crop.tscn")
static var crop_text_file = JSON.parse_string(FileAccess.get_file_as_string("res://TextFiles/crops.json"))

var Name
var growth_duration: int
var max_growth_stage: int
var current_growth_stage: int = 0
var frame_coordinates: Vector2i
var position_coordinates: Vector2

static func instance(crop_name: String, optimal_conditions: bool):
	var instance = crop_scene.instantiate()
	var crop = crop_text_file[crop_name]
	if optimal_conditions:
		instance.growth_duration = crop["optimal_growth_duration"]
	else:
		instance.growth_duration = crop["growth_duration"]
	instance.max_growth_stage = crop["growth_stages"]
	instance.frame_coordinates = Vector2i(crop["frame_coords"][0], crop["frame_coords"][1])
	return instance

func _ready() -> void:
	$GrowthStageDuration.wait_time = growth_duration / max_growth_stage
	self.frame_coords = frame_coordinates
	self.position = position_coordinates

func _on_growth_stage_duration_timeout() -> void:
	current_growth_stage += 1
	frame += 1
	if current_growth_stage == max_growth_stage:
		$GrowthStageDuration.stop()
