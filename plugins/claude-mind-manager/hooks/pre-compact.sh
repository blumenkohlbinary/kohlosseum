#!/bin/bash
# Claude Mind Manager — PreCompact Hook
# Backs up MEMORY.md and CLAUDE.md before context compaction.
# Keeps last N backups (default 5) to prevent unbounded growth.

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "unknown"')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# --- Configurable ---
KEEP_COUNT="${MIND_BACKUP_KEEP_COUNT:-5}"

# --- Paths ---
MIND_DIR="$PROJECT_DIR/.claude-mind"
BACKUP_DIR="$MIND_DIR/backups"
# MEMORY.md stays at Claude Code's default location
HASH=$(echo "$PROJECT_DIR" | tr '/\\: ' '----' | sed 's/^-*//')
MEMORY_DIR="$HOME/.claude/projects/$HASH/memory"

# --- Create backup directory ---
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_COUNT=0

# --- Backup MEMORY.md ---
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
  cp "$MEMORY_DIR/MEMORY.md" "$BACKUP_DIR/MEMORY-${TIMESTAMP}.md"
  BACKUP_COUNT=$((BACKUP_COUNT + 1))
fi

# --- Backup project CLAUDE.md ---
for CMD_FILE in "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.claude/CLAUDE.md"; do
  if [ -f "$CMD_FILE" ]; then
    cp "$CMD_FILE" "$BACKUP_DIR/CLAUDE-${TIMESTAMP}.md"
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
    break
  fi
done

# --- Backup active-context.md ---
ACTIVE_CTX="$PROJECT_DIR/.claude/rules/active-context.md"
if [ -f "$ACTIVE_CTX" ]; then
  cp "$ACTIVE_CTX" "$BACKUP_DIR/active-context-${TIMESTAMP}.md"
  BACKUP_COUNT=$((BACKUP_COUNT + 1))
fi

# --- Rotate: keep only last N backups per type ---
for PREFIX in MEMORY CLAUDE active-context; do
  ls -t "$BACKUP_DIR/${PREFIX}-"*.md 2>/dev/null | tail -n +$((KEEP_COUNT + 1)) | xargs rm -f 2>/dev/null
done

# --- Save active context from transcript ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/save-context.sh" ]; then
  echo "$INPUT" | bash "$SCRIPT_DIR/save-context.sh"
fi

# --- Report (stdout goes to user transcript) ---
if [ "$BACKUP_COUNT" -gt 0 ]; then
  echo "[Mind Manager] Pre-compact backup: ${BACKUP_COUNT} file(s) saved (trigger: ${TRIGGER})"
fi

exit 0
