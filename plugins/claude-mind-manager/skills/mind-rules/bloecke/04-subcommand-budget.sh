#!/usr/bin/env bash
# /mind-rules — aus skills/mind-rules/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# 1. Was wurde tatsaechlich geladen, wann, und mit welchem Grund?
python "$CLAUDE_PLUGIN_ROOT/references/ladeprotokoll_auswertung.py"

# 2. Wie ist der Bestand aufgebaut? (Beleg / Vorfall / Code / reine Anweisung)
python "$CLAUDE_PLUGIN_ROOT/references/bestandsaufnahme.py" \
       --ordner "$PROJ/.claude/rules"
