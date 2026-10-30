#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# references/kontext_grundlage.py und /mind-denkstufe Step 4/6 (v5.155.0, Etappe 59, Etappe 60 Punkt 0).
#
# ⛔ KEINE SCHWELLE (Nutzer 28.10.2026): das Werkzeug liefert Grundlast, Stand nach Kompaktierung, Einlese-Bedarf und
#    Verteilung als Information. Gemessen 29.10.2026: hier Grundlast 147 898 (6), nach Kompaktierung 166 384 (69);
#    Zustellplan hat 0 frische Sitzungen — eine fortgesetzte beginnt mit ihrem alten Verlauf (Median 566 508), die
#    erste Fassung hielt das fuer die Grundlast. Der Selbsttest haelt den Ausschluss fest.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
K="$R/references/kontext_grundlage.py"
pruef "Werkzeug liegt im Paket" "$([ -f "$K" ] && echo ja || echo nein)" "ja"
[ -f "$K" ] || { echo "  $ok gruen · $rot rot"; exit 1; }
"$PY" "$(win "$K")" --selbsttest >/dev/null 2>&1; pruef "Selbsttest (je message.id, fortgesetzt, nicht messbar, geteilt)" "$?" "0"
"$PY" "$(win "$K")" >/dev/null 2>&1;              pruef "ohne Argumente rc 2" "$?" "2"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
"$PY" "$(win "$K")" --transkripte "$(win "$T/gibtsnicht")" >/dev/null 2>&1; pruef "fehlender Ordner rc 2" "$?" "2"
mkdir -p "$T/leer"; A=$("$PY" "$(win "$K")" --transkripte "$(win "$T/leer")" 2>&1); RC=$?
pruef "ohne Transkripte rc 1 ..."            "$RC" "1"
pruef "   ... und sagt NICHT MESSBAR, keine Zahl" "$(printf '%s' "$A" | grep -c 'NICHT MESSBAR')" "1"

D="$R/skills/mind-denkstufe/SKILL.md"
pruef "/mind-denkstufe ruft das Werkzeug"              "$(grep -c 'references/kontext_grundlage.py" --projekt "$PROJ"' "$D")" "1"
pruef "   ... und nennt die berechnete Grenze (v5.171.0)" "$(grep -c 'rechnet das Werkzeug eine Kompaktierungsgrenze je Ordner aus' "$D")" "1"
pruef "   ... die alte Regel steht nicht mehr als gueltig" "$(grep -c '^⛔ \*\*Die Ausgabe ist Information, KEINE Schwelle' "$D")" "0"
pruef "   ... Ausgabeformat traegt die Grenze"            "$(grep -c '^  HERGELEITET  Kompaktierungsgrenze autoCompactWindow <n> (Startlast' "$D")" "1"
pruef "   ... liest settings.local.json VOR settings.json (lokal geht vor)" "$(grep -n 'autoCompactWindow // empty' "$D" | head -1 | grep -c 'settings.local.json')" "1"
pruef "Empfehlung ist EINE Kombination mit Ultracode"   "$(grep -c '^Empfehlung:  <Modell> · <low|medium|high|xhigh|max> · Ultracode <an|aus>' "$D")" "1"
pruef "Einstell-Zeilen nennen den Schluessel ultracode" "$(grep -c '"ultracode": true|false' "$D")" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
