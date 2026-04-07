@tool
extends Node
class_name LevelDataExporterTool

@export_category("Exporter Controls")
## Check this box in the inspector to trigger the export process.
@export var trigger_export: bool = false:
	set(value):
		if Engine.is_editor_hint() and value == true:
			_run_export()
			trigger_export = false # Uncheck automatically

## Where the file should be saved (e.g., res://MyExtractedLevel.dat)
@export_file_path("*.dat") var export_file_path: String = "project_data.dat"
@export var level_name: String = "Extracted Level"

@export_category("Level Variables")
@export var camera_zoom: float = 2.4
@export var player_dashes: int = 2
@export var ice_physics: bool = false
@export var force_light: bool = false
@export_enum("None:0", "Lava:1", "Lava Darkened:2", "Desert:3", "Ice:4", "Grasslands:5") var custom_environment: int = 1

@export_category("Node References")
@export var player_node: Node2D
@export var carrot_holder: Node
## Drag the parent of regular coins here.
@export var coin_holder: Node
## Drag the parent of special/objective coins here.
@export var special_coin_holder: Node
@export var enemy_holder: Node
@export var collisions_parent: Node
## Drag the parent node containing Carrot Remover Area2Ds here.
@export var carrot_remover_node: Area2D
## Drag an AudioStreamPlayer here to export its current song.
@export var music_player: AudioStreamPlayer

func _run_export():
	print("--- Starting Level Data Extraction ---")
	
	# 1. Setup Data Structures
	var player_spawn: Vector2 = Vector2.ZERO
	if player_node:
		player_spawn = player_node.global_position
		
	var carrot_locations: Array = []
	var coin_locations: Array = []
	var enemy_locations: Array = []
	
	var winzone_location: Array = []
	var deathzone_locations: Array = []
	var cave_locations: Array = []
	var wind_locations: Array = []
	var carrot_remover_locations: Array = []
	var custom_environment_call_change_zone: Array = []

	# Music Data Variables
	var custom_music_data: PackedByteArray = PackedByteArray()
	var custom_music_extension: String = ""
	var custom_music_name: String = ""
	
	# 2. Extract Entities
	if carrot_holder:
		for child in carrot_holder.get_children():
			if child is CharacterBody2D:
				var dict = { "location": child.global_position }
				if "forced_max_dashes" in child: dict["dash_count"] = child.get("forced_max_dashes")
				elif "dash_count" in child: dict["dash_count"] = child.get("dash_count")
				else: dict["dash_count"] = 1
				carrot_locations.append(dict)
	
	# Extract Regular Coins
	if coin_holder:
		for child in coin_holder.get_children():
			if child is Node2D:
				coin_locations.append(_get_coin_dict(child))
				
	# Extract Special Coins into the SAME array
	if special_coin_holder:
		for child in special_coin_holder.get_children():
			if child is Node2D:
				coin_locations.append(_get_coin_dict(child))
				
	if enemy_holder:
		for child in enemy_holder.get_children():
			if child is Node2D:
				var dict = { "location": child.global_position }
				dict["tank_variant"] = child.get("tank_variant") if "tank_variant" in child else 0
				dict["speed"] = child.get("speed") if "speed" in child else 100.0
				dict["emits_light"] = child.get("emits_light") if "emits_light" in child else false
				enemy_locations.append(dict)

	# 3. Extract Collision Zones (Handles both Shapes and Polygons)
	if collisions_parent:
		for area in collisions_parent.get_children():
			if not area is Area2D: continue
			
			var area_name = area.name
			
			for shape_node in area.get_children():
				var shape_data = _get_rect_data_from_node(shape_node)
				if shape_data.is_empty(): continue
				
				var dict = {
					"location": shape_data.location,
					"shape_size": shape_data.size
				}
				
				if "Wind L" in area_name:
					dict["wind_type"] = "Wind - Activate Left"
					wind_locations.append(dict)
				elif "Wind R" in area_name:
					dict["wind_type"] = "Wind - Activate Right"
					wind_locations.append(dict)
				elif "Deactivate" in area_name:
					dict["wind_type"] = "Wind - Deactivate"
					wind_locations.append(dict)
				elif "Win" in area_name: 
					winzone_location.append(dict)
				elif "Death" in area_name:
					deathzone_locations.append(dict)
				elif "Cave" in area_name:
					dict["cave_type"] = "Cave Area"
					cave_locations.append(dict)
				
				# Environment Zones
				elif "Lava Env" in area_name:
					dict["environment_type"] = "Environment - Lava"
					custom_environment_call_change_zone.append(dict)
				elif "Lava DARK" in area_name:
					dict["environment_type"] = "Environment - Lava DARKENED"
					custom_environment_call_change_zone.append(dict)
				elif "Desert" in area_name:
					dict["environment_type"] = "Environment - Desert"
					custom_environment_call_change_zone.append(dict)
				elif "Ice" in area_name:
					dict["environment_type"] = "Environment - Ice"
					custom_environment_call_change_zone.append(dict)
				elif "Grass" in area_name:
					dict["environment_type"] = "Environment - Grasslands"
					custom_environment_call_change_zone.append(dict)

	# 4. Extract Carrot Remover (Direct Node)
	if carrot_remover_node:
		for shape_node in carrot_remover_node.get_children():
			var shape_data = _get_rect_data_from_node(shape_node)
			if shape_data.is_empty(): continue
			
			var dict = {
				"location": shape_data.location,
				"shape_size": shape_data.size
			}
			carrot_remover_locations.append(dict)

	# 5. Extract Music from AudioStreamPlayer
	if music_player and music_player.stream:
		var stream_path = music_player.stream.resource_path
		if stream_path != "" and FileAccess.file_exists(stream_path):
			custom_music_data = FileAccess.get_file_as_bytes(stream_path)
			custom_music_extension = stream_path.get_extension().to_lower()
			custom_music_name = stream_path.get_file()
			print("- Music Detected: ", custom_music_name)

	# 6. Compile the Final Dictionary
	var export_data = {
		"project_name": level_name,
		"godot_version": Engine.get_version_info(),
		"time_when_saved": Time.get_date_string_from_system(),
		
		"player_spawn": player_spawn,
		"camera_zoom": camera_zoom,
		"player_dashes": player_dashes,
		"ice_physics": ice_physics,
		"force_light": force_light,
		"custom_environment": custom_environment,
		
		"carrot_locations": carrot_locations,
		"coin_locations": coin_locations, 
		"enemy_locations": enemy_locations,
		"winzone_location": winzone_location,
		"deathzone_locations": deathzone_locations,
		"cave_locations": cave_locations,
		"wind_locations": wind_locations,
		"carrot_remover_locations": carrot_remover_locations,
		"custom_environment_call_change_zone": custom_environment_call_change_zone,
		"camerazoom_locations": [],
		
		# Embedded Music Data
		"custom_music_data": custom_music_data,
		"custom_music_extension": custom_music_extension,
		"custom_music_name": custom_music_name
	}

	# 7. Save to File
	var file = FileAccess.open(export_file_path, FileAccess.WRITE)
	if file:
		file.store_var(export_data, true)
		file.close()
		print_rich("[color=green]Successfully extracted level data to:[/color] ", export_file_path)
		print("- Carrots: ", carrot_locations.size())
		print("- Total Coins: ", coin_locations.size())
		print("- Enemies: ", enemy_locations.size())
		if not custom_music_data.is_empty():
			print_rich("- Music [color=cyan]Included[/color]")
	else:
		push_error("Failed to save extracted data. Error code: ", FileAccess.get_open_error())

