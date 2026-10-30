#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
mind_check_tools_have_rules "$PROJ"; TOOLCHECK_RC=$?
mind_ordner_hinweise "$PROJ"      # v5.127.0: HINWEIS je Top-Level-Ordner mit >= 5 ungenannten Skripten, kein Befund
# ⛔ v5.166.0 (Etappe 65 Nachtrag 1): was die Bloecke 03–09 angelegt haben, steht in der Liste DIESES Laufs —
#    der Bericht nennt GENAU diese Dateien (A/B-Lauf 30.10.2026: 6 angelegt, „keine“ berichtet).
_AL="$PROJ/.claude-mind/mind-files-angelegt-${LAUF:-ohne-lauf}.txt"
_AN=$(grep -c . "$_AL" 2>/dev/null); _AN=${_AN:-0}
echo "=== ANGELEGT in diesem Lauf: $_AN Datei(en) — genau diese in den Bericht (Zeile \"Angelegt:\"):"
[ "$_AN" -gt 0 ] && sed 's/^/  /' "$_AL"
[ -z "${LAUF:-}" ] && rm -f "$_AL"   # ohne Lauf-ID gaebe es sonst eine Liste ueber Laeufe hinweg
true
