class_name RelicVisual extends Node2D
const RELIC_BODY := Color(0.95, 0.78, 0.25)
const RELIC_HL := Color(1.0, 0.93, 0.56)

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2(0,-15),Vector2(10,0),Vector2(0,15),Vector2(-10,0)]), PackedColorArray([RELIC_BODY]))
