#!/usr/bin/env bash
# /mind-claudemd — aus skills/mind-claudemd/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
. "$CLAUDE_PLUGIN_ROOT/skills/mind-claudemd/bloecke/_ziele.sh"   # v5.154.0: BEREICH/ZIEL_* aus Step 1
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# WICHTIG: Backup MIT cd ins Projekt-Verzeichnis VOR cp.
# Sonst landet relativer Pfad im aktuellen CWD (z.B. Mind-Manager-Workspace
# statt Ziel-Projekt — Bug aus Session 2026-05-29 Log 1 Tool 15).
# N2-Fix: $CLAUDE_PROJECT_DIR (Claude Code env var) bevorzugt, Fallback $(pwd)
# ⛔ v5.23.0: gesichert wird $ZIEL_MD aus Step 1 — NICHT ein blankes CLAUDE.md.
#    Bis v5.22.1 stand hier `cd "$PROJECT_DIR" && cp CLAUDE.md ...`. Bei einem
#    `global`-Lauf sicherte das die PROJEKT-Datei und meldete trotzdem "Backup OK",
#    waehrend gleich darauf `~/.claude/CLAUDE.md` editiert worden waere.
#    Ein falscher Beleg ist schlimmer als gar keiner.
# ⛔ Die Quittung NENNT die gesicherte Datei. Ohne den Namen ist ein Backup der
#    falschen Datei von einem richtigen nicht zu unterscheiden — genau der Fehler,
#    der v5.2.2 bei mind_check_tools_have_rules aufgefallen ist.
[ -n "$ZIEL_MD" ] || { echo "ABBRUCH: Step 1 nicht gelaufen, \$ZIEL_MD leer" >&2; exit 1; }
[ -f "$ZIEL_MD" ] || { echo "ABBRUCH: Zieldatei fehlt: $ZIEL_MD" >&2; exit 1; }
BDIR="$PROJ/.claude-mind/backups"
mkdir -p "$BDIR" && \
  cp "$ZIEL_MD" "$BDIR/CLAUDE.md.$BEREICH.$(date +%Y%m%d_%H%M%S).bak" && \
  echo "Backup OK: $(ls -t "$BDIR"/CLAUDE.md.$BEREICH.*.bak | head -1)" && \
  echo "  gesichert wurde: $ZIEL_MD  (Bereich $BEREICH)"
