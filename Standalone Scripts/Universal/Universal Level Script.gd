# Universal Level Script.gd
# A universal management script to be attached to the root node of any level scene.
class_name UniversalLevel
extends Node2D

#region EXPORTED PROPERTIES
## ---------------------------
## --- EXPORTED PROPERTIES ---
## ---------------------------

@export var use_universal_tilemap: bool = true

@export_group("Environment Setup")
## The DEFAULT environment resource to load when the level starts.
@export var enable_environment: bool = true
@export var default_environment: LevelEnvironmentData = preload("res://Resources/Environmental/Lava.tres")

## Toggles Background visibility
@export var use_bg: bool = true
## Allows setting of the BG Image
@export var bg_img: Texture2D = preload("res://Assets/[General Art]/Backgrounds/Background.png")
## Allows setting of the Cave BG Image
@export var cave_bg_img: Texture2D = preload("res://Assets/[General Art]/Backgrounds/Background.png")
## Toggles the cave variant for the selected environment.
@export var is_cave: bool = false
## Forces the player's point light to stay on, regardless of the 'is_cave' setting.
@export var force_player_light_on: bool = false

@export_group("Level Mechanics")
## The base strength of the wind in this level. This value is passed to the player.
@export var wind_force: float = 3500.0

@export_group("Player Camera")
@export var player_camera_zoom: float = 2.4
## In order it is: Limit Up, Down, Left, Right. Negatives are automatically changed so positive only.
@export var camera_limit: Vector4i = Vector4i.ZERO
#endregion


#region NODE REFERENCES (ONREADY)
## ---------------------
## --- NODE ONREADYS ---
## ---------------------

@onready var player = $"UNIVERSAL LV Nodes/Player"
@onready var player_cam = $"UNIVERSAL LV Nodes/Player/Camera2D"
@onready var player_light: PointLight2D = $"UNIVERSAL LV Nodes/Player/Player Light"
@onready var bg_normal_color_rect: CanvasModulate = $"UNIVERSAL LV Nodes/BG/Background/Parallax Layer/Colored BG"
@onready var bg_cave_color_rect: CanvasModulate = $"UNIVERSAL LV Nodes/BG/Background Cave/Colored BG"
@onready var world_environment: WorldEnvironment = $"UNIVERSAL LV Nodes/WorldEnvironment"
@onready var gpu_particles_2d: GPUParticles2D = $"UNIVERSAL LV Nodes/Ash Follow Cam/GPUParticles2D"
@onready var directional_light_container: Node = $"Directional Light"

# Get references to all wind particles to set their color
@onready var wind_particles_color_L: CPUParticles2D = $"UNIVERSAL LV Nodes/Ash Follow Cam/WIND/CPU Particles ColouredL"
@onready var wind_particles_color_R: CPUParticles2D = $"UNIVERSAL LV Nodes/Ash Follow Cam/WIND/CPU Particles ColouredR"
#endregion


#region PRIVATE VARIABLES
## ------------------------
## --- PRIVATE VARIABLES ---
## ------------------------
const DEFAULT_BG = preload("res://Assets/[General Art]/Backgrounds/Background.png")

# Holds the currently active resource
var _current_environment_resource: LevelEnvironmentData

var ui_disabled = false
var _current_level_number: int = 0 
#endregion


