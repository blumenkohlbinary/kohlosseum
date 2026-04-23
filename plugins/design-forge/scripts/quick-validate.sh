#!/usr/bin/env bash
# quick-validate.sh — PostToolUse hook.
# Fast, non-blocking syntactic check on edited CSS/HTML files.
# Emits a subtle reminder if Magic Numbers or hardcoded colors are detected,
# but never blocks the edit (exit 0 always).
#
# Goal: <500ms execution. For deep audit, user runs /design-forge:audit.

set -u

FILE="${1:-}"

# No file passed → silent exit
if [ -z "$FILE" ]; then
  exit 0
fi

# Only care about CSS/HTML/JSX/TSX/Vue/Svelte
case "$FILE" in
  *.css|*.scss|*.sass|*.html|*.jsx|*.tsx|*.vue|*.svelte) ;;
  *) exit 0 ;;
esac

# File doesn't exist (edit may have been virtual) → silent
[ -f "$FILE" ] || exit 0

# Only run if .design-forge/ is initialized (opt-in behavior)
[ -d ".design-forge" ] || exit 0

WARNINGS=0
SPACING_GRID="4 8 12 16 24 32 48 64 96 128"

# 1) Hardcoded hex outside :root / token-like contexts
HARDCODE_COUNT=$(grep -cE '#[0-9a-fA-F]{3,6}\b' "$FILE" 2>/dev/null || echo 0)

# 2) Non-grid spacing values (simple heuristic, best-effort)
OFFGRID=$(grep -oE '(padding|margin|gap)\s*:\s*[0-9]+px' "$FILE" 2>/dev/null | grep -oE '[0-9]+' | awk -v grid="$SPACING_GRID" '
  BEGIN { n = split(grid, g, " "); for (i in g) set[g[i]] = 1 }
  { if (!($1 in set) && $1 != 0 && $1 < 200) print $1 }
' | sort -u | head -5)

# 3) !important count
BANG_COUNT=$(grep -c '!important' "$FILE" 2>/dev/null || echo 0)

# Emit silent reminder (exit 0 regardless)
if [ "$HARDCODE_COUNT" -gt 3 ] || [ -n "$OFFGRID" ] || [ "$BANG_COUNT" -gt 2 ]; then
  cat <<EOF
<design-forge-hint>
Quick-validate on $FILE:
  Hardcoded hex colors: $HARDCODE_COUNT (prefer tokens per guides/design-system.md)
  Off-grid spacing values: ${OFFGRID:-none} (grid: 4, 8, 12, 16, 24, 32, 48, 64)
  !important count: $BANG_COUNT
Run /design-forge:audit for full check.
</design-forge-hint>
EOF
fi

exit 0
