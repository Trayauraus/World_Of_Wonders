extends Control

##Change if level order has been updated and credits is no longer 9
@export var credits_manifest_no: int = 9

# --- Main Screen Nodes ---
@onready var Title_Node: Node2D = $"Title Screen"
@onready var Level_Node: Node2D = $"Level Select"
@onready var Stats_Node: Node2D = $Stats
@onready var Options_Node: Node2D = $Options


# --- Level Select Nodes ---
const LEVELS_DIR = "res://Scenes + Scripts/Levels/"
const LEVELS_PER_PAGE = 4
@onready var Coin_Total: Button = $"Level Select/Total Coins"
@onready var level_buttons_container = $"Level Select/LevelSelectButtons"
@onready var prev_button = $"Level Select/LevelSelectButtons/PrevButton"
@onready var next_button = $"Level Select/LevelSelectButtons/NextButton"
const LEVEL_MANIFEST_PATH = "res://Resources/level_manifest.tres"
@onready var level_manifest: LevelManifest = load(LEVEL_MANIFEST_PATH)
var level_paths: Dictionary = {}
var level_numbers: Array[int] = []
var current_page: int = 0

# --- NEW Stats Screen Nodes (match these to your refactored scene tree) ---
@onready var save_slot_list = $Stats/HSplitContainer/SlotListPanel/VBoxContainer/SaveSlotList
@onready var new_slot_button = $Stats/HSplitContainer/SlotListPanel/VBoxContainer/NewSlotButton
@onready var slot_detail_panel = $Stats/HSplitContainer/SlotDetailPanel
@onready var slot_name_label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/SlotNameLabel
@onready var level_label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/LevelLabel
@onready var time_label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/TimeLabel
@onready var coins_label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/CoinsLabel
@onready var coins_big_label: Label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/CoinsBigLabel
@onready var coins_special_label: Label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/CoinsSpecialLabel
@onready var death_label: Label = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/DeathLabel
@onready var load_button = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/LoadButton
@onready var delete_button = $Stats/HSplitContainer/SlotDetailPanel/VBoxContainer/DeleteButton
@onready var create_slot_dialog = $Stats/CreateSlotDialog
@onready var slot_name_input = $Stats/CreateSlotDialog/VBoxContainer/SlotNameInput
@onready var error_message_label = $Stats/CreateSlotDialog/VBoxContainer/ErrorMessage
@onready var version_warning_label = $Stats/VersionWarningLabel

## This variable will hold the name of the currently selected save slot in the list.
var selected_slot: String = ""

# MODIFICATION: New variable to track the currently LOADED save file's name.
var currently_loaded_slot: String = ""
var screenspace_expand = false

func _ready():
	if Global.is_demo:
		$"Title Screen/MarginContainer/VBoxContainer/Stats".hide()
		
		$"Level Select/Total Coins".hide()
		$"Level Select/LevelSelectButtons/Tutorial".hide()
		$"Level Select/LevelSelectButtons/1".hide()
		$"Level Select/LevelSelectButtons/2".hide()
		$"Level Select/LevelSelectButtons/3".hide()
		$"Level Select/LevelSelectButtons/4".hide()
		$"Level Select/LevelSelectButtons/PrevButton".hide()
		$"Level Select/LevelSelectButtons/NextButton".hide()
		
		$"Level Select/LevelSelectButtons/DEMO".show()
		$"Title Screen/Title DEMO".show()
		
		$"Replacement Start Screen".hide()


	
	
	if $"Title Screen/ScreenSpace" and $"Title Screen/Mobile NOTE":
		if OS.get_name() == "Android" or OS.get_name() == "iOS":
			$"Title Screen/ScreenSpace".show()
			$"Title Screen/Mobile NOTE".show()
		else:
			$"Title Screen/ScreenSpace".hide()
			$"Title Screen/Mobile NOTE".hide()
	# --- Initial Setup ---
	var project_ver = ProjectSettings.get_setting("application/config/version")
	$"Title Screen/Ver".text = "WoW. Ver %s : RELEASE BUILD" % project_ver
	
	# Initial Coin count (will be updated after save load)
	Coin_Total.text = str("Coins: ", Global.CoinCount)
	print_rich("[color=orange]#####################Title Screen########################")

	# --- Connect Signals ---
	# Level Select
	prev_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	# New Stats Screen
	new_slot_button.pressed.connect(_on_new_slot_button_pressed)
	load_button.pressed.connect(_on_load_selected_pressed)
	delete_button.pressed.connect(_on_delete_selected_pressed)

	# --- Initial State ---
	_back_to_title_menu()
	_find_and_sort_levels()
	
	# MODIFICATION: Initial check for a save file and subsequent UI update.
	_initial_save_file_check()
	# The _initial_save_file_check will now call _update_level_buttons if a save is loaded.
	# If no save is loaded, the button update should happen after the user creates a slot.
	
	# CRITICAL: We call it here *anyway* to ensure the first-time setup is done, 
	# even if _initial_save_file_check prompts for a new slot.
	_update_level_buttons()
	
	if not DiscordStatusHandler:
		return
	##Discord Stuff #Using my custom DiscordStatusHandler Script.
	DiscordStatusHandler.update_details_and_state("In Game", "On Title Screen")
	DiscordStatusHandler.update_small_image("title_screen", "Title Screen")
	DiscordStatusHandler.start_timestamp()
	
	
	#To be changed to correct value later
	if Global.current_lv_from_sav_file == 4	:
		DiscordStatusHandler.update_large_image("win", "Title Screen - Game Won!")
	
	if OS.is_debug_build():
		print_rich("[color=orange]OS Debug Build Gets Different Discord Icon")
		DiscordStatusHandler.update_large_image("rabbit_dev", "Title Screen - Developer Branch!")
	
	if Global.is_demo:
		DiscordStatusHandler.update_large_image("demo", "Title Screen - DEMO EDITION")
	
	if Global.current_lv_from_sav_file >= 9 or Global.current_lv >= 9:
		$"Title Screen/ExplodingRabbitIconWin".show()

