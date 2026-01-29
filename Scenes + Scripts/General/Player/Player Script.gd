# ==============================================================================
# Player Controller for a 2D Platformer (Revision 11 - Auto-Wake & Idle Zoom)
# ==============================================================================
extends CharacterBody2D

#region Exports and Configuration
# -- Movement & Physics --
@export var speed: float = 80.0
@export var jump_velocity: float = -250.0 
@export var roll_speed: float = 180.0

# -- Dash --
@export var dash_speed: float = 360.0
@export var max_dash_count: int = 2
@export_group("Dash Tuning")
@export var dash_horizontal_multiplier: float = 0.9
@export var dash_vertical_multiplier: float = 1.4
@export var ghost_scene: PackedScene ## Drag your ghost_effect.tscn here
@export var ghost_spawn_interval: float = 0.05 ## How frequently ghosts appear

# -- Camera Shake (NEW) --
@export_group("Camera Shake")
@export var dash_shake_intensity: float = 5.0 ## How violent the shake is
@export var shake_decay: float = 10.0 ## How fast the shake stops (Higher = stops faster)

# -- Timings --
@export var coyote_time: float = 0.2
@export var jump_buffer_time: float = 0.1

# -- Animation Upgrades --
@export_group("Idle Animations")
@export var idle_anim_count: int = 5 ## Amount of "Idle_X" animations you have.
@export var can_sleep: bool = true ## Can the player fall asleep?
@export var idle_wait_min: float = 5.0
@export var idle_wait_max: float = 14.0
## Seconds until sleep is possible (The start of the window)
@export var sleep_guarantee_time: float = 60.0 
## The window duration added to the guarantee time (e.g., 60s to 60+20s)
@export var sleep_window_variance: float = 20.0

# -- Auto-Wake (NEW) --
@export_group("Auto-Wake")
@export var auto_wake_min: float = 150.0 ## 2 mins 30 seconds
@export var auto_wake_max: float = 195.0 ## 3 mins 15 seconds

# -- Idle Camera Zoom (NEW) --
@export_group("Idle Camera Zoom")
@export var camera_zoom_idle_min: float = 20.0 ## Time standing still before zoom starts
@export var camera_zoom_idle_max: float = 55.0
@export var camera_zoom_target: float = 6.0  ## What zoom level to reach (higher = closer)
@export var camera_zoom_in_time: float = 3.4   ## Duration of the zoom-in animation
@export var camera_zoom_out_multiplier: float = 3.6   ## Duration of the zoom-in animation
@export var camera_zoom_curve: Curve           ## Optional: for fancy easing

# -- Wind --
@export_group("Wind")
@export var gust_duration_min: float = 6.0 
@export var gust_duration_max: float = 10.0
@export var lull_duration_min: float = 3.0      
@export var lull_duration_max: float = 5.0      
@export var wind_dash_dampening: float = 0.15

# -- Debug Mode --
@export_group("Debug")
@export var debug_mode_multiplier: float = 1.7

# -- Effects --
@export_group("") 
@export var fade_on_start: bool = true
@export var has_light: bool = true

# -- Gameplay --
@export_group("Fall") 
@export var cant_move_until_floor_touched: bool = false
@export var force_spawn_in_sky: bool = false
@export var no_music_until_landed: bool = false
@export var black_fade_on_landing: bool = false
@export var spawn_height: float = 100.0
@export var fall_to_ground_speed: float = 80.0
#endregion

#region Node References
@onready var jump_sound: AudioStreamPlayer = $SFX/Jump
@onready var dash_left_sound: AudioStreamPlayer = $SFX/DashLeft
@onready var dash_right_sound: AudioStreamPlayer = $SFX/DashRight
@onready var roll_anim_loop_timer: Timer = $Timers/RollAnimLoop
@onready var wind_interval_timer: Timer = $Timers/WindIntervalTimer
@onready var camera_2d: Camera2D = $Camera2D # Direct Reference for shake
@onready var camera_idle_timer: Timer = $Camera2D/Timer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var dash_particles: GPUParticles2D = $DashParticle
@onready var left_wall_raycast: RayCast2D = $RayCast2DLeft
@onready var right_wall_raycast: RayCast2D = $RayCast2DRight
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var screen_fader = $BlackColor
@onready var dev_mode_indicator: Sprite2D = $"DEBUG DEV/DevModeIndicator"
@onready var player_light: PointLight2D = $"Player Light"

