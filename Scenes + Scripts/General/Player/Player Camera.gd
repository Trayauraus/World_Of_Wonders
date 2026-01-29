extends Camera2D

@export_group("Cam Settings")
@export var cam_enabled = true

@onready var timer: Timer = $Timer

var IsIdle = false
var original_y: float

@export var position_smoothening: float = 8.0

@export var look_up_value: float = -100.0
@export var look_down_value: float = 75.0

func _ready() -> void:
	if not cam_enabled:
		self.enabled = false
	original_y = position.y

func _process(_delta):
	# Check for movement and reset timer if detected
	if Input.is_action_just_pressed("Left") or Input.is_action_just_pressed("Right"):
		timer.start() # or timer.stop() and timer.start()
		IsIdle = false
		if position_smoothing_speed != position_smoothening:
			position_smoothing_speed = position_smoothening
		
	# Handle idle camera pan
	if IsIdle == true:
		if Input.is_action_pressed("Up"):
			position.y = look_up_value
			position_smoothing_speed = 4
		elif Input.is_action_pressed("Down"):
			position.y = look_down_value
			position_smoothing_speed = 4
		else:
			# Return to original idle position if no up/down input
			position.y = 0
			position_smoothing_speed = 8
	else:
		# Keep camera at original position when not idle
		position.y = original_y
		position_smoothing_speed = 8

func _on_timer_timeout() -> void:
	IsIdle = true
	#print("You are Idle")
