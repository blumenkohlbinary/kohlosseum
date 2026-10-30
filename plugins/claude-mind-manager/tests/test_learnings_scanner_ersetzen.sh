#!/usr/bin/env bash
# test_learnings_scanner_ersetzen.sh — /mind-learnings Step 3 ersetzt Scanner-Zeilen statt sie anzuhaengen (v5.174.0)
#
# ⛔ ZIEL 15: `debug_aufraeumen.py --scanner-neu` war gebaut (v5.9.2) und wurde von KEINEM Skill gerufen.
#    Behobene Scanner-Befunde (`lauf=mind-learnings`) blieben im Index stehen und zaehlten in BEFUNDE.md
#    als Wiederholung. Diese Sammlung faehrt den ECHTEN Block aus SKILL.md Step 3 an einem Fixture.
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GRUEN=0; ROT=0
pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

S="$(skill_text_datei "$R" mind-learnings)"
BLOCK=$(awk '/^## Step 3: Nach Debug melden/{f=1} f&&/^```bash/{b=1;next} b&&/^```/{exit} b{print}' "$S")
pruef "Step-3-Block gefunden und ruft debug_aufraeumen --scanner-neu" 1 \
  "$(printf '%s\n' "$BLOCK" | grep -c 'debug_aufraeumen.py.*--scanner-neu')"

F="${TMPDIR:-/tmp}/learn-ersetzen-$$"
fixture() {  # <neue scanner-befunde: 0|1>
  rm -rf "${F:?}"; mkdir -p "$F/dbg" "$F/tmp" "$F/wurzel"
  {
    echo '{"ts":"2026-10-01 10:00","projekt":"A","klasse":"doku-veraltet","kurz":"alt behoben","lauf":"mind-learnings"}'
    echo '{"ts":"2026-10-01 10:00","projekt":"B","klasse":"sichtbarkeit","kurz":"alt behoben 2","lauf":"mind-learnings"}'
    echo '{"ts":"2026-09-01 09:00","projekt":"A","klasse":"plugin-defekt","kurz":"historisch","lauf":"20260901-0900"}'
  } > "$F/dbg/index.jsonl"
  : > "$F/tmp/befunde.jsonl"
  [ "$1" = 1 ] && echo '{"ts":"2026-10-30 22:00","projekt":"A","klasse":"doku-veraltet","kurz":"neu","lauf":"mind-learnings"}' > "$F/tmp/befunde.jsonl"
  echo "# Bericht" > "$F/tmp/bericht.md"
}
lauf() {
  ( export MIND_DEBUG_DIR="$F/dbg" CLAUDE_PROJECT_DIR="$F/wurzel" TMP="$F/tmp" WURZEL="$F/wurzel"
    cd "$F/wurzel" && eval "$BLOCK" ) >/dev/null 2>&1
}
# debug_aufraeumen schreibt mit `": "`, die Fixture ohne Leerzeichen — beide Formen zaehlen
zaehl() { grep -cE "\"kurz\": ?\"$1\"" "$F/dbg/index.jsonl" 2>/dev/null; }

echo "=== 1) neuer Scanner-Befund: alte Scanner-Zeilen raus, neue rein, Historie bleibt ==="
fixture 1; lauf
pruef "alte Scanner-Zeile 1 entfernt" 0 "$(zaehl 'alt behoben')"
pruef "alte Scanner-Zeile 2 entfernt" 0 "$(zaehl 'alt behoben 2')"
pruef "historischer Laufbericht bleibt" 1 "$(zaehl historisch)"
pruef "neuer Scanner-Befund steht genau einmal" 1 "$(zaehl neu)"
pruef "BEFUNDE.md neu erzeugt" 1 "$([ -s "$F/dbg/BEFUNDE.md" ] && echo 1 || echo 0)"

echo
echo "=== 2) kein Befund mehr: alles behoben -> Scanner-Zeilen weg, Auswertung trotzdem neu ==="
fixture 0; lauf
pruef "keine Scanner-Zeile mehr" 0 "$(grep -cE '"lauf": ?"mind-learnings"' "$F/dbg/index.jsonl")"
pruef "historischer Laufbericht bleibt" 1 "$(zaehl historisch)"
pruef "BEFUNDE.md neu erzeugt" 1 "$([ -s "$F/dbg/BEFUNDE.md" ] && echo 1 || echo 0)"

echo
echo "=== 3) Gegenprobe: ohne MIND_DEBUG_DIR wird nichts angefasst ==="
fixture 1
( unset MIND_DEBUG_DIR; export TMP="$F/tmp" WURZEL="$F/wurzel" CLAUDE_PROJECT_DIR="$F/wurzel"
  cd "$F/wurzel" && eval "$BLOCK" ) >/dev/null 2>&1
pruef "Index unveraendert (3 Zeilen)" 3 "$(grep -c . "$F/dbg/index.jsonl")"

rm -rf "${F:?}"
echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
