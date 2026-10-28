#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# debug_auswertung.art(): der Werkzeug-Erkenner (v5.149.0, Etappe 57 §4).
#
# ⛔ GEMESSEN 28.10.2026: von 20 Debug-Zeilen, die `debug_aufraeumen --behoben` nicht schliessen
#    liess, hatten mehrere einen benannten Bauteil, den der Erkenner nicht sah — `mind_stufe3_zeilen`
#    (Ziffer im Namen), `mind-update` (Skill-Name), `context-analyzer` (Agenten-Name). Ueber alle
#    738 Zeilen: 53 `unbestimmt` -> `zustand`, 2 `ereignis` -> `unbestimmt`, 0 `ereignis` -> `zustand`.
# ⭐ Die Gegenkontrollen sind genauso wichtig: ein Selbstbericht bleibt Ereignis, „beides" bleibt
#    unbestimmt, ein Satz ohne Bauteil bleibt unbestimmt.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
art() { "$PY" -c "import sys; sys.path.insert(0, sys.argv[1]); import debug_auswertung as d; print(d.art({'kurz': sys.argv[2]}))" \
          "$(win "$R/references")" "$1" | tr -d '\r'; }

pruef "⛔ Ziffer im Namen: mind_stufe3_zeilen ist ein Werkzeug" "$(art 'mind_stufe3_zeilen ohne Merker-Ort fuer Memory-Dateien')" "zustand"
pruef "⛔ Skill-Name: mind-update"                            "$(art 'mind-update 3e.2: Datum 10.09.2026 als Versionsnummer gelesen')" "zustand"
pruef "⛔ Agenten-Name: context-analyzer"                     "$(art 'context-analyzer claude-md am 20-Turn-Limit, per SendMessage nachgeholt')" "zustand"
pruef "unveraendert: mind_agent_bilanz"                      "$(art 'mind_agent_bilanz meldet DISPATCH=0')" "zustand"
pruef "GEGENKONTROLLE: Selbstbericht bleibt Ereignis"         "$(art 'ich habe vergessen zu committen')" "ereignis"
pruef "GEGENKONTROLLE: beides bleibt unbestimmt"              "$(art 'ich habe mind-update falsch aufgerufen')" "unbestimmt"
pruef "GEGENKONTROLLE: kein Bauteil bleibt unbestimmt"        "$(art 'Rettungsdatei endet 2,5h vor dem Rettungs-Zeitstempel')" "unbestimmt"
# ⚠ BEKANNTE GRENZE, festgehalten statt ungemessen umgebaut: `_SELBST` liest „eigenen" als
#   Selbstbericht, auch wenn es sich auf eine DATEI bezieht — so wurde Debug-Zeile 620 („…vor ihrem
#   eigenen Rettungs-Zeitstempel") zum Ereignis. Wird `_SELBST` geaendert, kippt dieser Fall.
pruef "BEKANNTE GRENZE: „eigenen\" auf eine Datei bezogen gilt als Ereignis" \
  "$(art 'Rettungsdatei endet 2,5h vor ihrem eigenen Zeitstempel')" "ereignis"
pruef "GEGENKONTROLLE: ein fremder Bindestrich-Name ist keiner" "$(art 'mind-blowing Ergebnis im Bericht')" "unbestimmt"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
