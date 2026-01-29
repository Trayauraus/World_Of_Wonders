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
		
		if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
			##Discord Stuff #Using my custom DiscordStatusHandler Script.
			var discord_img: String = ""
			if Global.current_lv == 1:
				discord_img = "lv_1"
			elif Global.current_lv == 2:
				discord_img = "lv_2"
			elif Global.current_lv == 3:
				discord_img = "lv_3"
			elif Global.current_lv == 4:
				discord_img = "lv_4"
			else: discord_img = "title_screen"
			
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
func _find_and_sort_levels():
	level_paths.clear()

	if not level_manifest:
		print_rich("[color=red]WIN SCREEN ERROR: Level manifest resource could not be loaded from: %s" % LEVEL_MANIFEST_PATH)
		return

	# Loop through each scene listed in our manifest file.
	for scene in level_manifest.level_scenes:
		var scene_path: String = scene.get_path()
		var file_name: String = scene_path.get_file()
		
		# Extract the three-digit number from the file name.
		var prefix = file_name.substr(0, 3)
		if prefix.is_valid_int():
			var level_num = prefix.to_int()
			# Don't add the tutorial (level 0) to the progression list.
			if level_num == 0:
				continue
			
			# Add the level number and its path to our dictionary.
			level_paths[level_num] = scene_path
		
#endregion
