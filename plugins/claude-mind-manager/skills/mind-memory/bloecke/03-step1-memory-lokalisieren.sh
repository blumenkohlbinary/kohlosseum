#!/usr/bin/env bash
# /mind-memory — aus skills/mind-memory/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Hash + Memory-Verzeichnis (v3.2.2: zentralisiert in lib.sh)
# Korrektes Windows-Slug-Mapping via cygpath (siehe lib.sh hash_project_dir)
# Beispiel: C:\CD\KOHLEKTIV\Plugin - Entwicklung -> C--CD-KOHLEKTIV-Plugin---Entwicklung
# M3-Fix: $CLAUDE_PLUGIN_ROOT Guard
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
if [ -z "$CLAUDE_PLUGIN_ROOT" ] || [ ! -f "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" ]; then
  echo "ERROR: \$CLAUDE_PLUGIN_ROOT nicht gesetzt oder lib.sh nicht gefunden" >&2
  exit 1
fi
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
MEMORY_DIR=$(get_memory_dir)
# ⛔ v5.109.0 (Etappe 18, Nutzer 14.09.2026: "jedes fork hat eigenen memory"): im
#    Rollen-Aufbau hat JEDER Roster-Unterordner sein eigenes Memory (eigener Slug).
#    Gemessen Creator: Wurzel 3 Dateien / 5 676 B, `Creator Stimme` 7 / 39 707 B — und
#    jeder Lauf sah nur die Wurzel. Alle Verzeichnisse, feste Reihenfolge:
MEMORY_DIRS=$(mind_memory_dirs "$PROJ" 2>/dev/null); [ -n "$MEMORY_DIRS" ] || MEMORY_DIRS="$MEMORY_DIR"
#    Die Schritte 1–4 laufen JE VERZEICHNIS getrennt (`while IFS= read -r MEMORY_DIR; do … done
#    <<<"$MEMORY_DIRS"`), der Bericht nennt jede Datei als `memory[<ordner>]/<name>` (Wurzel:
#    `memory/<name>`). ⛔ NIE ueber Slugs hinweg zusammenfuehren, deduplizieren oder
#    auslagern — jedes Verzeichnis gehoert einer ANDEREN Sitzung. Derselbe Fakt in zwei Slugs
#    ist ein BEFUND fuer /mind-cleaner (Duplikat), kein Merge. Die Sicherung vor dem Lauf
#    (backup-usage.md) sichert schon alle `projects/*/memory`, `memory_gates.py` vergleicht je Slug.
