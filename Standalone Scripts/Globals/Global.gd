extends Node

# Preload your new SaveData resource.
# IMPORTANT: Update the path to where you saved your SaveData.gd file.
const SAVE_DATA = preload("res://Standalone Scripts/SaveData.gd")

#Game data
var is_demo = false

var current_sav_file: String
var is_dead = false

var current_lv: int = -1
var current_lv_from_sav_file: int = 0

var CoinCount: int = 0
var CoinSpecialCount: int = 0
var CoinBigCount: int = 0

var Total_Time: float = 0.0
var DeathCount: int = 0

#Settings
var Fullscreen: bool = false

var Environment_On: bool = true
var Particles_On: bool = true
var Instant_Respawn: bool = true
var MuteGame: bool = false
var Volume: float

var Force_Stop_Time = false
var Has_Fallen = false

func _ready():
	var MASTER_BUS_INDEX = AudioServer.get_bus_index("Master")
	Volume = AudioServer.get_bus_volume_db(MASTER_BUS_INDEX)


func _input(_event: InputEvent):
	if Input.is_action_just_pressed("Fullscreen"):
		if not Fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		Fullscreen = !Fullscreen

## Scans the save directory and returns an array of slot names (without the extension).
func get_existing_save_slots() -> Array[String]:
	var slots: Array[String] = [] 
	# IndieBlueprintSavedGame.default_path holds the path to your save folder.
	var dir = DirAccess.open(IndieBlueprintSavedGame.default_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# Get the filename without the ".tres" or ".res" extension.
				var slot_name = file_name.get_basename()
				slots.append(slot_name)
			file_name = dir.get_next()
	else:
		print("Could not open save directory: ", IndieBlueprintSavedGame.default_path)
	
	return slots

## Call this function to save the current game state.
func save_game(slot_name: String):
	print("Attempting to save game to slot: ", slot_name)
	# Create a new instance of our save data resource.
	var save_file = SAVE_DATA.new()
	save_file.display_name = slot_name
	
	# Populate the save file instance with current data from Global.
	save_file.current_lv = current_lv_from_sav_file
	save_file.coin_count = CoinCount
	save_file.coin_special_count = CoinSpecialCount
	save_file.coin_big_count = CoinBigCount
	save_file.total_time = Total_Time
	save_file.death_count = DeathCount
	
	# Use the Indie Blueprint function to write the file to disk.
	var error = save_file.write_savegame(slot_name)
	
	if error == OK:
		print("Game saved successfully!")
	else:
		push_error("Failed to save game. Error code: %s" % error)

## Reads a save file and returns the SaveData resource without applying it globally.
## Returns null if the file doesn't exist or fails to load.
func read_save_data(slot_name: String) -> SaveData:
	var save_path = IndieBlueprintSavedGame.get_save_path(slot_name)
	
	if not ResourceLoader.exists(save_path):
		print("No save file found at path: ", save_path)
		return null
	
	var data: SaveData = ResourceLoader.load(save_path)
	return data

## Call this function to load the game state from a file.
func load_game(slot_name: String) -> bool:
	var save_path = IndieBlueprintSavedGame.get_save_path(slot_name)
	
	if not ResourceLoader.exists(save_path):
		print("No save file found at: ", save_path)
		return false
	
	print("Loading game from slot: ", slot_name)
	# Load the resource from the file.
	var loaded_data: SaveData = ResourceLoader.load(save_path)
	
	if loaded_data:
		# Apply the loaded data to the Global script.
		current_lv_from_sav_file = loaded_data.current_lv
		CoinCount = loaded_data.coin_count
		CoinSpecialCount = loaded_data.coin_special_count
		CoinBigCount = loaded_data.coin_big_count
		Total_Time = loaded_data.total_time
		DeathCount = loaded_data.death_count
		print("Game loaded successfully!")
		return true
	else:
		push_error("Failed to load data from path: %s" % save_path)
		return false

## Deletes a specific save file based on its slot name.
func delete_save(slot_name: String):
	var save_path = IndieBlueprintSavedGame.get_save_path(slot_name)
	
	if not FileAccess.file_exists(save_path):
		push_warning("Attempted to delete a save that does not exist: %s" % slot_name)
		return

	var error = DirAccess.remove_absolute(save_path)
	if error == OK:
		print("Successfully deleted save file: ", slot_name)
	else:
		push_error("Error deleting save file %s. Error code: %s" % [slot_name, error])

## Call this to reset all variables to their default state (e.g., for a new game).
func reset_game_state():
	current_lv = -1
	current_lv_from_sav_file = 0
	CoinCount = 0
	CoinSpecialCount = 0
	CoinBigCount = 0
	Total_Time = 0.0
	DeathCount = 0
	print("Global game state has been reset.")
