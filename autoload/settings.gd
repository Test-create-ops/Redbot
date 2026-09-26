extends Node
## Impostazioni persistenti, con scrittura atomica.
##
## Su console `user://` finisce nell'area di salvataggio della title, che
## sopravvive agli aggiornamenti del gioco. Va pero' scritta in modo
## atomico: se il sistema chiude il gioco nel mezzo di un salvataggio
## (sospensione, crash, energia che finisce) il file deve restare valido,
## non troncato. XR-001 chiede esattamente questo.

const PATH := "user://settings.json"
const BACKUP := "user://settings.json.bak"
const TMP := "user://settings.json.tmp"
const VERSION := 1

signal changed(key: String, value: Variant)

const DEFAULTS := {
	"text_scale": 1.0,        # accessibilita': scala di tutto il testo
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"screen_shake": 1.0,
	"show_vision_cones": true,  # le coni di vista si vedono anche senza osservare
	"input.move_left": "",
	"input.move_right": "",
	"input.move_up": "",
	"input.move_down": "",
	"input.interact": "",
	"input.dodge": "",
	"input.throw": "",
	"input.crouch": "",
	"input.observe": "",
	"input.pause": "",
	"input.restart_encounter": "",
}

var _data: Dictionary = {}
var _dirty := false
var _since_save := 0.0
const SAVE_EVERY := 2.0


func _ready() -> void:
	# ALWAYS: le impostazioni devono poter essere scritte mentre il gioco e'
	# in pausa, perche' si cambia la lingua o il volume dal menu di pausa e
	# poi si esce.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = DEFAULTS.duplicate(true)
	_load()


func _process(dt: float) -> void:
	# Scrittura differita: `set_value` viene chiamato anche a ogni frame
	# mentre si trascina uno slider, e scrivere un file 60 volte al secondo
	# su una console non e' gratis. Il gioco non perde nulla: `Game` chiama
	# `Settings.save()` su sospensione e su chiusura.
	if not _dirty:
		return
	_since_save += dt
	if _since_save >= SAVE_EVERY:
		save()


func value(key: String, fallback: Variant = null) -> Variant:
	return _data.get(key, fallback if fallback != null else DEFAULTS.get(key))


func set_value(key: String, v: Variant, persist: bool = true) -> void:
	if _data.get(key) == v:
		return
	_data[key] = v
	changed.emit(key, v)
	if persist:
		_dirty = true


## Scala del testo applicata a ogni Control. I consumer si collegano a
## `changed("text_scale", ...)` invece di indovinare il valore.
func text_scale() -> float:
	return float(value("text_scale", 1.0))


func save() -> void:
	var payload := {"version": VERSION, "data": _data}
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		push_warning("settings: impossibile aprire " + TMP)
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	_atomic_swap(TMP, PATH, BACKUP)
	_dirty = false
	_since_save = 0.0


func _load() -> void:
	var raw := _read_valid(PATH)
	if raw.is_empty():
		raw = _read_valid(BACKUP)
	if raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("settings: json illeggibile, uso i default")
		return
	var d: Dictionary = parsed.get("data", {})
	for k in DEFAULTS:
		if d.has(k):
			_data[k] = d[k]
	# un file di versione futura non va fidato ciecamente
	if int(parsed.get("version", 0)) > VERSION:
		push_warning("settings: file piu' recente del gioco, alcuni valori ignorati")


func _read_valid(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


## tmp -> bak, tmp -> finale. Se il finale non e' scrivibile il bak rimane
## comunque buono, quindi non si perde tutto in ogni caso.
func _atomic_swap(tmp: String, final_path: String, backup: String) -> void:
	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(final_path),
			ProjectSettings.globalize_path(backup))
	if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp),
			ProjectSettings.globalize_path(final_path)) != OK:
		push_error("settings: scrittura atomica fallita")
