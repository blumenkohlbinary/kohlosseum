#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-claudemd Step 1 — Bereich bestimmen und melden (v5.154.0).
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
. "$CLAUDE_PLUGIN_ROOT/skills/mind-claudemd/bloecke/_ziele.sh"   # v5.154.0: BEREICH/ZIEL_* aus Step 1
echo "Bereich: $BEREICH  ·  Ziel: $ZIEL_MD  ·  Rules: $ZIEL_RULES  ·  Wurzel: $ZIEL_WURZEL"
