#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# `mind_verdicht_kandidat` (v5.138.0, Etappe 49 §2) — die Rotation der
# Verdichtungs-Kandidatin. Veras Fund (Zustellplan, 26.09.2026): `ls -S | head -1`
# plus „eine je Lauf" heisst, dass nur die groesste Datei je verdichtet wird —
# `lessons.md` dreimal in Folge, zwei 27-KB-Dateien nie.
#
# ⛔ FALL 1 IST ANTONS PRUEFFALL WOERTLICH: drei Laeufe hintereinander waehlen drei
#    verschiedene Dateien. Gegen den Stand VOR dieser Version waehlt derselbe
#    Fixture-Bestand dreimal dieselbe — nachgemessen in
#    `Learnings/verdicht_rotation_gegenprobe.sh`, 1 statt 3 verschiedene.
#
# ⭐ FALL 2 IST DIE NEGATIVKONTROLLE ZU FALL 1. Eine Rotation, die IMMER wechselt,
#    waere so falsch wie eine, die nie wechselt: `probe` darf nichts merken, sonst
#    verschiebt schon das Nachsehen den Bestand.
# ⛔ FALL 4 IST DER, AN DEM DIE REGEL VERHUNGERN WUERDE (Bestand <= N). Er steht hier,
#    weil drei der zwoelf gemessenen Memory-Bestaende genau drei Dateien haben.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$R/hooks/lib.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# Bestand bauen: absteigende Groessen, Namen a > b > c > d in Bytes.
bau() {  # bau <verzeichnis> <anzahl>
  local d="$1" k="$2" i=1 gr
  mkdir -p "$d"
  while [ "$i" -le "$k" ]; do
    gr=$(( (k - i + 1) * 100 ))
    printf 'x%.0s' $(seq 1 "$gr") > "$d/datei$i.md"
    i=$((i+1))
  done
}
# Der Aufrufer sortiert (wie in den Skills): groesste zuerst.
liste() { ls -S "$1"/*.md 2>/dev/null; }
waehle() {  # waehle <projekt> <memverz> <skill> <merken|probe>
  liste "$2" | mind_verdicht_kandidat "$1" "$3" "$4" 2>/dev/null
}

echo "  Fall 1: ⛔ ANTONS PRUEFFALL — drei Laeufe, drei verschiedene Dateien"
P1="$TMP/projekt eins"; M1="$P1/memory"; bau "$M1" 4
A=$(basename "$(waehle "$P1" "$M1" mind-memory merken)")
B=$(basename "$(waehle "$P1" "$M1" mind-memory merken)")
C=$(basename "$(waehle "$P1" "$M1" mind-memory merken)")
pruef "drei Laeufe -> drei verschiedene" "3" \
  "$(printf '%s\n%s\n%s\n' "$A" "$B" "$C" | sort -u | grep -c .)"
pruef "Lauf 1 nimmt die GROESSTE — die Regel bleibt: die groesste, die frei ist" \
  "datei1.md" "$A"

echo "  Fall 2: ⭐ NEGATIVKONTROLLE — Modus probe merkt NICHTS (sonst waere Fall 1 wertlos)"
P2="$TMP/projekt zwei"; M2="$P2/memory"; bau "$M2" 4
D=$(basename "$(waehle "$P2" "$M2" mind-memory probe)")
E=$(basename "$(waehle "$P2" "$M2" mind-memory probe)")
pruef "zweimal probe -> dieselbe Datei" "ja" "$([ "$D" = "$E" ] && echo ja || echo nein)"
pruef "keine Historie angelegt" "nein" \
  "$([ -f "$P2/.claude-mind/verdichten-historie" ] && echo ja || echo nein)"

echo "  Fall 3: ⭐ der Bestand rotiert GANZ — 4 Dateien, 4 Laeufe, 4 verschiedene"
P3="$TMP/projekt drei"; M3="$P3/memory"; bau "$M3" 4
_V=""
for _i in 1 2 3 4; do _V="$_V$(basename "$(waehle "$P3" "$M3" mind-memory merken)")
"; done
pruef "vier Laeufe -> vier verschiedene" "4" "$(printf '%s' "$_V" | sort -u | grep -c .)"
pruef "Lauf 5 beginnt wieder bei der groessten" "datei1.md" \
  "$(basename "$(waehle "$P3" "$M3" mind-memory merken)")"

echo "  Fall 4: ⛔ Historie VOLL (Bestand <= N) — Kandidatin trotzdem, Meldung auf stderr"
P4="$TMP/projekt vier"; M4="$P4/memory"; bau "$M4" 3
MIND_VERDICHTEN_HISTORIE=3
export MIND_VERDICHTEN_HISTORIE
for _i in 1 2 3; do waehle "$P4" "$M4" mind-memory merken >/dev/null; done
_K4=$(liste "$M4" | mind_verdicht_kandidat "$P4" mind-memory merken 2>"$TMP/err4")
pruef "es gibt eine Kandidatin (kein Verhungern)" "ja" \
  "$([ -n "$_K4" ] && echo ja || echo nein)"
# ⭐ Gegreppt wird die MARKE, nicht der Satz (tests/README.md) — hier stand zuerst
#   `Historie voll`, also genau der Fehler, den die Regel benennt.
pruef "und die Lockerung wird GEMELDET, nicht verschwiegen" "ja" \
  "$(grep -q 'HISTORIE_VOLL' "$TMP/err4" && echo ja || echo nein)"
pruef "die Meldung geht NICHT nach stdout (der Aufrufer liest dort einen Pfad)" "ja" \
  "$([ -f "$_K4" ] && echo ja || echo nein)"
unset MIND_VERDICHTEN_HISTORIE

echo "  Fall 5: ⭐ der Regler wirkt — N=1 heisst: nur nicht zweimal hintereinander"
P5="$TMP/projekt fuenf"; M5="$P5/memory"; bau "$M5" 4
MIND_VERDICHTEN_HISTORIE=1; export MIND_VERDICHTEN_HISTORIE
F=$(basename "$(waehle "$P5" "$M5" mind-memory merken)")
G=$(basename "$(waehle "$P5" "$M5" mind-memory merken)")
H=$(basename "$(waehle "$P5" "$M5" mind-memory merken)")
pruef "N=1: erste, zweite, wieder erste" "datei1.md datei2.md datei1.md" "$F $G $H"
unset MIND_VERDICHTEN_HISTORIE

echo "  Fall 6: ⛔ je SKILL getrennt — vier Traeger teilen eine Datei"
P6="$TMP/projekt sechs"; M6="$P6/memory"; bau "$M6" 4
waehle "$P6" "$M6" mind-memory merken >/dev/null
pruef "mind-rules ist von mind-memorys Historie nicht gesperrt" "datei1.md" \
  "$(basename "$(waehle "$P6" "$M6" mind-rules merken)")"
pruef "Historie traegt beide, angehaengt statt ueberschrieben" "2" \
  "$(grep -c '^skill=' "$P6/.claude-mind/verdichten-historie")"

echo "  Fall 7: ⛔ FAIL-SAFE in Richtung HEUTE"
P7="$TMP/projekt sieben"; M7="$P7/memory"; bau "$M7" 4
pruef "leerer Projektpfad -> groesste Datei, rc 0" "datei1.md" \
  "$(basename "$(liste "$M7" | mind_verdicht_kandidat "" mind-memory merken 2>/dev/null)")"
pruef "unbrauchbarer Skillname -> groesste Datei" "datei1.md" \
  "$(basename "$(liste "$M7" | mind_verdicht_kandidat "$P7" "MIND/Memory" merken 2>/dev/null)")"
pruef "leere Liste -> rc 1, keine Ausgabe" "1|" \
  "$(_o=$(printf '' | mind_verdicht_kandidat "$P7" mind-memory probe 2>/dev/null); echo "$?|$_o")"
pruef "nicht existierende Pfade werden verworfen, nicht gewaehlt" "datei1.md" \
  "$(basename "$(printf '%s\n%s\n' "$M7/gibt-es-nicht.md" "$M7/datei1.md" \
      | mind_verdicht_kandidat "$P7" mind-memory probe 2>/dev/null)")"

echo "  Fall 8: ⛔ Pfad MIT LEERZEICHEN — daran ist die Rotation in lib.sh schon zerlegt"
pruef "Projektpfad traegt ein Leerzeichen" "ja" \
  "$(case "$P1" in *" "*) echo ja ;; *) echo nein ;; esac)"
pruef "Historie nennt den vollen Pfad, unzerlegt" "ja" \
  "$(grep -qF " datei=$M1/" "$P1/.claude-mind/verdichten-historie" && echo ja || echo nein)"

echo "  Fall 9: ⛔ wer den Merker verdichtet= SCHREIBT, muss ihn auch LESEN (Kollision IM Lauf)"
# ⚠ Gemessen 29.09.2026: vier Traeger schrieben den Merker, EINER las ihn — die
#   Zusicherung „nie dieselbe Datei zweimal im Lauf" galt nur fuer den letzten.
#   Faithful nachgestellt (Kettenreihenfolge, backup-usage.md groesste Rule UND
#   Companion-Rule): ALT waehlten mind-files und mind-rules DIESELBE Datei.
for _s in mind-files mind-rules mind-update; do
  _md="$R/skills/$_s/SKILL.md"
  # ⚠ v5.140.0: die Form ist jetzt die pruefende Funktion (Etappe 51 §2) — die
  #    Zusicherung („der Traeger merkt die Datei") ist unveraendert.
  pruef "$_s merkt verdichtet= (ueber die pruefende Funktion)" "ja" \
    "$(grep -q 'mind_verdichtet_merken "\$PROJ" "\$DATEI"' "$_md" && echo ja || echo nein)"
  pruef "   ... und LIEST es auch" "ja" \
    "$(grep -q "_SCHON=\$(grep '\^verdichtet='" "$_md" && echo ja || echo nein)"
done
# ⭐ mind-claudemd schreibt den Merker, liest ihn aber bewusst NICHT: es waehlt immer
#   `$ZIEL_MD`, hat also nichts zu ueberspringen. Der Fall sichert, dass das eine
#   Entscheidung bleibt und nicht zur vierten Luecke wird.
pruef "mind-claudemd waehlt eine FESTE Datei (deshalb kein Leser noetig)" "ja" \
  "$(grep -q '^DATEI="\$ZIEL_MD"' "$R/skills/mind-claudemd/SKILL.md" && echo ja || echo nein)"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
