# BossController.gd (V3) #SpiderBOSS
extends CharacterBody2D

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

#region Export Variables
@export_group("References")
## The path to the player node.
@export var player_path: NodePath = "../Universal Scene/UNIVERSAL LV Nodes/Player"
## The camera is used to check visibility.
@export var camera_path: NodePath = "../Universal Scene/UNIVERSAL LV Nodes/Player/Camera2D"

@export_group("Movement")
@export var patrol_speed: float = 75.0
@export var chase_speed: float = 950.0
@export var gravity: float = 980.0

@export_group("Attacks")
@export var jump_velocity: float = -600.0
@export var slam_speed: float = 1200.0
@export var min_action_interval: float = 2.5
@export var max_action_interval: float = 5.0
@export_range(0, 1) var chase_chance: float = 0.2 # 20% chance to chase

@export_group("Recovery")
@export var recover_jump_velocity: float = -350.0
## How many pixels above the player the boss should recover to after a slam.
@export var recovery_height_offset: float = 60.0

@export_group("Collision")
@export var bridge_collision_layer: int = 1

@export_group("Safety")
@export var stuck_check_interval: float = 5.0

@export_group("Timer")
@export var time_until_win: float = 90.0
#endregion

#region Private Variables
# Added CHASING state
enum State { INACTIVE, PATROLLING, CHASING, JUMPING_UP, SLAMMING_DOWN, RECOVERING }
var _current_state: State = State.INACTIVE

# Node references
var _action_timer: Timer
var _stuck_timer: Timer
var _notifier: VisibleOnScreenNotifier2D
var _player: Node2D # Using Node2D is more generic and safer

# Internal state variables
var _direction: int = 1
var _original_collision_mask: int
var _last_position: Vector2
var _target_slam_x: float # Stores player's X-pos for the slam
#endregion

#region Godot Functions
func _ready() -> void:
	# The boss starts inactive and won't process physics until visible.
	set_physics_process(false)
	
	_player = get_node_or_null(player_path)
	if not _player:
		push_error("Player node not found! Boss will not function. Check player_path.")
		return

	# Get node references
	_action_timer = $ActionTimer
	_stuck_timer = $StuckTimer
	_notifier = $VisibleOnScreenNotifier2D
	
	# Store original settings
	_original_collision_mask = get_collision_mask()
	_last_position = global_position
	
	# Connect signals
	_action_timer.timeout.connect(_on_action_timer_timeout)
	_stuck_timer.timeout.connect(_on_stuck_timer_timeout)
	# This signal will activate the boss the first time it's on screen.
	_notifier.screen_entered.connect(_on_screen_entered)
	
	# Initial print to show starting state
	print_rich("[color=gray]Boss is [b]INACTIVE[/b][/color]")


func _physics_process(delta: float) -> void:
	# Gravity doesn't apply when recovering or inactive
	if _current_state != State.RECOVERING and _current_state != State.INACTIVE:
		velocity.y += gravity * delta
	
	if time_until_win > 0:
		time_until_win -= delta
		$WinTimerLabel.text = "%.1fs" % time_until_win
	else:
		if $"../Universal Scene":
			if player_path:
				var player: CharacterBody2D = get_node(player_path)
				$"../Universal Scene".on_player_win(player)
	
	match _current_state:
		State.PATROLLING:
			_handle_patrolling(delta)
		State.CHASING:
			_handle_chasing(delta)
		State.JUMPING_UP:
			_handle_jumping_up(delta)
		State.SLAMMING_DOWN:
			_handle_slamming_down(delta)
		State.RECOVERING:
			_handle_recovering(delta)
			
	move_and_slide()
#endregion

#region State Logic
func _handle_patrolling(_delta: float) -> void:
	velocity.x = patrol_speed * _direction
	if is_on_wall():
		_direction *= -1
		if animated_sprite and _direction:
			animated_sprite.flip_h = _direction < 0

# NEW: Chase state logic
func _handle_chasing(_delta: float) -> void:
	# Move towards the player
	var player_direction = sign(_player.global_position.x - global_position.x)
	velocity.x = chase_speed * player_direction
	if animated_sprite and _direction:
		animated_sprite.flip_h = player_direction < 0

func _handle_jumping_up(_delta: float) -> void:
	# Horizontally move towards the target X while jumping up
	velocity.x = sign(_target_slam_x - global_position.x) * patrol_speed
	
	# Stop horizontal movement once close to the target
	if abs(_target_slam_x - global_position.x) < 5.0:
		velocity.x = 0

	# Start slamming once the peak of the jump is reached
	if velocity.y >= 0:
		_transition_to_state(State.SLAMMING_DOWN)

