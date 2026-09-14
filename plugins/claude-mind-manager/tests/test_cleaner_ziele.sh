#!/usr/bin/env bash
# test_cleaner_ziele.sh — v5.108.0 (Etappe 16): DOCS und RULE-PATHS als Klassen, --ziel docs,
# ERREICHBARKEIT-Ausnahme, paths-Sonde.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_cleaner_ziele.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
REF="$CLAUDE_PLUGIN_ROOT/references"
OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }
PY=python; command -v python >/dev/null 2>&1 || PY=python3
w() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

echo "== 1  Selbsttests tragen die neuen Faelle =="
for t in cleaner_einordnung cleaner_umzug cleaner_paths_sonde cleaner_audit; do
  janein "$t --selbsttest gruen" 0 "$($PY "$(w "$REF/$t.py")" --selbsttest >/dev/null 2>&1; echo $?)"
done
janein "einordnung: DOCS vor COMMAND im Selbsttest" ja "$($PY "$(w "$REF/cleaner_einordnung.py")" --selbsttest 2>/dev/null | grep -q "DOCS vor COMMAND" && echo ja || echo nein)"
janein "einordnung: RULE-PATHS im Selbsttest" ja "$($PY "$(w "$REF/cleaner_einordnung.py")" --selbsttest 2>/dev/null | grep -q "RULE-PATHS" && echo ja || echo nein)"
janein "umzug: --ziel docs OHNE Zeiger im Selbsttest" ja "$($PY "$(w "$REF/cleaner_umzug.py")" --selbsttest 2>/dev/null | grep -q "docs OHNE Zeiger" && echo ja || echo nein)"
janein "umzug: paths-gebunden im Selbsttest" ja "$($PY "$(w "$REF/cleaner_umzug.py")" --selbsttest 2>/dev/null | grep -q "gebunden an berechnung.py" && echo ja || echo nein)"

echo "== 2  Fixture in der Form von zeitungen-kontext.md -> DOCS + COMMAND =="
P=$(mktemp -d)
printf '# Zeitungen\n\nDas Gebiet hat drei Zeitungen.\n\nDie erste erscheint werktags.\n\nDie zweite am Wochenende.\n\nDie dritte monatlich.\n\nDie Strassen stehen in der Karte.\n' > "$P/zk.md"
A=$($PY "$(w "$REF/cleaner_einordnung.py")" --verzeichnis "$(w "$P")" 2>&1)
janein "Vorschlag DOCS + COMMAND" ja "$(printf '%s\n' "$A" | grep -q 'DOCS + COMMAND' && echo ja || echo nein)"
janein "   Grund der zweiten Klasse steht dabei" ja "$(printf '%s\n' "$A" | grep -q 'auch COMMAND:' && echo ja || echo nein)"
printf -- '---\ndescription: b\n---\n# B\n\n⛔ NIE `rechnen.py` ohne `test_rechnen.py`.\n\n⛔ `export.py` schreibt die Rundung.\n\nMUST `zeitplan.py` datieren.\n' > "$P/br.md"; rm -f "$P/zk.md"
janein "Datei-gebundene Bremse -> RULE-PATHS als zweite Klasse" ja "$($PY "$(w "$REF/cleaner_einordnung.py")" --verzeichnis "$(w "$P")" 2>&1 | grep -q '+ RULE-PATHS' && echo ja || echo nein)"
rm -rf "$P"

echo "== 3  cleaner_umzug --ziel docs auf der Kommandozeile =="
P=$(mktemp -d); mkdir -p "$P/docs"
printf '# Alt\n\nDie Zahl 42 Zeilen gilt.\n\nDer Ort ist `werk.py`.\n\nEine lange Herleitung, die nur erklaert und im Dauerkontext nichts verloren hat, Satz um Satz.\n' > "$P/alt.md"
printf '# Wissen\n\nDie Zahl 42 Zeilen gilt.\n\nDer Ort ist `werk.py`.\n\nEine lange Herleitung, die nur erklaert und im Dauerkontext nichts verloren hat, Satz um Satz.\n' > "$P/docs/wissen.md"
printf -- '---\ndescription: k\n---\n# K\n\nLies zuerst `%s`.\n' "$P/docs/wissen.md" > "$P/kurz_mit.md"
printf -- '---\ndescription: k\n---\n# K\n\nSiehe `%s`.\n' "$P/docs/wissen.md" > "$P/kurz_ohne.md"
janein "--ziel docs mit Zeiger -> 0" 0 "$($PY "$(w "$REF/cleaner_umzug.py")" --alt "$(w "$P/alt.md")" --kurz "$(w "$P/kurz_mit.md")" --skill "$(w "$P/docs/wissen.md")" --ziel docs >/dev/null 2>&1; echo $?)"
janein "--ziel docs ohne Zeiger-Satz -> 1" 1 "$($PY "$(w "$REF/cleaner_umzug.py")" --alt "$(w "$P/alt.md")" --kurz "$(w "$P/kurz_ohne.md")" --skill "$(w "$P/docs/wissen.md")" --ziel docs >/dev/null 2>&1; echo $?)"
janein "   ... und die Ausgabe nennt ZEIGER" ja "$($PY "$(w "$REF/cleaner_umzug.py")" --alt "$(w "$P/alt.md")" --kurz "$(w "$P/kurz_ohne.md")" --skill "$(w "$P/docs/wissen.md")" --ziel docs 2>&1 | grep -q 'ZEIGER' && echo ja || echo nein)"
janein "--ziel unsinn -> Aufruffehler 2" 2 "$($PY "$(w "$REF/cleaner_umzug.py")" --alt "$(w "$P/alt.md")" --kurz "$(w "$P/kurz_mit.md")" --skill "$(w "$P/docs/wissen.md")" --ziel unsinn >/dev/null 2>&1; echo $?)"
rm -rf "$P"

