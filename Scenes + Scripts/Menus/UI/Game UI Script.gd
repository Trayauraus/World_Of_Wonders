extends Control

@onready var Score_Label: Label = $UI/Game_Score_Label
@onready var Total_T_Label: Label = $UI/Game_Total_T_Label
@onready var Time_Label: Label = $UI/Game_Time_Label
@onready var Game_FPS_Label: Label = $UI/Game_FPS_Label

@export var start_timer_instantly = true

var elapsed_time: float = 0.0
var is_timer_active: bool = false

func _ready():
	if start_timer_instantly:
		start_timer()

func start_timer():
	#print_rich("[color=orange]DOUG, THE TIMER!")
	is_timer_active = true

func stop_timer():
	is_timer_active = false

func _process(delta: float) -> void:
	if Global.Force_Stop_Time:
		return
	if Score_Label:
		Score_Label.text = str(Global.CoinCount)
	if is_timer_active:
		elapsed_time += delta
		
		# Update the "current time" label with milliseconds
		Time_Label.text = format_time_with_milliseconds(elapsed_time)
		
		# Update the "total game time" label from the global variable
		Total_T_Label.text = format_time(Global.Total_Time + elapsed_time)
	if Game_FPS_Label:
		Game_FPS_Label.text = "FPS: %d\n" % Engine.get_frames_per_second()
		

func format_time_with_milliseconds(time_in_seconds: float) -> String:
	var minutes: int = int(fmod(time_in_seconds, 3600) / 60)
	var seconds: int = int(fmod(time_in_seconds, 60))
	var milliseconds: int = int(fmod(time_in_seconds, 1) * 100)
	
	return "%03d:%02d:%02d" % [minutes, seconds, milliseconds]

func format_time(time_in_seconds: float) -> String:
	var hours: int = int(time_in_seconds / 3600)
	var minutes: int = int(fmod(time_in_seconds, 3600) / 60)
	var seconds: int = int(fmod(time_in_seconds, 60))
	var milliseconds: int = int(fmod(time_in_seconds, 1) * 100)
	
	return "%03d:%02d:%02d:%02d" % [hours, minutes, seconds, milliseconds]

func _exit_tree():
	# Add the elapsed time of this scene to the global total
	Global.Total_Time += elapsed_time
	# This will correctly save the time whether you change scenes or restart the same one.
	Global.save_game(Global.current_sav_file)
	print_rich("[color=purple]Global.Total_Time + save file updated due to exit_tree() called. ", Global.Total_Time)

func _force_global_time_update():
	is_timer_active = false
	Global.Total_Time += elapsed_time
	# This will correctly save the time whether you change scenes or restart the same one.
	print("FORCED Global.Total_Time Update!.Value: ", Global.Total_Time, " . . . This also stops the timer.")
