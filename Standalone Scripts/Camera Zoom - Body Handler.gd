extends Node2D


func _on_zoom_cam_1_5_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_call_zoom_func(1.5)


func _on_zoom_cam_2_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_call_zoom_func(2.0)

func _call_zoom_func(zoomval: float):
	if $"Universal Scene":
		$"Universal Scene"._zoom_player_camera(zoomval)
		
