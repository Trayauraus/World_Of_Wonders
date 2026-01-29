extends Area2D

## Drag and drop your .tres Environment Resource here
@export var environment_to_load: LevelEnvironmentData

func _ready() -> void:
	# Connecting the signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# We search the scene tree for the specific node that has your script
		var level_manager = _find_universal_level(get_tree().current_scene)
		
		if level_manager and environment_to_load:
			level_manager.change_environment_resource(environment_to_load)
			print_rich("[color=green]Trigger: Successfully swapped environment to: [/color]", environment_to_load.resource_path.get_file())
		else:
			push_warning("EnvironmentTrigger: Could not find 'Universal Scene' node or Resource is missing.")

## Helper function to find the script even if it's buried in the tree
func _find_universal_level(node: Node) -> UniversalLevel:
	# 1. Check if the current scene root is the script (unlikely in your case)
	if node is UniversalLevel:
		return node
	
	# 2. Look for a child named "Universal Scene" specifically
	var found_node = node.find_child("Universal Scene", true, false)
	if found_node is UniversalLevel:
		return found_node
	
	# 3. Last ditch effort: loop through all children to find the class type
	for child in node.get_children():
		if child is UniversalLevel:
			return child
			
	return null
