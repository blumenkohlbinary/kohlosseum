#!/usr/bin/env bash
# /mind-rules — aus skills/mind-rules/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Die Pruefung, die gefehlt hat:
for f in "$RULES_DIR"/*.md; do
  head -1 "$f" | grep -q '^---$' || continue          # kein Frontmatter -> anderer Fall
  [ "$(grep -c '^---$' "$f")" -ge 2 ] || echo "CRITICAL: $f — Frontmatter nie geschlossen"
done
