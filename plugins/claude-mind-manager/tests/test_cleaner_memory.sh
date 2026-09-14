#!/usr/bin/env bash
# test_cleaner_memory.sh — v5.107.0 (Etappe 15): Memory ist Bestand im /mind-cleaner,
# zwei Werkzeugfehler aus dem Zustellplan-Lauf, CLAUDE_PLUGIN_ROOT-Rueckfall.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_cleaner_memory.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
REF="$CLAUDE_PLUGIN_ROOT/references"
OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }
PY=python; command -v python >/dev/null 2>&1 || PY=python3
w() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

echo "== 1  cleaner_audit.py kennt --nur memory (Selbsttest traegt die Faelle) =="
janein "--nur memory wird angenommen (kein '--nur braucht')" nein "$($PY "$(w "$REF/cleaner_audit.py")" --bereich "$(w "$(mktemp -d)")" --nur memory 2>&1 | grep -q -- '--nur braucht' && echo ja || echo nein)"
janein "--nur unsinn -> Aufruffehler 2" 2 "$($PY "$(w "$REF/cleaner_audit.py")" --bereich . --nur unsinn >/dev/null 2>&1; echo $?)"
janein "Selbsttest cleaner_audit gruen (Memory-Faelle darin)" 0 "$($PY "$(w "$REF/cleaner_audit.py")" --selbsttest >/dev/null 2>&1; echo $?)"
janein "   ... und nennt die Memory-Faelle" ja "$($PY "$(w "$REF/cleaner_audit.py")" --selbsttest 2>/dev/null | grep -q 'nur die Topic-Datei' && echo ja || echo nein)"

echo "== 2a cleaner_tor.py --memory <projektpfad> zaehlt NICHT die Wurzel-.md =="
# Projekt mit drei .md in der Wurzel und ohne Memory (temporaerer Pfad -> kein Slug-Ordner)
P=$(mktemp -d); printf '# a\n' > "$P/a.md"; printf '# b\n' > "$P/b.md"; printf '# c\n' > "$P/c.md"
A=$($PY "$(w "$REF/cleaner_tor.py")" --memory "$(w "$P")" 2>&1)
janein "Wurzel mit 3 .md, kein Memory -> 0 Topic-Dateien" ja "$(printf '%s\n' "$A" | grep -q '0 Topic-Dateien' && echo ja || echo nein)"
janein "   ... nicht '3 Topic-Dateien'" nein "$(printf '%s\n' "$A" | grep -q '3 Topic-Dateien' && echo ja || echo nein)"
# ein Memory-Verzeichnis direkt geht weiter
mkdir -p "$P/memory"; printf '# MEMORY\n' > "$P/memory/MEMORY.md"; printf -- '---\nname: t\ndescription: eine ausreichend lange Beschreibung fuer den Auswaehler hier\n---\nx\n' > "$P/memory/topic.md"
janein "   Memory-Verzeichnis direkt: 1 Topic-Datei" ja "$($PY "$(w "$REF/cleaner_tor.py")" --memory "$(w "$P/memory")" 2>&1 | grep -q '1 Topic-Dateien' && echo ja || echo nein)"
rm -rf "$P"

echo "== 2b bestandsaufnahme.py stuerzt bei einer Datei im Unterordner nicht mehr ab =="
P=$(mktemp -d); mkdir -p "$P/unter"; printf '# oben\n\nAbsatz.\n' > "$P/oben.md"; printf '# unten\n\nAbsatz.\n' > "$P/unter/tief.md"
A=$($PY "$(w "$REF/bestandsaufnahme.py")" --ordner "$(w "$P")" 2>&1); RC=$?
janein "Rueckgabe 0 (kein KeyError)" 0 "$RC"
janein "   beide Dateien in der Tabelle, die tiefe mit Unterordner" ja "$(printf '%s\n' "$A" | grep -q 'unter/tief.md' && echo ja || echo nein)"
janein "   BESTANDSAUFNAHME (2 Dateien" ja "$(printf '%s\n' "$A" | grep -q 'BESTANDSAUFNAHME  (2 Dateien' && echo ja || echo nein)"
rm -rf "$P"

echo "== 3  CLAUDE_PLUGIN_ROOT-Rueckfall vor jedem Guard =="
G=0; F=0
for s in "$CLAUDE_PLUGIN_ROOT"/skills/*/SKILL.md; do
  G=$((G + $(grep -cE '^[ \t]*(\[ -[nz] "\$CLAUDE_PLUGIN_ROOT" \]|if \[ -z "\$CLAUDE_PLUGIN_ROOT" \])' "$s")))
  F=$((F + $(grep -c 'v5.107.0 Rueckfall' "$s")))
done
janein "jeder Guard hat die Rueckfall-Zeile davor (Guards == Rueckfaelle, > 0)" ja "$([ "$G" -gt 0 ] && [ "$G" -eq "$F" ] && echo ja || echo "nein ($G/$F)")"
# die Zeile selbst, gefahren mit leerer Variable: sie findet das registrierte Paket
Z=$(grep -m1 'v5.107.0 Rueckfall' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" | sed 's/^[ \t]*//; s/[ ]*# v5.107.0 Rueckfall$//')
E=$(env -u CLAUDE_PLUGIN_ROOT bash -c "$Z"'; printf "%s" "$CLAUDE_PLUGIN_ROOT"' 2>/dev/null)
janein "mit leerer Variable: Rueckfall liefert ein Paket mit hooks/lib.sh" ja "$([ -n "$E" ] && [ -f "$E/hooks/lib.sh" ] && echo ja || echo "nein ($E)")"
janein "   ... und meldet WARN auf stderr" ja "$(env -u CLAUDE_PLUGIN_ROOT bash -c "$Z" 2>&1 >/dev/null | grep -q 'WARN: CLAUDE_PLUGIN_ROOT war leer' && echo ja || echo nein)"
janein "   mit gesetzter Variable: unveraendert, kein WARN" nein "$(CLAUDE_PLUGIN_ROOT=/x bash -c "$Z" 2>&1 >/dev/null | grep -q WARN && echo ja || echo nein)"

echo "== 4  Text-Gate mind-cleaner: Memory ist Bestand, Gates davor =="
MC="$CLAUDE_PLUGIN_ROOT/skills/mind-cleaner/SKILL.md"
janein "Step 0 kennt --bereich memory" ja "$(grep -q '^| `memory` |' "$MC" && echo ja || echo nein)"
janein "--audit nennt --nur …|memory" ja "$(grep -q 'global|projekt|alles|memory' "$MC" && echo ja || echo nein)"
janein "Sicherung + memory_gates.py vor dem Anwenden" ja "$(grep -q '_memory"' "$MC" && grep -q 'memory_gates.py "\$B"' "$MC" && echo ja || echo nein)"
janein "nicht autonom bleibt stehen" ja "$(grep -q 'Unverändert nicht autonom' "$MC" && echo ja || echo nein)"

echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
