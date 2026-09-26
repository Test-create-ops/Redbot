extends Control
class_name Hud
## HUD: obiettivo, vitoni, e la barra di allarme.
##
## Regola di layout per console: niente informazione importante ai bordi
## dello schermo. Tutto sta dentro la safe area, e la QA lo controlla con
## Ui.outside_safe_area.

const MARGIN := 0.05

var _objective: Label
var _bolts: Label
var _alert: ProgressBar
var _alert_box: ColorRect
var _toast: Label
var _toast_t := 0.0
var _world: World


func _ready() -> void:
	name = "Hud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.name = "Col"
	root.add_theme_constant_override("separation", 10)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_objective = Label.new()
	_objective.name = "Objective"
	root.add_child(_objective)

	_bolts = Label.new()
	_bolts.name = "Bolts"
	root.add_child(_bolts)

	_toast = Label.new()
	_toast.name = "Toast"
	_toast.modulate = Color(1, 1, 1, 0)
	root.add_child(_toast)

	var row := HBoxContainer.new()
	row.name = "AlertRow"
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	_alert_box = ColorRect.new()
	_alert_box.custom_minimum_size = Vector2(8, 34)
	_alert_box.color = Color(1, 1, 1, 0.15)
	row.add_child(_alert_box)
	_alert = ProgressBar.new()
	_alert.name = "Alert"
	_alert.show_percentage = false
	_alert.custom_minimum_size = Vector2(420, 34)
	_alert.max_value = 1.0
	_alert.value = 0.0
	row.add_child(_alert)

	Ui.apply_text_scale(root, Settings.text_scale())
	# L'HUD e' gia' nella scena, quindi la dimensione del viewport e'
	# affidabile: la safe area puo' essere calcolata sul serio.
	var safe := Ui.safe_area(root, MARGIN, get_viewport_rect().size)
	add_child(safe)


func level_started(w: World, lv: Dictionary) -> void:
	_world = w
	_objective.text = L10n.t("OBJ_RELIC")
	_refresh_bolts()


func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		_toast.modulate = Color(1, 1, 1, maxf(0.0, _toast_t / 0.6))

	var peak := 0.0
	if _world != null:
		for gu in _world.guardians():
			peak = maxf(peak, gu.alert_level())
	_alert.value = peak
	_alert_box.color = Color(1, 0.35, 0.3, 0.15 + 0.85 * peak)

	_refresh_bolts()


func _refresh_bolts() -> void:
	if _world == null or _world.player == null:
		return
	_bolts.text = L10n.t("HUD_BOLTS") % _world.player.bolt_count()


func toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate = Color(1, 1, 1, 1)
	_toast_t = 1.8
