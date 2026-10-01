#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# Etappe 51 §2/§3 (v5.140.0, Ritas Befunde 29.09.2026) — zwei Buchungen, die log-en statt zu
# behaupten.
#
# §2 `verdichtet=`: Rita hat zweimal das DEPONAT (`$ERGEBNIS`) gebucht statt der Quelldatei
#    (`$DATEI`). Die vier Traeger schrieben per `echo >>`, nichts pruefte den Pfad — der
#    Merker sperrte damit eine Datei, die niemand verdichten wollte.
# §3 `bestand=<skill>:0/0`: zaehlte STILL wie ein voller Pass. Gemessen an den LESERN, nicht
#    vermutet — `lib.sh` zaehlt die ZEILE (`grep -c '^bestand='`) und fragt sonst nur, ob eine
#    Zeile je Skill existiert. In `umfang=` stand `5/5 bestand`, auch wenn kein Bestand
#    angesehen wurde.
#
# ⭐ DIE NEGATIVKONTROLLEN SIND HIER DAS WICHTIGERE: eine Pruefung, die JEDEN Pfad abweist,
#    waere so falsch wie keine (Fall 2), und eine Bilanz, die bei jeder Zahl „null" anhaengt,
#    waere Rauschen (Fall 5). Beide Richtungen stehen nebeneinander.
# ⛔ §3 WEIST AUS, es WERTET NICHT: `5/5` bleibt `5/5`. Daraus einen Teilsync zu machen waere
#    eine neue Regel und Antons Entscheidung — Fall 6 haelt fest, dass die Zahl sich NICHT
#    aendert, damit niemand das stillschweigend nachzieht.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$R/hooks/lib.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

P="$TMP/projekt mit leer"
mkdir -p "$P/.claude-mind" "$P/.claude/rules"
echo "inhalt" > "$P/.claude/rules/echt.md"
MARKE="$P/.claude-mind/analyzed-scopes"

echo "  Fall 1: ⛔ §2 — der DEPONAT-Pfad wird abgewiesen (Ritas Fall)"
# ⛔ ZUERST: GIBT ES DIE FUNKTION? Ohne diese Zeile besteht „nichts gebucht" durch
#    ABWESENHEIT — im Stand vor 5.140.0 scheitert der Aufruf, also bucht er nichts,
#    also gruen, ohne dass etwas abgewiesen waere (gemessen an der Gegenprobe).
pruef "mind_verdichtet_merken existiert ueberhaupt" "ja" \
  "$(type -t mind_verdichtet_merken >/dev/null 2>&1 && echo ja || echo nein)"
: > "$MARKE"
mind_verdichtet_merken "$P" "$P/.claude-mind/verdichten-mind-rules.nachher.md" >/dev/null 2>&1
pruef "Rueckgabe 2" "2" "$?"
pruef "   ... und NICHTS gebucht" "0" "$(grep -c '^verdichtet=' "$MARKE")"

echo "  Fall 2: ⭐ NEGATIVKONTROLLE — die QUELLDATEI wird gebucht (sonst waere Fall 1 wertlos)"
mind_verdichtet_merken "$P" "$P/.claude/rules/echt.md" >/dev/null 2>&1
pruef "Rueckgabe 0" "0" "$?"
pruef "   ... genau eine Buchung" "1" "$(grep -c '^verdichtet=' "$MARKE")"
pruef "   ... und zwar die Quelldatei" "ja" \
  "$(grep -q 'verdichtet=.*/\.claude/rules/echt\.md$' "$MARKE" && echo ja || echo nein)"

echo "  Fall 3: ⛔ §2 — fehlende Datei und leerer Pfad werden abgewiesen"
mind_verdichtet_merken "$P" "$P/gibtesnicht.md" >/dev/null 2>&1
pruef "fehlende Datei: rc 2" "2" "$?"
mind_verdichtet_merken "$P" "" >/dev/null 2>&1
pruef "leerer Pfad: rc 2" "2" "$?"
pruef "   ... und immer noch nur die EINE gueltige Buchung" "1" "$(grep -c '^verdichtet=' "$MARKE")"

