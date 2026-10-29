#!/usr/bin/env bash
# /mind-memory — aus skills/mind-memory/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# ⛔ v5.145.0 (Etappe 55 §5, Veras Befund M-D, Zustellplan 11./12.10.2026): 7 von 40 Zeilen
#    wurden als TOT gemeldet, und ALLE SIEBEN existierten — sie zeigen auf `docs/…` im Projekt.
#    Der vorgeschriebene Fix („Zeile entfernen") haette sieben gueltige Zeiger geloescht.
#    Deshalb wird vor dem Urteil TOT auch relativ zur PROJEKTWURZEL aufgeloest.
# ⚠ Eigener Bash-Aufruf: MEMORY_DIR und PROJ kommen aus Step 1 nicht mit. Ohne MEMORY_DIR
#   waere die Schleife leer und saehe aus wie „alles in Ordnung".
[ -n "${MEMORY_DIR:-}" ] && [ -f "$MEMORY_DIR/MEMORY.md" ] || {
  echo "⛔ Index-Pruefung NICHT gefahren: MEMORY_DIR fehlt oder ohne MEMORY.md ('${MEMORY_DIR:-}')"; exit 2; }
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"   # v5.80.0: die Wurzel mit Roster
grep -o '](\([^)]*\.md\))' "$MEMORY_DIR/MEMORY.md" | sed 's/](//;s/)//' | while read -r z; do
  [ -f "$MEMORY_DIR/$z" ] && continue
  b=$(basename "$z")
  if [ -f "$MEMORY_DIR/$b" ]; then echo "PRAEFIX: $z -> $b"
  elif [ -f "$PROJ/$z" ]; then echo "PROJEKT: $z (gueltig, liegt im Projekt)"
  else echo "TOT: $z"; fi
done
