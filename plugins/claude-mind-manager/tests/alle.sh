#!/usr/bin/env bash
# =============================================================================
#  tests/alle.sh — faehrt ALLE Pruefsammlungen  (NEU v5.13.0)
# =============================================================================
#
# ⛔ WARUM ES DAS GIBT
#
# Bis v5.12.0 lagen 11 Pruefsammlungen in tests/ und es gab KEINEN Sammel-Laeufer.
# Wer pruefen wollte, rief einzelne Dateien NAMENTLICH auf — und meldete danach
# "alle Prueffaelle gruen". Am 23.08.2026 stellte sich heraus, dass
# `test_precompact.py` in keinem dieser Laeufe je dabei war.
#
# Das verletzt `fertig-heisst-fertig.md` §1 woertlich:
#   "Zahl ausgefuehrter Prueffaelle == Zahl vorhandener Prueffaelle."
#
# Und es ist die Ursache dahinter, dass zwei kaputte Messinstrumente (F2/F3 der
# v5.13.0-Runde) lange ueberlebt haben: sie hatten Prueffaelle, die niemand rief.
#
# ⚠ EINE KORREKTUR, DIE HIERHER GEHOERT: Die erste Fassung dieses Kommentars
#   behauptete, `test_precompact.py` sei ROT. Beim ersten Lauf war sie das, beim
#   zweiten gruen — ohne Codeaenderung. Grund: sie waehlt `kandidaten[1]`, das
#   zweitkleinste Transkript im Projektordner, und das ist je nach Sitzungsbestand
#   ein anderes. Ein Prueffall, dessen Urteil davon abhaengt, welche Datei er
#   zufaellig greift, kann einen Defekt ANZEIGEN, aber nie AUSSCHLIESSEN.
#   Deshalb liegt seit v5.13.0 `test_sampler_filter.py` daneben: feste Eingaben,
#   festes Urteil.
#
# ⛔ DIE BAUART, DAMIT ER NICHT DASSELBE PROBLEM BEKOMMT
#
#   1. Er FINDET die Sammlungen (find), er LISTET sie nicht auf. Eine Liste veraltet
#      in dem Moment, in dem jemand eine Datei dazulegt — genau der Fehler, den dieses
#      Skript beheben soll. Waere hier eine Liste, waere es sein eigener Vorgaenger.
#   2. Er meldet GEFUNDEN / GEFAHREN / GRUEN. Weichen die ersten beiden voneinander ab,
#      ist das ein ABBRUCH, keine Fussnote.
#   3. Er ueberschreibt CLAUDE_PLUGIN_ROOT NICHT. Drei Sammlungen taten das frueher und
#      liefen dadurch am Quellbaum statt am gebauten Paket — entgegen ihrer eigenen
#      README und entgegen `fertig-heisst-fertig.md` §1.
#
# Aufruf:
#   tests/alle.sh                  alles  (~55 s)
#   tests/alle.sh --liste          nur zeigen, was gefunden wuerde
#
# ⚠ Es gibt BEWUSST keinen Schnellmodus. Der ganze Bestand laeuft in unter einer
#   Minute, und eine Teilmenge zu fahren ist genau die Gewohnheit, aus der dieses
#   Skript entstanden ist.
#
# Rueckgabe: 0 = alles gruen · 1 = mindestens eine Sammlung rot · 2 = Zaehlung uneins
# =============================================================================
set -u

HIER="$(cd "$(dirname "$0")" && pwd)"
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$HIER/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$WURZEL"

NUR_LISTE=0
for a in "$@"; do
  case "$a" in
    --liste)   NUR_LISTE=1 ;;
    -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
    *) echo "unbekannte Option: $a" >&2; exit 2 ;;
  esac
done

# --- 1) FINDEN -------------------------------------------------------------
# Alles, was test_* heisst und .sh oder .py ist. Kein Muster von Hand gepflegt.
GEFUNDEN=()
while IFS= read -r f; do
  [ -n "$f" ] && GEFUNDEN+=("$f")
done < <(find "$HIER" -maxdepth 1 -type f \( -name 'test_*.sh' -o -name 'test_*.py' \) \
         | LC_ALL=C sort)

