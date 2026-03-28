@tool
extends Node
class_name ImporterTool

@export_category("Settings")
@export var target_tilemap: TileMapLayer:
	set(v):
		target_tilemap = v
		update_configuration_warnings()

@export_enum("Main/Foreground", "Background") var layer_type: int = 0

@export_category("Controls")
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
	else: 
		fd.current_file = "tileset_bg.tlst"
	
	fd.file_selected.connect(_on_file_selected)
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.4)
	fd.visibility_changed.connect(func(): if not fd.visible: fd.queue_free())

func _on_file_selected(path: String):
	_save_to_path(path)

func _save_to_path(path: String):
	if not target_tilemap: return
	
	print("TileMap Saver: Extracting binary tile data from: ", target_tilemap.name)
	
	# --- THE NEW WAY ---
	# We instantly grab the native PackedByteArray instead of looping through cells!
	var data_array: PackedByteArray = target_tilemap.get_tile_map_data_as_array()

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		# Save the raw binary array exactly how the Global script expects it
		file.store_var(data_array, true)
		file.close()
		print_rich("[color=lime]Success![/color] Saved tilemap binary (Size: %d bytes) to: %s" % [data_array.size(), path])
	else:
		printerr("TileMap Saver: Save failed. Error: ", FileAccess.get_open_error())

func _get_configuration_warnings():
	if not target_tilemap:
		return ["Please assign a Target Tilemap in the Inspector."]
	return []