# -- Wind Particles --
@onready var wind_particles_left_color: CPUParticles2D
@onready var wind_particles_left_gray: CPUParticles2D
@onready var wind_particles_right_color: CPUParticles2D
@onready var wind_particles_right_gray: CPUParticles2D
#endregion

#region State Variables
var _is_dev_mode: bool = false
var _can_jump: bool = true
var _jump_buffer_active: bool = false
var _is_dashing: bool = false
var _dashes_available: int = max_dash_count
var _can_dash: bool = true
var _is_rolling: bool = false
var _is_roll_colliding_wall: bool = false
var _roll_direction: int = 1
var _in_roll_loop: bool = false
var _camera_idle_timer_started: bool = true

# Shake State
var _current_shake_strength: float = 0.0

# Idle & Sleep State
var _idle_action_timer: Timer = null
var _last_idle_index: int = -1 # Tracks the last played Idle_X animation
var _current_idle_duration: float = 0.0 # Tracks total time standing still
var _target_sleep_trigger_time: float = -1.0 # Calculated random time for sleep
var _is_sleeping: bool = false   
var _is_waking: bool = false      
var _special_idle_active: bool = false  

# (NEW) Auto-Wake State
var _sleep_timer: float = 0.0
var _target_auto_wake_time: float = 0.0

# (NEW) Camera Zoom State
var _camera_idle_duration: float = 0.0
var _target_camera_zoom_time: float = -1.0
var _original_camera_zoom: Vector2 = Vector2.ONE
var _is_camera_zoomed: bool = false
var _zoom_tween: Tween = null

# Wind State
var _is_windy: bool = false                 
var _is_gusting: bool = false         
var _base_wind_force: float = 0.0      
var _current_wind_force: float = 0.0  
var _wind_direction: int = 1

# Ghost/Trail State
var _ghost_timer: Timer = null

#Variable Storage (Used to keep speed number
var var_store = null
var landing_sequence_active = false

var eerie_ambience_player: AudioStreamPlayer = null
#endregion

