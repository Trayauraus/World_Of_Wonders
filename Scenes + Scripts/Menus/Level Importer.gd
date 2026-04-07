## Level Importer.gd (Standalone Version for Game side)
extends Node

# --- Configuration ---
@export_group("Tilemap Setup")
@export var main_tilemap_layer: TileMapLayer
@export var bg_tilemap_layer: TileMapLayer
@export var shared_tileset: TileSet

@export_group("Entity Scenes")
@export var carrot_scene: PackedScene
@export var coin_scene: PackedScene
@export var enemy_scene: PackedScene

@export_group("UI References")
@export var level_importer: Control
@export var level_slot_list: VBoxContainer # %LevelSlotList
@export var audio_stream_player: AudioStreamPlayer

@export var coin_holder: Node2D
@export var carrot_holder: Node2D
@export var enemy_holder: Node2D

@export_group("Game UI References")
@export var game_node: Node2D
@export var particle_canvas: CanvasLayer
@export var main_parallax: ParallaxBackground
@export var cave_parallax: ParallaxBackground
@export var ui: CanvasLayer
##Also known as universal level
@export var game_handler: Node2D

@export_group("Collision Zones (Area2Ds)")
@export var collisions_parent: Node
@export var lava_env: Area2D
@export var lava_dark_env: Area2D
@export var desert_env: Area2D
@export var ice_env: Area2D
@export var grass_env: Area2D
@export var cave_zone: Area2D
@export var wind_left: Area2D
@export var wind_right: Area2D
@export var deactivate_wind: Area2D
@export var win_area: Area2D
@export var death_zone: Area2D
@export var carrot_remover: Area2D # NEW: Carrot Remover Reference

@export_group("Node References")
@export var wind_particles_left_color: CPUParticles2D
@export var wind_particles_left_gray: CPUParticles2D
@export var wind_particles_right_color: CPUParticles2D
@export var wind_particles_right_gray: CPUParticles2D

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

# Standard Variables
var camera_zoom: float = 2.4
var player_dashes: int = 2
var is_cave_default: bool = false
var ice_physics: bool = false
var force_light: bool = false

# Array Data
var carrot_locations: Array = []
var coin_locations: Array = []
var enemy_locations: Array = []
var winzone_location: Array = []
var deathzone_locations: Array = []
var carrot_remover_locations: Array = [] # NEW: Carrot Remover Locations
var cave_locations: Array = []
var wind_locations: Array = []
var camerazoom_locations: Array = []
var custom_environment: int
var custom_environment_call_change_zone: Array = []

const RECENT_PROJECTS_PATH = "user://recent_projects.json"
var recent_projects: Array = []

var selected_environment

func _ready() -> void:
	Global.current_lv = -1
	Global.current_lv_from_sav_file = 0
	Global.current_sav_file = ""
	if $"Level Importer/WarningLabel": $"Level Importer/WarningLabel".hide()
	if game_node: game_node.hide()
	if particle_canvas: particle_canvas.hide()
	if main_parallax: main_parallax.hide()
	if cave_parallax: cave_parallax.hide()
	
	if main_tilemap_layer: main_tilemap_layer.tile_set = shared_tileset
	if bg_tilemap_layer: bg_tilemap_layer.tile_set = shared_tileset
	
	# Attempt to automatically fetch collision nodes if they aren't assigned in the inspector
	if not collisions_parent: collisions_parent = get_node_or_null("Game/Collisions or AREA 2Ds")
	if collisions_parent:
		if not lava_env: lava_env = collisions_parent.get_node_or_null("Lava Env")
		if not lava_dark_env: lava_dark_env = collisions_parent.get_node_or_null("Lava DARKENED")
		if not desert_env: desert_env = collisions_parent.get_node_or_null("Desert Env")
		if not ice_env: ice_env = collisions_parent.get_node_or_null("Ice Env")
		if not grass_env: grass_env = collisions_parent.get_node_or_null("Grass Env")
		if not cave_zone: cave_zone = collisions_parent.get_node_or_null("CaveZone")
		if not wind_left: wind_left = collisions_parent.get_node_or_null("Wind Left")
		if not wind_right: wind_right = collisions_parent.get_node_or_null("Wind Right")
		if not deactivate_wind: deactivate_wind = collisions_parent.get_node_or_null("Deactivate Wind")
		if not win_area: win_area = collisions_parent.get_node_or_null("WinArea")
		if not death_zone: death_zone = collisions_parent.get_node_or_null("Death Zone")
		if not carrot_remover: carrot_remover = collisions_parent.get_node_or_null("Carrot Remover") # NEW
	
	load_recent_projects_list()
	refresh_level_ui()
	
	await get_tree().process_frame
	await get_tree().process_frame
	Refresh_Called()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause"):
		get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")

