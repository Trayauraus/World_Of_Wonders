@tool
extends Node

# Since this tool needs to be standalone but compatible with your Global script,
# we dynamically load the correct Resource class to prevent Editor caching bugs.

@export_group("Settings")
@export var target_tilemap: TileMapLayer:
	set(v):
		target_tilemap = v
		update_configuration_warnings()

@export_enum("Main/Foreground", "Background") var layer_type: int = 0

@export_group("Controls")
@export var CLICK_TO_SAVE: bool = false:
	set(value):
		if value == true:
			_on_save_button_pressed()
			CLICK_TO_SAVE = false
			notify_property_list_changed()

func _on_save_button_pressed():
	if not Engine.is_editor_hint(): return
	if not target_tilemap:
		printerr("TileMap Saver: ERROR - No Target Tilemap assigned!")
		return
	call_deferred("_open_save_dialog")

func _open_save_dialog():
	var fd = EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_FILESYSTEM
	fd.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	fd.add_filter("*.tlst", "Tile List Data") 
	fd.title = "Save TileMap Data for Global Loader"
	if layer_type == 0:
		fd.current_file = "tileset_main.tlst"
	else: fd.current_file = "tileset_bg.tlst"
	
	#fd.set_current_dir("user://Exports/")
	fd.file_selected.connect(_on_file_selected)
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.4)
	fd.visibility_changed.connect(func(): if not fd.visible: fd.queue_free())

func _on_file_selected(path: String):
	_save_to_path(path)

func _save_to_path(path: String):
	if not target_tilemap: return
	
	print("TileMap Saver: Extracting tiles from: ", target_tilemap.name)
	
	# --- THE FINAL FIX ---
	var actual_script: Script = _get_real_tile_data_script()
			
	if not actual_script:
		printerr("TileMap Saver: CRITICAL ERROR - Could not locate 'class_name TileDataResource' in global classes!")
		return

	print("TileMap Saver: Using confirmed script path: ", actual_script.resource_path)

	# We dynamically construct a strictly-typed Godot 4 Array.
	# This ensures store_var serializes it identically to the Godot Editor save.
	# It acts exactly like: var data_array: Array[TileDataResource] = []
	var data_array: Array = Array([], TYPE_OBJECT, &"Resource", actual_script)
	var cells = target_tilemap.get_used_cells()
	
	for cell in cells:
		var tile = actual_script.new()
		tile.local_coords = cell
		tile.source_id = target_tilemap.get_cell_source_id(cell)
		tile.atlas_coords = target_tilemap.get_cell_atlas_coords(cell)
		tile.alternative_tile = target_tilemap.get_cell_alternative_tile(cell)
		data_array.append(tile)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(data_array, true)
		file.close()
		print_rich("[color=lime]Success![/color] Saved %d tiles to: %s" % [data_array.size(), path])
	else:
		printerr("TileMap Saver: Save failed. Error: ", FileAccess.get_open_error())

func _get_real_tile_data_script() -> Script:
	var real_path = ""
	
	# Fetch the OFFICIAL path Godot has registered for this class.
	# This stops it from accidentally grabbing duplicates in "Debug" or "Backup" folders.
	for dict in ProjectSettings.get_global_class_list():
		if dict.get("class") == "TileDataResource":
			real_path = dict.get("path")
			break
			
	if real_path != "":
		# Use CACHE_MODE_IGNORE to guarantee we bypass the editor's memory cache and get the fresh file
		return ResourceLoader.load(real_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		
	return null

func _get_configuration_warnings():
	if not target_tilemap:
		return ["Please assign a Target Tilemap in the Inspector."]
	return []
