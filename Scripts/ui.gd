extends Control


@onready var time_label : Label = $LoopTimer/TimeLabel
@onready var seed_pouch : TextureButton = $Tools/SeedPouch
@onready var scythe : TextureButton = $Tools/Scythe
@onready var soil_scanner : TextureButton = $Tools/SoilScanner
@onready var milestone_text : Label = $Milestone/Label
@onready var timer: AnimatedSprite2D = $Timer

func _ready():
	Signals.timer_updated.connect(_on_time_updated)
	Signals.milestone_updated.connect(_on_milestone_updated)
	Signals.loop_started.connect(start_timer)
	Signals.loop_ended.connect(stop_timer)
	seed_pouch.pressed.connect(_on_seed_pouch_pressed)
	scythe.pressed.connect(_on_scythe_pressed)
	soil_scanner.pressed.connect(_on_soil_scanner_pressed)
	

func _on_time_updated(new_time : float, other : float) -> void:
	time_label.text = str(truncate_to(new_time, 1))


func _on_seed_pouch_pressed():
	# change to seed placement mode
	State.set_current_action("Planting")
	print("Planting Mode")
	

func _on_scythe_pressed():
	# change to harvesting mode
	#Signals.emit_signal("harvesting_mode_entered")
	State.set_current_action("Harvesting")
	print("Harvesting Mode")
	

func _on_soil_scanner_pressed():
	# change to scanning mode
	#Signals.emit_signal("inspecting_mode_entered")
	State.set_current_action("Inspecting")
	print("Inspecting Mode")
	
func _on_milestone_updated(milestone : Dictionary):
	# use milestone to update the the text and texture
	pass
	
func truncate_to(value: float, decimals: int) -> float:
	var factor = 10.0 ** decimals
	return float(int(value * factor)) / factor

func start_timer():
	timer.play("default")

func stop_timer():
	timer.stop()
