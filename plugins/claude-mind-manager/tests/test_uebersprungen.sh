#!/usr/bin/env bash
# =============================================================================
#  Der UEBERSPRUNGEN-Zaehler in alle.sh  (NEU v5.73.0)
# =============================================================================
#
# ⛔ WOZU. Bis v5.72.0 meldete `alle.sh` `gefunden / gefahren / gruen / rot`.
#    Ein UEBERSPRUNGENER Fall fiel in KEINE dieser Spalten und sah damit aus
#    wie gruen. Gemessen 10.09.2026: ein neu gebauter Waechter uebersprang
#    sich, weil `CLAUDE_PROJECT_DIR` fehlte — die Zusammenfassung sagte GRUEN
#    und hatte recht. Gefunden wurde es nur durch einen Blick in die
#    DETAILAUSGABE der Sammlung.
#
# ⭐ Das ist derselbe Fehler, den `hooks.md` eine Ebene tiefer beschreibt:
#    ein Hook, der schweigt weil er soll, und einer, der schweigt weil er
#    tot ist, sehen im Log identisch aus.
#
# ⛔ UND DER ZAEHLER SELBST IST ZWEIMAL DANEBENGEGANGEN — beide Fehlgriffe
#    sind hier als Prueffall festgehalten, weil sie sich sonst wiederholen:
#
#    (1) Die erste Fassung zaehlte JEDE Zeile mit dem Wort und meldete beim
#        ERSTEN Lauf einen Uebersprung in `test_schritt_quittung.sh`, der
#        keiner war: die Sammlung PRUEFT das Konzept, ihre Prueffall-Namen
#        lauten "als UEBERSPRUNGEN gezaehlt". Ein ERGEBNIS, kein Uebersprung.
#        ⭐ Neuntes Vorkommen der Klasse `nennung-statt-zuweisung`.
#
#    (2) Der erste Ausschluss dagegen filterte `[--]` und `[--- ]` weg — und
#        das SIND die Skip-Markierungen zweier Sammlungen. Ein Zaehler, der
#        die echten Uebersprunge wegfiltert und den Fehlalarm behaelt, waere
#        schlimmer als gar keiner.
#
# ⭐ DAS MERKMAL IST DIE ZEILENFORM, NICHT DAS WORT: ein Ergebnis beginnt mit
#    `[ok ]`, `[FEHL]`, `[ROT]`, `OK` oder `FEHL`. Ein Uebersprung tut das
#    nie — er hat kein Ergebnis, das ist sein ganzer Punkt.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LAEUFER="$WURZEL/tests/alle.sh"

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-58s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-58s ist=%-12s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}

[ -f "$LAEUFER" ] || { echo "ABBRUCH: $LAEUFER fehlt"; exit 2; }

D=$(mktemp -d "${TMPDIR:-/tmp}/uebXXXXXX") || exit 2

# ⛔ Die drei ECHTEN Formen aus dem Bestand, woertlich — plus die zwei
#   Ergebniszeilen, die NICHT mitzaehlen duerfen.
cat > "$D/probe.log" <<'LOG'
    UEBERSPRUNGEN — v5.70.0 nicht installiert, Gegenprobe nicht fahrbar.
  [--- ] UEBERSPRUNGEN: keine installierte Kopie unter tools/ vorhanden.
  [--] jq fehlt — JSON-Fall UEBERSPRUNGEN, nichts gemessen
  [ok ] als UEBERSPRUNGEN gezaehlt
  [ok ] der GRUND steht dabei
  [FEHL] UEBERSPRUNGEN falsch behandelt
LOG

zaehle() {
  grep 'UEBERSPRUNGEN' "$1" 2>/dev/null \
    | grep -cvE '^[[:space:]]*(\[(ok|FEHL|ROT)[^]]*\]|OK|FEHL)[[:space:]]'
}

echo "=============================================================================="
echo "  1) Der Zaehler trifft die drei ECHTEN Formen und nur die"
echo "=============================================================================="
janein "drei echte Uebersprunge gezaehlt" "3" "$(zaehle "$D/probe.log")"

echo
echo "=============================================================================="
echo "  2) ⛔ Die zwei Fehlgriffe, die er schon gemacht hat"
echo "=============================================================================="
printf '  [ok ] als UEBERSPRUNGEN gezaehlt\n' > "$D/nur_ergebnis.log"
janein "⛔ eine ERGEBNIS-Zeile mit dem Wort zaehlt NICHT" "0" \
       "$(zaehle "$D/nur_ergebnis.log")"
printf '  [--- ] UEBERSPRUNGEN: kein Netz\n' > "$D/nur_skip.log"
janein "⛔ die Skip-Markierung [--- ] zaehlt SEHR WOHL" "1" \
       "$(zaehle "$D/nur_skip.log")"
printf '  [--] jq fehlt — JSON-Fall UEBERSPRUNGEN\n' > "$D/nur_skip2.log"
janein "⛔ und die Form [--] ebenso" "1" "$(zaehle "$D/nur_skip2.log")"
printf 'nichts besonderes hier\n' > "$D/leer.log"
janein "eine Datei ohne das Wort ergibt 0" "0" "$(zaehle "$D/leer.log")"

echo
echo "=============================================================================="
echo "  3) alle.sh fuehrt die Spalte wirklich"
echo "=============================================================================="
janein "die Zusammenfassung nennt 'uebersprungen'" "ja" \
       "$(grep -q 'uebersprungen %d' "$LAEUFER" && echo ja || echo nein)"
janein "⭐ und BENENNT die Sammlungen, statt nur zu zaehlen" "ja" \
       "$(grep -q 'UEBERSPRUNGENE FAELLE' "$LAEUFER" && echo ja || echo nein)"
janein "⛔ es bricht NICHT ab — ein Uebersprung ist kein Fehler" "0" \
       "$(grep -c 'UEBERSPRUNGEN.*exit [12]' "$LAEUFER")"
janein "⚠ der Text sagt, dass er kein bestandener ist" "ja" \
       "$(grep -q 'KEIN bestandener' "$LAEUFER" && echo ja || echo nein)"

rm -rf "$D"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
