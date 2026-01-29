# Universal Level Script.gd
# A universal management script to be attached to the root node of any level scene.
# It handles player win/loss conditions, environment setup, and dynamic wind effects.
class_name UniversalMultiplayerLevel
extends Node2D

#region EXPORTED PROPERTIES
## ---------------------------
## --- EXPORTED PROPERTIES ---
## ---------------------------

@export var use_universal_tilemap: bool = true

@export_group("Environment Setup")
## Select the visual theme for the level. This affects colors and environmental effects.
@export_enum("Lava", "Lava DARKENED", "Desert", "Ice", "Grasslands", "ICE DEMO", "Custom", "None") var environment_type: String = "Lava"
##Toggles Background
@export var use_bg: bool = true
##Allows setting of the BG Image
@export var bg_img: Texture2D = preload("res://Assets/[General Art]/Backgrounds/Background.png")
##Allows setting of the Cave BG Image
@export var cave_bg_img: Texture2D = preload("res://Assets/[General Art]/Backgrounds/Background.png")
## Toggles the cave variant for the selected environment.
@export var is_cave: bool = false
## Forces the player's point light to stay on, regardless of the 'is_cave' setting.
@export var force_player_light_on: bool = false

@export_group("CUSTOM Environment Setup")
## The standard background/ambient color
@export var ambient_color: Color = Color("ffffffff")
## The color used when the player enters a cave area
@export var cave_color: Color = Color("262321")
## Color applied to wind particles or shaders
@export var wind_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## The standard WorldEnvironment resource
@export var ambient_env: Environment
## The darkened WorldEnvironment resource for caves
@export var cave_env: Environment

## Path to the ParticleProcessMaterial (.tres) for GPU particles
@export var gpu_particle_color: ParticleProcessMaterial
## The main DirectionalLight2D scene
@export var directional_light: PackedScene
## The DirectionalLight2D scene used in darkened areas
@export var darkened_world_dir_light: PackedScene

@export_group("Level Mechanics")
## The base strength of the wind in this level. This value is passed to the player.
@export var wind_force: float = 3500.0

@export_group("Player Camera")
@export var player_camera_zoom: float = 2.4
##In order it is: Limit Up, Down, Left, Right. Negatives are automatically changed so positive only.
@export var camera_limit: Vector4i = Vector4i.ZERO
#endregion


#region NODE REFERENCES (ONREADY)
## ---------------------
## --- NODE ONREADYS ---
## ---------------------

#@onready var player = $"UNIVERSAL LV Nodes/Player"
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

