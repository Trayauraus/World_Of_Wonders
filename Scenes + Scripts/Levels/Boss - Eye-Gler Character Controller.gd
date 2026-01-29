extends CharacterBody2D

# --- References ---
@export_group("External Nodes")
@export var companion_script: Node2D # Drag the Tower/Companion node here
@export var player_node: CharacterBody2D # Drag your Player node here
@export var phase_3_teleport_location: Vector2 = Vector2(500, 500)

@onready var sprite: AnimatedSprite2D = $BossSprite
# Ensure this path matches your unique Area2D for the dash-hit
@onready var boss_collision_area: Area2D = $"BossSprite/Boss Collision" 

# --- Boundary & Enraged Settings ---
@export_group("Enraged / Tower Mode")
@export var boundary_left_x: float = -500.0
@export var boundary_right_x: float = 1500.0
@export var tower_top_y: float = -400.0
@export var dive_end_y: float = 800.0
@export var tower_height_limit: float = -200.0
@export var dive_speed: float = 800.0
@export var dive_random_offset: float = 120.0

# --- Movement & Combat Settings ---
@export_group("Combat Tuning")
@export var move_speed = 150.0
@export var swoop_force = -400.0
@export var swoop_duration = 1.0
@export var swoop_frequency = 3.0
@export var laser_attack_frequency = 5.0
@export var swoop_curve_amount = 200.0

# --- Internal State ---
var original_y: float
var direction: int = 1
var last_known_phase: int = -1
var is_dead: bool = false

var swoop_timer: float = 0.0
var laser_timer: float = 0.0
var dive_timer: float = 0.0
var is_swooping: bool = false
var is_diving: bool = false
var dive_preparing: bool = false
var swoop_time: float = 0.0
var is_positioning_for_swoop: bool = false
var swoop_positioning_timer: float = 0.0
var target_swoop_x: float = 0.0
var swoop_direction: int = 1
var reposition_side: int = 1

func _ready():
	original_y = position.y
	if not player_node:
		player_node = get_tree().get_first_node_in_group("Player")
	
	# Connect the collision area signal
	if boss_collision_area:
		if not boss_collision_area.body_entered.is_connected(_on_boss_collision_entered):
			boss_collision_area.body_entered.connect(_on_boss_collision_entered)

func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		return

	var current_phase = -1
	if companion_script:
		current_phase = companion_script.phase
	
	if current_phase != last_known_phase:
		_on_phase_changed(current_phase)
		last_known_phase = current_phase

	if current_phase == 4:
		process_win_state()
		return 
		
	if position.x < boundary_left_x or position.x > boundary_right_x:
		process_enraged_logic(delta)
	else:
		match current_phase:
			1: process_combat_ai(delta)
			2: velocity = Vector2.ZERO
			3: process_phase_3_logic(delta)

# --- Phase Transition Logic ---
func _on_phase_changed(new_phase: int):
	print("Boss Entering Phase: ", new_phase)
	match new_phase:
		1:
			position.y = original_y
			position.x = 180
		3:
			position = phase_3_teleport_location
			# Crucial: Enable the hitbox so it can be dashed into
			if boss_collision_area:
				boss_collision_area.set_deferred("monitoring", true)
				boss_collision_area.set_deferred("monitorable", true)

# --- Mode: Phase 3 (Final Blow) ---
func process_phase_3_logic(_delta):
	velocity = Vector2.ZERO
	move_and_slide()
	
	if has_node("Final Blow MSG"):
		get_node("Final Blow MSG").show()

# --- Win/Defeat State ---
func process_win_state():
	if is_dead: return 
	
	is_dead = true
	print("Boss: I am defeated!")
	velocity = Vector2.ZERO
	
	if boss_collision_area:
		boss_collision_area.set_deferred("monitoring", false)
		boss_collision_area.set_deferred("monitorable", false)

	if has_node("Final Blow MSG"):
		get_node("Final Blow MSG").hide()

# --- Collision Signals ---
func _on_boss_collision_entered(body: Node2D):
	# Only trigger if we are in Phase 3
	if last_known_phase == 3 and body == player_node:
		# CHECK DASH STATE: 
		# Ensure 'is_dashing' matches the variable name in your player script!
		var player_is_dashing = player_node.get("is_dashing") or player_node.get("_is_dashing")
		
		if player_is_dashing:
			print("Critical Hit: Player dashed into boss!")
			if companion_script and companion_script.has_method("change_phase"):
				companion_script.change_phase()
		else:
			print("Player touched boss but wasn't dashing.")

