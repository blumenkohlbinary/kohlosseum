#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# references/lauf_tokens.py und der Verlauf-Hinweis in /mind-all (v5.151.0, Etappe 58 §0/§1, ZIEL 5).
#
# ⛔ GEMESSEN 28.10.2026: die bisherige Zaehlung summierte `usage` je ZEILE — Claude Code schreibt eine
#    Nachricht mit mehreren Bloecken als mehrere Zeilen mit DERSELBEN `usage` (936 von 936 in Ritas
#    Transkript). Je Nachricht kosteten die beiden Bezugslaeufe 132,9 und 91,3 Mio, nicht 250,8 und 240,8.
#    Gegenprobe gegen die alte Zaehlung: Ritas Lauf 250,85 Mio (alt 250,8), Veras 240,06 Mio (alt 240,8).
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
L="$R/references/lauf_tokens.py"
pruef "Werkzeug liegt im Paket" "$([ -f "$L" ] && echo ja || echo nein)" "ja"
[ -f "$L" ] || { echo "  Gegenstand fehlt"; exit 1; }
"$PY" "$(win "$L")" --selbsttest >/dev/null 2>&1; pruef "Selbsttest rc 0 (je Nachricht, Fenster, Lauf-ID, ms-Grenzen)" "$?" "0"
"$PY" "$(win "$L")" >/dev/null 2>&1;              pruef "ohne Argumente rc 2" "$?" "2"
"$PY" "$(win "$L")" --lauf X-123456789 --projekt "$(win "$(mktemp -d)")" >/dev/null 2>&1
pruef "Lauf ohne Quittung -> rc 2, keine Zahl" "$?" "2"

M="$R/skills/mind-all/SKILL.md"
pruef "/mind-all meldet einen langen eigenen Verlauf" "$(grep -c 'VERLAUF: diese Sitzung traegt rund' "$M")" "1"
pruef "   ... als Hinweis — der Lauf geht weiter"     "$(grep -c 'Der Lauf geht weiter."' "$M")" "1"
pruef "   ... und schreibt dafuer KEINEN projektweiten Merker" "$(grep -c 'lauf-verlauf' "$M")" "0"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
