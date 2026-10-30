#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-memory — aus skills/mind-memory/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
ABSCHNITT="$PROJ/.claude-mind/lauf-abschnitt-mind-memory.md"
BEFUNDE="$PROJ/.claude-mind/lauf-befunde-mind-memory.jsonl"
# ⚠ Ein Abschnitt aus einem FRUEHEREN Lauf zaehlt nicht — aelter als 2 h heisst: neu anlegen.
[ -n "$(find "$ABSCHNITT" -mmin -120 2>/dev/null)" ] || \
  printf '## %s — /mind-memory\n\n### Probleme in diesem Lauf\n- (keine)\n' "$(date '+%Y-%m-%d %H:%M')" > "$ABSCHNITT"
[ -f "$BEFUNDE" ] || : > "$BEFUNDE"
mind_debug_write "$PROJ" "mind-memory" "$ABSCHNITT" "$BEFUNDE"
mind_schritt mind_debug_write gelaufen --datei "$ABSCHNITT" "$PROJ"
