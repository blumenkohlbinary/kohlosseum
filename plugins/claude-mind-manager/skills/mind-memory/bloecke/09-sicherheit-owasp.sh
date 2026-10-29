#!/usr/bin/env bash
# /mind-memory — aus skills/mind-memory/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# ⛔ v5.147.0 (Etappe 56 §5): EINE ZAEHLZEILE AM ENDE. Ohne Fund gab der Scan 0 Byte aus — die
#    Quittung war LEER, und „nichts gefunden" war von „nicht gelaufen" nicht zu trennen (zweites
#    Auftreten, CK3). `DATEIEN=0` heisst jetzt: der Scan hatte keinen Gegenstand (MEMORY_DIR leer?).
S="$PROJ/.claude-mind/schritt-mind-memory-poisoning.txt"; : > "$S"; _n=0
for f in "$MEMORY_DIR"/*.md; do [ -f "$f" ] || continue; _n=$((_n+1)); mind_scan_poisoning "$f" >> "$S"; done
echo "DATEIEN=$_n BEFUNDE=$(grep -c '^BEFUND|' "$S") HINWEISE=$(grep -c '^HINWEIS|' "$S")" >> "$S"; cat "$S"
mind_schritt mind_scan_poisoning gelaufen --datei "$S" "$PROJ"
# Ausgabe je Fund: BEFUND|<art>|<zeile>|<detail>  bzw.  HINWEIS|...  — danach die Zaehlzeile
