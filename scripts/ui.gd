extends RefCounted
class_name Ui
## Helper di UI che risolvono due problemi che su console si prendono solo se
## sono gia' previsti: l'overscan delle TV e la navigazione da gamepad.

## Costruisce un MarginContainer con il margine "title safe" e ci mette dentro
## `content`.
##
## Il chiamante aggiunge il MarginContainer alla scena, NON il contenuto:
## `safe_area` non può chiamare `reparent()` perché su uno schermo appena
## creato il nodo non ha ancora un padre, e `reparent` su un nodo senza
## padre è un errore. Inoltre `get_viewport_rect()` su un nodo fuori dalla
## scena non ha una dimensione affidabile: si legge dal viewport, quindi
## serve che il contenitore sia già montato o che si usi la risoluzione di
## riferimento.
static func safe_area(content: Control, margin: float, vsize: Vector2 = Vector2.ZERO) -> MarginContainer:
	var m := MarginContainer.new()
	m.name = "SafeArea"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := vsize
	if v.x <= 0.0 or v.y <= 0.0:
		v = content.get_viewport_rect().size
	if v.x <= 0.0 or v.y <= 0.0:
		v = Vector2(1920, 1080)      # fallback: la risoluzione di riferimento
	var mx := int(round(v.x * margin))
	var my := int(round(v.y * margin))
	m.add_theme_constant_override("margin_left", mx)
	m.add_theme_constant_override("margin_right", mx)
	m.add_theme_constant_override("margin_top", my)
	m.add_theme_constant_override("margin_bottom", my)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_child(content)
	return m


## Rende una lista di Control navigabile da solo con il D-pad, senza mouse.
##
## Regole applicate:
##  - ogni bottone e' focusable e parte con focus_grab, quindi c'e' sempre
##    esattamente un elemento con il focus (niente schermi "morti");
##  - il mouse non e' necessario ma resta comodo in sviluppo;
##  - il ciclo chiuso (ultimo -> primo) evita il "cattura" del focus sul bordo
##    dello schermo, che su TV si vede come una selezione che scappa via.
static func make_controller_navigable(root: Control, first: String = "") -> Array[Control]:
	var list: Array[Control] = []
	_collect_focusables(root, list)
	var n := list.size()
	for i in n:
		var c := list[i]
		c.focus_mode = Control.FOCUS_ALL
		# focus_neighbor_* accettano NodePath, non nodi: get_path_to() calcola
		# il percorso relativo esatto, quindi funziona anche se i bottoni
		# stanno in contenitori annidati diversi.
		c.focus_neighbor_top = c.get_path_to(list[(i - 1 + n) % n])
		c.focus_neighbor_bottom = c.get_path_to(list[(i + 1) % n])
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom
	if n > 0:
		var target: Control = list[0]
		if first != "":
			for c in list:
				if c.name == first:
					target = c
		target.grab_focus()
	return list


static func _collect_focusables(n: Node, out: Array[Control]) -> void:
	for c in n.get_children():
		if c is Control:
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				if ctl is BaseButton or ctl.focus_mode == Control.FOCUS_ALL:
					out.append(ctl)
		_collect_focusables(c, out)


## Scala il testo di un albero di Control in base all'impostazione di
## accessibilita'. Non esiste un "font size" globale in Godot, quindi si
## risale l'albero e si tocca `theme_override_font_sizes/font_size`.
static func apply_text_scale(root: Control, scale: float) -> void:
	_apply_ts(root, scale)


static func _apply_ts(n: Node, scale: float) -> void:
	if n is Control:
		var c := n as Control
		var cur := c.get_theme_font_size("font_size")
		if cur > 0:
			c.add_theme_font_size_override("font_size", int(round(cur * scale)))
	for ch in n.get_children():
		_apply_ts(ch, scale)


## Elenco dei Control che finiscono fuori dalla safe area. La QA lo usa come
## lista di problemi: deve essere vuoto.
##
## I nodi nel gruppo "decor" sono esclusi: gli sfondi a tutto schermo (le
## tende dietro un menu) sono per definizione full-bleed e segnalarli come
## errori renderebbe il controllo inutile perche' finirebbe con un avviso
## che nessuno puo' correggere.
static func outside_safe_area(root: Control, margin: float) -> Array[String]:
	var bad: Array[String] = []
	var v: Vector2 = root.get_viewport_rect().size
	if v.x <= 0.0 or v.y <= 0.0:
		v = Vector2(1920, 1080)
	var safe := Rect2(Vector2(v.x * margin, v.y * margin),
			v * (1.0 - 2.0 * margin))
	_walk_rects(root, safe, bad)
	return bad


static func _walk_rects(n: Node, safe: Rect2, bad: Array[String]) -> void:
	for c in n.get_children():
		if c is Control:
			var ctl := c as Control
			if not ctl.is_visible_in_tree():
				continue
			if ctl.is_in_group("decor"):
				continue
			var r := ctl.get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0:
				# tolleranza di 1 px: arrotondamenti dei layout
				if (r.position.x < safe.position.x - 1.0
						or r.position.y < safe.position.y - 1.0
						or r.end.x > safe.end.x + 1.0
						or r.end.y > safe.end.y + 1.0):
					bad.append("%s %s" % [ctl.name, str(r)])
		_walk_rects(c, safe, bad)


static func mark_decor(n: Node) -> void:
	n.add_to_group("decor")
