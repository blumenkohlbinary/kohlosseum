#!/usr/bin/env bash
# Das eigene Transkript — direkt adressiert statt über einen Merker (v5.66.0).
#
# ⛔ WAS DIESE SAMMLUNG WAR (v5.38.0): `.claude-mind/transkript-pfad` ist EINE
#    Datei je PROJEKT und sollte EINE Sitzung kennzeichnen. Jede Sitzung
#    überschrieb ihn bei jedem Prompt — der Letzte gewann. v5.38.0 hat das
#    Rennfenster mit `pfad|sid|ts` und dem Einfrieren in Step 0 verkleinert und
#    den Rest ausdrücklich stehengelassen:
#      „EIN REST BLEIBT und wird nicht weggeredet — auflösen ließe sich das nur
#       mit einer Sitzungskennung im Skill, die es dort nicht gibt."
#
# ⭐ ES GIBT SIE. Gemessen 10.09.2026 in zwei Sitzungen dieses Projekts:
#      CLAUDE_CODE_SESSION_ID  4e6c2f15-…  ->  <slug>/4e6c2f15-….jsonl, 20 MB
#      CLAUDE_CODE_SESSION_ID  62ca5f72-…  ->  Spalte 3 des Rosters, exakt
#    Die Transkriptdatei heißt wie die Kennung. Damit entfällt der Merker samt
#    seinem Rest — die Fehlerklasse verschwindet, nicht nur ihr Fenster.
#
# ⛔ DIE MESSUNG VON v5.30.0 STIMMTE, DER SCHLUSS DARAUS NICHT.
#    `CLAUDE_SESSION_ID` (ohne `CODE_`) ist wirklich leer. Daraus wurde
#    „es gibt keine Kennung", und dieser Satz hat drei Konstruktionen getragen.
#    Der Name lag um ein Wort daneben.
#
# ⛔ WO DIE ALTEN ZUSICHERUNGEN GEBLIEBEN SIND:
#
#    | war (v5.38.0)                    | ist                                  |
#    |----------------------------------|--------------------------------------|
#    | Format `pfad\|sid\|ts` wird gelesen | ⛔ gegenstandslos — Abschnitt 1       |
#    |                                  |   sichert, dass der Merker IGNORIERT  |
#    |                                  |   wird, auch wenn eine Altlast liegt. |
#    | prompt-submit schreibt ihn       | ⛔ umgekehrt — Abschnitt 1.           |
#    | fremder Merker mitten im Lauf    | ⭐ ENTFÄLLT als Gefahr: die Kennung   |
#    |                                  |   ist die eigene, es gibt kein Rennen.|
#    | zweites Argument gewinnt         | ⭐ BLEIBT — Abschnitt 3 (der Hook-Weg).|
#    | die Tokenzahl daran              | ⛔ entfallen mit v5.65.0.             |
#
# ⭐ GEGENPROBE: Abschnitt 1 und 2 sind gegen v5.65.0 ROT.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_transkript_merker.sh
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
GRUEN=0; ROT=0
pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# shellcheck disable=SC1091
. "$R/hooks/lib.sh" 2>/dev/null

# Ein eigenes HOME, damit `$HOME/.claude/projects/<slug>` beherrschbar ist.
H="$TMP/home"; P="$TMP/home/proj"; mkdir -p "$P/.claude-mind"
SLUG=$(HOME="$H" hash_project_dir "$P")
D="$H/.claude/projects/$SLUG"; mkdir -p "$D"

MEINE="1111aaaa-2222-3333-4444-555566667777"
FREMDE="9999ffff-8888-7777-6666-555544443333"
printf '%s\n' '{"cwd":"x"}' > "$D/$MEINE.jsonl"
printf '%s\n' '{"cwd":"x"}' > "$D/$FREMDE.jsonl"
# ⛔ Die FREMDE ist die JÜNGERE — genau die, die `ls -t` und der Merker nähmen.
touch -d '+1 minute' "$D/$FREMDE.jsonl" 2>/dev/null || touch "$D/$FREMDE.jsonl"

ruf() { HOME="$H" CLAUDE_CODE_SESSION_ID="${1-}" mind_transkript_pfad "$P" "${2-}"; }

