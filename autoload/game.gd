extends Node
## Macchina a stati del gioco + roba che la certificazione Xbox pretende
## esista: pausa, sospensione, controller scollegato, salvataggio.
##
## Nota su `process_mode`: questo nodo gira SEMPRE, anche a gioco pausato,
## altrimenti non potrebbe ricevere il pulsante "pausa" per togliere la pausa.
## Per la stessa ragione `get_tree().paused` non blocca nulla qui dentro.

signal state_changed(from: State, to: State)

enum State { BOOT, MAIN_MENU, PLAYING, PAUSED, SETTINGS, CAUGHT, WON }

const OVERLAY_SAFE := 0.05   # 5% di margine: overscan delle TV

var state: State = State.BOOT
var world: World
var hud: CanvasItem
var _screen: Node
var _lost_pad_overlay: Control
var _prev_pads: Array[int] = []
var _resume_state: State = State.MAIN_MENU


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Game gestisce chiusura e sospensione e chiama SaveGame.flush() da li'.
	# Se anche SaveGame ascoltasse WM_CLOSE_REQUEST il quit partirebbe due
	# volte, e il secondo tentativo su un albero gia' distrutto e' un crash.
	get_tree().auto_accept_quit = false
	_prev_pads = Input.get_connected_joypads()
	_build_root()
	goto(State.MAIN_MENU)


func _build_root() -> void:
	world = World.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match state:
			State.PLAYING:
				goto(State.PAUSED)
			State.PAUSED, State.SETTINGS:
				goto(_resume_state)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart_encounter") and state == State.PLAYING:
		# Retry rapido dal checkpoint mentre si gioca, senza passare dal menu.
		world.restart_encounter()
		world.save_soon()
		SaveGame.flush()
		get_viewport().set_input_as_handled()


# ----------------------------------------------------------------- sospensione
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Sospendere NON e' uscire: non si deve perdere lo stato di gioco.
			# Salva e blocca, cosi' al ritorno l'istantanea non cala di
			# qualche decina di fotogrammi (una delle cose che la certificazione
			# segnala come freeze dopo ripresa).
			_on_suspend()
		NOTIFICATION_APPLICATION_RESUMED:
			_on_resume()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Anche "perso focus" su desktop vuol dire che il gioco non e'
			# piu' in primo piano: si salva lo stesso.
			_on_suspend()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			SaveGame.flush()
			Settings.save()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if state == State.PLAYING:
				goto(State.PAUSED)
			else:
				get_viewport().set_input_as_handled()


func _on_suspend() -> void:
	if state == State.PLAYING:
		world.save_soon()
	SaveGame.flush()
	Settings.save()
	# get_tree().paused non si mette qui: alla ripresa si risolve da soli e
	# bloccarlo qui lascerebbe il gioco fermo se la sospensione non si chiude.


func _on_resume() -> void:
	# Niente da ripristinare: il gioco era gia' in pausa, quindi l'istantanea
	# al ritorno e' gia' coerente. Si rimuove solo l'overlay di pad scollegato.
	_hide_pad_lost()


# ------------------------------------------------------------- controller
func _process(_dt: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.size() != _prev_pads.size():
		_prev_pads = pads
		if pads.is_empty() and state != State.MAIN_MENU:
			_show_pad_lost()
		elif not pads.is_empty():
			_hide_pad_lost()
			# Se era in pausa per il pad, torna a giocare: non lasciare il
			# giocatore bloccato da un menu che non ha piu' senso.
			if state == State.PAUSED and _resume_state == State.PLAYING:
				goto(State.PLAYING)


func _show_pad_lost() -> void:
	if _lost_pad_overlay != null:
		return
	if state == State.PLAYING:
		world.save_soon()
	SaveGame.flush()
	if state == State.PLAYING:
		_resume_state = State.PLAYING
		get_tree().paused = true
	var root := get_tree().root
	_lost_pad_overlay = Control.new()
	_lost_pad_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_lost_pad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lost_pad_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := CenterContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	var lbl := Label.new()
	lbl.text = L10n.t("PAD_COLLEGATO")
	panel.add_child(lbl)
	_lost_pad_overlay.add_child(panel)
	root.add_child.call_deferred(_lost_pad_overlay)


func _hide_pad_lost() -> void:
	if _lost_pad_overlay == null:
		return
	_lost_pad_overlay.queue_free()
	_lost_pad_overlay = null
	if state == State.PLAYING:
		get_tree().paused = false


# ------------------------------------------------------------------- stati
func goto(to: State) -> void:
	var from := state
	if from == State.PLAYING and to != State.PAUSED and to != State.SETTINGS:
		world.commit()
		SaveGame.flush()
	_clear_screen()
	# Il mondo si ferma, la UI no: i menu devono restare utilizzabili mentre
	# il gioco e' in pausa, altrimenti non si puo' neanche chiudere il menu.
	# Il menu principale invece NON pausa: non e' "il gioco in pausa", e
	# un albero fermo dentro cui girano solo schermi di menu surprises chiunque
	# ci metta dentro un nodo e si aspetti di vederlo girare.
	get_tree().paused = to != State.PLAYING and to != State.MAIN_MENU
	# "Indietro" dalle impostazioni torna sempre a donde si era arrivati. Senza
	# questo, aprire le impostazioni dal menu principale e poi premere
	# "Indietro" riportava a un menu che non esisteva piu', perche' la
	# memoria di partenza era rimasta quella del boot.
	if to == State.SETTINGS and from != State.SETTINGS:
		_resume_state = from
	state = to
	state_changed.emit(from, to)
	match to:
		State.MAIN_MENU:
			_screen = _mount(MainMenu.new())
		State.PAUSED:
			_screen = _mount(PauseMenu.new())
		State.SETTINGS:
			_screen = _mount(SettingsScreen.new())
		State.CAUGHT:
			_screen = _mount(CaughtScreen.new())
		State.WON:
			_screen = _mount(WonScreen.new())
		State.PLAYING:
			_screen = null


func _mount(c: Control) -> Control:
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	# Lo schermo non e' ancora nella scena, quindi non puo' misurare se
	# stesso. E la radice dell'albero e' una Window, che non e' un CanvasItem
	# e non ha get_viewport_rect(): la dimensione viene da DisplayServer, con
	# la risoluzione di progetto come ripiego per l'esecuzione headless.
	var safe := Ui.safe_area(c, OVERLAY_SAFE, _screen_size())
	safe.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(safe)
	return c


## Lo schermo attualmente montato, o null mentre si gioca. Serve alla QA per
## premere i veri bottoni del menu invece di ricostruire la schermata a mano:
## un bottone ricostruito non e' quello che il giocatore preme.
func current_screen() -> Control:
	return _screen if is_instance_valid(_screen) else null


## Torna indietro di uno schermo. Usare questo invece di `goto(_resume_state)`
## sposta il rimando: se si entra nelle impostazioni da due posti diversi, il
## ritorno va a entrambi correttamente senza che nessuno ricordi di
## aggiornare la memoria a mano.
func back() -> void:
	goto(_resume_state if _resume_state != State.SETTINGS else State.MAIN_MENU)


func _screen_size() -> Vector2:
	var s: Vector2i = DisplayServer.window_get_size()
	if s.x > 0 and s.y > 0:
		return Vector2(s)
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))


func _clear_screen() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
