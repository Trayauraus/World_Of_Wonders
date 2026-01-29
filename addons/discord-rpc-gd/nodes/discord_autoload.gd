## This is a GDscript Node wich gets automatically added as Autoload while installing the addon.
## 
## It can run in the background to comunicate with Discord.
## You don't need to use it. If you remove it make sure to run [code]DiscordRPC.run_callbacks()[/code] in a [code]_process[/code] function.
##
## @tutorial: https://github.com/vaporvee/discord-rpc-godot/wiki
extends Node

func _ready() -> void:
	##Discord RPC Plugin Setup Below. It's docs are at: https://docs.vaporvee.com/discord-rpc-godot#quick-start
	DiscordRPC.app_id = 1422750330919321680

	# 2. Set Activity Details
	DiscordRPC.details = "Waiting For Game Load.."#"Currently exploring the forest"
	DiscordRPC.state = "_________"
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system()) 
	await get_tree().create_timer(0.01).timeout
	DiscordRPC.refresh()

func  _process(_delta) -> void:
	DiscordRPC.run_callbacks()
