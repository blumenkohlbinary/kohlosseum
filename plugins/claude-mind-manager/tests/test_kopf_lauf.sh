#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# Der Lauf-Kopf bindet an DIESEN Lauf (v5.140.0, Etappe 51 §1, Ritas Befund 29.09.2026).
#
# ⛔ WAS VORHER WAR, gemessen am 01.10.2026: `mind_kopf_epoch` nahm `tail -1` ueber alle
#    mind-all-Startzeilen und gab die Sekunde des NEUN TAGE alten Laufs zurueck — kein rc,
#    keine Meldung. mind-all schrieb den Wert als `run_started=`, und `mind_schritt_start`
#    verglich damit die ts DES KOPFES.
#    ⭐ **Die Pruefung verglich den Kopf mit sich selbst** (`Kopf < Kopf − 900`) und konnte
#       nicht fehlschlagen. Nachgewiesen: derselbe Kopf mit unabhaengigem Bezug -> rc 1.
#
# ⛔ DIE ZUSICHERUNG HIER IST IDENTITAET, NICHT ZEITNAEHE: Kopf und Lock tragen dieselbe
#    Lauf-ID, sonst ist es ein fremder Kopf. Die ID entsteht im KOPF (eigener bash-Fence,
#    der Lock existiert dort noch nicht) und wird vom Lock GELESEN.
# ⭐ Faelle 5/6 sind die Negativkontrollen: der EIGENE Kopf darf NIE abbrechen, und ein
#    Altbestands-Kopf ohne `lauf`-Feld verhaelt sich wie bisher — sonst waere jedes
#    bestehende Projekt ueber Nacht rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$R/hooks/lib.sh"
# ⛔ Die Sitzungskennung gilt fuer die GANZE Sammlung. Ohne sie schrieb kopf() den Kopf
# unter Sitzung A, und die spaetere Abfrage lief als "unbekannt" — das neue Sitzungs-
# Kriterium verweigerte dann zu Recht. Die Fixture war uneinheitlich, nicht der Code.
# ⚠ Fall 8c setzt sie bewusst ABWEICHEND, um das Erben zu pruefen.
export CLAUDE_CODE_SESSION_ID="aaaabbbbccccdddd"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# Ein Projekt mit Kopf-Block, geschrieben vom ECHTEN mind_schritt_start (nicht nachgebaut).
bau() {  # bau <name> -> echo Projektpfad
  local p="$TMP/$1 mit leer"
  mkdir -p "$p/.claude-mind" "$p/.claude/rules"
  printf '%s' "$p"
}
kopf() {  # kopf <projekt>  — schreibt eine echte mind-all-Startzeile
  ( cd "$1" && MIND_SKILL_VERSION="$(basename "$R")" \
      CLAUDE_CODE_SESSION_ID="aaaabbbbccccdddd" mind_schritt_start "$1" mind-all x >/dev/null 2>&1 )
}
lock() {  # lock <projekt> <lauf-id>
  mkdir -p "$1/.claude-mind/mind-all.lock"
  printf '%s' "$2" > "$1/.claude-mind/mind-all.lock/lauf"
  date +%s > "$1/.claude-mind/mind-all.lock/ts"
}

echo "  Fall 1: ⭐ die Kopfzeile TRAEGT eine Lauf-ID (vorher gab es das Feld nicht)"
P1=$(bau p1); kopf "$P1"
Q1="$P1/.claude-mind/schritt-quittung.jsonl"
pruef "Startzeile hat ein lauf-Feld" "ja" \
  "$(grep -q '"lauf":"[0-9]' "$Q1" && echo ja || echo nein)"
KL=$(mind_kopf_lauf "$P1")
pruef "mind_kopf_lauf liest sie" "ja" "$([ -n "$KL" ] && echo ja || echo nein)"
pruef "sie traegt die letzten 9 Zeichen der Sitzungskennung" "ja" \
  "$(printf '%s' "$KL" | grep -q 'ccccdddd$' && echo ja || echo nein)"

echo "  Fall 2: ⛔ FREMDER KOPF — Lock mit ANDERER ID: mind_kopf_epoch rc 1 + Meldung"
lock "$P1" "19700101-000000-fremd9999"
_A=$(mind_kopf_epoch "$P1" 2>&1); _RC=$?
pruef "Rueckgabe 1" "1" "$_RC"
pruef "   ... und KEINE Zahl auf stdout" "ja" \
  "$(printf '%s' "$(mind_kopf_epoch "$P1" 2>/dev/null)" | grep -qE '^[0-9]+$' && echo nein || echo ja)"
