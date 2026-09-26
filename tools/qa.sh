#!/usr/bin/env bash
# QA di Redbot: import, controlli, e avvio reale del gioco.
#
# Uso:  tools/qa.sh
#
# Due fasi, perche' una sola non basta:
#
#  1. la scena di QA esce con codice 1 se un controllo fallisce
#  2. il gioco vero parte per qualche secondo e si verifica che nel log non
#     ci sia NEANCHE UN "SCRIPT ERROR"
#
# La seconda fase e' quella che ha trovato i bug pignoli. Una scena di test
# puo' essere perfetta mentre il gioco che le gira intorno chiama un metodo
# che non esiste 700 volte al secondo. Il codice di uscita di Godot in
# headless non segnala gli errori di script, quindi il controllo e' sul testo
# del log, non sul codice di uscita.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Users/francescogrigoreteodor/Downloads/Godot.app/Contents/MacOS/Godot}"
LOG="${TMPDIR:-/tmp}/redbot_qa_$$.log"
BOOT_SECONDS="${BOOT_SECONDS:-12}"
fail=0

cleanup() { rm -f "$LOG" "$LOG.boot"; }
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
hr()  { say "-----------------------------------------------------"; }

hr
say "import"
if ! "$GODOT" --headless --import >"$LOG" 2>&1; then
	say "IMPORT FALLITO"
	grep -E "Parse Error|Compile Error|Failed to load" "$LOG" | sort -u
	exit 1
fi
if grep -qE "Parse Error|Compile Error" "$LOG"; then
	say "errori di compilazione:"
	grep -E "Parse Error|Compile Error" "$LOG" | sort -u
	fail=1
fi
say "compilazione: ok"

hr
say "controlli (tools/qa_idxbox.tscn)"
"$GODOT" --headless --path . res://tools/qa_idxbox.tscn >"$LOG" 2>&1
rc=$?
grep -E "^(===|\[|ESITO|  !)" "$LOG"
if [ "$rc" -ne 0 ]; then
	say "QA: uscita $rc"
	fail=1
fi
if grep -qE "^SCRIPT ERROR" "$LOG"; then
	say "errori di script durante i controlli:"
	grep -E "^SCRIPT ERROR" "$LOG" | sort | uniq -c | sort -rn
	fail=1
fi

hr
say "avvio reale del gioco (${BOOT_SECONDS}s, poi chiuso)"
"$GODOT" --headless --path . >"$LOG.boot" 2>&1 &
boot_pid=$!
sleep "$BOOT_SECONDS"
kill "$boot_pid" 2>/dev/null
wait "$boot_pid" 2>/dev/null
if grep -qE "^SCRIPT ERROR" "$LOG.boot"; then
	say "errori di script durante l'avvio:"
	grep -E "^SCRIPT ERROR" "$LOG.boot" | sort | uniq -c | sort -rn
	fail=1
else
	say "nessun errore di script"
fi
if grep -qE "Cannot|not found|Invalid" "$LOG.boot"; then
	say "avvisi sospetti:"
	grep -E "Cannot|not found|Invalid" "$LOG.boot" | sort -u | head -20
fi

hr
if [ "$fail" -eq 0 ]; then
	say "ESITO COMPLESSIVO: OK"
else
	say "ESITO COMPLESSIVO: FALLITO"
fi
exit "$fail"
