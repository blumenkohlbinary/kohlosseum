#!/usr/bin/env bash
# load-system.sh — SessionStart hook: inject .design-forge/system.md summary into context.
# Silent no-op if system.md missing. Fast (<500ms expected).

set -u

SYSTEM_FILE=".design-forge/system.md"

if [ ! -f "$SYSTEM_FILE" ]; then
  exit 0
fi

# Extract YAML frontmatter between first two --- markers, limit to 2000 chars
FRONTMATTER=$(awk '/^---$/{n++; next} n==1{print}' "$SYSTEM_FILE" 2>/dev/null | head -c 2000)

if [ -z "$FRONTMATTER" ]; then
  exit 0
fi

# Emit compact context injection
cat <<EOF
<design-forge-memory>
Project has .design-forge/system.md. Respect its tokens + rules + decisions during UI work.
Key frontmatter:
$FRONTMATTER
</design-forge-memory>
EOF

exit 0
