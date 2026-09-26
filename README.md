# Redbot

Stealth-action 2D in Godot 4.7. Progetto separato da `redbot-1`.

La regola del gioco è in una frase: **non puoi vincere un combattimento, puoi
solo non farti vedere.** Non c'è un bottone d'attacco. Gli unici verbi sono
muoversi, accovacciarsi, schivare, lanciare un rumore e osservare.

Documento per ID@Xbox: [`CONCEPT.md`](CONCEPT.md).

## Provare

```bash
tools/qa.sh                       # import + controlli + avvio reale
/Users/francescogrigoreteodor/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

Comandi: D-pad o WASD per muoversi, **LB** accovacciati, **X** schivata,
**Y** lancia un vitone, **RB** mostra i coni, **A** interagisci, **L3** riavvia
dal checkpoint, **B** pausa.

## Struttura

```
autoload/     InputMap, impostazioni, salvataggi, macchina a stati
scripts/      gameplay (los, player, guardian, bolt, world, level)
scripts/ui/   menu e schermate
data/levels/  geometria dei livelli, in JSON
locale/       traduzioni en/it
tools/        QA headless
```

I livelli sono **dati**, non scene: un livello di stealth è soprattutto muri,
ombre e pattuglie, e la geometria si verifica molto meglio da codice che a
occhio. `data/levels/level_01.json` è leggibile e commentabile.

## Perché il codice è fatto in questo modo

**La linea di vista è una funzione pura.** `scripts/los.gd` non ha nodi, non
fa `get_node`, non ha `await`: prende punti e rettangoli e restituisce un
dizionario. Un meccanica che si può interrogare con una riga di codice si può
testare in headless, e un errore nella linea di vista è invisibile guardando
il gioco — rende il gioco troppo facile o impossibile, e in entrambi i casi
sembra "sbagliato" senza che si sappia perché.

**L'InputMap è costruito in codice** (`autoload/input_setup.gd`) per poter
essere verificato: `actions_without_gamepad()` deve restare vuota. Scritto a
mano in `project.godot`, quel controllo non sarebbe possibile, e un'azione
irraggiungibile con il pad è esattamente il difetto che blocca la
certificazione.

**I salvataggi sopravvivono a un file rotto.** Checksum su una forma
canonica, backup, scrittura atomica, migrazione esplicita. Nota: il checksum
non può essere `md5(JSON.stringify(body))`, perché `JSON.parse_string`
restituisce i numeri come float e il testo ricalcolato non corrisponderebbe
mai — ogni salvataggio con un intero andrebbe perso al primo reload.

**I livelli si validano all'avvio e in QA.** `Level.validate()` segnala
condizioni che rendono il livello ingiocabile; `Level.relic_connected()` fa un
BFS e verifica che l'obiettivo sia raggiungibile.

## QA

`tools/qa.sh` esegue tre fasi:

1. **compilazione** — nessun errore di parse
2. **controlli** (`tools/qa_idxbox.tscn`) — 190 controlli su input da gamepad,
   safe area e focus, linea di vista, livelli, salvataggi, impostazioni,
   localizzazione, assenza di rete, un test che **gioca davvero** (le guardie
   si muovono, il giocatore davanti a una guardia viene visto, il giocatore
   nell'ombra no, il rumore fa sospettare senza mettere in allarme) e uno che
   **preme i pulsanti del menu** verificando che lo stato cambi davvero
3. **avvio reale** — il gioco parte per 12 secondi e il log non deve
   contenere **nessun `SCRIPT ERROR`**

La terza fase non è pignoleria. Una scena di test può essere perfetta mentre
il gioco che le gira intorno chiama 700 volte al secondo un metodo che non
esiste, e il codice di uscita di Godot in headless non lo segnala: va letto il
log.

## Stato

Funziona: movimento, schivata, accovacciato, coni di vista, volumi d'ombra,
pattuglie con memoria, allarme a tre stati, lancio di vitoni con rimbalzo e
rumoro, raccolta della reliquia, menu, pausa, checkpoint, salvataggi,
impostazioni, localizzazione en/it.

Non fatto: arte (i placeholder sono forme piatte), audio, remap dei comandi a
schermo, livelli oltre il primo, schermata dei crediti.
