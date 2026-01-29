extends Control

func _enter_tree():
	Global.DeathCount += 1

func _ready():
	if $MarginContainer/VBoxContainer/Retry:
		$MarginContainer/VBoxContainer/Retry.grab_focus()
	if not DiscordStatusHandler:
		return
	DiscordStatusHandler.update_details_and_state("In Game", "Just Died To Level: %s   D:<" % Global.current_lv)
	DiscordStatusHandler.end_timestamp()

func _on_retry_pressed() -> void:
	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
		DiscordStatusHandler.update_details_and_state("In Game", "On Level: %s" % Global.current_lv)
		DiscordStatusHandler.start_timestamp()
	Engine.time_scale = 1
	Global.is_dead = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	Engine.time_scale = 1
	Global.is_dead = false
	get_tree().change_scene_to_file("res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn")