echo "=== 1) ⛔ Der Merker ist WEG — auch eine Altlast wirkt nicht mehr ==="
# Eine liegengebliebene Datei aus v5.65.0, die auf die FREMDE Sitzung zeigt.
printf '%s|fremd|1' "$D/$FREMDE.jsonl" > "$P/.claude-mind/transkript-pfad"
pruef "⛔ Altlast wird ignoriert, die eigene Kennung gewinnt" \
      "$D/$MEINE.jsonl" "$(ruf "$MEINE")"
# ⛔ GEZÄHLT WIRD DER ZUGRIFF, NICHT DIE NENNUNG. Die erste Fassung zählte
#   `claude-mind/transkript-pfad` schlechthin und wurde rot am eigenen
#   Kommentar, der sagt, dass der Merker ENTFERNT wurde. Ein Kommentar über
#   einen Wegfall ist kein Zugriff. Fünftes Vorkommen dieser Verwechslung in
#   diesem Projekt — sie steht in `env-vars.md` seit 27.08.2026 dokumentiert.
pruef "lib.sh liest den Merker nicht mehr" "0" \
      "$(grep -cE '(cat|-f) "\$proj/\.claude-mind/transkript-pfad"' "$R/hooks/lib.sh")"
pruef "prompt-submit.sh schreibt ihn nicht mehr" "0" \
      "$(grep -c '> "\$PROJ/.claude-mind/transkript-pfad"' "$R/hooks/prompt-submit.sh")"
rm -f "$P/.claude-mind/transkript-pfad"

echo
echo "=== 2) ⭐ Die eigene Kennung trifft die eigene Datei ==="
pruef "meine Kennung -> meine Datei"   "$D/$MEINE.jsonl"  "$(ruf "$MEINE")"
pruef "fremde Kennung -> fremde Datei" "$D/$FREMDE.jsonl" "$(ruf "$FREMDE")"
# ⭐ DIE POSITIVKONTROLLE DIESER SAMMLUNG: die fremde Datei ist die JÜNGERE.
#   Kommt trotzdem meine zurück, ist belegt, dass NICHT nach Änderungszeit
#   gewählt wird — genau der Fehler, gegen den v5.34.0 gebaut wurde.
pruef "⭐ und zwar OBWOHL die fremde jünger ist" "$D/$MEINE.jsonl" "$(ruf "$MEINE")"

echo
echo "=== 3) ⛔ FAIL-SAFE: keine Kennung ist keine erfundene Datei ==="
# ⛔ Antons Auflage (b). Ohne diese drei Fälle wäre die Variable eine stille
#   Abhängigkeit: fehlt sie, dürfte nichts Falsches herauskommen — es muss
#   sich verhalten wie vor v5.66.0.
AUS=$(ruf ""); case "$AUS" in "$D/"*.jsonl) A=heuristik ;; "") A=leer ;; *) A="$AUS" ;; esac
pruef "leere Variable -> Rückfall auf die Heuristik" "heuristik" "$A"
AUS=$(ruf "gibt-es-nicht-0000"); case "$AUS" in "$D/"*.jsonl) A=heuristik ;; "") A=leer ;; *) A="$AUS" ;; esac
pruef "Kennung ohne Datei -> Rückfall, kein erfundener Pfad" "heuristik" "$A"
pruef "⛔ und NIE der Name der fehlenden Datei" "0" \
      "$(printf '%s' "$(ruf 'gibt-es-nicht-0000')" | grep -c 'gibt-es-nicht-0000')"

echo
echo "=== 4) ⭐ Der HOOK-Weg gewinnt weiterhin ==="
# Ein Hook kennt `transcript_path` aus seinem Input — das war immer die
# verlässlichste Quelle und bleibt Vorrang vor allem anderen.
pruef "zweites Argument schlägt die Kennung" \
      "$D/$FREMDE.jsonl" "$(ruf "$MEINE" "$D/$FREMDE.jsonl")"
pruef "ein NICHT existierendes zweites Argument zählt nicht" \
      "$D/$MEINE.jsonl" "$(ruf "$MEINE" "$TMP/gibtsnicht.jsonl")"

