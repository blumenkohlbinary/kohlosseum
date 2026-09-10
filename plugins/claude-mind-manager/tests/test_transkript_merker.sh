#!/usr/bin/env bash
# Das eigene Transkript — direkt adressiert statt über einen Merker (v5.66.0).
#
# ⛔ WAS DIESE SAMMLUNG WAR (v5.38.0): `.claude-mind/transkript-pfad` ist EINE
#    Datei je PROJEKT und sollte EINE Sitzung kennzeichnen. Jede Sitzung
#    überschrieb ihn bei jedem Prompt — der Letzte gewann. v5.38.0 hat das
#    Rennfenster mit `pfad|sid|ts` und dem Einfrieren in Step 0 verkleinert und
#    den Rest ausdrücklich stehengelassen:
#      „EIN REST BLEIBT und wird nicht weggeredet — auflösen ließe sich das nur
#       mit einer Sitzungskennung im Skill, die es dort nicht gibt."
#
# ⭐ ES GIBT SIE. Gemessen 10.09.2026 in zwei Sitzungen dieses Projekts:
#      CLAUDE_CODE_SESSION_ID  4e6c2f15-…  ->  <slug>/4e6c2f15-….jsonl, 20 MB
#      CLAUDE_CODE_SESSION_ID  62ca5f72-…  ->  Spalte 3 des Rosters, exakt
#    Die Transkriptdatei heißt wie die Kennung. Damit entfällt der Merker samt
#    seinem Rest — die Fehlerklasse verschwindet, nicht nur ihr Fenster.
#
# ⛔ DIE MESSUNG VON v5.30.0 STIMMTE, DER SCHLUSS DARAUS NICHT.
#    `CLAUDE_SESSION_ID` (ohne `CODE_`) ist wirklich leer. Daraus wurde
#    „es gibt keine Kennung", und dieser Satz hat drei Konstruktionen getragen.
#    Der Name lag um ein Wort daneben.
#
# ⛔ WO DIE ALTEN ZUSICHERUNGEN GEBLIEBEN SIND:
#
#    | war (v5.38.0)                    | ist                                  |
#    |----------------------------------|--------------------------------------|
#    | Format `pfad\|sid\|ts` wird gelesen | ⛔ gegenstandslos — Abschnitt 1       |
#    |                                  |   sichert, dass der Merker IGNORIERT  |
#    |                                  |   wird, auch wenn eine Altlast liegt. |
#    | prompt-submit schreibt ihn       | ⛔ umgekehrt — Abschnitt 1.           |
#    | fremder Merker mitten im Lauf    | ⭐ ENTFÄLLT als Gefahr: die Kennung   |
#    |                                  |   ist die eigene, es gibt kein Rennen.|
#    | zweites Argument gewinnt         | ⭐ BLEIBT — Abschnitt 3 (der Hook-Weg).|
#    | die Tokenzahl daran              | ⛔ entfallen mit v5.65.0.             |
#
# ⭐ GEGENPROBE: Abschnitt 1 und 2 sind gegen v5.65.0 ROT.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_transkript_merker.sh
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
GRUEN=0; ROT=0
pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# shellcheck disable=SC1091
. "$R/hooks/lib.sh" 2>/dev/null

# Ein eigenes HOME, damit `$HOME/.claude/projects/<slug>` beherrschbar ist.
H="$TMP/home"; P="$TMP/home/proj"; mkdir -p "$P/.claude-mind"
SLUG=$(HOME="$H" hash_project_dir "$P")
D="$H/.claude/projects/$SLUG"; mkdir -p "$D"

MEINE="1111aaaa-2222-3333-4444-555566667777"
FREMDE="9999ffff-8888-7777-6666-555544443333"
printf '%s\n' '{"cwd":"x"}' > "$D/$MEINE.jsonl"
printf '%s\n' '{"cwd":"x"}' > "$D/$FREMDE.jsonl"
# ⛔ Die FREMDE ist die JÜNGERE — genau die, die `ls -t` und der Merker nähmen.
touch -d '+1 minute' "$D/$FREMDE.jsonl" 2>/dev/null || touch "$D/$FREMDE.jsonl"

ruf() { HOME="$H" CLAUDE_CODE_SESSION_ID="${1-}" mind_transkript_pfad "$P" "${2-}"; }

