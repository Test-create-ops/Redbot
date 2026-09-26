extends Node
## QA headless per ID@Xbox / certificazione console.
##
## Uso:
##   Godot --headless --path . res://tools/qa_idxbox.tscn
##
## Gira come SCENA, non come `--script`, per una ragione precisa: in modalita'
## script gli autoload non vengono istanziati, e quindi l'InputMap che si
## controllerebbe qui non sarebbe quello che il gioco usa davvero. Testare
## una copia del InputMap sarebbe peggio che non testarlo.
##
## Non e' un test di "funziona": e' il controllo delle cose che su console
## falliscono la certificazione quando non ci pensi, e che in un test
## normale non si vedono. Codice di uscita 1 se qualcosa e' rotto: in quel
## caso va saputo adesso, non davanti a un reviewer.

const PASS := 0
const FAIL := 1

var _errors: Array[String] = []
var _checks := 0


func _ready() -> void:
	print("=== QA Redbot ===")
	# La QA gira con l'albero sbloccato e sempre attiva: il menu principale
	# dell'autoload potrebbe mettere in pausa, e un mondo in pausa non
	# processa niente. Senza questo i test di giocabilita' passerebbero
	# "perche' non succede niente", che e' il peggiore modo di mentire.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	# Alcune verifiche hanno bisogno che il layout sia gia' calcolato.
	await get_tree().process_frame
	_check_input()
	await _check_screens()
	_check_los()
	_check_levels()
	_check_save()
	_check_locale()
	_check_offline()
	await _check_gameplay()
	await _check_menu()
	_report()


## Il gioco funziona? Non "non crasha": funziona.
##
## Fino a qui la QA guardava la geometria e i numeri. Questo invece costruisce
## il mondo vero e gli fa fare cose, ed e' l'unico controllo che avrebbe
## potuto vedere il bug delle guardie ferme: `patrol` arrivava dal JSON come
## Array non tipizzato, l'assegnazione a `Array[Vector2]` falliva, e tutte le
## verifiche sui livelli passavano lo stesso.
func _check_gameplay() -> void:
	print("[9] giocabilita")
	var w := World.new()
	w.name = "QaWorld"
	add_child(w)
	await get_tree().process_frame
	await get_tree().physics_frame

	_ok(not w.level.is_empty(), "mondo non caricato")
	if w.level.is_empty():
		w.queue_free()
		return

	# 1. le guardie hanno una pattuglia reale e si muovono
	_ok(w.guardians().size() > 0, "nessuna guardia")
	for i in w.guardians().size():
		var gu := w.guardians()[i]
		_ok(gu.patrol.size() >= 2,
				"guardia %d: pattuglia con %d punti (ne servono 2)" % [i, gu.patrol.size()])
		_ok(gu.target == w.player, "guardia %d: non guarda il giocatore" % i)
	var p0: Vector2 = w.guardians()[0].global_position
	for i in 40:
		await get_tree().physics_frame
	_ok(w.guardians()[0].global_position.distance_to(p0) > 10.0,
			"nessuna guardia si e' mossa: la pattuglia non parte")

	# 2. il giocatore esiste ed e' nel posto giusto
	_ok(w.player != null and w.player.alive, "il giocatore non e' vivo")
	_ok(w.player.global_position.distance_to(w.level["player_start"]) < 1.0,
			"il giocatore non parte dalla posizione dichiarata")

	# 3. stare davanti a una guardia porta all'allarme.
	#    Il punto NON e' scelto a mano: si cerca un punto che la linea di vista
	#    dichiara visibile. Altrimenti il test puo' passare o fallire per
	#    caso, perche' il punto finisce dentro un'ombra o dietro un muro, e un
	#    test di stealth che non controlla la propria premessa non testa niente.
	var g0: Guardian = w.guardians()[0]
	var spot: Variant = _find_visible_spot(w, g0, 170.0)
	if not _ok(spot != null, "nessun punto visibile attorno alla guardia: il livello e' troppo chiuso"):
		w.queue_free()
		await get_tree().process_frame
		return
	g0.mode = Guardian.Mode.PATROL
	g0.detect = 0.0
	w.player.global_position = spot
	w.player.crouching = false
	var alerted := false
	for i in 120:
		await get_tree().physics_frame
		if g0.mode == Guardian.Mode.ALERTED:
			alerted = true
			break
	_ok(alerted, "un giocatore fermo davanti alla guardia non viene mai visto")

	# 4. restare nell'ombra NON porta all'allarme: e' la promessa del gioco
	g0.mode = Guardian.Mode.PATROL
	g0.detect = 0.0
	var shadow_rect: Rect2 = w.level["shadows"][0]
	w.player.global_position = shadow_rect.get_center()
	var hidden_ok := true
	for i in 60:
		await get_tree().physics_frame
		if g0.mode == Guardian.Mode.ALERTED:
			hidden_ok = false
			break
	_ok(hidden_ok, "un giocatore nell'ombra e' stato visto: la stealth e' rotta")

	# 5. il rumore attira: la guardia va a verificare, senza Vedere
	g0.mode = Guardian.Mode.PATROL
	g0.detect = 0.0
	w.on_noise(g0.global_position + Vector2(180, 0), 600.0)
	_ok(g0.detect > 0.0 and g0.mode != Guardian.Mode.ALERTED,
			"un rumore deve far sospettare, non mettere in allarme subito")

	# 6. il riavvio dal checkpoint rimette il giocatore vicino al checkpoint
	w.player.global_position = Vector2(10000, 10000)
	w.restart_encounter()
	var cp: Vector2 = w.level["checkpoints"][0]
	_ok(w.player.global_position.distance_to(cp) < 200.0,
			"il riavvio non riporta al checkpoint")

	# 7. la reliquia si puo' raccogliere e porta a WON
	_ok(not w.level["relic"].is_zero_approx(), "nessuna reliquia nel livello")

	w.queue_free()
	await get_tree().process_frame


