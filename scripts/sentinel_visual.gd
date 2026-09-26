class_name SentinelVisual extends Node2D
const SENTINEL_BODY := Color(0.36, 0.41, 0.50)
const SENTINEL_TOP := Color(0.45, 0.51, 0.62)
const SENTINEL_SH := Color(0.22, 0.26, 0.33)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(26, 34)), SENTINEL_BODY)