func Go_Back_Called():
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")

func Refresh_Called():
	var warning_label = $"Level Importer/WarningLabel"
	var valid_projects = []
	var removed_count = 0
	
	for project in recent_projects:
		# 1. Check if file exists
		if not FileAccess.file_exists(project.path):
			removed_count += 1
			continue
			
		# 2. Check for compatibility (Peek into the file)
		var file = FileAccess.open_compressed(project.path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary:
				if typeof(data.get("custom_environment")) == TYPE_INT:
					valid_projects.append(project)
					continue
		
		# If it fails existence or type check, we reach here
		removed_count += 1

	recent_projects = valid_projects
	save_recent_projects_list()
	refresh_level_ui()

	if removed_count > 0:
		warning_label.text = "Refresh Complete: Removed " + str(removed_count) + " missing or incompatible levels."
		warning_label.modulate = Color.YELLOW
	else:
		warning_label.text = "All levels are compatible and reachable!"
		warning_label.modulate = Color.GREEN
	
	_show_warning_label(warning_label)

func _show_warning_label(label: Label):
	label.show()
	label.modulate.a = 1.0 
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(3.0)
	tween.finished.connect(label.hide)

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
	var metadata = _peak_metadata(path)
	
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
		
		var btn = Button.new()
		btn.text = level_data.name
		btn.custom_minimum_size.y = 40
		btn.pressed.connect(load_level_data.bind(level_data.path))
		
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
		
		# --- Load the Extracted Variables ---
		camera_zoom = data.get("camera_zoom", 2.4)
		player_dashes = data.get("player_dashes", 2)
		is_cave_default = data.get("is_cave_default", false)
		ice_physics = data.get("ice_physics", false)
		force_light = data.get("force_light", false)
		
		# --- Load Arrays (Now safe plain dictionaries) ---
		carrot_locations = data.get("carrot_locations", [])
		coin_locations = data.get("coin_locations", [])
		enemy_locations = data.get("enemy_locations", [])
		winzone_location = data.get("winzone_location", [])
		deathzone_locations = data.get("deathzone_locations", [])
		carrot_remover_locations = data.get("carrot_remover_locations", []) # NEW
		cave_locations = data.get("cave_locations", [])
		wind_locations = data.get("wind_locations", [])
		camerazoom_locations = data.get("camerazoom_locations", [])
		
		# --- PRINT ALL EXTRACTED DATA ---
		print_rich("\n[color=cyan]--- LEVEL DATA SUCCESSFULLY EXTRACTED ---[/color]")
		print("Name: ", level_name)
		print("Spawn Location: ", player_spawn)
		print("Camera Zoom: ", camera_zoom)
		print("Player Dashes: ", player_dashes)
		print("Ice Physics: ", ice_physics)
		print("Force Light: ", force_light)
		print("Carrots Found: ", carrot_locations.size())
		print("Coins Found: ", coin_locations.size())
		print("Enemies Found: ", enemy_locations.size())
		print_rich("[color=cyan]-----------------------------------------[/color]\n")
		
		var env_value = data.get("custom_environment")
		if typeof(env_value) != TYPE_INT:
			var warning_label = $"Level Importer/WarningLabel"
			warning_label.text = "Error: This level uses an outdated format and loaded the default environment."
			warning_label.modulate = Color.RED
			_show_warning_label(warning_label)
			env_value = 0

		custom_environment = env_value
		custom_environment_call_change_zone = data.get("custom_environment_call_change_zone", [])
		
		# Apply Tilemaps
		if main_tilemap_layer: main_tilemap_layer.clear()
		if bg_tilemap_layer: bg_tilemap_layer.clear()

		if data.has("tilemap_array_main_packed"):
			var raw_main = data.get("tilemap_array_main_packed")
			if typeof(raw_main) == TYPE_PACKED_BYTE_ARRAY:
				if not raw_main.is_empty() and main_tilemap_layer:
					main_tilemap_layer.set_tile_map_data_from_array(raw_main)
			else:
				_handle_incompatible_level("Tilemap format is outdated (PackedInt32Array).")
				return 

		if data.has("tilemap_array_bg_packed"):
			var raw_bg = data.get("tilemap_array_bg_packed")
			if typeof(raw_bg) == TYPE_PACKED_BYTE_ARRAY:
				if not raw_bg.is_empty() and bg_tilemap_layer:
					bg_tilemap_layer.set_tile_map_data_from_array(raw_bg)
		
		Get_Environment(is_cave_default)
		await get_tree().process_frame
		
		# --- Placement Sub-routines ---
		Place_Player()
		Spawn_Entities()
		Populate_Zones() # Populates the Area2Ds with their shapes
		
		# --- Play Custom Music (packed by GlobalProject export) ---
		_play_level_music(data)
		
		if level_importer: level_importer.hide()
		if particle_canvas: particle_canvas.show()
		if main_parallax: main_parallax.show()
		if cave_parallax: cave_parallax.show()
		if ui: ui.show()
		
		if OS.has_feature("android") or OS.has_feature("ios"):
			if game_handler:
				game_handler.show_mobile_ui()
		print("Loaded Level: ", level_name, " (Spawn: ", player_spawn, ")")

func _play_level_music(data: Dictionary) -> void:
	if not is_instance_valid(audio_stream_player):
		print_rich("[color=yellow]Skipping music: 'audio_stream_player' is not a valid node.[/color]")
		return
	
	var music_data: PackedByteArray = data.get("custom_music_data", PackedByteArray())
	var music_ext: String = data.get("custom_music_extension", "").to_lower()
	var music_name: String = data.get("custom_music_name", "")
	
	if music_data.is_empty():
		audio_stream_player.stop()
		print_rich("[color=yellow]No custom music packed in this level.[/color]")
		return
	
	var stream: AudioStream = null
	
	if music_ext == "ogg":
		stream = AudioStreamOggVorbis.load_from_buffer(music_data)
		if stream:
			stream.loop = true
	elif music_ext == "mp3":
		stream = AudioStreamMP3.new()
		stream.data = music_data
		stream.loop = true
	else:
		print_rich("[color=orange]Custom music skipped: unsupported extension '[/color]", music_ext, "[color=orange]'.[/color]")
		return
	
	if stream:
		audio_stream_player.stream = stream
		audio_stream_player.play()
		print_rich("[color=lime]Now playing custom music: [/color]", music_name)
	else:
		print_rich("[color=red]Failed to decode custom music: '[/color]", music_name, "[color=red]'.[/color]")

func _handle_incompatible_level(reason: String):
	var warning_label = $"Level Importer/WarningLabel"
	warning_label.text = "Error: " + reason
	warning_label.modulate = Color.RED
	_show_warning_label(warning_label)
	if game_node: game_node.hide() 

func Place_Player(spawn_coords: Vector2 = player_spawn):
	var player_scene = load("res://Scenes + Scripts/General/Player/Player_Scene.tscn")
	var player_instance = player_scene.instantiate()
	player_instance.name = "Bunny"
	player_instance.add_to_group("Player")
	
	##Player Node References
	if wind_particles_left_color: player_instance.wind_particles_left_color = wind_particles_left_color
	if wind_particles_left_gray: player_instance.wind_particles_left_gray = wind_particles_left_gray
	
	if wind_particles_right_color: player_instance.wind_particles_right_color = wind_particles_right_color
	if wind_particles_right_gray: player_instance.wind_particles_right_gray = wind_particles_right_gray
	
	if player_dashes:
		player_instance._dashes_available = player_dashes
		player_instance.max_dash_count = player_dashes
	if force_light:
		var player_light = player_instance.get_node("Player Light")
		if player_light != null:
			player_light.enabled = true
			player_light.visible = true
	if camera_zoom:
		var _camera = player_instance.get_node("Camera2D")
		if _camera != null:
			_camera.zoom = Vector2(camera_zoom,camera_zoom)
	if ice_physics:
		pass #not coded yet
	player_instance.global_position = spawn_coords
	spawned_player = player_instance
	if game_handler: game_handler.player = player_instance
	
	if game_node: print_rich("[color=green]Player Spawned."); game_node.add_child(player_instance)
	else: print_rich("[color=red]GameNode Not Found.."); add_child(player_instance)
	
	var camera: Camera2D = player_instance.get_node("Camera2D")
	camera.limit_enabled = false

func Spawn_Entities():
	if not game_node: return
	
	# Spawn Carrots
	await get_tree().process_frame
	if carrot_scene:
		for c_data in carrot_locations:
			var carrot = carrot_scene.instantiate()
			carrot.name = "Carrot"
			carrot.add_to_group("Carrot")
			carrot.global_position = c_data.get("location", Vector2.ZERO)
			
			# Using .set() ensures the game doesn't crash if the variable isn't in the script yet
			if "dash_count" in c_data: carrot.set("forced_max_dashes", c_data["dash_count"])
			
			if carrot_holder: carrot_holder.add_child(carrot)
			else: game_node.add_child(carrot)
			
			# NEW: Connect the body_entered signal from the Carrot Remover Area2D to this specific carrot instance
			if carrot_remover and carrot.has_method("_on_carrot_remover_body_entered"):
				carrot_remover.body_entered.connect(carrot._on_carrot_remover_body_entered)
	else:
		print_rich("[color=yellow]Warning: Carrot Scene not assigned in Level Importer[/color]")

	# Spawn Coins
	if coin_scene:
		for c_data in coin_locations:
			var coin = coin_scene.instantiate()
			coin.name = "Coin"
			coin.global_position = c_data.get("location", Vector2.ZERO)
			
			if "emits_light" in c_data: coin.set("emits_light", bool(c_data["emits_light"]))
			if "coin_variant" in c_data: coin.set("coin_variant", c_data["coin_variant"])
			if "coin_size" in c_data: coin.set("coin_size", c_data["coin_size"])
			
			if coin_holder: coin_holder.add_child(coin)
			else: game_node.add_child(coin)
	else:
		print_rich("[color=yellow]Warning: Coin Scene not assigned in Level Importer[/color]")

	# Spawn Enemies
	if enemy_scene:
		for e_data in enemy_locations:
			var enemy = enemy_scene.instantiate()
			enemy.name = "Enemy - ICE Tank"
			enemy.global_position = e_data.get("location", Vector2.ZERO)
			
			if "tank_variant" in e_data: enemy.set("tank_variant", e_data["tank_variant"])
			if "speed" in e_data: enemy.set("speed", float(e_data["speed"]))
			if "emits_light" in e_data: enemy.set("emits_light", bool(e_data["emits_light"]))
			
			if enemy_holder: enemy_holder.add_child(enemy)
			else: game_node.add_child(enemy)
	else:
		print_rich("[color=yellow]Warning: Enemy Scene not assigned in Level Importer[/color]")

# --- 5. ZONE & COLLISION POPULATION ---

func Populate_Zones():
	_clear_generated_zones() # Clear any loaded collision shapes if restarting/changing levels

	_add_shapes_to_area(win_area, winzone_location)
	_add_shapes_to_area(death_zone, deathzone_locations)
	_add_shapes_to_area(cave_zone, cave_locations)
	_add_shapes_to_area(carrot_remover, carrot_remover_locations) # NEW: Generate the shapes for Carrot Remover

	# Process Winds
	for w_data in wind_locations:
		# Assuming standard dictionary keys, feel free to update the string check if it differs
		var w_dir = 0
		if "wind_type" in w_data: w_dir = w_data["wind_type"]
		elif "wind_direction" in w_data: w_dir = w_data["wind_direction"]
		print(w_dir)
		
		if w_dir == "Wind - Activate Left":
			_add_single_shape(wind_left, w_data)
		elif w_dir == "Wind - Activate Right":
			_add_single_shape(wind_right, w_data)
		else:
			_add_single_shape(deactivate_wind, w_data)

	# Process Environments
	for env_data in custom_environment_call_change_zone:
		var e_id = 1 # Default to Lava
		
		# New Logic: Parse the String "Environment - X"
		if "environment_type" in env_data:
			var type_str = env_data["environment_type"]
			if "Lava" in type_str:
				e_id = 1
			elif "Lava DARKENED" in type_str:
				e_id = 2
			elif "Desert" in type_str:
				e_id = 3
			elif "Ice" in type_str:
				e_id = 4
			elif "Grasslands" in type_str:
				e_id = 5
				
		# Keep your original fallback checks just in case
		elif "environment_id" in env_data: 
			e_id = env_data["environment_id"]
		elif "env_id" in env_data: 
			e_id = env_data["env_id"]
		
		print("Detected Zone ID: ", e_id, " from ", env_data["environment_type"])
		
		match e_id:
			1: _add_single_shape(lava_env, env_data)
			2: _add_single_shape(lava_dark_env, env_data)
			3: _add_single_shape(desert_env, env_data)
			4: _add_single_shape(ice_env, env_data)
			5: _add_single_shape(grass_env, env_data)

	# Process Camera Zooms (Unique Implementation)
	for z_data in camerazoom_locations:
		_create_camera_zoom_zone(z_data)

func _clear_generated_zones():
	# NEW: Added carrot_remover to clear array
	var existing_areas = [win_area, death_zone, cave_zone, wind_left, wind_right, deactivate_wind, lava_env, lava_dark_env, desert_env, ice_env, grass_env, carrot_remover]
	for area in existing_areas:
		if is_instance_valid(area):
			for child in area.get_children():
				if child is CollisionShape2D:
					child.queue_free()
	
	# Clear specifically generated Camera Zoom Area2Ds
	var search_parent = collisions_parent if is_instance_valid(collisions_parent) else game_node
	if is_instance_valid(search_parent):
		for child in search_parent.get_children():
			if child.name.begins_with("CameraZoomZone_Dynamic"):
				child.queue_free()

func _add_shapes_to_area(area: Area2D, data_array: Array):
	if not is_instance_valid(area): return
	for data in data_array:
		_add_single_shape(area, data)

func _add_single_shape(area: Area2D, data: Dictionary):
	if not is_instance_valid(area): return
	
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	
	# Fallback support for both Extents (Godot 3 legacy logic) and Size (Godot 4 Default)
	# FIX: Added check for "shape_size" which the Editor uses to save zone dimensions
	var shape_size = Vector2(64, 64)
	if "shape_size" in data: shape_size = data["shape_size"]
	elif "size" in data: shape_size = data["size"]
	elif "extents" in data: shape_size = data["extents"] * 2.0
	
	rect.size = shape_size
	cs.shape = rect
	cs.global_position = data.get("location", Vector2.ZERO)
	
	area.add_child(cs)

func _create_camera_zoom_zone(data: Dictionary):
	var area = Area2D.new()
	area.name = "CameraZoomZone_Dynamic"
	area.collision_layer = 0
	area.collision_mask = 1 | 2 # Typical layers checking for Player body
	
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	
	# FIX: Added check for "shape_size"
	var shape_size = Vector2(128, 128)
	if "shape_size" in data: shape_size = data["shape_size"]
	elif "size" in data: shape_size = data["size"]
	elif "extents" in data: shape_size = data["extents"] * 2.0
	
	rect.size = shape_size
	cs.shape = rect
	
	# Keep Area and Shape centered identically
	area.global_position = data.get("location", Vector2.ZERO)
	area.add_child(cs)
	
	var target_zoom = data.get("zoom_amount", 2.4)
	if "zoom_amount" in data: target_zoom = data["zoom_amount"]
	else: print("Could Not find camera zoom amount")
	
	area.body_entered.connect(_on_camera_zoom_body_entered.bind(target_zoom))
	
	if is_instance_valid(collisions_parent):
		collisions_parent.add_child(area)
	elif is_instance_valid(game_node):
		game_node.add_child(area)
	else:
		add_child(area)

func _on_camera_zoom_body_entered(body: Node2D, target_zoom: float):
	if body.is_in_group("Player"):
		print("Zoomed to ", target_zoom)
		var camera: Camera2D = body.get_node_or_null("Camera2D")
		if camera:
			var tween = create_tween()
			tween.tween_property(camera, "zoom", Vector2(target_zoom, target_zoom), 1.0).set_trans(Tween.TRANS_SINE)


# --- 6. ENVIRONMENT GENERATION ---

func Get_Environment(cave = false):
	var env_map = {
		1: "res://Resources/Environmental/Lava.tres",
		2: "res://Resources/Environmental/Lava DARKENED.tres",
		3: "res://Resources/Environmental/Desert.tres",
		4: "res://Resources/Environmental/Ice.tres",
		5: "res://Resources/Environmental/Grasslands.tres"
	}

	if env_map.has(custom_environment):
		print("Chosen Environment No: ", custom_environment)
		var env_data = load(env_map[custom_environment])
		if env_data is LevelEnvironmentData:
			_apply_environment(env_data, true)
		else:
			push_error("Loaded resource is not LevelEnvironmentData!")
	else:
		print("Environment is Invalid. Selecting Lava.")
		var fallback_lava = load(env_map[1])
		_apply_environment(fallback_lava, true, cave)

func _update_environment_visuals(cave_enabled: bool):
	if selected_environment:
		_apply_environment(selected_environment, false, cave_enabled)

func _apply_environment(data: LevelEnvironmentData, instant: bool = false, cave = false) -> void:
	if not data:
		push_error("UniversalLevel: Cannot apply environment, Resource is null.")
		return
	else: if selected_environment != data: selected_environment = data

	is_cave = cave
	var bg_color = data.cave_color if is_cave else data.ambient_color
	var env_resource = data.world_env_cave if is_cave else data.world_env_normal
	var light_packed = data.dir_light_cave if is_cave else data.dir_light_normal
	
	if is_cave and light_packed == null:
		light_packed = data.dir_light_normal

	_update_directional_light(light_packed)

	if env_resource and world_environment:
		if Global.Environment_On:
			world_environment.environment = env_resource
		else:
			world_environment.environment = null

	if instant:
		if bg_normal_color_rect: bg_normal_color_rect.color = bg_color
		if bg_cave_color_rect: bg_cave_color_rect.color = bg_color
	else:
		var tween = create_tween()
		tween.set_parallel(true)
		if bg_normal_color_rect:
			tween.tween_property(bg_normal_color_rect, "color", bg_color, 1.0)
		if bg_cave_color_rect:
			tween.tween_property(bg_cave_color_rect, "color", bg_color, 1.0)
	
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
	
	if wind_particles_color_L: wind_particles_color_L.color = data.wind_color
	if wind_particles_color_R: wind_particles_color_R.color = data.wind_color
	
	await get_tree().process_frame
	if force_light:
		return
	await get_tree().create_timer(0.5).timeout
	if spawned_player:
		var player_light = spawned_player.get_node_or_null("Player Light")
		if player_light:
			if is_cave: 
				player_light.show()
			else:
				player_light.hide()

func _update_directional_light(light_packed: PackedScene) -> void:
	if not directional_light_container: return

	for child in directional_light_container.get_children():
		child.queue_free()

	if light_packed == null:
		print_rich("[color=yellow]Warning: No directional light scene in current Environment Resource.[/color]")
		return

	var light_instance = light_packed.instantiate()
	directional_light_container.add_child(light_instance)
