extends Control


@onready var time_label : Label = $LoopTimer/TimeLabel
@onready var seed_pouch : TextureButton = $Tools/SeedPouch
@onready var scythe : TextureButton = $Tools/Scythe
@onready var soil_scanner : TextureButton = $Tools/SoilScanner

func _ready():
	Signals.timer_updated.connect(_on_time_updated)
	seed_pouch.pressed.connect(_on_seed_pouch_pressed)
	scythe.pressed.connect(_on_scythe_pressed)
	soil_scanner.pressed.connect(_on_soil_scanner_pressed)


func _on_time_updated(new_time : float, other : float) -> void:
	time_label.text = str(truncate_to(new_time, 1))


func _on_seed_pouch_pressed():
	# change to seed placement mode
	Signals.emit_signal("planting_mode_entered")
	print("Planting Mode")
	

func _on_scythe_pressed():
	# change to harvesting mode
	Signals.emit_signal("harvesting_mode_entered")
	print("Harvesting Mode")
	

func _on_soil_scanner_pressed():
	# change to scanning mode
	Signals.emit_signal("inspecting_mode_entered")
	print("Inspecting Mode")
	
func truncate_to(value: float, decimals: int) -> float:
	var factor = 10.0 ** decimals
	return float(int(value * factor)) / factor
