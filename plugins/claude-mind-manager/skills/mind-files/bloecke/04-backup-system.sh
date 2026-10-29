#!/usr/bin/env bash
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
mkdir -p "$PROJ/.claude/rules"
# Overwrite-Guard: existiert die Rule schon -> NICHT ueberschreiben (ASK, default Skip)
if [ -f "$PROJ/.claude/rules/backup-usage.md" ]; then
  echo "SKIP: .claude/rules/backup-usage.md existiert bereits (User fragen ob ueberschreiben)"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/rule-templates/backup-usage.md" \
     "$PROJ/.claude/rules/backup-usage.md"
fi
