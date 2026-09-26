extends CharacterBody2D
class_name Guardian

const Art = preload("res://scripts/art.gd")
## Una guardia. Non ti insegue perche' ti odia: ti insegue perche' ti ha
## visto. Tutta la sua intelligenza e' una linea di vista, una memoria
## dell'ultima posizione nota, e un metro di allarme che si riempie.
##
## La guardia non e' nemica: quando ti prende non ti fa del male, ti mette
## fuori. E' una pattuglia, non un cacciatore.

signal caught_player()
signal spotted_player()

enum Mode { PATROL, SUSPICIOUS, ALERTED, STAGGERED }

const ALERT_DECAY := 0.55          # quanto scende il metro al secondo
const ALERT_RISE_MIN := 0.9
const LOSE_MEMORY := 2.6           # secondi di vista persa prima di dimenticare
const STAGGER_TIME := 0.85
const TURN_SPEED := 260.0

var mode: Mode = Mode.PATROL
var detect := 0.0
var facing := 0.0                  # gradi, 0 = +X
var patrol: Array[Vector2] = []
var view_range := 420.0
var half_angle := 36.0
var near_radius := 70.0
var catch_radius := 54.0
var speed := 50.0

var _walls: Array = []
var _shadows: Array = []
# Riferimento esplicito al giocatore. Non si usa il gruppo "player": con due
# mondi in scena (per esempio durante la QA) `get_first_node_in_group`
# restituirebbe il giocatore sbagliato e nessuno se ne accorgerebbe.
var target: Node2D
var show_cone := true

var _leg := 0
var _last_known := Vector2.ZERO
var _lost_t := 0.0
var _stagger_t := 0.0
var _sees_now := false
var _cone: Line2D
var _cone_fill: Polygon2D


## `spec` e' il dizionario di UNA guardia (pos, patrol, range...), non il
## livello: i dati della guardia sono annidati dentro il livello e passare
## l'intero dizionario faceva fallire l'accesso a "patrol" su un tipo sbagliato.
func setup(spec: Dictionary, walls: Array, shadows: Array) -> void:
	position = spec["pos"]
	speed = spec["speed"]
	view_range = spec["range"]
	half_angle = spec["half_angle"]
	near_radius = spec["near_radius"]
	catch_radius = spec["catch_radius"]
	_walls = walls
	_shadows = shadows
	# Il JSON restituisce un Array non tipizzato: assegnarlo direttamente a
	# una Array[Vector2] fallisce in silenzio e la guardia resta ferma per
	# sempre. Si copia elemento per elemento.
	patrol.clear()
	for p in spec["patrol"]:
		patrol.append(p)


func _ready() -> void:
	add_to_group("guardians")
	collision_layer = 4
	collision_mask = 1
	var v := Art.draw_sentinel()
	add_child(v)
	_cone = Line2D.new()
	_cone.width = 2.0
	_cone.default_color = Color(1.0, 0.85, 0.3, 0.35)
	add_child(_cone)
	_cone_fill = Polygon2D.new()
	_cone_fill.name = "ConeFill"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cone_fill.material = mat
	add_child(_cone_fill)
	queue_redraw()


func _physics_process(dt: float) -> void:
	if _stagger_t > 0.0:
		_stagger_t -= dt
		velocity = Vector2.ZERO
		if _stagger_t <= 0.0:
			_back_to_patrol()
		_draw_cone()
		return

	var player := target
	_sees_now = false
	if player != null:
		var eye := global_position
		var res := LOS.check(eye, facing, half_angle, view_range,
				player.global_position, near_radius, _walls, _shadows)
		_sees_now = res["seen"]
		if _sees_now:
			_last_known = player.global_position
			_lost_t = 0.0
			detect = minf(1.0, detect + LOS.detection_rate(res, view_range, _is_hidden(player)) * dt)
		else:
			_lost_t += dt
			detect = maxf(0.0, detect - ALERT_DECAY * dt)

	match mode:
		Mode.PATROL:
			if detect >= 1.0:
				_enter(Mode.ALERTED)
				spotted_player.emit()
			elif detect > 0.25:
				_enter(Mode.SUSPICIOUS)
			_patrol(dt)
		Mode.SUSPICIOUS:
			_face_last_known(dt)
			if detect >= 1.0:
				_enter(Mode.ALERTED)
				spotted_player.emit()
			elif detect <= 0.02:
				_back_to_patrol()
		Mode.ALERTED:
			_chase(dt)
			if _lost_t > LOSE_MEMORY:
				_enter(Mode.SUSPICIOUS)
				detect = 0.35

	_draw_cone()
	_check_catch(player)


func _is_hidden(p: Node) -> bool:
	return p is Player and (p as Player).crouching


func _enter(m: Mode) -> void:
	mode = m


func _back_to_patrol() -> void:
	detect = 0.0
	_lost_t = 0.0
	_leg = 0
	_enter(Mode.PATROL)


