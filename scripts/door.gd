extends StaticBody2D
class_name Door
## Una porta chiusa che blocca il passaggio.
##
## Serve una chiave per aprirla. Senza chiave non si puo' passare:
## il giocatore deve cercarla, rompendo il loop "muovi e ciao".

signal opened(door: Door)

var locked: bool = true
var open := false
var pos: Vector2
var size: Vector2


func setup(pos_: Vector2, size_: Vector2, wall_rects: Array) -> void:
	pos = pos_
	size = size_
	collision_layer = 1
	collision_mask = 0
	add_to_group("doors")
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = size * 0.5
	add_child(cs)
	queue_redraw()


func _draw() -> void:
	if open:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.10, 0.12, 0.16))
		draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), Color(0.16, 0.18, 0.22))
	else:
		var c := Color(0.55, 0.60, 0.68) if locked else Color(0.16, 0.18, 0.22)
		draw_rect(Rect2(0, 0, size.x, size.y), c)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color(0.08, 0.09, 0.12))
		if locked:
			draw_rect(Rect2(size.x * 0.65, size.y * 0.6, size.x * 0.3, size.y * 0.2), Color(0.55, 0.60, 0.68))
			draw_rect(Rect2(size.x * 0.75, size.y * 0.45, size.x * 0.1, size.y * 0.1), Color(0.55, 0.60, 0.68))


func try_open(p: Player) -> bool:
	if open or not locked:
		return false
	if p.bolt_count() < 1:
		return false
	p.add_bolt(-1)
	open = true
	collision_layer = 0
	queue_redraw()
	opened.emit(self)
	return true
