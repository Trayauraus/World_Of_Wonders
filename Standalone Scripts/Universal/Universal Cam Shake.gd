extends Camera2D

@export var isShaking = false  # Max shake intensity
@export var randomStrength: float = 30.0  # Max shake intensity
@export var shakeFade: float = 0.1  # How fast the shake fades out
@export var shakeSpeed: float = 0.2  # How slow the shake moves
@export var mouseInfluence: float = 50.0  # How much the mouse affects the camera
@export var mouseFollowSpeed: float = 2.0  # How smoothly the camera follows the mouse


var rng = RandomNumberGenerator.new()
var shake_strength: float = 0.0
var time_passed: float = 0.0  # Time variable for smooth motion
var target_offset: Vector2 = Vector2.ZERO  # Target offset for smooth mouse movement

func apply_shake():
	shake_strength = randomStrength  # Apply shake once

func _process(delta):
	if shake_strength > 0:
		shake_strength = lerpf(shake_strength, 0, shakeFade * delta)  # Smooth fade-out
		time_passed += delta * shakeSpeed  # Slow movement update
		
	if isShaking:
		apply_shake()
	
	# Get mouse position relative to the center of the screen
	var viewport_center = get_viewport_rect().size / 2
	var mouse_position = get_viewport().get_mouse_position()
	var mouse_offset = (mouse_position - viewport_center) / viewport_center * mouseInfluence

	# Smoothly interpolate the camera toward the target mouse position
	target_offset = lerp(target_offset, mouse_offset, mouseFollowSpeed * delta)

	# Apply both shake AND mouse movement to the offset
	offset = randomOffset() + target_offset

func randomOffset() -> Vector2:
	# Use slow movement instead of instant jitter
	var slow_x = sin(time_passed * 2.0) * shake_strength
	var slow_y = cos(time_passed * 1.5) * shake_strength
	return Vector2(slow_x, slow_y)
