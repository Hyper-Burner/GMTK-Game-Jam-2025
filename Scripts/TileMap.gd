extends Node2D

@onready var ground = $Ground
@onready var crops = $Crops
@onready var highlight = $Highlight

var source_id: int
var selected_tile: Vector2i
var placement_mode: bool

func _ready() -> void:
	Global.placement_mode_entered.connect(placement_mode_entered)
	Global.placement_mode_exited.connect(placement_mode_exited)

func _physics_process(delta: float) -> void:
	if true:
		highlight.clear()
		highlight.set_cell(get_tile_position(get_global_mouse_position()), 0, Vector2i(0, 0))

func get_tile_position(global_position: Vector2) -> Vector2i:
	var local_position = ground.to_local(global_position)
	var tile_position = ground.local_to_map(local_position)
	
	return tile_position

func placement_mode_entered(seed: String):
	placement_mode = true

func placement_mode_exited():
	placement_mode = false
