#!/usr/bin/env bash
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
pruef "Tokens stehen daneben" "ja" \
  "$(grep -qE '^schuld_tokens=[0-9]+' "$MERKER" && echo ja || echo nein)"
pruef "⛔ und NICHT mit Faktor 4 gerechnet" "ja" \
  "$(T=$(grep -m1 -oE '^schuld_tokens=[0-9]+' "$MERKER" | cut -d= -f2);
     [ "${T:-0}" -gt $(( S / 3 )) ] 2>/dev/null && echo ja || echo nein)"
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

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
