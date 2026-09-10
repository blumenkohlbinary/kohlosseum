#!/usr/bin/env bash
# =============================================================================
#  /mind-cleaner — Einordner und Umzugs-Gates  (NEU v5.15.0)
# =============================================================================
#
# ⛔ WAS HIER ENTSCHIEDEN WIRD
#
# /mind-cleaner zerschneidet die Wissensbasis des Nutzers. Beide Werkzeuge
# darunter tragen deshalb ihre eigene Gegenprobe (`--selbsttest`). Diese Sammlung
# faehrt sie und prueft zusaetzlich das, was ein Selbsttest NICHT kann:
#
#   1. Halten die Gates am ECHTEN Umzug vom 23.08.2026? (5 Dateien, real vollzogen)
#   2. Bleiben die zwei gemessenen FEHLURTEILE des Einordners sichtbar?
#
# ⭐ Punkt 2 ist der ungewoehnliche. Normalerweise prueft man, dass ein Werkzeug
#    richtig liegt. Hier wird geprueft, dass es seine bekannten Fehler WEITER
#    NENNT — denn beide sind nicht wegzustellen, und ein Werkzeug, das seine
#    Grenze verschweigt, ist gefaehrlicher als eines, das sie kennt.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EIN="$WURZEL/references/cleaner_einordnung.py"
UMZ="$WURZEL/references/cleaner_umzug.py"

fehler=0
pruefe() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-52s ist=%-9s soll=%s\n' "$1" "$2" "$3"
  else
    printf '    FEHL %-52s ist=%-9s soll=%s\n' "$1" "$2" "$3"
    fehler=$((fehler + 1))
  fi
}

for f in "$EIN" "$UMZ"; do
  [ -f "$f" ] || { echo "ABBRUCH: $f fehlt (Wurzel: $WURZEL)"; exit 2; }
done

echo "=============================================================================="
echo "  1) Die eigenen Gegenproben beider Werkzeuge"
echo "=============================================================================="
python "$EIN" --selbsttest > /dev/null 2>&1
pruefe "Einordner: Selbsttest" "$?" "0"
python "$UMZ" --selbsttest > /dev/null 2>&1
pruefe "Umzugs-Gates: Selbsttest" "$?" "0"

echo
echo "=============================================================================="
echo "  2) ⭐ Die Gates gegen einen kuenstlichen Umzug — beide Richtungen"
echo "=============================================================================="
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/skills/probe"

# ⛔ v5.71.0: DIE FIXTURE IST GEWACHSEN, DAS GATE IST NICHT GELOCKERT — derselbe
#    Griff wie in v5.39.0 elf Zeilen weiter unten, und aus demselben Grund.
#    Das neue Gate ENTLASTUNG verlangt, dass die Kurz-Rule in BYTES kleiner wird.
#    Mit den alten Ein-Wort-Absaetzen ("Zwei", "Drei", ...) war der PFLICHT-
#    Doppelzeiger laenger als der gesamte ausgelagerte Inhalt — der Umzug machte
#    die immer ladende Datei GROESSER und war damit genau der Fall, den der
#    Nutzer als "ihr stopft alles voll" gemeldet hat.
# ⭐ Drei Fixtures hatten diese Form (hier, test_doppelzeiger.sh und der
#    Selbsttest in cleaner_umzug.py). Alle drei entstanden, als der Vertrag nur
#    fragte "ist etwas verloren gegangen?" — keine fragte je "ist etwas
#    leichter geworden?".
# ⚠ Die Absaetze sind WORTGLEICH in alt und skill, sonst bricht das INHALT-Gate
#   an den Marken. "Eins" bleibt kurz: der Absatz bleibt in der Leitplanke.
_Z2='Zwei - die Herleitung samt Messreihe vom 21.08.2026, mit allen Zahlen und der Gegenprobe.'
_Z3='Drei - die vollstaendige Bedienung mit jedem Schalter und den drei Fallen darin.'
_Z4='Vier - der Vorfall, aus dem die Regel entstand, mit Datum und Belegen.'
_Z5='Fuenf - was danach anders gemacht wurde und woran man merkt, dass es wirkt.'
printf -- '---\ndescription: x\n---\n# A\n\nEins\n\n%s\n\n%s\n\n%s\n\n%s\n' \
  "$_Z2" "$_Z3" "$_Z4" "$_Z5" > "$T/alt.md"
printf -- '---\nname: probe\ndescription: Beschreibt ausfuehrlich genug worum es geht und nennt die Auslesewoerter\n---\n# A\n\n%s\n\n%s\n\n%s\n\n%s\n' \
  "$_Z2" "$_Z3" "$_Z4" "$_Z5" > "$T/skills/probe/SKILL.md"

# Der gute Fall: DOPPELZEIGER (Pfad UND Command), keine Ladebedingung,
# nichts verloren.
# v5.39.0: der Command kam dazu. Bis v5.38.0 nannte diese Fixture nur den
# Pfad und galt als 'vollstaendiger Umzug' - unter dem neuen Vertrag ist sie
# unvollstaendig. Die FIXTURE ist nachgezogen, das GATE nicht gelockert.
printf -- '---\ndescription: Leitplanke\n---\n# A\n\nEins\n\nVolltext: `%s`\nWird er nicht angeboten: Command `/probe`.\n' \
  "$T/skills/probe/SKILL.md" > "$T/kurz_gut.md"