const _ENVIRONMENT_DATA: Dictionary = {
	"Lava": {
		"normal_color": Color(0.92, 0.272, 0.17), # e8452b
		"cave_color": Color(0.055, 0.0, 0.0),
		"normal_env": "res://Environments/WorldEnvironment.tres",
		"cave_env": "res://Environments/WorldEnvironment.tres",
		"wind_color": Color("c53121ff"),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process RED.tres",
		"directional_light": "res://Assets/Directional Lights/RedDirectionalLight.tscn",
		"darkened_world_dir_light": "res://Assets/Directional Lights/DARKEN World/RedDirectionalLightDARK.tscn"
	},
	"Lava DARKENED": {
		"normal_color": Color(0.67, 0.165, 0.085, 0.839), # e8452b
		"cave_color": Color(0.106, 0.02, 0.0),
		"normal_env": "res://Environments/WorldEnvironment.tres",
		"cave_env": "res://Environments/WorldEnvironment.tres",
		"wind_color": Color("a12518ff"),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process RED.tres",
		"directional_light": "res://Assets/Directional Lights/DARKEN World/RedDirectionalLightDARK.tscn",
		"darkened_world_dir_light":"res://Assets/Directional Lights/DARKEN World/RedDirectionalLightDARKER.tscn"
	},
	"Desert": {
		"normal_color": Color("dfcb00"),
		"cave_color": Color("352f00"),
		"normal_env": "res://Environments/Lv2Environment.tres",
		"cave_env": "res://Environments/Lv2Environment.tres",
		"wind_color": Color("efb824"),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process YELLOW.tres",
		"directional_light": "res://Assets/Directional Lights/DesertDirectionalLight.tscn",
		"darkened_world_dir_light": "" # Intentionally left blank to test fallback
	},
	"Ice": {
		"normal_color": Color("89cddc"),
		"cave_color": Color("262321"),
		"normal_env": "res://Environments/Lv3Environment.tres",
		"cave_env": "res://Environments/Lv3DarkenedEnvironment.tres",
		"wind_color": Color("89cddc"),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process BLUE.tres",
		"directional_light": "res://Assets/Directional Lights/IceDirectionalLight.tscn",
		"darkened_world_dir_light": "res://Assets/Directional Lights/DARKEN World/IceDirectionalLightDARK.tscn"
	},
	"Grasslands": {
		"normal_color":  Color("00922dff"), #Color("00ca42ff"),
		"cave_color": Color("1b271fff"),
		"normal_env": "res://Environments/WorldEnvironment.tres",
		"cave_env": "res://Environments/WorldEnvironment.tres",
		"wind_color": Color("007824ff"),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process GREEN.tres",
		"directional_light": "res://Assets/Directional Lights/DARKEN World/RedDirectionalLightDARK.tscn",
		"darkened_world_dir_light": "res://Assets/Directional Lights/DARKEN World/IceDirectionalLightDARK.tscn"
	},
	"ICE DEMO": {
		"normal_color": Color(0.359, 0.64, 0.696, 1.0),
		"cave_color": Color(0.149, 0.137, 0.129),
		"normal_env": "res://Environments/DEMO/LvDEMOEnvironment.tres",
		"cave_env": "res://Environments/DEMO/LvDEMODarkenedEnvironment.tres",
		"wind_color": Color(0.286, 0.831, 1.0),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process BLUE.tres",
		"directional_light": "res://Assets/Directional Lights/DEMO/ICE DEMO Directional Light.tscn",
		"darkened_world_dir_light": "res://Assets/Directional Lights/DEMO/ICE DEMO DARKENED Directional Light.tscn"
	}
}

var _CUSTOM_ENVIRONMENT_DATA: Dictionary = {
		"Custom": {
		"normal_color": Color(0.0, 0.0, 0.0, 1.0),
		"cave_color": Color(0.0, 0.0, 0.0, 1.0),
		"normal_env": "res://Environments/WorldEnvironment.tres",
		"cave_env": "res://Environments/WorldEnvironment.tres",
		"wind_color": Color(0.0, 0.0, 0.0, 1.0),
		"gpu_particle_color": "res://Assets/Shaders/Shader Process Materials/Particle Process RED.tres",
		"directional_light": "res://Assets/Directional Lights/RedDirectionalLight.tscn",
		"darkened_world_dir_light": "res://Assets/Directional Lights/DARKEN World/RedDirectionalLightDARK.tscn"
	}
}

var _current_level_number: int = 0 # New variable to store the extracted level number
var ui_toggle = false
#endregion

#region NODE REFERENCES
# MULTIPLAYER FIX: Removed the hardcoded player reference. 
# We will detect the local player dynamically via Area2Ds or registration.
var local_player: CharacterBody2D = null
#endregion


