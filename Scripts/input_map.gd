extends Node

func _process(delta):
	if Input.is_action_just_pressed("move_left"):
		print("Move left action triggered!")
	if Input.is_action_pressed("fire"):
		print("Fire action is currently being held down.")
	if Input.is_action_just_released("jump"):
		print("Jump action was just released.")
