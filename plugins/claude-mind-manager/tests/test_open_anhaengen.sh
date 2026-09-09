#!/usr/bin/env bash
# OPEN wird nur noch ANGEHAENGT (v5.56.0) — gleichzeitige Kompaktierungen.
#
# ⛔ DER FALL, FUER DEN ES GEBAUT IST, IST FALL 3. Bis v5.55.0 las
#    `pre-compact.sh` den Merker (Z.175-181) und schrieb ihn spaeter mit `>`
#    komplett neu (Z.228) — ein Read-Modify-Write ohne Sperre. Zwei
#    Kompaktierungen im selben Ordner: die zweite liest den Stand VOR dem
#    Schreiben der ersten und ueberschreibt ihn. Die Rettung der ersten liegt
#    als Datei da und ist als QUELLE unerreichbar. Gemessen am Code, 10.09.2026.
#
# ⭐ FALL 2 IST DIE POSITIVKONTROLLE DAZU: nacheinander muss es weiter gehen.
#    Ein Merker, der gar nichts mehr sammelt, waere gegen Fall 3 immun und
#    trotzdem kaputt.
#
# ⚠ Fall 3 ist ein NEBENLAEUFIGKEITS-Test. Er kann auf einer sehr langsamen
#   Maschine gruen werden, ohne wirklich ueberlappt zu haben — deshalb prueft
#   er ZUSAETZLICH, dass beide Rettungsdateien verschiedene Namen tragen.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
H="$R/hooks"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

neu_projekt() { local d; d=$(mktemp -d); mkdir -p "$d/.claude-mind/rescued"; printf '%s' "$d"; }
transkript() {
  : > "$1"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf '{"type":"user","message":{"content":[{"type":"text","text":"Frage %s"}]}}\n' "$i" >> "$1"
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"Antwort %s. Entscheidung: Weg A."}],"usage":{"input_tokens":2,"cache_read_input_tokens":1000,"cache_creation_input_tokens":3,"output_tokens":9}}}\n' "$i" >> "$1"
  done
}
precompact() { # projekt sid
  printf '{"hook_event_name":"PreCompact","cwd":"%s","session_id":"%s","transcript_path":"%s","trigger":"auto"}' \
    "$1" "$2" "$1/t.jsonl" \
    | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$1" MIND_LOG_FILE="$1/log.txt" \
      bash "$H/pre-compact.sh" >/dev/null 2>&1
}
pfade() { grep -c '^path=' "$1/.claude-mind/rescued/OPEN" 2>/dev/null; }
lebend() {  # wie viele path= zeigen auf eine Datei, die es gibt
  local n=0 p
  while IFS= read -r p; do
    p="${p#path=}"; [ -n "$p" ] && [ -f "$p" ] && n=$((n+1))
  done < <(grep '^path=' "$1/.claude-mind/rescued/OPEN" 2>/dev/null)
  printf '%s' "$n"
}

echo "=== 1) Eine Kompaktierung: der Merker entsteht ==="
P=$(neu_projekt); transkript "$P/t.jsonl"
precompact "$P" "S1"
pruef "OPEN liegt"            "ja" "$([ -f "$P/.claude-mind/rescued/OPEN" ] && echo ja || echo nein)"
pruef "genau eine path=-Zeile" "1" "$(pfade "$P")"
pruef "und sie zeigt auf eine Datei" "1" "$(lebend "$P")"
pruef "⛔ kein compactions= mehr" "0" \
      "$(grep -c '^compactions=' "$P/.claude-mind/rescued/OPEN" 2>/dev/null)"
pruef "⛔ kein blocks= mehr" "0" \
      "$(grep -c '^blocks=' "$P/.claude-mind/rescued/OPEN" 2>/dev/null)"
pruef "⭐ die Sitzung steht im Merker" "1" \
      "$(grep -c '^sid=S1' "$P/.claude-mind/rescued/OPEN" 2>/dev/null)"

echo
echo "=== 2) ⭐ POSITIVKONTROLLE: nacheinander sammelt es weiter (v5.4.1) ==="
precompact "$P" "S1"
precompact "$P" "S1"
pruef "drei path=-Zeilen" "3" "$(pfade "$P")"
pruef "alle drei zeigen auf Dateien" "3" "$(lebend "$P")"
pruef "⭐ jede Rettung hat ihr eigenes events=" "3" \
      "$(grep -c '^events=' "$P/.claude-mind/rescued/OPEN" 2>/dev/null)"
pruef "⭐ und ihr eigenes ts=" "3" \
      "$(grep -c '^ts=' "$P/.claude-mind/rescued/OPEN" 2>/dev/null)"
rm -rf "$P"

echo
echo "=== 3) ⛔ DER FALL: ZWEI Kompaktierungen GLEICHZEITIG ==="
P=$(neu_projekt); transkript "$P/t.jsonl"
precompact "$P" "SA" &
_A=$!
precompact "$P" "SB" &
_B=$!
wait "$_A" "$_B"
pruef "⛔ BEIDE Rettungen stehen im Merker" "2" "$(pfade "$P")"
pruef "⛔ und beide Dateien existieren"     "2" "$(lebend "$P")"
pruef "⭐ zwei VERSCHIEDENE Rettungsdateien" "2" \
      "$(ls -1 "$P/.claude-mind/rescued"/*_chat.md 2>/dev/null | wc -l | tr -d ' ')"
