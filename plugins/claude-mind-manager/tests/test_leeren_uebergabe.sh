#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Uebergabe nach dem LEEREN (v5.156.0, Etappe 60).
#
# ⛔ GEMESSEN 29.10.2026 (Antons Transkripte 99786305 -> 750b6366): Leeren per Desktop liefert SessionStart mit
#    source=startup, nicht clear, und kein PreCompact. Die neue Sitzung sah den RESUME einer frueheren
#    Kompaktierung; die letzten drei Nutzernachrichten fehlten, die Rekonstruktion kostete ~152 000 Agent-Tokens.
# ⭐ Verknuepft wird ueber die HOST-Kennung (bleibt beim Leeren gleich), nie ueber „das neueste Transkript im
#    Ordner" — dort arbeiten drei Rollen, das neueste waere oft das einer Kollegin.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude-mind"
ALT="$TMP/alt-sitzung.jsonl"
{ printf '{"type":"user","timestamp":"2026-10-29T16:55:00Z","message":{"role":"user","content":"Erster Auftrag: baue den Schalter"}}\n'
  printf '{"type":"assistant","timestamp":"2026-10-29T16:56:00Z","message":{"id":"m1","role":"assistant","content":[{"type":"text","text":"Gebaut."}]}}\n'
  printf '{"type":"user","timestamp":"2026-10-29T17:00:00Z","message":{"role":"user","content":"Letzter Auftrag: pruefe die Kennung ZWOELF"}}\n'
} > "$ALT"
merke() { ( CLAUDE_CODE_HOST_SESSION_ID="$1" bash -c '. "$0/hooks/lib.sh"; mind_sitzung_merken "$1" alt-sid-1 "$2"' "$R" "$P" "$ALT" ); }
start() {  # $1 = Host-Kennung der NEUEN Sitzung (leer = nicht gesetzt)
  printf '{"session_id":"neu-sid-2","source":"startup","cwd":"%s"}' "$P" \
    | ( cd "$P" && env -u CLAUDE_CODE_HOST_SESSION_ID ${1:+CLAUDE_CODE_HOST_SESSION_ID=$1} \
        CLAUDE_PROJECT_DIR="$P" CLAUDE_PLUGIN_ROOT="$R" MIND_LOG_FILE="$TMP/log" bash "$R/hooks/session-start.sh" ) 2>/dev/null
}

echo "=== 1) gleiche Host-Kennung, neue sid: die letzten Auftraege der vorigen Sitzung ==="
merke "local_host-A"
pruef "Merker je Host-Kennung angelegt" "$([ -f "$P/.claude-mind/sitzung/local_host-A.letzte" ] && echo ja || echo nein)" "ja"
A=$(start "local_host-A")
pruef "⛔ die Uebergabe nennt den LETZTEN Auftrag" "$(printf '%s' "$A" | grep -c 'ZWOELF')" "1"
pruef "   ... und sagt, woher sie kommt"          "$(printf '%s' "$A" | grep -c 'VORIGEN Sitzung')" "1"
pruef "RESUME liegt in rescued/"                  "$(ls "$P/.claude-mind/rescued/"*-leeren-*_RESUME.md 2>/dev/null | wc -l | tr -d ' ')" "1"

echo "=== 2) ⛔ fremde Host-Kennung (Kollegin im selben Ordner): KEINE Uebergabe ==="
B=$(start "local_host-B")
pruef "kein fremder Auftrag" "$(printf '%s' "$B" | grep -c 'ZWOELF')" "0"

echo "=== 3) ohne Host-Kennung: Verhalten wie bisher ==="
C=$(start "")
pruef "keine Uebergabe" "$(printf '%s' "$C" | grep -c 'VORIGEN Sitzung')" "0"
( env -u CLAUDE_CODE_HOST_SESSION_ID bash -c '. "$0/hooks/lib.sh"; mind_sitzung_merken "$1" x y' "$R" "$TMP/ohne" )
pruef "ohne Host-Kennung wird nichts geschrieben" "$([ -d "$TMP/ohne/.claude-mind/sitzung" ] && echo ja || echo nein)" "nein"

echo "=== 4) dieselbe sid (Kompaktierung, kein Leeren): KEINE Uebergabe aus dem eigenen Transkript ==="
( CLAUDE_CODE_HOST_SESSION_ID=local_host-A bash -c '. "$0/hooks/lib.sh"; mind_sitzung_merken "$1" neu-sid-2 "$2"' "$R" "$P" "$ALT" )
D=$(start "local_host-A")
pruef "keine Uebergabe bei gleicher sid" "$(printf '%s' "$D" | grep -c 'VORIGEN Sitzung')" "0"

echo "=== 5) stop.sh merkt die Sitzung ==="
rm -rf "$P/.claude-mind/sitzung"
printf '{"session_id":"s-9","transcript_path":"%s","cwd":"%s"}' "$ALT" "$P" \
  | ( cd "$P" && CLAUDE_CODE_HOST_SESSION_ID=local_host-C CLAUDE_PROJECT_DIR="$P" CLAUDE_PLUGIN_ROOT="$R" bash "$R/hooks/stop.sh" ) >/dev/null 2>&1
pruef "Merker mit sid aus dem Stop-Input" "$(grep -c '^sid=s-9$' "$P/.claude-mind/sitzung/local_host-C.letzte" 2>/dev/null)" "1"

echo "=== 6) Rollen-Gate: nach dem Leeren traegt die HOST-Kennung die Rolle (Spalte, die der manager pflegt) ==="
mkdir -p "$TMP/r/.claude/rules"
printf '| Rolle | Name | sessionId | Host |\n|---|---|---|---|\n| **manager** | A | `aaaa1111-0000-0000-0000-000000000000` | `local_aaaa` |\n| **sync** | R | `cccc3333-0000-0000-0000-000000000000` | `local_cccc` |\n' \
  > "$TMP/r/.claude/rules/rollen.md"
rolle() { ( env -u CLAUDE_CODE_HOST_SESSION_ID ${2:+CLAUDE_CODE_HOST_SESSION_ID=$2} bash -c '. "$0/hooks/lib.sh"; mind_rolle "$1" "$2"' "$R" "$1" "$TMP/r" ); }
pruef "alte sid: Rolle aus Spalte 3 (wie bisher)"       "$(rolle aaaa1111-0000-0000-0000-000000000000)" "manager"
pruef "⛔ neue sid + gleiche Host-Kennung: Rolle bleibt" "$(rolle 99999999-0000-0000-0000-000000000000 local_aaaa)" "manager"
pruef "neue sid ohne Host-Kennung: unbekannt (laut)"     "$(rolle 99999999-0000-0000-0000-000000000000)" "unbekannt"
pruef "fremde Host-Kennung: unbekannt"                   "$(rolle 99999999-0000-0000-0000-000000000000 local_zzzz)" "unbekannt"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