func _ready():
	if $"../../MusicFade":
		$"../../MusicFade".play("RESET")
	if not Global.Has_Fallen:
		if no_music_until_landed:
			if $"../../LV Audio/LvMusic":
				$"../../LV Audio/LvMusic".stop()
				
				# Create the player
				eerie_ambience_player = AudioStreamPlayer.new()
				# Load the sound and assign it
				eerie_ambience_player.stream = load("res://Audio/Eerie Ambience.mp3")
				eerie_ambience_player.volume_db = 6
				# Add it to the scene so it can actually play sound
				add_child(eerie_ambience_player)
				# Start playing
				eerie_ambience_player.play()
	
		if cant_move_until_floor_touched:
			Global.Force_Stop_Time = true
		else:
			Global.Force_Stop_Time = false
	else:
		cant_move_until_floor_touched = false
		force_spawn_in_sky = false
		no_music_until_landed = false
		black_fade_on_landing = false
	
	var_store = fall_to_ground_speed
	if force_spawn_in_sky:
		self.global_position.y = self.global_position.y - spawn_height
	if not has_light:
		if player_light:
			player_light.hide()
	
	# Capture initial camera zoom
	if camera_2d:
		_original_camera_zoom = camera_2d.zoom

	# --- Setup Idle Timer ---
	_idle_action_timer = Timer.new()
	_idle_action_timer.one_shot = true
	_idle_action_timer.timeout.connect(_on_idle_action_timeout)
	add_child(_idle_action_timer)
	# --- Setup Ghost Timer (NEW) ---
	_ghost_timer = Timer.new()
	_ghost_timer.wait_time = ghost_spawn_interval
	_ghost_timer.timeout.connect(_add_ghost)
	add_child(_ghost_timer)
	# --- Connect Animation Signal ---
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

	# --- Safely find and assign wind particles ---
	var scene_root = get_owner()
	if scene_root:
		var wind_parent_node = scene_root.get_node_or_null("UNIVERSAL LV Nodes/Ash Follow Cam/WIND")
		if not wind_parent_node:
			wind_parent_node = scene_root.get_node_or_null("Universal Scene/UNIVERSAL LV Nodes/Ash Follow Cam/WIND")
		if wind_parent_node:
			wind_particles_left_color = wind_parent_node.get_node_or_null("CPU Particles ColouredL")
			wind_particles_left_gray = wind_parent_node.get_node_or_null("CPU Particles GrayL")
			wind_particles_right_color = wind_parent_node.get_node_or_null("CPU Particles ColouredR")
			wind_particles_right_gray = wind_parent_node.get_node_or_null("CPU Particles GrayR")
			
			# Safety check before accessing properties
			if wind_particles_right_color: wind_particles_right_color.emitting = false
			if wind_particles_right_gray: wind_particles_right_gray.emitting = false
			if wind_particles_left_color: wind_particles_left_color.emitting = false
			if wind_particles_left_gray: wind_particles_left_gray.emitting = false
		else:
			push_warning("Player Warning: Could not find 'WIND' node. Wind particles will be disabled.")
	else:
		push_warning("Player Warning: Could not get scene root. Wind particles will be disabled.")

	# --- Safely initialize other nodes ---
	if dev_mode_indicator:
		dev_mode_indicator.hide()
	if dash_particles:
		dash_particles.emitting = false
	if wind_interval_timer:
		wind_interval_timer.timeout.connect(_on_wind_interval_timeout)
	
	if animated_sprite:
		animated_sprite.play("NEW_Jump")
	
	if fade_on_start:
		if screen_fader and animation_player:
			screen_fader.show()
			animation_player.play("Black To Visible")
			await get_tree().create_timer(0.6).timeout
			if not black_fade_on_landing:
				screen_fader.hide()
		elif screen_fader:
			screen_fader.hide()
	elif screen_fader:
		screen_fader.hide()


func _input(event: InputEvent) -> void:
	if _is_dev_mode:
		if event is InputEventMouseButton && event.is_pressed() && event.button_index == MOUSE_BUTTON_LEFT:
			global_position = get_global_mouse_position()

func _teleport_player(posit: Vector2):
	print("Called function \"_teleport_player\". Teleporting to ", posit)
	global_position = posit


func _physics_process(delta: float) -> void:
	if OS.is_debug_build():
		_handle_debug_input()

	if not _is_dev_mode:
		if Global.is_dead:
			velocity.y = 200
			velocity.x = 0
			_handle_animation()
			move_and_slide()
			return
#		else:
#			Engine.time_scale = 1
#			Global.is_dead = false
	else:
		Engine.time_scale = 1
		Global.is_dead = false

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var gravity_multiplier = 0.5 if _is_dev_mode else 1.0
	if not is_on_floor():
		velocity.y += gravity * delta * gravity_multiplier

	# Logic pipeline
	_handle_movement() 
	_handle_jump()      
	_handle_dash()      
	_handle_roll()
	_apply_wind(delta)

	move_and_slide()
	_handle_camera_shake(delta) # Apply shake effect
	_handle_animation()
	
	if cant_move_until_floor_touched:
		return
		
	_handle_camera_idle()
	# Manages the timer for idle animations, auto-wake, and camera zoom
	_update_idle_logic(delta)

# ==============================================================================
# Public Functions
# ==============================================================================

func teleport_to(target_position: Vector2) -> void:
	global_position = target_position

