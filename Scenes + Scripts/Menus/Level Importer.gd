extends Node

# --- Configuration ---
@export_group("Tilemap Setup")
@export var main_tilemap_layer: TileMapLayer
@export var bg_tilemap_layer: TileMapLayer
@export var shared_tileset: TileSet

@export_group("UI References")
@export var level_importer: Control
@export var level_slot_list: VBoxContainer # %LevelSlotList

@export_group("Game UI References")
@export var game_node: Node2D
@export var particle_canvas: CanvasLayer
@export var main_parallax: ParallaxBackground
@export var cave_parallax: ParallaxBackground
@export var ui: CanvasLayer



@onready var bg_normal_color_rect: CanvasModulate = $"Game/UNIVERSAL LV Nodes/BG/Background/Parallax Layer/Colored BG"
@onready var bg_cave_color_rect: CanvasModulate = $"Game/UNIVERSAL LV Nodes/BG/Background Cave/Colored BG"
@onready var world_environment: WorldEnvironment = $MenuEnvironment
@onready var gpu_particles_2d: GPUParticles2D = $"Game/UNIVERSAL LV Nodes/Ash Follow Cam/GPUParticles2D"
@onready var directional_light_container: Node = $"Game/Directional Light"
# Get references to all wind particles to set their color
@onready var wind_particles_color_L: CPUParticles2D = $"Game/UNIVERSAL LV Nodes/Ash Follow Cam/WIND/CPU Particles ColouredL"
@onready var wind_particles_color_R: CPUParticles2D = $"Game/UNIVERSAL LV Nodes/Ash Follow Cam/WIND/CPU Particles ColouredR"

#-- Not Extracted But Needed --
var is_cave: bool = false
var spawned_player

# --- Extracted Data Variables ---
var level_name: String = ""
var godot_version: String = ""
var player_spawn: Vector2 = Vector2.ZERO
var carrot_locations: Array = []
var winzone_location: Array = []
var deathzone_locations: Array = []
var custom_environment: int
var custom_environment_call_change_zone: Array = []

const RECENT_PROJECTS_PATH = "user://recent_projects.json"
var recent_projects: Array = []

func _ready() -> void:
	if game_node: game_node.hide()
	if particle_canvas: particle_canvas.hide()
	if main_parallax: main_parallax.hide()
	if cave_parallax: cave_parallax.hide()
	
	if main_tilemap_layer: main_tilemap_layer.tile_set = shared_tileset
	if bg_tilemap_layer: bg_tilemap_layer.tile_set = shared_tileset
	
	load_recent_projects_list()
	refresh_level_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause"):
		get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")
		

func Go_Back_Called():
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")

# --- 1. THE IMPORT PROCESS ---

func Import_Called():
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.wowlv", "WoW Level Files")
	file_dialog.file_selected.connect(_on_level_file_selected)
	file_dialog.use_native_dialog = true
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.4)

func _on_level_file_selected(path: String):
	# We quickly peak into the file to get metadata for the UI labels
	var metadata = _peak_metadata(path)
	
	# Add/Update list
	var exists_index = -1
	for i in range(recent_projects.size()):
		if recent_projects[i].path == path:
			exists_index = i
			break
			
	var entry = {
		"name": metadata.get("name", path.get_file().get_basename()),
		"path": path,
		"godot_ver": metadata.get("godot_ver", "Unknown"),
		"imported_at": Time.get_date_string_from_system()
	}

	if exists_index != -1:
		recent_projects[exists_index] = entry
	else:
		recent_projects.append(entry)
		
	save_recent_projects_list()
	refresh_level_ui()

func _peak_metadata(path: String) -> Dictionary:
	var file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			var g_info = data.get("godot_version", {})
			return {
				"name": data.get("project_name", "Unknown"),
				"godot_ver": g_info.get("string", "Unknown")
			}
	return {}

# --- 2. DATA MANAGEMENT (JSON) ---

func save_recent_projects_list():
	var file = FileAccess.open(RECENT_PROJECTS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(recent_projects, "\t"))

func load_recent_projects_list():
	if FileAccess.file_exists(RECENT_PROJECTS_PATH):
		var file = FileAccess.open(RECENT_PROJECTS_PATH, FileAccess.READ)
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data is Array: recent_projects = json_data

# --- 3. UI GENERATION (Mimicking Editor) ---

func refresh_level_ui():
	for child in level_slot_list.get_children():
		child.queue_free()
		
	for level_data in recent_projects:
		var slot_container = VBoxContainer.new()
		
		# Main Button
		var btn = Button.new()
		btn.text = level_data.name
		btn.custom_minimum_size.y = 40
		btn.pressed.connect(load_level_data.bind(level_data.path))
		
		# Labels Row
		var info_hbox = HBoxContainer.new()
		
		var date_label = Label.new()
		date_label.text = "Date: " + str(level_data.get("imported_at", "??"))
		date_label.modulate = Color(0.8, 0.8, 0.8)
		date_label.add_theme_font_size_override("font_size", 14)
		
		var ver_label = Label.new()
		ver_label.text = "Godot: " + str(level_data.get("godot_ver", "Unknown"))
		ver_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ver_label.modulate = Color(0.8, 0.8, 0.8)
		ver_label.add_theme_font_size_override("font_size", 14)
		
		info_hbox.add_child(date_label)
		info_hbox.add_child(ver_label)
		
		slot_container.add_child(btn)
		slot_container.add_child(info_hbox)
		# Add spacing between slots
		slot_container.add_child(HSeparator.new())
		
		level_slot_list.add_child(slot_container)

