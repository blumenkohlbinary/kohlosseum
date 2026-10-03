---
name: mind-denkstufe
description: |
  [Mind Manager] ALWAYS invoke when the user asks which model or thinking level
  (effort) a RECURRING task should run at — or says "welche denkstufe", "welches
  modell", "reicht low", "braucht das high", "mind denkstufe", "/mind-denkstufe".

  Empfiehlt Modell UND Denkstufe (low/medium/high/xhigh/max, auch "lokales Modell")
  fuer eine wiederkehrende Aufgabe. Jede Aussage traegt BELEGT (mit Quelle) oder
  HERGELEITET — die Trennung ist der Zweck, nicht die Zierde.

  Liest eine Ablage, die ALLEN Projekten gemeinsam ist, und speichert die Antwort je
  Aufgabe: der zweite Aufruf rechnet NICHT neu. AENDERT nichts ausser dieser Ablage.

  ⛔ NICHT fuer die Frage, welche Stufe die LAUFENDE Sitzung gerade hat (das steht in
  `CLAUDE_EFFORT`), und nicht fuer einmalige Aufgaben — der Aufwand lohnt nur bei
  etwas, das wiederkehrt.
allowed-tools: Bash, Read, Glob, Grep, Agent, WebFetch
---

# Modell und Denkstufe fuer eine wiederkehrende Aufgabe

## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht

```
PFLICHTSCHRITTE
antwort_zuerst
aufgabe_verstehen
ablage_lesen
eigene_erfahrung
gegenprobe
antwort_speichern
```

**Vor dem ersten Schritt, ohne Ausnahme:**

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ=$(mind_projekt_wurzel)    # v5.80.0: der Ordner mit rollen.md, sonst cwd
# ⛔ v5.77.0: DIE VERSION DIESES SKILL-TEXTS. lib.sh vergleicht sie mit
#    basename "$CLAUDE_PLUGIN_ROOT" und meldet VERSIONSBRUCH, wenn ein alter
#    Text gegen neuen Code laeuft (Rita bekam am 10.09.2026 den Text aus 5.2.0).
#    ⚠ Wird beim Release nachgezogen; das Zaehl-Gate prueft alle elf.
#    ⛔ v5.125.0: DIESELBE Bash wie mind_schritt_start — sonst rc 1, keine Startzeile (Etappe 37 §3).
MIND_SKILL_VERSION="5.142.0"
mind_schritt_start "$PROJ" mind-denkstufe antwort_zuerst aufgabe_verstehen ablage_lesen eigene_erfahrung gegenprobe antwort_speichern