func start_wind(force_and_direction: float) -> void:
	_base_wind_force = abs(force_and_direction)
	_wind_direction = sign(force_and_direction)
	_is_windy = true
	_is_gusting = false 
	_on_wind_interval_timeout()

func stop_wind() -> void:
	if wind_particles_right_color:
		wind_particles_right_color.speed_scale = 5.0
		wind_particles_right_gray.speed_scale = 5.0
		wind_particles_left_color.speed_scale = 5.0
		wind_particles_left_gray.speed_scale = 5.0
		wind_particles_right_color.emitting = false
		wind_particles_right_gray.emitting = false
		wind_particles_left_color.emitting = false
		wind_particles_left_gray.emitting = false

	_is_windy = false
	_is_gusting = false
	_current_wind_force = 0.0
	if wind_interval_timer:
		wind_interval_timer.stop()

# ==============================================================================
# Internal Logic Handlers
# ==============================================================================

func _handle_debug_input() -> void:
	if Input.is_action_just_pressed("Debug"):
		_is_dev_mode = not _is_dev_mode
		if dev_mode_indicator:
			dev_mode_indicator.visible = _is_dev_mode
		print_rich("[color=green]Debug Mode Toggled: ", "ON" if _is_dev_mode else "OFF")

func _handle_movement() -> void:
	# 1. Check if we are in the falling state
	if cant_move_until_floor_touched:
		# 2. Check if we hit the floor
		if self.is_on_floor():
			# 3. THE FIX: Only run this if we aren't already running it!
			if not landing_sequence_active:
				_start_landing_sequence()
			
		#Reference var store for original speed
		if Input.is_action_pressed("Down"):
			fall_to_ground_speed = var_store + 80
		else:
			fall_to_ground_speed = var_store
		velocity.y = fall_to_ground_speed
		move_and_slide()
		return
	
	var direction = Input.get_axis("Left", "Right")

	# --- (NEW) Revert Camera Zoom on Move ---
	# Only reverts on user movement as requested
	if direction != 0:
		if _is_camera_zoomed:
			_revert_idle_zoom()
		_reset_idle_state()

	# --- Sleep / Wake Lock ---
	if _is_waking:
		velocity.x = move_toward(velocity.x, 0, speed)
		return 

	if _is_sleeping:
		if direction != 0 or Input.is_action_just_pressed("Jump"):
			_trigger_wakeup()
		velocity.x = move_toward(velocity.x, 0, speed)
		return

	# --- Normal Movement ---
	if direction and animated_sprite:
		animated_sprite.flip_h = direction < 0
		_roll_direction = int(direction)

	if _is_dashing or _is_rolling:
		return

	var current_speed = speed * (debug_mode_multiplier * 1.3 if _is_dev_mode else 1.0)
	if direction:
		velocity.x = direction * current_speed
		_reset_idle_state()
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

func _start_landing_sequence() -> void:
	# Lock the sequence so _physics_process doesn't trigger it again
	landing_sequence_active = true
	
	if black_fade_on_landing:
		if animated_sprite:
			animated_sprite.play("NEW_Damage") # Player hits ground
		
		if animation_player:
			await get_tree().create_timer(0.05).timeout
			if animated_sprite:
				animated_sprite.play("NEW_Death") # Player lay on ground effect
			if $BlackColor:
				$BlackColor.show()
				# Optional: Ensure the screen is black immediately if the animation needs it
				animation_player.play("RESET") 
				if $"../../LV Audio/SFX/Hurt SFX":
					$"../../LV Audio/SFX/Hurt SFX".play()
			
			# Wait 1 second (Death anim plays, screen is black)
			await get_tree().create_timer(1.5).timeout
			
			# Fade back in
			animation_player.play("Black To Visible Long")
			if no_music_until_landed:
				var music_node = $"../../LV Audio/LvMusic"
				if music_node:
					music_node.play()
				if eerie_ambience_player:
					eerie_ambience_player.stop()      # Stop the sound
					eerie_ambience_player.queue_free() # Remove the node from the game
					eerie_ambience_player = null       # Clear the variable
				if $"../../MusicFade":
					$"../../MusicFade".play("None To MUSIC")
				else: print_rich("[color=red]WARNING: Player tried to tween music but could not find Music Fade")
			
			# Wait 1.5 seconds for the fade to finish
			await get_tree().create_timer(1.6).timeout
			
			if $BlackColor:
				$BlackColor.hide()
			
	else:
		# Logic for when there is NO black fade
		if no_music_until_landed:
			var music_node = $"../../LV Audio/LvMusic"
			if music_node:
				music_node.play()
		
		# Keep the delay consistent with the other branch if needed
		await get_tree().create_timer(1.0).timeout

	# --- SEQUENCE FINISHED ---
	
	# Restore control to the player
	Global.Force_Stop_Time = false
	Global.Has_Fallen = true
	cant_move_until_floor_touched = false
	
	# Reset the guard (optional, depends if you want to reuse this logic later without reloading)
	landing_sequence_active = false

