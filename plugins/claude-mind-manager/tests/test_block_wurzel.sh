#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Jeder Block findet lib.sh auch OHNE gesetztes CLAUDE_PLUGIN_ROOT (v5.163.0, Etappe 65 §1.1).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Messlauf 20261030-030527): die Bash der Desktop-App setzt CLAUDE_PLUGIN_ROOT
#    NICHT. Der Kopf setzte ihn per Rueckfall, ohne `export` — jeder Block als Kindprozess sah ihn leer,
#    `[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source …` uebersprang STILL, dann `mind_block_umgebung: command not
#    found`. Rita musste den Lock entfernen und den Kopf neu fahren.
# Gegen 5.162.0 sind Abschnitt 1 und 2 rot.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

echo "=== 1) JEDER Block leitet die Wurzel her, bevor er lib.sh laedt ==="
fehl=0; n=0
for b in "$R"/skills/*/bloecke/*.sh; do
  n=$((n+1))
  w=$(grep -n 'CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE\[0\]}")' "$b" | head -1 | cut -d: -f1)
  s=$(grep -n 'source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"' "$b" | head -1 | cut -d: -f1)
  { [ -n "$w" ] && [ -n "$s" ] && [ "$w" -lt "$s" ]; } || { fehl=$((fehl+1)); echo "      fehlt: ${b#$R/}"; }
done
pruef "alle $n Bloecke" "$fehl" "0"

echo "=== 2) ein echter Block startet OHNE die Variable ==="
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
A=$( cd "$TMP" && env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$TMP" bash "$R/skills/mind-all/bloecke/step-1-debug.sh" 2>&1 )
pruef "kein 'command not found'" "$(printf '%s\n' "$A" | grep -c 'command not found')" "0"

echo "=== 3) jeder Kopf-Fence exportiert die Variable ==="
fehl=0
for s in "$R"/skills/*/SKILL.md; do
  grep -q 'mind_schritt_start' "$s" || continue
  grep -q '^export CLAUDE_PLUGIN_ROOT' "$s" || { fehl=$((fehl+1)); echo "      fehlt: ${s#$R/}"; }
done
pruef "kein Kopf ohne export" "$fehl" "0"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
