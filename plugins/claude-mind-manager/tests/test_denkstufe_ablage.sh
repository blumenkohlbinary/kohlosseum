#!/bin/bash
. "$(dirname "$0")/lib_test.sh"
# Pruefstand fuer die Ablage von /mind-denkstufe (v5.142.0, Etappe 52 §1, Teil 1).
#
# ⛔ DIESE SAMMLUNG IST KEIN MANTEL UM DEN SELBSTTEST.
#    Der Selbsttest im Werkzeug prueft seine Gates von INNEN (er kennt die Funktionen).
#    Hier wird von AUSSEN geprueft, was ein Mantel nicht sieht:
#      · faellt der Aufruf ueber die Kommandozeile mit dem richtigen Rueckgabewert aus?
#      · liegt die Ablage wirklich an EINEM Ort fuer alle Projekte - also NICHT im Projekt?
#      · traegt der Regler fuer das Verfallsalter?
#      · ist die Ausgabe ASCII, wie sie sein muss?
#    Ein Prueffall, der nur `--selbsttest` aufruft, misst die Verkettung nicht.

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"
W="$CLAUDE_PLUGIN_ROOT/references/denkstufe_ablage.py"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# --- 0 · VAKUUM-WAECHTER ------------------------------------------------------
pruef "Werkzeug liegt im Paket" "$([ -f "$W" ] && echo ja || echo nein)" "ja"
pruef "Python gefunden"         "$([ -n "$PY" ] && echo ja || echo nein)" "ja"
[ -f "$W" ] && [ -n "$PY" ] || { echo "  Gegenstand fehlt — Abbruch"; exit 1; }

T=$(mktemp -d)
export MIND_DENKSTUFE_DIR="$T/ablage mit leer"     # Leerzeichen: hier heisst ein Ordner so
export MIND_DENKSTUFE_SICHERUNG="$T/sicherung"
mkdir -p "$MIND_DENKSTUFE_SICHERUNG"

# --- 1 · der Selbsttest muss gruen sein (Untergrenze, nicht die Pruefung) ----
"$PY" "$W" --selbsttest >/dev/null 2>&1
pruef "--selbsttest rc 0" "$?" "0"

# --- 2 · die Verkettung: Rueckgabewerte ueber die Kommandozeile ---------------
# ⛔ OHNE Ablage muss --lesen rc 2 geben, nicht rc 0 mit leerer Ausgabe.
"$PY" "$W" --lesen >/dev/null 2>&1
pruef "--lesen ohne Ablage -> rc 2" "$?" "2"
"$PY" "$W" --alter >/dev/null 2>&1
pruef "--alter ohne Ablage -> rc 1 (gilt als abgelaufen)" "$?" "1"

"$PY" "$W" --anlegen >/dev/null 2>&1
pruef "--anlegen rc 0" "$?" "0"
pruef "Datei liegt im Ablage-Ordner" \
  "$([ -f "$MIND_DENKSTUFE_DIR/messwerte.json" ] && echo ja || echo nein)" "ja"
"$PY" "$W" --lesen >/dev/null 2>&1
pruef "--lesen mit Ablage -> rc 0" "$?" "0"
"$PY" "$W" --alter >/dev/null 2>&1
pruef "--alter frisch -> rc 0" "$?" "0"

# --- 3 · EINE Ablage fuer alle Projekte: NICHTS landet im Projekt ------------
# ⛔ Der Auftrag sagt ausdruecklich "EINE Ablage fuer alle Projekte, nicht je Projekt".
#    Das ist pruefbar: nach einem vollen Durchlauf darf unter dem Projekt keine
#    Ablagedatei liegen. Ohne diese Zusicherung waere die Anforderung eine Behauptung.
PROJ_T="$T/projekt"; mkdir -p "$PROJ_T/.claude-mind"
( cd "$PROJ_T" && "$PY" "$W" --lesen >/dev/null 2>&1 )
pruef "kein messwerte.json im Projektordner" \
  "$(find "$PROJ_T" -name 'messwerte.json' | wc -l | tr -d ' ')" "0"
pruef "kein aufgaben/ im Projektordner" \
  "$(find "$PROJ_T" -type d -name 'aufgaben' | wc -l | tr -d ' ')" "0"