func _handle_jump() -> void:
	if is_on_floor():
		_can_jump = true

	if _is_sleeping or _is_waking:
		return

	if not is_on_floor() and velocity.y > 0 and _can_jump and not _is_dev_mode:
		get_tree().create_timer(coyote_time, false).timeout.connect(func(): _can_jump = false)

	if Input.is_action_just_pressed("Jump") or Input.is_action_just_pressed("B_On_Xbox"):
		if is_on_floor() or _can_jump or _is_dev_mode:
			_perform_jump()
		else:
			_jump_buffer_active = true
			get_tree().create_timer(jump_buffer_time, false).timeout.connect(func(): _jump_buffer_active = false)
	
	if _jump_buffer_active and is_on_floor():
		_perform_jump()
		_jump_buffer_active = false

func _handle_dash() -> void:
	if _is_sleeping or _is_waking: return

	if is_on_floor():
		_dashes_available = max_dash_count
		_can_dash = true
		if dash_particles and dash_particles.emitting:
			dash_particles.emitting = false

	if not Input.is_action_just_pressed("Dash") or not _can_dash or _dashes_available <= 0 or _is_rolling:
		return

	_is_dashing = true
	_reset_idle_state()
	# TRIGGER SHAKE HERE
	_current_shake_strength = dash_shake_intensity
	# --- START TRAIL EFFECT ---
	_add_ghost() # Spawn one immediately
	if _ghost_timer:
		_ghost_timer.start()
	# --------------------------

	if not _is_dev_mode:
		_dashes_available -= 1
		if _dashes_available == 0:
			_can_dash = false

	var dash_vector = Input.get_vector("Left", "Right", "Up", "Down").normalized()
	var current_dash_speed = dash_speed * (debug_mode_multiplier * 1.5 if _is_dev_mode else 1.0)
	velocity.x = dash_vector.x * current_dash_speed * (dash_horizontal_multiplier / (2.0 if is_on_floor() else 1.0))
	velocity.y = dash_vector.y * current_dash_speed * dash_vertical_multiplier
	if dash_left_sound and dash_right_sound:
		(dash_left_sound if velocity.x < 0 else dash_right_sound).play()

	if dash_particles:
		dash_particles.emitting = true
	# Stop Dash and Ghost Spawning after 0.3s
	get_tree().create_timer(0.3, false).timeout.connect(func(): 
		_is_dashing = false
		if _ghost_timer:
			_ghost_timer.stop()
	)

func _handle_roll() -> void:
	if _is_sleeping or _is_waking: return

	if Input.is_action_just_released("Roll") and _is_rolling:
		_stop_roll()

	if is_on_floor() and Input.is_action_pressed("Roll") and not _is_rolling:
		_is_rolling = true
		_can_dash = false
		if roll_anim_loop_timer:
			roll_anim_loop_timer.start()

	if _is_rolling:
		var current_roll_speed = roll_speed * (debug_mode_multiplier if _is_dev_mode else 1.0)
		velocity.x = _roll_direction * current_roll_speed
		if left_wall_raycast and right_wall_raycast:
			_is_roll_colliding_wall = right_wall_raycast.is_colliding() or left_wall_raycast.is_colliding()