python "$UMZ" --alt "$T/alt.md" --kurz "$T/kurz_gut.md" --skill "$T/skills/probe/SKILL.md" >/dev/null 2>&1
pruefe "vollstaendiger Umzug -> alle Gates halten" "$?" "0"

# ⛔ Der Fall, der die ganze Architektur traegt: Pfad FEHLT.
printf -- '---\ndescription: Leitplanke\n---\n# A\n\nEins\n\nVolltext steht im Skill `probe`.\n' > "$T/kurz_ohne.md"
AUS=$(python "$UMZ" --alt "$T/alt.md" --kurz "$T/kurz_ohne.md" --skill "$T/skills/probe/SKILL.md" 2>&1)
RC=$?
pruefe "nur Skill-NAME statt Pfad -> Bruch" "$RC" "1"
pruefe "und nennt die 20-84-Prozent-Mechanik" \
       "$(printf '%s' "$AUS" | grep -c '20-84')" "1"

# Ladebedingung in der Kurz-Rule: eine Leitplanke, die nicht immer laedt.
printf -- '---\ndescription: L\nglobs: ["**/*.md"]\n---\n# A\n\nEins\n\n`%s`\n' \
  "$T/skills/probe/SKILL.md" > "$T/kurz_glob.md"
python "$UMZ" --alt "$T/alt.md" --kurz "$T/kurz_glob.md" --skill "$T/skills/probe/SKILL.md" >/dev/null 2>&1
pruefe "Kurz-Rule mit globs: -> Bruch" "$?" "1"

# Fehlende Datei ist NICHT MESSBAR, nicht 'bestanden'.
python "$UMZ" --alt "$T/gibtsnicht.md" --kurz "$T/kurz_gut.md" --skill "$T/skills/probe/SKILL.md" >/dev/null 2>&1
pruefe "fehlende Datei -> Rueckgabe 2 (nicht messbar)" "$?" "2"

echo
echo "=============================================================================="
echo "  3) ⭐ Die gemessenen FEHLURTEILE muessen sichtbar BLEIBEN"
echo "=============================================================================="
# ⛔ Kein Prueffall auf Richtigkeit, sondern auf EHRLICHKEIT. Beide Fehlurteile
#    sind am echten Bestand gemessen und nicht durch andere Schwellen wegzustellen.
#    Verschwinden sie aus der Ausgabe, verliert der Nutzer die Warnung.
AUS=$(python "$EIN" "$WURZEL/tests/README.md" 2>&1 || true)
pruefe "Ausgabe nennt autonom-arbeiten als Fehlurteil" \
       "$(printf '%s' "$AUS" | grep -c 'autonom-arbeiten')" "1"
pruefe "Ausgabe nennt keine-annahmen als Fehlurteil" \
       "$(printf '%s' "$AUS" | grep -c 'keine-annahmen')" "1"
pruefe "Ausgabe sagt: COMMAND-Vorschlag nie ohne Bestaetigung" \
       "$(printf '%s' "$AUS" | grep -c 'ohne menschliche Bestaetigung')" "1"
# ⚠ grep MIT -i. Die Ausgabe schreibt "NICHT", die erste Fassung dieser Zeile
#   suchte "nicht" -> 0 Treffer, obwohl der Satz dasteht. Dritter Fall derselben
#   Bauart an einem Tag; der zweite haette fast ein korrektes Zitat in
#   env-vars.md als erfunden verworfen.
pruefe "Ausgabe sagt: HOOK-KANDIDAT heisst nicht gebaut" \
       "$(printf '%s' "$AUS" | grep -ci "heisst NICHT 'wird gebaut'")" "1"

echo
echo "=============================================================================="
echo "  4) Der Einordner muss UNTERSCHEIDEN, nicht nur laufen"
echo "=============================================================================="
mkdir -p "$T/korpus"
printf -- '# S\n\n⛔ NIEMALS `rm -rf` auf `dist/` anwenden.\n\n⛔ NIE `git push` ohne `git pull --rebase`.\n' > "$T/korpus/hart.md"
printf -- '# N\n\nDer Ablauf hat drei Stufen.\n\nDie zweite liegt im Speicher.\n\nDie dritte legt ab.\n' > "$T/korpus/weich.md"
AUS=$(python "$EIN" --verzeichnis "$T/korpus" 2>&1)
pruefe "erzwingend+konkret -> HOOK-KANDIDAT" \
       "$(printf '%s' "$AUS" | grep -c 'hart.md.*HOOK-KANDIDAT')" "1"
# ⛔ v5.27.0: die Klasse heisst COMMAND, nicht mehr SKILL. Nutzer-Auftrag
#    "ich will keine skill typen ... nur lokal global" — "Skill" und
#    "Slash-Command" standen in der Einordnungstabelle als ZWEI Wege und sind
#    dasselbe: etwas, das man mit /name tippt. Die Zusicherung bleibt gleich
#    streng, nur der Name ist neu — dasselbe Vorgehen wie bei
#    test_leitplanke.sh in v5.25.0.
pruefe "Nachschlagewerk -> COMMAND" \
       "$(printf '%s' "$AUS" | grep -c 'weich.md.*COMMAND')" "1"

# Leeres Verzeichnis: KEIN Urteil, sondern eine Meldung.
mkdir -p "$T/leer"
python "$EIN" --verzeichnis "$T/leer" >/dev/null 2>&1
pruefe "leeres Verzeichnis -> Rueckgabe 1, kein stilles OK" "$?" "1"

echo
echo "=== $fehler Abweichung(en) ==="
exit $((fehler > 0 ? 1 : 0))
