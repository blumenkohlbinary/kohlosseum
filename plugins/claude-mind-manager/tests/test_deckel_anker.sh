#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# Der Deckel-Anker (v5.47.0) — die Schuld, die viele kleine Schritte ueberlebt.
#
# ⛔ DER FALL, FUER DEN ER GEBAUT IST, IST FALL 3. Bis v5.46.0 schrieb
#    `kontext-wache.sh` ihren Bezugswert bei JEDEM Turn fort, auch wenn sie
#    schwieg. Jeder Vergleich lief damit gegen den LETZTEN TURN — 90 Zeilen in
#    vielen Schritten von je unter 20 sind nie gemeldet worden, obwohl jede
#    einzelne Messung stimmte.
#
# ⭐ POSITIV- UND NEGATIVKONTROLLE STEHEN NEBENEINANDER. Ein Anker, der immer
#    meldet, waere so wertlos wie einer, der nie meldet — Fall 2 prueft das
#    Schweigen, Fall 3 das Reden.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
W="$R/hooks/kontext-wache.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

P="$TMP/proj"
mkdir -p "$P/.claude/rules" "$P/.claude-mind"
# Zeilen von rund 200 B, damit wenige Zeilen viele Bytes ergeben.
fuelle() {  # fuelle <datei> <zeilen>
  : > "$1"
  i=0; while [ "$i" -lt "$2" ]; do
    printf 'x%.0s' $(seq 1 200) >> "$1"; printf '\n' >> "$1"
    i=$((i+1))
  done
}
anhaengen() {  # anhaengen <datei> <zeilen>
  i=0; while [ "$i" -lt "$2" ]; do
    printf 'y%.0s' $(seq 1 200) >> "$1"; printf '\n' >> "$1"
    i=$((i+1))
  done
}
MERKER="$P/.claude-mind/KONTEXT-GEWACHSEN"
ANKER="$P/.claude-mind/kontext-deckel"
lauf() { rm -f "$MERKER"; CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P" >/dev/null 2>&1; }
meldet() { [ -f "$MERKER" ] && echo ja || echo nein; }

echo "=== 1) Erster Lauf: Anker setzen, NICHTS behaupten ==="
fuelle "$P/CLAUDE.md" 20
lauf
pruef "Anker ist angelegt" "ja" "$([ -f "$ANKER" ] && echo ja || echo nein)"
pruef "aber es wird nichts gemeldet" "nein" "$(meldet)"
A0=$(grep -m1 -oE '^BYTES=[0-9]+' "$ANKER" | cut -d= -f2)
pruef "Anker traegt eine Byte-Zahl" "ja" \
  "$(case "$A0" in ''|*[!0-9]*) echo nein;; *) echo ja;; esac)"

echo
echo "=== 2) ⛔ NEGATIVKONTROLLE: kleiner Schritt, kleine Schuld -> STILL ==="
anhaengen "$P/CLAUDE.md" 5
lauf
pruef "5 Zeilen (~1000 B) melden nicht" "nein" "$(meldet)"

echo
echo "=== 3) ⭐ POSITIVKONTROLLE: viele kleine Schritte, jeder unter der Schwelle ==="
# je 10 Zeilen (~2000 B) — Delta 10 < SCHWELLE 20, aber die Schuld waechst.
for i in 1 2 3; do
  anhaengen "$P/CLAUDE.md" 10
  lauf
done
pruef "die STEHENDE Schuld wird gemeldet" "ja" "$(meldet)"
S=$(grep -m1 -oE '^schuld_bytes=[0-9]+' "$MERKER" | cut -d= -f2)
pruef "Schuld liegt ueber der Schwelle" "ja" \
  "$([ "${S:-0}" -ge 6000 ] 2>/dev/null && echo ja || echo nein)"
# ⛔ v5.65.0: HIER STANDEN ZWEI FAELLE UEBER `schuld_tokens=`.
#    Die Klammer "(~N Tokens)" neben der Byte-Zahl ist entfallen —
#    Nutzer-Entscheidung 10.09.2026, "die sollen garnicht mehr tokens messen".
#    ⭐ Sie sind UMGEKEHRT worden, nicht geloescht: eine geschaetzte Zahl
#       neben einer gemessenen macht die gemessene unglaubwuerdig, und ohne
#       diesen Fall koennte sie zurueckkommen, ohne dass es auffaellt.
#    ⚠ Der zweite Fall pruefte, dass NICHT mit Faktor 4 gerechnet wird
#       (der Eich-Faktor ist 1,917). Diese Zusicherung steht weiter in
#       `.claude/rules/werkzeuge-zuerst.md` — dort als Umrechnung fuer einen
#       Menschen, nicht als Ablauf-Entscheidung.
pruef "⛔ KEINE geschaetzte Tokenzahl neben der gemessenen Byte-Zahl" "ja" \
  "$(grep -qE '^schuld_tokens=' "$MERKER" && echo nein || echo ja)"
pruef "⭐ die BYTE-Messung steht weiterhin" "ja" \
  "$(grep -qE '^schuld_bytes=[0-9]+' "$MERKER" && echo ja || echo nein)"
pruef "der Anker-Zeitpunkt steht dabei" "ja" \
  "$(grep -q '^anker_ts=' "$MERKER" && echo ja || echo nein)"

echo
echo "=== 4) ⭐ Tilgen: zurueck unter den Anker -> Schuld 0, Anker wandert MIT ==="
fuelle "$P/CLAUDE.md" 10
lauf; lauf
A1=$(grep -m1 -oE '^BYTES=[0-9]+' "$ANKER" | cut -d= -f2)
pruef "Anker ist gesunken" "ja" \
  "$([ "${A1:-0}" -lt "${A0:-0}" ] 2>/dev/null && echo ja || echo nein)"
pruef "und es wird nicht mehr gemeldet" "nein" "$(meldet)"

echo
echo "=== 5) ⛔ KEIN GUTHABEN: nach dem Tilgen wird neu gezaehlt ==="
# Wer erst kuerzt und dann wieder auffuellt, faengt bei 0 an — nicht im Plus.
for i in 1 2 3; do
  anhaengen "$P/CLAUDE.md" 10
  lauf
done
pruef "Wiederauffuellen wird erneut gemeldet" "ja" "$(meldet)"

echo
echo "=== 6) ⛔ Es SPERRT nicht — Rueckgabe bleibt eine Meldung ==="
rm -f "$MERKER"
CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P" >"$TMP/out" 2>&1
pruef "keine Ausgabe auf stdout" "0" "$(wc -c < "$TMP/out" | tr -d ' ')"


# ══════════════════════════════════════════════════════════════════════════════
#  v5.137.0 (Etappe 48) — ein AUSSETZER darf kein Anker werden
# ══════════════════════════════════════════════════════════════════════════════
# ⛔ DER ANLASS IST GEMESSEN (Etappe 47 §3, 26.09.2026): von 9 012 B gemeldeter
#    Deckel-Schuld waren **8 067 B kein Wachstum**, sondern ein falscher Anker — auf das
#    Byte die Groesse von `~/.claude/rules/kontext-anlegen.md`, einer Datei, die es gab und
#    die sich seit dem 23.09. nicht geaendert hatte. Zwei Ursachen zusammen:
#      1. `mind_kontext_bilanz` fing ein unlesbares `wc -c` mit `b=0` ab — die Datei blieb
#         in DATEIEN, ihre Groesse verschwand. **0 sieht hier aus wie eine Tilgung.**
#      2. Die RATSCHE NACH UNTEN uebernahm jeden niedrigeren Wert dauerhaft, also auch den
#         Aussetzer eines einzigen Turns.
# ⭐ DIE KLASSE: eine Messung, die ihren Gegenstand nicht erreicht, meldet 0 — und 0 ist von
#    einem echten Ergebnis nicht zu unterscheiden.
#
# ⚠ NACHGESTELLT, NICHT GEMESSEN, und der Unterschied gehoert dazu: eine wirklich unlesbare
#   Datei ist auf NTFS nicht herstellbar (`chmod 000` geprueft am 27.09.2026 — `wc -c`
#   liefert die Groesse weiter). Die Faelle 5 und 6 schatten deshalb `wc` ab, sodass `-c`
#   ohne Ausgabe zurueckkommt: genau die FORM, in der der Fehler im Code ankommt. Belegt ist
#   damit, dass der Zweig greift — nicht, dass er den echten Vorfall gefangen haette.

_bau48() {  # _bau48 <projektpfad> — kleines Projekt mit eigenem HOME, damit die Zahlen klein bleiben
  mkdir -p "$1/.claude/rules" "$1/.claude-mind" "$1/home/.claude/rules"
  printf '# Projekt\nEine Zeile.\n'         > "$1/CLAUDE.md"
  printf '# Regel A\nZwei\nZeilen.\n'       > "$1/.claude/rules/a.md"
  printf '# Regel B\nDrei\nZeilen\nhier.\n' > "$1/.claude/rules/b.md"
}
# shellcheck disable=SC1090
. "$R/hooks/lib.sh" >/dev/null 2>&1

echo
echo "  Fall 5: unlesbare Groesse -> UNGUELTIG= statt stiller 0"
P5="$TMP/p5"; _bau48 "$P5"
_B5=$(HOME="$P5/home" mind_kontext_bilanz "$P5" 2>/dev/null)
pruef "Vorbedingung: drei Dateien, Bytes > 0" "ja" \
  "$([ "$(printf '%s\n' "$_B5" | grep -m1 -oE 'DATEIEN=[0-9]+' | cut -d= -f2)" = 3 ] \
    && [ "$(printf '%s\n' "$_B5" | grep -m1 -oE 'BYTES=[0-9]+' | cut -d= -f2)" -gt 0 ] \
    && echo ja || echo nein)"
wc() { case "${1:-}" in -c) return 1 ;; esac; command wc "$@"; }
_B5K=$(HOME="$P5/home" mind_kontext_bilanz "$P5" 2>/dev/null)
unset -f wc
pruef "Kopfzeile traegt UNGUELTIG=3" "ja" \
  "$(printf '%s\n' "$_B5K" | grep -q '^ZEILEN=.* UNGUELTIG=3$' && echo ja || echo nein)"
