#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# ⛔ v5.166.0 (Etappe 65 Nachtrag 1): die Bedingung prueft der Block SELBST, angelegt wird nur ueber
#    mind_vorlage_anlegen (Liste je Lauf, Block 13 berichtet sie). Gemessen im A/B-Lauf 30.10.2026: die Bloecke
#    kopierten bedingungslos, das Gating stand nur im SKILL-Text — 6 Dateien angelegt, berichtet „keine“.
# Bedingung (Step 5, v3.3.0): kein tools/backup_tools.py im Projekt.
if [ -f "$PROJ/tools/backup_tools.py" ]; then
  echo "NICHT ANGELEGT: Backup-System — tools/backup_tools.py ist schon da"; exit 0
fi
mkdir -p "$PROJ/.claude-mind/backups"
# Overwrite-Guard: existiert eine Datei schon -> SKIP, NIE ueberschreiben.
# (update_changelog.py gehoert NICHT hierher — Release-Hygiene, Step 5b.)
for FILE in tools/backup_tools.py tools/rollback.py tools/mutation_guard.py docs/BACKUP_USAGE.md; do
  mind_vorlage_anlegen "$CLAUDE_PLUGIN_ROOT/references/backup-system-templates/$FILE" "$FILE"
done
# .backupignore nur, wenn es fehlt — bis v5.165.0 stand hier `cat >`, ein bestehendes wurde ueberschrieben.
if [ ! -e "$PROJ/.backupignore" ]; then
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
  printf '%s\n' ".backupignore" >> "$PROJ/.claude-mind/mind-files-angelegt-${LAUF:-ohne-lauf}.txt"
  echo "ANGELEGT: .backupignore"
fi
# .backuprc — projekt-spezifisch basierend auf project-scanner (Detection-Tabelle im SKILL-Text)