#region GODOT BUILT-IN METHODS
#==============================================================================
# --- BUILT-IN GODOT FUNCTIONS ---
#==============================================================================
func _ready() -> void:
	# --------------------------------------------------------
	# LEVEL NUMBER EXTRACTION
	# --------------------------------------------------------
	var root_node_name: String = name
	if get_parent():
		root_node_name = get_parent().name
		print_rich("[color=cyan]Root/Level Node Name (via get_parent()):[/color] " + root_node_name)
	else:
		push_warning("UniversalLevel: Script is attached to the tree root, cannot get parent's name.")

	if root_node_name.length() >= 3:
		var level_number_string = root_node_name.substr(0, 3)
		if level_number_string.is_valid_int():
			_current_level_number = level_number_string.to_int()
			print_rich("[color=cyan]Extracted Level Number: %d[/color]" % _current_level_number)
	# --------------------------------------------------------
	
	if player_cam:
		_zoom_player_camera(player_camera_zoom)
	
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		_setup_mobile_controls() # Moved logic to helper function at bottom

	if $TileMaps:
		if not use_universal_tilemap:
			print_rich("[color=yellow]Removed Default Tilemap From Scene.[/color]")
			$TileMaps.queue_free()
			
	if not player or not bg_normal_color_rect or not world_environment:
		push_warning("UniversalLevel: One or more required nodes were not found. Please check paths.")
	
	if force_player_light_on:
		player_light.show()
	
	if use_bg:
		_toggle_bg_nodes(true)
		
	if bg_img != DEFAULT_BG:
		if $"UNIVERSAL LV Nodes/BG/Background/Parallax Layer/BG IMG":
			$"UNIVERSAL LV Nodes/BG/Background/Parallax Layer/BG IMG".texture = bg_img
	
	if cave_bg_img != DEFAULT_BG:
		if $"UNIVERSAL LV Nodes/BG/Background Cave/ParallaxLayer/Cave BG IMG":
			$"UNIVERSAL LV Nodes/BG/Background Cave/ParallaxLayer/Cave BG IMG".texture = cave_bg_img
	
	if camera_limit != Vector4i.ZERO:
		_set_player_camera_limit(camera_limit)
	
	# Load the default environment resource if one is assigned
	if not enable_environment:
		print("Disabled Emvironment. Ensure scene has it's own.")
		return
	if default_environment:
		change_environment_resource(default_environment)
	else:
		push_warning("UniversalLevel: No 'Default Environment' resource assigned in Inspector!")


func _input(_event: InputEvent):
	if Input.is_action_just_pressed("Pause"):
		if not Global.is_dead:
			add_or_remove_pause_menu()
			
	if OS.is_debug_build() and Input.is_action_pressed("Dev_Button"):
		if player:
			on_player_win(player)
		else: 
			print_rich("[color=red]DEBUG ERROR IN UNIVERSAL: COULD NOT CALL PLAYER WIN")
	
	if Input.is_action_just_pressed("Graphics_Quality"):
		Global.Environment_On = !Global.Environment_On
		Global.Particles_On = Global.Environment_On
		# Re-apply current resource to toggle effects
		if _current_environment_resource:
			_apply_environment(_current_environment_resource)
	
	if Input.is_action_just_pressed("UI_Toggle"):
		print("UI Toggled: ", ui_disabled)
		if $"Current UI":
			if ui_disabled:
				$"Current UI".show()
			else:
				$"Current UI".hide()
		ui_disabled = !ui_disabled

func add_or_remove_pause_menu():
	# Load and instantiate the scene
	var pause_menu_scene = preload("res://Scenes + Scripts/Menus/UI/Pause_Menu.tscn")
	var pause_menu_instance = pause_menu_scene.instantiate()

	# Get the UI container node
	var current_ui = $"Current UI"
	if current_ui == null: return

	# Check for conflicting menus
	if current_ui.has_node("Win Screen") or current_ui.has_node("Options Menu"):
		return 

	var rope_manager_node = get_node_or_null("../Rope")
	
	if current_ui.has_node("Pause Menu"):
		# --- UNPAUSE LOGIC ---
		var p_menu = $"Current UI/Pause Menu"
		if p_menu != null:
			p_menu.queue_free()
			if rope_manager_node: _set_rope_physics_state(rope_manager_node, false)
			Engine.time_scale = 1
	else:
		# --- PAUSE LOGIC ---
		current_ui.add_child(pause_menu_instance)
		pause_menu_instance.name = "Pause Menu"
		if rope_manager_node: _set_rope_physics_state(rope_manager_node, true)
		Engine.time_scale = 0

func _set_rope_physics_state(rope_manager_node: Node, do_pause: bool):
	var sleeping_state = do_pause
	var freeze_state = do_pause
	for rope_container_name in ["RopeMain", "RopeLeft", "RopeRight"]:
		var rope_container = rope_manager_node.get_node_or_null(rope_container_name)
		if rope_container:
			for child in rope_container.get_children():
				if child is RigidBody2D:
					child.sleeping = sleeping_state
					child.freeze = freeze_state
