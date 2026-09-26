extends Node
## InputMap costruito in codice.
##
## Perche' non in project.godot: tools/qa_idxbox.gd deve poter verificare che
## ogni azione di gioco abbia almeno un binding da GAMEPAD. Scritto a mano
## nel .godot, quel controllo non sarebbe possibile, e "un'azione irraggiungibile
## con il pad" e' esattamente il difetto che blocca la certificazione.
##
## Layout (standard Xbox):
##   A = interagisci (contestuale)   X = schivata   Y = lancia vitone
##   B = annulla / pausa            LB = accovacciato (tieni premuto)
##   RB = osserva (tieni premuto)   Back = menu pausa
##   L3 = riavvia l'incontro dal checkpoint
##
## La tastiera e' un fallback per sviluppare su desktop, non un input di gioco:
## nessun gameplay deve poter essere completato solo da tastiera+tastiera.
var SCHEMA := {
	# azione            deadzone, [tasti gamepad], [tasti tastiera]
	"move_left": [0.25, ["dpad_left", "lstick_left"], ["A", "Left"]],
	"move_right": [0.25, ["dpad_right", "lstick_right"], ["D", "Right"]],
	"move_up": [0.25, ["dpad_up", "lstick_up"], ["W", "Up"]],
	"move_down": [0.25, ["dpad_down", "lstick_down"], ["S", "Down"]],
	"interact": [0.5, ["a"], ["E", "Enter"]],
	"dodge": [0.5, ["x"], ["Space"]],
	"throw": [0.5, ["y"], ["F"]],
	"crouch": [0.5, ["lb"], ["C", "Ctrl"]],
	"observe": [0.5, ["rb"], ["Q"]],
	"pause": [0.5, ["b", "back", "start"], ["Escape"]],
	# L3 e' libero nel layout standard e serve esattamente a questo: in un
	# gioco di stealth la morte e' frequente e il retry immediato dal
	# checkpoint e' una funzione di accessibilita', non un lusso.
	"restart_encounter": [0.5, ["l3"], ["F5"]],
}

# alias gamepad -> (tipo, valore)
const PAD_BUTTON := {
	"a": JOY_BUTTON_A,
	"b": JOY_BUTTON_B,
	"x": JOY_BUTTON_X,
	"y": JOY_BUTTON_Y,
	"lb": JOY_BUTTON_LEFT_SHOULDER,
	"rb": JOY_BUTTON_RIGHT_SHOULDER,
	"l3": JOY_BUTTON_LEFT_STICK,
	"r3": JOY_BUTTON_RIGHT_STICK,
	"back": JOY_BUTTON_BACK,
	"start": JOY_BUTTON_START,
	"dpad_up": JOY_BUTTON_DPAD_UP,
	"dpad_down": JOY_BUTTON_DPAD_DOWN,
	"dpad_left": JOY_BUTTON_DPAD_LEFT,
	"dpad_right": JOY_BUTTON_DPAD_RIGHT,
}
const PAD_AXIS := {
	"lstick_left": [JOY_AXIS_LEFT_X, -1.0],
	"lstick_right": [JOY_AXIS_LEFT_X, 1.0],
	"lstick_up": [JOY_AXIS_LEFT_Y, -1.0],
	"lstick_down": [JOY_AXIS_LEFT_Y, 1.0],
}
const KEY_ALIAS := {
	"A": KEY_A, "B": KEY_B, "C": KEY_C, "D": KEY_D, "E": KEY_E, "F": KEY_F,
	"Q": KEY_Q, "W": KEY_W, "S": KEY_S,
	"Left": KEY_LEFT, "Right": KEY_RIGHT, "Up": KEY_UP, "Down": KEY_DOWN,
	"Space": KEY_SPACE, "Enter": KEY_ENTER, "Escape": KEY_ESCAPE,
	"Ctrl": KEY_CTRL, "F5": KEY_F5,
}


func _ready() -> void:
	_install()


func _install() -> void:
	for action in SCHEMA:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, SCHEMA[action][0])
		for pad in SCHEMA[action][1]:
			_add_pad(action, pad)
		for key in SCHEMA[action][2]:
			_add_key(action, key)


func _add_pad(action: String, alias: String) -> void:
	if PAD_BUTTON.has(alias):
		var e := InputEventJoypadButton.new()
		e.button_index = PAD_BUTTON[alias]
		e.device = -1          # -1 = qualunque pad
		InputMap.action_add_event(action, e)
	elif PAD_AXIS.has(alias):
		var ax: Array = PAD_AXIS[alias]
		var e2 := InputEventJoypadMotion.new()
		e2.axis = ax[0]
		e2.axis_value = ax[1]
		e2.device = -1
		InputMap.action_add_event(action, e2)
	else:
		push_error("alias gamepad sconosciuto: " + alias)


func _add_key(action: String, alias: String) -> void:
	if not KEY_ALIAS.has(alias):
		push_error("alias tasto sconosciuto: " + alias)
		return
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ALIAS[alias]
	InputMap.action_add_event(action, e)


## Il remap completo e' un requisito di accessibilita' su Xbox: va
## implementato prima della submission. Qui si espone l'API, non la UI.
func rebind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	Settings.set_value("input." + action, event.as_text())


## Elenco delle azioni che NON hanno un binding da gamepad. Deve essere vuoto.
static func actions_without_gamepad() -> Array[String]:
	var bad: Array[String] = []
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue          # le ui_* le mette Godot e hanno gia' il pad
		var has_pad := false
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				has_pad = true
				break
		if not has_pad:
			bad.append(String(action))
	return bad