# --- 4 · der Regler fuer das Verfallsalter traegt wirklich -------------------
# ⛔ Ein Regler, den niemand gegen BEIDE Richtungen prueft, ist eine Zierde.
"$PY" - "$MIND_DENKSTUFE_DIR/messwerte.json" <<'PYEOF'
import io, json, sys
p = sys.argv[1]
d = json.loads(io.open(p, encoding="utf-8").read())
d["geholt_am"] = "2026-09-25"          # 7 Tage vor dem 02.10.2026
io.open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent=2))
PYEOF
MIND_DENKSTUFE_STALE_DAYS=30 "$PY" "$W" --alter >/dev/null 2>&1
pruef "7 Tage alt, Grenze 30 -> frisch (rc 0)" "$?" "0"
MIND_DENKSTUFE_STALE_DAYS=3 "$PY" "$W" --alter >/dev/null 2>&1
pruef "7 Tage alt, Grenze 3  -> abgelaufen (rc 1)" "$?" "1"
MIND_DENKSTUFE_STALE_DAYS=unsinn "$PY" "$W" --alter >/dev/null 2>&1
pruef "unsinniger Regler faellt auf die Vorgabe 14 zurueck (rc 0)" "$?" "0"

# --- 5 · die Gates von AUSSEN: BELEGT ohne Quelle wird abgewiesen ------------
A="$T/antwort.json"
printf '{"empfehlung":{"modell":"opus","stufe":"high"},"aussagen":[{"text":"x","art":"BELEGT"}]}\n' > "$A"
"$PY" "$W" --schreiben "testaufgabe" --json "$A" >/dev/null 2>&1
pruef "BELEGT ohne Quelle -> rc 2" "$?" "2"
pruef "   ... und es wurde NICHTS angelegt" \
  "$([ -f "$MIND_DENKSTUFE_DIR/aufgaben/testaufgabe.json" ] && echo ja || echo nein)" "nein"

printf '{"empfehlung":{"modell":"opus","stufe":"high"},"aussagen":[{"text":"x","art":"BELEGT","quelle":"https://example.invalid"}]}\n' > "$A"
"$PY" "$W" --schreiben "testaufgabe" --json "$A" >/dev/null 2>&1
pruef "BELEGT MIT Quelle -> rc 0" "$?" "0"
pruef "   ... Antwort liegt da" \
  "$([ -f "$MIND_DENKSTUFE_DIR/aufgaben/testaufgabe.json" ] && echo ja || echo nein)" "ja"
pruef "   ... und eine Kopie in der Sicherung" \
  "$(find "$MIND_DENKSTUFE_SICHERUNG" -name 'testaufgabe.json' | wc -l | tr -d ' ')" "1"

# --- 6 · Kosten: der zweite Aufruf FINDET die Antwort (rc 0) ----------------
# Das ist die Grundlage der Kostenregel aus dem Auftrag — ohne Treffer gaebe es
# keinen Grund, die Gegenprobe beim zweiten Mal auszulassen.
"$PY" "$W" --aufgabe "testaufgabe" >/dev/null 2>&1
pruef "zweiter Aufruf findet die Antwort -> rc 0" "$?" "0"
"$PY" "$W" --aufgabe "andere aufgabe" >/dev/null 2>&1
pruef "fremde Aufgabe -> rc 1 (nicht 0)" "$?" "1"

# --- 7 · die Ausgabe ist ASCII ----------------------------------------------
# ⛔ stdout ist hier cp1252 (shell-windows.md). Ein Sonderzeichen in einer MELDUNG
#    beendet den Lauf mit UnicodeEncodeError — am 01.10.2026 genau so passiert.
"$PY" "$W" --lesen > "$T/ausgabe.txt" 2>&1
# ⛔ BYTEWEISE zaehlen, nicht als Text lesen. Die erste Fassung las die Datei als
#    UTF-8 und starb am Byte 0xa7 (cp1252 fuer das Paragraf-Zeichen): die Messung
#    BRACH AB, statt die Abweichung zu melden. Ein Messgeraet, das am Fund
#    zerbricht, misst nicht — und es war gruen, sobald der Fund weg war.
pruef "--lesen bleibt ASCII (byteweise)" \
  "$("$PY" -c "import sys; b=open(sys.argv[1],chr(114)+chr(98)).read(); print(sum(1 for x in b if x>127))" "$T/ausgabe.txt")" "0"

rm -rf "$T"
echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
