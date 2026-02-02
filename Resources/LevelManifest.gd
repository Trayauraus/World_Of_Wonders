# File: LevelManifest.gd
extends Resource
class_name LevelManifest

## An array containing the file paths to all level scenes.
@export_file("*.tscn") var level_scenes: Array[String]
