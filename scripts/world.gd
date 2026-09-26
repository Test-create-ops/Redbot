extends Node2D
class_name World

const Art = preload("res://scripts/art.gd")
## Radice del gioco: costruisce il livello dai dati, tiene lo stato della
## partita e parla con Game per i cambi di schermata.
##
## Nota: Game crea questo nodo e lo chiama `world`, quindi i menu raggiungono
## i suoi metodi (restart_encounter, save_soon, commit) senza cercarlo a mano.

const WALL_COLOR := Color(0.16, 0.18, 0.22)
const SHADOW_COLOR := Color(0.05, 0.06, 0.10, 0.72)
const FLOOR_COLOR := Color(0.10, 0.11, 0.14)

var level: Dictionary = {}
var player: Player
var hud: Hud

var _walls_node: Node2D
var _shadows_node: Node2D
var _guardians: Array[Guardian] = []
var _doors: Array[Door] = []
var _keys: Array[Node2D] = []
var _relic: Node2D
var _relic_visual
var _checkpoint := Vector2.ZERO
var _checkpoint_i := 0
var _collected := false
var _finished := false


func _ready() -> void:
	load_level(SaveGame.data().get("level", "level_01"))


# ------------------------------------------------------------------- costruzione
func load_level(id: String) -> void:
	for c in get_children():
		c.queue_free()
	_guardians.clear()
	player = null
	_collected = false
	_finished = false

	level = Level.load_id(id)
	if level.is_empty():
		push_error("World: livello non caricabile: " + id)
		return
	if not (level["errors"] as Array).is_empty():
		for e in level["errors"]:
			push_error("World: %s" % e)

	var size: Vector2 = level["size"]

	add_child(Art.build_floor(size))
	add_child(Art.build_walls(level["walls"], level["shadows"]))

	for g in level["guardians"]:
		var gu := Guardian.new()
		gu.setup(g, level["walls"], level["shadows"])
		gu.show_cone = bool(Settings.value("show_vision_cones", true))
		gu.caught_player.connect(_on_caught)
		add_child(gu)
		_guardians.append(gu)

	_relic = Node2D.new()
	_relic.name = "Relic"
	_relic.position = level["relic"]
	add_child(_relic)
	_relic_visual = Art.draw_relic()
	_relic_visual.name = "Visual"
	_relic.add_child(_relic_visual)
	_redraw_relic()

	for p in level["bolts"]:
		_spawn_bolt_node(p)

	for d in level.get("doors", []):
		_spawn_door(d)
	for k in level.get("keys", []):
		_spawn_key(k)

	player = Player.new()
	player.name = "Player"
	player.position = level["player_start"]
	player.died.connect(_on_caught)
	player.add_child(_player_visual())
	var pshape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 16.0
	pshape.shape = circ
	pshape.name = "Body"
	player.add_child(pshape)
	add_child(player)
	# Le guardie devono guardare QUESTO giocatore, non "un" giocatore trovato
	# per gruppo: con piu' mondi in scena la ricerca globale e' ambigua.
	for gu in _guardians:
		gu.target = player

	var cps := Node2D.new()
	cps.name = "Checkpoints"
	add_child(cps)
	for i in level["checkpoints"].size():
		var c: Node2D = Node2D.new()
		c.position = level["checkpoints"][i]
		c.set_meta("i", i)
		cps.add_child(c)
	_checkpoint = level["checkpoints"][0]
	_checkpoint_i = 0

	hud = Hud.new()
	add_child(hud)
	hud.level_started(self, level)


func _quad(r: Rect2, col: Color, additive: bool) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y)])
	p.color = col
	return p


func _collider(r: Rect2) -> StaticBody2D:
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = r.position + r.size * 0.5
	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	cs.shape = box
	sb.add_child(cs)
	return sb


func _player_visual() -> Node2D:
	return Art.draw_robot()


func _redraw_relic() -> void:
	if _relic_visual == null:
		return
	_relic_visual.set("collected", _collected)
	_relic_visual.queue_redraw()


# ------------------------------------------------------------------ azioni
func wall_rects() -> Array:
	return level.get("walls", [])


func guardians() -> Array[Guardian]:
	return _guardians