pruef "   ... Meldung nennt beide IDs" "ja" \
  "$(printf '%s' "$_A" | grep -q 'FREMDER KOPF' && echo ja || echo nein)"

echo "  Fall 3: ⛔ und der Skill-Start bricht ab (Ritas Fall, vorher rc 0)"
: > "$P1/.claude-mind/analyzed-scopes"
{ echo "run_started=$(date +%s)"; echo "snapshot=$TMP"; } > "$P1/.claude-mind/analyzed-scopes"
_B=$(MIND_SKILL_VERSION="$(basename "$R")" mind_schritt_start "$P1" mind-files x 2>&1); _RC2=$?
pruef "Rueckgabe 1" "1" "$_RC2"
pruef "   ... Meldung nennt den fremden Lauf" "ja" \
  "$(printf '%s' "$_B" | grep -q 'FREMDER KOPF' && echo ja || echo nein)"

echo "  Fall 4: ⛔ KEIN Kopf -> rc 1, und NICHT mehr die jetzige Sekunde"
P4=$(bau p4)
_C=$(mind_kopf_epoch "$P4" 2>&1); _RC3=$?
pruef "Rueckgabe 1" "1" "$_RC3"
pruef "   ... keine Sekunde auf stdout (vorher kam date +%s)" "ja" \
  "$(printf '%s' "$(mind_kopf_epoch "$P4" 2>/dev/null)" | grep -qE '^[0-9]+$' && echo nein || echo ja)"
pruef "   ... Meldung sagt, dass nichts geraten wird" "ja" \
  "$(printf '%s' "$_C" | grep -q 'KEIN mind-all-KOPF' && echo ja || echo nein)"

echo "  Fall 5: ⭐ NEGATIVKONTROLLE — der EIGENE Kopf laeuft durch"
P5=$(bau p5); kopf "$P5"
lock "$P5" "$(mind_kopf_lauf "$P5")"
_E=$(mind_kopf_epoch "$P5" 2>/dev/null); _RC4=$?
pruef "Rueckgabe 0" "0" "$_RC4"
pruef "   ... und eine echte Sekunde kommt zurueck" "ja" \
  "$(printf '%s' "$_E" | grep -qE '^[0-9]{9,}$' && echo ja || echo nein)"
{ echo "run_started=$(date +%s)"; echo "snapshot=$TMP"; } > "$P5/.claude-mind/analyzed-scopes"
MIND_SKILL_VERSION="$(basename "$R")" mind_schritt_start "$P5" mind-files x >/dev/null 2>&1
pruef "   ... und der Skill-Start bricht NICHT ab" "0" "$?"

echo "  Fall 6: ⭐ ALTBESTAND — Kopf ohne lauf-Feld verhaelt sich wie bisher"
# ⛔ Ohne diesen Fall waere jedes bestehende Projekt ueber Nacht rot: alle Quittungen, die
#    vor 5.140.0 geschrieben wurden, haben kein lauf-Feld. Die Identitaet kann dort nichts
#    bilden — und eine Pruefung, die ihren Gegenstand nicht bilden kann, darf nicht urteilen.
P6=$(bau p6)
printf '{"ereignis":"start","skill":"mind-all","erwartet":"x","ts":"%s","code":"x","text":"x","versionsbruch":false}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$P6/.claude-mind/schritt-quittung.jsonl"
lock "$P6" "19700101-000000-irgendwas"
_F=$(mind_kopf_epoch "$P6" 2>/dev/null); _RC5=$?
pruef "ohne lauf-Feld: rc 0 (kein Urteil ohne Gegenstand)" "0" "$_RC5"
pruef "   ... und die Sekunde des Kopfes kommt zurueck" "ja" \
  "$(printf '%s' "$_F" | grep -qE '^[0-9]{9,}$' && echo ja || echo nein)"

echo "  Fall 7: ⛔ run_started kommt aus lock/ts, NICHT aus dem Kopf"
pruef "mind-all liest lock/ts" "ja" \
  "$(grep -q 'mind-all.lock/ts' "$R/skills/mind-all/SKILL.md" && echo ja || echo nein)"
