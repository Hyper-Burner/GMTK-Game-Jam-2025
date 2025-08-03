extends Control

@onready var continue_button: TextureButton = $Continue
@onready var ui_board: TextureRect = $TextureRect
var tween: Tween
var screen_size
const LOAD_DURATION = 0.5

func _ready():
	visible = false
	ui_board.self_modulate.a = 0.8
	# Ensure manual positioning works
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	self.size = Vector2(0, 315)  # Optional: set if size is undefined in editor

	# Start off-screen at the bottom
	screen_size = get_viewport().size
	self.position = Vector2(80, screen_size.y)

	# Connect signals
	Signals.loop_ended.connect(_on_loop_ended)
	continue_button.connect("pressed", _on_continue_pressed)

func pop_up():
	var target_y = screen_size.y - size.y
	tween = create_tween()
	tween.tween_property(self, "position", Vector2(80, target_y), 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
func slide_out():
	if tween and tween.is_running():
		tween.kill()  # Stop any ongoing animation
	tween = create_tween()
	tween.tween_property(self, "position", Vector2(80, screen_size.y), 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
# when a loop ends, show the summary
func _on_loop_ended():
	visible = true
	pop_up()
	var top_row = get_node("Harvested/TopRow")
	var bottom_row = get_node("Time Capsule/BottomRow")
	top_row.set_targets(Milestone.current_loop_score)
	bottom_row.set_targets(Inventory.time_capsule_inventory)
	await get_tree().create_timer(0.75).timeout
	Signals.top_row_done.connect(func():
		bottom_row.start_increment(LOAD_DURATION)
	)
	top_row.start_increment(LOAD_DURATION)

# when the player presses the continue button, hide the summary and start the next loop
func _on_continue_pressed():
	slide_out()
	visible = true
	Signals.loop_continued.emit()
	print("Loop started!")
