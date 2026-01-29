# rope_manager.gd
extends Node2D

## Main Bridge Rope Settings
@export_group("Main Bridge")
@export var main_segment_scene: PackedScene
@export var main_start_anchor: NodePath
@export var main_end_anchor: NodePath
@export var main_segment_count: int = 42
@export var main_first_and_last_have_col: bool = false # Renamed for clarity

## Left Support Rope Settings
@export_group("Left Rope")
@export var left_segment_scene: PackedScene
@export var left_end_anchor: NodePath 
@export var left_segment_count: int = 28
@export var l_first_and_last_have_col: bool = true

## Right Support Rope Settings
@export_group("Right Rope")
@export var right_segment_scene: PackedScene
@export var right_end_anchor: NodePath 
@export var right_segment_count: int = 28
@export var r_first_and_last_have_col: bool = true

## Shared Physics Settings
@export_group("Physics - Main Rope")
@export var segment_stiffness: float = 20.0
@export var segment_dampening: float = 80.0

## Side Rope Physics Settings (To control sag/stretch)
@export_group("Physics - Support Ropes")
@export var side_rope_stiffness: float = 0.04 # Set this much lower than main_rope for sag
@export var side_rope_dampening: float = 1.0 #Unused Due To Normal Pin Joints Not Supporting


func _ready():
	# 1. Build the main bridge. It will use the default collision layers (1 and 1).
	var main_rope_segments = _create_rope(
		get_node(main_start_anchor),
		get_node(main_end_anchor),
		main_segment_scene,
		main_segment_count,
		get_node("RopeMain"),
		1, # collision_layer
		1, # collision_mask
		main_first_and_last_have_col
		# Uses default segment_stiffness and segment_dampening
	)

	if main_rope_segments.is_empty():
		push_error("Main rope failed to generate. Stopping.")
		return

	# 2. Find the middle segment to attach the side ropes to.
	# We use the attachment point's own position as the anchor for the side ropes.
	@warning_ignore("integer_division")
	var middle_index = (main_segment_count / 2) - 1
	var attachment_point = main_rope_segments[middle_index]

	# 3. Build the side ropes, passing in the custom collision layer, mask, and SOFTNESS.
	# The soft joints allow the side rope to stretch and reduce the upward pull on the bridge.
	
	# Left Rope
	_create_rope(
		attachment_point,
		get_node(left_end_anchor),
		left_segment_scene,
		left_segment_count,
		get_node("RopeLeft"),
		8, # collision_layer
		0, #1, # collision_mask
		l_first_and_last_have_col,
		side_rope_stiffness, # <-- LOW STIFFNESS for side rope
		side_rope_dampening  # <-- LOW DAMPENING for side rope
	)
	
	# Right Rope
	_create_rope(
		attachment_point,
		get_node(right_end_anchor),
		right_segment_scene,
		right_segment_count,
		get_node("RopeRight"),
		8, # collision_layer
		0, #1, # collision_mask
		r_first_and_last_have_col,
		side_rope_stiffness, # <-- LOW STIFFNESS for side rope
		side_rope_dampening  # <-- LOW DAMPENING for side rope
	)



# ----------------------------------------------------------------------
## Updated _create_rope function
# It now accepts collision properties, a collision flag, AND optional
# overrides for stiffness and dampening.
# ----------------------------------------------------------------------
func _create_rope(
	start_node: Node,
	end_node: Node,
	segment_scene: PackedScene,
	segment_count: int,
	parent_node: Node,
	collision_layer: int = 1,
	collision_mask: int = 1,
	first_and_last_have_col: bool = false,
	# NEW: Optional overrides for physics properties (use -1.0 to use global defaults)
	local_stiffness: float = -1.0, 
	local_dampening: float = -1.0
) -> Array[RigidBody2D]:
	var created_segments: Array[RigidBody2D] = []

	if not start_node or not end_node or not segment_scene:
		print_rich("[color=yellow]Missing anchors or segment scene for a rope.")
		return created_segments

	# Determine which physics settings to use
	var current_stiffness = segment_stiffness
	var _current_dampening = segment_dampening
	if local_stiffness >= 0.0:
		current_stiffness = local_stiffness
	if local_dampening >= 0.0:
		_current_dampening = local_dampening

	var start_pos = (start_node as Node2D).global_position
	var end_pos = (end_node as Node2D).global_position

	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	@warning_ignore("incompatible_ternary")
	var actual_seg_len = distance / (segment_count + 1) if (segment_count + 1) > 0 else 0

	var prev_node = start_node
	var prev_pos = start_pos

	for i in range(segment_count):
		var seg = segment_scene.instantiate() as RigidBody2D
		var seg_pos = prev_pos + direction * actual_seg_len
		seg.global_position = seg_pos
		
		# --- ROTATION ---
		seg.rotation = direction.angle() + PI / 2

		# --- COLLISION SETUP ---
		seg.collision_layer = collision_layer
		seg.collision_mask = collision_mask
		
		# --- DISABLE COLLISION FOR FIRST AND LAST SEGMENTS IF THE FLAG IS FALSE ---
		if first_and_last_have_col: # Note the 'not' here to correctly implement the flag logic
			# Check if it's the first or the last segment
			if i == 0 or i == (segment_count - 1):
				seg.collision_layer = 0
				seg.collision_mask = 0

		parent_node.add_child(seg)
		created_segments.append(seg)

		var joint = PinJoint2D.new()
		joint.node_a = prev_node.get_path()
		joint.node_b = seg.get_path()
		joint.global_position = seg_pos
		
		# Use the determined stiffness/dampening
		joint.softness = current_stiffness 
#		joint.damping = _current_dampening # Disabled in original
		parent_node.add_child(joint)

		prev_node = seg
		prev_pos = seg_pos

	var final_joint = PinJoint2D.new()
	final_joint.node_a = prev_node.get_path()
	final_joint.node_b = end_node.get_path()
	final_joint.global_position = end_pos
	
	# Use the determined stiffness/dampening
	final_joint.softness = current_stiffness
#	final_joint.damping = _current_dampening # Disabled in original
	parent_node.add_child(final_joint)
	
	return created_segments
