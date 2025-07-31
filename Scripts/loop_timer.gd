extends TextureRect

const LOOP_TIME = 120

func _ready():
	$Timer.wait_time = LOOP_TIME
	$Timer.autostart = true
	$Timer.connect("timeout", _on_Timer_timeout)
	
# loop triggered
func _on_Timer_timeout():
	print("LOOP ENDED")