# ============================================================================
# STATS SCREEN LOGIC
# ============================================================================

# MODIFICATION: New function to handle the initial state.
func _initial_save_file_check():
	var existing_saves = Global.get_existing_save_slots()
	#If this is a DEMO build, no save file is even needed
	if Global.is_demo:
		print_rich("[color=blue]DEMO DETECTED. NO SAVE FILE")
		return

	# Only attempt to auto-load a save file if one isn't already loaded into the Global state.
	if Global.current_sav_file.is_empty():
		
		if existing_saves.is_empty():
			# No save files found, prompt to create one.
			print("No save files found. Prompting for new slot.")
			_on_new_slot_button_pressed()
		else:
			# Load the first save file found ONLY IF no save is currently loaded globally.
			var first_slot_name = existing_saves[0]
			print("Found save files. Auto-loading the first slot: ", first_slot_name)
			
			# Set the Global state using the first file
			if Global.load_game(first_slot_name):
				Global.current_sav_file = first_slot_name
				currently_loaded_slot = first_slot_name # Store it locally too
				Coin_Total.text = str("Coins: ", Global.CoinCount) # Update UI
				print("Global state updated with default save.")
				# CRITICAL FIX: Update the level buttons NOW that Global.current_lv_from_sav_file is set!
				_update_level_buttons() 
			else:
				push_error("Auto-load failed for slot: %s" % first_slot_name)
				
			# This will select and show details of the loaded file for context
			# The save list is only populated when entering the stats screen.
			# We can simulate the button press to set up the selected_slot and details.
			selected_slot = first_slot_name
			# This is an optional call for UI consistency on the Title Screen
			if Stats_Node.visible:
				_on_save_slot_pressed(selected_slot)
	else:
		# If a file is already loaded, just update the local tracker.
		print("Save file '%s' is already loaded, skipping auto-load." % Global.current_sav_file)
		currently_loaded_slot = Global.current_sav_file
		# Update the UI in case it was a different scene that changed Global state
		Coin_Total.text = str("Coins: ", Global.CoinCount)
		
		# Ensure the selected_slot is set if the user immediately goes to Stats
		selected_slot = currently_loaded_slot
		# The level buttons are updated in _ready() after this, which is fine.


