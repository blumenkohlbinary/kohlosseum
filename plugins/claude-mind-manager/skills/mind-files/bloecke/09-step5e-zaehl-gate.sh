#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# ⛔ v5.166.0 (Etappe 65 Nachtrag 1): die Bedingung prueft der Block SELBST, angelegt wird nur ueber
#    mind_vorlage_anlegen (Liste je Lauf, Block 13 berichtet sie). Gemessen im A/B-Lauf 30.10.2026: die Bloecke
#    kopierten bedingungslos, das Gating stand nur im SKILL-Text — 6 Dateien angelegt, berichtet „keine“.
# Bedingung (Step 5e, v5.11.0): Python UND >= 3 Zahlen in CLAUDE.md/.claude/rules UND noch KEIN zaehl_gate.py im Projekt
# (hier liegt es unter Learnings/ — ein zweites daneben waere ein Nachbau, werkzeuge-zuerst.md).
_DA=$(find "$PROJ" -maxdepth 3 -name 'zaehl_gate.py' -not -path '*/.claude-mind/*' 2>/dev/null | head -1)
_Z=$(cat "$PROJ/CLAUDE.md" "$PROJ"/.claude/rules/*.md 2>/dev/null | grep -oE '\b[0-9]+\b' | head -3 | wc -l | tr -d ' ')
if [ -n "$_DA" ] || ! { command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; } || [ "${_Z:-0}" -lt 3 ]; then
  if [ -n "$_DA" ]; then echo "NICHT ANGELEGT: Zaehl-Gate — schon da: ${_DA#"$PROJ"/}"
  else echo "NICHT ANGELEGT: Zaehl-Gate — Python oder Zahlen fehlen (${_Z:-0} Zahlen)"; fi
  exit 0
fi
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/doc-templates/zaehl_gate.py" "tools/zaehl_gate.py"
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/rule-templates/zaehlwerte-pruefen.md" ".claude/rules/zaehlwerte-pruefen.md"