func _patrol(dt: float) -> void:
	if patrol.size() < 2:
		return
	# `wp` e non `target`: `target` e' il giocatore, un membro della classe.
	var wp: Vector2 = patrol[_leg]
	if global_position.distance_to(wp) < 18.0:
		_leg = (_leg + 1) % patrol.size()
		wp = patrol[_leg]
	_step(dt, wp, speed * 0.8)


func _face_last_known(dt: float) -> void:
	var d := _last_known - global_position
	if d.length() > 4.0:
		_turn_toward(rad_to_deg(atan2(d.y, d.x)), dt)


func _chase(dt: float) -> void:
	_step(dt, _last_known, speed * 1.55)


func _step(dt: float, goal: Vector2, spd: float) -> void:
	# `goal` e non `target`: `target` e' il membro che punta al giocatore, e
	# dentro questa funzione il nome del parametro lo nasconderebbe. Con
	# `target` la guardia inseguiva il giocatore invece della destinazione,
	# quindi la pattuglia non partiva mai.
	var d := goal - global_position
	if d.length() < 1.0:
		velocity = Vector2.ZERO
		return
	var dir := d.normalized()
	_turn_toward(rad_to_deg(atan2(dir.y, dir.x)), dt)
	velocity = dir * spd
	# I muri hanno collider veri (creati dal level builder) e `move_and_slide`
	# fa scivolare la guardia lungo il muro invece di incastrarci. Nessuna
	# logica manuale: la stessa geometria e' usata dalla linea di vista, quindi
	# quello che vedi e' quello che ti colpisce.
	move_and_slide()


func _turn_toward(target_deg: float, dt: float) -> void:
	var diff := LOS.angle_delta(target_deg, facing)
	facing = facing + clampf(diff, -TURN_SPEED * dt, TURN_SPEED * dt)


func _draw_cone() -> void:
	if _cone == null:
		return
	_cone.visible = show_cone and mode != Mode.STAGGERED
	if not _cone.visible:
		if _cone.points.size() > 0:
			_cone.points = PackedVector2Array()
		return
	var pts := PackedVector2Array()
	var steps := 22
	var a0 := deg_to_rad(facing - half_angle)
	var a1 := deg_to_rad(facing + half_angle)
	for i in steps + 1:
		var a: float = lerp(a0, a1, float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * view_range)
	# arco e rientro: e' un cono, non un raggio
	for i in range(pts.size() - 1, -1, -1):
		pts.append(pts[i] * 0.02)
	# Line2D non ha add_points(): si assegna l'intero array.
	_cone.points = pts
	_cone.closed = true
	# L'opacita' segue il riempimento del metro: il giocatore vede da
	# quanto e' vicino a farsi beccare senza dover leggere una barra.
	_cone.default_color = Color(1.0, 0.85, 0.3, 0.10 + 0.22 * detect)
	_cone_fill.polygon = pts
	_cone_fill.color = Color(1.0, 0.85, 0.3, 0.10 + 0.22 * detect)
	_cone_fill.visible = _cone.visible



func _check_catch(player: Node2D) -> void:
	if player == null or _stagger_t > 0.0:
		return
	var d := global_position.distance_to(player.global_position)
	if d > catch_radius:
		return
	var p := player as Player
	if p == null:
		return
	# spinta: accovacciato e addosso. Non e' un attacco, e' un urto di
	# corpi, e ti costa il fattore come tutto il resto.
	if p.is_shoving():
		_stagger_t = STAGGER_TIME
		_enter(Mode.STAGGERED)
		detect = maxf(detect, 0.55)
		return
	if p.is_invulnerable():
		return
	caught_player.emit()


## Un rumore non significa "mi hai visto". Significa "vado a guardare li'".
## Il metro di allarme sale, ma la guardia non spara e non ti insegue
## all'istante: va a verificare. E' la differenza fra un gioco di stealth
## e un gioco di punizione.
func hear(pos: Vector2, radius: float) -> void:
	if _stagger_t > 0.0:
		return
	if global_position.distance_to(pos) > radius:
		return
	_last_known = pos
	_lost_t = 0.0
	detect = maxf(detect, 0.30)
	if mode == Mode.PATROL:
		_enter(Mode.SUSPICIOUS)


## Azzera la memoria della guardia. Serve al riavvio dell'incontro: dopo un
## retry la guardia deve ripartire dalla sua postazione e non ricordare dove
## ti aveva visto un secondo prima, altrimenti il "riprova" e' una punizione.
func reset_memory() -> void:
	detect = 0.0
	_lost_t = 0.0
	_leg = 0
	_sees_now = false
	_stagger_t = 0.0
	if not patrol.is_empty():
		facing = rad_to_deg(atan2(
			(patrol[1] - patrol[0]).y, (patrol[1] - patrol[0]).x))


func alert_level() -> float:
	return detect


func is_seeing() -> bool:
	return _sees_now
