#!/usr/bin/env bash
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# nur ausfuehren wenn Gating erfuellt UND User bestaetigt
mkdir -p "$PROJ/tools" "$PROJ/.claude/rules"

# 1. version.py (stdlib-only, kein PyInstaller-Teil)
if [ -f "$PROJ/tools/version.py" ]; then
  echo "SKIP: tools/version.py existiert bereits (User fragen ob ueberschreiben)"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/release-templates/version.py" \
     "$PROJ/tools/version.py"
fi

# 2. Companion-Rule release-build.md (PFLICHT, Overwrite-Guard)
if [ -f "$PROJ/.claude/rules/release-build.md" ]; then
  echo "SKIP: .claude/rules/release-build.md existiert bereits (User fragen)"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/rule-templates/release-build.md" \
     "$PROJ/.claude/rules/release-build.md"
fi
