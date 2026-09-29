#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# Der PROBELAUF ist entfallen (v5.139.0, Etappe 50). Nutzer-Entscheidung 29.09.2026:
# „wieso kein richtiger lauf kostet geld" und „allgemein keine Probelaeufe mehr … ich will
# Ergebnisse sehen".
#
# ⛔ DIE ZUSICHERUNG DIESER SAMMLUNG IST NICHT „die Flagge ist weg", sondern: WER SIE NOCH
#    GIBT, BEKOMMT EINEN ABBRUCH — keinen stillen Echtlauf. Wer `--dry-run` tippt, erwartet,
#    dass nichts geschrieben wird; ein Lauf, der die Flagge ignoriert und trotzdem schreibt,
#    waere genau die Verhaltensaenderung, die niemand bemerkt
#    (`autonom-arbeiten.md`: „Verhalten, auf das der User sich verlaesst, NIE beim Umbau
#    still mitloeschen").
#
# ⭐ FALL 3 IST DIE NEGATIVKONTROLLE: OHNE die Flagge darf derselbe Block NICHT abbrechen.
#    Ein Abbruch-Wachter, der immer abbricht, waere so falsch wie einer, der nie abbricht.
# ⚠ Gefahren wird der Block WOERTLICH aus der SKILL.md, nicht nachgebaut — ein Nachbau
#   pruefte meinen Prueftext, nicht die Anleitung (Klasse `instrument-nachgebaut`).
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# Den Abbruch-Block woertlich aus einer SKILL.md ziehen und ausfuehrbar machen.
ausschnitt() {  # ausschnitt <skill> <args>
  local md="$R/skills/$1/SKILL.md" d="$TMP/a$2$1" von bis
  mkdir -p "$d"
  von=$(grep -n "^if echo \"\$ARGS\" | grep -qE '(^|\[\[:space:\]\])--dry-run" "$md" | head -1 | cut -d: -f1)
  [ -n "$von" ] || { echo "KEIN_BLOCK"; return 0; }
  bis=$((von + 20))
  {
    echo '#!/usr/bin/env bash'
    echo 'set -u'
    printf 'ARGS="%s"\n' "$2"
    sed -n "${von},${bis}p" "$md" | sed -n '1,/^fi$/p'
    echo 'echo "WEITERGELAUFEN"'
  } > "$d/lauf.sh"
  bash "$d/lauf.sh" 2>"$d/err" >"$d/out"; echo "$?"
}

SKILLS="mind-all mind-claudemd mind-memory mind-rules mind-files mind-update"

echo "  Fall 1: ⛔ --dry-run BRICHT AB (Rueckgabe 2), in JEDEM der sechs Skills"
for s in $SKILLS; do
  rc=$(ausschnitt "$s" "--dry-run")
  pruef "$s: Rueckgabe 2" "2" "$rc"
done

echo "  Fall 2: ⛔ und der Lauf laeuft NICHT weiter (kein stiller Echtlauf)"
# ⛔ DIE AUSGABEDATEI MUSS EXISTIEREN. Ohne diese Bedingung besteht der Fall durch
#    ABWESENHEIT: findet der Ausschnitt keinen Abbruch-Block (so im Stand vor 5.139.0),
#    entsteht keine Datei, und `grep -q` darauf ist falsch — also „nein", also gruen.
#    Gemessen an der Gegenprobe: 6 von 26 roten Faellen waren so faelschlich gruen.
#    Eine Pruefung, die ihren Gegenstand nicht bilden kann, MELDET das.
for s in $SKILLS; do
  _o="$TMP/a--dry-run$s/out"
  pruef "$s: Ausgabe da UND 'WEITERGELAUFEN' steht nicht darin" "ja|nein" \
    "$([ -f "$_o" ] && echo ja || echo nein)|$(grep -q 'WEITERGELAUFEN' "$_o" 2>/dev/null && echo ja || echo nein)"
done

echo "  Fall 3: ⭐ NEGATIVKONTROLLE — OHNE die Flagge bricht NICHTS ab"
for s in $SKILLS; do
  rc=$(ausschnitt "$s" "")
  pruef "$s: Rueckgabe 0 und weitergelaufen" "0|ja" \
    "$rc|$(grep -q 'WEITERGELAUFEN' "$TMP/a$s/out" && echo ja || echo nein)"
done

echo "  Fall 4: ⛔ die Meldung nennt den GRUND und den Weg, nicht nur ein Nein"
_E="$TMP/a--dry-runmind-all/err"
# ⛔ Erst pruefen, ob es die Fehlerdatei GIBT — sonst bestehen alle Zusicherungen dieses
#    Falls durch Abwesenheit (dieselbe Luecke wie in Fall 2, gemessen an der Gegenprobe).
pruef "es gibt ueberhaupt eine Fehlermeldung" "ja" \
  "$([ -s "$_E" ] && echo ja || echo nein)"
pruef "sie sagt, dass die Flagge entfallen ist" "ja" \
  "$(grep -q 'entfallen' "$_E" && echo ja || echo nein)"
pruef "sie nennt die Version" "ja" \
  "$(grep -q '5\.139\.0' "$_E" && echo ja || echo nein)"
