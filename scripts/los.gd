extends RefCounted
class_name LOS
## Linea di vista 2D, calcolata su dati e non sul mondo fisico.
##
## Tutte le funzioni sono pure e prendono rectangoli come argomenti. Motivo:
## la rilevazione e' IL meccanica di gioco, e un meccanica che si puo'
## interrogare con una riga di codice si puo' verificare in headless. Qui
## dentro non c'e' nessun nodo, nessun get_node, nessun await: la QA di
## tools/qa_idxbox.gd chiama queste funzioni con casi noti e verifica che
## "un player nell'ombra non e' visto" sia vero per costruzione, non per
## fiducia.
##
## Coordinate: schermo 2D, X a destra, Y giu'. Un angolo di 0 gradi punta
## verso +X e cresce verso il basso, come la rotazione di Godot.

## Intersezione segmento/rettangolo (metodo dello "slab" per i rettangoli
## allineati agli assi). Restituisce true se il segmento tocca il rettangolo.
static func segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var p := a[axis]
		var q := d[axis]
		var lo := r.position[axis]
		var hi := r.position[axis] + r.size[axis]
		# se il segmento e' parallelo all'asse ed e' fuori, non c'e' intersezione
		if absf(q) < 1e-6:
			if p < lo or p > hi:
				return false
			continue
		var t_lo := (lo - p) / q
		var t_hi := (hi - p) / q
		if t_lo > t_hi:
			var tmp := t_lo
			t_lo = t_hi
			t_hi = tmp
		t0 = maxf(t0, t_lo)
		t1 = minf(t1, t_hi)
		if t0 > t1:
			return false
	return true


static func segment_hits_any(a: Vector2, b: Vector2, rects: Array) -> bool:
	for r in rects:
		if segment_hits_rect(a, b, r):
			return true
	return false


static func point_in_any(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


## Differenza angolare in gradi, sempre nel range [-180, 180].
static func angle_delta(deg_a: float, deg_b: float) -> float:
	var d := fmod(deg_a - deg_b + 540.0, 360.0) - 180.0
	return d


## Il punto `target` e' visibile dall'occhio `eye` che guarda verso `facing`?
##
## Restituisce un dizionario perche' a valle servono piu' di un booleano:
## la barra di rilevazione cresce con la vicinanza, e i muri "vicini" contano
## meno dei muri lontani.
##
## keys: seen, dist, in_shadow, angle_off, blocked
static func check(eye: Vector2, facing_deg: float, half_angle_deg: float,
		range_px: float, target: Vector2, near_radius: float,
		walls: Array, shadows: Array) -> Dictionary:
	var d := target - eye
	var dist := d.length()
	var res := {
		"seen": false, "dist": dist, "in_shadow": false,
		"angle_off": 180.0, "blocked": false, "reason": "out_of_range",
	}
	if dist < 0.001:
		res["seen"] = true
		res["reason"] = "same_point"
		return res

	# L'ombra e' un volume: se il player e' dentro, non e' visibile dal punto
	# di vista della guardia, anche se in linea diretta.
	if point_in_any(target, shadows):
		res["in_shadow"] = true
		res["reason"] = "in_shadow"
		return res

	if dist > range_px:
		res["reason"] = "out_of_range"
		return res

	# La direzione del segmento e' l'angolo reale, non quello nominale del
	# guardiano: durante la svolta il cono ruota e bisogna che ruoti davvero.
	var look := rad_to_deg(atan2(d.y, d.x))
	res["angle_off"] = absf(angle_delta(look, facing_deg))

	if dist > near_radius and res["angle_off"] > half_angle_deg:
		res["reason"] = "out_of_cone"
		return res

	if segment_hits_any(eye, target, walls):
		res["blocked"] = true
		res["reason"] = "blocked"
		return res

	res["seen"] = true
	res["reason"] = "seen"
	return res


## Quanto velocemente si riempie il metro di rilevazione, da 0 a 1.
## Stabilisce quanto e' difficile farsi beccere: da lontano e accovacciato
## ci si vede lentamente.
static func detection_rate(res: Dictionary, max_range: float, crouching: bool) -> float:
	if not res.get("seen", false):
		return 0.0
	var closeness: float = 1.0 - clampf(res["dist"] / maxf(max_range, 1.0), 0.0, 1.0)
	var base: float = 0.35 + 0.85 * closeness        # 0.35 .. 1.20
	if crouching:
		base *= 0.55                                  # accovacciato dimezza
	if res["angle_off"] > 90.0:
		base *= 0.7                                   # alle spalle, meno sensibile
	return base