echo "  Fall 4: ⛔ §3 — die Stichprobe quittiert SELBST, wenn das Budget leer ist"
P4="$TMP/p4 mit leer"; mkdir -p "$P4/.claude-mind"
printf 'skill=mind-files|x\n' > "$P4/.claude-mind/analyzed-scopes"
echo y > "$P4/a.md"
python "$R/references/cleaner_stichprobe.py" "$P4" --skill mind-files --max 0 "$P4/a.md" >/dev/null 2>&1
pruef "bestand=mind-files:0/0 steht in der Marke" "ja" \
  "$(grep -q '^bestand=mind-files:0/0$' "$P4/.claude-mind/analyzed-scopes" && echo ja || echo nein)"
# ⭐ ECHTE und STAERKERE Zusicherung, vom ersten Anlauf dieses Falls gefunden: ohne
#   `--skill` kommt der Lauf GAR NICHT bis zur Stichprobe — rc 2, „--skill fehlt"
#   (Zeile 424–427). Ich hatte hier zuerst eine Meldung aus einem defensiven
#   else-Zweig erwartet; der war UNERREICHBAR und ist entfernt. Der Fall prueft
#   jetzt, was wirklich gilt.
P4b="$TMP/p4b mit leer"; mkdir -p "$P4b/.claude-mind"
printf 'skill=mind-files|x\n' > "$P4b/.claude-mind/analyzed-scopes"
echo y > "$P4b/a.md"
_O=$(python "$R/references/cleaner_stichprobe.py" "$P4b" --max 0 "$P4b/a.md" 2>&1); _RCS=$?
pruef "ohne --skill: rc 2, keine Buchung, und der Grund steht da" "2|0|ja" \
  "$_RCS|$(grep -c '^bestand=' "$P4b/.claude-mind/analyzed-scopes")|$(printf '%s' "$_O" | grep -q 'skill fehlt' && echo ja || echo nein)"

echo "  Fall 5: ⛔ §3 — die Null ist in der Bilanz SICHTBAR"
P5="$TMP/p5 mit leer"; mkdir -p "$P5/.claude-mind"
printf 'skill=mind-files|x\nbestand=mind-files:0/0\nbestand=mind-rules:3/3\n' \
  > "$P5/.claude-mind/analyzed-scopes"
_U=$(mind_umfang_bilden "$P5" "" 4 2>/dev/null)
pruef "bestand-null nennt den Skill" "ja" \
  "$(printf '%s' "$_U" | grep -q 'bestand-null=mind-files' && echo ja || echo nein)"
# ⛔ Die Marke muss DA sein, bevor ihr Inhalt beurteilt wird — sonst besteht dieser
#    Fall durch Abwesenheit (im alten Stand gibt es `bestand-null` nicht).
pruef "   ... und NUR den mit 0/0 (nicht den mit 3/3)" "ja|nein" \
  "$(printf '%s' "$_U" | grep -q 'bestand-null=' && echo ja || echo nein)|$(printf '%s' "$_U" | grep -q 'bestand-null=.*mind-rules' && echo ja || echo nein)"

echo "  Fall 6: ⭐ NEGATIVKONTROLLE — ohne Null steht KEIN Zusatz, und die ZAHL bleibt"
P6="$TMP/p6 mit leer"; mkdir -p "$P6/.claude-mind"
printf 'skill=mind-files|x\nbestand=mind-files:2/2\nbestand=mind-rules:3/3\n' \
  > "$P6/.claude-mind/analyzed-scopes"
_V=$(mind_umfang_bilden "$P6" "" 4 2>/dev/null)
pruef "kein bestand-null, wenn es keine Null gibt" "nein" \
  "$(printf '%s' "$_V" | grep -q 'bestand-null' && echo ja || echo nein)"
# ⛔ Die Zahl darf sich durch §3 NICHT geaendert haben — 0/0 ist ein gelaufener Pass.
pruef "mit Null: die Zahl ist dieselbe wie ohne (2/5 bestand)" "ja" \
  "$([ "$(printf '%s' "$_U" | sed -n 's/.*\([0-9]\)\/5 bestand.*/\1/p')" \
     = "$(printf '%s' "$_V" | sed -n 's/.*\([0-9]\)\/5 bestand.*/\1/p')" ] && echo ja || echo nein)"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
