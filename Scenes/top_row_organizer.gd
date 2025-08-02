extends HBoxContainer

var targets := [123, 456, 789]
var currents := []
var labels := []
var speeds := []
var duration := 2.0  
var prefix := "x"
var current_index := 0
var is_animating := false

func _ready():
	set_process(false)

	for child in get_children():
		var label := child.get_node("Label")
		labels.append(label)
		label.visible = false
		label.text = prefix + "0"

	Signals.loop_ended.connect(_on_loop_end)

func _on_loop_end():
	start_increment()

func start_increment():
	currents = []
	speeds = []
	current_index = 0

	for i in range(len(targets)):
		currents.append(0)
		speeds.append(targets[i] / duration) 
		labels[i].text = prefix + "0"
		labels[i].visible = false

	if labels.size() > 0:
		_reveal_and_start(current_index)

func _process(delta):
	if !is_animating or current_index >= labels.size():
		return

	var i = current_index
	if currents[i] < targets[i]:
		var increment: int = ceil(speeds[i] * delta)  
		currents[i] = min(currents[i] + increment, targets[i])
		labels[i].text = prefix + str(currents[i])
	else:
		is_animating = false
		current_index += 1
		if current_index < labels.size():
			await get_tree().create_timer(0.25).timeout
			_reveal_and_start(current_index)
		else:
			set_process(false)

func _reveal_and_start(index: int):
	labels[index].visible = true
	is_animating = true
	set_process(true)