pruef "sie sagt, was stattdessen zu tun ist (OHNE die Flagge)" "ja" \
  "$(grep -q 'OHNE die Flagge' "$_E" && echo ja || echo nein)"
# ⛔ Gemessen beim Bau: im ersten Anlauf stand in dieser Meldung ein Wort in Backticks, und
#    bash FUEHRTE es aus (shell-windows.md) — "--ask: command not found" auf stderr, das Wort
#    aus dem Text getilgt. Der Fall haelt fest, dass das nicht zurueckkommt.
pruef "kein 'command not found' — die Meldung enthaelt keine Backticks" "ja|nein" \
  "$([ -s "$_E" ] && echo ja || echo nein)|$(grep -q 'command not found' "$_E" 2>/dev/null && echo ja || echo nein)"
pruef "und --ask wird als bleibende Flagge genannt" "ja" \
  "$(grep -q '\-\-ask' "$_E" && echo ja || echo nein)"

echo "  Fall 5: ⛔ die Flagge wird auch nicht mehr ANGEBOTEN (sonst tippt sie jemand)"
for s in $SKILLS; do
  pruef "$s: kein --dry-run in description/argument-hint" "nein" \
    "$(head -20 "$R/skills/$s/SKILL.md" | grep -q -- '--dry-run' && echo ja || echo nein)"
done

echo "  Fall 6: ⛔ kein Zweig haengt mehr an DRY_RUN (eine immer wahre Bedingung bleibt nicht stehen)"
for s in $SKILLS; do
  pruef "$s: kein ausfuehrbares DRY_RUN mehr" "0" \
    "$(grep -v '^\s*#' "$R/skills/$s/SKILL.md" | grep -c 'DRY_RUN')"
done

echo "  Fall 7: ⭐ was BLEIBEN muss — der gfs-Loeschschutz ist kein Probelauf"
pruef "backup_tools.py gfs ist weiter default dry_run" "ja" \
  "$(grep -q 'def gfs_cleanup(root: Path, dry_run: bool = True' \
      "$R/references/backup-system-templates/tools/backup_tools.py" && echo ja || echo nein)"
pruef "und --apply ist weiter der Weg zum Loeschen" "ja" \
  "$(grep -q 'dry_run=not apply' \
      "$R/references/backup-system-templates/tools/backup_tools.py" && echo ja || echo nein)"
# ⛔ v5.139.0, Antons Entscheidung gegen meinen VOR-Vorschlag: `rollback.py restore`
#    verliert seinen Probelauf MIT. Sein Argument ist das bessere, und es steht im Code:
#    vor JEDEM restore entsteht ein Pre-Rollback-Snapshot (`rollback.py:9`, 261-263) —
#    jeder restore ist umkehrbar, der Blick vorher schuetzt nichts, was nicht schon
#    geschuetzt ist. Beim gfs ist es anders: `--apply` loescht OHNE Netz.
# ⛔ Gefragt wird der SYNTAXBAUM, nicht die Zeile. Mein erster Anlauf greppte und war
#    rot: der Treffer stand im DOCSTRING, der den Entfall ERKLAERT. Ein grep sieht das
#    Wort, der Parser sieht den Unterschied zwischen Prosa und Code.
pruef "rollback.py: `dry_run` ist kein Code mehr (AST, nicht grep)" "0" \
  "$(python "$(dirname "$0")/dry_run_weg.py" \
      "$R/references/backup-system-templates/tools/rollback.py" >/dev/null 2>&1; echo $?)"
pruef "und der Pre-Rollback-Snapshot ist BEDINGUNGSLOS (er traegt die Sicherheit jetzt)" "ja" \
  "$(grep -A1 '# Pre-Rollback-Sicherung' "$R/references/backup-system-templates/tools/rollback.py" \
     | grep -q 'pre_dir.mkdir(parents=True, exist_ok=True)' && echo ja || echo nein)"

echo "  Fall 8: ⛔ rollback.py restore --dry-run BRICHT AB (rc 2), kein stiller Echt-restore"
_RB="$R/references/backup-system-templates/tools/rollback.py"
_RBD="$TMP/rb"; mkdir -p "$_RBD"
(cd "$_RBD" && python "$_RB" restore gibtesnicht --dry-run >"$_RBD/out" 2>"$_RBD/err"; echo $? > "$_RBD/rc")
pruef "Rueckgabe 2" "2" "$(cat "$_RBD/rc" 2>/dev/null)"
pruef "Meldung da UND nennt den Entfall" "ja|ja" \
  "$([ -s "$_RBD/err" ] && echo ja || echo nein)|$(grep -q 'entfallen' "$_RBD/err" 2>/dev/null && echo ja || echo nein)"
pruef "sie nennt den Pre-Rollback-Snapshot als das, was schuetzt" "ja" \
  "$(grep -q 'Pre-Rollback-Snapshot' "$_RBD/err" 2>/dev/null && echo ja || echo nein)"
# ⚠ ASCII: die Datei wird in FREMDE Projekte installiert, deren Konsolen-Kodierung
#   niemand kennt. Gemessen beim Bau: ein Gedankenstrich kam als „?" heraus.
pruef "die Meldung ist ASCII (kein Gedankenstrich)" "nein" \
  "$(grep -qP '[^\x00-\x7F]' "$_RBD/err" 2>/dev/null && echo ja || echo nein)"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