pruef "Ausweis nennt die Dateinamen" "ja" \
  "$(printf '%s\n' "$_B5K" | grep -q 'nicht lesbar, Bilanz UNGUELTIG:.*CLAUDE.md' && echo ja || echo nein)"
pruef "DATEIEN bleibt 3 (die Datei ist nicht weg, nur ihre Groesse unbekannt)" "3" \
  "$(printf '%s\n' "$_B5K" | grep -m1 -oE 'DATEIEN=[0-9]+' | cut -d= -f2)"
pruef "der Ausweis sagt die RICHTUNG des Fehlers" "ja" \
  "$(printf '%s\n' "$_B5K" | grep -q 'zu NIEDRIG, nicht zu hoch' && echo ja || echo nein)"

echo
echo "  Fall 6: ungueltige Bilanz setzt und senkt KEINEN Anker"
P6="$TMP/p6"; _bau48 "$P6"
# ⛔ `export -f`: `bash "$W"` ist ein EIGENER Prozess. Ohne den Export lief dort das
#    echte `wc`, die Bilanz war gueltig, und dieser Fall pruefte NICHTS (erst rot
#    geworden, dann verstanden — 27.09.2026).
wc() { case "${1:-}" in -c) return 1 ;; esac; command wc "$@"; }
export -f wc
_A6=$(HOME="$P6/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P6" 2>&1)
unset -f wc
pruef "erster Lauf: kein Anker angelegt" "nein" \
  "$([ -f "$P6/.claude-mind/kontext-deckel" ] && echo ja || echo nein)"