pruef "⭐ beide Sitzungen sind benannt" "2" \
      "$(grep -c '^sid=S' "$P/.claude-mind/rescued/OPEN" 2>/dev/null)"
rm -rf "$P"

echo
echo "=== 4) Der Dateiname traegt Sub-Sekunde UND Kennung ==="
P=$(neu_projekt); transkript "$P/t.jsonl"
precompact "$P" "local_61d97508-9fbd-444f-beb8-612fb89fdf06"
_F=$(basename "$(ls -1 "$P/.claude-mind/rescued"/*_chat.md 2>/dev/null | head -1)" 2>/dev/null)
pruef "Name hat vier Teile (datum-zeit-ms-sid)" "ja" \
      "$(case "$_F" in [0-9]*-[0-9]*-[0-9]*-*_chat.md) echo ja ;; *) echo nein ;; esac)"
# ⚠ Die Kennung wird auf die letzten ACHT Zeichen gekuerzt — der Prueffall
#   erwartete zwoelf und war rot, obwohl der Hook richtig lag. Ein Prueffall,
#   der die falsche Erwartung misst, meldet einen Fehler, den es nicht gibt.
pruef "⭐ die Kennung steht drin" "ja" \
      "$(case "$_F" in *b89fdf06_chat.md) echo ja ;; *) echo nein ;; esac)"
rm -rf "$P"

echo
echo "=== 5) Die Zahl der Kompaktierungen wird GEZAEHLT ==="
P=$(neu_projekt); transkript "$P/t.jsonl"
precompact "$P" "S1"; precompact "$P" "S1"; precompact "$P" "S1"
# ⛔ DIE UEBERGABE MUSS WEG, SONST MISST DIESER FALL SIE STATT DER SCHULD.
#    `pre-compact.sh` legt `UEBERGABE` bei JEDER Kompaktierung an, und
#    `prompt-submit.sh` meldet sie ZUERST und steigt aus. Der Prueffall war
#    deshalb rot, obwohl die Zaehlung stimmte — er hat die falsche Meldung
#    gemessen. ⭐ Das ist zugleich die Bestaetigung von v5.54.0: die Uebergabe
#    hat Vorrang vor jeder Mahnung.
rm -f "$P/.claude-mind/rescued/UEBERGABE"
_M=$(printf '{"session_id":"leser","transcript_path":"","prompt":"hi","cwd":"%s"}' "$P" \
     | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" MIND_SYNC_AT_TOKENS=0 \
       bash "$H/prompt-submit.sh" 2>/dev/null)
pruef "prompt-submit nennt 3 Kompaktierungen" "1" \
      "$(printf '%s' "$_M" | grep -c '3 Kompaktierungen')"
# ⭐ UND DIE BEGLEITANGABEN GEHOEREN ZUR JUENGSTEN RETTUNG. Mit dem Anhaengen
#    gibt es drei `ts=`-Zeilen; `grep -m1` haette die aelteste genommen und den
#    Pfad der einen mit dem Zeitstempel der anderen gemeldet.
_TSJUNG=$(grep '^ts=' "$P/.claude-mind/rescued/OPEN" | cut -d= -f2- | tail -1)
_TSALT=$(grep  '^ts=' "$P/.claude-mind/rescued/OPEN" | cut -d= -f2- | head -1)
pruef "⭐ die Meldung nennt den JUENGSTEN Zeitstempel" "1" \
      "$(printf '%s' "$_M" | grep -c "$_TSJUNG")"
pruef "⛔ und NICHT den aeltesten" "0" \
      "$(printf '%s' "$_M" | grep -c "$_TSALT")"
rm -rf "$P"

echo
echo "=== 6) ⚠ ALTE Merker bleiben lesbar (compactions=, eine path=-Zeile) ==="
P=$(neu_projekt)
: > "$P/.claude-mind/rescued/alt_chat.md"; echo "## [x]" >> "$P/.claude-mind/rescued/alt_chat.md"
printf 'path=%s/.claude-mind/rescued/alt_chat.md\nevents=9\nts=alt\ncompactions=4\nblocks=0\n' \
  "$P" > "$P/.claude-mind/rescued/OPEN"
_M=$(printf '{"session_id":"leser","transcript_path":"","prompt":"hi","cwd":"%s"}' "$P" \
     | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" MIND_SYNC_AT_TOKENS=0 \
       bash "$H/prompt-submit.sh" 2>/dev/null)
pruef "⚠ die alte 4 gewinnt gegen die gezaehlte 1" "1" \
      "$(printf '%s' "$_M" | grep -c '4 Kompaktierungen')"
rm -rf "$P"

echo
echo "=== 7) ⛔ NEGATIVKONTROLLE: lief der Sync, entsteht KEINE Schuld ==="
# ⚠ Ohne diesen Fall waere jede Zusicherung oben auch mit einem Hook gruen,
#   der bei JEDER Kompaktierung eine Schuld anlegt — auch nach einem Sync.
P=$(neu_projekt); transkript "$P/t.jsonl"
printf 'ts=jetzt\numfang=5/5 skills 4/4 agents\n' > "$P/.claude-mind/rescued/sync-stand"
precompact "$P" "S1"
pruef "kein OPEN" "nein" "$([ -f "$P/.claude-mind/rescued/OPEN" ] && echo ja || echo nein)"
pruef "die Rettung entsteht trotzdem" "1" \
      "$(ls -1 "$P/.claude-mind/rescued"/*_chat.md 2>/dev/null | wc -l | tr -d ' ')"
rm -rf "$P"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
