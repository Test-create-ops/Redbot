extends Node
## Salvataggi di gioco: versionati, atomici, con backup e checksum.
##
## Requisiti di certificazione che questo file copre:
##  - XR-001: dopo un aggiornamento del gioco i salvataggi devono restare
##    leggibili. Da qui il campo `version` e la migrazione esplicita.
##  - Il salvataggio deve sopravvivere a chiusura improvvisa: scrittura in
##    `tmp` + rename, con il precedente conservato come `.bak`.
##  - Disinstallare e reinstallare non deve corrompere nulla: al primo
##    avvio di una title non c'e' piu' `user://`, quindi il default e'
##    "nuova partita", mai un file che il gioco non sa leggere.
##  - Il gioco deve essere giocabile offline, quindi nessun salvataggio
##    dipende da servizi di rete.

signal saved(slot: int)
signal loaded(slot: int)

const SCHEMA := 1
const SLOTS := 3
const BASE := "user://save_slot_%d.json"
const DEFAULT_SLOT := 0

var _cache: Dictionary = {}
var _dirty: Dictionary = {}
var _quitting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Game gestisce chiusura e sospensione e chiama flush() da li'. Qui non si
## tocca NOTIFICATION_WM_CLOSE_REQUEST: se lo facessero anche SaveGame e Game,
## il quit partirebbe due volte e il secondo sarebbe un crash.


func path_for(slot: int) -> String:
	return BASE % slot


func exists(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Legge uno slot. Se il file e' corrotto prova il backup; se anche quello
## e' perso restituisce null e il gioco riparte pulito invece di crashare.
func read(slot: int) -> Dictionary:
	if _cache.has(slot):
		return _cache[slot]
	var d := _read_one(path_for(slot))
	if d.is_empty():
		d = _read_one(path_for(slot) + ".bak")
		if not d.is_empty():
			push_warning("save: slot %d recuperato dal backup" % slot)
	if not d.is_empty():
		_cache[slot] = d
	return d


func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save: json corrotto in " + path)
		return {}
	var doc: Dictionary = parsed
	var body: Dictionary = doc.get("data", {})
	var stamp := String(doc.get("checksum", ""))
	if stamp != _checksum(body):
		push_warning("save: checksum non valido in " + path)
		return {}
	body = _migrate(body)
	return body


## Scrive in modo differito. Chiamare in continuazione e' economico: il file
## viene toccato una volta sola, alla prossima flush.
func write(slot: int, data: Dictionary) -> void:
	_cache[slot] = data
	_dirty[slot] = true


func is_dirty(slot: int) -> bool:
	return _dirty.has(slot)


func flush() -> void:
	if _dirty.is_empty():
		return
	for slot in _dirty.keys():
		_write_now(slot, _cache.get(slot, {}))
	_dirty.clear()


func _write_now(slot: int, data: Dictionary) -> void:
	var body := data
	body["schema"] = SCHEMA
	var doc := {"version": SCHEMA, "checksum": _checksum(body), "data": body}
	var tmp := path_for(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: impossibile scrivere " + tmp)
		return
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	var fin := path_for(slot)
	if FileAccess.file_exists(fin):
		if FileAccess.file_exists(fin + ".bak"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fin + ".bak"))
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(fin),
			ProjectSettings.globalize_path(fin + ".bak"))
	if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp),
			ProjectSettings.globalize_path(fin)) != OK:
		push_error("save: scrittura atomica fallita su slot " + str(slot))
		return
	saved.emit(slot)


## Checksum: non serve crittografia, serve capire se il file e' stato
## troncato o corrotto.
##
## Attenzione: NON si puo' fare `md5(JSON.stringify(body))`. `JSON.parse_string`
## restituisce ogni numero come float, quindi `2` torna come `2.0` e il testo
## ricalcolato e' diverso da quello scritto: il checksum non corrisponderebbe
## MAI e ogni salvataggio con un intero andrebbe perso al primo reload. Il
## bug e' invisibile guardando i numeri e si vede solo facendo un giro di
## scrittura/lettura.
##
## Si canonizza invece il valore: chiavi ordinate, numeri interi senza punto.
## La forma canonica e' la stessa prima e dopo il passaggio da JSON.
func _checksum(data: Dictionary) -> String:
	return _canon(data).md5_text()


func _canon(v: Variant) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var keys: Array = (v as Dictionary).keys()
			keys.sort()                      # l'ordine non deve contare
			var parts: Array[String] = []
			for k in keys:
				parts.append("%s=%s" % [str(k), _canon((v as Dictionary)[k])])
			return "{" + "|".join(parts) + "}"
		TYPE_ARRAY:
			var items: Array[String] = []
			for it in (v as Array):
				items.append(_canon(it))
			return "[" + ",".join(items) + "]"
		TYPE_FLOAT:
			var f: float = v
			# 2.0 e 2 devono dare la stessa stringa, altrimenti il checksum
			# dipende da come il numero e' passato dentro e fuori dal JSON.
			if is_equal_approx(f, roundf(f)) and absf(f) < 9.0e15:
				return str(int(roundf(f)))
			return str(f)
		TYPE_STRING:
			return '"' + String(v) + '"'
		TYPE_NIL:
			return "null"
		_:
			return str(v)


## Migrazione esplicita. Quando si aggiunge un campo si tocca qui, non si
## assume che il default valga per i salvataggi vecchi.
##
## La migrazione NON si attiva sull'assenza di "schema": ogni corpo scritto
## da questa versione ce l'ha, quindi controllare quello renderebbe questa
## funzione un no-op e i salvataggi legacy non migrerebbero mai. Si guarda
## la forma del payload. E' idempotente: un corpo gia' migrato ha "levels",
## quindi non viene rimigrato.
func _migrate(body: Dictionary) -> Dictionary:
	if body.has("progress") and not body.has("levels"):
		# salvataggi pre-sistema-a-slot
		body["levels"] = {"unlocked": body["progress"]}
		body.erase("progress")
	body["schema"] = SCHEMA
	return body


func delete(slot: int) -> void:
	_cache.erase(slot)
	_dirty.erase(slot)
	for p in [path_for(slot), path_for(slot) + ".bak", path_for(slot) + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# --- scorciatoie sullo slot principale -------------------------------------
# La maggior parte del gioco scade e legge sullo slot 0. Queste tre funzioni
# nascondono il numero per non avere `write(0, ...)` sparso ovunque.

func data() -> Dictionary:
	return read(DEFAULT_SLOT)


func set_value(key: String, value: Variant) -> void:
	var d := data()
	d[key] = value
	write(DEFAULT_SLOT, d)


func value(key: String, fallback: Variant = null) -> Variant:
	return data().get(key, fallback)


## Statistiche per la QA: cosa c'e' davvero su disco, non in memoria.
func disk_report() -> Dictionary:
	var rep := {}
	for i in SLOTS:
		rep["slot%d" % i] = {
			"exists": FileAccess.file_exists(path_for(i)),
			"bytes": _size(path_for(i)),
			"backup": FileAccess.file_exists(path_for(i) + ".bak"),
			"tmp_left": FileAccess.file_exists(path_for(i) + ".tmp"),
		}
	return rep


func _size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n