#region GODOT BUILT-IN METHODS
#==============================================================================
# --- BUILT-IN GODOT FUNCTIONS ---
#==============================================================================
func _ready() -> void:
	print_rich("[color=green]Multiplayer Universal Scene Node Activated")
	if $"UNIVERSAL LV Nodes/Player":
		local_player = $"UNIVERSAL LV Nodes/Player"
	# --------------------------------------------------------
	# MODIFIED LOGIC: Get Parent Node's Name (The actual scene root)
	# --------------------------------------------------------
	var root_node_name: String = name # Start with the current node's name ("Universal Scene")
	
	# The actual level number is expected to be on the PARENT node.
	if get_parent():
		root_node_name = get_parent().name
		print_rich("[color=cyan]Root/Level Node Name (via get_parent()):[/color] " + root_node_name)
	else:
		# This case handles if Universal Scene is somehow the actual root of the tree
		push_warning("UniversalLevel: Script is attached to the tree root, cannot get parent's name.")

	# Check if the name is at least 3 characters long (for the 3 digits)
	if root_node_name.length() >= 3:
		var level_number_string = root_node_name.substr(0, 3)
		# Attempt to convert the first 3 characters to an integer
		if level_number_string.is_valid_int():
			_current_level_number = level_number_string.to_int()
			print_rich("[color=cyan]Extracted Level Number: %d[/color]" % _current_level_number)
		else:
			push_warning("Level node name ('%s') does not start with a valid 3-digit number." % root_node_name)
	else:
		push_warning("Level node name ('%s') is too short to extract a 3-digit level number." % root_node_name)
	# --------------------------------------------------------
	
	if player_cam:
		
		_zoom_player_camera(player_camera_zoom) ##Ensure player camera is zoomed to specified level value
	
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		print_rich("[color=green]Android / iOS Device Detected. Added Mobile Controls..")
		# Load and instantiate the scene
		var touch_controls_scene = preload("res://Scenes + Scripts/Menus/UI/Touch Controls.tscn")
		var touch_controls_instance = touch_controls_scene.instantiate()

		# Add the instance to the specified location
		var current_ui = self
		if current_ui != null:
			if current_ui.has_node("Win Screen"):
				return #You cant win and pause at the same time
			current_ui.add_child(touch_controls_instance)
			# Set the name of the instantiated scene
			touch_controls_instance.name = "Touch Controls"
			var pause_button: TouchScreenButton = touch_controls_instance.get_node_or_null("Pause")

			if pause_button:
				var error = pause_button.pressed.connect(add_or_remove_pause_menu)
				
				##Move FPS Counter Out Of Way
				if $"Current UI/Game UI/UI/Game_FPS_Label":
					$"Current UI/Game UI/UI/Game_FPS_Label".position.x = 1030.0
				if error != OK:
					push_error("ERROR: Could not connect 'Pause' button signal. Error code: " + str(error))
			else:
				push_warning("WARNING: 'Pause' button node not found inside 'Touch Controls.tscn'.")

	
	if $TileMaps:
		if not use_universal_tilemap:
			print_rich("[color=yellow]Removed Default Tilemap From Scene. This means scene has it's own unique tilemap[/color]")
			$TileMaps.queue_free()
	if not bg_normal_color_rect or not world_environment:
		push_warning("UniversalLevel: One or more required nodes were not found. Please check paths.")
	
	if force_player_light_on:
		player_light.show()
	
		##Unhiding Stuff Hidden In Editor For Easy Editing. Can also be used to add custom bg using the use_bg variable.
	if use_bg:
		if $"UNIVERSAL LV Nodes/BG/Background":
			$"UNIVERSAL LV Nodes/BG/Background".show()
		if $"UNIVERSAL LV Nodes/BG/Background Cave":
			$"UNIVERSAL LV Nodes/BG/Background Cave".show()
		if $"UNIVERSAL LV Nodes/Ash Follow Cam":
			$"UNIVERSAL LV Nodes/Ash Follow Cam".show()
		if $"Current UI":
			$"Current UI".show()
	if bg_img != DEFAULT_BG:
		if $"UNIVERSAL LV Nodes/BG/Background/Parallax Layer/BG IMG":
			$"UNIVERSAL LV Nodes/BG/Background/Parallax Layer/BG IMG".texture = bg_img
	
	if cave_bg_img != DEFAULT_BG:
		if $"UNIVERSAL LV Nodes/BG/Background Cave/ParallaxLayer/Cave BG IMG":
			$"UNIVERSAL LV Nodes/BG/Background Cave/ParallaxLayer/Cave BG IMG".texture = cave_bg_img
	
	
	if camera_limit != Vector4i.ZERO:
		_set_player_camera_limit(camera_limit)
	
	if environment_type == "None":
		if world_environment and not Global.Environment_On:
			world_environment.environment = null
		return
	
	_CUSTOM_ENVIRONMENT_DATA["Custom"] = {
		"normal_color": ambient_color,
		"cave_color": cave_color,
		"normal_env": ambient_env.resource_path if ambient_env else "",
		"cave_env": cave_env.resource_path if cave_env else "",
		"wind_color": wind_color,
		"gpu_particle_color": gpu_particle_color.resource_path if gpu_particle_color else "",
		"directional_light": directional_light.resource_path if directional_light else "",
		"darkened_world_dir_light": darkened_world_dir_light.resource_path if darkened_world_dir_light else ""
	}
	_setup_environment()

