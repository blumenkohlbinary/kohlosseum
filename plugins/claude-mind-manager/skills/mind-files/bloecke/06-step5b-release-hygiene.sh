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
# Bedingung (Step 5b, v5.7.0): Git-Repo UND Versions-Signal. Bis v5.165.0 lag HAT_VERSION in Block 05 —
# hier war es leer, kopiert wurde bei jedem Git-Repo (Prozessgrenze, neunter Fall).
HAT_VERSION="nein"
for _s in VERSION pyproject.toml package.json; do
  [ -f "$PROJ/$_s" ] && HAT_VERSION="ja"
done
ls "$PROJ"/*.csproj >/dev/null 2>&1 && HAT_VERSION="ja"
[ -n "$(git -C "$PROJ" tag 2>/dev/null | head -1)" ] && HAT_VERSION="ja"
if [ ! -d "$PROJ/.git" ] || [ "$HAT_VERSION" = "nein" ]; then
  echo "NICHT ANGELEGT: Release-Hygiene — Git-Repo $([ -d "$PROJ/.git" ] && echo ja || echo nein), Versions-Signal $HAT_VERSION"; exit 0
fi
command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || echo "WARN: Python nicht gefunden. update_changelog.py installiert aber NICHT lauffaehig."
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/backup-system-templates/tools/update_changelog.py" "tools/update_changelog.py"
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/rule-templates/release-hygiene.md" ".claude/rules/release-hygiene.md"
