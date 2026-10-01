#!/bin/bash
. "$(dirname "$0")/lib_test.sh"
# Pruefstand fuer die Denkstufe der beiden Agenten (v5.141.0, Etappe 52 §0a).
#
# ⛔ WARUM ES DIESE SAMMLUNG BRAUCHT — gemessen am laufenden Programm (2.1.284), nicht
#    aus der Doku: der Lader fuer Plugin-Agenten prueft `effort` und schreibt bei einem
#    falschen Wert nur eine LOGZEILE
#      "Plugin agent file … has invalid effort '…'. Valid options: … or an integer"
#    — der Agent laeuft trotzdem, dann eben auf der Sitzungsstufe. Ein Tippfehler
#    (`mediun`) ist damit UNSICHTBAR: der Agent arbeitet, nur nicht auf der Stufe, die
#    im Frontmatter steht. Genau die Klasse, gegen die dieses Projekt gebaut ist —
#    ein Feld, das dasteht und nichts tut.
#
# ⚠ DIESE SAMMLUNG LEGT DIE STUFE NICHT FEST. Sie prueft, dass eine GUELTIGE dasteht.
#   Welche es ist, entscheidet der Mensch bzw. der manager; ein Wertwechsel darf keinen
#   Prueffall rot machen, sonst wird der Prueffall beim naechsten Wechsel gestrichen.
#
# ⚠ Die Liste der gueltigen Werte ist am Programm GEMESSEN (01.10.2026, 2.1.284:
#   30 Vorkommen von ["low","medium","high","xhigh","max"]). Kommt eine Stufe dazu,
#   geht diese Sammlung ROT statt still falsch zu werden — die richtige Richtung.

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"

ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# Der Pruefer selbst — EINE Stelle, von den Faellen UND von der Gegenprobe benutzt.
stufe_gueltig() {
  case "$1" in
    low|medium|high|xhigh|max) return 0 ;;
    ''|*[!0-9]*)               return 1 ;;   # leer oder nicht nur Ziffern
    *)                         return 0 ;;   # eine ganze Zahl ist erlaubt
  esac
}

# Stufe aus dem Frontmatter lesen: nur aus dem Block zwischen den ersten zwei `---`.
# ⛔ Hier stand ein `sed`-Ausdruck, der den RUMPF mitgelesen hat — gefunden von Fall 0b
#    im ersten Lauf (erwartet `max` aus dem Frontmatter, bekommen `low` aus dem Rumpf).
#    Mit nur den Agenten-Dateien als Faellen waere er nie aufgefallen: dort steht `effort`
#    ohnehin nur oben. Ein Prueffall, der das Werkzeug der Pruefung prueft, ist kein Luxus.
stufe_aus() {
  awk 'NR==1 && /^---[[:space:]]*$/ {drin=1; next}
       drin && /^---[[:space:]]*$/   {exit}
       drin                          {print}' "$1" 2>/dev/null \
    | tr -d '\r' | sed -n 's/^effort:[[:space:]]*//p' | sed -n '1p'
}

# --- 0 · GEGENPROBE ZUERST: kann der Pruefer ueberhaupt scheitern? ------------
# ⛔ Ohne diese vier Zeilen waere jede gruene Meldung unten wertlos — ein Pruefer, der
#    alles durchlaesst, meldet auch einen Tippfehler als gueltig.
pruef "Pruefer nimmt 'medium'"  "$(stufe_gueltig medium  && echo ja || echo nein)" "ja"
pruef "Pruefer nimmt 'xhigh'"   "$(stufe_gueltig xhigh   && echo ja || echo nein)" "ja"
pruef "Pruefer nimmt eine Zahl" "$(stufe_gueltig 20000   && echo ja || echo nein)" "ja"
pruef "Pruefer LEHNT 'mediun' ab"  "$(stufe_gueltig mediun && echo ja || echo nein)" "nein"
pruef "Pruefer LEHNT 'hoch' ab"    "$(stufe_gueltig hoch   && echo ja || echo nein)" "nein"
pruef "Pruefer LEHNT Leeres ab"    "$(stufe_gueltig ''     && echo ja || echo nein)" "nein"

# --- 0b · und liest der Leser aus dem FRONTMATTER, nicht aus dem Rumpf? ------
T=$(mktemp -d)
printf -- '---\nname: x\neffort: max\n---\n\nIm Rumpf steht:\neffort: low\n' > "$T/a.md"
pruef "liest aus dem Frontmatter, nicht aus dem Rumpf" "$(stufe_aus "$T/a.md")" "max"
printf -- '---\nname: x\nmodel: sonnet\n---\n\ntext\n' > "$T/b.md"
pruef "ohne Feld: leer (kein geratener Wert)" "$(stufe_aus "$T/b.md")" ""
rm -rf "$T"

# --- 1 · die beiden ausgelieferten Agenten -----------------------------------
for A in context-analyzer project-scanner; do
  F="$CLAUDE_PLUGIN_ROOT/agents/$A.md"
  # VAKUUM-WAECHTER: erst die Existenz, dann der Inhalt. Eine Aussage ueber eine
  # Datei, die es nicht gibt, ist gruen aus dem falschen Grund.
  pruef "$A: Datei da" "$([ -f "$F" ] && echo ja || echo nein)" "ja"
  [ -f "$F" ] || continue
  S=$(stufe_aus "$F")
  pruef "$A: traegt eine Stufe"        "$([ -n "$S" ] && echo ja || echo nein)" "ja"
  pruef "$A: die Stufe ist gueltig ($S)" "$(stufe_gueltig "$S" && echo ja || echo nein)" "ja"
  pruef "$A: genau EINE effort-Zeile im Frontmatter" \
    "$(stufe_aus "$F" | grep -c .)" "1"
  # ⛔ Mehrfachstempel-Lehre aus 5.139.0: eine zweite Zuweisung irgendwo in der Datei
  #    faellt nicht auf, weil der Leser die erste nimmt. Also die GANZE Datei zaehlen.
  pruef "$A: kein zweites effort: in der ganzen Datei" \
    "$(grep -c '^effort:' "$F")" "1"
done

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
