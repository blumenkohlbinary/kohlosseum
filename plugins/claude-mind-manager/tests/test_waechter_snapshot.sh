#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Der Zeilenenden-Waechter (mind-all Step 2.95) findet den Snapshot DIESES Laufs (v5.161.0, Etappe 63 N1).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): der Waechter meldete `UNGUELTIG` (VERGLICHEN=0) —
#    `MIND_SNAPSHOT_DIR` setzte seit Hebel B (5.152.0) niemand mehr, und Step 2.9 hatte analyzed-scopes schon
#    nach `.done` umbenannt. Rita fuhr ihn von Hand: 87 verglichen, 0 gekippt.
# ⛔ Und die Gegenrichtung: eine `.done` eines FREMDEN Laufs darf NICHT als Snapshot gelten.
# Gegen 5.161.0 sind Abschnitt 1 und 2 rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; SN="$P/.claude-mind/snapshots/20261030_003212_pre-mind-all"
mkdir -p "$SN/project/.claude/rules" "$P/.claude/rules"
for f in CLAUDE.md .claude/rules/a.md; do printf 'x\ny\n' > "$SN/project/$f"; printf 'x\ny\n' > "$P/$f"; done
LAUF="20261030-003203-604ab6140"
scopes() {  # $1 = Datei, $2 = Lauf-ID in der skill=-Zeile
  printf 'run_started=1793316732\nsnapshot=%s\nskill=mind-files|%s\n' "$SN" "$2" > "$1"
}
waechter() {
  ( cd "$P" && env -u MIND_SNAPSHOT_DIR LAUF="$LAUF" CLAUDE_PROJECT_DIR="$P" PROJ="$P" \
      bash "$R/skills/mind-all/bloecke/step2.95-waechter.sh" 2>&1 )
}

echo "=== 1) nach Step 2.9: .done mit DIESER Lauf-ID -> der Waechter vergleicht ==="
scopes "$P/.claude-mind/analyzed-scopes.done" "$LAUF"
A=$(waechter)
pruef "VERGLICHEN=2" "$(printf '%s\n' "$A" | grep -c '^VERGLICHEN=2 ')" "1"
pruef "⛔ kein UNGUELTIG" "$(printf '%s\n' "$A" | grep -c 'UNGUELTIG')" "0"

echo "=== 2) waehrend des Laufs: die lebende analyzed-scopes zaehlt ohne Weiteres ==="
rm -f "$P/.claude-mind/analyzed-scopes.done"; scopes "$P/.claude-mind/analyzed-scopes" "irgendwas"
pruef "VERGLICHEN=2" "$(waechter | grep -c '^VERGLICHEN=2 ')" "1"
rm -f "$P/.claude-mind/analyzed-scopes"

echo "=== 3) ⛔ .done eines FREMDEN Laufs -> KEIN Snapshot, UNGUELTIG bleibt ==="
scopes "$P/.claude-mind/analyzed-scopes.done" "20261029-235959-anderer"
B=$(waechter)
pruef "VERGLICHEN=0" "$(printf '%s\n' "$B" | grep -c '^VERGLICHEN=0 ')" "1"
pruef "UNGUELTIG gemeldet" "$(printf '%s\n' "$B" | grep -c 'UNGUELTIG')" "1"

echo "=== 4) gekippte Datei wird gefunden (Instrument misst) ==="
scopes "$P/.claude-mind/analyzed-scopes.done" "$LAUF"; printf 'x\r\ny\r\n' > "$P/CLAUDE.md"
pruef "GEKIPPT=1" "$(waechter | grep -c 'GEKIPPT=1')" "1"

echo "=== 5) ⛔ der Start-Snapshot eines laufenden Laufs rotiert nicht weg (v5.174.0, Ritas Lauf 30.10.2026) ==="
# Vier Teil-Snapshots der Kette bei KEEP=3: vorher fiel der aelteste — der Start-Snapshot — heraus.
Q="$TMP/rotation"; mkdir -p "$Q/.claude-mind/snapshots/20261030_225139_pre-mind-all" "$Q/.claude/rules"
printf 'x\n' > "$Q/CLAUDE.md"
touch -d '2026-10-30 22:51:39' "$Q/.claude-mind/snapshots/20261030_225139_pre-mind-all"
printf 'snapshot=%s\n' "$Q/.claude-mind/snapshots/20261030_225139_pre-mind-all" > "$Q/.claude-mind/analyzed-scopes"
for l in pre-rules pre-verdichten pre-update pre-memory; do
  ( . "$R/hooks/lib.sh"; MIND_SNAPSHOT_KEEP_COUNT=3 mind_snapshot "$Q" "$l" >/dev/null 2>&1 )
done
pruef "Start-Snapshot steht noch" "$([ -d "$Q/.claude-mind/snapshots/20261030_225139_pre-mind-all" ] && echo ja || echo nein)" "ja"
pruef "   ... die Rotation wirkt trotzdem (hoechstens KEEP + Start)" "$(ls -d "$Q/.claude-mind/snapshots"/*/ | wc -l | tr -d ' ')" "4"
rm -f "$Q/.claude-mind/analyzed-scopes"
( . "$R/hooks/lib.sh"; MIND_SNAPSHOT_KEEP_COUNT=3 mind_snapshot "$Q" pre-files >/dev/null 2>&1 )
pruef "Gegenprobe: ohne laufende Kette rotiert er wie bisher" "$([ -d "$Q/.claude-mind/snapshots/20261030_225139_pre-mind-all" ] && echo ja || echo nein)" "nein"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
