#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# 1. Tools-Dir anlegen
mkdir -p "$PROJ/tools" "$PROJ/docs" "$PROJ/.claude-mind/backups"

# 2. Templates 1:1 ins Projekt schreiben (Read aus references/, Write ins Projekt)
# 3 Python-Files + 1 Doku-File:
# (update_changelog.py gehoert NICHT hierher — es ist Release-Hygiene, nicht Backup;
#  wird im Release-Hygiene-Bundle installiert, siehe Step 5b.)
# Overwrite-Guard PFLICHT (Hard Constraint "NEVER overwrite without confirmation"):
# existiert eine Datei schon -> SKIP + User fragen, NIE blind ueberschreiben.
for FILE in tools/backup_tools.py tools/rollback.py tools/mutation_guard.py docs/BACKUP_USAGE.md; do
  if [ -f "$PROJ/$FILE" ]; then
    echo "SKIP: $FILE existiert bereits (User fragen ob ueberschreiben)"
  else
    cp "$CLAUDE_PLUGIN_ROOT/references/backup-system-templates/$FILE" "$PROJ/$FILE"
  fi
done

# 3. .backupignore generieren (Standard-Defaults)
cat > "$PROJ/.backupignore" << 'EOF'
# .backupignore - Files die NICHT in Backups landen
# Format aehnlich .gitignore
node_modules/
__pycache__/
.venv/
.git/
dist/
build/
*.pyc
.DS_Store
.pytest_cache/
.coverage
EOF

# 4. .backuprc generieren — projekt-spezifisch basierend auf project-scanner
# (siehe Detection-Tabelle unten)
