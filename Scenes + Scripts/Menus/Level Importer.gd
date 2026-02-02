extends Control

#region Node References
@onready var go_back_button: Button = %"Stats Go Back"
@onready var refresh_button: Button = %RefreshButton
@onready var import_button: Button = %ImportButton
@onready var level_slot_list: VBoxContainer = %LevelSlotList
@onready var warning_label: Label = %WarningLabel

# UI Visibility Groups
@onready var background: Sprite2D = %StatsMenuBackground
@onready var main_split_container: HSplitContainer = $HSplitContainer
@onready var bottom_panel_1: Panel = $Panel
@onready var bottom_panel_2: Panel = $Panel2
#endregion

#region Constants & Variables
const UNIVERSAL_LEVEL_TEMPLATE = preload("res://Scenes + Scripts/Levels/UNIVERSAL Level Template.tscn")
const SAVE_FILE_PATH = "user://imported_levels_list.json"

var file_dialog: FileDialog
var imported_level_paths: Array[String] = []
var current_level_instance: Node = null
#endregion

func _ready() -> void:
	_setup_file_dialog()
	_connect_signals()
	_load_imported_levels()
	_refresh_list_validity()
	_update_ui_list() # This is now an async call internally
	
	warning_label.text = ""

func _setup_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM 
	file_dialog.filters = ["*.wowlv ; World o' Wonders Level", "*.tscn ; Godot Scene File"]
	file_dialog.use_native_dialog = true
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_file_selected)

func _connect_signals() -> void:
	go_back_button.pressed.connect(_on_go_back_pressed)
	import_button.pressed.connect(_on_import_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)

#region Level Management Logic
func _on_import_pressed() -> void:
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	var final_path = path
	# Store the original filename (e.g., "cool_level.wowlv") to show the user later
	var display_name = path.get_file() 
	
	# Check if we need to migrate a .wowlv file
	if path.get_extension().to_lower() == "wowlv":
		final_path = _import_external_wowlv(path)
		if final_path == "":
			warning_label.text = "Error: Failed to copy level file."
			return

	if final_path in imported_level_paths:
		warning_label.text = "Level already imported!"
		return
		
	imported_level_paths.append(final_path)
	_save_imported_levels()
	await _update_ui_list()
	
	# Use the original name here instead of final_path.get_file()
	if display_name.contains(".wowlv"):
		warning_label.text = "Imported: " + display_name + "     (Converted to .tscn for Godot)"
	else:
		warning_label.text = "Imported: " + display_name

func _import_external_wowlv(original_path: String) -> String:
	var folder_path = "user://Imported wowlv Levels"
	
	# 1. Create directory if missing
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_recursive_absolute(folder_path)
	
	# 2. Construct new filename (renaming extension to .tscn)
	var file_name = original_path.get_file().get_basename() + ".tscn"
	var destination_path = folder_path.path_join(file_name)
	
	# 3. Perform the copy
	var dir = DirAccess.open("user://")
	var error = dir.copy(original_path, destination_path)
	
	if error == OK:
		print("Successfully migrated: ", destination_path)
		return destination_path
	else:
		printerr("Error copying file: ", error)
		return ""

func _on_refresh_pressed() -> void:
	var removed = _refresh_list_validity()
	_update_ui_list()
	warning_label.text = "Verified. Removed " + str(removed) + " missing files."

func _refresh_list_validity() -> int:
	var valid_paths: Array[String] = []
	var removed_count = 0
	for path in imported_level_paths:
		if FileAccess.file_exists(path):
			valid_paths.append(path)
		else:
			removed_count += 1
	imported_level_paths = valid_paths
	if removed_count > 0:
		_save_imported_levels()
	return removed_count

func _load_imported_levels() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Array:
				imported_level_paths = []
				for item in data:
					imported_level_paths.append(str(item))

func _save_imported_levels() -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(imported_level_paths))
		file.close()
#endregion

#region UI & Preview Generation
# FIX: Added 'await' logic to the loop so it waits for screenshots to finish
func _update_ui_list() -> void:
	for child in level_slot_list.get_children():
		child.queue_free()
	
	for path in imported_level_paths:
		await _create_level_entry(path)

func _create_level_entry(path: String) -> void:
	var h_box = HBoxContainer.new()
	h_box.custom_minimum_size = Vector2(0, 120)
	h_box.add_theme_constant_override("separation", 20)
	
	# Create Preview Thumbnail
	var aspect = AspectRatioContainer.new()
	aspect.custom_minimum_size = Vector2(160, 90)
	aspect.stretch_mode = AspectRatioContainer.STRETCH_WIDTH_CONTROLS_HEIGHT
	
	var tex_rect = TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = await _generate_preview(path)
	
	aspect.add_child(tex_rect)
	h_box.add_child(aspect)
	
	# Create Button
	var btn = Button.new()
	btn.text = " Play: " + path.get_file().replace(".tscn", "").replace(".wowlv", "")
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 32)
	
	# Connect signals for various mouse buttons
	btn.pressed.connect(_on_level_play_requested.bind(path))
	
	btn.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					_open_file_location(path)
				MOUSE_BUTTON_MIDDLE:
					_remove_level_from_list(path)
	)
	
	h_box.add_child(btn)
	level_slot_list.add_child(h_box)