func _input(_event: InputEvent):
	if Input.is_action_just_pressed("Pause"):
		if not Global.is_dead:
			add_or_remove_pause_menu()
	if OS.is_debug_build() and Input.is_action_pressed("Dev_Button"):
		on_player_win(local_player)
	
	if Input.is_action_just_pressed("Graphics_Quality"):
		Global.Environment_On = !Global.Environment_On
		Global.Particles_On = Global.Environment_On
		_setup_environment()
	
	if Input.is_action_just_pressed("UI_Toggle"):
		if $"Current UI":
			ui_toggle = !ui_toggle  # <--- YOU NEED THIS LINE TO FLIP THE STATE
			$"Current UI".visible = !ui_toggle 
		else:
			print_rich("[color=red]Failed to find CURRENT UI")

func add_or_remove_pause_menu():
	# Load and instantiate the scene
	var pause_menu_scene = preload("res://Scenes + Scripts/Menus/UI/Pause_Menu.tscn")
	var pause_menu_instance = pause_menu_scene.instantiate()

	# Get the UI container node
	var current_ui = $"Current UI"
	if current_ui == null:
		return

	# Check for conflicting menus
	if current_ui.has_node("Win Screen") or current_ui.has_node("Options Menu"):
		return # Cannot pause while in Win Screen or Options Menu

	# *** FIX IS HERE: Use get_node_or_null() to safely check for the Rope node ***
	var rope_manager_node = get_node_or_null("../Rope")
	
	if current_ui.has_node("Pause Menu"):
		# --- UNPAUSE LOGIC ---
		var p_menu = $"Current UI/Pause Menu"
		if p_menu != null:
			p_menu.queue_free()
			
			## Unpause all rigid bodies in the rope structure
			if rope_manager_node: # Only runs if rope_manager_node is NOT null
				_set_rope_physics_state(rope_manager_node, false)
			
			Engine.time_scale = 1
	else:
		# --- PAUSE LOGIC ---
		current_ui.add_child(pause_menu_instance)
		pause_menu_instance.name = "Pause Menu"
		
		## Pause all rigid bodies in the rope structure
		if rope_manager_node: # Only runs if rope_manager_node is NOT null
			_set_rope_physics_state(rope_manager_node, true)
							
		Engine.time_scale = 0

# ----------------------------------------------------------------------
## Helper function to clean up the pause/unpause logic
# ----------------------------------------------------------------------
func _set_rope_physics_state(rope_manager_node: Node, do_pause: bool):
	var sleeping_state = do_pause
	var freeze_state = do_pause
	# Iterate through the three rope container nodes
	for rope_container_name in ["RopeMain", "RopeLeft", "RopeRight"]:
		var rope_container = rope_manager_node.get_node_or_null(rope_container_name)
		if rope_container:
			for child in rope_container.get_children():
				if child is RigidBody2D:
					child.sleeping = sleeping_state
					child.freeze = freeze_state
					if do_pause:
						# Optional: Keep the print for debugging, but it's not strictly necessary.
						# print("paused segment: ", child.name)
						pass
#endregion



#region PUBLIC API
#==============================================================================
# --- PUBLIC API FUNCTIONS ---
#==============================================================================

func _on_death_body_entered(body):
	var current_ui = $"Current UI"
	if current_ui != null:
		if current_ui.has_node("Death Screen"):
			return #You cant die multiple times
	
	#if Global.WindowFocused == true:
	if body is not TileMapLayer and body.is_in_group("Player") or body is not TileMapLayer and body.is_in_group("Enemy"):
		print("Player Detected In DEATHZONE")
		if Global.Instant_Respawn:
			Engine.time_scale = 0.75
			var death_timer = $"Collisions or AREA 2Ds/Death Zone/Timer"
			if death_timer:
				Global.is_dead = true
				death_timer.start()
				local_player.flashplayer()
				if $"LV Audio/SFX/Hurt SFX":
					$"LV Audio/SFX/Hurt SFX".play()
				else:
					print_rich("[color=red]LEVEL: CANNOT FIND Hurt SFX")
		else:
			Global.is_dead = true
			local_player.flashplayer()
			await get_tree().create_timer(0.3).timeout
			Engine.time_scale = 1
			Global.is_dead = false
			get_tree().reload_current_scene()
	#else:
	#		print_rich("[color=red]Death Stopped By Being Out Of Focus")

