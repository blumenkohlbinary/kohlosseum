#!/usr/bin/env bash
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Project rules — Syntax-Check (paths: vs globs:)
grep -rn '^paths:' .claude/rules/*.md 2>/dev/null

# Global rules (NEU v3.2.1)
grep -rn '^paths:' "$HOME"/.claude/rules/*.md 2>/dev/null
