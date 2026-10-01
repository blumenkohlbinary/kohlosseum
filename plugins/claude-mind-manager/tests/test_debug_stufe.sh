#!/bin/bash
. "$(dirname "$0")/lib_test.sh"
# Pruefstand fuer Modell und Stufe in jeder Debug-Befundzeile (v5.141.0, Etappe 52 §0b).
#
# ⛔ DIE FRAGE IST NICHT "steht ein Feld da?", sondern:
#    Kann man einen Befund spaeter nach der Stufe auswerten, auf der er entstanden ist?
#    Dafuer muessen BEIDE Felder auf JEDER Zeile stehen — auch wenn nichts bestimmbar war.
#    Ein fehlendes Feld und ein unbekannter Wert sehen in der Auswertung gleich aus.
#
# ⛔ GEGENKONTROLLE IST TEIL DER SAMMLUNG, nicht ein Anhang:
#    · eine Zeile, die die Stufe SELBST nennt, darf NICHT ueberschrieben werden
#    · eine kaputte Zeile muss WEITERHIN verworfen werden (altes Verhalten)
#    · `unbekannt` muss als WERT erscheinen, nicht als fehlendes Feld
#
# ⚠ FALLE, in die diese Sammlung selbst getreten ist: `CLAUDE_EFFORT` ist in der
#   Sitzung, die den Lauf startet, GESETZT (gemessen: `high`). Wer sie nicht ausdruecklich
#   leert, prueft den Rueckfall nie — er prueft zweimal denselben Zweig.

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"

ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

T=$(mktemp -d)
command -v jq >/dev/null 2>&1 || { echo "  jq fehlt — diese Sammlung braucht es"; exit 1; }

# --- 0 · VAKUUM-WAECHTER: gibt es den Gegenstand ueberhaupt? ------------------
# ⛔ Zwei Zusicherungen einer frueheren Etappe waren gruen, WEIL die Funktion fehlte
#    (tests/README.md). Deshalb steht diese Frage vor allen anderen.
pruef "mind_stufe ist definiert" \
  "$(type -t mind_stufe 2>/dev/null)" "function"
pruef "mind_modell ist definiert (wird benutzt, nicht nachgebaut)" \
  "$(type -t mind_modell 2>/dev/null)" "function"

# --- 1 · Quelle 1: die Umgebungsvariable gilt und kostet keinen Dateizugriff ---
pruef "CLAUDE_EFFORT wird genommen" \
  "$(CLAUDE_EFFORT=medium mind_stufe)" "medium"
pruef "... auch ohne Transkript-Argument" \
  "$(CLAUDE_EFFORT=xhigh mind_stufe "/gibt/es/nicht")" "xhigh"

# --- 2 · Quelle 2: das Transkript, wenn die Variable leer ist -----------------
TR="$T/sitzung mit leer.jsonl"       # Leerzeichen im Pfad: hier heisst ein Ordner so
{
  printf '{"type":"assistant","effort":"low","message":{"model":"claude-sonnet-5-5"}}\n'
  printf '{"type":"user","message":{"content":"x"}}\n'
  printf '{"type":"assistant","effort":"max","message":{"model":"claude-opus-5"}}\n'
} > "$TR"
pruef "ohne Variable liest es das Transkript" \
  "$(CLAUDE_EFFORT= mind_stufe "$TR")" "max"
pruef "... und nimmt die LETZTE Stufe, nicht die erste" \
  "$(CLAUDE_EFFORT= mind_stufe "$TR" | grep -c '^max$')" "1"

# --- 2b · die <synthetic>-Falle, an der mind_modell haengt --------------------
# ⛔ Gemessen 01.10.2026: `.effort` steht auf keiner synthetischen Zeile. Diese Zeile
#    haelt fest, dass eine synthetische LETZTE Zeile die Stufe nicht verdeckt — sonst
#    waere der fehlende `grep -v '^<'`-Filter in mind_stufe eine Luecke statt einer
#    begruendeten Auslassung.
printf '{"type":"assistant","message":{"model":"<synthetic>"}}\n' >> "$TR"
pruef "synthetische Schlusszeile verdeckt die Stufe nicht" \
  "$(CLAUDE_EFFORT= mind_stufe "$TR")" "max"
pruef "... und mind_modell liest dort NICHT <synthetic>" \
  "$(CLAUDE_EFFORT= mind_modell "$TR")" "claude-opus-5"

# --- 3 · nicht bestimmbar: rc 1 und LEERE Ausgabe, kein geratener Wert --------
_s=$(CLAUDE_EFFORT= mind_stufe "/gibt/es/nicht" 2>/dev/null); _rc=$?
pruef "nicht bestimmbar -> rc 1"      "$_rc" "1"
pruef "nicht bestimmbar -> leer"      "$_s"  ""

# --- 4 · die Befundzeile traegt BEIDE Felder ---------------------------------
export MIND_DEBUG_DIR="$T/debug"
printf '# Bericht\n' > "$T/bericht.md"
printf '{"ts":"2026-10-01 18:00","projekt":"/x/p","klasse":"sonstiges","kurz":"a","lauf":"L1"}\n' > "$T/b1.jsonl"
CLAUDE_EFFORT=high mind_debug_write "/x/p" "test" "$T/bericht.md" "$T/b1.jsonl"
Z1=$(tail -1 "$MIND_DEBUG_DIR/index.jsonl")
pruef "Zeile ist weiterhin gueltiges JSON" \
  "$(printf '%s\n' "$Z1" | jq -e . >/dev/null 2>&1 && echo ja || echo nein)" "ja"