func _populate_save_slots():
	# Clear any old buttons from the list
	for child in save_slot_list.get_children():
		child.queue_free()

	# MODIFICATION: SYNCHRONIZE LOCAL STATE WITH GLOBAL STATE
	# This ensures that when we re-enter the Stats screen after loading a save 
	# and switching scenes, the correct save file is marked as green.
	currently_loaded_slot = Global.current_sav_file

	# --- Font Setup (START) ---
	# 1. Define the font path and size
	const CUSTOM_FONT_PATH = "res://Assets/Fonts/Pixel Game.otf"
	const FONT_SIZE = 50 # Keep the size constant for theme overrides

	# 2. Load the font file (FontFile resource)
	var base_font_file = load(CUSTOM_FONT_PATH)
	
	# 3. Create a Font resource (FontVariation or DynamicFont)
	var custom_font_resource
	
	if base_font_file is FontFile:
		# Use FontVariation (Godot 4)
		custom_font_resource = FontVariation.new()
		custom_font_resource.base_font = base_font_file
	elif base_font_file is Font:
		# Already a Font (e.g., loaded from a DynamicFont resource file)
		custom_font_resource = base_font_file
	
	# --- Font Setup (END) ---

	var existing_saves = Global.get_existing_save_slots()

	if existing_saves.is_empty():
		var label = Label.new()
		label.text = "No save files exist."
		save_slot_list.add_child(label)
		
		# Apply font settings to the Label if the font resource was created
		if custom_font_resource:
			label.add_theme_font_override("font", custom_font_resource)
			label.add_theme_font_size_override("font_size", FONT_SIZE)
	else:
		for slot_name in existing_saves:
			var button = Button.new()
			button.text = slot_name
			
			# Check against the synchronized local variable
			if slot_name == currently_loaded_slot:
				# Use a green color for the text of the currently loaded save
				var color_override = Color("00ff00") # Bright Green
				button.add_theme_color_override("font_color", color_override)
				# Adding hover/pressed colors helps maintain the green look
				button.add_theme_color_override("font_hover_color", color_override.darkened(0.5))
				button.add_theme_color_override("font_pressed_color", color_override.darkened(0.5))
			
			# Apply font settings to the Button if the font resource was created
			if custom_font_resource:
				button.add_theme_font_override("font", custom_font_resource)
				button.add_theme_font_size_override("font_size", FONT_SIZE)

			button.pressed.connect(_on_save_slot_pressed.bind(slot_name))
			save_slot_list.add_child(button)

func _on_save_slot_pressed(slot_name: String):
	print("Selected slot: ", slot_name)
	selected_slot = slot_name
	
	# Use our new helper function to read the data without loading it
	var data: SaveData = Global.read_save_data(slot_name)
	if data == null:
		push_error("Could not read data for slot: %s" % slot_name)
		slot_detail_panel.hide()
		return
	
	# Populate the detail panel with the data from the file
	slot_name_label.text = "Slot: %s" % data.display_name
	level_label.text = "Current Level: %s" % ("Tutorial" if data.current_lv == 0 else str(data.current_lv))
	time_label.text = "Time Played: %.2f seconds" % data.total_time
	coins_label.text = "Total Coins: %d" % data.coin_count
	coins_big_label.text = "Total BEEGCoins: %d" % data.coin_big_count
	coins_special_label.text = "Total Hidden Collectables: %d" % data.coin_special_count
	death_label.text = "Deaths: %d" % data.death_count
	
	# Check for version mismatch and show warning if needed
	var current_version = ProjectSettings.get_setting("application/config/version", "1.0.0")
	if data.version_control != current_version:
		version_warning_label.show()
		version_warning_label.text = "WARNING: Godot version mismatch between save file and Godot \nGodot: %s   vs   Saved: %s" % [current_version, data.version_control]
	else:
		version_warning_label.hide()

	slot_detail_panel.show()

func _on_load_selected_pressed():
	if selected_slot.is_empty(): return
	
	print("Loading game from slot: ", selected_slot)
	
	# 1. Load the game data into the Global state
	if Global.load_game(selected_slot):
		currently_loaded_slot = selected_slot 
		Global.current_sav_file = currently_loaded_slot
		# MODIFICATION: Update our local variable for the visual highlight
		print("Global state updated successfully")
		
		# 2. Update any displayed global values that may have changed.
		Coin_Total.text = str("Coins: ", Global.CoinCount)
		
		# MODIFICATION: Refresh the save slots list to update the visual highlight
		_populate_save_slots() 
		
		_update_level_buttons()
		# 3. Change to the Level Select screen.
		_on_play_pressed()
	else:
		push_error("Load failed for slot: %s" % selected_slot)

func _on_delete_selected_pressed():
	if selected_slot.is_empty(): return
	
	print("Deleting save slot: ", selected_slot)
	Global.delete_save(selected_slot)
	
	# MODIFICATION: If the loaded slot was deleted, clear the loaded slot tracker.
	if selected_slot == currently_loaded_slot:
		currently_loaded_slot = ""
	
	# Hide the details of the now-deleted file and refresh the list
	slot_detail_panel.hide()
	selected_slot = ""
	_populate_save_slots()

