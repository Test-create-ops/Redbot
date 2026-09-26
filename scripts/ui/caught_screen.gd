extends Control
class_name CaughtScreen

## Preso. Niente morte, niente sangue, niente violenza: sei un robottino e
## le guardie non ti fanno del male, ti mettono fuori.
##
## Questo e' anche una scelta di posizionamento per il concept, non solo di
## tono: il fallimento non toglie nulla al giocatore, quindi il gioco resta
## "a casa" su Xbox (tutti i generi, nessunaViolenza esplicita) e il costo
## di un errore e' solo tempo.

var _tries := 0


func _ready() -> void:
	name = "CaughtScreen"
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.0, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.mark_decor(dim)   # tenda full-bleed: esclusa dal controllo safe area
	add_child(dim)

	var vb := VBoxContainer.new()
	vb.name = "Col"
	vb.add_theme_constant_override("separation", 22)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 640.0
	vb.offset_right = -640.0
	vb.offset_top = 340.0
	vb.offset_bottom = -340.0
	add_child(vb)

	var t := Label.new()
	t.name = "Title"
	t.text = L10n.t("CAUGHT_TITLE")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	vb.add_child(t)

	var s := Label.new()
	s.name = "Hint"
	s.text = L10n.t("CAUGHT_HINT")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)

	_mk(vb, "Riprova", L10n.t("CAUGHT_RETRY"), _on_retry)
	_mk(vb, "Menu principale", L10n.t("MENU_MAIN"), func(): Game.goto(Game.State.MAIN_MENU))

	Ui.apply_text_scale(self, Settings.text_scale())
	Ui.make_controller_navigable(self, "Riprova")


func _mk(parent: Node, n: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.custom_minimum_size = Vector2(420, 64)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_retry() -> void:
	_tries += 1
	Game.world.restart_encounter()
	Game.goto(Game.State.PLAYING)
