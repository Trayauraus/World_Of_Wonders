##Options Menu.gd
extends Control

@export var is_on_title: bool = false
@export var darken_area_around_options: bool = true

func _ready():
	if Global.current_lv == 1:
		_spawn_warning()
	# Initialize the UI controls with the current global settings
	# Assuming your UI nodes are named appropriately (e.g., CheckBox, HSlider)
	if $"MarginContainer/PanelContainer/VBoxContainer/World Environment":
		$"MarginContainer/PanelContainer/VBoxContainer/World Environment".set_pressed_no_signal(Global.Environment_On)
	if $MarginContainer/PanelContainer/VBoxContainer/Particles:
		$MarginContainer/PanelContainer/VBoxContainer/Particles.set_pressed_no_signal(Global.Particles_On)
	if $"MarginContainer/PanelContainer/VBoxContainer/Instant Respawn2":
		$"MarginContainer/PanelContainer/VBoxContainer/Instant Respawn2".set_pressed_no_signal(!Global.Instant_Respawn)
	if $MarginContainer/PanelContainer/VBoxContainer/MuteGame:
		$MarginContainer/PanelContainer/VBoxContainer/MuteGame.set_pressed_no_signal(Global.MuteGame)
	if $MarginContainer/PanelContainer/VBoxContainer/Volume:
		$MarginContainer/PanelContainer/VBoxContainer/Volume.set_value_no_signal(Global.Volume)
	
	
	if not is_on_title:
		if $MarginContainer/PanelContainer/VBoxContainer/Back:
			$MarginContainer/PanelContainer/VBoxContainer/Back.grab_focus()
	if not darken_area_around_options:
		print("Not added")
		pass

func _return_to_prev():
	if is_on_title:
		$"..".hide()
		$"../../Title Screen".show()
		$"../../Level Select".hide()
		$"../../Stats".hide()
		if $"../../Title Screen/MarginContainer/VBoxContainer/Play":
			$"../../Title Screen/MarginContainer/VBoxContainer/Play".grab_focus()
	else:
		if $"../Pause Menu":
			$"../Pause Menu".show()
			if $"../Pause Menu/MarginContainer/VBoxContainer/Resume":
				$"../Pause Menu/MarginContainer/VBoxContainer/Resume".grab_focus()
		self.hide()


func _on_world_environment_toggled(toggled_on: bool) -> void:
	Global.Environment_On = toggled_on
	if $"../..":
		$"../.."._setup_environment()


func _on_particles_toggled(toggled_on: bool) -> void:
	Global.Particles_On = toggled_on
	if $"../..":
		$"../.."._setup_environment()

func _on_instant_respawn_2_toggled(toggled_on: bool) -> void:
	Global.Instant_Respawn = !toggled_on


func _on_mute_game_toggled(toggled_on: bool) -> void:
	Global.MuteGame = toggled_on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), toggled_on)


func _on_volume_value_changed(value: float) -> void:
	Global.Volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(Global.Volume))
	print("Volume set to: ", Global.Volume)

func _spawn_warning():
	if $Warning:
		$Warning.show()
