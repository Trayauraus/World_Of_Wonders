extends Node2D

@export_group("Spring Settings")
@export var spring_tightness: float = 20.0

@export_group("Hover Settings")
@export var hover_amplitude: float = 4.0
@export var hover_speed: float = 1.5

@onready var count_label: Label = $MOVER/Dash_Count

var _time: float = 0.0
var _target_global_x: float 
var _player_ref: CharacterBody2D

func _ready() -> void:
	# Store reference to the player (the parent)
	_player_ref = get_parent() as CharacterBody2D
	_target_global_x = global_position.x
	
	# Initial label update
	_update_counter_display()

func _process(delta: float) -> void:
	if not _player_ref:
		return

	_time += delta
	
	# 1. SPRINGY X-AXIS
	var player_global_x = _player_ref.global_position.x
	_target_global_x = lerp(_target_global_x, player_global_x, 1.0 - exp(-spring_tightness * delta))
	global_position.x = _target_global_x
	
	# 2. VERTICAL HOVER
	# We use sin() for the bobbing motion
	position.y = sin(_time * hover_speed) * hover_amplitude
	
	# 3. UPDATE ACTUAL COUNTER
	_update_counter_display()

func _update_counter_display() -> void:
	if _player_ref and count_label:
		var current_dashes = _player_ref._dashes_available
		count_label.text = str(current_dashes)
		
		# Celeste-Inspired Color Logic
		match current_dashes:
			0:
				count_label.modulate = Color.CYAN         # Blue/Cyan (Spent)
			1:
				count_label.modulate = Color.RED          # Red (Standard)
			2:
				count_label.modulate = Color.DEEP_PINK    # Pink
			3:
				count_label.modulate = Color.GOLD         # Yellow/Gold
			4:
				count_label.modulate = Color.GREEN        # Green
			5:
				count_label.modulate = Color.PURPLE #Color.REBECCA_PURPLE # White/Purple (High Dash)
			_:
				# For 6+ dashes, we'll stick to White
				count_label.modulate = Color.WHITE
