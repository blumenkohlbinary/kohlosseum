#!/usr/bin/env bash
# =============================================================================
#  Urteilsbuch + Duplikaterkennung  (NEU v5.16.0)
# =============================================================================
#
# ⛔ WAS HIER ENTSCHIEDEN WIRD
#
# Nutzer-Entscheidung 24.08.2026: BEIDE Werkzeuge duerfen aufraeumen —
# `/mind-cleaner` (mit Rueckfrage) und `/mind-claudemd` (autonom bei jedem
# `/mind-all`). Ohne gemeinsamen Zustand kippt diese Entscheidung ins Gegenteil:
#
#   1. Der Cleaner laesst eine "Verdichtung + Zeiger" bewusst stehen (Zielform).
#   2. /mind-claudemd sieht zwei Stellen mit gleichem Inhalt, haelt es fuer ein
#      Duplikat und entfernt eine — AUTONOM.
#   3. Danach fehlt der Kurz-Regel ihr Inhalt, und niemand weiss warum.
#
# Diese Sammlung prueft, dass genau das NICHT passieren kann.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
U="$WURZEL/references/cleaner_urteile.py"
D="$WURZEL/references/cleaner_duplikate.py"
# ⛔ WINDOWS-FASSUNG DER WURZEL. `python.exe` kann `/c/...` nicht
#    aufloesen — ein sys.path.insert mit MSYS-Pfad findet das Modul nie.
#    Genau hier zum SECHSTEN Mal an einem Tag hineingelaufen.
WREF=$(cygpath -m "$WURZEL/references" 2>/dev/null || echo "$WURZEL/references")

fehler=0
pruefe() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-50s ist=%-11s soll=%s\n' "$1" "$2" "$3"
  else
    printf '    FEHL %-50s ist=%-11s soll=%s\n' "$1" "$2" "$3"
    fehler=$((fehler + 1))
  fi
}

for f in "$U" "$D"; do
  [ -f "$f" ] || { echo "ABBRUCH: $f fehlt (Wurzel: $WURZEL)"; exit 2; }
done

echo "=============================================================================="
echo "  1) Die eigenen Gegenproben"
echo "=============================================================================="
python "$U" --selbsttest >/dev/null 2>&1; pruefe "Urteilsbuch: Selbsttest" "$?" "0"
python "$D" --selbsttest >/dev/null 2>&1; pruefe "Duplikate: Selbsttest"   "$?" "0"

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/proj"
A="$T/proj/a.md"; B="$T/proj/b.md"
printf '# A\nEins\n' > "$A"
printf '# B\nZwei\n' > "$B"

echo
echo "=============================================================================="
echo "  2) ⭐ Der Vertrag — ein autonomes Werkzeug darf zielform NICHT aufheben"
echo "=============================================================================="
python "$U" "$T/proj" --orte "$A" "$B" >/dev/null 2>&1
pruefe "unbeurteilt -> Rueckgabe 1" "$?" "1"

python "$U" "$T/proj" --schreiben --orte "$A" "$B" --urteil zielform \
       --werkzeug mind-cleaner --von mensch --grund "Verdichtung + Zeiger" >/dev/null 2>&1
AUS=$(python "$U" "$T/proj" --orte "$A" "$B" 2>&1); RC=$?
pruefe "nach Eintrag -> Rueckgabe 0" "$RC" "0"
pruefe "meldet zielform"          "$(printf '%s' "$AUS" | grep -c 'Urteil:  zielform')" "1"
pruefe "autonom DARF NICHT"       "$(printf '%s' "$AUS" | grep -c 'autonom:.*DARF NICHT')" "1"

echo
echo "=============================================================================="
echo "  3) Die Gegenrichtung — sonst waere das Buch eine Fessel"
echo "=============================================================================="
# ⛔ Ohne diesen Fall wuerde ein einmal gefaelltes Urteil eine Datei EINFRIEREN.
sleep 1
printf 'Drei\nVier\nFuenf\n' >> "$B"
AUS=$(python "$U" "$T/proj" --orte "$A" "$B" 2>&1)
pruefe "Inhalt geaendert -> veraltet" "$(printf '%s' "$AUS" | grep -c 'veraltet')" "1"

# Ein `duplikat` DARF ein autonomes Werkzeug anwenden — sonst raeumt niemand auf.
C="$T/proj/c.md"; printf '# C\n' > "$C"
python "$U" "$T/proj" --schreiben --orte "$A" "$C" --urteil duplikat \
       --werkzeug mind-claudemd --von autonom --grund "gleiche Aussage" >/dev/null 2>&1
