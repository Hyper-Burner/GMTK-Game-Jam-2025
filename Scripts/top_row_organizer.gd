extends HBoxContainer

var targets: Array = []
var currents := []
var textures := []
var labels := []
var speeds := []
var prefix := "x"
var current_index := 0
var is_animating := false

func set_targets(new_targets: Array):
	targets = new_targets

func _ready():
	set_process(false)

	for i in range(get_child_count()):
		var tex = get_child(i)
		var label = tex.get_node("Label")
		textures.append(tex)
		labels.append(label)

		label.visible = false
		label.text = prefix + "0"
		tex.self_modulate.a = 0.0


func start_increment(duration):
	currents = []
	speeds = []
	current_index = 0

	for i in range(targets.size()):
		currents.append(0)
		speeds.append(targets[i] / duration)
		labels[i].text = prefix + "0"
		labels[i].visible = false
		textures[i].self_modulate.a = 0.0

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
			await get_tree().create_timer(0.05).timeout
			_reveal_and_start(current_index)
		else:
			set_process(false)
			Signals.top_row_done.emit()

func _reveal_and_start(index: int):
	textures[index].self_modulate.a = 1.0
	labels[index].visible = true
	is_animating = true
	set_process(true)
