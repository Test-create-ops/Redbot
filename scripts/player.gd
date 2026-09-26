extends CharacterBody2D
class_name Player
## Il giocatore: piccolo, e non abbastanza forte.
##
## Il set di verbi e' deliberatamente minimo e tutto quello che si puo' fare
## e' rumore. Non c'e' un bottone d'attacco perche' nella fantasia del gioco
## non esiste: quello che puoi fare a una guardia e' spingerla un secondo e
## scappare, e basta.

signal died()

const SPEED := 250.0
const CROUCH_SPEED := 118.0
const ACCEL := 2200.0
const FRICTION := 2600.0
const DODGE_SPEED := 720.0
const DODGE_TIME := 0.26
const DODGE_COOLDOWN := 0.55
const SHOVE_RANGE := 62.0

var facing := Vector2.RIGHT
var crouching := false
var dodging := false
var invulnerable := false      # i-frame della schivata
var alive := true

var _dodge_t := 0.0
var _dodge_cd := 0.0
var _has_bolt := 0
var _hurt_flash := 0.0

@onready var _shape: CircleShape2D = $Body.shape
@onready var _radius: float = _shape.radius


func _ready() -> void:
	add_to_group("player")
	# Il giocatore deve poter leggere il movimento anche mentre il gioco e'
	# in pausa non e'-relevant, ma i guardiani devono poterlo ignorare a
	# runtime: e' `_physics_process` che fa la differenza.
	collision_layer = 2
	collision_mask = 1 | 4      # muri (1) + guardiani (4)


func _physics_process(dt: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	_dodge_cd = maxf(0.0, _dodge_cd - dt)
	_hurt_flash = maxf(0.0, _hurt_flash - dt)

	var want := _input_vector()
	crouching = Input.is_action_pressed("crouch") and not dodging

	if dodging:
		_dodge_t -= dt
		if _dodge_t <= 0.0:
			dodging = false
	else:
		velocity = velocity.move_toward(want, (ACCEL if want != Vector2.ZERO else FRICTION) * dt)

	if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0 and not dodging:
		dodging = true
		invulnerable = true
		_dodge_t = DODGE_TIME
		_dodge_cd = DODGE_COOLDOWN
		var dir := want if want != Vector2.ZERO else facing
		velocity = dir.normalized() * DODGE_SPEED
		facing = dir.normalized()

	if dodging and _dodge_t <= 0.0:
		invulnerable = false

	# accovacciato: piu' lento e profilo piu' basso
	var cap := CROUCH_SPEED if crouching else SPEED
	if velocity.length() > cap and not dodging:
		velocity = velocity.normalized() * cap
	_apply_visual_pose()

	move_and_slide()

	if Input.is_action_just_pressed("throw") and _has_bolt > 0:
		_has_bolt -= 1
		var world := get_parent() as Node
		if world != null and world.has_method("spawn_bolt"):
			world.spawn_bolt(global_position, facing)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()


func _input_vector() -> Vector2:
	var v := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() > 0.15:
		facing = v.normalized()
	return v


func _apply_visual_pose() -> void:
	if _shape == null:
		return
	# Accovacciato: il raggio dimezza, e con lui la superficie che le guardie
	# possono vedere. E' la rappresentazione fisica del rumore che fai.
	var r := _radius * (0.62 if crouching else 1.0)
	if not is_equal_approx(_shape.radius, r):
		_shape.radius = r
	queue_redraw()


func _try_interact() -> void:
	for d in get_tree().get_nodes_in_group("doors"):
		if d is Door and not d.open and d.global_position.distance_to(global_position) < 60.0:
			if d.try_open(self):
				return
	for b in get_tree().get_nodes_in_group("bolts"):
		if b is Node2D and global_position.distance_to((b as Node2D).global_position) < 54.0:
			b.queue_free()
			_has_bolt += 1
			return
	var world := get_parent() as Node
	if world != null and world.has_method("try_relic"):
		world.try_relic(global_position)


## Sta spingendo? Accovacciato e in movimento verso la guardia: e' l'unico
## "attacco" del gioco e non fa danno, fa solo perdere il filo.
func is_shoving() -> bool:
	return crouching and velocity.length() > 40.0


func shield_radius() -> float:
	return _shape.radius


func bolt_count() -> int:
	return _has_bolt


func add_bolt(n: int) -> void:
	_has_bolt += n


func is_invulnerable() -> bool:
	return invulnerable


func caught() -> void:
	if not alive or invulnerable:
		return
	alive = false
	died.emit()
