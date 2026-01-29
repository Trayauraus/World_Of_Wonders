extends Control

var options_button

func _ready():
	if $MarginContainer/VBoxContainer/Resume:
		$MarginContainer/VBoxContainer/Resume.grab_focus()

func _on_resume_pressed() -> void:
	var o_menu = $"../Options Menu"
	if o_menu != null:
			o_menu.queue_free()
	##Unpause all rigid boies to avoid explosions
	
	
	var rope = get_node_or_null("../../../Rope")
	if rope != null:
		for child in $"../../../Rope".get_children():
			if child is RigidBody2D:
				# Starts physics simulation on this segment
				child.sleeping = false
				child.freeze = false # Unfreezes motion without resetting transform
	Engine.time_scale = 1
	self.queue_free()


func _on_options_pressed() -> void:
	# Load and instantiate the scene
	var options_menu_scene = preload("res://Scenes + Scripts/Menus/UI/Options_Menu.tscn")
	var options_menu_instance = options_menu_scene.instantiate()

	# Add the instance to the specified location
	var current_ui = $".."
	if current_ui != null:
		if current_ui.has_node("Win Screen"):
			return #You cant win and be in options at the same time
		if current_ui.has_node("Options Menu"):
			var o_menu = $"../Options Menu"
			if o_menu != null:
				o_menu.show()
				Engine.time_scale = 0
				self.hide()
				if options_button:
					options_button.grab_focus()
		else:
			current_ui.add_child(options_menu_instance)

			# Set the name of the instantiated scene
			options_menu_instance.name = "Options Menu"
			options_button = options_menu_instance.get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/Back")
			if options_button:
				options_button.grab_focus()
			Engine.time_scale = 0
			self.hide()


func _on_main_menu_pressed() -> void:
	Engine.time_scale = 1
	Global.current_lv = -1
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")