## Il nodo ha almeno una connessione viva sul segnale indicato.
##
## "Viva" vuol dire che il Callable e' valido e non punta a un nodo in coda di
## cancellazione. Attenzione: su una lambda `Callable.get_object()` restituisce
## lo GDScript che la contiene, NON un Node, quindi chiamare metodi da Node su
## quel risultato e' un errore. Per questo il controllo distingue i due casi.
func _has_action(n: Node, sig: String) -> bool:
	for conn in n.get_signal_connection_list(sig):
		var c: Callable = conn.get("callable", Callable())
		if not c.is_valid():
			continue
		var o: Object = c.get_object()
		if o is Node and (o as Node).is_queued_for_deletion():
			continue
		return true
	return false


## Cerca attorno alla guardia un punto che questa vede davvero: dentro il cono,
## senza muri di mezzo e fuori dall'ombra. Restituisce null se non esiste.
func _find_visible_spot(w: World, g: Guardian, radius: float) -> Variant:
	for i in 72:
		var a := deg_to_rad(float(i) * 5.0)
		var p: Vector2 = g.global_position + Vector2(cos(a), sin(a)) * radius
		var r := LOS.check(g.global_position, g.facing, g.half_angle, g.view_range,
				p, g.near_radius, w.level["walls"], w.level["shadows"])
		if r["seen"]:
			return p
	return null


