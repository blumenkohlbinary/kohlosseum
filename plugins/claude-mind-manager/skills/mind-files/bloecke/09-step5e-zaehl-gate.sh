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

if [ -f "$PROJ/tools/zaehl_gate.py" ]; then
  echo "SKIP: tools/zaehl_gate.py existiert bereits (User fragen ob ueberschreiben)"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/doc-templates/zaehl_gate.py" \
     "$PROJ/tools/zaehl_gate.py"
fi

# ⛔ KERN-INVARIANTE: kein Tool ohne glob-getriggerte Companion-Rule.
if [ -f "$PROJ/.claude/rules/zaehlwerte-pruefen.md" ]; then
  echo "SKIP: Rule existiert bereits"
else
  cp "$CLAUDE_PLUGIN_ROOT/references/rule-templates/zaehlwerte-pruefen.md" \
     "$PROJ/.claude/rules/zaehlwerte-pruefen.md"
fi
