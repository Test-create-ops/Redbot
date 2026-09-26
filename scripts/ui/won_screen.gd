extends Control
class_name WonScreen

## Livello completato. Il tono e' quello del gioco: niente esplosioni, niente
## punteggio, niente "hai sconfitto il boss". Hai portato via un pezzo di
## macchina e sei uscito. Fine.

var _time := 0.0


func _ready() -> void:
	name = "WonScreen"
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.05, 0.08, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.mark_decor(dim)   # tenda full-bleed: esclusa dal controllo safe area
	add_child(dim)

	var vb := VBoxContainer.new()
	vb.name = "Col"
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 620.0
	vb.offset_right = -620.0
	vb.offset_top = 320.0
	vb.offset_bottom = -320.0
	add_child(vb)

	var t := Label.new()
	t.name = "Title"
	t.text = L10n.t("WON_TITLE")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	vb.add_child(t)

	var s := Label.new()
	s.name = "Sub"
	s.text = L10n.t("WON_SUB")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)

	_mk(vb, "Rigioca", L10n.t("WON_AGAIN"), _on_again)
	_mk(vb, "Menu principale", L10n.t("MENU_MAIN"), func(): Game.goto(Game.State.MAIN_MENU))

	Ui.apply_text_scale(self, Settings.text_scale())
	Ui.make_controller_navigable(self, "Rigioca")


func _mk(parent: Node, n: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.custom_minimum_size = Vector2(420, 64)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_again() -> void:
	Game.world.restart_encounter()
	Game.goto(Game.State.PLAYING)
