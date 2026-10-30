#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# VOR der Auswertung pruefen, ob die Konvention ueberhaupt vorkommt:
TREFFER=$(git log --oneline -50 | grep -cE '^[0-9a-f]+ (feat|fix|refactor|perf|docs|test|chore)')
if [ "$TREFFER" -eq 0 ]; then
  echo "Schritt 3c: NICHT ANWENDBAR — keine Conventional-Commits-Praefixe in den letzten"
  echo "  50 Commits. Das ist KEIN '0 Luecken'."
  # Hat das Projekt eine eigene Konvention, gehoert ihr Muster in CLAUDE.md und hierher.
fi