func _open_file_location(path: String) -> void:
	var global_path = ""
	
	if path.begins_with("user://"):
		global_path = ProjectSettings.globalize_path(path.get_base_dir())
	else:
		# For files still sitting in D:/Downloads or elsewhere
		global_path = path.get_base_dir()
	
	if DirAccess.dir_exists_absolute(global_path):
		OS.shell_open(global_path)
		warning_label.text = "Opening folder: " + global_path.get_file()
	else:
		warning_label.text = "Could not find folder location."

func _remove_level_from_list(path: String) -> void:
	if path in imported_level_paths:
		imported_level_paths.erase(path)
		_save_imported_levels()
		_update_ui_list() # Refresh the UI to show it's gone
		warning_label.text = "Removed from list: " + path.get_file()

func _generate_preview(path: String) -> Texture2D:
	var level_res = load(path)
	if not level_res or not level_res is PackedScene: 
		printerr("Invalid level file for preview: ", path)
		return null
	
	var preview_node = level_res.instantiate()
	
	# --- FIX 1: DISABLING FADE, PLAYER & UI ---
	# Hide the Player 
	var p = preview_node.find_child("Player", true, false)
	if p:
		p.visible = false
	
	# Hide the specific UI node from the Universal Template 
	var ui_layer = preview_node.find_child("Current UI", true, false)
	if ui_layer:
		ui_layer.visible = false

	# Hide any other CanvasLayers (Ash particles, Wind, etc.) 
	for child in preview_node.get_children():
		if child is CanvasLayer:
			child.visible = false
			
	# Recursive check to catch UI nested deep in nodes like "UNIVERSAL LV Nodes" 
	var all_canvas_layers = preview_node.find_children("*", "CanvasLayer", true, false)
	for cl in all_canvas_layers:
		cl.visible = false
	
	# --- FIX 2: VIEWPORT ISOLATION ---
	var viewport = SubViewport.new()
	viewport.size = Vector2(1152, 648) 
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.own_world_3d = true 
	
	add_child(viewport)
	viewport.add_child(preview_node)

	await get_tree().process_frame

	# --- FIX 3: ENVIRONMENT COLORS ---
	var env = preview_node.get("default_environment")
	if env == null:
		env = load("res://Resources/Environmental/Lava.tres")
	
	var bg_color = env.ambient_color
	if preview_node.get("is_cave") == true:
		bg_color = env.cave_color

	# Target the CanvasModulate nodes [cite: 6]
	var normal_modulate = preview_node.find_child("Colored BG", true, false)
	if normal_modulate: 
		normal_modulate.color = bg_color
	
	if preview_node.has_method("change_environment_resource"):
		preview_node.change_environment_resource(env, true)

	# --- FIX 4: WAIT FOR GPU ---
	if Global.speed_up:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(0.7).timeout
	
	var img = viewport.get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	
	# Cleanup
	viewport.queue_free()
	preview_node.queue_free()
	return tex
#endregion

#region Mirroring & Play Logic
func _on_level_play_requested(path: String) -> void:
	# Check if file exists on disk
	if not FileAccess.file_exists(path):
		# REMOVAL LOGIC:
		# Remove the specific invalid path from our array
		imported_level_paths.erase(path)
		# Update the JSON file immediately so it doesn't come back on restart
		_save_imported_levels()
		
		warning_label.text = "File missing! Removed from registry. Press Refresh to update list."
		return

	var level_res = load(path)
	
	# Check if the file is actually a valid Godot Scene
	if not level_res or not level_res is PackedScene:
		# Optional: Also remove files that aren't real scenes
		imported_level_paths.erase(path)
		_save_imported_levels()
		warning_label.text = "Invalid Level! File removed. Press Refresh to update list."
		return

	if $MenuEnvironment:
		$MenuEnvironment.queue_free()
	# Proceed with level instantiation
	var fresh_level = UNIVERSAL_LEVEL_TEMPLATE.instantiate()
	var editor_data_node = level_res.instantiate()
	
	current_level_instance = fresh_level
	_clone_level_data(editor_data_node, fresh_level)
	
	editor_data_node.queue_free()
	
	add_child(current_level_instance)
	_set_menu_visible(false)