N=${#GEFUNDEN[@]}
if [ "$N" -eq 0 ]; then
  echo "ABBRUCH: keine Pruefsammlung in $HIER gefunden."
  echo "         Das ist NIE ein gutes Ergebnis — eher ein falscher Pfad."
  exit 2
fi

if [ "$NUR_LISTE" = 1 ]; then
  echo "$N Sammlungen gefunden:"
  for f in "${GEFUNDEN[@]}"; do echo "  $(basename "$f")"; done
  exit 0
fi

echo "======================================================================"
echo "  Pruefsammlungen — $(date '+%d.%m.%Y %H:%M')"
echo "  Wurzel: $WURZEL"
echo "======================================================================"
echo "  $N Sammlungen gefunden"
echo

# --- 2) FAHREN -------------------------------------------------------------
GEFAHREN=0
GRUEN=0
ROT=()
UEBERSPRUNGEN=0     # v5.73.0 — fiel bisher in KEINE Spalte
MIT_SKIP=()
NICHT_GEFAHREN=()
LOGDIR="${TMPDIR:-/tmp}/mind-tests-$$"
mkdir -p "$LOGDIR"

for f in "${GEFUNDEN[@]}"; do
  base="$(basename "$f")"

  case "$base" in
    *.py) CMD=(python "$f") ;;
    *.sh) CMD=(bash "$f") ;;
    *)    # Kann heute nicht eintreten -- find und dieses case nennen dieselben
          # zwei Endungen. Der Zweig steht da, damit ein spaeterer `find`-Umbau
          # die Datei nicht STILL ueberspringt, sondern unten die Zaehlung reisst.
          NICHT_GEFAHREN+=("$base")
          printf '  %-28s NICHT GEFAHREN (unbekannte Endung)\n' "$base"
          continue ;;
  esac

  t0=$(date +%s)
  "${CMD[@]}" >"$LOGDIR/$base.log" 2>&1
  rc=$?
  t1=$(date +%s)
  GEFAHREN=$((GEFAHREN + 1))

  # ⛔ v5.73.0: UEBERSPRUNGENE FAELLE ZAEHLEN — sie fielen bisher in KEINE Spalte.
  #    Gemessen 10.09.2026: ein neu gebauter Waechter uebersprang sich, weil
  #    `CLAUDE_PROJECT_DIR` fehlte. Die Sammlung meldete GRUEN und hatte recht —
  #    ein uebersprungener Fall ist kein roter. Gefunden wurde es nur durch einen
  #    Blick in die DETAILAUSGABE.
  # ⭐ Das ist derselbe Fehler, den `hooks.md` eine Ebene tiefer beschreibt:
  #    ein Hook, der schweigt weil er soll, und einer, der schweigt weil er tot
  #    ist, sehen im Log identisch aus.
  # ⛔ GEZAEHLT WIRD DIE AUSGABE, NICHT DER QUELLTEXT — sonst zaehlten Kommentare
  #    mit. Klasse `nennung-statt-zuweisung`.
  #
  # ⛔ UND DAS REICHTE NICHT. Die erste Fassung zaehlte jede Zeile mit dem Wort
  #    und meldete beim ERSTEN Lauf einen Uebersprung in `test_schritt_quittung.sh`,
  #    der keiner war: die Sammlung PRUEFT das Konzept, und ihre Prueffall-Namen
  #    lauten "als UEBERSPRUNGEN gezaehlt". Ein Ergebnis, kein Uebersprung.
  #    ⭐ NEUNTES Vorkommen derselben Klasse — im selben Handgriff, in dem der
  #      Kommentar darueber davor warnt. Gefunden hat es der neue Zaehler beim
  #      ersten Lauf; das ist zugleich sein bester Beleg.
  #
  # ⭐ DAS MERKMAL IST DIE ZEILENFORM, NICHT DAS WORT: ein ERGEBNIS beginnt mit
  #    `[ok ]`, `[FEHL]`, `[ROT]`, `OK` oder `FEHL`. Ein Uebersprung tut das nie —
  #    er hat kein Ergebnis, das ist sein ganzer Punkt.
  # ⛔ `[--]` und `[--- ]` sind AUSDRUECKLICH NICHT ausgeschlossen — das SIND die
  #    Skip-Markierungen zweier Sammlungen. Die erste Fassung dieses Ausschlusses
  #    haette sie mitgetoetet und damit genau die Faelle verschwiegen, um die es
  #    geht: ein Zaehler, der die echten Uebersprunge wegfiltert und den
  #    Fehlalarm behaelt, waere schlimmer als gar keiner.
  u=$(grep 'UEBERSPRUNGEN' "$LOGDIR/$base.log" 2>/dev/null \
      | grep -cvE '^[[:space:]]*(\[(ok|FEHL|ROT)[^]]*\]|OK|FEHL)[[:space:]]' \
      || echo 0)
  case "$u" in ''|*[!0-9]*) u=0 ;; esac
  if [ "$u" -gt 0 ]; then
    UEBERSPRUNGEN=$((UEBERSPRUNGEN + u))
    MIT_SKIP+=("$base:$u")
  fi

  if [ "$rc" -eq 0 ]; then
    GRUEN=$((GRUEN + 1))
    if [ "$u" -gt 0 ]; then
      printf '  %-28s GRUEN   (%ss)  ⚠ %s uebersprungen\n' "$base" "$((t1 - t0))" "$u"
    else
      printf '  %-28s GRUEN   (%ss)\n' "$base" "$((t1 - t0))"
    fi
  else
    ROT+=("$base")
    printf '  %-28s ROT     (Rueckgabe %s, %ss)\n' "$base" "$rc" "$((t1 - t0))"
  fi
