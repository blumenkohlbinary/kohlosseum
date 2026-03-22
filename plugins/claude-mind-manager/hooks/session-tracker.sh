#!/bin/bash
# Claude Mind Manager — UserPromptSubmit Hook (Session Tracker)
# Increments a per-session message counter in /tmp for the Stop hook.
# No stdout — UserPromptSubmit output goes to context and we don't want noise.

INPUT=$(cat)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# --- Per-session counter in /tmp ---
if [ -n "$SESSION_ID" ]; then
  COUNTER_KEY="$SESSION_ID"
else
  COUNTER_KEY=$(echo "$PROJECT_DIR" | tr '/\\: ' '----' | sed 's/^-*//')
fi
COUNTER_FILE="/tmp/mind-msg-count-${COUNTER_KEY}"

if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

exit 0