func spawn_bolt(pos: Vector2, dir: Vector2) -> void:
	var b := Bolt.make_thrown(pos, dir)
	add_child(b)


## Un rumore non e' "il giocatore e' stato visto": e' un punto da cui le
## guardie possono andare a guardare. Questa distinzione e' tutto il gioco.
func on_noise(pos: Vector2, radius: float) -> void:
	if hud:
		hud.toast(L10n.t("TOAST_NOISE"))
	for gu in _guardians:
		gu.hear(pos, radius)


func _spawn_bolt_node(pos: Vector2) -> void:
	add_child(Bolt.make_pickup(pos))


func _spawn_door(rect: Rect2) -> void:
	var d := Door.new()
	d.name = "Door"
	d.setup(rect.position, rect.size, level["walls"])
	d.opened.connect(_on_door_opened)
	add_child(d)
	_doors.append(d)


func _spawn_key(pos: Vector2) -> void:
	var k := Node2D.new()
	k.name = "Key"
	k.position = pos
	var sp := Sprite2D.new()
	sp.texture = preload("res://icon.svg")
	sp.scale = Vector2(0.5, 0.5)
	k.add_child(sp)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 14.0
	cs.shape = circ
	k.add_child(cs)
	k.connect("body_entered", _on_key_touched)
	add_child(k)
	_keys.append(k)


func _on_door_opened(_door: Door) -> void:
	if hud:
		hud.toast("Porta aperta")


func _on_key_touched(_body: Node2D) -> void:
	if player and _body is Node2D and _body.global_position.distance_to(player.global_position) < 60.0:
		player.add_bolt(1)
		if hud:
			hud.toast("Chiave trovata")
		_body.queue_free()


func _process(_dt: float) -> void:
	_update_checkpoint()
	_update_cones()


## Tieni premuto "osserva" (RB) e i coni di vista appaiono. Non e' un
## debug: e' l'informazione che un giocatore di stealth chiede al gioco per
## decidere cosa fare. Il cono e' la promessa di un nemico e, insieme al
## rumore, la sua risposta deve essere leggibile. Di default e' gia' visibile
## perche' e' la versione onesta del gioco: un giocatore non deve fare
## screenshot per capire se e' visto.
func _update_cones() -> void:
	var want := bool(Settings.value("show_vision_cones", true)) or Input.is_action_pressed("observe")
	for gu in _guardians:
		gu.show_cone = want


func _update_checkpoint() -> void:
	if player == null:
		return
	var cps: Array = level.get("checkpoints", [])
	for i in cps.size():
		if player.global_position.distance_to(cps[i]) < 60.0 and i > _checkpoint_i:
			_checkpoint_i = i
			_checkpoint = cps[i]
			if hud:
				hud.toast(L10n.t("TOAST_CHECKPOINT"))


func try_relic(pos: Vector2) -> void:
	if _collected or _relic == null:
		return
	if pos.distance_to(_relic.global_position) > 70.0:
		return
	_collected = true
	_redraw_relic()
	_finished = true
	SaveGame.set_value("finished", true)
	SaveGame.flush()
	Game.goto(Game.State.WON)


func _on_caught() -> void:
	if _finished:
		return
	Game.goto(Game.State.CAUGHT)


func restart_encounter() -> void:
	# Riavvia dal checkpoint, non dal livello intero: la ripetizione deve
	# essere rapida, altrimenti si smette di giocare.
	# Il giocatore torna SEMPRE al checkpoint corrente, anche al primo: con
	# la condizione "> 0" il retry dal checkpoint iniziale non muoveva il
	# personaggio e lo lasciava dove lo avevano preso.
	if _checkpoint_i >= 0 and _checkpoint_i < level["checkpoints"].size():
		player.global_position = level["checkpoints"][_checkpoint_i]
	for gu in _guardians:
		gu.mode = Guardian.Mode.PATROL
		gu.detect = 0.0
		gu.reset_memory()
		gu.global_position = gu.patrol[0] if not gu.patrol.is_empty() else gu.global_position
	_collected = false
	_redraw_relic()
	_finished = false


func save_soon() -> void:
	SaveGame.set_value("level", level.get("id", "level_01"))
	SaveGame.set_value("checkpoint", _checkpoint_i)


func commit() -> void:
	save_soon()
	SaveGame.flush()
