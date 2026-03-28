@tool
extends Node
class_name TileConverter

@export_category("Layers")
## The existing TileMapLayer with the old v1 tiles (Default ID 0)
@export var source_layer: TileMapLayer
@export var v1_id = 0
## The new, empty TileMapLayer where v2 tiles (Default ID 1) will go
@export var destination_layer: TileMapLayer
@export var v2_id = 1

@export_category("Settings")
## Uses the visible tile in the tile atlas if true else uses the one with no texture.
@export var show_barriers: bool = false
## Clears all previously added tiles from tilemap if true.
@export var clear_prev_tiles: bool = true
## If true, ignores mapping and copies ID 1 tiles 1:1 (Useful for merging layers)
@export var copy_v2_to_destination: bool = false

@export_category("Convert")
@export var run_conversion: bool = false:
	set(value):
		if value: 
			convert_to_new_layer()

func convert_to_new_layer():
	if not source_layer or not destination_layer:
		print("Error: Please assign both Source and Destination layers.")
		return
	
	var barrier_newtileset_vector = Vector2i(11, 30) if show_barriers else Vector2i(11, 31)

	# Tiles marked for mirroring on the Y axis (Horizontal Flip)
	var tiles_to_mirror_y = [
		Vector2i(1, 5), # Right 'hover' block
		Vector2i(9, 3), # Right up sign
		Vector2i(9, 4), # Left pole
		Vector2i(9, 5),  # Left sign
		Vector2i(8, 6)
	]

	# [Old Atlas Coords] : [New Atlas Coords]
	# Note: ONLY WORKS WITH V1 TTILESET TO CONVERT TO NEW TILESET
	var mapping = {
		##Lava Tiles
		# Row 0
		Vector2i(0, 0): Vector2i(3, 5),
		Vector2i(1, 0): Vector2i(3, 4),
		Vector2i(2, 0): Vector2i(4, 4),
		# Row 1
		Vector2i(0, 1): Vector2i(3, 6),
		Vector2i(1, 1): Vector2i(4, 5),
		Vector2i(2, 1): Vector2i(5, 5),
		Vector2i(3, 1): Vector2i(6, 5),
		# Row 2
		Vector2i(0, 2): Vector2i(3, 7),
		Vector2i(1, 2): Vector2i(4, 6),
		Vector2i(2, 2): Vector2i(5, 6),
		Vector2i(3, 2): Vector2i(6, 6), ##Duplicate Block on Tilemap for Some reason??
		# Row 3
		Vector2i(0, 3): Vector2i(3, 8), #Duplicate Block on Tilemap for Some reason?? #2
		Vector2i(1, 3): Vector2i(4, 7),
		Vector2i(2, 3): Vector2i(6, 7),
		Vector2i(3, 3): Vector2i(6, 6), ##Duplicate Block on Tilemap for Some reason??
		# Row 4
		Vector2i(0, 4): Vector2i(3, 8), #Duplicate Block on Tilemap for Some reason?? #2
		Vector2i(1, 4): Vector2i(4, 8),
		Vector2i(2, 4): Vector2i(5, 4),
		Vector2i(3, 4): Vector2i(6, 4),
		Vector2i(2, 5): Vector2i(5, 7),
		
		##LavaTree Tiles
		# Row 0
		Vector2i(12, 0): Vector2i(3, 0),
		Vector2i(13, 0): Vector2i(4, 0),
		Vector2i(14, 0): Vector2i(5, 0),
		Vector2i(15, 0): Vector2i(6, 0),
		# Row 1
		Vector2i(12, 1): Vector2i(3, 1),
		Vector2i(13, 1): Vector2i(4, 1),
		Vector2i(14, 1): Vector2i(5, 1),
		Vector2i(15, 1): Vector2i(6, 1),
		# Row 2
		Vector2i(12, 2): Vector2i(3, 2),
		Vector2i(13, 2): Vector2i(4, 2),
		Vector2i(14, 2): Vector2i(5, 2),
		Vector2i(15, 2): Vector2i(6, 2),
		# Row 3
		Vector2i(12, 3): Vector2i(3, 3),
		Vector2i(13, 3): Vector2i(4, 3),
		Vector2i(14, 3): Vector2i(5, 3),
		Vector2i(15, 3): Vector2i(6, 3),
		
		##Desert
		#Row 0
		Vector2i(3, 0): Vector2i(14, 4),
		Vector2i(4, 0): Vector2i(15, 4),
		#Row 1
		Vector2i(4, 1): Vector2i(15, 5),
		Vector2i(5, 1): Vector2i(16, 5),
		#Row 2
		Vector2i(4, 2): Vector2i(15, 6),
		Vector2i(5, 2): Vector2i(16, 6),
		#Row 3
		Vector2i(5, 3): Vector2i(16, 7),
		#Row 4
		Vector2i(5, 4): Vector2i(16, 8),
		
		##Cactus Tiles
		# Row 0
		Vector2i(2, 9): Vector2i(15, 0),
		Vector2i(3, 9): Vector2i(16, 0),
		Vector2i(4, 9): Vector2i(17, 0),
		# Row 1
		Vector2i(2, 10): Vector2i(15, 1),
		Vector2i(3, 10): Vector2i(16, 1),
		Vector2i(4, 10): Vector2i(17, 1),
		# Row 2
		Vector2i(2, 11): Vector2i(15, 2),
		Vector2i(3, 11): Vector2i(16, 2),
		Vector2i(4, 11): Vector2i(17, 2),
		# Row 3
		Vector2i(3, 12): Vector2i(16, 3),
		Vector2i(4, 12): Vector2i(17, 3),
		
		##Ice
		#Row 0
		Vector2i(5, 0): Vector2i(26, 4),
		Vector2i(6, 0): Vector2i(27, 4),
		#Row 1
		Vector2i(6, 1): Vector2i(27, 5),
		#Row 2
		Vector2i(6, 2): Vector2i(27, 6),
		Vector2i(7, 2): Vector2i(28, 6),
		#Row 3
		Vector2i(6, 3): Vector2i(27, 7),
		Vector2i(7, 3): Vector2i(26, 7),
		#Row 4
		Vector2i(6, 4): Vector2i(27, 8),
		Vector2i(7, 4): Vector2i(28, 8),
		
		##Clouds
		#Row 0
		Vector2i(7, 0): Vector2i(13, 12),
		Vector2i(8, 0): Vector2i(14, 12),
		#Row 1
		Vector2i(7, 1): Vector2i(13, 13),
		Vector2i(8, 1): Vector2i(14, 13),
		#Row 2
		Vector2i(8, 2): Vector2i(14, 14),
		
		##Cave
		Vector2i(4, 3): Vector2i(26, 19), #Most Common Block
		#Rare Cave
		Vector2i(4, 4): Vector2i(25, 8),
		Vector2i(6, 5): Vector2i(26, 20),
		Vector2i(7, 5): Vector2i(22, 14),
		Vector2i(6, 6): Vector2i(25, 20),
		Vector2i(7, 6): Vector2i(23, 14),
		
		
		##Decor
		Vector2i(0, 5): Vector2i(0, 31),
		Vector2i(1, 5): Vector2i(0, 31), #Right 'hover' block removed in favor of using mirror tool.
		
		Vector2i(8, 3): Vector2i(18, 30), #Left up sign removed in favor of using mirror tool.
		Vector2i(9, 3): Vector2i(18, 30),
		Vector2i(10, 3): Vector2i(19, 30),
		Vector2i(10, 4): Vector2i(20, 30),
		Vector2i(8, 5): Vector2i(17, 30),
		Vector2i(9, 5): Vector2i(17, 30), #Left sign removed in favor of using mirror tool.
		#Poles
		Vector2i(8, 4): Vector2i(18, 31),
		Vector2i(9, 4): Vector2i(18, 31), #Left pole removed in favor of using mirror tool.
		Vector2i(8, 6): Vector2i(19, 31),
		#Modular Board
		Vector2i(0, 6): Vector2i(0, 28),
		Vector2i(1, 6): Vector2i(1, 28),
		Vector2i(2, 6): Vector2i(2, 28),
		Vector2i(0, 7): Vector2i(0, 29),
		Vector2i(1, 7): Vector2i(1, 29),
		Vector2i(2, 7): Vector2i(2, 29),
		Vector2i(0, 8): Vector2i(0, 30),
		Vector2i(1, 8): Vector2i(1, 30),
		Vector2i(2, 8): Vector2i(2, 30),
		
		##Background
		#Gray
		Vector2i(0, 9): Vector2i(19, 22),
		Vector2i(0, 10): Vector2i(19, 23),
		Vector2i(0, 11): Vector2i(19, 24),
		Vector2i(0, 12): Vector2i(19, 25),
		Vector2i(0, 13): Vector2i(19, 26),
		Vector2i(0, 14): Vector2i(19, 27),
		#Blue
		Vector2i(1, 9): Vector2i(20, 22),
		Vector2i(1, 10): Vector2i(20, 23),
		Vector2i(1, 11): Vector2i(20, 24),
		Vector2i(1, 12): Vector2i(20, 25),
		Vector2i(1, 13): Vector2i(20, 26),
		Vector2i(1, 14): Vector2i(20, 27),
		Vector2i(1, 15): Vector2i(20, 28),
		#Misc BG
		Vector2i(3, 7): Vector2i(15, 25),
		Vector2i(4, 13): Vector2i(9, 22),
		
		Vector2i(3, 14): Vector2i(12, 23),
		Vector2i(4, 14): Vector2i(13, 23),
		Vector2i(5, 14): Vector2i(14, 23),
		Vector2i(6, 14): Vector2i(15, 23),
		Vector2i(7, 14): Vector2i(16, 23),
		
		Vector2i(2, 15): Vector2i(12, 26),
		
		Vector2i(3, 15): Vector2i(12, 24),
		Vector2i(4, 15): Vector2i(13, 24),
		Vector2i(5, 15): Vector2i(14, 24),
		Vector2i(6, 15): Vector2i(15, 24),
		Vector2i(7, 15): Vector2i(16, 24),
		
		
		##Misc
		Vector2i(0, 15): barrier_newtileset_vector, ##Barrier Blocks are special, can be "visible" variant or no texture varient.
		Vector2i(5, 5): Vector2i(9, 30), #Flag (RED) ##Blue v2 flag location is: (9, 31)
		#Lava
		Vector2i(2, 13): Vector2i(18, 28),
		Vector2i(3, 13): Vector2i(17, 28),
		Vector2i(2, 14): Vector2i(19, 28),
		#"Death" Blocks
		Vector2i(3, 5): Vector2i(22, 19),
		Vector2i(4, 5): Vector2i(23, 19),
		Vector2i(3, 6): Vector2i(22, 20),
		Vector2i(4, 6): Vector2i(23, 20),
		#Giant Flag
		Vector2i(9, 7): Vector2i(25, 23),
		Vector2i(9, 8): Vector2i(25, 24),
		Vector2i(9, 9): Vector2i(25, 25),
		Vector2i(9, 10): Vector2i(25, 26),
		Vector2i(9, 11): Vector2i(25, 27),
		Vector2i(9, 12): Vector2i(25, 28),
		Vector2i(9, 13): Vector2i(25, 29),
		Vector2i(9, 14): Vector2i(25, 30),
		Vector2i(9, 15): Vector2i(25, 31),
	}

	var cells = source_layer.get_used_cells()
	var count = 0
	
	# Clear the destination first to avoid overlaps if rerunning
	if clear_prev_tiles:
		destination_layer.clear()

	for coords in cells:
		var atlas_coords = source_layer.get_cell_atlas_coords(coords)
		var source_id = source_layer.get_cell_source_id(coords)
		var alt_id = source_layer.get_cell_alternative_tile(coords)

		if copy_v2_to_destination:
			# MODE: 1:1 COPY (Uses v2_id as the source check)
			if source_id == v2_id:
				destination_layer.set_cell(coords, v2_id, atlas_coords, alt_id)
				count += 1
		else:
			# MODE: TRANSLATION (Uses v1_id as the source check and v2_id as the output)
			if source_id == v1_id and atlas_coords in mapping:
				var new_atlas_coords = mapping[atlas_coords]
				var final_alt_id = alt_id
				
				# Apply mirroring (Horizontal Flip / Y-axis reflection) if tile is flagged
				if atlas_coords in tiles_to_mirror_y:
					final_alt_id = final_alt_id | TileSetAtlasSource.TRANSFORM_FLIP_H
					
				destination_layer.set_cell(coords, v2_id, new_atlas_coords, final_alt_id)
				count += 1
			
	var mode_text = "Copied (1:1)" if copy_v2_to_destination else "Translated"
	print("TileConverter: ", mode_text, " ", count, " tiles using Source ID ", v1_id, " -> Target ID ", v2_id)
