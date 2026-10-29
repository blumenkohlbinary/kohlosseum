#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Kommen die Argumente eines /mind-*-Aufrufs in den Block-Skripten an? (v5.159.0, Etappe 60 Zusatz)
#
# ⛔ GEMESSEN 29.10.2026 (Learnings/argumente_messung.py, 23 echte Aufrufe mit Argumenten): Claude Code
#    ersetzt beim Laden eines Skills das BLANKE `$ARGUMENTS`, nie `${ARGUMENTS:-}` — das stand in allen
#    eingespielten Skilltexten woertlich. Vor 5.152.0 kamen Argumente nur an, wenn das Modell sie beim
#    Abtippen der Fence von Hand einsetzte (6 von 23). Seit 5.152.0 stehen die Zeilen in Skripten, die
#    niemand abtippt, und `ARGUMENTS` ist in der Bash-Umgebung UNGESETZT: --ask, --dry-run, --quick und
#    `global` fielen still auf die Vorgabe — aus `--dry-run` wurde ein echter Lauf mit Snapshot.
# ⭐ Diese Sammlung macht die Ersetzung von Claude Code nach (blankes `$ARGUMENTS` in der AUFRUFZEILE der
#    SKILL.md durch den Argumenttext) und faehrt die Zeile — sie prueft den Text, den das Modell sieht,
#    und das Skript, das er ruft, zusammen.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude/rules"; printf '# P\n' > "$P/CLAUDE.md"

# zeile <skill> <muster>  -> die Aufrufzeile aus der SKILL.md (erste, die das Muster traegt)
zeile() { grep -m1 -F "$2" "$R/skills/$1/SKILL.md"; }
# laden <zeile> <args>    -> was Claude Code daraus macht: blankes $ARGUMENTS durch den Text ersetzen
laden() { python -c "import sys; print(sys.argv[1].replace('\$ARGUMENTS', sys.argv[2]))" "$1" "$2"; }
fahre() {  # <zeile> <args> [nachsatz] -> stdout+stderr, rc als letzte Zeile
  ( cd "$P" && env -u ARGUMENTS CLAUDE_PROJECT_DIR="$P" MIND_LOG_FILE="$TMP/log" \
      bash -c "$(laden "$1" "$2")${3:+
$3}" 2>&1; echo "rc=$?" )   # Nachsatz auf eigener Zeile: die Aufrufzeile kann einen #-Kommentar tragen
}

echo "=== 1) --dry-run bricht in JEDEM Skill mit Step-0-Block ab (nichts geschrieben) ==="
for s in mind-all mind-update mind-claudemd mind-files mind-memory mind-rules; do
  Z=$(zeile "$s" "/bloecke/step0-snapshot.sh"); [ -n "$Z" ] || Z=$(zeile "$s" "/bloecke/02-step0-modus-snapshot.sh")
  pruef "$s: Aufrufzeile gefunden" "$([ -n "$Z" ] && echo ja || echo nein)" "ja"
  [ -n "$Z" ] || continue
  A=$(fahre "$Z" "--dry-run")
  pruef "⛔ $s --dry-run -> ABBRUCH rc 2" "$(printf '%s' "$A" | grep -c 'ABBRUCH: --dry-run')$(printf '%s' "$A" | tail -1)" "1rc=2"
done
pruef "  ... und kein Snapshot entstand" "$(ls "$P/.claude-mind/snapshots" 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "=== 2) /mind-claudemd global: _ziele.sh stellt den Bereich um ==="
Z=$(zeile mind-claudemd '/bloecke/_ziele.sh"')
pruef "⛔ global -> BEREICH=global" "$(fahre "$Z" "global" 'echo "B=$BEREICH"' | grep -o 'B=[a-z]*')" "B=global"
pruef "ohne Argument -> BEREICH=projekt (wie bisher)" "$(fahre "$Z" "" 'echo "B=$BEREICH"' | grep -o 'B=[a-z]*')" "B=projekt"

echo "=== 3) /mind-update --quick erreicht den Drift-Block ==="
Z=$(zeile mind-update "/bloecke/step3e2-drift.sh")
pruef "⛔ --quick -> QUICK_MODE=yes im Block" "$(fahre "$Z" "--quick" | grep -c 'rc=')$(laden "$Z" "--quick" | grep -c "ARGUMENTS='--quick'")" "11"

echo "=== 4) Freitext mit Sonderzeichen wird NICHT ausgefuehrt ==="
Z=$(zeile mind-claudemd '/bloecke/_ziele.sh"')
A=$(fahre "$Z" 'global $(touch '"$TMP"'/boese) `touch '"$TMP"'/boese2` "x"' 'echo "B=$BEREICH"')
pruef "⛔ \$( ) und Backticks im Argument laufen nicht" "$(ls "$TMP"/boese* 2>/dev/null | wc -l | tr -d ' ')" "0"

pruef "⚠ Apostroph im Freitext: Syntaxfehler, rc 2 — sichtbar, nicht still auf die Vorgabe" "$(fahre "$Z" "global geht's" 'echo "B=$BEREICH"' | grep -c 'B=projekt')$(fahre "$Z" "global geht's" | tail -1)" "0rc=2"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
