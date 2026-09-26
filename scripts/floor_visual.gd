class_name FloorVisual extends Node2D

const FLOOR_BASE := Color(0.086, 0.098, 0.133)
const FLOOR_GRID := Color(0.115, 0.137, 0.200)
const FLOOR_MAJOR := Color(0.145, 0.169, 0.251)
const FLOOR_LIT := Color(0.130, 0.150, 0.220)

var size: Vector2 = Vector2(1920, 1080)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FLOOR_BASE)