#endregion


#region PUBLIC API
#==============================================================================
# --- PUBLIC API FUNCTIONS ---
#==============================================================================

func _on_death_body_entered(body):
	var current_ui = $"Current UI"
	if current_ui != null and current_ui.has_node("Death Screen"):
		return 
	
	if body is not TileMapLayer and (body.is_in_group("Player") or body.is_in_group("Enemy")):
		print("Player Detected In DEATHZONE")
		if Global.Instant_Respawn:
			Engine.time_scale = 0.75
			var death_timer = $"Collisions or AREA 2Ds/Death Zone/Timer"
			if death_timer:
				Global.is_dead = true
				death_timer.start()
				if player: player.flashplayer()
				if $"LV Audio/SFX/Hurt SFX": $"LV Audio/SFX/Hurt SFX".play()
		else:
			Global.is_dead = true
			player.flashplayer()
			await get_tree().create_timer(0.3).timeout
			Engine.time_scale = 1
			Global.is_dead = false
			get_tree().reload_current_scene()

func on_player_death() -> void:
	print_rich("[color=red]LEVEL: Player has died..")
	var death_screen_scene = preload("res://Scenes + Scripts/General/Death Handler/Death Screen.tscn")
	var death_screen_instance = death_screen_scene.instantiate()
	var current_ui = $"Current UI"
	if current_ui != null:
		current_ui.add_child(death_screen_instance)
	death_screen_instance.name = "Death Screen"
	Engine.time_scale = 0

func _on_timer_timeout() -> void:
	Global.is_dead = true