pruef "   ... und ruft mind_kopf_epoch NICHT mehr dafuer" "0" \
  "$(grep -c '$(mind_kopf_epoch' "$R/skills/mind-all/SKILL.md")"
pruef "   ... der Lock holt die ID aus dem Kopf" "ja" \
  "$(grep -q 'LAUF=$(mind_kopf_lauf' "$R/skills/mind-all/SKILL.md" && echo ja || echo nein)"
# ⚠ Fehlt lock/ts, darf KEINE Sekunde geraten werden — die Zeile entfaellt dann.
pruef "   ... fehlt lock/ts, wird run_started NICHT geschrieben" "ja" \
  "$(grep -q 'run_started wird NICHT geschrieben' "$R/skills/mind-all/SKILL.md" && echo ja || echo nein)"

echo "  Fall 8: ⛔ RITAS LAGE, woertlich — Kopf-Block NICHT gefahren"
# ⛔ Antons Pflicht-Fall, und er deckt den Fehler in MEINEM ersten Entwurf auf:
#    Rita fuhr Step 0 nicht. Dann ist die letzte Startzeile die vom 20.09. Mein erster
#    Bau liess den Lock diese ID BLIND uebernehmen — und danach verglich
#    `mind_kopf_epoch` alt gegen alt, war zufrieden, rc 0. Dieselbe Zirkularitaet eine
#    Ebene hoeher: der Bezugswert kam wieder aus dem Gegenstand.
# ⭐ Die ID wird hier NICHT von Hand gesetzt, sondern ueber den ECHTEN Weg geholt, den
#    mind-all nimmt. Mein erster Prueffall setzte sie selbst und war deshalb blind.
P8="$TMP/p8 mit leer"; mkdir -p "$P8/.claude-mind"
# der alte Kopf vom 20.09., mit seiner Lauf-ID — und seine Laufspur in .done
ALT_ID="20260920-174224-604ab6140"
printf '{"ereignis":"start","skill":"mind-all","erwartet":"x","ts":"2026-09-20T17:42:24Z","code":"x","text":"x","versionsbruch":false,"lauf":"%s"}\n' \
  "$ALT_ID" > "$P8/.claude-mind/schritt-quittung.jsonl"
printf 'run_started=1789918931\nskill=mind-files|%s\n' "$ALT_ID" \
  > "$P8/.claude-mind/analyzed-scopes.done"
# KEIN neuer Kopf-Block. Jetzt holt sich der Lock seine ID so wie mind-all:
_L8=$(mind_kopf_lauf_frisch "$P8" 2>"$TMP/err8"); _RC8=$?
pruef "frische ID verweigert (rc 1)" "1" "$_RC8"
pruef "   ... und KEINE ID auf stdout" "ja" "$([ -z "$_L8" ] && echo ja || echo nein)"
pruef "   ... Meldung sagt: Kopf-Block fuer DIESEN Lauf fehlt" "ja" \
  "$(grep -q 'KOPF-BLOCK FUER DIESEN LAUF FEHLT' "$TMP/err8" && echo ja || echo nein)"
pruef "   ... und nennt den abgeschlossenen Lauf" "ja" \
  "$(grep -q "$ALT_ID" "$TMP/err8" && echo ja || echo nein)"
# ⛔ FALL 8b — DIESELBE LAGE OHNE `.done`, und sie ist der eigentliche Fall. Mein zweiter
#    Bau fragte nur „steht diese ID in `.done` oder in `lauf-verbraucht`?" und war bei
#    Fall 8 gruen — weil Fall 8 ein `.done` baut. Ohne `.done` gab dieselbe Lage **rc 0**
#    (selbst gemessen). `.done` wird je Lauf ERSETZT: die Lage ohne ist der Normalfall.
#    ⭐ Gefangen wird sie erst von der richtigen Frage — nicht „ist die ID alt?", sondern
#      „hat der Kopf-Block DIESES Laufs gelaufen?" (Merker `lauf-offen`).
P8d="$TMP/p8d mit leer"; mkdir -p "$P8d/.claude-mind"
printf '{"ereignis":"start","skill":"mind-all","erwartet":"x","ts":"2026-09-20T17:42:24Z","code":"x","text":"x","versionsbruch":false,"lauf":"%s"}\n' \
  "$ALT_ID" > "$P8d/.claude-mind/schritt-quittung.jsonl"
