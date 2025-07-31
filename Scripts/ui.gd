extends Control


@onready var time_label : Label = $TimeLabel
@onready var seed_pouch : TextureButton = $Tools/SeedPouch
@onready var scythe : TextureButton = $Tools/Scythe
@onready var soil_scanner : TextureButton = $Tools/SoilScanner

func _ready():
	Global.timer_updated.connect(_on_time_updated)
	seed_pouch.pressed.connect(_on_seed_pouch_pressed)
	scythe.pressed.connect(_on_scythe_pressed)
	soil_scanner.pressed.connect(_on_soil_scanner_pressed)


func _on_time_updated(new_time : int) -> void:
	#time_label.text = str(new_time)
	pass

func _on_seed_pouch_pressed():
	# change to seed placement mode
	Global.emit_signal("planting_mode_entered")
	print("Planting Mode")
	

func _on_scythe_pressed():
	# change to harvesting mode
	Global.emit_signal("harvesting_mode_entered")
	print("Harvesting Mode")
	

func _on_soil_scanner_pressed():
	# change to scanning mode
	Global.emit_signal("inspecting_mode_entered")
	print("Inspecting Mode")
	
