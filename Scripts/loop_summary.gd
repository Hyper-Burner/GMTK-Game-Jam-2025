extends Control

@onready var continue_button : TextureButton = $Continue
var duration := 0.5
func _ready():
	visible = false
	Signals.loop_ended.connect(_on_loop_ended)
	continue_button.connect("pressed", _on_continue_pressed)

# when a loop ends, show the summary
func _on_loop_ended():
	visible = true
	var top_row = get_node("Harvested/TopRow")
	var bottom_row = get_node("Time Capsule/BottomRow")
	top_row.set_targets([123, 456, 789])
	bottom_row.set_targets([800, 12, 500])

	Signals.top_row_done.connect(func():
		bottom_row.start_increment(duration)
	)
	top_row.start_increment(duration)

# when the player presses the continue button, hide the summary and start the next loop
func _on_continue_pressed():
	visible = false
	Signals.loop_continued.emit()
	print("Loop started!")
