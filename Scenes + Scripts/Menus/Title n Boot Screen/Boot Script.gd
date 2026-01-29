#Boot Script.gd
extends Control

# This is the path to the next scene you want to load.
var next_scene_path = "res://Scenes + Scripts/Menus/Title n Boot Screen/Boot Screen WoW.tscn"

# This variable will hold a reference to the loaded scene resource.
var loaded_scene_resource: PackedScene = null

# Flag to prevent multiple scene change calls
var scene_change_initiated: bool = false

@export var is_demo: bool = false
@onready var timer: Timer = $Timer
@onready var version_label: Label = $Animated/Version

func _ready():
	# Access the version information from the Engine singleton
	var engine_version = Engine.get_version_info()
	
	# Format the version string
	var version_string = "v%s.%s.%s" % [
		engine_version["major"],
		engine_version["minor"],
		engine_version["patch"],
	]
	
	# Set the Label's text
	version_label.text = version_string
	if is_demo:
		Global.is_demo = true
		print_rich("[color=blue]DEMO DETECTED.)")
	
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		var main_window = get_tree().get_root()
		main_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		print("Set aspect to EXPAND for mobile.")
	print_rich("[color=orange]################Boot Script###############################")
	# Start loading the next scene in the background.
	ResourceLoader.load_threaded_request(next_scene_path)
	print("Boot Screen: Starting to load next scene in background...")
	
	# Start the timer for the boot screen to display for a set duration.
	timer.start()



func _process(_delta):
	# Check if the next scene has finished loading in the background.
	if not loaded_scene_resource and ResourceLoader.load_threaded_get_status(next_scene_path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		loaded_scene_resource = ResourceLoader.load_threaded_get(next_scene_path)
		if loaded_scene_resource:
			print("Boot Screen: Next scene loaded in background.")
			# If the scene is loaded AND the timer has already ended, change scene immediately.
			if timer.is_stopped():
				_change_scene_final()

func _input(event: InputEvent):
	if scene_change_initiated:
		return

	# This allows the player to skip the boot screen with a mouse click or button press.
	#if event.is_action_pressed("ui_accept"): # You may need to replace "ui_accept" with your specific action name.
	if event.is_action_pressed("Jump") or \
	event.is_action_pressed("Pause") or \
	(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if loaded_scene_resource:
			_change_scene_final()
		else:
			print("Boot Screen: Input detected, but scene not yet loaded. Waiting for load...")


		if event is InputEventScreenTouch && event.is_pressed():
			print("Game Started Via Tap")
			if loaded_scene_resource:
				_change_scene_final()
			else:
				print("Boot Screen: Input detected, but scene not yet loaded. Waiting for load...")


func _on_timer_timeout():
	print("Boot Screen: Timer ended. Checking if scene is loaded to proceed.")
	_change_scene_final()

# This is the single function responsible for the actual scene change.
func _change_scene_final():
	if scene_change_initiated:
		return

	if loaded_scene_resource:
		scene_change_initiated = true
		
		# Create a new instance of the next scene.
		var next_scene_instance = loaded_scene_resource.instantiate()
		
		# Get a reference to the MainNode, which is the root of your scene tree.
		var main_node = get_parent()
		
		# Add the new scene instance as a child of the MainNode.
		if main_node:
			main_node.add_child(next_scene_instance)
			print("Title Screen scene added successfully!")
		else:
			print("Error: Could not find MainNode to add the next scene.")
			return
			
		# Remove the current Boot Screen scene from the scene tree.
		self.queue_free()
		print("Boot Screen removed from scene tree.")