func _handle_slamming_down(_delta: float) -> void:
	# NOTE: The move_and_slide call at the end of _physics_process will handle the movement.
	# We use `move_and_collide` here to specifically detect the bridge collision and transition.
	# However, since you are using CharacterBody2D, it's better to stick to `move_and_slide`
	# and use `get_slide_collision(0)` to check for the bridge *after* the slide.
	
	velocity.y = slam_speed
	
	move_and_slide() # Let the main function call this
	
	# Check for collision after the slide
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		# Check if we hit a collider that is a StaticBody2D AND has the bridge layer
		# Only transition if we're hitting a bridge, not just any floor.
		if collider is StaticBody2D and collider.get_collision_layer_value(bridge_collision_layer):
			_transition_to_state(State.RECOVERING)
			return


# MODIFIED: Recovery logic is now relative to the player
func _handle_recovering(_delta: float) -> void:
	var recovery_target_y = _player.global_position.y - recovery_height_offset
	
	# If we have reached or passed the target recovery height
	if global_position.y <= recovery_target_y:
		global_position.y = recovery_target_y
		velocity = Vector2.ZERO
		_transition_to_state(State.PATROLLING)
#endregion

#region Signal Callbacks
# NEW: Activates the boss one time.
func _on_screen_entered():
	if _current_state == State.INACTIVE:
		print_rich("[color=lime]Boss is on screen, [b]ACTIVATING![/b][/color]")
		set_physics_process(true)
		_stuck_timer.start(stuck_check_interval)
		_transition_to_state(State.PATROLLING)
		# Disconnect the signal so this function never runs again.
		_notifier.screen_entered.disconnect(_on_screen_entered)

# MODIFIED: Now triggers either a chase or a slam.
func _on_action_timer_timeout() -> void:
	if _current_state == State.PATROLLING:
		if randf() < chase_chance:
			_transition_to_state(State.CHASING)
		else:
			_transition_to_state(State.JUMPING_UP)
	elif _current_state == State.CHASING:
		# Always transition to JUMPING_UP or PATROLLING after the chase timer
		if randf() < 0.5: # 50% chance to slam after chasing, otherwise patrol
			_transition_to_state(State.JUMPING_UP)
		else:
			_transition_to_state(State.PATROLLING)

func _on_stuck_timer_timeout() -> void:
	if global_position.distance_to(_last_position) < 1.0:
		if _current_state == State.PATROLLING or _current_state == State.CHASING:
			velocity.y = jump_velocity * 0.5
			print_rich("[color=orange]Boss [b]STUCK[/b], performing small jump.[/color]")
	_last_position = global_position
	_stuck_timer.start()
#endregion

#region Helper Functions
func _start_action_timer() -> void:
	var duration = randf_range(min_action_interval, max_action_interval)
	_action_timer.start(duration)

func _transition_to_state(new_state: State) -> void:
	if _current_state == new_state:
		# For chase, just restart the timer to extend its duration
		if new_state == State.CHASING:
			_start_action_timer()
		return
		
	var old_state = _current_state
	_current_state = new_state
	var bridge_only_mask = 1 << bridge_collision_layer
	
	# Print state transition
	var state_color = "white"
	match new_state:
		State.PATROLLING: state_color = "cyan"
		State.CHASING: state_color = "red"
		State.JUMPING_UP: state_color = "yellow"
		State.SLAMMING_DOWN: state_color = "purple"
		State.RECOVERING: state_color = "blue"
	print_rich("Transition: [color=gray]%s[/color] -> [color=%s][b]%s[/b][/color]" % [State.keys()[old_state], state_color, State.keys()[new_state]])
	
	match new_state:
		State.PATROLLING:
			set_collision_mask(_original_collision_mask)
			collision_shape_2d.disabled = false # Re-enable collision
			$"Death Zone/CollisionShape2D".disabled = false
			_start_action_timer()
		State.CHASING:
			# No collision change, just start the timer for how long to chase
			_start_action_timer()
		State.JUMPING_UP:
			# Store player's position at the start of the jump
			_target_slam_x = _player.global_position.x
			velocity.y = jump_velocity
		State.SLAMMING_DOWN:
			velocity.x = 0 # Slam straight down
			# Only set the collision mask to the bridge layer so we only collide with the bridge
			set_collision_mask(bridge_only_mask)
			collision_shape_2d.disabled = false # Ensure collision is enabled for the slam
			$"Death Zone/CollisionShape2D".disabled = false
		State.RECOVERING:
			# Reset the collision mask before disabling the shape.
			# This is important if you want the boss to collide with platforms on the way up.
			set_collision_mask(_original_collision_mask)
			collision_shape_2d.disabled = true # Disable the shape to go through the bridge
			$"Death Zone/CollisionShape2D".disabled = true
			velocity.x = 0
			velocity.y = recover_jump_velocity
#endregion
