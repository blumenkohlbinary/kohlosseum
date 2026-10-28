#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Check 13 („toter Pfad"): „hier nicht aufloesbar" ist eine eigene Klasse (v5.147.0, Etappe 56 §5).
#
# ⛔ GEMESSEN 28.10.2026 an vier Projekten: 33 Meldungen „toter Pfad", der haeufigste Fehlalarm des
#    Monats. Fuenf Formen sind NIE tot, sondern nur von hier aus nicht pruefbar — 33 -> 25.
#    Jeder Fall unten ist eine dieser Formen; die Gegenkontrollen halten fest, dass ein ECHT
#    toter Pfad weiter gemeldet wird (darunter `~/.claude/...`, wo HOME den ersten Teil kennt).
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PL="$R/references/claudemd_pipeline.py"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ELTERN="$TMP/eltern mit leer"; P="$ELTERN/projekt"
mkdir -p "$P/.claude/rules" "$ELTERN/_ablage"
: > "$P/.claude/rules/rollen.md"; : > "$ELTERN/_ablage/sicherung.md"
cat > "$P/CLAUDE.md" <<'MD'
# Projekt

- Laeuft ein Lauf, liegt `.claude-mind/mind-all.lock` — vorher pruefen mit `ls .claude-mind/mind-all.lock`.
- Der Roster steht in `rules/rollen.md`.
- Die alte Fassung liegt in `_ablage/sicherung.md`.
- Auf der Workstation liegt der Testordner unter `~/gibtsnurdort_7q/ordner/datei.txt`.
- Das Werkzeug ist `tools/gibtesnicht.py`.
- Die globale Regel steht in `~/.claude/rules/gibtsnicht_7q.md`.
MD
A=$("$PY" "$(win "$PL")" "$(win "$P/CLAUDE.md")" --projekt "$(win "$P")" 2>&1)
tot() { printf '%s\n' "$A" | grep -c "toter Pfad: $1"; }
hin() { printf '%s\n' "$A" | grep 'hier nicht aufloesbar' | grep -c -- "$1"; }

pruef "Laufzeit-Merker ist nicht tot"                       "$(tot '.claude-mind/mind-all.lock')" "0"
pruef "   ... sondern als nicht aufloesbar ausgewiesen"     "$( [ "$(hin '.claude-mind/mind-all.lock')" -ge 1 ] && echo ja || echo nein)" "ja"
pruef "Befehlswort davor: nicht tot"                        "$(tot 'ls .claude-mind')" "0"
pruef "rules/<x> meint .claude/rules/<x>: nicht tot"        "$(tot 'rules/rollen.md')" "0"
pruef "relativ zum Elternordner: nicht tot"                 "$(tot '_ablage/sicherung.md')" "0"
pruef "Pfad einer anderen Maschine: nicht tot"              "$(tot '~/gibtsnurdort_7q')" "0"
pruef "   ... sondern ausgewiesen"                          "$(hin 'anderen Maschine')" "1"
pruef "⛔ GEGENKONTROLLE: ein echt toter Pfad bleibt tot"    "$(tot 'tools/gibtesnicht.py')" "1"
if [ -d "$HOME/.claude" ]; then
  pruef "⛔ GEGENKONTROLLE: ~/.claude/<fehlt> bleibt tot (HOME kennt den ersten Teil)" \
    "$(tot '~/.claude/rules/gibtsnicht_7q.md')" "1"
fi

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
