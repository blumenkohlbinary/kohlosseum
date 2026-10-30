#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.153.0: QUICK_MODE kam aus Step 2.5 — einem anderen Prozess. Dieselbe Herleitung hier.
ARGS="${ARGUMENTS:-}"
QUICK_MODE="no"
echo "$ARGS" | grep -qE '(^|[[:space:]])--quick([[:space:]]|$)' && QUICK_MODE="yes"
if [ "$QUICK_MODE" != "yes" ]; then
  RULES_HITS=0
  for f in .claude/rules/*.md "$HOME"/.claude/rules/*.md; do
    [ -f "$f" ] || continue
    # Versions-Patterns nur mit Kontext-Keyword (Stable/Unstable/Last sync/Tabelle/Bullet/Code)
    # ⛔ v5.147.0 (Etappe 56 §5, CK3): der letzte Teil hoechstens DREI Ziffern — `10.09.2026` ist
    #    ein Datum (vierstelliges Jahr), keine Version; das alte Muster las es als Drift.
    hits=$(grep -nE "v?[0-9]+\.[0-9]+\.[0-9]{1,3}(-dev\.[0-9]+)?([^0-9]|$)" "$f" 2>/dev/null | \
           grep -iE "(stable|unstable|tag|commit|last sync|^[[:space:]]*[-*|\`])" )
    # Test-Counts nur mit Test-Keyword in derselben Zeile
    hits2=$(grep -nE "\b[0-9]{2,4}\s+(pytest-)?[Tt]ests?\b" "$f" 2>/dev/null | \
            grep -iE "(gruen|gruene|passed|collected|pytest|coverage)")
    if [ -n "$hits$hits2" ]; then
      echo "=== $f ($(wc -l < "$f") Zeilen) ==="
      [ -n "$hits" ] && echo "$hits"
      [ -n "$hits2" ] && echo "$hits2"
      RULES_HITS=$((RULES_HITS + 1))
    fi
  done
  echo "Rules-Files mit potentieller Drift: $RULES_HITS"
fi