## Helper to extract coin data consistently
func _get_coin_dict(node: Node2D) -> Dictionary:
	var dict = { "location": node.global_position }
	dict["emits_light"] = node.get("emits_light") if "emits_light" in node else false
	dict["coin_variant"] = node.get("coin_variant") if "coin_variant" in node else 0
	dict["coin_size"] = node.get("coin_size") if "coin_size" in node else 1.0
	return dict

## NEW HELPER: Converts Shape2D or Polygon2D into rectangular data (AABB)
func _get_rect_data_from_node(node: Node) -> Dictionary:
	if node is CollisionShape2D:
		var rect = node.shape as RectangleShape2D
		if rect:
			return { "location": node.global_position, "size": rect.size }
	
	elif node is CollisionPolygon2D:
		var points = node.polygon
		if points.size() > 0:
			# Calculate the Bounding Box of the polygon
			var min_pos = points[0]
			var max_pos = points[0]
			for i in range(1, points.size()):
				min_pos.x = min(min_pos.x, points[i].x)
				min_pos.y = min(min_pos.y, points[i].y)
				max_pos.x = max(max_pos.x, points[i].x)
				max_pos.y = max(max_pos.y, points[i].y)
			
			var poly_size = max_pos - min_pos
			# The center of the polygon's bounding box in global space
			var center_offset = min_pos + (poly_size / 2.0)
			var global_center = node.to_global(center_offset)
			
			return { "location": global_center, "size": poly_size }
			
	return {}
