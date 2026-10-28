#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Eine frisch verdichtete, seither unveraenderte Datei ist keine Kandidatin (v5.149.0, Etappe 57 §1).
#
# ⛔ GEMESSEN (CK3): ein Verdichten-Agent kostete 99 000 Tokens fuer 16 B — auf einer Datei, die
#    gerade erst verdichtet worden war. Die Rotation kannte nur, WELCHE Datei gewaehlt wurde, nicht
#    ob sie danach verdichtet wurde.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude-mind" "$P/.claude/rules"
G="$P/.claude/rules/gross.md"; K="$P/.claude/rules/klein.md"
printf 'zeile\n%.0s' $(seq 1 50) > "$G"; printf 'kurz\n' > "$K"
L() { ( source "$R/hooks/lib.sh"; export MIND_LOG_FILE="$TMP/log"; "$@" ); }
wahl() { printf '%s\n' "$G" "$K" | L mind_verdicht_kandidat "$P" mind-rules probe 2>"$TMP/err"; }

pruef "Vorbedingung: ohne Historie ist die groesste die Kandidatin" "$(wahl)" "$G"

echo "=== 1) Anwenden schreibt den Nachher-Fingerabdruck ==="
DEP="$P/.claude-mind/verdichten-mind-rules.txt"; ERG="$TMP/erg.md"
printf 'zeile\n%.0s' $(seq 1 40) > "$ERG"
printf 'gross.md       Vorher-Fassung  md5 %s  %s\n' "$(L _md5 "$G")" "$G" > "$DEP"
L mind_verdichtung_anwenden "$G" "$ERG" "$DEP" >/dev/null 2>&1
pruef "angewendet (Inhalt = Ergebnis)" "$(cmp -s "$G" "$ERG" && echo ja || echo nein)" "ja"
pruef "Historie traegt eine nach-Zeile mit dem neuen md5" \
  "$(grep -c "^nach ts=.* datei=$G md5=$(L _md5 "$G")$" "$P/.claude-mind/verdichten-historie")" "1"

echo "=== 2) ⛔ unveraendert seit der Verdichtung -> nicht mehr Kandidatin ==="
pruef "die kleinere ist jetzt dran"        "$(wahl)" "$K"
pruef "   ... und das wird GESAGT"          "$(grep -c 'seit ihrer letzten Verdichtung unveraendert' "$TMP/err")" "1"

echo "=== 3) geaendert -> wieder Kandidatin ==="
printf 'neu dazu\n' >> "$G"
pruef "die groessere ist wieder dabei"     "$(wahl)" "$G"

echo "=== 4) alles ruht -> keine Kandidatin (rc 1, wie eine leere Liste) ==="
printf 'zeile\n%.0s' $(seq 1 40) > "$G"
printf 'nach ts=x datei=%s md5=%s\n' "$K" "$(L _md5 "$K")" >> "$P/.claude-mind/verdichten-historie"
printf '%s\n' "$G" "$K" | L mind_verdicht_kandidat "$P" mind-rules probe >/dev/null 2>&1
pruef "rc 1" "$?" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