func _on_new_slot_button_pressed():
	slot_name_input.text = ""
	error_message_label.text = ""
	create_slot_dialog.popup_centered()
	# MODIFICATION: Using call_deferred to ensure the dialog is visible before attempting to grab focus.
	call_deferred("grab_focus_on_slot_input") 
	
# MODIFICATION: Helper function for deferred focus
func grab_focus_on_slot_input():
	slot_name_input.grab_focus()


func _on_create_slot_confirm_pressed():
	var new_name = slot_name_input.text.strip_edges()
	
	# Validation checks
	if new_name.is_empty():
		error_message_label.text = "Name cannot be empty."
		return
	
	var existing_saves = Global.get_existing_save_slots()
	if new_name.to_lower() in existing_saves.map(func(s): return s.to_lower()):
		error_message_label.text = "A save with this name already exists."
		return

	# All checks passed, create a new save file
	print("Creating new save slot: ", new_name)
	Global.reset_game_state() # Start with fresh data
	Global.save_game(new_name) # Save the fresh data to the new file
	
	# MODIFICATION: Automatically make the new slot the loaded one.
	Global.current_sav_file = new_name
	currently_loaded_slot = new_name
	Coin_Total.text = str("Coins: ", Global.CoinCount) # Update UI
	
	create_slot_dialog.hide()
	_populate_save_slots() # Refresh the list to show the new save and its green highlight
	
	# CRITICAL FIX: Update level buttons after creating a new save!
	_update_level_buttons() 

	# MODIFICATION: Select the new slot to show its details immediately.
	selected_slot = new_name
	_on_save_slot_pressed(selected_slot)


# ============================================================================
# SCREEN NAVIGATION AND OTHER LOGIC
# ============================================================================

func _input(event: InputEvent):
	if OS.is_debug_build() and event.is_action_pressed("Dev_Button"):
		get_tree().change_scene_to_file("res://Scenes + Scripts/Levels/DEV/Dev_Test_Scene.tscn")

func _swap_screenspace_mode():
	var main_window = get_tree().get_root()
	if screenspace_expand:
		main_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		print("Changed Screenspace Mode To Keep")
		screenspace_expand = !screenspace_expand
	else:
		main_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		print("Changed Screenspace Mode To Expand")
		screenspace_expand = !screenspace_expand

func _on_play_pressed():
	print("Title: Main Menu --> Level Select")
	Level_Node.show()
	Title_Node.hide()
	Stats_Node.hide()
	Options_Node.hide()
	$"Level Select/LevelSelectButtons/1".grab_focus()

func _on_options_pressed():
	print("Title: Main Menu --> Options")
	Options_Node.show()
	Title_Node.hide()
	Level_Node.hide()
	Stats_Node.hide()
	
	if $Options/Options_Menu/MarginContainer/PanelContainer/VBoxContainer/Back:
		$Options/Options_Menu/MarginContainer/PanelContainer/VBoxContainer/Back.grab_focus()

func _back_to_title_menu() -> void:
	print("Title: Main Menu <-- Level Select / Stats / Options")
	Title_Node.show()
	Level_Node.hide()
	Stats_Node.hide()
	Options_Node.hide()
	slot_detail_panel.hide() # Hide details when leaving stats screen
	version_warning_label.hide()
	$"Title Screen/MarginContainer/VBoxContainer/Play".grab_focus()

func _on_stats_pressed():
	print("Title: Main Menu --> Stats")
	Stats_Node.show()
	Title_Node.hide()
	Level_Node.hide()
	Options_Node.hide()
	_populate_save_slots() # Populate the list every time we enter the screen
	if $"Stats/Stats Go Back":
		$"Stats/Stats Go Back".grab_focus()

func _on_exit_pressed():
	get_tree().quit()

func _on_tutorial_pressed() -> void:
	print("Entering Tutorial")

	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
		DiscordStatusHandler.update_details_and_state("In Game", "Currently On The Tutorial")
		DiscordStatusHandler.start_timestamp()

	Global.current_lv = 0
	Global.is_dead = false
	#get_tree().change_scene_to_file("res://Scenes + Scripts/Levels/000_Tutorial Grounds.tscn")
	if Global.current_lv_from_sav_file != 0:
		get_tree().change_scene_to_file("res://Scenes + Scripts/Levels/000_Tutorial Grounds.tscn")
		if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
			DiscordStatusHandler.update_small_image("tutorial", "WoW! Look at The Tutorial Grounds! So Red..")
	else:
		get_tree().change_scene_to_file("res://Scenes + Scripts/Levels/-001 Tutorial Grasslands.tscn")
		if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
			DiscordStatusHandler.update_small_image("tutorial_grass", "WoW! Look at Thhat Tutorial Grassland!")
