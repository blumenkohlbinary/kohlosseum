#!/bin/bash
# Claude Mind Manager — UserPromptSubmit Hook (Session Tracker)
# Increments a per-project message counter in /tmp for the SessionEnd hook.
# No stdout — UserPromptSubmit output goes to context and we don't want noise.

INPUT=$(cat)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# --- Per-project counter in /tmp ---
HASH=$(echo "$PROJECT_DIR" | tr '/\\: ' '----' | sed 's/^-*//')
COUNTER_FILE="/tmp/mind-session-count-${HASH}"

if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

exit 0
