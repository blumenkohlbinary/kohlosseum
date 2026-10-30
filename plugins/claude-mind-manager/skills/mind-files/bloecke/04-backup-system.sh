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
# Companion-Rule des Backup-Systems: nur, wenn das Werkzeug da ist (No Dead Tools — und keine Rule ohne Tool).
if [ ! -f "$PROJ/tools/backup_tools.py" ]; then
  echo "NICHT ANGELEGT: backup-usage.md — kein tools/backup_tools.py"; exit 0
fi
# ⛔ v5.167.0: Tool-Bundles bleiben ein ANGEBOT, auch autonom (SKILL.md, Abschnitt Autonomie) — angelegt nur mit
#    --anlegen, das nach Bestaetigung (--ask) uebergeben wird. 5.166.0 legte bei erfuellter Bedingung an; 5.151.0 nie.
case " $* " in *" --anlegen "*) ;; *) echo "ANGEBOT (nicht angelegt): backup-usage.md — Bedingung erfuellt, angelegt nur mit --anlegen nach Bestaetigung"; exit 0 ;; esac
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/rule-templates/backup-usage.md" ".claude/rules/backup-usage.md"
