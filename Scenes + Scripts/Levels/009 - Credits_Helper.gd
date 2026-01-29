extends Node2D

var detection_count = 0

var has_won = false

const LEVEL_MANIFEST_PATH = "res://Manifest/level_manifest.tres"

# --- Script Variables ---
## A dictionary mapping a level number (e.g., 3) to its file path.
var level_paths: Dictionary = {}
## The preloaded manifest resource containing all level scenes.
@onready var level_manifest: LevelManifest = load(LEVEL_MANIFEST_PATH)
func _ready():
	$"Win Art/EndCam/CanvasLayer/Continue".hide()
	$Animated.hide()
	$"Win Art".hide()

func _on_fall_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		detection_count += 1
		
		if detection_count == 1:
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred1Label".show()
		if detection_count == 2:
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred2Label".show()
		if detection_count == 3:
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred3Label".show()
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred2Label".hide()
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred4Label".show()
		if detection_count == 4:
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred1Label".hide()
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred2Label".hide()
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred3Label".hide()
			$"Universal Scene/UNIVERSAL LV Nodes/Player/Credits/Cred4Label".hide()
			$FallDetector.monitoring = false


func _on_winbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if $"Universal Scene/UNIVERSAL LV Nodes/Player":
			$"Universal Scene/UNIVERSAL LV Nodes/Player".queue_free()
		
		$Winbox.queue_free()
		
		$"Win Art".show()
		$"Win Art/EndCam/CanvasLayer/Continue".show()
		$"Win Art/EndCam".enabled = true
		$"Universal Scene/UNIVERSAL LV Nodes/WorldEnvironment".environment = load("res://Environments/End Environment.tres")
		$Animated.show()
		$Animated/AnimationPlayer.play("Fade to white")
		has_won = true
		
func _process(_delta):
	if has_won:
		if Input.is_action_just_pressed("B_On_Xbox") or Input.is_action_just_pressed("Pause") or Input.is_action_just_pressed("Jump"):
			move_on()
	
func _input(event):
		if event is InputEventScreenTouch && event.is_pressed():
			move_on()
		
		
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				move_on()


func move_on():
	print_rich("[color=green]######################WIN#######################")
	print("Finished level: ", Global.current_lv, " also known as the END.")
	Engine.time_scale = 1
	Global.current_lv = -1
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")
