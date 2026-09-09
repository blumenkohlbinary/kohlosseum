#!/usr/bin/env bash
# rollen_geruest.py — der AUFRUF-Vertrag, nicht die Logik.
#
# ⭐ Die Logik prueft `--selbsttest` (24 Faelle, mit Positiv- UND
#   Negativkontrolle). Diese Sammlung prueft, was er NICHT sieht: die
#   Rueckgabewerte, das Verhalten ohne Argumente und ohne Umgebung.
#
# ⛔ WARUM DAS EINE EIGENE SAMMLUNG BRAUCHT: v5.35.0 hatte 24 gruene Faelle,
#   und der EINZIGE Pfad mit echter Aussenwirkung war ungetestet — der erste
#   echte Einsatz starb an einem lokalen Import. Ein Selbsttest, der die
#   Funktionen direkt ruft, laesst `main()` unberuehrt.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
S="$R/references/rollen_geruest.py"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }
hat() { case "$3" in *"$2"*) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";;
  *) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' fehlt";; esac; }

echo "=== 0) Die Datei ist ueberhaupt ausgeliefert ==="
pruef "rollen_geruest.py liegt im Paket" "ja" "$([ -f "$S" ] && echo ja || echo nein)"
[ -f "$S" ] || { echo "  ABBRUCH"; exit 1; }

echo
echo "=== 1) Der Selbsttest laeuft im gebauten Paket durch ==="
OUT=$(CLAUDE_PLUGIN_ROOT="$R" python "$S" --selbsttest 2>&1); RC=$?
pruef "Rueckgabe 0" 0 "$RC"
hat "  ... und sagt es auch" "alle Selbsttests bestanden" "$OUT"
hat "  ... Positivkontrolle ist dabei" "POSITIVKONTROLLE" "$OUT"
hat "  ... Negativkontrolle auch" "NEGATIVKONTROLLE" "$OUT"

echo
echo "=== 2) ⛔ Rueckgabewerte — 2 heisst AUFRUFFEHLER, nicht 'sauber' ==="
python "$S" >/dev/null 2>&1; pruef "ohne Argument -> 2" 2 "$?"
python "$S" --pruefe >/dev/null 2>&1; pruef "--pruefe ohne Datei -> 2" 2 "$?"
python "$S" --pruefe "$TMP/gibtesnicht.md" >/dev/null 2>&1
pruef "--pruefe auf fehlende Datei -> 2" 2 "$?"
python "$S" --projekt >/dev/null 2>&1; pruef "--projekt ohne Verzeichnis -> 2" 2 "$?"

echo
echo "=== 3) --projekt erzeugt ein Geruest, das --pruefe besteht ==="
mkdir -p "$TMP/proj/src" "$TMP/proj/docs" "$TMP/proj/.git"
CLAUDE_PLUGIN_ROOT="$R" python "$S" --projekt "$TMP/proj" > "$TMP/rollen.md" 2>/dev/null
pruef "Erzeugung -> 0" 0 "$?"
pruef "Datei ist nicht leer" "ja" "$([ -s "$TMP/rollen.md" ] && echo ja || echo nein)"
G=$(cat "$TMP/rollen.md")
hat "der tatsaechliche Ordner steht drin" '`src/**`' "$G"
hat "  ... der zweite auch" '`docs/**`' "$G"
python "$S" --pruefe "$TMP/rollen.md" >/dev/null 2>&1
pruef "eigenes Erzeugnis besteht die Pruefung -> 0" 0 "$?"

echo
echo "=== 4) ⛔ Ausfuellfehler 1: kein Pfad, den es nicht gibt ==="
case "$G" in *'`.git/**`'*) ROT=$((ROT+1)); echo "  [ROT] .git steht in der Tabelle";;
  *) GRUEN=$((GRUEN+1)); echo "  [ok ] .git steht NICHT in der Tabelle";; esac
case "$G" in *'`knowledge/**`'*) ROT=$((ROT+1)); echo "  [ROT] erfundener Ordner drin";;
  *) GRUEN=$((GRUEN+1)); echo "  [ok ] kein erfundener Ordner";; esac

echo
echo "=== 5) ⛔ Leere Namen bleiben leer ==="
hat "Platzhalter statt erfundener Name" "<Name>" "$G"

echo
echo "=== 6) ⛔ Eine echte Umbenennung wird gemeldet, rc=1 ==="
sed 's/^## ⛔ Offene Deckel-Schuld/## Deckel-Schuld/' "$TMP/rollen.md" > "$TMP/kaputt.md"
OUT2=$(python "$S" --pruefe "$TMP/kaputt.md" 2>&1); RC2=$?
pruef "Rueckgabe 1 bei Befund" 1 "$RC2"
hat "  ... und nennt den Verdacht" "umbenannt" "$OUT2"

echo
echo "=== 7) ⭐ ERGAENZEN bleibt still (rc 0) ==="
printf '\n## Etwas Projekteigenes\n\ntext\n' >> "$TMP/rollen.md"
OUT3=$(python "$S" --pruefe "$TMP/rollen.md" 2>&1); RC3=$?
pruef "zusaetzlicher Abschnitt -> 0" 0 "$RC3"
hat "  ... und wird als erlaubt gemeldet" "projekteigener Abschnitt" "$OUT3"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
