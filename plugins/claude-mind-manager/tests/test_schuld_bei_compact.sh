#!/usr/bin/env bash
# Die Sync-Schuld darf nicht verschwinden, weil zugleich eine Kompaktierung
# aussteht (v5.50.0).
#
# ⛔ DER FEHLER WAR STRUKTURELL, NICHT ZUFAELLIG. `prompt-submit.sh` ist eine
#    Kette aus `if … exit 0`. Der COMPACT-FAELLIG-Zweig steigt aus, die
#    Schuld-Meldung steht 150 Zeilen weiter unten — sie wurde bei BEIDEN
#    Merkern nie erreicht.
#
# ⚠ DER AUSSTIEG IST RICHTIG: ein Hook gibt genau EINEN `additionalContext`
#   aus. Falsch war, dass die eine Meldung nur eine der beiden Tatsachen trug.
#
# ⛔ UND ES IST DER HAEUFIGE FALL, nicht der seltene: ein token-erzwungener
#    Sync bekommt oberhalb von MIND_AGENT_HALB_TOKENS null Agenten, ist damit
#    per Konstruktion ein Teilsync (OPEN mit grund=teilsync) und setzt zugleich
#    COMPACT-FAELLIG.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PS="$R/hooks/prompt-submit.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }
hat() { case "$3" in *"$2"*) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";;
  *) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' fehlt";; esac; }
nicht() { case "$3" in *"$2"*) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' steht drin";;
  *) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";; esac; }

P="$TMP/proj"; mkdir -p "$P/.claude-mind/rescued"
echo '{"cwd":"'"$P"'","session_id":"t1"}' > "$TMP/in.json"
lauf() { CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" \
         bash "$PS" < "$TMP/in.json" 2>/dev/null; }

echo "=== 1) ⭐ POSITIVKONTROLLE: beide Merker -> beide Tatsachen ==="
printf 'path=%s/x_chat.md\ngrund=teilsync\nungepruef=claude-md,memory\n' \
  "$P/.claude-mind/rescued" > "$P/.claude-mind/rescued/OPEN"
touch "$P/.claude-mind/rescued/x_chat.md" "$P/.claude-mind/rescued/COMPACT-FAELLIG"
A=$(lauf)
hat "die Kompaktierung wird genannt" "compact" "$A"
hat "⛔ die SCHULD auch" "SYNC-SCHULD" "$A"
hat "   ... mit dem Grund" "teilsync" "$A"
hat "   ... und den UNGEPRUEFTEN Bereichen" "claude-md" "$A"
hat "   ... als ungeprueft, nicht als unauffaellig" "UNGEPRUEFT" "$A"
hat "   ... und dass sie die Kompaktierung ueberlebt" "bleibt danach bestehen" "$A"

echo
echo "=== 2) ⛔ Es bleibt EINE gueltige JSON-Ausgabe ==="
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$A" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1
  pruef "gueltiges JSON mit additionalContext" 0 "$?"
  pruef "genau EIN Objekt" 1 "$(printf '%s' "$A" | grep -c 'hookSpecificOutput')"
else
  echo "  [--] jq fehlt — uebersprungen (ein uebersprungener Fall ist kein bestandener)"
fi

echo
echo "=== 3) ⛔ NEGATIVKONTROLLE: ohne Schuld wird keine behauptet ==="
rm -f "$P/.claude-mind/rescued/OPEN"
B=$(lauf)
hat "die Kompaktierung wird weiter genannt" "compact" "$B"
nicht "⛔ aber KEINE Schuld erfunden" "SYNC-SCHULD" "$B"
nicht "   ... und kein TEILSYNC" "TEILSYNC" "$B"

echo
echo "=== 4) ⭐ Ohne COMPACT-FAELLIG bleibt der alte Weg unveraendert ==="
rm -f "$P/.claude-mind/rescued/COMPACT-FAELLIG"
printf 'path=%s/x_chat.md\n' "$P/.claude-mind/rescued" > "$P/.claude-mind/rescued/OPEN"
C=$(lauf)
hat "die Schuld wird ueber den eigenen Zweig gemeldet" "Sync-Schuld" "$C"

echo
echo "=== 5) ⛔ Eine OPEN ohne grund= behauptet keinen Teilsync ==="
touch "$P/.claude-mind/rescued/COMPACT-FAELLIG"
D=$(lauf)
hat "die Schuld steht da" "SYNC-SCHULD" "$D"
nicht "   ... aber ohne erfundenen Grund" "Grund:" "$D"
nicht "   ... und ohne erfundene Bereiche" "UNGEPRUEFT" "$D"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
