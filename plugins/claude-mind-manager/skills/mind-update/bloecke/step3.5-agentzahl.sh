#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# ⛔ v5.64.0: HIER WURDE DER KONTEXT GEMESSEN. Das faellt komplett weg.
#    Nutzer-Entscheidung 10.09.2026: "die sollen garnicht mehr tokens messen
#    das soll komplett raus". Weder die Agentenzahl noch der Abbruch haengen
#    noch an einer Tokenzahl — `AGENT_MAX` ist fest 4.
# ⭐ GEMESSEN, warum: der Tokenstand kam aus einem Merker je PROJEKT, und im
#    selben Ordner arbeiten mehrere Rollen. Die Zahl gehoerte zuverlaessig einer
#    fremden Sitzung (Palvedo, 10.09.2026: ~130 000 echt gegen 721 405 gemeldet).
# ⛔ DAS TEILSYNC-VERBOT BLEIBT — gemessen wird HINTERHER, an der Quittung:
#    kommt ein Agent leer zurueck, steht er in `ungepruef=`, `mind_sync_voll`
#    sagt "teil", und die Schuld bleibt liegen.
AGENT_MAX=4
AGENT_SOLL=$AGENT_MAX          # Step 2.96a von mind-all liest das