func _apply_wind(delta: float) -> void:
	if _is_windy:
		var effective_wind_force = _current_wind_force
		if _is_dashing:
			effective_wind_force *= wind_dash_dampening
		if _is_sleeping:
			effective_wind_force *= 0.1 

		velocity.x += effective_wind_force * _wind_direction * delta

func _handle_camera_shake(delta: float) -> void:
	if _current_shake_strength > 0:
		_current_shake_strength = move_toward(_current_shake_strength, 0, shake_decay * delta)
		# Apply random offset based on strength
		var offset = Vector2(
			randf_range(-_current_shake_strength, _current_shake_strength),
			randf_range(-_current_shake_strength, _current_shake_strength)
		)
		if camera_2d:
			camera_2d.offset = offset

##Handles ALL Player Animations
func _handle_animation() -> void:
	if not animated_sprite: 
		return
	if cant_move_until_floor_touched:
		return
	if Global.is_dead:
		animated_sprite.play("NEW_Death")
		return

	# --- Special Idle & Sleep Logic Override ---
	if _is_waking:
		animated_sprite.play("Sleep_Wakeup")
		return
	if _is_sleeping:
		animated_sprite.play("Sleep_Loop")
		return
	if _special_idle_active:
		return 
	if _is_dashing:
		return

	if _is_rolling:
		if _is_roll_colliding_wall and velocity.x == 0:
			animated_sprite.play("NEW_Idle")
		elif _in_roll_loop:
			animated_sprite.play("NEW_RollLoop")
		else:
			animated_sprite.play("NEW_Roll")
		return

	if not is_on_floor():
		animated_sprite.play("NEW_Jump")
		return

	if velocity.x != 0:
		animated_sprite.play("NEW_Run")
	else:
		animated_sprite.play("NEW_Idle")

func _handle_camera_idle() -> void:
	if not camera_idle_timer: 
		return
	if velocity.x == 0 and not _is_rolling:
		if _camera_idle_timer_started:
			camera_idle_timer.start()
			_camera_idle_timer_started = false
	else:
		camera_idle_timer.stop()
		_camera_idle_timer_started = true

# ==============================================================================
# Idle, Sleep & Camera Logic
# ==============================================================================

func _update_idle_logic(delta: float):
	# 1. Reset everything if moving or in transition states
	if velocity.x != 0 or _is_rolling or _is_dashing or _is_waking or Global.is_dead:
		if _idle_action_timer and not _idle_action_timer.is_stopped():
			_idle_action_timer.stop()
		
		# Reset idle timers when moving
		if velocity.x != 0 or _is_dashing or _is_rolling:
			_current_idle_duration = 0.0
			_camera_idle_duration = 0.0
			_target_sleep_trigger_time = -1.0 
			_target_camera_zoom_time = -1.0
		return

	# 2. Track Idle Duration & Auto-Wake Logic
	if velocity.x == 0 and is_on_floor():
		if not _is_sleeping:
			_current_idle_duration += delta
			_camera_idle_duration += delta
		else:
			# Increment sleep timer for auto-wake
			_sleep_timer += delta
			if _sleep_timer >= _target_auto_wake_time:
				_trigger_wakeup()

	# 3. Handle Guaranteed Sleep Trigger
	if _target_sleep_trigger_time < 0:
		_target_sleep_trigger_time = randf_range(sleep_guarantee_time, sleep_guarantee_time + sleep_window_variance)
	
	if can_sleep and _current_idle_duration >= _target_sleep_trigger_time and not _special_idle_active and not _is_sleeping:
		_special_idle_active = true
		animated_sprite.play("Sleep_Begin")

	# 4. Handle "Fidget" Animations
	if _idle_action_timer.is_stopped() and not _special_idle_active and not _is_sleeping:
		var wait_time = randf_range(idle_wait_min, idle_wait_max)
		_idle_action_timer.start(wait_time)
	
	# 5. (NEW) Camera Zoom Logic
	if _target_camera_zoom_time < 0:
		_target_camera_zoom_time = randf_range(camera_zoom_idle_min, camera_zoom_idle_max)
	
	if _camera_idle_duration >= _target_camera_zoom_time and not _is_camera_zoomed:
		_start_idle_zoom()