pruef "stufe steht in der Zeile"  "$(printf '%s\n' "$Z1" | jq -r '.stufe')"  "high"
pruef "modell steht in der Zeile" "$(printf '%s\n' "$Z1" | jq -r '.modell != null')" "true"
pruef "der urspruengliche Inhalt ist unberuehrt" \
  "$(printf '%s\n' "$Z1" | jq -r '.klasse')" "sonstiges"

# --- 5 · nicht bestimmbar heisst `unbekannt` — ALS WERT, nicht als Leerstelle --
printf '{"ts":"2026-10-01 18:05","projekt":"/x/p","klasse":"sonstiges","kurz":"b","lauf":"L2"}\n' > "$T/b2.jsonl"
( unset CLAUDE_EFFORT; HOME="$T/kein-home" mind_debug_write "/x/p" "test" "$T/bericht.md" "$T/b2.jsonl" )
Z2=$(tail -1 "$MIND_DEBUG_DIR/index.jsonl")
pruef "ohne jede Quelle: stufe=unbekannt"  "$(printf '%s\n' "$Z2" | jq -r '.stufe')"  "unbekannt"
pruef "ohne jede Quelle: modell=unbekannt" "$(printf '%s\n' "$Z2" | jq -r '.modell')" "unbekannt"
pruef "das Feld FEHLT nicht (hat-Pruefung)" \
  "$(printf '%s\n' "$Z2" | jq -r 'has("stufe")')" "true"
pruef "und ist nicht die leere Zeichenkette" \
  "$(printf '%s\n' "$Z2" | jq -r '.stufe | length > 0')" "true"

# --- 6 · GEGENKONTROLLE: eine Zeile, die es selbst sagt, wird NICHT ueberschrieben ---
# ⛔ ZWEI Zeilen in EINEM Lauf, und das ist der ganze Punkt. Mit nur der ersten Zeile war
#    diese Pruefung VAKUUM-GRUEN: gegen den alten Stand bestand sie, weil dort niemand
#    etwas anreicherte — "nicht ueberschrieben" und "gar kein Mechanismus" sahen gleich aus
#    (gemessen 01.10.2026 am Altstand, dieselbe Klasse wie in tests/README.md).
#    Die zweite Zeile ohne eigene Angabe MUSS im selben Lauf angereichert werden; damit
#    unterscheidet der Fall "behaelt den eigenen Wert" von "tut nichts".
{
  printf '{"ts":"2026-09-01 09:00","projekt":"/x/p","klasse":"sonstiges","kurz":"alt","lauf":"L3","stufe":"low","modell":"claude-fable-5-1"}\n'
  printf '{"ts":"2026-09-01 09:01","projekt":"/x/p","klasse":"sonstiges","kurz":"neu","lauf":"L3"}\n'
} > "$T/b3.jsonl"
CLAUDE_EFFORT=max mind_debug_write "/x/p" "test" "$T/bericht.md" "$T/b3.jsonl"
# ⚠ KEIN `tail -2 | head -1`: `head` schliesst die Pipe und schickt dem Vorlauf SIGPIPE
#   (shell-windows.md). Hier harmlos, aber das Muster wird nicht geuebt — erst in eine
#   Datei, dann zeilenweise lesen.
tail -2 "$MIND_DEBUG_DIR/index.jsonl" > "$T/letzte2.jsonl"
Z3=$(sed -n '1p' "$T/letzte2.jsonl")
Z3B=$(sed -n '2p' "$T/letzte2.jsonl")
pruef "eigene stufe bleibt stehen"  "$(printf '%s\n' "$Z3" | jq -r '.stufe')"  "low"
pruef "eigenes modell bleibt stehen" "$(printf '%s\n' "$Z3" | jq -r '.modell')" "claude-fable-5-1"
pruef "... und die Zeile daneben wird im SELBEN Lauf angereichert" \
  "$(printf '%s\n' "$Z3B" | jq -r '.stufe')" "max"

# --- 7 · GEGENKONTROLLE: das alte Verhalten ist NICHT mitgeloescht ------------
# ⛔ autonom-arbeiten.md: Verhalten, auf das sich jemand verlaesst, wird beim Umbau nicht
#    still mitgeloescht. Die JSON-Pruefung aus v5.126.0 muss weiter verwerfen.
VOR=$(wc -l < "$MIND_DEBUG_DIR/index.jsonl" | tr -d ' ')
printf 'das ist kein JSON\n' > "$T/b4.jsonl"
CLAUDE_EFFORT=high mind_debug_write "/x/p" "test" "$T/bericht.md" "$T/b4.jsonl" 2>/dev/null
NACH=$(wc -l < "$MIND_DEBUG_DIR/index.jsonl" | tr -d ' ')
pruef "kaputte Zeile wird weiterhin verworfen" "$NACH" "$VOR"

# --- 8 · jede Zeile im Index ist gueltig UND vollstaendig --------------------
pruef "keine Zeile ohne stufe" \
  "$(jq -s -r '[.[] | select(has("stufe") | not)] | length' "$MIND_DEBUG_DIR/index.jsonl" 2>/dev/null)" "0"
pruef "keine Zeile ohne modell" \
  "$(jq -s -r '[.[] | select(has("modell") | not)] | length' "$MIND_DEBUG_DIR/index.jsonl" 2>/dev/null)" "0"

rm -rf "$T"
echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
