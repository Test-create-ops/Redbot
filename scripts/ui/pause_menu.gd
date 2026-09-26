extends Control
class_name PauseMenu

## Menu di pausa. Dispose anche del riavvio dell'incontro e del ritorno al
## menu: sono le tre azioni che un giocatore su console si aspetta di trovare
## quando preme "pausa".

var _root: Control


func _ready() -> void:
	name = "PauseMenu"
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.mark_decor(dim)   # tenda full-bleed: esclusa dal controllo safe area
	add_child(dim)

	var vb := VBoxContainer.new()
	vb.name = "Col"
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 660.0
	vb.offset_right = -660.0
	vb.offset_top = 300.0
	vb.offset_bottom = -300.0
	add_child(vb)

	var t := Label.new()
	t.name = "Title"
	t.text = L10n.t("MENU_PAUSED")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	vb.add_child(t)

	_mk(vb, "Riprendi", L10n.t("MENU_RESUME"), func(): Game.goto(Game.State.PLAYING))
	_mk(vb, "Impostazioni", L10n.t("MENU_SETTINGS"), func(): Game.goto(Game.State.SETTINGS))
	_mk(vb, "Ricomincia incontro", L10n.t("MENU_RETRY"), _on_retry)
	_mk(vb, "Menu principale", L10n.t("MENU_MAIN"), func(): Game.goto(Game.State.MAIN_MENU))

	Ui.apply_text_scale(self, Settings.text_scale())
	Ui.make_controller_navigable(self, "Riprendi")


func _mk(parent: Node, n: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.custom_minimum_size = Vector2(460, 64)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_retry() -> void:
	Game.world.restart_encounter()
	Game.goto(Game.State.PLAYING)
