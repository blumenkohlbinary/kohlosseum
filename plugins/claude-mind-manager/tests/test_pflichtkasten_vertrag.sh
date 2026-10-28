#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# VERTRAG: der PFLICHTSCHRITTE-Kasten und die mind_schritt_start-Zeile nennen DIESELBEN
# Schritte — in jedem SKILL.md, das beides hat (v5.145.0, Etappe 55 §2, Veras Befund M-A).
#
# ⛔ WAS GEMESSEN WURDE (Zustellplan, zwei Laeufe 11./12.10.2026, am Quellbaum nachgesehen):
#    `cleaner_tor` stand in vier Kaesten (mind-claudemd, mind-files, mind-memory, mind-rules,
#    mind-update) und in KEINER Startzeile. Folge: quittiert, aber nie erwartet — er erschien
#    als „zusaetzlich" statt als erfuellter Pflichtschritt, und FEHLT konnte ihn nie melden.
# ⭐ Das ist kein Wort, nach dem man greppen koennte, sondern eine ZUSICHERUNG, die alle
#    Dateien derselben Art einhalten muessen (CLAUDE.md, ALLBETROFFENHEIT: Vertraege).
#    Deshalb liest der Prueffall JEDEN Skill, auch die, die heute stimmen.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0; n=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

kasten() {  # Namen zwischen der Zeile PFLICHTSCHRITTE und dem schliessenden Fence
  tr -d '\r' < "$1" | awk '/^PFLICHTSCHRITTE$/{f=1; next} f && /^```/{exit} f && NF && $1 !~ /^[(]/{print $1}' | sort -u
}
startzeile() {  # Namen ab dem dritten Wort der ersten mind_schritt_start "$PROJ"-Zeile
  tr -d '\r' < "$1" | grep -m1 '^mind_schritt_start "\$PROJ"' \
    | awk '{for(i=4;i<=NF;i++) print $i}' | sort -u
}

for f in "$R"/skills/*/SKILL.md; do
  s=$(basename "$(dirname "$f")")
  K=$(kasten "$f"); Z=$(startzeile "$f")
  [ -n "$K" ] || continue
  n=$((n+1))
  nur_k=$(comm -23 <(printf '%s\n' "$K") <(printf '%s\n' "$Z") | tr '\n' ' ' | sed 's/ $//')
  nur_z=$(comm -13 <(printf '%s\n' "$K") <(printf '%s\n' "$Z") | tr '\n' ' ' | sed 's/ $//')
  pruef "$s: jeder Kasten-Eintrag steht in der Startzeile" "${nur_k:-keiner}" "keiner"
  pruef "$s: die Startzeile erwartet nichts, was der Kasten nicht nennt" "${nur_z:-keiner}" "keiner"
done

# ⛔ VAKUUM-WAECHTER: findet die Sammlung keinen Kasten, ist sie gruen, ohne gemessen zu haben.
#    Heute tragen zehn Skills einen Kasten; weniger als acht heisst: das Format hat sich
#    geaendert und der Vertrag wird nicht mehr gelesen.
pruef "mindestens acht Skills mit Kasten gelesen" "$([ "$n" -ge 8 ] && echo ja || echo "nein ($n)")" "ja"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
