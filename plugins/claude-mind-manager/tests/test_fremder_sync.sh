#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Der fremde Sync loescht keine Schuld mehr (v5.143.0, Etappe 53 §1).
#
# ⛔ DIE LAGE VOM 01.10.2026 IN PALVEDO, nachgebaut:
#    Noras voller Sync (Sitzung NORA) schrieb `sync-stand` und `letzter-sync`. Kalles
#    Sitzung (KALLE) war untaetig — sie wartete auf Noras Ergebnis — und kompaktierte
#    12 Minuten spaeter. Ihr Hook fand NORAS Merker, sah keine Beitraege NACH Noras Sync
#    und legte KEINE Schuld an. 5 090 Beitraege, nie eingespeist: Noras Sync hatte Kalles
#    laufenden Verlauf nie gelesen.
#
# ⭐ Fall 1 ist der Befund. Fall 2–4 sind die GEGENKONTROLLEN, und sie sind genauso wichtig:
#    das Verhalten darf sich NUR bei einem positiven Nichttreffer aendern. Eine eigene
#    Kompaktierung, ein Merker aus einer alten Fassung ohne `sid=`, eine unbekannte Kennung —
#    alle drei bleiben, wie sie bis v5.142.0 waren.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
H="$R/hooks"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# --- 0 · VAKUUM-WAECHTER ----------------------------------------------------
pruef "pre-compact.sh liegt im Paket" "$([ -f "$H/pre-compact.sh" ] && echo ja || echo nein)" "ja"
[ -f "$H/pre-compact.sh" ] || { echo "  Gegenstand fehlt"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

lage() {   # $1 = Name, $2 = sid-Zeile im sync-stand (leer = keine Zeile)
  local d="$TMP/$1 mit leer"
  mkdir -p "$d/.claude-mind/rescued"
  # Kalles Verlauf: alle Beitraege VOR Noras Sync-Ende (18:30Z < 19:00Z)
  : > "$d/t.jsonl"
  local i
  for i in 1 2 3 4 5; do
    printf '{"type":"user","timestamp":"2026-10-01T18:2%s:00Z","message":{"content":"Frage %s, bitte pruefen"}}\n' "$i" "$i" >> "$d/t.jsonl"
    printf '{"type":"assistant","timestamp":"2026-10-01T18:2%s:30Z","message":{"content":[{"type":"text","text":"Antwort %s. Entscheidung: Weg A."}]}}\n' "$i" "$i" >> "$d/t.jsonl"
  done
  # Noras voller Sync — VOR der Kompaktierung, NACH Kalles letztem Beitrag
  { printf 'ts=2026-10-01 20:46:00\numfang=5/5 skills 4/4 agents\nungepruef=\n'
    [ -n "$2" ] && printf '%s\n' "$2"; } > "$d/.claude-mind/rescued/sync-stand"
  printf 'ts=20261001-204600\nutc=2026-10-01T19:00:00Z\n' > "$d/.claude-mind/rescued/letzter-sync"
  printf '%s' "$d"
}
kompaktiert() {  # $1 = Projekt, $2 = Sitzung, die kompaktiert
  printf '{"hook_event_name":"PreCompact","cwd":"%s","session_id":"%s","transcript_path":"%s","trigger":"auto"}' \
    "$1" "$2" "$1/t.jsonl" \
    | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$1" MIND_LOG_FILE="$1/log.txt" \
      bash "$H/pre-compact.sh" >/dev/null 2>&1
}
eintraege() { grep -c '^path=' "$1/.claude-mind/rescued/OPEN" 2>/dev/null || echo 0; }
hat()       { grep -qx "$2" "$1/.claude-mind/rescued/OPEN" 2>/dev/null && echo ja || echo nein; }
merker()    { [ -f "$1/.claude-mind/rescued/sync-stand" ] && echo liegt || echo weg; }
rettungen() { ls "$1"/.claude-mind/rescued/*_chat.md 2>/dev/null | wc -l | tr -d ' '; }

echo "=== 1) ⛔ die Lage vom 01.10.: NORA synct, KALLE kompaktiert ==="
P=$(lage f1 "sid=NORA-aaaa-bbbb")
kompaktiert "$P" "KALLE-cccc-dddd"
pruef "eine Rettung entstand (Vorbedingung, sonst misst der Fall nichts)" "$(rettungen "$P")" "1"
pruef "⛔ und sie steht in OPEN"                 "$(eintraege "$P")" "1"
pruef "   ... mit dem Grund"                     "$(hat "$P" 'grund=fremder-sync')" "ja"
pruef "   ... und wessen Sync es war"            "$(hat "$P" 'sync_sid=NORA-aaaa-bbbb')" "ja"
pruef "⛔ Noras Merker wurde NICHT verbraucht"    "$(merker "$P")" "liegt"

echo "=== 2) GEGENKONTROLLE: NORA kompaktiert selbst — wie bis v5.142.0 ==="
P=$(lage f2 "sid=NORA-aaaa-bbbb")
kompaktiert "$P" "NORA-aaaa-bbbb"
pruef "eine Rettung entstand"                    "$(rettungen "$P")" "1"
pruef "KEINE Schuld (der eigene Sync deckt sie)" "$(eintraege "$P")" "0"
pruef "der Merker wurde verbraucht"              "$(merker "$P")" "weg"

echo "=== 3) GEGENKONTROLLE: Merker aus einer alten Fassung, ohne sid= ==="
P=$(lage f3 "")
kompaktiert "$P" "KALLE-cccc-dddd"
pruef "KEINE Schuld (Verhalten wie bis v5.142.0)" "$(eintraege "$P")" "0"
pruef "der Merker wurde verbraucht"               "$(merker "$P")" "weg"

echo "=== 4) GEGENKONTROLLE: sid=unbekannt ==="
P=$(lage f4 "sid=unbekannt")
kompaktiert "$P" "KALLE-cccc-dddd"
pruef "KEINE Schuld (unbekannt ist kein Nichttreffer)" "$(eintraege "$P")" "0"

echo "=== 5) GEGENKONTROLLE: Kompaktierung ohne eigene Kennung ==="
P=$(lage f5 "sid=NORA-aaaa-bbbb")
kompaktiert "$P" ""
pruef "KEINE Schuld (eigene Kennung leer -> wie bisher)" "$(eintraege "$P")" "0"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