func _on_idle_action_timeout():
	_special_idle_active = true
	var pool = []
	for i in range(1, idle_anim_count + 1):
		if i == _last_idle_index:
			pool.append(i) 
		else:
			for j in range(5):
				pool.append(i)
	var random_idle_index = pool.pick_random()
	_last_idle_index = random_idle_index
	animated_sprite.play("Idle_" + str(random_idle_index))

func _reset_idle_state():
	_current_idle_duration = 0.0
	_camera_idle_duration = 0.0
	_target_sleep_trigger_time = -1.0
	_target_camera_zoom_time = -1.0
	if animated_sprite: #and "Idle_" in animated_sprite.animation:
		_special_idle_active = false

func _trigger_wakeup():
	if _is_sleeping:
		_is_sleeping = false
		_is_waking = true
		_current_idle_duration = 0.0 
		_sleep_timer = 0.0
		_target_sleep_trigger_time = -1.0
		animated_sprite.play("Sleep_Wakeup")
		_reset_idle_state()

# --- (NEW) Camera Zoom Functions ---

func _start_idle_zoom():
	if not camera_2d: return
	
	# If camera is already more zoomed in than target, don't do anything
	if camera_2d.zoom.x >= camera_zoom_target:
		_is_camera_zoomed = true # Mark as zoomed so we don't keep checking
		return

	# Capture current zoom as original before we start
	_original_camera_zoom = camera_2d.zoom
	_is_camera_zoomed = true
	
	if _zoom_tween: _zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(camera_2d, "zoom", Vector2(camera_zoom_target, camera_zoom_target), camera_zoom_in_time)

func _revert_idle_zoom():
	if not camera_2d: return
	
	_is_camera_zoomed = false
	_camera_idle_duration = 0.0
	_target_camera_zoom_time = -1.0
	
	# Zoom out is 1.25 times faster than zoom in
	var zoom_out_time = camera_zoom_in_time / camera_zoom_out_multiplier
	
	if _zoom_tween: _zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(camera_2d, "zoom", _original_camera_zoom, zoom_out_time)

# -----------------------------------

func _on_animation_finished():
	if animated_sprite.animation == "Sleep_Begin":
		_special_idle_active = false 
		_is_sleeping = true 
		# Initialize Auto-Wake Timer
		_sleep_timer = 0.0
		_target_auto_wake_time = randf_range(auto_wake_min, auto_wake_max)
		animated_sprite.play("Sleep_Loop")
	elif animated_sprite.animation == "Sleep_Wakeup":
		_is_waking = false
		_is_sleeping = false
		_special_idle_active = false
		animated_sprite.play("NEW_Idle")
	elif "Idle_" in animated_sprite.animation:
		_special_idle_active = false
		animated_sprite.play("NEW_Idle")

# ==============================================================================
# Private Helpers and Signal Callbacks
# ==============================================================================

func _perform_jump() -> void:
	_reset_idle_state()
	var current_jump_velocity = jump_velocity
	if _is_dev_mode:
		current_jump_velocity = current_jump_velocity * 1.5
	velocity.y = current_jump_velocity
	if jump_sound:
		jump_sound.play()
	if not _is_dev_mode:
		_can_jump = false

func _stop_roll() -> void:
	if roll_anim_loop_timer:
		roll_anim_loop_timer.stop()
	_is_rolling = false
	_in_roll_loop = false
	_can_dash = true
	if animated_sprite:
		animated_sprite.play("NEW_RollLoopEnd")
		await animated_sprite.animation_finished
		if not _is_rolling:
			animated_sprite.play("NEW_Idle")

