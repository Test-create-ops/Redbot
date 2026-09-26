# Redbot — Game Concept

Documento per **ID@Xbox**. Non è un pitch generico: è il modulo che va
compilato nel portale, con la build dimostrabile accanto.

> Stato: bozza di lavoro. Le sezioni marcate **[da confermare]** sono proposte
> di lavoro, non decisioni prese. Vanno confermate prima dell'invio.

---

## 1. Informazioni generali

| Campo | Valore |
|---|---|
| Titolo di lavoro | **Redbot** |
| Sviluppatore | **[da confermare]** |
| Editore | self-published |
| Piattaforme | Xbox Series X\|S, Xbox One |
| Data prevista | H1 2028 **[da confermare]** |
| Prezzo previsto | 19,99 USD **[da confermare]** |
| Genere | Action & adventure / Stealth |
| Engine | Godot 4.7 |
| Modalità | Single player |
| Lingue | inglese, italiano |
| Xbox Network | Achievements, nessun multiplayer **[da confermare]** |
| UGC | nessuno in v1 |

## 2. Descrizione del gioco

Sei un piccolo robot di manutenzione in un impianto dismesso. Non sei un
eroe e non hai un'arma: sei piccolo, e le cose che ti danno la caccia sono
più grandi di te.

Non puoi vincere nessuno scontro. L'unica cosa che ti resta è non farti
trovare.

**Il gioco è:** uno stealth-action 2D a vista dall'alto, a livelli brevi e
densi, costruito attorno a una sola domanda: *posso attraversare questa stanza
senza che nessuno se ne accorga?*

## 3. Meccaniche

Sei verbi, e sono tutti rumore. Non c'è un bottone d'attacco.

| Verbo | Tasto | Cosa fa |
|---|---|---|
| Muoversi | D-pad / stick | 8 direzioni |
| **Accovacciarsi** | LB (tieni premuto) | Più lento, profilo più basso, **mezza velocità di rilevamento** |
| **Schivare** | X | Rotolata con brevi frame di invulnerabilità. Il modo per attraversare un cono di vista |
| **Lanciare** | Y | Un vitone. Non fa male: fa rumore e attira. È l'unico modo per spostare una guardia *senza* essere visto |
| **Osservare** | RB (tieni premuto) | Mostra i coni di vista e le zone d'ombra |
| Interagire | A | Raccogliere un vitone, prendere la reliquia |
| Riavvia l'incontro | L3 | Torna al checkpoint |

**Le guardie** hanno cono di vista, distanza, e un metro di allarme che si
riempie con la vicinanza. Non ti inseguono perché ti odiano: ti inseguono
perché ti hanno visto. Se ti perdono di vista, vengono a verificare dove ti
avevano visto e poi tornano al giro.

**L'ombra è un volume, non uno stile.** Un pilastro proietta una zona in cui
non sei visibile, indipendentemente da cosa hai davanti.

**Il fallimento non è morte.** Le guardie non ti fanno del male: ti mettono
fuori. Non c'è sangue, non c'è punizione, non si perde niente.

**Checkpoint frequenti.** Il riavvio è immediato (L3) e si torna dal
checkpoint più vicino, perché in un gioco di stealth la morte è un evento
normale e non deve essere una punizione.

## 4. Perché funziona su Xbox

Non è un argomento sulla certificazione, è un argomento sul *posizionamento*,
e va detto perché il concept review lo valuta.

- **Nessuna violenza esplicita.** Niente sangue, niente armi da fuoco usate
  contro persone, niente morte. Il protagonista è un robot, le guardie sono
  macchine. Rientra in tutti i generi, quindi è "family friendly" per
  definizione e non per dichiarazione.
- **Fallibilità bassa, punizione bassa.** Un giocatore può fallire spesso
  senza perdere nulla. Questo tiene la classificazione IARC bassa e il
  giocatore è più propenso a continuare a giocare, non meno.
- **Sessioni corte.** Livelli da 5–10 minuti: è un gioco da 20 minuti di
  console, e si lascia in piedi.
- **Si capisce in dieci secondi.** Il cono di vista è letteralmente un cono
  disegnato a terra. Il primo screen dice al giocatore cosa fare senza una
  parola di tutorial.

## 5. Materiale di riferimento

**Concept in un'immagine:** `[da produrre — screenshot del primo livello con
il cono di vista e le zone d'ombra]`

**Video di gameplay:** `[da produrre — 60-90 secondi, un livello completo,
zero montaggio, niente musica above]`

**Build dimostrabile:** questo progetto (`/Users/francescogrigoreteodor/Redbot`),
vertical slice giocabile su PC e su console con pad.

**Note per il piano:** i placeholder grafici sono forme piatte colorate
(Polygon2D). Non sono il piano estetico: il piano è 2D stilizzato con
illuminazione a due toni. Serve artista 2D. La geometria di gioco — coni,
ombre, muri, checkpoint — è già definitivo ed è ciò che la QA numerica
verifica.

## 6. Comparables

| Titolo | Cosa prendiamo |
|---|---|
| Mark of the Ninja | Leggibilità del cono di vista; il nemico è una macchina, non un soldato |
| Shadows of Doubt | Il mistero come struttura, non come storia raccontata |
| Inside | Il rumore come risorsa e come punizione; la gravità del fallimento |
| Hollow Knight | Lettura istantanea del pericolo attraverso la sola forma |
| Rain World | Reazioni non scriptate delle guardie |

## 7. Stato tecnico e requisiti di piattaforma

Cose già fatte nel progetto, che la certificazione pretende e che da sole
costano tempo se si rimandano:

- [x] InputMap costruito in codice, **ogni azione ha un binding da gamepad**
- [x] Nessun gameplay dipende dal mouse
- [x] Safe area al 5% su tutti gli schermi (overscan TV)
- [x] Ogni schermata ha esattamente un elemento con il focus: niente input morto
- [x] Salvataggi versionati, con checksum, backup e scrittura atomica
- [x] Migrazione esplicita degli schemi di salvataggio
- [x] Impostazioni persistenti con scrittura differita
- [x] Sospensione e ripresa senza perdita di stato
- [x] Controller scollegato → pausa automatica con richiesta di ricollegamento
- [x] Localizzazione con dominio esplicito e controllo automatico delle chiavi
- [x] **Zero dipendenze di rete**
- [x] QA headless automatica: 190 controlli, incluso un test che gioca davvero
      e uno che preme i pulsanti del menu verificando che portino davvero
      allo schermo promesso

Non fatto, e va detto: nessun remap dei comandi a schermo, nessuna
localizzazione oltre en/it, audio non ancora implementato, arte non ancora
prodotta.

## 8. Verifica

```
tools/qa.sh
```

Importa, esegue i controlli e avvia il gioco vero verificando che non ci sia
**nessun errore di script** nel log. È il controllo che ha trovato i difetti
veri: i guardiani fermi per un array non tipizzato, la linea di vista che non
colpiva, ogni salvataggio con un intero perso al primo reload.
