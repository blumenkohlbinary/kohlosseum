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
# Bedingung (Step 5d, v5.3.0): Python UND (docs/ ODER >= 10 .md ausserhalb vendor-/Beispiel-Ordnern).
_MD=$(find "$PROJ" -name '*.md' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/Beispiele/*' \
        -not -path '*/.claude-mind/*' 2>/dev/null | head -10 | wc -l | tr -d ' ')
if ! { command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; } || { [ ! -d "$PROJ/docs" ] && [ "${_MD:-0}" -lt 10 ]; }; then
  echo "NICHT ANGELEGT: Doku-Gate — Python oder Doku-Flaeche fehlt (docs/ $([ -d "$PROJ/docs" ] && echo ja || echo nein), .md ${_MD:-0})"; exit 0
fi
# ⛔ v5.167.0: Tool-Bundles bleiben ein ANGEBOT, auch autonom (SKILL.md, Abschnitt Autonomie) — angelegt nur mit
#    --anlegen, das nach Bestaetigung (--ask) uebergeben wird. 5.166.0 legte bei erfuellter Bedingung an; 5.151.0 nie.
case " $* " in *" --anlegen "*) ;; *) echo "ANGEBOT (nicht angelegt): Doku-Gate — Bedingung erfuellt, angelegt nur mit --anlegen nach Bestaetigung"; exit 0 ;; esac
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/doc-templates/coverage_gate.py" "tools/coverage_gate.py"
mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/rule-templates/wissenstransfer-pruefen.md" ".claude/rules/wissenstransfer-pruefen.md"
