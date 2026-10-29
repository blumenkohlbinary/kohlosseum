#!/usr/bin/env bash
# /mind-rules — aus skills/mind-rules/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
D="$PROJ/.claude-mind/schritt-mind-rules-duplikate.txt"
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_duplikate.py" --bereich "$PROJ" --nur projekt > "$D" 2>&1
head -40 "$D"
mind_schritt cleaner_duplikate gelaufen --datei "$D" "$PROJ"