AUS=$(python "$U" "$T/proj" --orte "$A" "$C" 2>&1)
pruefe "autonom DARF duplikat anwenden" "$(printf '%s' "$AUS" | grep -c 'autonom:.*DARF ')" "1"

echo
echo "=============================================================================="
echo "  4) ⭐ Zahlendrift — der Fall, den Textaehnlichkeit NIE findet"
echo "=============================================================================="
# ⛔ Der echte Fall aus dem eigenen Bestand, nachgebaut:
#    eine Stelle fuehrt einen Regler als geltend, die andere als entfallen.
mkdir -p "$T/echt/.claude/rules"
printf -- '---\ndescription: x\n---\n# P\n\n`MIND_NOTFALL_TOKENS` steht auf 940 000 und gilt.\n' \
  > "$T/echt/CLAUDE.md"
printf -- '---\ndescription: y\n---\n# R\n\n`MIND_NOTFALL_TOKENS` ist entfallen in v5.9.3.\n' \
  > "$T/echt/.claude/rules/regler.md"
AUS=$(python "$D" --bereich "$T/echt" --nur projekt 2>&1)
pruefe "Zahlendrift erkannt" "$(printf '%s' "$AUS" | grep -cE 'zahlendrift +1$')" "1"
pruefe "und sagt: entscheidet NICHT selbst" \
       "$(printf '%s' "$AUS" | grep -c 'entscheidet dieses Werkzeug NICHT')" "1"

# ⛔ DIE NEGATIVKONTROLLE, ohne die alles obige nichts wert waere.
#    Dieselbe Marke, verschiedene DATEN daneben — das ist KEINE Drift.
#    Die erste Fassung meldete hier 11 Fehlalarme und begrub den einen echten.
mkdir -p "$T/ruhig/.claude/rules"
printf -- '---\ndescription: x\n---\n# P\n\n`MIND_SYNC_AT_TOKENS` wurde am 17.08.2026 gesetzt.\n' \
  > "$T/ruhig/CLAUDE.md"
printf -- '---\ndescription: y\n---\n# R\n\n`MIND_SYNC_AT_TOKENS` wurde am 19.08.2026 geprueft.\n' \
  > "$T/ruhig/.claude/rules/regler.md"
AUS=$(python "$D" --bereich "$T/ruhig" --nur projekt 2>&1)
pruefe "verschiedene DATEN sind keine Drift" \
       "$(printf '%s' "$AUS" | grep -c '⛔ zahlendrift    0')" "1"

echo
echo "=============================================================================="
echo "  5) ⭐ Zielform wird NICHT als Duplikat gemeldet"
echo "=============================================================================="
# Der haeufigste Fall im echten Bestand: kurze Fassung PLUS Zeiger.
mkdir -p "$T/ziel/.claude/rules"
{ echo '---'; echo 'description: x'; echo '---'; echo '# P'; echo
  echo 'Kurz zu `MIND_BACKUP_KEEP_COUNT`. Volltext: `.claude/rules/lang.md`'; } \
  > "$T/ziel/CLAUDE.md"
{ echo '---'; echo 'description: y'; echo '---'; echo '# R'; echo
  for i in 1 2 3 4 5 6 7 8; do echo "Absatz $i ueber \`MIND_BACKUP_KEEP_COUNT\`."; echo; done; } \
  > "$T/ziel/.claude/rules/lang.md"
AUS=$(python "$D" --bereich "$T/ziel" --nur projekt 2>&1)
pruefe "als zielform eingeordnet" "$(printf '%s' "$AUS" | grep -cE 'zielform +1$')" "1"
pruefe "NICHT als duplikat"       "$(printf '%s' "$AUS" | grep -cE 'duplikat +0$')" "1"

