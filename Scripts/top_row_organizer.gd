extends GridContainer

var targets: Dictionary = {}
var currents: Array = []
var textures: Array = []
var labels: Array = []
var speeds: Array = []
var prefix := "x"
var current_index := 0
var is_animating := false

func set_targets(new_targets: Dictionary):
	targets = new_targets

func _ready():
	set_process(false)
	Signals.loop_ended.connect(_on_loop_end)
	_on_loop_end()

func _on_loop_end():
	labels.clear()
	textures.clear()

	for i in range(get_child_count()):
		var tex = get_child(i)
		var label = tex.get_node("Label")
		textures.append(tex)
		labels.append(label)

		label.visible = false
		label.text = prefix + "0"
		tex.self_modulate.a = 0.0

func start_increment(duration):
	currents.clear()
	speeds.clear()
	current_index = 0

	for i in range(textures.size()):
		var tex = textures[i]
		var name = tex.name
		var target_value = targets.get(name, 0)

		currents.append(0)
		speeds.append(target_value / duration if duration != 0 else 0)
		labels[i].text = prefix + "0"
		labels[i].visible = false
		textures[i].self_modulate.a = 0.0

	if textures.size() > 0:
		_reveal_and_start(current_index)

func _process(delta):
	if !is_animating or current_index >= labels.size():
		return

	var i = current_index
	var name = textures[i].name
	var target = targets.get(name, 0)

	if currents[i] < target:
		var increment: int = ceil(speeds[i] * delta)
		currents[i] = min(currents[i] + increment, target)
		labels[i].text = prefix + str(currents[i])
	else:
		is_animating = false
		current_index += 1
		if current_index < labels.size():
			await get_tree().create_timer(0.075).timeout
			_reveal_and_start(current_index)
		else:
			set_process(false)
			Signals.top_row_done.emit()

func _reveal_and_start(index: int):
	var tex = textures[index]
	var label = labels[index]
	var name = tex.name

	label.visible = true

	if !targets.has(name):
		# No target match → dim and skip animation
		tex.self_modulate.a = 0.3
		label.text = prefix + "0"
		await get_tree().create_timer(0.075).timeout
		current_index += 1
		if current_index < labels.size():
			_reveal_and_start(current_index)
		else:
			Signals.top_row_done.emit()
		return

	# Matched target → animate normally
	tex.self_modulate.a = 1.0
	is_animating = true
	set_process(true)