echo "== 4  paths-Sonde: zwei Schritte, nichts stellt sich selbst zurueck =="
P=$(mktemp -d); mkdir -p "$P/proj/.claude/rules" "$P/sich"
printf -- '---\ndescription: r\nglobs: ["tools/x.py"]\n---\n# R\n\n⛔ NIE `x.py` ohne Test.\n' > "$P/proj/.claude/rules/x-regel.md"
A=$(MIND_SONDE_SICHERUNG="$P/sich" CLAUDE_CODE_SESSION_ID=abcdef12-0000 $PY "$(w "$REF/cleaner_paths_sonde.py")" --start "$(w "$P/proj")" 2>&1); RC=$?
janein "--start rc 0" 0 "$RC"
janein "   Merker liegt" ja "$([ -f "$P/proj/.claude-mind/paths-sonde" ] && echo ja || echo nein)"
janein "   Rule traegt paths: statt globs:" ja "$(grep -q '^paths:' "$P/proj/.claude/rules/x-regel.md" && ! grep -q '^globs:' "$P/proj/.claude/rules/x-regel.md" && echo ja || echo nein)"
janein "   Sicherung traegt noch globs:" ja "$(grep -rq '^globs:' "$P/sich" && echo ja || echo nein)"
janein "   Ausgabe sagt: neue Sitzung starten" ja "$(printf '%s\n' "$A" | grep -q 'NEUE Sitzung starten' && echo ja || echo nein)"
L="$P/lade.log"; printf '2099-01-01 00:00:01\tsession_start\t%s\tzzzzzzzz\n' "$P/proj/.claude/rules/x-regel.md" > "$L"
janein "--auswerten: neue Sitzung laedt sie beim Start -> filtert NICHT (rc 1)" 1 "$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P/proj")" --log "$(w "$L")" >/dev/null 2>&1; echo $?)"
printf '2099-01-01 00:00:01\tsession_start\t%s\tzzzzzzzz\n' "$P/proj/.claude/rules/andere.md" > "$L"
janein "--auswerten: neue Sitzung ohne die Rule -> filtert (rc 0)" 0 "$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P/proj")" --log "$(w "$L")" >/dev/null 2>&1; echo $?)"
janein "   Rule steht danach unveraendert auf paths: (kein Selbst-Rueckweg)" ja "$(grep -q '^paths:' "$P/proj/.claude/rules/x-regel.md" && echo ja || echo nein)"
rm -rf "$P"

echo "== 5  Text-Gate mind-cleaner =="
MC="$CLAUDE_PLUGIN_ROOT/skills/mind-cleaner/SKILL.md"
janein "Step 3 nennt DOCS und RULE-PATHS" ja "$(grep -q '\*\*DOCS\*\*' "$MC" && grep -q '\*\*RULE-PATHS\*\*' "$MC" && echo ja || echo nein)"
janein "beide Klassen im Bericht" ja "$(grep -q 'stehen BEIDE im Bericht' "$MC" && echo ja || echo nein)"
janein "--ziel docs mit ZEIGER-Gate" ja "$(grep -q -- '--ziel docs' "$MC" && grep -q 'ZEIGER' "$MC" && echo ja || echo nein)"
janein "ERREICHBARKEIT-Ausnahme paths-gebunden" ja "$(grep -q 'paths-gebunden an' "$MC" && echo ja || echo nein)"
janein "--paths-sonde: zwei Schritte, Mensch startet die Sitzung" ja "$(grep -q 'cleaner_paths_sonde.py" --start' "$MC" && grep -q 'cleaner_paths_sonde.py" --auswerten' "$MC" && grep -q 'die Sitzung startet der Mensch' "$MC" && echo ja || echo nein)"

echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
