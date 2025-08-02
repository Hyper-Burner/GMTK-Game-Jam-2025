extends Control

@onready var continue_button: TextureButton = $Continue
var tween: Tween
var screen_size

func _ready():
	visible = false
	print("Popup pos before tween:", position)
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
	tween.tween_property(self, "position", Vector2(80, target_y), 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	print("Visible:", visible)
	print("Popup size:", size)
	print("Popup pos after tween:", position)
	print("Viewport size:", get_viewport().size)
	
func slide_out():
	if tween and tween.is_running():
		tween.kill()  # Stop any ongoing animation

	var screen_size = get_viewport().size
	tween = create_tween()
	tween.tween_property(self, "position", Vector2(80, screen_size.y), 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
const LOAD_DURATION = 0.75
# when a loop ends, show the summary
func _on_loop_ended():
	visible = true
	pop_up()
	var top_row = get_node("Harvested/TopRow")
	var bottom_row = get_node("Time Capsule/BottomRow")
	top_row.set_targets([123, 456, 789])
	bottom_row.set_targets([800, 12, 500])
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
