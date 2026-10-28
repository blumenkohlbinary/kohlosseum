#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# VERTRAG: kein ausgeliefertes Werkzeug-Verweis zeigt aus dem Paket hinaus (v5.145.0,
# Etappe 55 §1, Veras Befund M-C).
#
# ⛔ WAS GEMESSEN WURDE (Zustellplan 11.10.2026, am Quellbaum bestaetigt): `mind-memory` und
#    `mind-cleaner` nannten `Learnings/memory_gates.py` als DAS pruefende Programm der vier
#    Memory-Gates. `Learnings/` gibt es nur im Entwicklungs-Workspace. In jedem anderen Projekt
#    blieben Gate 3/4 UNGEPRUEFT — Vera hat richtig nicht zusammengefuehrt, aber erzwungen durch
#    ein fehlendes Werkzeug, nicht durch einen Befund.
# ⭐ Ein Vertrag, kein Wort: es zaehlt nicht, ob `memory_gates` vorkommt, sondern ob JEDER
#    genannte Werkzeugpfad im Paket eine Datei hat.
#    · `Learnings/<name>` — immer ein Verstoss (der Ordner wird nie ausgeliefert)
#    · `tools/<name>.py|.sh` — erlaubt, wenn das Paket die Datei als VORLAGE mitbringt
#      (`mind-files` installiert sie nach `<projekt>/tools/`); sonst ein Verstoss
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# Ausgeliefert = alles, was der Nutzer bekommt und ein Modell liest.
DATEIEN=$(find "$R/skills" "$R/agents" "$R/hooks" "$R/references" -type f \( -name '*.md' -o -name '*.sh' \) \
            -not -path '*/fixtures/*' 2>/dev/null)
n=$(printf '%s\n' "$DATEIEN" | grep -c .)
pruef "Vakuum-Waechter: ausgelieferte .md/.sh gefunden (mind. 20)" "$([ "$n" -ge 20 ] && echo ja || echo "nein ($n)")" "ja"

# ⚠ BENANNTE AUSNAHMEN — je mit Grund; eine neue Fundstelle ist rot, bis sie hier steht.
#   hooks/lib.sh            `Learnings/zaehl_gate.py` ist im Kommentar von
#                           `mind_check_tools_have_rules` das BEISPIEL einer Aufrufform, keine Anweisung
#   references/bestands-pass.md  `tools/erfindungsprobe.py` liegt ausdruecklich „in einem fremden
#                           Projekt" — „lesen ja, editieren nie"; kein Werkzeug dieses Pakets
ausnahme() {  # $1 = Datei relativ zum Paket, $2 = genannter Pfad
  case "$1|$2" in
    "hooks/lib.sh|Learnings/zaehl_gate.py") return 0 ;;
    "references/bestands-pass.md|tools/erfindungsprobe.py") return 0 ;;
  esac
  return 1
}

# 1) Learnings/ — nie
L=$(printf '%s\n' "$DATEIEN" | while IFS= read -r f; do
      rel="${f#$R/}"
      grep -oE 'Learnings/[A-Za-z0-9_.-]+\.(py|sh)' "$f" 2>/dev/null | sort -u | while IFS= read -r t; do
        ausnahme "$rel" "$t" || printf '%s:%s\n' "$rel" "$t"; done; done)
pruef "kein ausgelieferter Verweis auf Learnings/" "${L:-keiner}" "keiner"

# 2) tools/<name> — nur, wenn das Paket die Datei mitbringt
# ⚠ `tools/x.py` ist das Beispiel im Kommentar von `mind_check_tools_have_rules` (lib.sh) — kein Werkzeug.
FEHLT=""
while IFS='|' read -r rel t; do
  [ -n "$t" ] || continue
  b="${t##*/}"
  [ "$b" = "x.py" ] && continue
  ausnahme "$rel" "$t" && continue
  find "$R" -name "$b" -not -path '*/tests/*' 2>/dev/null | grep -q . || FEHLT="$FEHLT $rel:$t"
done <<< "$(printf '%s\n' "$DATEIEN" | while IFS= read -r f; do
              grep -oE '(^|[^A-Za-z0-9_/.-])tools/[A-Za-z0-9_.-]+\.(py|sh)' "$f" 2>/dev/null \
                | sed -E 's#^[^t]*##' | sort -u | sed "s#^#${f#$R/}|#"; done)"
pruef "jedes genannte tools/<name> liegt als Vorlage im Paket" "${FEHLT:-keins}" "keins"

# 3) die konkrete Stelle: das Programm der Memory-Gates liegt im Paket
pruef "references/memory_gates.py wird ausgeliefert" "$([ -f "$R/references/memory_gates.py" ] && echo ja || echo nein)" "ja"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
