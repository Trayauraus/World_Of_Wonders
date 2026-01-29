extends Area2D

@export_group("Coin Settings")
##Whether the coin has a pointlight or not
@export var EmitsLight = true
## Select Coin Type To Use
@export_enum("Yellow", "Big_Yellow", "Special_Coin") var coin_type: String = "Yellow"
##Size of coin
@export var coin_size: float = 1

@onready var coin_anim_sprite: AnimatedSprite2D = $Coins
@onready var coin_area2d: Area2D = $"."
@onready var point_light: PointLight2D = $PointLight

func _ready() -> void:
	# Visual setup happens for everyone locally
	if not EmitsLight:
		point_light.enabled = false
	
	if coin_size == 0:
		coin_size = 1
		print_rich("[color=yellow]Overrided Coin Size From 0 To 1")
	
	setup_visuals()

func setup_visuals():
	if coin_type == "Yellow":
		coin_area2d.scale = Vector2(coin_size, coin_size)
	elif coin_type == "Big_Yellow":
		var pl_scale = coin_size / 9.5 if coin_size <= 10 else coin_size / (coin_size * 2.0)
		point_light.scale = Vector2(pl_scale, pl_scale)
		var scal = coin_size * 1.5
		coin_area2d.scale = Vector2(scal, scal)
	elif coin_type == "Special_Coin":
		coin_anim_sprite.modulate = Color(0.0, 0.315, 0.355)
		coin_area2d.scale = Vector2(coin_size, coin_size)

func _on_body_entered(body):
	# 1. Only the Server/Host should decide if a coin is picked up
	if not multiplayer.is_server():
		return

	# 2. Check if the body is a Player
	if body.is_in_group("Player"):
		# Check if the player who touched it is the authority of that player node
		# (This ensures we know exactly who picked it up if needed)
		sync_collection.rpc()

## This function runs on EVERYONE'S machine when the server calls it
@rpc("any_peer", "call_local", "reliable")
func sync_collection():
	# Update Global variables 
	# Note: In a serious competitive game, Global variables should be synced 
	# via a MultiplayerSynchronizer, but this works for basic setups.
	Global.CoinCount += 1
	
	if coin_type == "Big_Yellow":
		Global.CoinBigCount += 1
	elif coin_type == "Special_Coin":
		Global.CoinSpecialCount += 1
	
	# Play SFX locally for every player
	var scene_root = get_owner()
	if scene_root:
		var coin_sfx_node = scene_root.get_node_or_null("Universal Scene/LV Audio/SFX/Coin SFX")
		if coin_sfx_node:
			coin_sfx_node.play()

	# Remove the coin from the game for everyone
	queue_free()
