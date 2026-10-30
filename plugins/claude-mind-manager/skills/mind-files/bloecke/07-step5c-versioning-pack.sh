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
# Bedingung (Step 5c, v4.0): Python UND Primary code_app (Argument 1, aus dem project-scanner) UND Build-/Versions-Signal.
# Ohne Argument wird NICHTS angelegt — der Typ ist ein Urteil des Scanners, kein Dateimerkmal.
PRIMARY="${1:-}"
_SIG="nein"
for _s in build.py pyproject.toml VERSION; do [ -f "$PROJ/$_s" ] && _SIG="ja"; done
ls "$PROJ"/*.spec >/dev/null 2>&1 && _SIG="ja"
if ! { command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; } || [ "$PRIMARY" != "code_app" ] || [ "$_SIG" = "nein" ]; then
  echo "NICHT ANGELEGT: Versioning-Pack — Primary '${PRIMARY:-(kein Argument)}', Signal $_SIG"; exit 0
fi
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/release-templates/version.py" "tools/version.py"
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/rule-templates/release-build.md" ".claude/rules/release-build.md"