echo
echo "=============================================================================="
echo "  6) ⛔ Ein Urteil auf einem TOTEN Ort ist gegenstandslos — und wird gemeldet"
echo "=============================================================================="
# ⛔ GEMESSEN AM ECHTEN BUCH, 09.09.2026: beide Eintraege zeigten auf Dateien,
#    die es nicht mehr gab (`kontext-und-umgebung.md` geloescht, `knowledge/`
#    nach `docs/plugin/` umbenannt) — 3 von 4 Pfaden tot. `--lesen` zeigte sie
#    unveraendert an, als waeren sie in Kraft. Ein Schutzinstrument, das seinen
#    eigenen Ausfall nicht meldet, ist von einem wirksamen nicht zu
#    unterscheiden.
mkdir -p "$T/tot/.claude-mind" "$T/tot/a"
echo "x" > "$T/tot/a/lebt.md"
# ⛔ WINDOWS-PFADE IN DIE JSON, NICHT MSYS. `python.exe` kann `/tmp/...` nicht
#    aufloesen — dann gelten BEIDE Orte als tot, der Positivfall meldet 2 statt
#    1 und die Negativkontrolle schlaegt nie um. Genau so beim ersten Lauf
#    passiert; die Falle steht in `shell-windows.md`.
TW=$(cygpath -m "$T/tot" 2>/dev/null || echo "$T/tot")
printf '{"ts":"2026-09-09T00:00","werkzeug":"t","orte":["%s/a/lebt.md","%s/a/weg.md"],"schluessel":"k1","urteil":"zielform","entschieden_von":"mensch","grund":"g","hashes":{}}\n' \
  "$TW" "$TW" > "$T/tot/.claude-mind/urteile.jsonl"
AUS6=$(python "$U" "$TW" --lesen 2>&1)
pruefe "toter Ort wird benannt" \
  "$(printf '%s' "$AUS6" | grep -c 'ORT EXISTIERT NICHT MEHR')" "1"
pruefe "   ... und als GEGENSTANDSLOS gezaehlt" \
  "$(printf '%s' "$AUS6" | grep -c 'GEGENSTANDSLOS')" "1"
pruefe "⚠ ohne Loeschauftrag" \
  "$(printf '%s' "$AUS6" | grep -c 'KEIN Auftrag')" "1"

# ⭐ NEGATIVKONTROLLE: leben beide Orte, schweigt es. Ohne diesen Fall waere ein
#   Melder, der IMMER meldet, vom richtigen nicht zu unterscheiden.
echo "y" > "$T/tot/a/weg.md"
AUS7=$(python "$U" "$TW" --lesen 2>&1)
pruefe "⭐ beide Orte da -> kein Befund" \
  "$(printf '%s' "$AUS7" | grep -c 'GEGENSTANDSLOS')" "0"
pruefe "   ... der Eintrag steht trotzdem da" \
  "$(printf '%s' "$AUS7" | grep -c 'zielform')" "1"

echo
echo "=============================================================================="
echo "  7) ⛔ Wort-Marken werden AUSGEWIESEN, nicht gefiltert"
echo "=============================================================================="
# ⛔ GEMESSEN 09.09.2026 im eigenen Bestand: von 186 Duplikat-Paaren hingen 62
#    (33 %) an Marken, die reine Woerter sind — BEIDE, EINEM, JEDER, ZUERST.
# ⚠ NICHT ALLE sind Rauschen: OPEN ist ein Merkername, NEVER ein Haertegrad.
#   Die FORM kann das nicht entscheiden. Deshalb kennzeichnen und zaehlen —
#   wer filtert, macht aus einer pruefbaren Zahl eine Behauptung.
pruefe "reines Wort erkannt" \
  "$(python -c "import sys;sys.path.insert(0,r'$WREF');
import cleaner_duplikate as D;print(int(D._wortmarke('BEIDE')))" 2>&1)" "1"
pruefe "   ... Umlaut zaehlt als Buchstabe" \
  "$(python -c "import sys;sys.path.insert(0,r'$WREF');
import cleaner_duplikate as D;print(int(D._wortmarke('GROESSE')))" 2>&1)" "1"
pruefe "⭐ NEGATIV: Pfad ist keine Wort-Marke" \
  "$(python -c "import sys;sys.path.insert(0,r'$WREF');
import cleaner_duplikate as D;print(int(D._wortmarke('hooks/lib.sh')))" 2>&1)" "0"
pruefe "   ... Slash-Command auch nicht" \
  "$(python -c "import sys;sys.path.insert(0,r'$WREF');
import cleaner_duplikate as D;print(int(D._wortmarke('/mind-all')))" 2>&1)" "0"
pruefe "   ... Regler mit Unterstrich auch nicht" \
  "$(python -c "import sys;sys.path.insert(0,r'$WREF');
import cleaner_duplikate as D;print(int(D._wortmarke('MIND_SYNC_AT_TOKENS')))" 2>&1)" "0"
pruefe "⛔ leere Marke bricht nicht" \
  "$(python -c "import sys;sys.path.insert(0,r'$WREF');
import cleaner_duplikate as D;print(int(D._wortmarke('')))" 2>&1)" "0"

echo
echo "=== $fehler Abweichung(en) ==="
exit $((fehler > 0 ? 1 : 0))
