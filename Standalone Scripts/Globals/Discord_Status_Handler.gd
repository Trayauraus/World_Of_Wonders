##Discord_Status_Handler.gd - Custom Made script to handle communication between the DiscordRPC addon and game.
extends Node

##Title of stuff followed by the current gamestate
func update_details_and_state(details: String, state: String):
	#if Engine.has_singleton("DiscordRPC"):
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return
	DiscordRPC.details = details
	DiscordRPC.state = state
	DiscordRPC.refresh()

##Image name then The text of the image in that order.
func update_small_image(image: String, text: String):
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return
	DiscordRPC.small_image = image
	DiscordRPC.small_image_text = text
	DiscordRPC.refresh()

##Image name then The text of the image in that order.
func update_large_image(image: String, text: String):
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return
	DiscordRPC.large_image = image
	DiscordRPC.large_image_text = text
	DiscordRPC.refresh()

func start_timestamp():
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system()) 
	DiscordRPC.refresh()

func end_timestamp():
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return
	DiscordRPC.end_timestamp = int(Time.get_unix_time_from_system())
	DiscordRPC.refresh()
