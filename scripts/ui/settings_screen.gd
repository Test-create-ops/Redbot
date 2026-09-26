extends Control
class_name SettingsScreen

## Impostazioni. Il primo settings esistente di una title console deve
## coprire almeno: volume, testo, e comportamento del gioco che possa
## disturbare (scuotimento camera).
##
## Sul controller si regola con D-pad + A/left-right, e le modifiche si
## vedono subito: niente schermate intermedie.

var _rows: Array[Dictionary] = []


func _ready() -> void:
	name = "Settings"
	process_mode = Node.PROCESS_MODE_ALWAYS

	var vb := VBoxContainer.new()
	vb.name = "Col"
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 520.0
	vb.offset_right = -520.0
	vb.offset_top = 180.0
	vb.offset_bottom = -180.0
	add_child(vb)

	# Background dentro VBoxContainer (stessa safe area)
	var bg := Panel.new()
	bg.name = "Background"
	bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.10, 0.11, 0.14, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_child(bg)
	vb.move_child(bg, 0)

	var t := Label.new()
	t.name = "Title"
	t.text = L10n.t("MENU_SETTINGS")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	vb.add_child(t)

	_row(vb, "Volume musica", "music_volume", 0.0, 1.0, 0.1)
	_row(vb, "Volume effetti", "sfx_volume", 0.0, 1.0, 0.1)
	_row(vb, "Dimensione testo", "text_scale", 0.75, 1.75, 0.25)
	_row(vb, "Scuotimento camera", "screen_shake", 0.0, 1.0, 0.25)
	_toggle(vb, "Mostra coni di vista", "show_vision_cones")
	_mk(vb, "Indietro", L10n.t("MENU_BACK"), func(): Game.back())

	Ui.make_controller_navigable(self, "Title")


func _row(parent: Node, label: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new()
	h.name = label
	h.add_theme_constant_override("separation", 24)
	parent.add_child(h)

	var l := Label.new()
	l.text = tr(key)
	l.custom_minimum_size = Vector2(360, 0)
	h.add_child(l)

	var val := Label.new()
	val.name = "Val"
	val.custom_minimum_size = Vector2(110, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)

	var sl := HSlider.new()
	sl.name = "Slider"
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(Settings.value(key, lo))
	sl.custom_minimum_size = Vector2(420, 40)
	sl.focus_mode = Control.FOCUS_ALL
	h.add_child(sl)

	var refresh := func() -> void:
		Settings.set_value(key, sl.value)
		val.text = "%d%%" % int(round(sl.value * 100.0))
	refresh.call()
	sl.value_changed.connect(func(_v): refresh.call())
	if key == "text_scale":
		Settings.changed.connect(func(k, _v):
			if k == "text_scale":
				Ui.apply_text_scale(self, float(Settings.value("text_scale"))))
	_rows.append({"key": key, "refresh": refresh})


func _toggle(parent: Node, label: String, key: String) -> void:
	var b := CheckButton.new()
	b.name = label
	b.text = tr(key)
	b.button_pressed = bool(Settings.value(key, true))
	b.focus_mode = Control.FOCUS_ALL
	b.toggled.connect(func(on: bool): Settings.set_value(key, on))
	parent.add_child(b)


func _mk(parent: Node, n: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.custom_minimum_size = Vector2(420, 60)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