# ============================================================================
# LEVEL SELECT LOGIC (Unchanged from your script)
# ============================================================================

func _find_and_sort_levels():
	level_paths.clear()
	level_numbers.clear()
	if not level_manifest: return
	for scene in level_manifest.level_scenes:
		var scene_path: String = scene.get_path()
		var file_name: String = scene_path.get_file()
		var prefix = file_name.substr(0, 3)
		if prefix.is_valid_int():
			var level_num = prefix.to_int()
			if level_num == 0: continue
			if level_num == credits_manifest_no: continue
			level_paths[level_num] = scene_path
	var keys = level_paths.keys()
	for key in keys: level_numbers.append(key)
	level_numbers.sort()

func _update_level_buttons():
	await get_tree().create_timer(0.01).timeout
	if Global.current_lv_from_sav_file >= 9 or Global.current_lv >= 9:
		$"Title Screen/ExplodingRabbitIconWin".show()
		$"Replacement Start Screen".hide()
	else:
		$"Title Screen/ExplodingRabbitIconWin".hide()
	var start_index = current_page * LEVELS_PER_PAGE
	
	# Fetch the highest unlocked level number.
	# Levels 1 and above are locked if their number is > this value.
	# The Tutorial (Level 0) is handled separately to always be unlocked.
	var highest_unlocked_level: int = Global.current_lv_from_sav_file

	for i in range(LEVELS_PER_PAGE):
		var button: Button = level_buttons_container.get_node(str(i + 1))
		var level_array_index = start_index + i
		
		# Clear existing connections to prevent multiple connections on refresh
		if button.is_connected("pressed", _on_level_button_pressed):
			button.pressed.disconnect(_on_level_button_pressed)
			
		if level_array_index < level_numbers.size():
			var level_num = level_numbers[level_array_index]
			
			button.text = str(level_num)
			
			# --- NEW UNLOCK LOGIC ---
			var is_unlocked: bool
			
			if OS.is_debug_build():
				# 1. Debug Build: Always unlocked
				is_unlocked = true
			elif level_num == 0:
				# 2. Tutorial (Level 0): Always unlocked (even though it's not in level_numbers array)
				# NOTE: Since you're filtering out level 0 in _find_and_sort_levels, 
				# this check is technically for robustness if level_num were to include 0.
				# The actual tutorial button is handled separately via _on_tutorial_pressed.
				is_unlocked = true
			else:
				# 3. Standard Levels (1+): Unlocked if the level number is less than or equal to 
				# the highest level saved in the file (Global.current_lv_from_sav_file).
				is_unlocked = level_num <= highest_unlocked_level
			
			if is_unlocked:
				button.disabled = false
				# Connect the signal only if the button is enabled
				button.pressed.connect(_on_level_button_pressed.bind(i + 1))
			else:
				button.disabled = true
				# Optional: Set the text to visually indicate it's locked
				# button.text = "[LOCKED]" 
			# --- END NEW UNLOCK LOGIC ---
			
		else:
			# For buttons that go beyond the list of available levels
			button.text = "-"
			button.disabled = true
			
	prev_button.disabled = (current_page == 0)
	next_button.disabled = ((current_page + 1) * LEVELS_PER_PAGE >= level_numbers.size())

func _on_level_button_pressed(button_index: int):
	var level_array_index = (current_page * LEVELS_PER_PAGE) + (button_index - 1)
	if level_array_index < level_numbers.size():
		var level_to_load = level_numbers[level_array_index]
		var scene_path = level_paths[level_to_load]
		Global.current_lv = level_to_load
		Global.is_dead = false
		Engine.time_scale = 1
		
		if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
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
		get_tree().change_scene_to_file(scene_path)



func _on_previous_pressed():
	if current_page > 0:
		current_page -= 1
		_update_level_buttons()

func _on_next_pressed():
	current_page += 1
	_update_level_buttons()


func _on_demo_pressed() -> void:
	print("Entering Tutorial")

	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
		DiscordStatusHandler.update_details_and_state("In Game", "Currently In The DEMO Level")
		DiscordStatusHandler.update_small_image("demo_lv", "WoW! Look at That DEMO!")
		DiscordStatusHandler.start_timestamp()

	Global.current_lv = 0
	Global.is_dead = false
	get_tree().change_scene_to_file("res://Scenes + Scripts/Levels/Level_DEMO.tscn")


func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://Multiplayer/Multiplayer.tscn")
