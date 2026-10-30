#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-all — aus skills/mind-all/SKILL.md ausgelagert (v5.152.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# ⛔ v5.144.0 (Etappe 56 §1): DIESER BLOCK IST SELBSTTRAGEND. Er ist ein eigener Bash-Aufruf —
#    `$PROJ`, `$SCOPES_FILE`, `$LAUF` und `mind_lauf_frei` aus Step 0 kommen hier NICHT an.
#    Bis v5.143.0 war das gleichgueltig, weil der trap aus Step 0 den Lock schon nach dem
#    ersten Block entfernt hatte. Seit er haelt, ist dies die EINZIGE Freigabe im Normalweg.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
SCOPES_FILE="${SCOPES_FILE:-$PROJ/.claude-mind/analyzed-scopes}"
# ⚠ Die eigene Lauf-ID aus der Kopfzeile dieses Laufs — `mind_lauf_frei` gibt nur frei, wenn
#   der Lock DIESE ID traegt; einem fremden Lauf wird nichts weggeraeumt.
LAUF="${LAUF:-$(mind_kopf_lauf "$PROJ" 2>/dev/null)}"
[ -f "$SCOPES_FILE" ] && mv -f "$SCOPES_FILE" "${SCOPES_FILE}.done" 2>/dev/null
# ⛔ v5.30.0: Sperre freigeben — NUR die eigene. `mind_lauf_frei` prueft die
#    Kennung; ein abbrechender Zweitlauf raeumt dem Erstlauf nichts weg.
#    ⚠ Der `trap` aus Step 0 faengt den Abbruchfall; dieser Aufruf ist der
#      Normalweg und macht die Freigabe im Bericht sichtbar.
mind_lauf_frei "$PROJ" "${LAUF:-}" \
  && echo "Sperre freigegeben (Lauf ${LAUF:-?})."
