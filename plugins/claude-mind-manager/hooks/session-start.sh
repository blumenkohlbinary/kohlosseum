#!/bin/bash
# Claude Mind Manager — SessionStart Hook
# Checks MEMORY.md and CLAUDE.md line counts, rules syntax, outputs context injection.
# Exit 0 + stdout → injected as Claude context (SessionStart special behavior).

INPUT=$(cat)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# --- Compute project hash ---
# Path encoding: / → -, \ → -, : → -, space → -
HASH=$(echo "$PROJECT_DIR" | tr '/\\: ' '----' | sed 's/^-*//')

MEMORY_FILE="$HOME/.claude/projects/$HASH/memory/MEMORY.md"
WARNINGS=""
WARN_COUNT=0

# --- Configurable thresholds via env vars (set in settings.json env:{}) ---
MEMORY_THRESHOLD="${MIND_MEMORY_WARN_THRESHOLD:-180}"
CLAUDE_MD_THRESHOLD="${MIND_CLAUDE_MD_MAX_LINES:-200}"

# --- Check MEMORY.md ---
if [ -f "$MEMORY_FILE" ]; then
  MEM_LINES=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
  if [ "$MEM_LINES" -gt "$MEMORY_THRESHOLD" ]; then
    WARNINGS="${WARNINGS}MEMORY.md: ${MEM_LINES}/200 lines (threshold: ${MEMORY_THRESHOLD}). Run /mind:cleanup to free space. "
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
else
  MEM_LINES=0
fi

# --- Check project CLAUDE.md ---
for CMD_FILE in "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.claude/CLAUDE.md"; do
  if [ -f "$CMD_FILE" ]; then
    CMD_LINES=$(wc -l < "$CMD_FILE" | tr -d ' ')
    if [ "$CMD_LINES" -gt "$CLAUDE_MD_THRESHOLD" ]; then
      REL_PATH=$(echo "$CMD_FILE" | sed "s|$PROJECT_DIR/||")
      WARNINGS="${WARNINGS}${REL_PATH}: ${CMD_LINES} lines (threshold: ${CLAUDE_MD_THRESHOLD}). Compliance may degrade (>400 lines = 71%). Run /mind:optimize. "
      WARN_COUNT=$((WARN_COUNT + 1))
    fi
    break  # Only check first found
  fi
done

# --- Check CLAUDE.local.md deprecation ---
if [ -f "$PROJECT_DIR/CLAUDE.local.md" ]; then
  WARNINGS="${WARNINGS}CLAUDE.local.md detected. Anthropic indicates deprecation — consider migrating to @imports. Run /mind:optimize. "
  WARN_COUNT=$((WARN_COUNT + 1))
fi

# --- Check rules for paths: bug ---
RULES_DIR="$PROJECT_DIR/.claude/rules"
if [ -d "$RULES_DIR" ]; then
  BAD_RULES=$(grep -rl '^paths:' "$RULES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$BAD_RULES" -gt 0 ]; then
    WARNINGS="${WARNINGS}${BAD_RULES} rule file(s) use 'paths:' (known bug, may be silently ignored). Run /mind:rules migrate to fix. "
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
fi

# --- Output ---
if [ "$WARN_COUNT" -gt 0 ]; then
  # Structured JSON for SessionStart context injection
  ESCAPED_WARNINGS=$(echo "$WARNINGS" | sed 's/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[Mind Manager] %d warning(s): %s"}}' \
    "$WARN_COUNT" "$ESCAPED_WARNINGS"
fi

# --- Persist env vars for session ---
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "MIND_MEMORY_LINES=${MEM_LINES}" >> "$CLAUDE_ENV_FILE"
  echo "MIND_PROJECT_HASH=${HASH}" >> "$CLAUDE_ENV_FILE"
fi

exit 0
