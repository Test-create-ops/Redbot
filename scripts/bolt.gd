extends Node2D
class_name Bolt
## Un vitone. Non fa male a nessuno: e' un rumore che si puo' lanciare.
##
## Serve a una cosa sola, e la cosa e' importante per il design: permette di
## spostare una guardia *senza* essere visto. Il giocatore non vince nessuno
## scontro, sceglie dove farlo succedere.

enum Kind { PICKUP, THROWN }

const SPEED := 430.0
const FRICTION := 0.72
const LIFETIME := 7.0
const RESTITUTION := 0.62

var kind: Kind = Kind.PICKUP
var velocity := Vector2.ZERO

var _t := 0.0
var _walls: Array = []
var _noisy := false


static func make_pickup(pos: Vector2) -> Bolt:
	var b := Bolt.new()
	b.kind = Kind.PICKUP
	b.position = pos
	return b


static func make_thrown(pos: Vector2, dir: Vector2) -> Bolt:
	var b := Bolt.new()
	b.kind = Kind.THROWN
	b.position = pos
	b.velocity = dir.normalized() * SPEED
	return b


func _ready() -> void:
	z_index = 5
	# Solo i vitoni a terra si raccolgono: un vitone lanciato non deve
	# diventare subito raccoglibile dalla stessa mano che l'ha lanciato.
	if kind == Kind.PICKUP:
		add_to_group("bolts")
	var w := get_parent()
	if w != null and w.has_method("wall_rects"):
		_walls = w.wall_rects()


func _physics_process(dt: float) -> void:
	if kind == Kind.PICKUP:
		return

	_t += dt
	if _t > LIFETIME:
		queue_free()
		return

	velocity *= pow(FRICTION, dt * 60.0)
	if velocity.length() < 12.0:
		velocity = Vector2.ZERO
		return

	var step := velocity * dt
	# Collisione geometrica sui rectangoli dei muri: gli stessi rettangoli
	# usati dalla linea di vista, quindi il rimbalzo e' dove vedi il muro.
	# Con piu' muri sovrapposti si testa il passo piu' corto per non
	# attraversarne due in un solo frame.
	for r in _walls:
		var rect: Rect2 = r
		if not rect.has_point(global_position):
			continue
		var seg := Rect2(
			rect.position, rect.size).intersection(
			Rect2(global_position, step + Vector2.ONE))
		if seg.size == Vector2.ZERO:
			continue
		_resolve(rect)
		_noise()
		break


## Se il centro e' dentro un muro, si sposta fuori dal lato piu' vicino e si
## riflette la velocione su quell'asse.
func _resolve(r: Rect2) -> void:
	var l := global_position.x - r.position.x
	var rr := r.end.x - global_position.x
	var t := global_position.y - r.position.y
	var b := r.end.y - global_position.y
	var m: float = minf(minf(l, rr), minf(t, b))
	if is_equal_approx(m, l):
		global_position.x = r.position.x
		velocity.x = -velocity.x * RESTITUTION
	elif is_equal_approx(m, rr):
		global_position.x = r.end.x
		velocity.x = -velocity.x * RESTITUTION
	elif is_equal_approx(m, t):
		global_position.y = r.position.y
		velocity.y = -velocity.y * RESTITUTION
	else:
		global_position.y = r.end.y
		velocity.y = -velocity.y * RESTITUTION


## Il rumore parte al primo rimbalzo e non subito al lancio: un gioco in cui
## il rumore parte al lancio punisce il giocatore che ha appena schivato.
func _noise() -> void:
	if _noisy:
		return
	_noisy = true
	var w := get_parent()
	if w != null and w.has_method("on_noise"):
		w.on_noise(global_position, 640.0)


func _draw() -> void:
	if kind == Kind.PICKUP:
		draw_circle(Vector2.ZERO, 7.0, Color(0.75, 0.8, 0.88))
		draw_circle(Vector2.ZERO, 3.0, Color(1, 0.95, 0.7))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(0.8, 0.85, 0.9))
		draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1))
