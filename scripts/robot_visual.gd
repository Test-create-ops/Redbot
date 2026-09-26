class_name RobotVisual extends Node2D
const ROBOT_BODY := Color(0.79, 0.57, 0.19)
const ROBOT_HL := Color(0.93, 0.77, 0.36)
const ROBOT_SH := Color(0.47, 0.34, 0.11)
const ROBOT_EYE_HIDE := Color(0.45, 0.72, 0.96)
const ROBOT_EYE_RISK := Color(0.94, 0.80, 0.30)
const ROBOT_EYE_FLASH := Color(0.98, 0.96, 0.90)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8, ROBOT_BODY)
