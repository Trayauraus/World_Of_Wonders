extends Node2D

@export_group("UI References")
@export var label_l: Label
@export var label_r: Label

@export var universal_scene: Node2D
@export var player: CharacterBody2D

@export_group("Settings")
@export var capture_speed: float = 10.0
@export var decay_speed: float = 5.0

var percent_l: float = 0.0
var percent_r: float = 0.0

var is_occupied_l: bool = false
var is_occupied_r: bool = false

# Flags to ensure the "Destroy" logic only runs once
var destroyed_l: bool = false
var destroyed_r: bool = false
var phase: int = 1

func _ready():
	$"Phase Control/Tower Block Off R".hide()
	if has_node("Tower General"):
		$"Tower General/Towers Extra Hard Ver".hide()
	
	if has_node("Phase Control/Phase 2"):
		$"Phase Control/Phase 2/Ground".hide()
	if has_node("Phase Control/Phase 3"):
		$"Phase Control/Phase 3/Ground_Red".hide()

func _process(delta: float) -> void:
	# --- Left Tower Logic ---
	if label_l:
		if is_occupied_l:
			percent_l = move_toward(percent_l, 100.0, capture_speed * delta)
		else:
			percent_l = move_toward(percent_l, 0.0, decay_speed * delta)
		
		if percent_l >= 100.0 and not destroyed_l:
			destroyed_l = true
			
			label_l.queue_free()
			$"MISC Collisions/Block L".queue_free()
			_on_left_tower_destroyed()

	# --- Right Tower Logic ---
	if label_r:
		if is_occupied_r:
			percent_r = move_toward(percent_r, 100.0, capture_speed * delta)
		else:
			percent_r = move_toward(percent_r, 0.0, decay_speed * delta)
			
		if percent_r >= 100.0 and not destroyed_r:
			destroyed_r = true
			
			label_r.queue_free()
			$"MISC Collisions/Block R".queue_free()
			_on_right_tower_destroyed()

	# --- UI Updates ---
	if label_l: label_l.text = str(round(percent_l)) + "%"
	if label_r: label_r.text = str(round(percent_r)) + "%"

# --- Destruction Events ---

func _on_left_tower_destroyed() -> void:
	print("Left Tower Down!")
	$"Phase Control/Tower Block Off L".show()
	$"Phase Control/Tower Block Off L".collision_enabled = true
	$"Boss Death L".monitoring = true
	
	$"Tower General/Towers Extra Hard Ver".show()
	$"Tower General/Towers Extra Hard Ver".collision_enabled = true
	$"Tower General/SpotLightL2".show()
	
	$"Tower General/Tower L Escape Path Block".hide()
	$"Tower General/Tower L Escape Path Block".collision_enabled = false
	$"Tower General/Tower L Escape Path Block/Death Zone".monitoring = false
	
	change_phase()

func _on_right_tower_destroyed() -> void:
	print("Right Tower Down!")
	$"Phase Control/Tower Block Off R".show()
	$"Phase Control/Tower Block Off R".collision_enabled = true
	
	$"Tower General/Tower R Escape Path Block".hide()
	$"Tower General/Tower R Escape Path Block".collision_enabled = false
	$"Tower General/SpotLightR2".show()
	
	change_phase()
	


func change_phase() -> void:
	phase += 1
	print("Phase ", phase)
	
	if phase > 4:
		phase = 4
	
	if phase > 1:
		$"Tower General/Towers Extra Hard Ver".show()
		$"Tower General/Towers Extra Hard Ver".collision_enabled = true
		$"Boss Death Zones HARDMODE Hideable".monitoring = true
	
	
	if universal_scene:
		if universal_scene.get_script() != null:
			if player:
				if phase == 2:
					var new_resource: LevelEnvironmentData = load("res://Resources/Environmental/Grasslands.tres")
					universal_scene.change_environment_resource(new_resource)
					#universal_scene.set_grasslands_environment(player)
					$"Phase Control/Phase 1/Ground_Ice".hide()
					$"Phase Control/Phase 2/Ground".show()
					$"Phase Control/Phase 3/Ground_Red".hide()
					if $"Upgrades/Carrot DOWNGRADE1":
						$"Upgrades/Carrot DOWNGRADE1".force_carrot_upgrade() #Removes a dash so its a downgrade instead of an upgrade in this case
				if phase == 3:
					var new_resource: LevelEnvironmentData = load("res://Resources/Environmental/Lava.tres")
					universal_scene.change_environment_resource(new_resource)
					#universal_scene.set_lava_environment(player)
					$"Phase Control/Phase 1/Ground_Ice".hide()
					$"Phase Control/Phase 2/Ground".hide()
					$"Phase Control/Phase 3/Ground_Red".show()
					if $"Upgrades/Carrot DOWNGRADE0":
						$"Upgrades/Carrot DOWNGRADE0".force_carrot_upgrade() #Removals ALL Dashes
					$"Upgrades/Carrot Remover".monitoring = true
					$"Upgrades/Carrot Remover".monitorable = true
				if phase == 4:
					universal_scene.on_player_win(player)
			else: print_rich("[color=red]Eye-gler: NO PLAYER FOUND")
		else: print_rich("[color=red]Eye-gler: The provided Universal Scene node has NO script attached!")
	else: print_rich("[color=red]Eye-gler: No Universal Scene Found!")


# --- Area2D Signals (Now with Group Check) ---

func _on_block_l_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_occupied_l = true

func _on_block_l_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_occupied_l = false

func _on_block_r_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_occupied_r = true

func _on_block_r_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_occupied_r = false

func _on_zoom_cam_out_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_call_zoom_func(1.8)

func _on_zoom_cam_in_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_call_zoom_func(2.2)

func _call_zoom_func(zoomval: float):
	if $"Universal Scene":
		$"Universal Scene"._zoom_player_camera(zoomval)