echo "=== 1) ⛔ Der Merker ist WEG — auch eine Altlast wirkt nicht mehr ==="
# Eine liegengebliebene Datei aus v5.65.0, die auf die FREMDE Sitzung zeigt.
printf '%s|fremd|1' "$D/$FREMDE.jsonl" > "$P/.claude-mind/transkript-pfad"
pruef "⛔ Altlast wird ignoriert, die eigene Kennung gewinnt" \
      "$D/$MEINE.jsonl" "$(ruf "$MEINE")"
# ⛔ GEZÄHLT WIRD DER ZUGRIFF, NICHT DIE NENNUNG. Die erste Fassung zählte
#   `claude-mind/transkript-pfad` schlechthin und wurde rot am eigenen
#   Kommentar, der sagt, dass der Merker ENTFERNT wurde. Ein Kommentar über
#   einen Wegfall ist kein Zugriff. Fünftes Vorkommen dieser Verwechslung in
#   diesem Projekt — sie steht in `env-vars.md` seit 27.08.2026 dokumentiert.
pruef "lib.sh liest den Merker nicht mehr" "0" \
      "$(grep -cE '(cat|-f) "\$proj/\.claude-mind/transkript-pfad"' "$R/hooks/lib.sh")"
pruef "prompt-submit.sh schreibt ihn nicht mehr" "0" \
      "$(grep -c '> "\$PROJ/.claude-mind/transkript-pfad"' "$R/hooks/prompt-submit.sh")"
rm -f "$P/.claude-mind/transkript-pfad"

echo
echo "=== 2) ⭐ Die eigene Kennung trifft die eigene Datei ==="
pruef "meine Kennung -> meine Datei"   "$D/$MEINE.jsonl"  "$(ruf "$MEINE")"
pruef "fremde Kennung -> fremde Datei" "$D/$FREMDE.jsonl" "$(ruf "$FREMDE")"
# ⭐ DIE POSITIVKONTROLLE DIESER SAMMLUNG: die fremde Datei ist die JÜNGERE.
#   Kommt trotzdem meine zurück, ist belegt, dass NICHT nach Änderungszeit
#   gewählt wird — genau der Fehler, gegen den v5.34.0 gebaut wurde.
pruef "⭐ und zwar OBWOHL die fremde jünger ist" "$D/$MEINE.jsonl" "$(ruf "$MEINE")"

echo
echo "=== 3) ⛔ FAIL-SAFE: keine Kennung ist keine erfundene Datei ==="
# ⛔ Antons Auflage (b). Ohne diese drei Fälle wäre die Variable eine stille
#   Abhängigkeit: fehlt sie, dürfte nichts Falsches herauskommen — es muss
#   sich verhalten wie vor v5.66.0.
AUS=$(ruf ""); case "$AUS" in "$D/"*.jsonl) A=heuristik ;; "") A=leer ;; *) A="$AUS" ;; esac
pruef "leere Variable -> Rückfall auf die Heuristik" "heuristik" "$A"
AUS=$(ruf "gibt-es-nicht-0000"); case "$AUS" in "$D/"*.jsonl) A=heuristik ;; "") A=leer ;; *) A="$AUS" ;; esac
pruef "Kennung ohne Datei -> Rückfall, kein erfundener Pfad" "heuristik" "$A"
pruef "⛔ und NIE der Name der fehlenden Datei" "0" \
      "$(printf '%s' "$(ruf 'gibt-es-nicht-0000')" | grep -c 'gibt-es-nicht-0000')"

echo
echo "=== 4) ⭐ Der HOOK-Weg gewinnt weiterhin ==="
# Ein Hook kennt `transcript_path` aus seinem Input — das war immer die
# verlässlichste Quelle und bleibt Vorrang vor allem anderen.
pruef "zweites Argument schlägt die Kennung" \
      "$D/$FREMDE.jsonl" "$(ruf "$MEINE" "$D/$FREMDE.jsonl")"
pruef "ein NICHT existierendes zweites Argument zählt nicht" \
      "$D/$MEINE.jsonl" "$(ruf "$MEINE" "$TMP/gibtsnicht.jsonl")"

echo
echo "=== 5) ⛔ Die Sitzungskennung der Laufsperre kommt aus der Umgebung ==="
SK="$R/skills/mind-all/SKILL.md"
pruef "mind-all nimmt CLAUDE_CODE_SESSION_ID" "1" \
      "$(grep -c 'MIND_SID="\${CLAUDE_CODE_SESSION_ID:-' "$SK")"
pruef "⛔ mit Rückfall, nicht ungeschützt" "1" \
      "$(grep -c 'CLAUDE_CODE_SESSION_ID:-\$(basename' "$SK")"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
