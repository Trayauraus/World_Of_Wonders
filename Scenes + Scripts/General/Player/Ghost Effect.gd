extends Sprite2D

func _ready():
	# 1. OPTIONAL: Make it a single color (like Celeste's silhouette)
	#self.modulate = Color(0.428, 0.458, 0.68, 0.682) # Blue-ish tint
	self.modulate = Color(0.771, 0.504, 0.107, 0.761) # Blue-ish tint
	
	# 2. Create the fade animation
	var tween = create_tween()
	
	# Fade alpha to 0 over 0.5 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Delete this node when the tween finishes
	tween.tween_callback(queue_free)