# --- 4. THE LOADING LOGIC ---

func load_level_data(file_path: String):
	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open_compressed(file_path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if not file: return
	
	if game_node: game_node.show()
	
	var data = file.get_var() 
	file.close()
	
	if data is Dictionary:
		# Extract to variables for your game's use
		level_name = data.get("project_name", "Unnamed")
		var g_info = data.get("godot_version", {})
		godot_version = g_info.get("string", "Unknown")
		
		player_spawn = data.get("player_spawn", Vector2.ZERO)
		
		# Casting to arrays safely (using .assign if you have the resource scripts)
		# For now, storing as raw data arrays
		carrot_locations = data.get("carrot_locations", [])
		winzone_location = data.get("winzone_location", [])
		deathzone_locations = data.get("deathzone_locations", [])
		custom_environment = data.get("custom_environment", 0)
		custom_environment_call_change_zone = data.get("custom_environment_call_change_zone", [])
		
		# Apply Tilemaps
		if main_tilemap_layer: main_tilemap_layer.clear()
		if bg_tilemap_layer: bg_tilemap_layer.clear()

		if data.has("tilemap_array_main_packed"):
			_unpack_and_apply(main_tilemap_layer, data["tilemap_array_main_packed"])
			
		if data.has("tilemap_array_bg_packed"):
			_unpack_and_apply(bg_tilemap_layer, data["tilemap_array_bg_packed"])
		
		Get_Environment()
		await get_tree().process_frame
		Place_Player()
		
		if level_importer: level_importer.hide()
		if particle_canvas: particle_canvas.show()
		if main_parallax: main_parallax.show()
		if cave_parallax: cave_parallax.show()
		if ui: ui.show()
		print("Loaded Level: ", level_name, " (Spawn: ", player_spawn, ")")

func _unpack_and_apply(layer: TileMapLayer, packed: PackedInt32Array):
	if not layer: return
	var i = 0
	while i < packed.size():
		var coords = Vector2i(packed[i], packed[i+1])
		var source_id = packed[i+2]
		var atlas_coords = Vector2i(packed[i+3], packed[i+4])
		var alt_tile = packed[i+5]
		layer.set_cell(coords, source_id, atlas_coords, alt_tile)
		i += 6

func Place_Player(spawn_coords: Vector2 = player_spawn):
	var player_scene = load("res://Scenes + Scripts/General/Player/Player_Scene.tscn")
	var player_instance = player_scene.instantiate()
	player_instance.global_position = spawn_coords
	spawned_player = player_instance
	if game_node: game_node.add_child(player_instance)
	else: print_rich("[color=red]GameNode Not Found.."); add_child(player_instance)
	
	var camera: Camera2D = player_instance.get_node("Camera2D")
	camera.limit_enabled = false


func Get_Environment():
	# Define the paths based on the order in your image
	var env_map = {
		1: "res://Resources/Environmental/Lava.tres",
		2: "res://Resources/Environmental/Lava DARKENED.tres",
		3: "res://Resources/Environmental/Desert.tres",
		4: "res://Resources/Environmental/Ice.tres",
		5: "res://Resources/Environmental/Grasslands.tres"
	}

	# Check if the selection is valid (1-5)
	if env_map.has(custom_environment):
		print("Chosen Environment No: ", custom_environment)
		
		# Load the resource from the path
		var env_data = load(env_map[custom_environment])
		
		# Apply it with instant set to true
		if env_data is LevelEnvironmentData:
			_apply_environment(env_data, true)
		else:
			push_error("Loaded resource is not LevelEnvironmentData!")
			
	else:
		# Fallback to Lava (Index 5) if invalid
		print("Environment is Invalid. Selecting Lava.")
		var fallback_lava = load(env_map[5])
		_apply_environment(fallback_lava, true)

func _apply_environment(data: LevelEnvironmentData, instant: bool = false) -> void:
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
	if instant:
		#print_rich("[color=yellow]ENV: Applying Colors INSTANTLY[/color]")
		if bg_normal_color_rect: bg_normal_color_rect.color = bg_color
		if bg_cave_color_rect: bg_cave_color_rect.color = bg_color
	else:
		#print_rich("[color=yellow]ENV: Applying Colors via TWEEN[/color]")
		var tween = create_tween()
		tween.set_parallel(true)
		if bg_normal_color_rect:
			tween.tween_property(bg_normal_color_rect, "color", bg_color, 1.0)
		if bg_cave_color_rect:
			tween.tween_property(bg_cave_color_rect, "color", bg_color, 1.0)
	
	# Update Particles
	if $"Game/UNIVERSAL LV Nodes/Ash Follow Cam":
		if not Global.Particles_On:
			$"Game/UNIVERSAL LV Nodes/Ash Follow Cam".hide()
			if gpu_particles_2d: gpu_particles_2d.emitting = false
		else:
			$"Game/UNIVERSAL LV Nodes/Ash Follow Cam".show()
			if gpu_particles_2d:
				gpu_particles_2d.emitting = true
				if data.gpu_particles_material:
					gpu_particles_2d.process_material = data.gpu_particles_material
	
	# Update Wind Particle Color
	if wind_particles_color_L: wind_particles_color_L.color = data.wind_color
	if wind_particles_color_R: wind_particles_color_R.color = data.wind_color
	
	await get_tree().create_timer(0.5).timeout
	var player_light = spawned_player.get_node("Player Light")
	# Update Player Light Visibility
	if player_light:
		if is_cave: #force_player_light_on or is_cave:
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
