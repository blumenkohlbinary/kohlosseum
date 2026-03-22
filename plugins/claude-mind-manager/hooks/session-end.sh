#!/bin/bash
# Claude Mind Manager — SessionEnd Hook
# Creates a session summary from the transcript and detects new dependencies.
# Writes to .claude-mind/sessions/session-YYYY-MM-DD-HHMM.md
# Appends dependency/command suggestions to .claude-mind/suggestions.md

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ -z "$PROJECT_DIR" ] || [ -z "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# --- Read message count (per-session counter) ---
if [ -n "$SESSION_ID" ]; then
  COUNTER_KEY="$SESSION_ID"
else
  COUNTER_KEY=$(echo "$PROJECT_DIR" | tr '/\\: ' '----' | sed 's/^-*//')
fi
COUNTER_FILE="/tmp/mind-msg-count-${COUNTER_KEY}"
MSG_COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  MSG_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
fi

# Skip trivially short sessions (< 3 messages)
if [ "$MSG_COUNT" -lt 3 ]; then
  rm -f "$COUNTER_FILE"
  exit 0
fi

# --- Ensure sessions directory ---
SESSIONS_DIR="$PROJECT_DIR/.claude-mind/sessions"
mkdir -p "$SESSIONS_DIR"

TIMESTAMP=$(date '+%Y-%m-%d-%H%M')
SESSION_FILE="$SESSIONS_DIR/session-${TIMESTAMP}.md"

# --- Extract key info from transcript (last 150 lines) ---
DECISIONS=""
ERRORS=""
FILE_CHANGES=""
KEY_COMMANDS=""

if [ -f "$TRANSCRIPT_PATH" ]; then
  TAIL_DATA=$(tail -150 "$TRANSCRIPT_PATH" 2>/dev/null)

  # Decisions: lines where assistant mentions deciding/choosing/using
  DECISIONS=$(echo "$TAIL_DATA" | jq -r '
    select(.type == "assistant" or .role == "assistant") |
    if .message then (.message.content // empty)
    elif .content then .content
    else empty end |
    if type == "array" then map(select(.type == "text") | .text) | join("\n")
    elif type == "string" then .
    else empty end
  ' 2>/dev/null | grep -iE '(decided|chose|using|switched to|went with|selected)' | head -5)

  # Errors: lines with error/fail/exception
  ERRORS=$(echo "$TAIL_DATA" | jq -r '
    select(.type == "assistant" or .role == "assistant") |
    if .message then (.message.content // empty)
    elif .content then .content
    else empty end |
    if type == "array" then map(select(.type == "text") | .text) | join("\n")
    elif type == "string" then .
    else empty end
  ' 2>/dev/null | grep -iE '(error|failed|exception|fix|bug)' | head -5)

  # File changes: tool_use with Write/Edit
  FILE_CHANGES=$(echo "$TAIL_DATA" | jq -r '
    select(.type == "tool_use" or .type == "tool_result") |
    select(.name == "Write" or .name == "Edit" or .name == "Bash") |
    "\(.name): \(.input.file_path // .input.command // "unknown" | tostring | .[0:80])"
  ' 2>/dev/null | sort -u | head -10)

  # Key commands: bash commands run
  KEY_COMMANDS=$(echo "$TAIL_DATA" | jq -r '
    select(.type == "tool_use") | select(.name == "Bash") |
    .input.command // empty | .[0:80]
  ' 2>/dev/null | head -8)
fi

# --- Write session summary ---
cat > "$SESSION_FILE" <<EOF
# Session Summary — ${TIMESTAMP}

- **Messages:** ${MSG_COUNT}
- **Project:** ${PROJECT_DIR}

## Decisions
${DECISIONS:-_No explicit decisions detected._}

## Errors Encountered
${ERRORS:-_No errors detected._}

## File Changes
${FILE_CHANGES:-_No file changes detected._}

## Key Commands
${KEY_COMMANDS:-_No commands detected._}
EOF

# --- Detect new dependencies and append suggestions ---
SUGGESTIONS=""
if [ -f "$TRANSCRIPT_PATH" ]; then
  # Detect npm install / pip install / cargo add
  NEW_DEPS=$(tail -150 "$TRANSCRIPT_PATH" 2>/dev/null | jq -r '
    select(.type == "tool_use") | select(.name == "Bash") |
    .input.command // empty
  ' 2>/dev/null | grep -oE '(npm install|pip install|cargo add) [^ ]+' | sort -u)

  if [ -n "$NEW_DEPS" ]; then
    SUGGESTIONS="- New dependencies installed: ${NEW_DEPS}"
  fi
fi

if [ -n "$SUGGESTIONS" ]; then
  mkdir -p "$PROJECT_DIR/.claude-mind"
  SUGGEST_FILE="$PROJECT_DIR/.claude-mind/suggestions.md"
  echo "" >> "$SUGGEST_FILE"
  echo "## Session ${TIMESTAMP}" >> "$SUGGEST_FILE"
  echo "$SUGGESTIONS" >> "$SUGGEST_FILE"
fi

# --- Reset counter ---
rm -f "$COUNTER_FILE"

# --- Report ---
echo "[Mind Manager] Session summary saved (${MSG_COUNT} messages) -> session-${TIMESTAMP}.md"

exit 0
