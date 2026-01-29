extends CharacterBody2D

const DASH_COUNTER_SCENE = preload("res://Scenes + Scripts/General/Collectables/Dash Counter Player Addon.tscn")

@export var target_node: CharacterBody2D

@export_group("Override")
@export var force_upgrade_collect_on_start: bool = false

@export_group("Dash Override")
@export var forced_max_dashes: int = -1

@export_group("Follow Settings")
@export var follow_tightness: float = 5.0
@export var follow_offset: Vector2 = Vector2(-20, -10)
@export var flip_speed: float = 8.0

@export_group("Hover Settings")
@export var hover_amplitude: Vector2 = Vector2(4.0, 6.0)
@export var hover_speed: float = 1.5

@export_group("Force / Remove")
@export var enable_object_removal: bool = false
@export var removal_object: Node

@export_group("Force / Spawn")
@export var enable_object_addition: bool = false
@export var additional_object_scene: PackedScene
@export var spawn_location: Vector2i

### NEW: Variable to track who we physically follow (Player OR another Carrot)
var follow_target: Node2D = null 

var is_following: bool = false
var _is_collecting: bool = false 
var _time: float = 0.0
var _base_pos: Vector2
var _current_offset: Vector2
var _spawned_addon: Node = null
var _original_max_dashes: int = 2

func _ready() -> void:
	# --- RANDOMIZATION ---
	# Offsets the "internal clock" and speed so chained carrots don't move in unison
	_time = randf_range(0.0, 50.0) 
	hover_speed *= randf_range(0.85, 1.15)
	
	# --- AUTO-LINK CARROT REMOVER ---
	var remover = get_node_or_null("../Carrot Remover")
	if remover:
		# Connect the signal via code so you don't have to do it manually in the editor
		if not remover.body_entered.is_connected(_on_carrot_remover_body_entered):
			remover.body_entered.connect(_on_carrot_remover_body_entered)
	else:
		# Your specific error message if the node is missing
		print_rich("[color=orange]CARROT:[color=yellow]Could not find a Carrot Remover. Is this an error or intentional? [color=/]", self)

	# --- INITIALIZATION ---
	_base_pos = global_position
	_current_offset = follow_offset
	
	if has_node("DetectionArea"):
		$DetectionArea.body_entered.connect(_on_body_entered)
		
	if force_upgrade_collect_on_start == true:
		force_carrot_upgrade()

func _process(delta: float) -> void:
	_time += delta
	
	# 1. CHECK CHAIN INTEGRITY
	if is_following:
		if not is_instance_valid(follow_target):
			if is_instance_valid(target_node):
				follow_target = target_node
			else:
				is_following = false

	# 2. CALCULATE HOVER
	var x_mult: float = 1.0 if is_following else 0.0
	var hover_vector = Vector2(
		sin(_time * hover_speed) * (hover_amplitude.x * x_mult), 
		cos(_time * hover_speed * 1.1) * hover_amplitude.y        
	)
	
	# 3. UPDATE BASE POSITION
	if is_following and follow_target and not _is_collecting:
		_handle_movement_logic(delta)
	
	# 4. APPLY FINAL POSITION
	global_position = _base_pos + hover_vector

func _handle_movement_logic(delta: float) -> void:
	var player_sprite = target_node.get_node_or_null("AnimatedSprite")
	var intended_x_offset = follow_offset.x
	
	if player_sprite and player_sprite is AnimatedSprite2D:
		if player_sprite.flip_h:
			intended_x_offset = -follow_offset.x
	
	_current_offset.x = lerp(_current_offset.x, intended_x_offset, flip_speed * delta)
	_current_offset.y = follow_offset.y

	var target_goal = follow_target.global_position + _current_offset
	_base_pos = _base_pos.lerp(target_goal, 1.0 - exp(-follow_tightness * delta))

func add_dash_counter() -> void:
	if target_node:
		if forced_max_dashes >= 0:
			_original_max_dashes = target_node.max_dash_count
			target_node.max_dash_count = forced_max_dashes
			target_node._dashes_available = forced_max_dashes 
		
		if follow_target == target_node and _spawned_addon == null:
			var addon = DASH_COUNTER_SCENE.instantiate()
			target_node.add_child(addon)
			_spawned_addon = addon

func _on_carrot_remover_body_entered(body: Node2D) -> void:
	# This is now triggered by the code-connected signal from "Carrot Remover"
	if body.is_in_group("Player"):
		if is_following:
			if _is_collecting: return
			_is_collecting = true
			is_following = false 
			
			if target_node and forced_max_dashes >= 0:
				target_node.max_dash_count = _original_max_dashes
				target_node._dashes_available = min(target_node._dashes_available, _original_max_dashes)
			
			if _spawned_addon != null:
				_spawned_addon.queue_free()
				_spawned_addon = null
			
			if target_node.has_meta("last_carrot") and target_node.get_meta("last_carrot") == self:
				target_node.remove_meta("last_carrot")

			if has_node("Carrot"):
				$Carrot.play("Collect")
				await $Carrot.animation_finished
			
			self.queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and not is_following and not _is_collecting:
		target_node = body 
		
		var last_carrot_in_chain = null
		if body.has_meta("last_carrot"):
			var potential_tail = body.get_meta("last_carrot")
			if is_instance_valid(potential_tail):
				last_carrot_in_chain = potential_tail
		
		if last_carrot_in_chain:
			follow_target = last_carrot_in_chain
			print_rich("[color=yellow]CHAINING CARROT")
		else:
			follow_target = body
			print_rich("[color=green]FIRST CARROT ACQUIRED")
		
		body.set_meta("last_carrot", self)
		is_following = true
		
		if enable_object_removal and removal_object:
			removal_object.queue_free()
		
		if enable_object_addition and additional_object_scene: 
			var instance = additional_object_scene.instantiate()
			get_tree().current_scene.add_child(instance)
			if instance is Node2D:
				instance.global_position = Vector2(spawn_location)
				instance.z_index = 0
		
		add_dash_counter()

func force_carrot_upgrade():
	if target_node:
		_on_body_entered(target_node)
	else: print_rich("[color=orange]Carrot:[color=red] UPGRADE Tried to be forced but failed. Is a targetnode set?[color=/] ID:   ", self)
