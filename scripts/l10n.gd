extends RefCounted
class_name L10n
## Accesso alle stringhe localizzate.
##
## Perche' esiste questo helper e non basta `tr()`:
##
##  - `tr()` funziona, ma il dominio di ricerca e' dedotto dal path dello
##    script e non e' ispezionabile. Se un giorno il CSV cambia nome, `tr()`
##    restituisce silenziosamente la chiave grezza e a schermo compare
##    "MENU_RESUME" invece di "Riprendi".
##  - Su Xbox un testo non tradotto non da' alcun errore: appare e basta. Il
##    modo piu' comune di scoprire di non aver localizzato niente e' giocare
##    in inglese senza accorgersene.
##
## Quindi: punto di accesso unico, e un avviso rumoroso quando una chiave non
## esiste. La chiave mancante viene anche controllata dalla QA, che la cerca
## nel sorgente con un'espressione regolare.

const DOMAIN := "game"

static var _seen_missing := {}


## Traduzione per la lingua corrente. Se la chiave non esiste, la segnala una
## volta sola: durante il gioco non deve comparire nulla a schermo, e in
## sviluppo deve essere rumoroso.
static func t(key: String) -> String:
	var out := TranslationServer.translate(key)
	if out == key and not _seen_missing.has(key):
		_seen_missing[key] = true
		if OS.is_debug_build():
			push_warning("L10n: chiave mancante nelle traduzioni: " + key)
	return out
