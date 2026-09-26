extends RefCounted
class_name Level
## Caricamento e validazione dei dati di livello.
##
## I livelli sono dati, non scene. Motivo pratico: un livello di stealth e'
## soprattutto geometria (muri, zone d'ombra, pattuglie) e la geometria e'
## molto piu' facile da verificare da codice che a occhio. tools/qa_idxbox.gd
## carica tutti i livelli e segnala quelli incoerenti.

const DIR := "res://data/levels/"


static func load_id(id: String) -> Dictionary:
	var path := DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("Level: mancante " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Level: json non valido in " + path)
		return {}
	return build(parsed, id)


static func build(d: Dictionary, id: String) -> Dictionary:
	var size: Array = d.get("size", [1920, 1080])
	var out := {
		"id": id,
		"name_key": d.get("name_key", "LEVEL_%s" % id.to_upper()),
		"size": Vector2(float(size[0]), float(size[1])),
		"player_start": _v2(d.get("player_start", [0, 0])),
		"relic": _v2(d.get("relic", [0, 0])),
		"walls": [],
		"shadows": [],
		"guardians": [],
		"bolts": [],
		"checkpoints": [],
		"doors": [],
		"keys": [],
		"errors": [],
	}
	for w in d.get("walls", []):
		out["walls"].append(_rect(w))
	for s in d.get("shadows", []):
		out["shadows"].append(_rect(s))
	for b in d.get("bolts", []):
		out["bolts"].append(_v2(b))
	for c in d.get("checkpoints", []):
		out["checkpoints"].append(_v2(c))
	for dd in d.get("doors", []):
		out["doors"].append(_rect(dd))
	for kk in d.get("keys", []):
		out["keys"].append(_v2(kk))
	for g in d.get("guardians", []):
		var path_pts: Array = []
		for p in g.get("patrol", []):
			path_pts.append(_v2(p))
		out["guardians"].append({
			"pos": _v2(g.get("pos", [0, 0])),
			"patrol": path_pts,
			"speed": float(g.get("speed", 50.0)),
			"range": float(g.get("range", 420.0)),
			"half_angle": float(g.get("half_angle", 36.0)),
			"near_radius": float(g.get("near_radius", 70.0)),
			"catch_radius": float(g.get("catch_radius", 54.0)),
		})
	out["errors"] = validate(out)
	return out


static func _v2(a: Variant) -> Vector2:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


static func _rect(a: Variant) -> Rect2:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 4:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Rect2()


## Errori che rendono il livello ingiocabile. Non e' un controllo di stile:
## sono le cose che fanno crashare o bloccare il giocatore.
static func validate(lv: Dictionary) -> Array[String]:
	var err: Array[String] = []
	var size: Vector2 = lv["size"]
	var bounds := Rect2(Vector2.ZERO, size)

	for key in ["player_start", "relic"]:
		var p: Vector2 = lv[key]
		if not bounds.grow(-8.0).has_point(p):
			err.append("%s fuori dai bordi: %s" % [key, str(p)])
		if _in_any(p, lv["walls"]):
			err.append("%s dentro un muro: %s" % [key, str(p)])

	if lv["bolts"].is_empty():
		err.append("nessun vitone: il giocatore non puo' distrarre nessuno")

	for i in lv["guardians"].size():
		var g: Dictionary = lv["guardians"][i]
		if (g["patrol"] as Array).size() < 2:
			err.append("guardia %d: pattuglia con meno di 2 punti" % i)
		for j in (g["patrol"] as Array).size():
			if not bounds.grow(-8.0).has_point(g["patrol"][j]):
				err.append("guardia %d: punto pattuglia %d fuori dai bordi" % [i, j])
		if g["range"] <= 0.0:
			err.append("guardia %d: portata di vista zero" % i)
		if g["half_angle"] <= 0.0 or g["half_angle"] > 90.0:
			err.append("guardia %d: cono di vista fuori 0..90 gradi" % i)
		if g["catch_radius"] >= g["range"]:
			err.append("guardia %d: raggiunge il player prima di vederlo" % i)

	if lv["shadows"].is_empty():
		err.append("nessuna zona d'ombra: niente stealth")

	if lv["checkpoints"].is_empty():
		err.append("nessun checkpoint: un errore costringe a ricominciare il livello")

	if lv.get("doors", []).is_empty():
		err.append("nessuna porta: il livello e' lineare, nessuna scelta di percorso")

	return err


static func _in_any(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


## Connessione raggiungibile fra checkpoint e reliquia saltando i muri?
## Non e' pathfinding completo: e' una verifica grossolana che il livello
## non sia diviso in due meta' irraggiungibili. Serve a evitare di consegnare
## un livello che la QA non puo' completare.
static func relic_connected(lv: Dictionary, samples: int = 160) -> bool:
	var size: Vector2 = lv["size"]
	var start: Vector2 = lv["player_start"]
	var goal: Vector2 = lv["relic"]
	var walls: Array = lv["walls"]
	var step := size.x / float(samples)
	# BFS su griglia grossolana
	var key := func(p: Vector2) -> Vector2i:
		return Vector2i(int(p.x / step), int(p.y / step))
	var seen := {}
	var q: Array[Vector2] = [start]
	seen[key.call(start)] = true
	var g: Vector2i = key.call(goal)
	var guard := 0
	while not q.is_empty() and guard < 200000:
		guard += 1
		var p: Vector2 = q.pop_back()
		if key.call(p) == g:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := p + Vector2(d) * step
			if not Rect2(Vector2.ZERO, size).has_point(n):
				continue
			if LOS.point_in_any(n, walls):
				continue
			# Le zone d'ombra NON sono muri: ci si passa dentro, e anzi sono
			# la strada giusta. Trattarle come ostacoli rendeva la reliquia
			# "irraggiungibile" perche' il bersaglio e' dentro un'ombra.
			var k: Vector2i = key.call(n)
			if seen.has(k):
				continue
			seen[k] = true
			q.append(n)
	return false
