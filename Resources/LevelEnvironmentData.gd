class_name LevelEnvironmentData
extends Resource

@export_group("Colors")
## The standard background/ambient color
@export var ambient_color: Color = Color.WHITE
## The color used when the player enters a cave area
@export var cave_color: Color = Color("262321")
## Color applied to wind particles
@export var wind_color: Color = Color.WHITE

@export_group("Environment Resources")
## The standard WorldEnvironment resource (.tres)
@export var world_env_normal: Environment
## The darkened WorldEnvironment resource for caves (.tres)
@export var world_env_cave: Environment
## The ParticleProcessMaterial for the ash/snow particles
@export var gpu_particles_material: ParticleProcessMaterial

@export_group("Lighting Scenes")
## The main DirectionalLight2D scene (.tscn)
@export var dir_light_normal: PackedScene
## The DirectionalLight2D scene used in caves (.tscn)
@export var dir_light_cave: PackedScene
