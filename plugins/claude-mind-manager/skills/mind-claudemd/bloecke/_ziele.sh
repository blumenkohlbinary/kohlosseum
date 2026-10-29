#!/usr/bin/env bash
# /mind-claudemd — Bereich und Ziele (Step 1), EINE Stelle, gesourct von jedem Block, der
# BEREICH/ZIEL_MD/ZIEL_RULES/ZIEL_WURZEL liest (v5.154.0, Etappe 58 Hebel B). ⛔ Jeder Block ist ein eigener
# Prozess; bis v5.153.0 brach 4c mit „Step 1 nicht gelaufen, $ZIEL_MD leer" ab, wenn das Modell nichts uebertrug.
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
ARGS="${ARGUMENTS:-}"
PROJ=$(mind_projekt_wurzel 2>/dev/null) || PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"   # v5.80.0: Wurzel mit Roster; ohne lib.sh wie bisher

if echo "$ARGS" | grep -qE '(^|[[:space:]])global([[:space:]]|$)'; then
  BEREICH="global"
  ZIEL_MD="$HOME/.claude/CLAUDE.md"
  ZIEL_RULES="$HOME/.claude/rules"
  ZIEL_WURZEL="$HOME"          # ⛔ NICHT $HOME/.claude — siehe Step 4c
  ZEIGER="~/.claude/rules"
else
  BEREICH="projekt"
  ZIEL_MD="$PROJ/CLAUDE.md"
  [ -f "$ZIEL_MD" ] || ZIEL_MD="$PROJ/.claude/CLAUDE.md"
  ZIEL_RULES="$PROJ/.claude/rules"
  ZIEL_WURZEL="$PROJ"
  ZEIGER=".claude/rules"
  # ⛔ v5.106.0: die CLAUDE.md der Roster-Unterordner gehoeren zum Bestand (Kasten unten)
  UNTER_MD=$(mind_unterordner_kontext "$PROJ" 2>/dev/null | grep '/CLAUDE\.md$')
fi
