#!/usr/bin/env bash
# /mind-claudemd — aus skills/mind-claudemd/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
. "$CLAUDE_PLUGIN_ROOT/skills/mind-claudemd/bloecke/_ziele.sh"   # v5.154.0: BEREICH/ZIEL_* aus Step 1
PIPE="$CLAUDE_PLUGIN_ROOT/references/claudemd_pipeline.py"
python "$PIPE" "$ZIEL_MD" --projekt "$ZIEL_WURZEL"
# ⛔ v5.23.1: BEIDE aus Step 1. Bis v5.23.0 stand hier `"<ziel.md>"` und
#    `--projekt "$PROJ"` — bei einem `global`-Lauf also die
#    Projekt-Wurzel, waehrend die Zieldatei ~/.claude/CLAUDE.md war. Check 18 sucht
#    `<wurzel>/.claude/rules` und fand nichts: GEMESSEN 0 rules statt 15.
#    Eine falsche Null sieht aus wie ein Befund und ist eine Nichtmessung.
# Rueckgabe: 0 = keine Befunde · 1 = Befunde · 2 = Aufruffehler
#            3 = MESSUNG UNGUELTIG (Instrumentenkontrolle durchgefallen) -> Zahlen verwerfen
python "$PIPE" --selbsttest      # 22 Pruefungen, vor jedem Zweifelsfall
