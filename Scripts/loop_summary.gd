extends Control

@onready var continue_button : TextureButton = $Continue

func _ready():
	visible = false
	Signals.loop_ended.connect(_on_loop_ended)
	continue_button.connect("pressed", _on_continue_pressed)

# when a loop ends, show the summary
func _on_loop_ended():
	visible = true

# when the player presses the continue button, hide the summary and start the next loop
func _on_continue_pressed():
	visible = false
	Signals.loop_continued.emit()
	print("Loop started!")
