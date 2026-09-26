extends Control
class_name MainMenu

## Menu principale. Ogni voce e' un bottone con focus, quindi si naviga
## solo con D-pad: nessun passaggio richiede il mouse.
## `focus_neighbor_*` sono gia' collegati da Ui.make_controller_navigable.

var _continue_btn: Button


func _ready() -> void:
	name = "MainMenu"

	var vb := VBoxContainer.new()
	vb.name = "Col"
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 480.0
	vb.offset_right = -480.0
	vb.offset_top = 120.0
	vb.offset_bottom = -120.0
	add_child(vb)

	# Background dentro VBoxContainer (stessa safe area)
	var bg := Panel.new()
	bg.name = "Background"
	bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.10, 0.11, 0.14, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_child(bg)
	vb.move_child(bg, 0)

	var title := Label.new()
	title.name = "Title"
	title.text = L10n.t("GAME_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	vb.add_child(title)

	if SaveGame.exists(0):
		_continue_btn = _mk(vb, "Continua", L10n.t("MENU_CONTINUE"), Callable(self, "_on_continue"))
	_mk(vb, "Nuova partita", L10n.t("MENU_NEW_GAME"), Callable(self, "_on_new"))
	_mk(vb, "Impostazioni", L10n.t("MENU_SETTINGS"), Callable(self, "_on_settings"))
	_mk(vb, "Esci", L10n.t("MENU_QUIT"), Callable(self, "_on_quit"))

	var col := vb
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 480.0
	col.offset_right = -480.0
	col.offset_top = 120.0
	col.offset_bottom = -120.0

	Ui.apply_text_scale(self, Settings.text_scale())
	Ui.make_controller_navigable(self, "Title" if _continue_btn == null else "Continua")
	# Il titolo non e' un bottone: il primo focus va su un pulsante.
	_grab_first_button()


## `_cb` va COLLEGATO. Era un parametro ignorato e il risultato era un menu
## con quattro voci, di cui una sola funzionante: gli altri tre bottoni si
## illuminavano, si selezionavano col D-pad e non facevano niente. La QA
## controllava che esistessero e che avessero il focus, non che fossero
## collegati a qualcosa.
func _mk(parent: Node, n: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.custom_minimum_size = Vector2(420, 72)
	parent.add_child(b)
	if cb.is_valid():
		b.pressed.connect(cb)
	else:
		push_error("MainMenu: '%s' non ha azione collegata" % n)
	return b


func _grab_first_button() -> void:
	for c in find_children("*", "Button", true, false):
		if c is Button and not (c as Button).is_visible_in_tree():
			(c as Button).grab_focus()
			return


func _on_continue() -> void:
	Game.goto(Game.State.PLAYING)


func _on_new() -> void:
	print("MainMenu: _on_new clicked")
	SaveGame.delete(0)
	Game.goto(Game.State.PLAYING)


func _on_settings() -> void:
	Game.goto(Game.State.SETTINGS)


func _on_quit() -> void:
	SaveGame.flush()
	Settings.save()
	get_tree().quit()
