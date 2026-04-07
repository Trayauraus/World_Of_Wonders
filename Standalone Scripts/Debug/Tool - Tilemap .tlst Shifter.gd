@tool
extends Node
## Tilemap Shifter Tool
## This tool loads .tlst (PackedByteArray) files, offsets all tile coordinates, 
## and saves them back. Useful for fixing alignment issues after imports.

@export_group("File Settings")
## The folder containing the .tlst files (e.g., "user://Projects/MyLevel/")
@export_dir var project_folder: String = "user://"
## The filename for the main tilemap (Match your screenshot: tileset_main.tlst)
@export var main_tlst_name: String = "tileset_main.tlst"
## The filename for the background tilemap (Match your screenshot: tileset_bg.tlst)
@export var bg_tlst_name: String = "tileset_bg.tlst"

@export_group("Shift Settings")
## How many tiles to shift (X = Horizontal, Y = Vertical)
@export var tile_offset: Vector2i = Vector2i(0, 0)

@export_group("Execution")
## Click this checkbox in the inspector to run the process
@export var run_shift_process: bool = false:
	set(value):
		if value:
			_execute_shift()
			run_shift_process = false

func _execute_shift():
	if project_folder.is_empty():
		push_error("Shifter Tool: Project folder is not set.")
		return
	
	print_rich("[color=cyan][b]Starting Tilemap Shift Process...[/b][/color]")
	print_rich("Offset: ", tile_offset)

	# We use a temporary TileMapLayer to handle the heavy lifting of coordinate translation
	var temp_layer = TileMapLayer.new()
	add_child(temp_layer)
	
	# Process Main Layer
	_process_layer_file(temp_layer, main_tlst_name)
	
	# Process BG Layer
	_process_layer_file(temp_layer, bg_tlst_name)
	
	temp_layer.queue_free()
	print_rich("[color=lime][b]Shift Process Complete![/b][/color]")

func _process_layer_file(layer: TileMapLayer, filename: String):
	var path = project_folder.path_join(filename)
	
	if not FileAccess.file_exists(path):
		print_rich("[color=yellow]Skipping: ", filename, " (File not found at ", path, ")[/color]")
		return

	# 1. Load the PackedByteArray
	var file = FileAccess.open(path, FileAccess.READ)
	var raw_data = file.get_var(true)
	file.close()

	if typeof(raw_data) != TYPE_PACKED_BYTE_ARRAY:
		push_error("Shifter Tool: " + filename + " is not a valid PackedByteArray.")
		return

	# 2. Apply to layer
	layer.clear()
	layer.set_tile_map_data_from_array(raw_data)
	
	# 3. Extract cells and shift
	var used_cells = layer.get_used_cells()
	var new_cell_data = [] # Stores [coords, source_id, atlas_coords, alternative_tile]
	
	for cell in used_cells:
		var source_id = layer.get_cell_source_id(cell)
		var atlas_coords = layer.get_cell_atlas_coords(cell)
		var alt_tile = layer.get_cell_alternative_tile(cell)
		
		new_cell_data.append({
			"new_pos": cell + tile_offset,
			"source": source_id,
			"atlas": atlas_coords,
			"alt": alt_tile
		})
	
	# 4. Clear and rebuild layer with shifted coordinates
	layer.clear()
	for d in new_cell_data:
		layer.set_cell(d.new_pos, d.source, d.atlas, d.alt)
		
	# 5. Extract back to PackedByteArray
	var shifted_data: PackedByteArray = layer.get_tile_map_data_as_array()
	
	# 6. Save back to disk (overwriting the old file)
	var write_file = FileAccess.open(path, FileAccess.WRITE)
	write_file.store_var(shifted_data, true)
	write_file.close()
	
	print_rich("[color=green]Successfully shifted and saved: [/color]", filename)
