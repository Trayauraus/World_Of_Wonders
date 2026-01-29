extends Node2D

@onready var RayCastRight = $RayCastRight
@onready var RayCastLeft = $RayCastLeft
@onready var animated_sprite = $EnemySprite
@onready var enemy_light: PointLight2D = $EnemyLight

@export_enum("None", "LAVA", "DESERT", "ICE", "GRASSY") var super_tank_variant: String = "None"
@export var SPEED = 60.0
@export var emits_light: bool = true


var direction = 1
var playerdead = 1
var runonce = true

func _ready():
	if super_tank_variant == null or SPEED == null or emits_light == null:
		print_rich("[color=red]Slime: UNKNOWN ERROR.[color=/] ", self)
		return
	if SPEED <= 0:
		SPEED = 1
		print("Enemy Speed Cannot Be <= 0. Making 1")
	if not emits_light:
		enemy_light.enabled = false
	
	if super_tank_variant == "LAVA":
		animated_sprite.modulate = Color(1.0, 0.549, 0.067)
		SPEED = SPEED + 22.5
	elif super_tank_variant == "DESERT":
		animated_sprite.modulate = Color(0.551, 0.512, 0.0)
		SPEED = SPEED + 18.5
	elif super_tank_variant == "ICE":
		animated_sprite.modulate = Color(0.0, 0.559, 0.531)
		SPEED = SPEED - (2.5 / SPEED)
	elif super_tank_variant == "GRASSY":
		animated_sprite.modulate = Color(0.055, 0.682, 0.0)
		SPEED = SPEED + 10.0

func _physics_process(delta):
	if Global.is_dead == false:
		if RayCastRight.is_colliding():
			# Check if the colliding node is the player.
			if RayCastRight.get_collider().is_in_group("Player"):
				if runonce == true:
					print_rich("[color=sky_blue]ICE SLIME Collided With Player From Right Side.	")
					runonce = false
			elif RayCastRight.get_collider() is TileMapLayer:
				direction = -1
		
		if RayCastLeft.is_colliding():
			# Check if the colliding node is the player.
			if RayCastLeft.get_collider().is_in_group("Player"):
				if runonce == true:
					print_rich("[color=SKY_BLUE]ICE SLIME Collided With Player From Left Side")
					runonce = false
			elif RayCastLeft.get_collider() is TileMapLayer:
				direction = 1
	else:
		playerdead = 0
	
	position.x += direction * SPEED * delta * playerdead
	
	if direction > 0:
		animated_sprite.flip_h = false
		
	elif direction < 0:
		animated_sprite.flip_h = true


func enemy_area_entered(body: Node2D):
	if body.is_in_group("Player"):
		call_on_player_death()

func call_on_player_death():
	# Get the parent of the enemy (e.g., the "Enemies" node).
	var parent_node = get_parent()
	if parent_node:
		# From the parent, get the node with the UniversalLevel script.
		# The path is relative to the parent.
		var universal_level = parent_node.get_node_or_null("../Universal Scene")
		
		#Double Safety to ensure it finds the location
		if not universal_level:
			universal_level =  $"Universal Scene"
		if not universal_level:
			universal_level =  $"../.."
			
		if universal_level:
			# Call the function.
			#universal_level.on_player_death()
			universal_level._on_death_body_entered(self)
		else:
			print("Error: Could not find Universal Scene node.")