echo
echo "=== 5) ⛔ Die Sitzungskennung der Laufsperre kommt aus der Umgebung ==="
SK="$R/skills/mind-all/SKILL.md"
pruef "mind-all nimmt CLAUDE_CODE_SESSION_ID" "1" \
      "$(grep -c 'MIND_SID="\${CLAUDE_CODE_SESSION_ID:-' "$SK")"
pruef "⛔ mit Rückfall, nicht ungeschützt" "1" \
      "$(grep -c 'CLAUDE_CODE_SESSION_ID:-\$(basename' "$SK")"

echo
# ⛔ KEINE BACKTICKS IN EINEM echo. Hier standen sie und bash hat `ls -t`
#    WIRKLICH gefahren — in der Ueberschrift erschienen die Ordnernamen.
echo "=== 6) ⛔ v5.68.0: DIE DREI SKILLS GREIFEN NICHT MEHR NACH ls -t ==="
# ⛔ Der Griff `ls -t "$PROJECTS_DIR"/*.jsonl | head -1` stand ZEICHENGLEICH
#    in drei Skills und nahm die nach AENDERUNGSZEIT juengste Datei — bei
#    mehreren Rollen im Ordner also die Sitzung, die GERADE schreibt.
#    ⚠ Gemessen 10.09.2026: 17 Transkripte, drei Rollen. Die syncende Sitzung
#      schreibt waehrend ihres Laufs am wenigsten und verliert das Rennen fast
#      immer — der Wissens-Sync haette einen FREMDEN Chat analysiert.
# ⭐ Es war ein NACHBAU von `mind_transkript_pfad` (Klasse
#    `instrument-nachgebaut`, 9 Vorkommen). Alle drei sourcen `lib.sh` laengst.
for _sk in mind-update mind-compact mind-session-log; do
  _f="$R/skills/$_sk/SKILL.md"
  pruef "$_sk ruft mind_transkript_pfad" "1" \
        "$(grep -c 'JSONL=$(mind_transkript_pfad' "$_f")"
  # ⚠ GEZAEHLT WIRD DER PRIMAERE GRIFF, NICHT JEDES VORKOMMEN: `ls -t` steht
  #   weiterhin im RUECKFALL, eingerueckt im if-Zweig. Eine Zaehlung ohne
  #   Zeilenanfang haette den Rueckfall als Verstoss gewertet — und der ist
  #   gewollt.
  pruef "   ... und nicht mehr direkt nach ls -t" "0" \
        "$(grep -c '^JSONL=$(ls -t' "$_f")"
done

echo
echo "=== 7) ⭐ DER ECHTE BLOCK, GEFAHREN — nicht nachgebaut ==="
# ⛔ Der Block wird aus der SKILL.md AUSGESCHNITTEN und ausgefuehrt. Ein
#    nachgebauter Block pruefte die eigene Erwartung; dieser bricht, sobald
#    jemand die Datei aendert.
_BLK="$TMP/blk.sh"
# ⛔ BIS ZUM ZWEITEN `fi`. Ein Bereich bis zum ERSTEN endet am if/elif und
#    laesst den Meldungsblock weg — der Prueffall fuehre dann einen Block, den
#    es so nicht gibt, und meldete zu Recht eine fehlende Meldung.
awk '/^# .* v5.68.0: NICHT/{an=1} an{print} an && /^fi$/{n++; if(n==2) exit}' \
  "$R/skills/mind-update/SKILL.md" | sed 's/\r$//' > "$_BLK"
pruef "der Block liess sich ausschneiden" "ja" \
      "$([ -s "$_BLK" ] && echo ja || echo nein)"
bash -n "$_BLK" 2>/dev/null
pruef "   ... und ist syntaktisch sauber" "0" "$?"

# Ein Wegwerf-Projekt mit ZWEI Transkripten; das fremde ist das JUENGERE.
_D="$TMP/skillprobe"; mkdir -p "$_D"
_MEIN="1111aaaa-2222-3333-4444-555566667777"
_FREMD="9999ffff-8888-7777-6666-555544443333"
printf '{}\n' > "$_D/$_MEIN.jsonl"
printf '{}\n' > "$_D/$_FREMD.jsonl"
touch -d '+1 minute' "$_D/$_FREMD.jsonl" 2>/dev/null || touch "$_D/$_FREMD.jsonl"

# ⚠ mind_transkript_pfad baut den Pfad aus $HOME und dem Projekt-Slug. Fuer
#   die Probe wird HOME umgebogen und die eigene Datei dort abgelegt.
_H="$TMP/probehome"; _PJ="$_H/proj"; mkdir -p "$_PJ"
_SL=$(HOME="$_H" hash_project_dir "$_PJ")
mkdir -p "$_H/.claude/projects/$_SL"
cp "$_D/$_MEIN.jsonl"  "$_H/.claude/projects/$_SL/"
cp "$_D/$_FREMD.jsonl" "$_H/.claude/projects/$_SL/"
touch -d '+1 minute' "$_H/.claude/projects/$_SL/$_FREMD.jsonl" 2>/dev/null || true

blk_lauf() {  # $1 = CLAUDE_CODE_SESSION_ID  -> "<quelle>|<basename>|<warnung ja/nein>"
  ( PROJECTS_DIR="$_H/.claude/projects/$_SL"
    export PROJECTS_DIR
    HOME="$_H" CLAUDE_PROJECT_DIR="$_PJ" CLAUDE_CODE_SESSION_ID="${1-}" \
      bash -c ". \"$R/hooks/lib.sh\" 2>/dev/null
                PROJECTS_DIR=\"$PROJECTS_DIR\"
                . \"$_BLK\" >\"$TMP/aus.txt\" 2>&1
                printf '%s|%s' \"\$_JQUELLE\" \"\$(basename \"\$JSONL\")\"" 2>/dev/null
    if grep -q 'RUECKFALL' "$TMP/aus.txt" 2>/dev/null; then printf '|ja'; else printf '|nein'; fi )
}

# ⭐ (c) EXISTIERENDE DATEI: die eigene Kennung greift — obwohl die fremde
#    Datei die JUENGERE ist. Das ist die Positivkontrolle.
_E=$(blk_lauf "$_MEIN")
pruef "⭐ (c) eigene Kennung -> eigene Datei, obwohl die fremde juenger ist" \
      "kennung|$_MEIN.jsonl|nein" "$_E"

# ⛔ (b) LEERE VARIABLE: verhaelt sich wie vor v5.68.0 — Rueckfall auf ls -t.
_L=$(blk_lauf "")
pruef "⛔ (b) leere Kennung -> Rueckfall auf die juengste (wie bisher)" \
      "rueckfall|$_FREMD.jsonl|ja" "$_L"

# ⛔ (d) DER RUECKFALL MELDET SICH. Ein stiller Fehlgriff darf nicht wie ein
#    richtiger Griff aussehen.
pruef "⛔ (d) der Rueckfall sagt es im Bericht" "ja" \
      "$(grep -q 'RUECKFALL gewaehlt' "$TMP/aus.txt" && echo ja || echo nein)"
pruef "   ... und nennt die gewaehlte Datei" "ja" \
      "$(grep -q "$_FREMD" "$TMP/aus.txt" && echo ja || echo nein)"
pruef "   ... und warnt vor der FREMDEN Sitzung" "ja" \
      "$(grep -qi 'FREMDE' "$TMP/aus.txt" && echo ja || echo nein)"
# ⭐ GEGENPROBE zur Meldung: im Kennungs-Fall wird NICHT gewarnt.
blk_lauf "$_MEIN" >/dev/null
pruef "⭐ GEGENPROBE: bei Treffer ueber die Kennung KEINE Warnung" "nein" \
      "$(grep -q 'RUECKFALL gewaehlt' "$TMP/aus.txt" && echo ja || echo nein)"

echo
echo "=== 8) ⛔ v5.69.0: KEIN RUECKFALL AUF EIN FREMDES PROJEKT ==="
# ⛔ Gemessen 10.09.2026: fehlte der Slug-Ordner, schob
#    `[ ! -d "$PROJECTS_DIR" ] && PROJECTS_DIR=$(ls -td .../projects/*/ | head -1)`
#    IRGENDEIN anderes Projekt unter — 25 lagen dort. `mind_transkript_pfad`
#    faengt das NICHT: sie rechnet ihren Slug selbst, kommt leer zurueck, und
#    der Rueckfall aus v5.68.0 las dann aus dem FREMDEN Ordner.
# ⭐ Ein ausgefallener Lauf hinterlaesst nichts, ein falsch gespeister
#    hinterlaesst Falsches. Deshalb Abbruch statt Ersatz.
for _sk in mind-update mind-compact mind-session-log; do
  _f="$R/skills/$_sk/SKILL.md"
  # ⛔ GEZAEHLT WIRD DIE ZUWEISUNG AM ZEILENANFANG, NICHT DIE NENNUNG.
  #   Die erste Fassung zaehlte die Zeichenkette schlechthin und wurde rot
  #   am EIGENEN Kommentar, der zitiert, was entfernt WURDE. Sechstes
  #   Vorkommen dieser Verwechslung in diesem Projekt — sie steht in
  #   `env-vars.md` seit 27.08.2026 dokumentiert und trifft mich weiter.
  pruef "$_sk: kein Rueckfall auf ein fremdes Projekt" "0" \
        "$(grep -cE '^[[:space:]]*PROJECTS_DIR=[$][(]ls -td' "$_f")"
  pruef "   ... sondern Abbruch" "1" \
        "$(grep -c 'ABBRUCH: kein Transkript-Ordner' "$_f")"
  # ⭐ AUFLAGE (a): die Meldung nennt den GRUND, nicht nur den Fehler — sonst
  #    sucht der Leser nach einem kaputten Slug, den es nicht gibt.
  pruef "   ... und nennt den GRUND (nie eine Sitzung)" "1" \
        "$(grep -c 'nie eine Claude-Sitzung' "$_f")"
  # ⚠ Desselben Grundes wegen: die AUSGABEFORM zaehlen, nicht jedes Vorkommen.
  pruef "   ... und schliesst den kaputten Slug AUS" "1" \
        "$(grep -c 'echo .*KEIN kaputter Slug' "$_f")"
done

echo
echo "=== 9) ⭐ (d) NACHGESTELLT: Projekt ohne Slug-Ordner ==="
# ⛔ Der ECHTE Block aus der SKILL.md, ausgeschnitten und gefahren.
_ABB="$TMP/abbruch.sh"
awk '/^# .* v5.69.0: HIER STAND EIN RUECKFALL/{an=1} an{print} an && /^fi$/{exit}' \
  "$R/skills/mind-update/SKILL.md" | sed 's/\r$//' > "$_ABB"
pruef "der Abbruch-Block liess sich ausschneiden" "ja" \
      "$([ -s "$_ABB" ] && echo ja || echo nein)"
bash -n "$_ABB" 2>/dev/null
pruef "   ... und ist syntaktisch sauber" "0" "$?"

_FEHLT="$TMP/gibt-es-nicht/projects/kein-slug"
_AUS=$(PROJECTS_DIR="$_FEHLT" bash "$_ABB" 2>&1); _RC=$?
pruef "⛔ fehlender Ordner -> Rueckgabe 1 (Abbruch)" "1" "$_RC"
pruef "   ... die Meldung nennt den erwarteten Pfad" "ja" \
      "$(printf '%s' "$_AUS" | grep -q 'kein-slug' && echo ja || echo nein)"
pruef "   ... und den Grund" "ja" \
      "$(printf '%s' "$_AUS" | grep -q 'nie eine Claude-Sitzung' && echo ja || echo nein)"
# ⛔ DER FALL, DER ZAEHLT: PROJECTS_DIR darf danach NICHT auf ein fremdes
#    Projekt zeigen. Frueher stand hier der juengste Ordner von 25.
pruef "⛔ KEIN fremdes Projekt in der Ausgabe" "0" \
      "$(printf '%s' "$_AUS" | grep -c 'C--CD-KOHLEKTIV')"

# ⭐ GEGENPROBE: ist der Ordner DA, laeuft der Block durch und sagt nichts.
_DA="$TMP/dabei"; mkdir -p "$_DA"
_AUS2=$(PROJECTS_DIR="$_DA" bash "$_ABB" 2>&1); _RC2=$?
pruef "⭐ GEGENPROBE: Ordner da -> Rueckgabe 0" "0" "$_RC2"
pruef "   ... und keine Meldung" "" "$_AUS2"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