pruef "und es wird im MERKER gemeldet (nicht auf stdout)" "ja" \
  "$(grep -q '^anker_abgelehnt=kein Anker angefasst' "$P6/.claude-mind/KONTEXT-GEWACHSEN" 2>/dev/null \
    && echo ja || echo nein)"
# ⛔ Der Vertrag aus v5.47.0: dieser Hook meldet ueber den Merker, NIE auf stdout.
pruef "stdout bleibt leer" "0" "$(printf '%s' "$_A6" | command wc -c | tr -d ' ')"
printf 'BYTES=99999\nTS=2026-09-01T00:00:00Z\n' > "$P6/.claude-mind/kontext-deckel"
wc() { case "${1:-}" in -c) return 1 ;; esac; command wc "$@"; }
export -f wc
_A6B=$(HOME="$P6/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P6" 2>&1)
unset -f wc
pruef "bestehender Anker bleibt 99999" "99999" \
  "$(grep -m1 -oE '^BYTES=[0-9]+' "$P6/.claude-mind/kontext-deckel" | cut -d= -f2)"
# ⚠ „kein Anker angefasst", nicht „nicht gesenkt": bei ungueltiger Bilanz greift das
#   aeussere Tor, die Senkungs-Entscheidung wird nie erreicht. Hier stand zuerst die
#   andere Erwartung — meine, nicht das Verhalten.
pruef "Ablehnung im Merker, auch mit bestehendem Anker" "ja" \
  "$(grep -q '^anker_abgelehnt=kein Anker angefasst' "$P6/.claude-mind/KONTEXT-GEWACHSEN" 2>/dev/null \
    && echo ja || echo nein)"
