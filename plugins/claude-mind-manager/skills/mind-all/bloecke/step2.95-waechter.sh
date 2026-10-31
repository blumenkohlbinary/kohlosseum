#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-all — aus skills/mind-all/SKILL.md ausgelagert (v5.152.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# Der Snapshot aus Step 0 ist der Vorher-Stand — er wird hier zum Messinstrument.
MEMDIR=$(get_memory_dir "$PROJ" 2>/dev/null) || MEMDIR=""
# ⚠ v5.109.0: der Waechter vergleicht das WURZEL-Memory (Snapshot memory/). Die Memorys der
#   Roster-Ordner liegen unter memory-unterordner/<ordner>/ und werden hier NICHT verglichen —
#   ausgewiesen, nicht behoben (Etappe 18, Allbetroffenheit); ihr Rueckweg ist die Kopie.
# ⛔ v5.175.0 (Etappe 68 N1): quittiert sich selbst; rc 2 (ungueltig) als fehler, nie als gelaufen.
mkdir -p "$PROJ/.claude-mind/pass-mind-all" 2>/dev/null
_WA="$PROJ/.claude-mind/pass-mind-all/mind_zeilenenden_waechter.txt"
mind_zeilenenden_waechter "$MIND_SNAPSHOT_DIR" "$PROJ" "$MEMDIR" > "$_WA" 2>&1
RC=$?
cat "$_WA"
if [ "$RC" = 2 ]; then mind_schritt mind_zeilenenden_waechter "fehler:ungueltig" -1 "$PROJ"
else echo "rc=$RC" >> "$_WA"; mind_schritt mind_zeilenenden_waechter gelaufen --datei "$_WA" "$PROJ"; fi
[ "$RC" = 2 ] && echo "⛔ WAECHTER UNGUELTIG — Zeilenenden in diesem Lauf NICHT geprueft."
# v5.175.0 (Etappe 68 N1 Schnitt D): der naechste Aufruf woertlich.
echo "WEITER: bash \"$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step2.96-abschluss.sh\""