func on_player_win(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var win_screen_scene = preload("res://Scenes + Scripts/Menus/UI/Win_Screen.tscn")
		var win_screen_instance = win_screen_scene.instantiate()
		
		var current_ui = $"Current UI"
		if current_ui != null:
			if current_ui.has_node("Win Screen"): return
			print_rich("[color=green]LEVEL: Player has won! Win Screen Added..")
			
			var scene_root = get_owner()
			if scene_root:
				var win_sfx_node = scene_root.get_node_or_null("Universal Scene/LV Audio/SFX/Win SFX")
				if win_sfx_node: win_sfx_node.play()
			
			current_ui.add_child(win_screen_instance)
			win_screen_instance.name = "Win Screen"
			Engine.time_scale = 0

func enable_wind_left_to_right(body: Node2D) -> void:
	if body.is_in_group("Player"): activate_wind(1.0)

func enable_wind_right_to_left(body: Node2D) -> void:
	if body.is_in_group("Player"): activate_wind(-1.0)

func activate_wind(direction: float) -> void:
	if player and player.has_method("start_wind"):
		player.start_wind(wind_force * direction)

func deactivate_wind(body: Node2D) -> void:
	if not body.is_in_group("Player"): return
	if player and player.has_method("stop_wind"):
		player.stop_wind()

#endregion


#region RESOURCE ENVIRONMENT METHODS
#==============================================================================
# --- NEW RESOURCE BASED ENVIRONMENT SYSTEM ---
#==============================================================================

## Call this to switch the entire environment theme using a Resource
func change_environment_resource(new_resource: LevelEnvironmentData) -> void:
	_current_environment_resource = new_resource
	_apply_environment(new_resource)

## Internal function to apply the data from the resource
func _apply_environment(data: LevelEnvironmentData) -> void:
	if not data:
		push_error("UniversalLevel: Cannot apply environment, Resource is null.")
		return

	# Determine correct resources based on whether we're in a cave or not
	var bg_color = data.cave_color if is_cave else data.ambient_color
	var env_resource = data.world_env_cave if is_cave else data.world_env_normal
	var light_packed = data.dir_light_cave if is_cave else data.dir_light_normal
	
	# If cave light is missing, fallback to normal light
	if is_cave and light_packed == null:
		light_packed = data.dir_light_normal

	# Update Light
	_update_directional_light(light_packed)

	# Update World Environment
	if env_resource and world_environment:
		if Global.Environment_On:
			world_environment.environment = env_resource
		else:
			world_environment.environment = null

	# Tween Colors
	var tween = create_tween()
	tween.set_parallel(true)
	if bg_normal_color_rect and bg_cave_color_rect:
		tween.tween_property(bg_normal_color_rect, "color", bg_color, 1.0)
		tween.tween_property(bg_cave_color_rect, "color", bg_color, 1.0)
	
	# Update Particles
	if $"UNIVERSAL LV Nodes/Ash Follow Cam":
		if not Global.Particles_On:
			$"UNIVERSAL LV Nodes/Ash Follow Cam".hide()
			if gpu_particles_2d: gpu_particles_2d.emitting = false
		else:
			$"UNIVERSAL LV Nodes/Ash Follow Cam".show()
			if gpu_particles_2d:
				gpu_particles_2d.emitting = true
				if data.gpu_particles_material:
					gpu_particles_2d.process_material = data.gpu_particles_material
	
	# Update Wind Particle Color
	if wind_particles_color_L: wind_particles_color_L.color = data.wind_color
	if wind_particles_color_R: wind_particles_color_R.color = data.wind_color
	
	# Update Player Light Visibility
	if player_light:
		if force_player_light_on or is_cave:
			player_light.show()
		else:
			player_light.hide()

func _update_directional_light(light_packed: PackedScene) -> void:
	if not directional_light_container: return

	# Clear previous light
	for child in directional_light_container.get_children():
		child.queue_free()

	if light_packed == null:
		print_rich("[color=yellow]Warning: No directional light scene in current Environment Resource.[/color]")
		return

	# Instance new light
	var light_instance = light_packed.instantiate()
	directional_light_container.add_child(light_instance)

#endregion


#region HELPER METHODS
#==============================================================================
# --- PRIVATE HELPER FUNCTIONS ---
#==============================================================================

func _zoom_player_camera(zoom_size: float):
	if not player or not player_cam: return
	
	if zoom_size == player_cam.zoom.x and zoom_size == player_cam.zoom.y:
		return
	player.change_camera_zoom(zoom_size)

func _set_player_camera_limit(camera_limits: Vector4):
	if not player: return
	player.set_camera_limit(camera_limits)

func get_current_level_number() -> int:
	return _current_level_number

func _toggle_bg_nodes(state: bool):
	if $"UNIVERSAL LV Nodes/BG/Background": $"UNIVERSAL LV Nodes/BG/Background".visible = state
	if $"UNIVERSAL LV Nodes/BG/Background Cave": $"UNIVERSAL LV Nodes/BG/Background Cave".visible = state
	if $"UNIVERSAL LV Nodes/Ash Follow Cam": $"UNIVERSAL LV Nodes/Ash Follow Cam".visible = state
	if $"Current UI": $"Current UI".visible = state

func _setup_mobile_controls():
	print_rich("[color=green]Android / iOS Device Detected. Added Mobile Controls..")
	var touch_controls_scene = preload("res://Scenes + Scripts/Menus/UI/Touch Controls.tscn")
	var touch_controls_instance = touch_controls_scene.instantiate()
	var current_ui = self
	if current_ui != null:
		if current_ui.has_node("Win Screen"): return
		current_ui.add_child(touch_controls_instance)
		touch_controls_instance.name = "Touch Controls"
		var pause_button: TouchScreenButton = touch_controls_instance.get_node_or_null("Pause")
		if pause_button:
			pause_button.pressed.connect(add_or_remove_pause_menu)
			if $"Current UI/Game UI/UI/Game_FPS_Label":
				$"Current UI/Game UI/UI/Game_FPS_Label".position.x = 1030.0

#endregion


#region SIGNAL CONNECTION METHODS
#==============================================================================
# --- FUNCTIONS FOR SIGNAL CONNECTIONS ---
#==============================================================================

func connect_cave_enter_zone(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_cave = true
		if _current_environment_resource:
			_apply_environment(_current_environment_resource)

func connect_cave_exit_zone(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_cave = false
		if _current_environment_resource:
			_apply_environment(_current_environment_resource)

# NOTE: The old string-based functions (set_desert_environment, etc.) 
# have been removed. Use the EnvironmentTrigger script on your Area2D 
# to switch environments using Resources.

#endregion