# --- Mode: Enraged (Tower Boundaries) ---
func process_enraged_logic(delta):
	if player_node and player_node.position.y < tower_height_limit:
		handle_circling_behavior(delta)
		return

	if is_diving:
		handle_dive_movement(delta)
	elif dive_preparing:
		handle_dive_positioning(delta)
	else:
		move_left_right(delta)
		dive_timer += delta
		if dive_timer >= randf_range(3.0, 6.0):
			dive_preparing = true
			reposition_side = 1 if player_node.position.x < (boundary_left_x + boundary_right_x) / 2 else -1
			dive_timer = 0.0

func handle_dive_positioning(_delta):
	var escape_x = boundary_right_x - 150 if reposition_side == 1 else boundary_left_x + 150
	if abs(position.x - escape_x) > 50 and position.y > tower_top_y + 100:
		velocity.x = move_speed * 2.0 * reposition_side
		velocity.y = 0 
	else:
		velocity.x = move_toward(velocity.x, 0, 20)
		velocity.y = -dive_speed 
		if position.y <= tower_top_y:
			position.y = tower_top_y
			dive_preparing = false
			is_diving = true
			position.x = player_node.position.x + randf_range(-dive_random_offset, dive_random_offset)
			velocity = Vector2.DOWN * dive_speed
	move_and_slide()

func handle_dive_movement(_delta):
	velocity = Vector2.DOWN * dive_speed
	move_and_slide()
	if position.y >= dive_end_y:
		is_diving = false
		dive_preparing = true
		dive_timer = 0.0 
		reposition_side = 1 if player_node.position.x < (boundary_left_x + boundary_right_x) / 2 else -1

func handle_circling_behavior(_delta):
	var safe_radius = 450.0 
	var orbit_speed = 2.5
	var time = Time.get_ticks_msec() / 1000.0
	var target_offset = Vector2(cos(time * orbit_speed), sin(time * orbit_speed)) * safe_radius
	var target_pos = player_node.position + target_offset
	var circle_speed = move_speed * 1.2
	velocity = position.direction_to(target_pos) * circle_speed
	move_and_slide()

func process_combat_ai(delta):
	if is_swooping:
		handle_swoop_movement(delta)
	elif is_positioning_for_swoop:
		handle_swoop_positioning(delta)
	else:
		move_left_right(delta)
		handle_swoop_timer(delta)
		handle_laser_attack(delta)

func move_left_right(_delta):
	if player_node:
		var target_x = player_node.position.x
		direction = sign(target_x - position.x)
		velocity.x = move_speed * direction
		if position.x < boundary_left_x or position.x > boundary_right_x:
			var target_y = player_node.position.y - 200
			velocity.y = lerp(velocity.y, (target_y - position.y) * 2.0, 0.1)
		else:
			velocity.y = move_toward(velocity.y, 0, 10)
		move_and_slide()

func handle_swoop_timer(delta):
	swoop_timer += delta
	if swoop_timer >= swoop_frequency:
		is_positioning_for_swoop = true
		swoop_positioning_timer = 1.0
		target_swoop_x = position.x + (250 * -direction)
		swoop_direction = direction
		swoop_timer = 0.0

func handle_swoop_positioning(delta):
	velocity.x = (move_speed * 1.5) * sign(target_swoop_x - position.x)
	move_and_slide()
	if abs(position.x - target_swoop_x) < 20:
		position.x = target_swoop_x
		velocity.x = 0
		swoop_positioning_timer -= delta
		if swoop_positioning_timer <= 0:
			is_positioning_for_swoop = false
			is_swooping = true
			swoop_time = 0.0

func handle_swoop_movement(delta):
	swoop_time += delta
	velocity.y = swoop_force * (1.0 - (swoop_time / swoop_duration) * 2.0)
	velocity.x = swoop_curve_amount * swoop_direction * sin((swoop_time / swoop_duration) * PI)
	move_and_slide()
	if swoop_time >= swoop_duration:
		is_swooping = false
		position.y = original_y

func handle_laser_attack(delta):
	laser_timer += delta
	if laser_timer >= laser_attack_frequency:
		laser_timer = 0.0
