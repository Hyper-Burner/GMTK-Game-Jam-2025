extends Control

@onready var icons: Array = [$Ready, $Set, $Plant]

func _ready():
	Signals.in_pre_loop.connect(_pre_loop)
	for icon in icons:
		icon.visible = false
	Signals.pre_loop_ready.emit()

	
func _pre_loop():
	await get_tree().create_timer(1.0).timeout
	for i in icons.size():
		for icon in icons:
			icon.visible = false

		# Show current one
		icons[i].visible = true

		# Wait for 1 second
		await get_tree().create_timer(1.0).timeout

	# Finally hide the last one
	icons[icons.size() - 1].visible = false
	Signals.pre_loop_done.emit()
