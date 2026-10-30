#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
HAT_VERSION="nein"
for _s in VERSION pyproject.toml package.json; do
  [ -f "$PROJ/$_s" ] && HAT_VERSION="ja"
done
ls "$PROJ"/*.csproj >/dev/null 2>&1 && HAT_VERSION="ja"
[ -n "$(git -C "$PROJ" tag 2>/dev/null | head -1)" ] && HAT_VERSION="ja"
# HAT_VERSION=nein -> NICHT anbieten, sondern INFO: "kein Versions-Signal, der Changelog
#                     haette hier keine Quelle"