func _clone_level_data(source: Node, target: Node) -> void:
	# 1. Define Core Tilemap Layers
	var core_layers = ["Ground", "BG Objects"]
	var processed_nodes: Array[Node] = []

	# PHASE A & B: SYNC TILEMAPS (Existing logic, kept for stability)
	for layer_name in core_layers:
		var s_layer = source.find_child(layer_name, true, false)
		var t_layer = target.find_child(layer_name, true, false)
		if s_layer is TileMapLayer and t_layer is TileMapLayer:
			_sync_tile_cells(s_layer, t_layer)
			processed_nodes.append(s_layer)

	for child in source.get_children():
		if child is TileMapLayer and not child in processed_nodes:
			var new_layer = TileMapLayer.new()
			new_layer.name = child.name
			target.add_child(new_layer)
			_sync_tile_cells(child, new_layer)

	# PHASE C: SYNC SPECIFIC COLLISION ZONES (The Fix)
	# We look for these specific functional areas regardless of where they are in the source
	var special_zones: Array[String] = [
		"WinArea", "Death Zone", "Carrot Remover", 
		"Wind Left", "Wind Right", "Deactivate Wind", "CaveZone",
		"Lava Env", "Lava DARKENED", "Desert Env", "Ice Env", "Grass Env"
	]
	for zone_name in special_zones:
		var s_zone = source.find_child(zone_name, true, false)
		var t_zone = target.find_child(zone_name, true, false)
		
		if s_zone and t_zone:
			# Sync position and scale from the editor-made level
			t_zone.global_position = s_zone.global_position
			t_zone.rotation = s_zone.rotation
			t_zone.scale = s_zone.scale
			
			# If the zone has specific collision shapes (like a custom Win box), clone them over
			for old_shape in t_zone.get_children():
				if old_shape is CollisionShape2D or old_shape is CollisionPolygon2D:
					old_shape.queue_free()
			
			for new_shape in s_zone.get_children():
				if new_shape is CollisionShape2D or new_shape is CollisionPolygon2D:
					var cloned_shape = new_shape.duplicate()
					t_zone.add_child(cloned_shape)

	# PHASE D: SYNC GENERAL CONTAINERS (Upgrades, etc.)
	var dynamic_containers = ["Upgrades", "Coins", "Special", "Enemies"]	
	for c_name in dynamic_containers:
		var s_cont = source.find_child(c_name, true, false)
		var t_cont = target.find_child(c_name, true, false)
		
		if s_cont and t_cont:
			for item in s_cont.get_children():
				var new_item = item.duplicate()
				t_cont.add_child(new_item)

	# PHASE E: SPAWN & ENVIRONMENT
	_handle_spawn_and_env(source, target)



# Helper function to keep the code clean and reusable
func _sync_tile_cells(source_layer: TileMapLayer, target_layer: TileMapLayer) -> void:
	target_layer.tile_set = source_layer.tile_set
	target_layer.clear()
	
	for cell in source_layer.get_used_cells():
		target_layer.set_cell(
			cell, 
			source_layer.get_cell_source_id(cell), 
			source_layer.get_cell_atlas_coords(cell), 
			source_layer.get_cell_alternative_tile(cell)
		)

# Helper for the player setup
func _handle_spawn_and_env(source: Node, target: Node) -> void:
	# 1. Sync Spawn Position
	var s_spawn = source.find_child("PlayerSpawnPoint", true, false)
	var t_spawn = target.find_child("PlayerSpawnPoint", true, false)
	if s_spawn and t_spawn:
		t_spawn.global_position = s_spawn.global_position 

	# 2. Sync Environment Logic
	#await get_tree().process_frame
	# Force a hard check for the environment
	var env_to_use = source.get("default_environment")
	
	# If the imported level has no env
	if env_to_use == null:
		env_to_use = load("res://Resources/Environmental/Lava.tres")
	
	# Apply it to the target (the template)
	target.default_environment = env_to_use
	
	# IMPORTANT: We call this AFTER a tiny delay to ensure the 
	# Template's own internal scripts haven't overwritten it with Lava again
	if target.has_method("change_environment_resource"):
		target.change_environment_resource(env_to_use, true)
		# Manually trigger the apply one more time to be safe
		target._apply_environment(env_to_use, true)
#endregion

func _set_menu_visible(is_visible: bool) -> void:
	background.visible = is_visible
	main_split_container.visible = is_visible
	go_back_button.visible = is_visible
	bottom_panel_1.visible = is_visible
	bottom_panel_2.visible = is_visible
	
	if is_visible and current_level_instance:
		current_level_instance.queue_free()
		current_level_instance = null

func _on_go_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")


func _on_speed_up_pressed() -> void:
	Global.speed_up = !Global.speed_up
