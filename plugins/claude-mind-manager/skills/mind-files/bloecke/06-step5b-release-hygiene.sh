#!/usr/bin/env bash
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
if [ -d "$PROJ/.git" ]; then
  mkdir -p "$PROJ/tools" "$PROJ/.claude/rules"

  # update_changelog.py ist ein PYTHON-Tool -> ohne Interpreter waere es ein totes Tool.
  # Python-Detection; fehlt Python -> WARN (analog Backup-Bundle), Install laeuft trotzdem.
  if ! (python --version >/dev/null 2>&1 || python3 --version >/dev/null 2>&1); then
    echo "WARN: Python nicht gefunden. update_changelog.py installiert aber NICHT lauffaehig"
    echo "      bis Python installiert ist (die Conventional-Commit-Regeln gelten trotzdem)."
  fi

  # 1. Changelog-Engine (git-basiert) — gehoert hierher, NICHT zum Backup-Bundle. Overwrite-Guard.
  if [ -f "$PROJ/tools/update_changelog.py" ]; then
    echo "SKIP: tools/update_changelog.py existiert bereits (User fragen ob ueberschreiben)"
  else
    cp "$CLAUDE_PLUGIN_ROOT/references/backup-system-templates/tools/update_changelog.py" \
       "$PROJ/tools/update_changelog.py"
  fi

  # 2. Companion-Rule (Overwrite-Guard: nie ueberschreiben, ASK default Skip)
  if [ -f "$PROJ/.claude/rules/release-hygiene.md" ]; then
    echo "SKIP: .claude/rules/release-hygiene.md existiert bereits (User fragen)"
  else
    cp "$CLAUDE_PLUGIN_ROOT/references/rule-templates/release-hygiene.md" \
       "$PROJ/.claude/rules/release-hygiene.md"
  fi
fi
