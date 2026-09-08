#!/usr/bin/env bash
# v5.43.0: die Feld-Migration `paths:` -> `globs:` ist ENTFERNT.
#
# ⛔ SIE LIEF FUENF MONATE IN DIE FALSCHE RICHTUNG. `mind-rules` schrieb AUTONOM
#    `paths:` nach `globs:` um — auch in FREMDEN Projekten. Die Begruendung
#    stammte aus dem Januar 2026, als `paths:` tatsaechlich kaputt war; repariert
#    wurde es in Claude Code v2.1.84, fuenf Tage nach der Verschriftlichung des
#    Workarounds.
#
# ⛔ Die Folge: eine funktionierende Pfad-Eingrenzung wurde in eine Regel
#    verwandelt, die BEDINGUNGSLOS laedt. Das Plugin vergroesserte damit genau
#    den Dauerkontext, den es verkleinern soll.
#
# ⭐ DIESE SAMMLUNG IST EINE RATSCHE. Sie wird rot, sobald jemand die alte
#    Richtung wieder einbaut — egal in welcher Formulierung.
#
# ⚠ Sie prueft NICHT, dass die Gegenrichtung gebaut ist. Die ist bewusst NICHT
#   gebaut: gemessen ist, dass `globs:` nicht filtert; NICHT gemessen ist, dass
#   `paths:` es hier tut.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GRUEN=0; ROT=0
pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }
hat() { case "$3" in *"$2"*) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";;
  *) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' fehlt";; esac; }

S="$R/skills/mind-rules/SKILL.md"
B="$R/references/budget-thresholds.md"
G="$R/references/context-file-guide.md"

echo "=== 1) ⛔ RATSCHE: die alte Richtung darf nicht zurueckkommen ==="
N=$(grep -rc 'paths: to globs\|auto-convert paths\|paths:.*to the working.*globs' \
     "$R/skills" "$R/references" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
pruef "keine Stelle sagt mehr 'paths: -> globs:'" 0 "$N"

echo
echo "=== 2) Der Skill sagt, dass er nichts umschreibt ==="
hat "migrate schreibt NICHTS mehr um" "SCHREIBT NICHTS UM" "$(cat "$S")"
hat "   ... und der Unterbefehl sagt es auch" "schreibt NICHTS mehr um" "$(cat "$S")"
hat "die Zusammenfassung zaehlt statt zu migrieren" "ohne Feld (= laden immer)" "$(cat "$S")"

echo
echo "=== 3) ⭐ Beide Seiten der Messlage stehen da ==="
D=$(cat "$S")
hat "was GEMESSEN ist: globs filtert nicht" "path_glob_match" "$D"
hat "   ... mit der Zahl" "3667" "$D"
hat "⚠ was NICHT gemessen ist: dass paths hier filtert" "NICHT gemessen" "$D"
hat "der Versuch, der es entscheiden wuerde, steht dabei" "frische Sitzung" "$D"
hat "   ... und dass nur der Mensch ihn ausloesen kann" "Nur der Mensch" "$D"

echo
echo "=== 4) ⛔ Der Health-Score belohnt den Fehler nicht mehr ==="
BT=$(cat "$B")
pruef "die +5 fuer globs: sind weg" 0 \
  "$(grep -c '^- Rules use `globs:` not `paths:`: +5' "$B")"
hat "   ... und die Zeile sagt, dass sie entfallen ist" "ENTFALLEN v5.43.0" "$BT"

echo
echo "=== 5) @import wird nicht mehr als Ersparnis belohnt ==="
hat "@import zaehlt nicht mehr fuer Modularitaet" "@import\` zaehlt NICHT mehr" "$BT"
hat "   ... mit der offiziellen Begruendung" "doesn't" "$BT"
hat "progressive disclosure meint Skills/Commands" "nicht \`@import\`" "$BT"

echo
echo "=== 6) CLAUDE.local.md ist nicht deprecated ==="
hat "die Deprecation-Behauptung ist zurueckgenommen" "NICHT deprecated" "$(cat "$G")"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