done

# --- 3) ZAEHLEN ------------------------------------------------------------
# ⛔ Die eigentliche Zusicherung dieses Skripts. Sie greift auf ZAHLEN zu, nicht
#    auf Text — eine Kontrolle gegen einen formatierten Bericht ist am 21.08.2026
#    dreimal am falschen Gegenstand gescheitert.
echo
echo "----------------------------------------------------------------------"
printf '  gefunden %d · gefahren %d · gruen %d · rot %d · uebersprungen %d\n' \
       "$N" "$GEFAHREN" "$GRUEN" "${#ROT[@]}" "$UEBERSPRUNGEN"

# ⭐ v5.73.0: Uebersprungenes wird BENANNT, nicht nur gezaehlt. Eine Zahl allein
#    liesse offen, WO nachzusehen ist — und der Blick in die Detailausgabe war
#    genau der Schritt, ohne den es unentdeckt geblieben waere.
# ⛔ Es bricht NICHT ab. Ein uebersprungener Fall kann eine ehrliche Umgebungs-
#    grenze sein (kein `jq`, keine Vorgaengerversion). Er darf nur nicht mehr
#    wie ein bestandener aussehen.
if [ "$UEBERSPRUNGEN" -gt 0 ]; then
  echo
  echo "  ⚠ UEBERSPRUNGENE FAELLE — ein uebersprungener Fall ist KEIN bestandener:"
  for x in "${MIT_SKIP[@]:-}"; do
    [ -n "$x" ] && echo "     ${x%%:*}  (${x##*:})  -> $LOGDIR/${x%%:*}.log"
  done
fi

# ⚠ EHRLICH DAZUGESAGT: Diese Zusicherung kann heute nicht ausloesen — `find`
#   und das `case` oben nennen dieselben zwei Endungen, also wird jede gefundene
#   Datei auch gefahren. Sie steht trotzdem hier, weil genau diese Annahme beim
#   naechsten Umbau kippt und der Ausfall dann STILL waere. Eine Zusicherung, die
#   heute strukturell haelt, ist billig; sie nicht zu haben, war teuer.
if [ "$GEFAHREN" -ne "$N" ]; then
  echo
  echo "⛔ ABBRUCH: gefahren ($GEFAHREN) != gefunden ($N)."
  for x in "${NICHT_GEFAHREN[@]:-}"; do [ -n "$x" ] && echo "   nicht gefahren: $x"; done
  echo "   Eine Sammlung wurde gefunden, aber nicht ausgefuehrt. Genau diese Luecke"
  echo "   ist der Grund, warum es dieses Skript gibt — sie darf nicht still bleiben."
  exit 2
fi

if [ "${#ROT[@]}" -gt 0 ]; then
  echo
  echo "  ROTE SAMMLUNGEN:"
  for r in "${ROT[@]}"; do
    echo "    - $r      Ausgabe: $LOGDIR/$r.log"
    sed -n '$p' "$LOGDIR/$r.log" | sed 's/^/        /'
  done
  echo
  echo "  ⚠ Ein roter Lauf ist ein BEFUND, kein Anlass, die Sammlung zu aendern."
  echo "    Pruefungen sind unantastbar (messung-vor-glauben.md §2)."
  exit 1
fi

echo
echo "  alles gruen. Ausgaben: $LOGDIR"
exit 0