ARGS="${ARGUMENTS:-}"
NEU="no"; MESSEN="no"
echo "$ARGS" | grep -qE '(^|[[:space:]])--neu([[:space:]]|$)'    && NEU="yes"
echo "$ARGS" | grep -qE '(^|[[:space:]])--messen([[:space:]]|$)' && MESSEN="yes"
# Die Aufgabe ist alles, was keine Flagge ist.
AUFGABE=$(echo "$ARGS" | sed -E 's/--(neu|messen)//g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
[ -n "$AUFGABE" ] || { echo "ERROR: welche Aufgabe? /mind-denkstufe <Aufgabe oder /befehl>" >&2; exit 2; }
ABLAGE="$CLAUDE_PLUGIN_ROOT/references/denkstufe_ablage.py"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
```

**Nach JEDEM Schritt** — auch nach einem, der entfaellt:

```bash
mind_schritt <name> gelaufen                "$BYTES" "$PROJ"
mind_schritt <name> "uebersprungen:<grund>" 0        "$PROJ"
mind_schritt <name> "fehler:<grund>"        -1       "$PROJ"
```

---

## ⛔ DIE KOSTENREGEL STEHT VOR ALLEM ANDEREN

**Nutzer-Entscheidung 29.09.2026, woertlich:** *„koennt ihr diesen scheiss problauf aus
mind manager machen der kostet tokens so ein muell braucht kein mensch"* — und
allgemein: *„keine Probelaeufe mehr … ich will Ergebnisse sehen"*.

⭐ **Die Zahl, die alles entscheidet, ist gemessen — und sie steht NICHT hier.**
Ein Agentenlauf mit **Minimalauftrag** (eine Datei lesen, Zeilen zaehlen) kostete
gemessen ein Vielfaches dessen, was man einem leeren Lauf zutraut: **ein Agent ist
auch leer nicht billig**, und zwei Gegenproben sind das Doppelte davon — fuer EINE
Empfehlung. Der Messwert liegt in der Ablage unter `leerer-agent-tokens`, mit Quelle
und Datum.
⛔ **Nicht in diesem Text**, denn eine Zahl im Anleitungstext veraltet lautlos —
dieselbe Klasse, die dieses Projekt in `architecture.md` und in der globalen
`CLAUDE.md` je einmal gekostet hat. ⚠ **Ich habe die Regel beim Schreiben selbst
gebrochen** und die Zahl hier hingeschrieben, zwei Abschnitte ueber dem Satz, der sie
verbietet. `test_denkstufe_belegt.sh` haelt die Stelle jetzt frei.

**Daraus folgt, und es ist nicht verhandelbar:**

| | |
|---|---|
| **Schritt 1 ist immer die gespeicherte Antwort** | gibt es sie, endet der Lauf dort |
| **Websuche** | NUR wenn der Zwischenspeicher abgelaufen ist (`--alter` sagt es) |
| **Agenten-Gegenprobe** | NUR beim **ERSTaufruf** je Aufgabe, nie beim zweiten |
| **`--neu`** | rechnet neu — **auf Ansage**, nicht von selbst |

⛔ **Ein zweiter Aufruf, der wieder Agenten startet, ist ein Fehler**, kein
Gruendlichkeitsbeweis.

---

## Step 1 · `antwort_zuerst` — die gespeicherte Antwort (PFLICHT, zuerst)

```bash
if [ "$NEU" = "no" ] && "$PY" "$ABLAGE" --aufgabe "$AUFGABE" 2>/dev/null; then
  echo ""
  echo "⭐ Gespeicherte Antwort — KEIN Agent, KEINE Websuche, nichts neu gerechnet."
  echo "   Neu rechnen: /mind-denkstufe $AUFGABE --neu"
  mind_schritt antwort_zuerst gelaufen 1 "$PROJ"
  for s in aufgabe_verstehen ablage_lesen eigene_erfahrung gegenprobe antwort_speichern; do
    mind_schritt "$s" "uebersprungen:gespeicherte Antwort lag vor" 0 "$PROJ"
  done
  exit 0
fi
mind_schritt antwort_zuerst "uebersprungen:keine gespeicherte Antwort" 0 "$PROJ"
```

⛔ **Die uebersprungenen Schritte werden QUITTIERT, nicht verschwiegen.** Ein Lauf, der
fuenf Schritte auslaesst, weil er die Antwort schon hatte, ist vollstaendig — ein Lauf,
der sie unquittiert auslaesst, ist von einem abgebrochenen nicht zu unterscheiden
(`FEHLT` in der Bilanz, v5.130.0).

---

## Step 2 · `aufgabe_verstehen` — Merkmale erheben, nicht raten

**Ist die Aufgabe ein Befehl oder Skill** (beginnt mit `/` oder nennt einen Skillnamen),
**dann wird seine Datei GELESEN** — `$CLAUDE_PLUGIN_ROOT/skills/<name>/SKILL.md`, sonst
`~/.claude/skills/<name>/SKILL.md`. Sonst gilt die Beschreibung des Nutzers.

⛔ **Nicht aus dem Namen schliessen.** `/mind-cleaner` klingt nach Aufraeumen und
zerschneidet die Wissensbasis; `/mind-learnings` klingt nach Lernen und aendert nichts.

Erhoben wird, mit Begruendung je Merkmal:

| Merkmal | warum es die Stufe bewegt |
|---|---|
| Anteil **festes Skript** gegen **Urteil** | ein Skript laeuft auf jeder Stufe gleich; ein Urteil nicht |
| **Laenge der Kette** | viele Schritte heissen viele Werkzeugaufrufe — und die Stufe wirkt auf Werkzeugaufrufe (BELEGT) |
| schreibt **ohne Rueckfrage** in Dauerkontext oder Nutzerdaten | Fehlerkosten steigen, ein falsches Urteil bleibt stehen |
| **Fehlerkosten**: faellt ein Fehler auf, oder meldet er gruen? | ⭐ der schwerste Posten — ein zu schwacher Pruefer **meldet gruen und sieht aus wie vorher** |
| startet **Agenten**, und erben die die Stufe? | `effort:` im Frontmatter heisst nein, sonst ja (BELEGT, eigene Messung) |
| **vertrauliche Daten** | dann lokales Modell erwaegen |
| **Haeufigkeit** | taeglich mal teuer ist das Wochenlimit |

---

## Step 3 · `ablage_lesen` — und die Websuche bleibt die Ausnahme

```bash
"$PY" "$ABLAGE" --anlegen >/dev/null 2>&1      # nur wenn leer; ueberschreibt nie
"$PY" "$ABLAGE" --lesen
if "$PY" "$ABLAGE" --alter; then
  echo "⭐ Zwischenspeicher frisch — KEINE Websuche."
else
  echo "⚠ Zwischenspeicher abgelaufen — eine Websuche ist jetzt erlaubt."
  # Nach dem Holen: je Wert quelle/datum/vorbehalt setzen und --schreiben.
fi
```

⛔ **Keine Zahl steht in DIESEM Text.** Sie veraltet lautlos — dieselbe Klasse, die in
`architecture.md` und in der globalen `CLAUDE.md` schon zweimal eine feste Zahl gekostet
hat. Der Skill **liest** die Ablage, er zitiert sie nicht.

⛔ **Jede Kennzahl traegt `quelle`, `datum`, `vorbehalt`** — das Werkzeug weigert sich
sonst (rc 2). ⭐ Der `vorbehalt` ist kein Schmuck: die Benchmark-Zahlen zu den Stufen
stehen unter *„with fallback"*, und eine Pruefung meldet, dass **nur eine von fuenf**
davon einen Modellwechsel im Hintergrund ausschliesst. **Wandert der Vorbehalt nicht mit
der Zahl, ist die Zahl beim ersten Zitieren eine Behauptung.**

---

## Step 4 · `eigene_erfahrung` — das Projekt hat Messwerte, nicht nur Meinungen

```bash
# Befunde je Denkstufe — seit v5.141.0 traegt JEDE neue Zeile `stufe` und `modell`.
if [ -n "${MIND_DEBUG_DIR:-}" ] && [ -f "$MIND_DEBUG_DIR/index.jsonl" ]; then
  jq -r 'select(.stufe != null) | "\(.stufe)\t\(.klasse)"' "$MIND_DEBUG_DIR/index.jsonl" \
    2>/dev/null | sort | uniq -c | sort -rn
fi
```

⛔ **Und der Blick auf das Ergebnis ist GEDECKELT, nicht geraten:** Zeilen ohne `stufe`
sind **Altbestand** (vor v5.141.0) und sagen ueber die Stufe **nichts** — sie werden
gezaehlt und als „ohne Angabe" ausgewiesen, nie der heutigen Stufe zugeschlagen.
⚠ Solange die Zahl der Zeilen MIT Stufe klein ist, ist jede Aussage daraus
**HERGELEITET**, nicht BELEGT. Die Grenze dafuer wird **genannt**, nicht erfunden:
unter 30 Zeilen je Stufe steht im Bericht „zu wenige Faelle fuer eine Aussage".
⛔ **Diese 30 ist GESETZT, nicht gemessen** — ausgewiesen, damit sie niemand
fuer einen Befund liest.

Dazu `listeverbesserungen.md` im Projekt: welche Laeufe Befunde brachten und welche nicht.

---

## Step 5 · `gegenprobe` — zwei Agenten, JE GEGEN EINE THESE

**Nur beim ERSTaufruf je Aufgabe.** Zwei Agenten, blockierend, `model: sonnet`,
Denkstufe `low`/`medium` (`~/.claude/rules/workflow-agent-rate-limit.md`):

| Agent | Auftrag |
|---|---|
| **A** | *Finde die staerksten Gruende, dass eine NIEDRIGE Stufe fuer diese Aufgabe genuegt.* |
| **B** | *Finde die staerksten Gruende, dass diese Aufgabe eine HOHE Stufe braucht.* |

⛔ **Beide gegen die jeweils andere These, nicht beide fuer die eigene Vermutung** —
`workflow-agent-rate-limit.md`: *„Bei vier Agents einer GEGEN die eigene These."* Hier
sind es zwei, also **einer je Richtung**. Ein Paar, das in dieselbe Richtung sucht,
bestaetigt den Auftraggeber und misst nichts.

⛔ **In den Auftrag gehoert, was der Agent NICHT sieht** (er hat kein Memory, keine
Historie): die erhobenen Merkmale, die Aufgabe im Wortlaut, und **ausdruecklich**
*„starte keine eigenen Agenten"* (gemessen 17.09.2026: Sub-Agenten starten ungefragt
eigene).

⚠ **Ein leerer Agent ist ein Problem, kein „unauffaellig".** Kommt einer mit 0 Byte
zurueck, gilt seine Richtung als **ungeprueft** und steht so im Bericht — nicht als
„keine Gegengruende gefunden".

---

## Step 6 · `antwort_speichern` — die Ausgabe, und jede Zeile traegt ihre Herkunft

```
Aufgabe:     <Wortlaut>
Empfehlung:  Modell <…>, Denkstufe <low|medium|high|xhigh|max>

BEGRUENDUNG
  BELEGT       <Aussage>                        Quelle: <URL oder eigene Messung>  (<Datum>)
  HERGELEITET  <Aussage>
  UNGEPRUEFT   <Richtung, deren Agent leer zurueckkam>

GEGENSTIMMEN  (die staerksten Gruende GEGEN die Empfehlung — nie weggelassen)
  BELEGT       <…>
```

⛔ **Eine Empfehlung ohne Gegenstimmen wird nicht ausgegeben.** Gibt es keine, steht da
*„keine gefunden"* — und das ist eine Aussage, die man pruefen kann. Ein Bericht, der
nur Zustimmung enthaelt, hat nicht gesucht.
⛔ **`BELEGT` ohne Quelle ist verboten** — das Werkzeug lehnt es ab (rc 2), und zwar in
derselben Sekunde, in der man es versucht.

```bash
# Antwort als JSON schreiben, dann speichern (das Werkzeug prueft die Gates):
"$PY" "$ABLAGE" --schreiben "$AUFGABE" --json "$TMP/antwort.json"
```

---

## `--messen` — nur auf ausdrueckliche Ansage

Die Aufgabe auf einer **Kopie** mit zwei Stufen fahren und die Ergebnisse vergleichen.
⭐ **Das ist der einzige echte Nachweis** — die Doku sagt es woertlich und mehrfach:
*„Run a fresh effort sweep on your own evals rather than carrying settings over."*

⛔ **VORHER melden, was es kostet** (zwei volle Laeufe der Aufgabe, nicht zwei Agenten).
⛔ **Aufgaben mit AUSSENWIRKUNG sind nicht messbar** — Push, Nachricht, Nutzerdaten,
alles Unumkehrbare. Dann **melden, nicht fahren**:

> *„`<Aufgabe>` schreibt nach aussen (<was>). Zwei Laeufe waeren zwei Wirkungen —
> nicht messbar. Mess- statt Wirkungsweg: <Vorschlag> oder eine Kopie ohne Zielsystem."*

⚠ **Das ist KEIN Probelauf im Sinn des 29.09.** Dort war es derselbe Lauf **vorab und
ohne Wirkung** — reine Kosten ohne Ergebnis. Hier ist es eine **Messung auf Bestellung**,
die eine Frage beantwortet, die sonst unbeantwortet bleibt. Der Unterschied steht hier,
damit niemand das eine fuer das andere haelt und es wieder herausnimmt.

---

## Hard Constraints

- `MUST` **gespeicherte Antwort zuerst** — immer, vor jedem anderen Schritt
- `MUST` jede Aussage `BELEGT` (mit Quelle) oder `HERGELEITET`; **`NEVER` `BELEGT` ohne Quelle**
- `MUST` Gegenstimmen ausgeben; gibt es keine, **`NEVER` weglassen** — *„keine gefunden"* hinschreiben
- `MUST` Gegenprobe **nur beim Erstaufruf** je Aufgabe
- `NEVER` eine Websuche bei frischem Zwischenspeicher — **stattdessen** die Ablage lesen
- `NEVER` eine feste Kennzahl in diesen Text schreiben — **stattdessen** in die Ablage, mit `quelle`/`datum`/`vorbehalt`
- `NEVER` `--messen` ohne ausdrueckliche Ansage, und `NEVER` bei Aussenwirkung — **stattdessen** als nicht messbar melden
- `NEVER` die eigene Sitzungsstufe als Empfehlung ausgeben — sie ist der Zufall der Umgebung, kein Befund
- ⚠ `MIND_DENKSTUFE_DIR` liegt unter `~/.claude/` und damit **ausserhalb** des Sicherungs-Hooks. Jedes Schreiben legt eine Kopie nach `_claude_backups/`; die Kennzahlen sind ohnehin neu holbar, die **Antworten je Aufgabe nicht** — sie haben Agenten gekostet
