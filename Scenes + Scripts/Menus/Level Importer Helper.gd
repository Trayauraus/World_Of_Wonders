# Level Importer Helper.gd
# This script acts as a proxy for UniversalLevel logic within the Level Importer environment.
extends Node2D

@export_group("Level Mechanics")
## The base strength of the wind in this level. This value is passed to the player.
@export var wind_force: float = 3500.0
# --- Variables for Reference ---
var player: CharacterBody2D
var is_cave: bool = false
var wind_strength: float = 1000

# --- Nodes & Paths (Relative to Importer Structure) ---
@onready var game_node = $"../Game"
@onready var current_ui = $"../Game/Current UI"
@onready var collisions_node = $"../Game/Collisions or AREA 2Ds"

var touch_controls

func _ready():
	Global.is_dead = false
	
	# Detect Mobile for Touch Controls
	#if OS.has_feature("android") or OS.has_feature("ios"):
	_add_touch_controls()

# --- PLAYER DEATH LOGIC ---

func on_player_death() -> void:
	if not player: return
	print_rich("[color=red]LEVEL: Player has died..")
	var death_screen_scene = preload("res://Scenes + Scripts/General/Death Handler/Death Screen.tscn")
	var death_screen_instance = death_screen_scene.instantiate()
	
	if current_ui != null:
		if current_ui.has_node("Death Screen"): return
		current_ui.add_child(death_screen_instance)
		death_screen_instance.name = "Death Screen"
	
	await get_tree().create_timer(1).timeout
	Engine.time_scale = 0

func _on_death_zone_body_entered(body):
	print(body)
	if not body.is_in_group("Player"):
		return
	_on_death_body_entered(body)

func _on_death_body_entered(body):
	if not player: return
	
	# Check if UI already has a screen up
	if current_ui != null:
		if current_ui.has_node("Death Screen") or current_ui.has_node("Win Screen"):
			return 
	
	#if body is not TileMapLayer and (body.is_in_group("Player") or body.is_in_group("Enemy")):
	print("Entity Detected In DEATHZONE")
	
	#if body.is_in_group("Player"):
	Engine.time_scale = 0.75
	var death_timer = collisions_node.get_node_or_null("Death Zone/Timer")
	if death_timer:
		Global.is_dead = true
		death_timer.start()
		if player.has_method("flashplayer"): player.flashplayer()
		
		var hurt_sfx = $"../Game/LV Audio/SFX/Hurt SFX"
		if hurt_sfx: hurt_sfx.play()
		on_player_death()

# --- WIN / LEVEL COMPLETE LOGIC ---

func _on_win_zone_body_entered(body: Node2D) -> void:
	print(body)
	if body.is_in_group("Player"):
		if current_ui.has_node("Win Screen"): return
		
		var win_screen_scene = preload("res://Scenes + Scripts/Menus/UI/Win_Screen.tscn")
		var win_screen_instance = win_screen_scene.instantiate()
		current_ui.add_child(win_screen_instance)
		win_screen_instance.name = "Win Screen"
		
		Engine.time_scale = 0

# --- ENVIRONMENT & CAVE LOGIC ---

# Fixed: Redirecting environment changes and ensuring we handle potential nulls/strings
func change_environment_resource(resource):
	var importer = get_parent()
	if not importer: return
	
	# Log for debugging based on your error report
	if resource == null:
		print("Helper: Received null environment resource. Ignoring change.")
		return
		
	if importer.has_method("_apply_environment"):
		print("Helper: Redirecting environment change to Importer...")
		importer._apply_environment(resource)

# Compatibility for old string-based triggers (Ice, Lava, etc)
func change_environment(env_name: String):
	print("Helper: Received string-based environment change: ", env_name)
	var path = "res://Resources/Environmental/" + env_name + ".tres"
	if FileAccess.file_exists(path):
		var res = load(path)
		change_environment_resource(res)
	else:
		print("Helper: Could not find environment file at ", path)

func connect_cave_enter_zone(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_cave = true
		_update_importer_environment()

func connect_cave_exit_zone(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_cave = false
		_update_importer_environment()

func _update_importer_environment():
	# Communicate back to the Level Importer script to swap parallaxes/colors
	var importer = get_parent()
	if importer and importer.has_method("_update_environment_visuals"):
		print("Setting environment to include cave data: ", is_cave)
		importer._update_environment_visuals(is_cave)

# --- WIND MECHANICS ---

func enable_wind_left_to_right(body: Node2D) -> void:
	if body.is_in_group("Player"): activate_wind(1.0)

func enable_wind_right_to_left(body: Node2D) -> void:
	if body.is_in_group("Player"): activate_wind(-1.0)

func activate_wind(direction: float) -> void:
	if player and player.has_method("start_wind"):
		print("Wind started. Direction ", direction)
		player.start_wind(wind_force * direction)

func _on_wind_area_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if player.has_method("stop_wind"):
			print("Wind stopped")
			player.stop_wind()

# --- UI HANDLING ---

func _add_touch_controls() -> void:
	print("Importer Helper: Mobile Device Detected. Adding Controls.")
	var touch_scene = preload("res://Scenes + Scripts/Menus/UI/Touch Controls.tscn")
	var touch_instance = touch_scene.instantiate()
	
	if current_ui:
		current_ui.add_child(touch_instance)
		touch_instance.name = "Touch Controls"
		
		# Connect to the importer's visibility to toggle controls
		var importer = get_parent()
		if importer and "level_importer" in importer:
			var menu = importer.level_importer
			# If menu is visible now, hide controls
			if menu.visible:
				touch_instance.hide()
			touch_controls = touch_instance
			# Monitor visibility changes if possible, or just rely on the importer calling hide/show
			# (Assuming Level Importer handles the UI visibility switching)

func show_mobile_ui():
	if touch_controls:
		touch_controls.show()