func _on_roll_anim_loop_timeout() -> void:
	if _is_rolling:
		_in_roll_loop = true

func _on_wind_interval_timeout() -> void:
	if not _is_windy:
		return
	if not wind_interval_timer or not wind_particles_left_color:
		return

	_is_gusting = not _is_gusting 

	if _is_gusting:
		_current_wind_force = _base_wind_force
		wind_interval_timer.wait_time = randf_range(gust_duration_min, gust_duration_max)
		if wind_particles_right_color: wind_particles_right_color.speed_scale = 1.0
		if wind_particles_right_gray: wind_particles_right_gray.speed_scale = 1.0
		if wind_particles_left_color: wind_particles_left_color.speed_scale = 1.0
		if wind_particles_left_gray: wind_particles_left_gray.speed_scale = 1.0
		
		if Global.Particles_On:
			if _wind_direction > 0: 
				if wind_particles_right_color: wind_particles_right_color.emitting = true
				if wind_particles_right_gray: wind_particles_right_gray.emitting = true
				if wind_particles_left_color: 
					wind_particles_left_color.emitting = false
					wind_particles_left_color.speed_scale = 5.0
				if wind_particles_left_gray: wind_particles_left_gray.speed_scale = 5.0
			else: 
				if wind_particles_left_color: wind_particles_left_color.emitting = true
				if wind_particles_left_gray: wind_particles_left_gray.emitting = true
				if wind_particles_right_color: 
					wind_particles_right_color.emitting = false
					wind_particles_right_color.speed_scale = 5.0
				if wind_particles_right_gray: wind_particles_right_gray.speed_scale = 5.0
		else:
			wind_particles_right_color.emitting = false
			wind_particles_right_gray.emitting = false
			wind_particles_left_color.emitting = false
			wind_particles_left_gray.emitting = false
	else:
		_current_wind_force = 0.0
		wind_interval_timer.wait_time = randf_range(lull_duration_min, lull_duration_max)
		if wind_particles_right_color: 
			wind_particles_right_color.emitting = false
			wind_particles_right_color.speed_scale = 5.0
		if wind_particles_right_gray: wind_particles_right_gray.speed_scale = 5.0
		if wind_particles_left_color: 
			wind_particles_left_color.emitting = false
			wind_particles_left_color.speed_scale = 5.0
		if wind_particles_left_gray: wind_particles_left_gray.speed_scale = 5.0
	wind_interval_timer.start()

func change_camera_zoom(zoom_size: float):
	if camera_2d:
		camera_2d.zoom = Vector2(zoom_size, zoom_size)
		# Update base zoom so a manual change doesn't cause a snap-back
		_original_camera_zoom = camera_2d.zoom
	else:
		print_rich("[color=red]ERROR: Could Not Find CAMERA2D On Player")

func set_camera_limit(camera_limit: Vector4i):
	if camera_2d:
		if camera_limit.x != 0: camera_2d.limit_top = -camera_limit.x
		if camera_limit.y != 0: camera_2d.limit_bottom = camera_limit.y
		if camera_limit.z != 0: camera_2d.limit_left = -camera_limit.z
		if camera_limit.w != 0: camera_2d.limit_right = camera_limit.w
	else:
		print_rich("[color=red]ERROR: Could Not Find CAMERA2D On Player")

func flashplayer():
	animated_sprite.material.set_shader_parameter("flash_modifier", 0.8)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.material.set_shader_parameter("flash_modifier", 0.6)
	await get_tree().create_timer(0.15).timeout
	animated_sprite.material.set_shader_parameter("flash_modifier", 0.85)

# ==============================================================================
# Ghost Trail Functionality
# ==============================================================================
func _add_ghost():
	if not ghost_scene or not animated_sprite: 
		return
	var ghost = ghost_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	var frame_tex = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.texture = frame_tex
	ghost.flip_h = animated_sprite.flip_h
	ghost.scale = animated_sprite.scale