pruef "stdout bleibt leer" "0" "$(printf '%s' "$_A6B" | command wc -c | tr -d ' ')"

echo
echo "  Fall 7: DATEIEN kleiner — erstes Mal abgelehnt, zweites Mal uebernommen"
# ⭐ Entschieden wird durch WIEDERHOLUNG, nicht durch eine geratene Schwelle: eine im
#   Messmoment fehlende Datei sieht genauso aus wie eine geloeschte — nur kommt sie wieder.
P7="$TMP/p7"; _bau48 "$P7"
HOME="$P7/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P7" >/dev/null 2>&1
_ANK7=$(grep -m1 -oE '^BYTES=[0-9]+' "$P7/.claude-mind/kontext-deckel" 2>/dev/null | cut -d= -f2)
pruef "Vorbedingung: Anker gesetzt, Vorstand traegt DATEIEN=3" "ja" \
  "$([ -n "${_ANK7:-}" ] && grep -q '^DATEIEN=3' "$P7/.claude-mind/kontext-wache" && echo ja || echo nein)"
mv "$P7/.claude/rules/b.md" "$TMP/b7.weg"
_S7=$(HOME="$P7/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P7" 2>&1)
pruef "erstes Mal: Anker unveraendert" "$_ANK7" \
  "$(grep -m1 -oE '^BYTES=[0-9]+' "$P7/.claude-mind/kontext-deckel" | cut -d= -f2)"
pruef "abgelehnt UND im Merker gemeldet, mit den Zahlen" "ja" \
  "$(grep -q 'DATEIEN 3 -> 2 beim ersten Mal' "$P7/.claude-mind/KONTEXT-GEWACHSEN" 2>/dev/null \
    && echo ja || echo nein)"
pruef "Verdacht im Vorstand vermerkt" "ja" \
  "$(grep -q '^verdacht=2' "$P7/.claude-mind/kontext-wache" && echo ja || echo nein)"
HOME="$P7/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P7" >/dev/null 2>&1
_ANK7B=$(grep -m1 -oE '^BYTES=[0-9]+' "$P7/.claude-mind/kontext-deckel" | cut -d= -f2)
pruef "zweites Mal derselbe Stand: Anker gesenkt" "ja" \
  "$([ "${_ANK7B:-0}" -lt "${_ANK7:-0}" ] 2>/dev/null && echo ja || echo nein)"

echo
echo "  Fall 8: echte Verdichtung wird weiter uebernommen"
# ⛔ Die Negativhaelfte zu 5-7: waere „lehn immer ab" gruen, waeren die drei Faelle wertlos.
P8="$TMP/p8"; _bau48 "$P8"
HOME="$P8/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P8" >/dev/null 2>&1
_V0=$(grep -m1 -oE '^BYTES=[0-9]+' "$P8/.claude-mind/kontext-deckel" | cut -d= -f2)
printf '# Regel B\nkurz.\n' > "$P8/.claude/rules/b.md"
_V2=$(HOME="$P8/home" CLAUDE_PLUGIN_ROOT="$R" bash "$W" "$P8" 2>&1)
_V1=$(grep -m1 -oE '^BYTES=[0-9]+' "$P8/.claude-mind/kontext-deckel" | cut -d= -f2)
pruef "Anker gesenkt (Ratsche wirkt, wo sie soll)" "ja" \
  "$([ "${_V1:-0}" -lt "${_V0:-0}" ] 2>/dev/null && echo ja || echo nein)"
pruef "keine Ablehnungsmeldung bei gueltiger Verdichtung" "nein" \
  "$(grep -q '^anker_abgelehnt=' "$P8/.claude-mind/KONTEXT-GEWACHSEN" 2>/dev/null \
    && echo ja || echo nein)"

echo
echo "  Fall 9: ohne Aussetzer ist die Kopfzeile byteweise wie bisher"
P9="$TMP/p9"; _bau48 "$P9"
_K9=$(HOME="$P9/home" mind_kontext_bilanz "$P9" 2>/dev/null | head -1)
pruef "keine UNGUELTIG-Marke" "nein" \
  "$(printf '%s' "$_K9" | grep -q 'UNGUELTIG' && echo ja || echo nein)"
pruef "Form unveraendert" "ja" \
  "$(printf '%s' "$_K9" | grep -qE '^ZEILEN=[0-9]+ ANWEISUNGEN=[0-9]+ DATEIEN=[0-9]+ BYTES=[0-9]+$' \
    && echo ja || echo nein)"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
