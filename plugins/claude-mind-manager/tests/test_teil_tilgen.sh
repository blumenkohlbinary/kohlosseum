#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# OPEN wird nur fuer die Rettungen getilgt, die der Lauf eingelesen hat (v5.149.0, Etappe 57 §3).
#
# ⛔ GEMESSEN (Veras Lauf Zustellplan 11.10.2026, Debug 646): 7 Rettungen eingespeist, 41 kamen
#    WAEHREND des Laufs dazu — `mind_schuld_begleichen` entfernte OPEN ganz und tilgte damit die
#    Schuld fuer 41 Rettungen, die niemand gelesen hatte.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
lage() {
  local d="$TMP/$1 mit leer" x; mkdir -p "$d/.claude-mind/rescued"
  printf 'compactions=3\n' > "$d/.claude-mind/rescued/OPEN"
  for x in A B C; do
    : > "$d/.claude-mind/rescued/2026102${x}_chat.md"; : > "$d/.claude-mind/rescued/2026102${x}_RESUME.md"
    printf 'path=%s\nresume=%s\nts=2026102%s\ngrund=x\n' "$d/.claude-mind/rescued/2026102${x}_chat.md" \
      "$d/.claude-mind/rescued/2026102${x}_RESUME.md" "$x" >> "$d/.claude-mind/rescued/OPEN"
  done
  printf '%s' "$d"
}
bg() { ( source "$R/hooks/lib.sh"; MIND_LOG_FILE="$TMP/log" mind_schuld_begleichen "$@" ); }

echo "=== 1) ⛔ Veras Lage: A und C eingelesen, B kam waehrend des Laufs dazu ==="
P=$(lage f1); O="$P/.claude-mind/rescued/OPEN"
printf '%s\n' "2026102A_chat.md" "2026102C_chat.md" > "$P/gelesen"
A=$(bg "$P" "$P/gelesen"); RC=$?
pruef "rc 0"                                       "$RC" "0"
pruef "⛔ OPEN bleibt — B ist nicht eingelesen"     "$([ -f "$O" ] && echo liegt || echo weg)" "liegt"
pruef "   ... mit genau EINER Rettung: B"          "$(grep -c '^path=' "$O")" "1"
pruef "   ... und es ist B"                        "$(grep -c '2026102B_chat.md' "$O")" "1"
pruef "   ... die Kopfzeile bleibt (compactions=)"  "$(grep -c '^compactions=3$' "$O")" "1"
pruef "A und C: RESUME .done"                      "$(ls "$P/.claude-mind/rescued/"*.done.md 2>/dev/null | wc -l | tr -d ' ')" "2"
pruef "B: RESUME NICHT .done"                      "$([ -f "$P/.claude-mind/rescued/2026102B_RESUME.md" ] && echo ja || echo nein)" "ja"
pruef "die Meldung nennt beides"                   "$A" "2 RESUME .done, 1 Rettung(en) bleiben offen"
pruef "die Liste ist verbraucht"                   "$([ -f "$P/gelesen" ] && echo liegt || echo weg)" "weg"

echo "=== 2) alle eingelesen -> OPEN weg ==="
P=$(lage f2); printf '%s\n' 2026102A_chat.md 2026102B_chat.md 2026102C_chat.md > "$P/gelesen"
bg "$P" "$P/gelesen" >/dev/null
pruef "OPEN entfernt" "$([ -f "$P/.claude-mind/rescued/OPEN" ] && echo liegt || echo weg)" "weg"

echo "=== 3) Liste angegeben, aber fehlt -> rc 2, NICHTS getilgt ==="
P=$(lage f3); bg "$P" "$P/gibtsnicht" >/dev/null 2>&1; RC=$?
pruef "rc 2" "$RC" "2"
pruef "OPEN unveraendert (3 Rettungen)" "$(grep -c '^path=' "$P/.claude-mind/rescued/OPEN")" "3"

echo "=== 4) GEGENKONTROLLE: ohne Liste -> Altform (alles), wie bis v5.148.0 ==="
P=$(lage f4); A=$(bg "$P")
pruef "OPEN entfernt" "$([ -f "$P/.claude-mind/rescued/OPEN" ] && echo liegt || echo weg)" "weg"
pruef "drei RESUME .done" "$A" "3 RESUME .done"

echo "=== 5) /mind-all Step 0 schreibt die Liste aus RESCUED_ALL — Dateinamen, auch aus Windows-Pfaden ==="
Z=$(tr -d '\r' < "$R/skills/mind-all/SKILL.md" | grep -m1 "^printf '%s\\\\n' \"\$RESCUED_ALL\" | sed")
pruef "Zeile gefunden" "$([ -n "$Z" ] && echo ja || echo nein)" "ja"
RESCUED_ALL=$(printf '%s\n' 'C:\CD\x\.claude-mind\rescued\20261026-1_chat.md' '/c/CD/x/.claude-mind/rescued/20261027-2_chat.md')
_GL="$TMP/gl.txt" RESCUED_ALL="$RESCUED_ALL" bash -c "$Z"
pruef "zwei Namen, ohne Pfad" "$(tr '\n' ' ' < "$TMP/gl.txt")" "20261026-1_chat.md 20261027-2_chat.md "

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