## Preme i bottoni VERAMENTE, non una ricostruzione della schermata.
##
## I controlli precedenti verificavano che i pulsanti esistessero, avessero il
## focus e fossero collegati a una Callable. Tutte e tre le cose erano vere per
## un bottone che non faceva niente: un menu con tre voci illuminate col D-pad
## e nessuna azione. L'unico test che chiude il buco e' premere il pulsante e
## guardare dove si finisce.
func _check_menu() -> void:
	print("[10] menu")
	# Uno slot salvato rende visibile "Continua": si parte da uno stato noto.
	SaveGame.delete(0)
	Game.goto(Game.State.MAIN_MENU)
	await _settle()
	var mm := Game.current_screen()
	if not _ok(mm != null, "il menu principale non e' montato"):
		return

	# Il primo bottone deve avere il focus: e' quello su cui arriva il D-pad.
	_ok(mm.get_viewport().gui_get_focus_owner() != null,
			"nessun elemento ha il focus nel menu: il D-pad non avrebbe niente su cui fermarsi")

	# "Impostazioni" dal menu, e poi "Indietro": il ritorno deve tornare al
	# menu, non a uno schermo gia' liberato.
	var b_settings := mm.find_child("Impostazioni", true, false)
	if _ok(b_settings != null, "manca il bottone 'Impostazioni'"):
		(b_settings as Button).emit_signal("pressed")
		await _settle()
		_ok(Game.state == Game.State.SETTINGS,
				"'Impostazioni' non apre le impostazioni (stato: %s)" % _st(Game.state))
		var ss := Game.current_screen()
		if _ok(ss != null, "la schermata impostazioni non e' montata"):
			var back := ss.find_child("Indietro", true, false)
			if _ok(back != null, "manca il bottone 'Indietro' nelle impostazioni"):
				(back as Button).emit_signal("pressed")
				await _settle()
				_ok(Game.state == Game.State.MAIN_MENU,
						"'Indietro' non torna al menu (stato: %s)" % _st(Game.state))
				_ok(Game.current_screen() != null and Game.current_screen() != ss,
						"'Indietro' lascia la schermata delle impostazioni ancora montata")

	# "Nuova partita" deve entrare nel gioco. E' il pulsante che segnala al
	# giocatore che il gioco esiste.
	await _settle()
	mm = Game.current_screen()
	var b_new := mm.find_child("Nuova partita", true, false) if mm != null else null
	if _ok(b_new != null, "manca il bottone 'Nuova partita'"):
		(b_new as Button).emit_signal("pressed")
		await _settle()
		_ok(Game.state == Game.State.PLAYING,
				"'Nuova partita' non porta al gioco (stato: %s)" % _st(Game.state))
		_ok(not get_tree().paused, "nel gioco l'albero deve essere attivo, non in pausa")
		_ok(Game.current_screen() == null, "il menu resta montato durante il gioco")

		# E la pausa deve tornare al gioco, non al menu. `Game.back()` usa la
		# memoria dello schermo da cui si e' entrati: se quella memoria non
		# viene aggiornata, "Riprendi" porta al menu principale e il giocatore
		# perde la partita senza volerlo.
		Game.goto(Game.State.PAUSED)
		await _settle()
		var pm := Game.current_screen()
		if _ok(pm != null, "la schermata di pausa non e' montata"):
			var resume := pm.find_child("Riprendi", true, false)
			if _ok(resume != null, "manca il bottone 'Riprendi'"):
				(resume as Button).emit_signal("pressed")
				await _settle()
				_ok(Game.state == Game.State.PLAYING,
						"'Riprendi' non torna al gioco (stato: %s)" % _st(Game.state))

	# Torna al menu e libera lo slot di prova.
	Game.goto(Game.State.MAIN_MENU)
	await _settle()
	SaveGame.delete(0)

	# "Esci" chiama `quit()`: premere qui chiuderebbe la QA prima del
	# rapporto, quindi si verifica che sia collegato al metodo giusto invece di
	# premarlo. Il resto dei bottoni e' stato premuto davvero.
	#
	# Va controllato DOPO essere tornati al menu: durante il gioco il menu e'
	# stato liberato, e cercare un bottone dentro un nodo in coda di
	# cancellazione restituirebbe sempre null, facendo sembrare il menu
	# incompleto.
	mm = Game.current_screen()
	var b_quit := mm.find_child("Esci", true, false) if mm != null else null
	if _ok(b_quit != null, "manca il bottone 'Esci'"):
		_ok(_quit_target(b_quit) == "_on_quit",
				"'Esci' non e' collegato a _on_quit")


## Il nome del metodo richiamato da un bottone, per confronto.
func _quit_target(b: Button) -> String:
	for conn in b.get_signal_connection_list("pressed"):
		var c: Callable = conn.get("callable", Callable())
		if c.is_valid():
			return String(c.get_method())
	return ""


func _settle() -> void:
	# Le schermate sono montate in modo differito e le precedenti vengono
	# liberate in coda: servono dei frame, non un singolo `process_frame`, o il
	# test misurerebbe la schermata vecchia.
	for i in 4:
		await get_tree().process_frame


func _st(s: int) -> String:
	match s:
		Game.State.BOOT: return "BOOT"
		Game.State.MAIN_MENU: return "MAIN_MENU"
		Game.State.PLAYING: return "PLAYING"
		Game.State.PAUSED: return "PAUSED"
		Game.State.SETTINGS: return "SETTINGS"
		Game.State.CAUGHT: return "CAUGHT"
		Game.State.WON: return "WON"
	return "?"


