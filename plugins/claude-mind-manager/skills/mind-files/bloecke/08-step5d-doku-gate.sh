#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# nur ausfuehren wenn Gating erfuellt UND User bestaetigt
mkdir -p "$PROJ/tools" "$PROJ/.claude/rules"

# 1. coverage_gate.py (stdlib-only, keine Fremd-Abhaengigkeit, kein Netzzugriff)
if [ -f "$PROJ/tools/coverage_gate.py" ]; then
  echo "SKIP: tools/coverage_gate.py existiert bereits (User fragen ob ueberschreiben)"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/doc-templates/coverage_gate.py" \
     "$PROJ/tools/coverage_gate.py"
fi

# 2. Companion-Rule wissenstransfer-pruefen.md (PFLICHT, Overwrite-Guard)
if [ -f "$PROJ/.claude/rules/wissenstransfer-pruefen.md" ]; then
  echo "SKIP: .claude/rules/wissenstransfer-pruefen.md existiert bereits (User fragen)"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/rule-templates/wissenstransfer-pruefen.md" \
     "$PROJ/.claude/rules/wissenstransfer-pruefen.md"
fi