##Function stars via death_timer or enemy
func on_player_death() -> void:
	print_rich("[color=red]LEVEL: Player has died..")
	# Load and instantiate the scene
	var death_screen_scene = preload("res://Scenes + Scripts/General/Death Handler/Death Screen.tscn")
	var death_screen_instance = death_screen_scene.instantiate()

	# Add the instance to the specified location
	var current_ui = $"Current UI"
	if current_ui != null:
		current_ui.add_child(death_screen_instance)

	# Set the name of the instantiated scene
	death_screen_instance.name = "Death Screen"
	Engine.time_scale = 0



func _on_timer_timeout() -> void:
	Global.is_dead = true

func on_player_win(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# Load and instantiate the scene
		var win_screen_scene = preload("res://Scenes + Scripts/Menus/UI/Win_Screen.tscn")
		var win_screen_instance = win_screen_scene.instantiate()
		
		# Add the instance to the specified location
		var current_ui = $"Current UI"
		if current_ui != null:
			if current_ui.has_node("Win Screen"):
				return
			print_rich("[color=green]LEVEL: Player has won! Win Screen Added..")
			
			#Find WinSFX and Play It
			var scene_root = get_owner()
			if scene_root:
				var win_sfx_node = scene_root.get_node_or_null("Universal Scene/LV Audio/SFX/Win SFX")
				if win_sfx_node:
					win_sfx_node.play()
				else:
					print_rich("[color=red]LEVEL: Cannot Find Win SFX")
			
			#Add Child
			current_ui.add_child(win_screen_instance)
			
			# Set the name of the instantiated scene
			win_screen_instance.name = "Win Screen"
			Engine.time_scale = 0

## This function simply tells the player to activate wind blowing RIGHT.
func enable_wind_left_to_right(body: Node2D) -> void:
	if body.is_in_group("Player"):
		activate_wind(1.0)

## This function simply tells the player to activate wind blowing LEFT.
func enable_wind_right_to_left(body: Node2D) -> void:
	if body.is_in_group("Player"):
		activate_wind(-1.0)

## Tells the player to start the wind, passing the force and direction.
func activate_wind(direction: float) -> void:
	# Communicate with the player to start the wind push
	if local_player.has_method("start_wind"):
		local_player.start_wind(wind_force * direction)

## Tells the player to stop the wind.
func deactivate_wind(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# Communicate with the player to stop the wind push
	if local_player.has_method("stop_wind"):
		local_player.stop_wind()

#endregion


#region PRIVATE HELPER METHODS
#==============================================================================
# --- PRIVATE HELPER FUNCTIONS ---
#==============================================================================

## Configures the entire level's visual theme and mechanics.
func _setup_environment() -> void:
	var  data = null
	if environment_type != "Custom":
		data = _ENVIRONMENT_DATA.get(environment_type)
	else:
		data = _CUSTOM_ENVIRONMENT_DATA.get(environment_type)
	
	if not data:
		push_error("UniversalLevel: Invalid environment type selected: " + environment_type)
		return

	# Determine correct resources based on whether we're in a cave or not
	var bg_color = data.cave_color if is_cave else data.normal_color
	var env_path = data.cave_env if is_cave else data.normal_env
	var light_path = data.get("directional_light", "")
	
	# If it's a cave, check for a specific 'darkened' light, otherwise fallback to the normal one
	if is_cave:
		var darkened_light_path = data.get("darkened_world_dir_light", "")
		if not darkened_light_path.is_empty():
			light_path = darkened_light_path

	_update_directional_light(light_path)

	
	var target_wind_color = data.wind_color
	var gpu_particle_col = data.gpu_particle_color
	
	var gpu_material = null
	if gpu_particle_col != "":
		gpu_material = load(gpu_particle_col)

	var env_resource
	if env_path != "":
		env_resource = load(env_path)
	
	if env_resource and world_environment:
		if Global.Environment_On:
			world_environment.environment = env_resource
		else:
			world_environment.environment = null
	else:
		push_warning("UniversalLevel: Failed to load environment resource at path: " + env_path)

	var tween = create_tween()
	tween.set_parallel(true)
	
	if bg_normal_color_rect and bg_cave_color_rect:
		tween.tween_property(bg_normal_color_rect, "color", bg_color, 1.0)
		tween.tween_property(bg_cave_color_rect, "color", bg_color, 1.0)
	
	if $"UNIVERSAL LV Nodes/Ash Follow Cam":
		if not Global.Particles_On:
			$"UNIVERSAL LV Nodes/Ash Follow Cam".hide()
		else:
			$"UNIVERSAL LV Nodes/Ash Follow Cam".show()
	
	# Set wind particle color for both directions
	if wind_particles_color_L:
		wind_particles_color_L.color = target_wind_color
	if wind_particles_color_R:
		wind_particles_color_R.color = target_wind_color
	
	gpu_particles_2d.process_material = gpu_material
	
	# Player light is on if forced OR if it's a cave
	if force_player_light_on or is_cave:
		player_light.show()
	else:
		player_light.hide()

## Clears old directional lights and instances the new one.
func _update_directional_light(light_scene_path: String) -> void:
	if not directional_light_container:
		push_warning("Directional light container node not found.")
		return

	# Clear any previously added directional light to prevent duplicates
	for child in directional_light_container.get_children():
		child.queue_free()

	# If no path is provided, warn the user and do nothing
	if light_scene_path.is_empty():
		print_rich("[color=yellow]Warning: No directional light scene specified for this environment.[/color]")
		return

	# Load the new light scene
	var light_scene = load(light_scene_path)
	if not light_scene is PackedScene:
		print_rich("[color=yellow]Warning: Failed to load directional light scene at path: %s[/color]" % light_scene_path)
		return
	
	# Instance and add the new light to the scene
	var light_instance = light_scene.instantiate()
	directional_light_container.add_child(light_instance)

func _zoom_player_camera(zoom_size: float):
	if not local_player:
		print("Player Not Found")
		return
	
	if not player_cam:
		print("Plr Camera Not Found")
		return
	
	#print(zoom_size," pcz.x ", player_cam.zoom.x," pcz.y ", player_cam.zoom.y)
	if zoom_size == player_cam.zoom.x and zoom_size == player_cam.zoom.y:
		print_rich("[color=yellow]Camera tried to change to same zoom size to same size: ", zoom_size)
		return
	
	local_player.change_camera_zoom(zoom_size)

func _set_player_camera_limit(camera_limits: Vector4):
	if not local_player:
		print("Player Not Found")
		return
	
	if not player_cam:
		print("Plr Camera Not Found")
		return
	
	local_player.set_camera_limit(camera_limits)

func get_current_level_number() -> int:
	return _current_level_number
#endregion


#region SIGNAL CONNECTION METHODS
#==============================================================================
# --- FUNCTIONS FOR SIGNAL CONNECTIONS ---
#==============================================================================

func connect_cave_enter_zone(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	change_environment(true)

func connect_cave_exit_zone(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	change_environment(false)

func change_environment(is_cave_variant: bool) -> void:
	self.is_cave = is_cave_variant
	_setup_environment()

func change_lv_type(new_type: String):
	self.environment_type = new_type
	_setup_environment()

func set_desert_environment(body: Node2D) -> void:
	if body.is_in_group("Player"):
		change_lv_type("Desert")

func set_ice_environment(body: Node2D) -> void:
	if body.is_in_group("Player"):
		change_lv_type("Ice")

func set_grasslands_environment(body: Node2D) -> void:
	if body.is_in_group("Player"):
		change_lv_type("Grasslands")

func set_lava_environment(body: Node2D) -> void:
	if body.is_in_group("Player"):
		change_lv_type("Lava")

func set_lava_darkened_environment(body: Node2D) -> void:
	if body.is_in_group("Player"):
		change_lv_type("Lava DARKENED")

func set_custom_environment(body: Node2D) -> void:
	if body.is_in_group("Player"):
		change_lv_type("Custom")

#endregion