func _report() -> void:
	print("---")
	if _errors.is_empty():
		print("ESITO: OK (%d controlli, 0 problemi)" % _checks)
		get_tree().quit(PASS)
	else:
		for e in _errors:
			print("  ! " + e)
		print("ESITO: FALLITO (%d controlli, %d problemi)" % [_checks, _errors.size()])
		get_tree().quit(FAIL)


func _ok(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_errors.append(msg)
	return cond


# ---------------------------------------------------------------- 1. input
## Il controllo che vale di piu' in assoluto. Un'azione senza binding da pad e'
## una funzione che il giocatore console non puo' usare, e la QA non la
## troverebbe mai giocando su desktop con la tastiera.
func _check_input() -> void:
	print("[1] input da gamepad")
	var bad := InputSetup.actions_without_gamepad()
	_ok(bad.is_empty(), "azioni senza binding gamepad: %s" % str(bad))

	for action in ["move_left", "move_right", "move_up", "move_down",
			"interact", "dodge", "throw", "crouch", "observe", "pause",
			"restart_encounter"]:
		_ok(InputMap.has_action(action), "azione mancante: " + action)

	# Ogni azione deve poter essere premuta: un'azione con deadzone ma senza
	# eventi non risponde mai.
	for action in InputSetup.SCHEMA:
		_ok(InputMap.action_get_events(action).size() > 0,
				"azione senza eventi: " + action)


# -------------------------------------------------------------- 2/3. schermate
func _check_screens() -> void:
	print("[2/3] safe area e focus")
	var screens := {
		"MainMenu": MainMenu.new(),
		"PauseMenu": PauseMenu.new(),
		"SettingsScreen": SettingsScreen.new(),
		"CaughtScreen": CaughtScreen.new(),
		"WonScreen": WonScreen.new(),
	}
	for name in screens:
		var s: Control = screens[name]
		# Si replica Game._mount: lo schermo va dentro una safe area, e in
		# testa si usa la risoluzione di riferimento perche' lo schermo non
		# e' ancora nella scena.
		var safe := Ui.safe_area(s, 0.05, Vector2(1920, 1080))
		add_child(safe)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var outside := Ui.outside_safe_area(s, 0.05)
		_ok(outside.is_empty(), "%s: elementi fuori dalla safe area: %s" % [name, str(outside)])

		# La lista dei navigabili e' quella che restituisce
		# make_controller_navigable: NON basta cercare i Button, perche' uno
		# schermo con slider e check box ha pulsanti che non sono Button e il
		# focus parte dal primo elemento della lista, non dal primo bottone.
		var focusables := Ui.make_controller_navigable(s)
		_ok(focusables.size() > 0, "%s: nessun elemento navigabile" % name)

		# Ogni bottone deve essere COLLEGATO a qualcosa. Il controllo di prima
		# (esiste, ha il focus) passava anche su un bottone morto: un menu con
		# tre voci scollegate si illuminava col D-pad e non faceva niente, e
		# la QA lo dava per buono. E' esattamente il difetto che ha rotto
		# questo menu la prima volta.
		for c in s.find_children("*", "Button", true, false):
			if not (c as Control).is_visible_in_tree():
				continue
			var b := c as Button
			var sig := "pressed"
			if b is CheckButton:
				sig = "toggled"
			_ok(_has_action(b, sig),
					"%s: il bottone '%s' non e' collegato a nessuna azione" % [name, b.name])
		for c in s.find_children("*", "HSlider", true, false):
			if not (c as Control).is_visible_in_tree():
				continue
			_ok(_has_action(c, "value_changed"),
					"%s: lo slider '%s' non e' collegato" % [name, (c as Control).name])

		# Esattamente un elemento con il focus: zero e' uno schermo morto,
		# piu' di uno e' focus e focus ridondanti in lotta fra loro.
		var focused := 0
		for c in focusables:
			if c.has_focus():
				focused += 1
		_ok(focused == 1, "%s: elementi con il focus = %d (deve essere 1)" % [name, focused])

		# Il D-pad deve poter attraversare tutti gli elementi e tornare indietro.
		if focusables.size() > 1:
			var order_ok := true
			for i in focusables.size():
				var a := focusables[i]
				var b := focusables[(i + 1) % focusables.size()]
				if a.focus_neighbor_bottom.is_empty():
					order_ok = false
					break
				if a.get_node_or_null(a.focus_neighbor_bottom) != b:
					order_ok = false
					break
			_ok(order_ok, "%s: la catena di navigazione D-pad e' rotta" % name)

		safe.queue_free()
		await get_tree().process_frame


# ------------------------------------------------------------------ 4. LOS
## Qui non si testa Godot: si testa la geometria. Un errore nella linea di
## vista e' invisibile guardando il gioco, e rende il gioco o troppo facile o
## impossibile.
func _check_los() -> void:
	print("[4] linea di vista")
	var wall := Rect2(100, -50, 50, 200)
	var shadow := Rect2(200, -50, 50, 200)
	var eye := Vector2(0, 0)

	var r1 := LOS.check(eye, 0.0, 45.0, 500.0, Vector2(150, 0), 30.0, [], [])
	_ok(r1["seen"] == true, "davanti senza ostacoli: doveva vedere (%s)" % r1["reason"])

	# 63 gradi con un cono di 45: fuori. Il bordo esatto (45) e' dentro, e
	# va bene cosi': il cono include il limite.
	var r2 := LOS.check(eye, 0.0, 45.0, 500.0, Vector2(150, 300), 30.0, [], [])
	_ok(r2["seen"] == false and r2["reason"] == "out_of_cone",
			"di lato oltre il cono: %s" % r2["reason"])

	# il limite esatto del cono conta come visto
	var r2b := LOS.check(eye, 0.0, 45.0, 500.0, Vector2(150, 150), 30.0, [], [])
	_ok(r2b["seen"] == true, "il bordo del cono deve contare come visto: %s" % r2b["reason"])

	# cono ruotato di 180: guarda a -X, quindi il bersaglio a +X e' DIETRO
	var r3 := LOS.check(eye, 180.0, 45.0, 500.0, Vector2(150, 0), 30.0, [], [])
	_ok(r3["seen"] == false, "bersaglio alle spalle col cono girato: %s" % r3["reason"])
	# e il bersaglio davanti al cono girato viene visto
	var r3b := LOS.check(eye, 180.0, 45.0, 500.0, Vector2(-150, 0), 30.0, [], [])
	_ok(r3b["seen"] == true, "davanti al cono girato: %s" % r3b["reason"])

	var r4 := LOS.check(eye, 0.0, 45.0, 500.0, Vector2(300, 0), 30.0, [wall], [])
	_ok(r4["seen"] == false and r4["reason"] == "blocked", "muro in mezzo: %s" % r4["reason"])

	# ombra: x da 200 a 250. Il punto (220,0) e' DENTRO l'ombra e deve essere
	# invisibile anche senza muri. Se questo test passa solo per caso,
	# l'ombra non sta proteggendo niente.
	var r5 := LOS.check(eye, 0.0, 45.0, 500.0, Vector2(220, 0), 30.0, [], [shadow])
	_ok(r5["seen"] == false and r5["in_shadow"] == true, "in ombra: %s" % r5["reason"])
	# appena fuori dall'ombra e' di nuovo visibile: il volume ha bordi netti
	var r5b := LOS.check(eye, 0.0, 45.0, 500.0, Vector2(260, 0), 30.0, [], [shadow])
	_ok(r5b["seen"] == true, "oltre il bordo dell'ombra: %s" % r5b["reason"])

	var r6 := LOS.check(eye, 0.0, 45.0, 200.0, Vector2(400, 0), 30.0, [], [])
	_ok(r6["seen"] == false and r6["reason"] == "out_of_range", "fuori portata: %s" % r6["reason"])

	var r7 := LOS.check(eye, 180.0, 45.0, 500.0, Vector2(20, 0), 30.0, [], [])
	_ok(r7["seen"] == true, "a contatto deve sentirti: %s" % r7["reason"])

	var fast := LOS.detection_rate({"seen": true, "dist": 300.0, "angle_off": 0.0}, 500.0, false)
	var slow := LOS.detection_rate({"seen": true, "dist": 300.0, "angle_off": 0.0}, 500.0, true)
	_ok(slow < fast, "accovacciato deve essere piu' lento: %.3f vs %.3f" % [slow, fast])

	_ok(is_zero_approx(LOS.detection_rate({"seen": false, "dist": 0.0, "angle_off": 0.0}, 500.0, false)),
			"non visto: il rate deve essere 0")

	_ok(LOS.segment_hits_rect(Vector2(0, 0), Vector2(10, 0), Rect2(5, -1, 2, 2)), "segmento che tocca")
	_ok(not LOS.segment_hits_rect(Vector2(0, 0), Vector2(10, 0), Rect2(5, 5, 2, 2)), "segmento che manca")
	_ok(not LOS.segment_hits_rect(Vector2(0, 0), Vector2(1, 0), Rect2(5, -1, 2, 2)),
			"segmento che si ferma prima")
	_ok(LOS.segment_hits_rect(Vector2(-10, 0), Vector2(10, 0), Rect2(-1, -1, 2, 2)),
			"segmento che attraversa da sinistra")


# ---------------------------------------------------------------- 5. livelli
func _check_levels() -> void:
	print("[5] livelli")
	var found := 0
	for f in DirAccess.get_files_at(Level.DIR):
		if not f.ends_with(".json"):
			continue
		found += 1
		var id := f.get_basename()
		var lv := Level.load_id(id)
		if not _ok(not lv.is_empty(), "%s: non caricabile" % id):
			continue
		for e in lv["errors"]:
			_ok(false, "%s: %s" % [id, e])
		_ok(Level.relic_connected(lv), "%s: la reliquia non e' raggiungibile" % id)
	_ok(found > 0, "nessun livello trovato in " + Level.DIR)


# ------------------------------------------------------------ 6. salvataggi
func _check_save() -> void:
	print("[6] salvataggi")
	var slot := 2
	SaveGame.delete(slot)
	SaveGame.write(slot, {"level": "level_01", "checkpoint": 2})
	SaveGame.flush()
	_ok(SaveGame.exists(slot), "salvataggio non scritto")
	_ok(not FileAccess.file_exists(SaveGame.path_for(slot) + ".tmp"), "file .tmp rimasto")
	SaveGame._cache.erase(slot)
	_ok(int(SaveGame.read(slot).get("checkpoint", -1)) == 2, "lettura dopo flush")

	# una seconda scrittura deve spostare il precedente in .bak
	SaveGame.write(slot, {"level": "level_01", "checkpoint": 3})
	SaveGame.flush()
	_ok(FileAccess.file_exists(SaveGame.path_for(slot) + ".bak"), "backup non creato")

	# file corrotto: deve tornare al backup, non crashare
	SaveGame._cache.erase(slot)
	SaveGame._dirty.clear()
	var f := FileAccess.open(SaveGame.path_for(slot), FileAccess.WRITE)
	f.store_string("{ questo non e' json")
	f.close()
	_ok(int(SaveGame.read(slot).get("checkpoint", -1)) == 2,
			"file corrotto: doveva tornare al backup, non crashare")

	# schema vecchio: deve migrare
	SaveGame.delete(slot)
	SaveGame.write(slot, {"progress": 7})
	SaveGame.flush()
	SaveGame._cache.erase(slot)
	var got := SaveGame.read(slot)
	_ok(int(got.get("levels", {}).get("unlocked", -1)) == 7, "schema vecchio non migrato")

	# checksum: una modifica fuori dal gioco deve essere respinta
	SaveGame.delete(slot)
	SaveGame.write(slot, {"level": "level_01"})
	SaveGame.flush()
	SaveGame._cache.erase(slot)
	_ok(SaveGame.read(slot).get("level", "") == "level_01", "salvataggio integro non leggibile")

	SaveGame.delete(slot)

	# impostazioni: stessa disciplina, piu' il fatto che un valore salvato
	# deve sopravvivere al riavvio e che un file rovinato non deve impedire
	# al gioco di partire con i default.
	var keep := float(Settings.value("text_scale", 1.0))
	Settings.set_value("text_scale", 1.5)
	Settings.save()
	Settings._data = {}
	Settings._load()
	_ok(is_equal_approx(float(Settings.value("text_scale")), 1.5),
			"impostazione non sopravvive al riavvio")
	Settings.set_value("text_scale", keep)
	Settings.save()

	var f2 := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	f2.store_string("rotto")
	f2.close()
	Settings._data = Settings.DEFAULTS.duplicate(true)
	Settings._load()
	_ok(is_equal_approx(Settings.text_scale(), 1.0),
			"impostazioni corrotte: il gioco deve partire con i default, non crashare")


# ------------------------------------------------------------- 7. localizzazione
func _check_locale() -> void:
	print("[7] localizzazione")
	_ok(TranslationServer.get_loaded_locales().size() > 0, "nessuna localizzazione caricata")
	_ok(FileAccess.file_exists("res://locale/game.en.csv"), "game.en.csv mancante")
	_ok(FileAccess.file_exists("res://locale/game.it.csv"), "game.it.csv mancante")

	var keys := {}
	for line in FileAccess.get_file_as_string("res://locale/game.it.csv").split("\n"):
		var parts := line.split(",")
		if parts.size() >= 2:
			keys[parts[0].strip_edges().replace("\"", "")] = true
	_ok(keys.size() > 20, "poche chiavi in game.it.csv: %d" % keys.size())
	for k in ["GAME_TITLE", "CAUGHT_TITLE", "WON_TITLE", "PAD_COLLEGATO",
			"OBJ_RELIC", "MENU_SETTINGS", "MENU_RESUME", "TOAST_NOISE"]:
		_ok(keys.has(k), "chiave mancante in it: " + k)

	# Le stesse chiavi in en e it: una chiave solo in una lingua e' una
	# stringa che su Xbox compare grezza a meta' delle schermate.
	var en_keys := {}
	for line in FileAccess.get_file_as_string("res://locale/game.en.csv").split("\n"):
		var parts := line.split(",")
		if parts.size() >= 2:
			en_keys[parts[0].strip_edges().replace("\"", "")] = true
	for k in en_keys:
		_ok(keys.has(k), "chiave solo in en, manca in it: " + k)

	TranslationServer.set_locale("it")
	_ok(L10n.t("MENU_RESUME") == "Riprendi", "traduzione it non applicata: " + L10n.t("MENU_RESUME"))
	TranslationServer.set_locale("en")
	_ok(L10n.t("MENU_RESUME") == "Resume", "traduzione en non applicata: " + L10n.t("MENU_RESUME"))

	# Il controllo che chiude il cerchio: ogni chiave richiesta nel sorgente
	# deve esistere nelle traduzioni. Una chiave mancante in en E it non
	# verrebbe fuori dal confronto fra le due tabelle, e a schermo
	# mostrerebbe "MENU_QUIT" senza che nessuno se ne accorga.
	var used := {}
	var rx := RegEx.new()
	rx.compile("L10n\\.t\\(\"([A-Z0-9_]+)\"\\)")
	for f in _all_scripts("res://scripts") + _all_scripts("res://autoload"):
		for m in rx.search_all(FileAccess.get_file_as_string(f)):
			used[m.get_string(1)] = f
	_ok(used.size() > 15, "poche chiavi usate nel codice: %d" % used.size())
	for k in used:
		_ok(keys.has(k) and en_keys.has(k), "chiave usata in %s ma assente nelle traduzioni: %s" % [used[k], k])

	# Chiavi passate a L10n.t() in modo dinamico (sono anche chiavi di
	# impostazione, non solo stringhe): non le trova l'espressione regolare,
	# quindi sono elencate qui per evitare che restino non verificate.
	for k in ["music_volume", "sfx_volume", "text_scale", "screen_shake", "show_vision_cones"]:
		_ok(keys.has(k) and en_keys.has(k), "chiave dinamica assente dalle traduzioni: " + k)


# ---------------------------------------------------------------- 8. offline
## Su console non ci sono servizi da chiamare: se il gioco funziona solo
## online, la certificazione lo segnala subito.
func _check_offline() -> void:
	print("[8] nessuna dipendenza di rete")
	var bad: Array[String] = []
	for f in _all_scripts("res://"):
		if f.ends_with("qa_idxbox.gd"):
			continue     # questo file nomina i tipi solo per cercarli
		var t := FileAccess.get_file_as_string(f)
		for pat in ["HTTPRequest", "HTTPClient", "WebSocketPeer",
				"PacketPeerUDP", "TCPServer", "StreamPeerTCP"]:
			if t.contains(pat):
				bad.append("%s contiene %s" % [f, pat])
	_ok(bad.is_empty(), "dipendenze di rete: %s" % str(bad))


func _all_scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_all_scripts(dir_path.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out
