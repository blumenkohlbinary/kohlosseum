#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Pytest verfuegbar UND tests/ existiert?
if [ -d "tests/" ] && (command -v pytest &>/dev/null || [ -x ".venv/Scripts/python.exe" ]); then
  # Source of Truth: pytest --collect-only
  if [ -x ".venv/Scripts/python.exe" ]; then
    REAL_COUNT=$(.venv/Scripts/python -m pytest tests/ --collect-only -q 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)
  else
    REAL_COUNT=$(pytest tests/ --collect-only -q 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)
  fi

  if [ -n "$REAL_COUNT" ] && [ "$REAL_COUNT" -gt 0 ]; then
    # Grep alle Custom-Context-Files fuer hardcoded Test-Counts
    # Pattern: '\b\d{2,4}\s+[Tt]ests?\b' (z.B. "434 Tests", "283 tests")
    # Mismatch → Finding (AUTO bei Drift <10%, ASK bei groesserer)
    :  # Logik in Step 4 implementiert
  fi
else
  # Skip — nicht-Python oder kein tests/-Dir
  REAL_COUNT=""
fi
