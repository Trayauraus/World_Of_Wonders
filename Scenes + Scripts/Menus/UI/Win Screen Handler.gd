# Win Screen Hander.gd
# This script handles the logic for the win screen, allowing the player
# to proceed to the next level or return to the main menu.
extends Control

#region Constants and Variables
# --- Configuration ---
## Path to the resource that lists all our game levels.
const LEVEL_MANIFEST_PATH = "res://Resources/level_manifest.tres"

# --- Script Variables ---
## A dictionary mapping a level number (e.g., 3) to its file path.
var level_paths: Dictionary = {}
## The preloaded manifest resource containing all level scenes.
@onready var level_manifest: LevelManifest = load(LEVEL_MANIFEST_PATH)
#endregion

func _input(_event: InputEvent):
	if Input.is_action_just_pressed("Jump"):
		_on_next_lv_pressed()
	if Input.is_action_just_pressed("B_On_Xbox"):
		_on_main_menu_win_pressed()

func _ready():
	if Global.is_demo:
		$"Win Level/Start".hide()
		$"Win Level/B".hide()
		$"Win Level/VBoxContainer/Next Lv".hide()
	
	print_rich("[color=green]######################WIN#######################")
	print("Finished level: ", Global.current_lv)
	#Global.current_lv += 1
	var scene_root = get_tree().root
	if scene_root:
		for direct_child in scene_root.get_children():
			for grandchild in direct_child.get_children():
				if grandchild.name == "Universal Scene":
					if grandchild.has_method("get_current_level_number"):
						var current_lv = grandchild.get_current_level_number()
						Global.current_lv_from_sav_file = current_lv + 1
						#return
					else:
						print("Win Screen: Found 'Universal Scene' but it lacks the necessary method.")
	
	# Ensure the game is paused if it was unpaused on win.
	Engine.time_scale = 0
	# Populate the level list from our manifest when the screen loads.
	_find_and_sort_levels()
	
	if not DiscordStatusHandler:
		return
	DiscordStatusHandler.update_details_and_state("In Game", "Just Finished Level: %s" % Global.current_lv)
	DiscordStatusHandler.end_timestamp()


#region Signal Handlers
# ----------------------------------------------------------------------------
#  Public functions connected to UI button signals.
# ----------------------------------------------------------------------------

func _on_next_lv_pressed() -> void:
	# Calculate the number of the level that should come next.
	var next_level_num = Global.current_lv + 1
	print_rich("[color=cyan]WIN SCREEN: Attempting to load next level: %d" % next_level_num)

	# Check if the calculated next level exists in our list.
	if level_paths.has(next_level_num):
		# It exists! Load the scene.
		Global.current_lv = next_level_num
		
		if OS.get_name() not in ["Android", "iOS"]:
			var discord_img: String = "title_screen" # Default fallback
	
			if Global.current_lv in range(1, 9):
				discord_img = "lv_%d" % Global.current_lv
			
				DiscordStatusHandler.update_details_and_state("In Game", "On Level: %s" % Global.current_lv)
				DiscordStatusHandler.update_small_image(discord_img, "WoW! Look at level %s!" % Global.current_lv)
				DiscordStatusHandler.start_timestamp()
	
		Engine.time_scale = 1
		var scene_path = level_paths[next_level_num]
		print_rich("[color=green]WIN SCREEN: Found next level. Loading: %s" % scene_path)
		get_tree().change_scene_to_file(scene_path)
	else:
		# It's the last level. Return to the title screen.
		print_rich("[color=yellow]WIN SCREEN: No next level found. Returning to main menu.")
		get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")

func _on_main_menu_win_pressed() -> void:
	print_rich("WIN SCREEN: Returning to main menu.")
	Global.current_lv = -1 # Reset the current level tracker.
	Engine.time_scale = 1
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")
#endregion


#region Helper Functions
# ----------------------------------------------------------------------------
#  Private functions for internal script logic.
# ----------------------------------------------------------------------------

## Populates the 'level_paths' dictionary by reading from the LevelManifest resource.
## Populates the 'level_paths' dictionary by reading from the LevelManifest resource.
func _find_and_sort_levels():
	level_paths.clear()

	if not level_manifest:
		print_rich("[color=red]WIN SCREEN ERROR: Level manifest resource could not be loaded from: %s" % LEVEL_MANIFEST_PATH)
		return

	# Iterate through the Array[String] in the manifest
	for entry in level_manifest.level_scenes:
		var actual_path: String = entry
		
		# 1. Convert UID (uid://...) to a standard res:// path
		if entry.begins_with("uid://"):
			actual_path = ResourceUID.get_id_path(ResourceUID.text_to_id(entry))
		
		# 2. Extract the filename to get the level number (e.g., "001")
		var file_name: String = actual_path.get_file()
		var prefix = file_name.substr(0, 3)
		
		# 3. If the prefix is a number, map it in the dictionary
		if prefix.is_valid_int():
			var level_num = prefix.to_int()
			
			# Skip the tutorial (0) and credits
			if level_num == 0 or level_num == 9: 
				continue
				
			level_paths[level_num] = actual_path
			print("Win Screen found Level %d: %s" % [level_num, actual_path])
#endregion