# KEIN .done, KEIN lauf-verbraucht, KEIN lauf-offen — nur der alte Kopf.
_L8d=$(mind_kopf_lauf_frisch "$P8d" 2>"$TMP/err8d"); _RC8d=$?
pruef "ohne .done trotzdem verweigert (rc 1)" "1" "$_RC8d"
pruef "   ... und die Meldung nennt den fehlenden Kopf-Block" "ja" \
  "$(grep -q 'keinen eigenen Kopf-Block' "$TMP/err8d" && echo ja || echo nein)"
pruef "   ... keine ID auf stdout" "ja" "$([ -z "$_L8d" ] && echo ja || echo nein)"
# ⛔ Und die zweite Quelle einzeln: eine ID, die ein Lauf freigegeben hat, ist verbraucht.
P8b="$TMP/p8b mit leer"; mkdir -p "$P8b/.claude-mind"
kopf "$P8b"
_ID=$(mind_kopf_lauf "$P8b")
mind_lauf_verbraucht "$P8b" "$_ID"
mind_kopf_lauf_frisch "$P8b" >/dev/null 2>&1
pruef "schon verbrauchte ID wird verweigert" "1" "$?"
# ⭐ NEGATIVKONTROLLE: eine FRISCHE ID wird angenommen — und danach ist sie verbraucht,
#   ein zweites Annehmen scheitert (eine ID gilt genau einmal).
P8c="$TMP/p8c mit leer"; mkdir -p "$P8c/.claude-mind"
kopf "$P8c"
mind_kopf_lauf_frisch "$P8c" >/dev/null 2>&1
pruef "frische ID wird angenommen (rc 0)" "0" "$?"
mind_kopf_lauf_frisch "$P8c" >/dev/null 2>&1
pruef "   ... und beim ZWEITEN Mal verweigert (genau einmal)" "1" "$?"
# ⛔ FALL 8c — FREMDE SITZUNG erbt keinen liegengebliebenen Kopf (Antons Ergaenzung).
#    Stirbt ein Lauf zwischen Kopf und Lock, bleibt `lauf-offen` liegen. Eine ANDERE
#    Sitzung darf ihn nicht uebernehmen. Geprueft wird am Suffix der Lauf-ID — sie endet
#    auf die letzten neun Zeichen der Sitzungskennung, ein zweites Feld braucht es nicht.
# ⚠ Benannt und NICHT geschlossen: dieselbe Sitzung, Lauf stirbt zwischen Kopf und Lock.
#   Dann passt das Suffix. Der Kopf gehoert dann zu einem Lauf, der nie einen Lock hielt.
P8e="$TMP/p8e mit leer"; mkdir -p "$P8e/.claude-mind"
( cd "$P8e" && MIND_SKILL_VERSION="$(basename "$R")" \
    CLAUDE_CODE_SESSION_ID="aaaabbbbccccdddd" mind_schritt_start "$P8e" mind-all x >/dev/null 2>&1 )
CLAUDE_CODE_SESSION_ID="zzzzyyyyxxxxwwww" mind_kopf_lauf_frisch "$P8e" >/dev/null 2>&1
pruef "fremde Sitzung: verweigert" "1" "$?"
# ⭐ NEGATIVKONTROLLE: dieselbe Sitzung nimmt ihn an — sonst waere die Pruefung eine Sperre
#   gegen jeden, nicht gegen Fremde.
CLAUDE_CODE_SESSION_ID="aaaabbbbccccdddd" mind_kopf_lauf_frisch "$P8e" >/dev/null 2>&1
pruef "   ... eigene Sitzung: angenommen" "0" "$?"
# ⛔ mind-all darf die ID NICHT neu rechnen, wenn sie fehlt — das wuerde den Fall decken.
pruef "mind-all holt sie ueber mind_kopf_lauf_frisch" "ja" \
  "$(grep -q 'LAUF=$(mind_kopf_lauf_frisch' "$R/skills/mind-all/SKILL.md" && echo ja || echo nein)"
pruef "   ... und rechnet sie NICHT neu (kein date-Rueckfall)" "nein" \
  "$(grep -q '|| LAUF="$(date' "$R/skills/mind-all/SKILL.md" && echo ja || echo nein)"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
