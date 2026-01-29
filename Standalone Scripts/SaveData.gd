# SaveData.gd
class_name SaveData extends IndieBlueprintSavedGame

## Add every variable from Global.gd that you want to save.
## The @export tag makes them visible in the Inspector and ensures they get saved.
@export var current_lv: int = -1

@export var coin_count: int = 0
@export var coin_special_count: int = 0
@export var coin_big_count: int = 0

@export var total_time: float = 0.0
@export var death_count: int = 0
