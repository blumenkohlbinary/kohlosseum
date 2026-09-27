#!/usr/bin/env bash
# Meldet, wenn der IMMER geladene Kontext gewachsen ist — auch bei HANDARBEIT.
#
#   bash kontext-wache.sh <projekt>   ->  0 = gewachsen, Merker geschrieben
#                                         1 = kein nennenswerter Zuwachs
#
# ⛔ WARUM ES DIESE DATEI GIBT — GEMESSEN, NICHT VERMUTET (02.09.2026).
#    Das Kontext-Tor (`cleaner_tor.py`, v5.26.0) greift bei `ADD`/`NEW_FILE`
#    INNERHALB der fuenf Context-Commands. Wer eine Regeldatei von Hand
#    schreibt, laeuft daran vorbei. Ueber die Git-Historie dieses Projekts:
#
#      Commits an CLAUDE.md + .claude/rules/    117 Handarbeit  ·  43 Command
#      hinzugefuegte Zeilen                    1991 Handarbeit  ·  620 Command
#      Anteil der Handarbeit am ZUWACHS                    76 %
#
#    Das ist NICHT "selten genug fuer eine Meldung im naechsten Lauf" — es ist
#    der Normalfall. Drei Viertel des Wachstums sah nie ein Tor.
#
# ⛔ ES SPERRT NICHT, ES MELDET. Handarbeit an Context-Dateien ist legitim; eine
#    Sperre wuerde richtige Arbeit blockieren. Der Zweck des Tors war nie
#    "verhindern", sondern "begruendungspflichtig machen".
#
# ⛔ WARUM EIN EIGENER BEZUGSWERT UND NICHT `--vergleichen`.
#    `mind_kontext_bilanz --vergleichen` SCHREIBT den gemerkten Stand mit fort
#    (lib.sh, Zeile 81: `--merken` ODER `--vergleichen`). Ein Hook, der das je
#    Turn ruft, ueberschreibt den Bezugswert der fuenf Skills — und damit die
#    Wirkungsmessung jedes `/mind-all`- und `/mind-cleaner`-Laufs. Deshalb wird
#    hier OHNE Modus gemessen (schreibt nichts) und gegen eine EIGENE Merkdatei
#    verglichen.
#
# ⛔ ALS SUBPROZESS AUFRUFBAR, nicht ueber `command -v`. `stop.sh` sourct
#    `lib.sh` nur im Token-Zweig, `prompt-submit.sh` gar nicht — beides bewusst.
#    Ein `command -v`-Waechter waere IMMER falsch und wuerde den Ausfall still
#    verschlucken. Genau dieser Fehler war in v5.28.0 lautlos und wurde nur von
#    einer Positivkontrolle gefunden (`plan-pause.sh` sagt es im Kopf).
#
# ⛔ FAIL-SAFE-RICHTUNG: alles Unklare heisst KEIN Zuwachs (Rueckgabe 1). Eine
#    ausbleibende Meldung kostet eine Runde; eine falsche Meldung bei jedem Turn
#    macht den Melder wertlos, und dann schaltet ihn jemand ab.
set -u

PROJ="${1:-}"
[ -n "$PROJ" ] || exit 1
[ -d "$PROJ" ] || exit 1

MERKER="$PROJ/.claude-mind/KONTEXT-GEWACHSEN"
STAND="$PROJ/.claude-mind/kontext-wache"
# ⭐ Der DECKEL-ANKER (v5.47.0). Er wandert NICHT je Turn mit — genau
#   das ist sein Zweck. `STAND` beantwortet "was ist seit dem letzten
#   Turn passiert", `DECKEL` beantwortet "was steht seit dem letzten
#   Ausgleich offen". Ohne den zweiten verschwinden 90 Zeilen in vielen
#   kleinen Schritten, von denen jeder einzelne unter der Schwelle liegt.
DECKEL="$PROJ/.claude-mind/kontext-deckel"

# ⚠ Die Schwelle ist GESETZT, nicht gemessen — wie die Reglern aus v5.5.0.
#   20 Zeilen sind rund eine Bildschirmseite; darunter ist es Rauschen, das die
#   Meldung entwertet. Wer eine andere Zahl will, setzt sie; das Plugin setzt
#   sie NIE selbst (claude-mem #2836).
SCHWELLE="${MIND_KONTEXT_WARN_ZEILEN:-20}"
case "$SCHWELLE" in ''|*[!0-9]*) SCHWELLE=20 ;; esac

# ⚠ GESETZT, nicht gemessen — wie SCHWELLE. 6000 B sind rund 100 Zeilen
#   (gemessen 09.09.2026: 146 353 B auf 2424 Zeilen = 60 B/Zeile) und
#   damit genau die Einheit, in der die Deckelregel formuliert ist:
#   "100 dazu, 100 weg". ⛔ Das Plugin setzt sie NIE selbst.
DECKEL_SCHWELLE="${MIND_DECKEL_WARN_BYTES:-6000}"
case "$DECKEL_SCHWELLE" in ''|*[!0-9]*) DECKEL_SCHWELLE=6000 ;; esac

LIB="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/hooks/lib.sh"
[ -f "$LIB" ] || exit 1
# shellcheck disable=SC1090
. "$LIB" 2>/dev/null || exit 1
command -v mind_kontext_bilanz >/dev/null 2>&1 || exit 1
# v5.82.0: im Unterordner-Aufbau tragen STAND und DECKEL die Kennung des Unterordners —
#   sonst saehe jede der neun Sitzungen den Stand der anderen (hooks.md, DIE KLASSE).
#   In der Wurzel und in jedem Projekt ohne Unterordner: leer, Namen wie bisher.
KENN=""
command -v mind_kontext_kennung >/dev/null 2>&1 && KENN=$(mind_kontext_kennung "$PROJ")
STAND="$STAND$KENN"
DECKEL="$DECKEL$KENN"

# ⛔ OHNE Modus: misst und schreibt NICHTS. Siehe Begruendung im Kopf.
AUSGABE=$(mind_kontext_bilanz "$PROJ" 2>/dev/null) || exit 1
JETZT=$(printf '%s\n' "$AUSGABE" | grep -m1 -oE 'ZEILEN=[0-9]+' | cut -d= -f2)
case "$JETZT" in ''|*[!0-9]*) exit 1 ;; esac
JETZT_B=$(printf '%s\n' "$AUSGABE" | grep -m1 -oE 'BYTES=[0-9]+' | cut -d= -f2)
case "${JETZT_B:-}" in ''|*[!0-9]*) JETZT_B=0 ;; esac
[ "$JETZT" -gt 0 ] 2>/dev/null || exit 1
# ⛔ v5.137.0 (Etappe 48b): die Marke `UNGUELTIG=` sagt, dass mindestens eine gezaehlte
#    Datei nicht lesbar war — dann ist BYTES zu NIEDRIG, und ein Anker darauf waere die
#    Tilgung einer Schuld, die niemand beglichen hat. Gelesen wird die MARKE, nicht der
#    deutsche Satz darunter (Etappe 47 §1).
UNGUELTIG=$(printf '%s\n' "$AUSGABE" | grep -m1 -oE 'UNGUELTIG=[0-9]+' | cut -d= -f2)
case "${UNGUELTIG:-}" in ''|*[!0-9]*) UNGUELTIG=0 ;; esac
JETZT_D=$(printf '%s\n' "$AUSGABE" | grep -m1 -oE 'DATEIEN=[0-9]+' | cut -d= -f2)
case "${JETZT_D:-}" in ''|*[!0-9]*) JETZT_D=0 ;; esac

VORHER=""
[ -f "$STAND" ] && VORHER=$(grep -m1 -oE '^ZEILEN=[0-9]+' "$STAND" 2>/dev/null | cut -d= -f2)
case "${VORHER:-}" in ''|*[!0-9]*) VORHER="" ;; esac
# v5.137.0: der Vorstand traegt jetzt auch DATEIEN und den Verdacht des letzten Laufs.
#   Fehlt eins (Altbestand), verhaelt sich alles wie bisher.
VORHER_D=""
[ -f "$STAND" ] && VORHER_D=$(grep -m1 -oE '^DATEIEN=[0-9]+' "$STAND" 2>/dev/null | cut -d= -f2)
case "${VORHER_D:-}" in ''|*[!0-9]*) VORHER_D="" ;; esac
VERDACHT=""
[ -f "$STAND" ] && VERDACHT=$(grep -m1 -oE '^verdacht=[0-9]+' "$STAND" 2>/dev/null | cut -d= -f2)
case "${VERDACHT:-}" in ''|*[!0-9]*) VERDACHT="" ;; esac

_MERK_VERDACHT=""
_merken() {
  mkdir -p "$(dirname "$STAND")" 2>/dev/null
  printf 'ZEILEN=%s\nDATEIEN=%s\nts=%s\n' "$JETZT" "$JETZT_D" "$(date +%s)" \
    > "$STAND" 2>/dev/null
  [ -n "$_MERK_VERDACHT" ] && printf 'verdacht=%s\n' "$_MERK_VERDACHT" >> "$STAND" 2>/dev/null
  return 0
}

# ⚠ Erster Lauf: nur merken, nie melden. Ohne Vorstand ist jeder Wert ein
#   "Zuwachs von 0 auf N" — das waere eine Meldung ueber das Anlegen der
#   Merkdatei, nicht ueber Wachstum.
# ── Deckel-Anker ───────────────────────────────────────────────────────
# ⛔ Steht VOR der Schwellenpruefung. Stuende er dahinter, wuerde er bei
#    jedem kleinen Zuwachs uebersprungen — also in genau dem Fall, fuer
#    den er gebaut ist.
SCHULD=0; ANKER=""; ANKER_TS=""
_ABLEHN=""   # v5.137.0: Ablehnungsgrund, wandert in den Merker (NICHT auf stdout)
# ⛔ v5.137.0: die Ungueltigkeit wird VOR dem `JETZT_B > 0`-Tor geprueft. Sind ALLE
#    Groessen unlesbar, ist BYTES genau 0 — und dann uebersprang das Tor die Pruefung,
#    also im schlimmsten Fall. Gefunden vom Prueffall, nicht im Betrieb: am 24.09. war
#    nur EINE Datei betroffen, BYTES blieb > 0.
if [ "$UNGUELTIG" -gt 0 ] 2>/dev/null; then
  _ABLEHN="kein Anker angefasst — Bilanz UNGUELTIG ($UNGUELTIG Datei(en) nicht lesbar); BYTES ist zu niedrig, nicht getilgt"
  [ -f "$DECKEL" ] && {
    ANKER=$(grep -m1 -oE '^BYTES=[0-9]+' "$DECKEL" 2>/dev/null | cut -d= -f2)
    ANKER_TS=$(grep -m1 '^TS=' "$DECKEL" 2>/dev/null | cut -d= -f2-)
  }
  case "${ANKER:-}" in ''|*[!0-9]*) ANKER="" ;; esac
elif [ "$JETZT_B" -gt 0 ] 2>/dev/null; then
  [ -f "$DECKEL" ] && {
    ANKER=$(grep -m1 -oE '^BYTES=[0-9]+' "$DECKEL" 2>/dev/null | cut -d= -f2)
    ANKER_TS=$(grep -m1 '^TS=' "$DECKEL" 2>/dev/null | cut -d= -f2-)
  }
  case "${ANKER:-}" in ''|*[!0-9]*) ANKER="" ;; esac
  # ⚠ Ein UNGUELTIG-Zweig stand hier bis zum Bau von Fall 6 — er ist jetzt unerreichbar,
  #   weil die Ungueltigkeit oben am aeusseren Tor abgefangen wird. Toten Code stehen zu
  #   lassen waere die Bauform, die dieses Projekt „sieht repariert aus" nennt.
  if [ -z "$ANKER" ]; then
    # Erster Lauf: Anker setzen, keine Schuld behaupten.
    mkdir -p "$(dirname "$DECKEL")" 2>/dev/null
    printf 'BYTES=%s\nTS=%s\n' "$JETZT_B" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > "$DECKEL" 2>/dev/null
    ANKER="$JETZT_B"
  elif [ "$JETZT_B" -lt "$ANKER" ] 2>/dev/null; then
    # ⛔ RATSCHE NACH UNTEN: getilgt ist getilgt, aber es gibt kein
    #    Guthaben. Ohne das liesse sich erst kuerzen und danach unbemerkt
    #    wieder auffuellen.
    # ⛔ v5.137.0 (Etappe 48b): ein Rueckgang wird nur noch uebernommen, wenn er
    #    PLAUSIBEL ist. Hier wurde bis 5.136.0 JEDER niedrigere Wert dauerhaft
    #    festgeschrieben — am 24.09.2026 ein Aussetzer von einem Turn, 8 067 B.
    _ABLEHNUNG=""
    if [ -n "$VORHER_D" ] && [ "$JETZT_D" -lt "$VORHER_D" ] 2>/dev/null; then
      # ⭐ Transient gegen dauerhaft, entschieden durch WIEDERHOLUNG statt durch eine
      #   geratene Schwelle: erst wenn derselbe niedrigere Stand zweimal in Folge kommt,
      #   ist es eine echte Loeschung und keine Datei, die im Messmoment fehlte.
      if [ "$VERDACHT" = "$JETZT_D" ]; then
        :   # zweites Mal derselbe Stand -> echte Loeschung, Ratsche darf greifen
      else
        _ABLEHNUNG="DATEIEN $VORHER_D -> $JETZT_D beim ersten Mal — eine im Messmoment fehlende Datei sieht genauso aus wie eine geloeschte"
        _MERK_VERDACHT="$JETZT_D"
      fi
    fi
    if [ -n "$_ABLEHNUNG" ]; then
      # ⛔ Abgelehnt heisst GEMELDET, nicht verschwiegen — ein stiller Verwurf waere
      #    derselbe Fehler in der anderen Richtung.
      _ABLEHN="Anker NICHT gesenkt ($ANKER -> $JETZT_B abgelehnt): $_ABLEHNUNG"
    else
      mkdir -p "$(dirname "$DECKEL")" 2>/dev/null
      printf 'BYTES=%s\nTS=%s\n' "$JETZT_B" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        > "$DECKEL" 2>/dev/null
      ANKER="$JETZT_B"
    fi
  fi
  SCHULD=$(( JETZT_B - ANKER ))
  [ "$SCHULD" -lt 0 ] 2>/dev/null && SCHULD=0
fi

# ⛔ v5.137.0: der fruehe Abbruch gilt nur, wenn NICHTS abgelehnt wurde. „Erster Lauf,
#    nur merken" ist fuer Wachstum richtig (ein Zuwachs von 0 auf N waere eine Meldung
#    ueber das Anlegen der Merkdatei) — fuer eine Ablehnung ist er falsch: dass kein Anker
#    gesetzt wurde, ist genau dann zu melden, wenn noch keiner existiert.
if [ -z "$VORHER" ]; then
  if [ -z "$_ABLEHN" ]; then
    _merken
    exit 1
  fi
  DELTA=""   # ohne Vorstand ist kein Vergleich moeglich — die Ablehnung traegt die Meldung
else
  DELTA=$(( JETZT - VORHER ))
fi
# ⭐ ODER-Bedingung: gemeldet wird bei einem grossen EINZELSCHRITT ODER
#   bei einer grossen STEHENDEN Schuld. Nur die erste zu pruefen war der
#   Defekt — 90 Zeilen in Schritten von je unter 20 sind so nie gemeldet
#   worden, obwohl jede einzelne Messung stimmte.
# ⛔ v5.137.0: eine ABLEHNUNG muss den Merker erzwingen. Ohne die dritte Bedingung
#    faellt sie still aus, sobald Delta und Schuld unter ihren Schwellen liegen — und
#    eine still ausgefallene Meldung ueber einen stillen Ausfall ist der Fehler selbst.
if [ -n "$DELTA" ] && [ "$DELTA" -lt "$SCHWELLE" ] 2>/dev/null \
   && [ "$SCHULD" -lt "$DECKEL_SCHWELLE" ] 2>/dev/null \
   && [ -z "$_ABLEHN" ]; then
  # ⚠ Auch bei SCHRUMPFEN fortschreiben — sonst meldet der naechste Zuwachs
  #   gegen einen veralteten Hochstand und faellt zu klein aus.
  _merken
  exit 1
fi

mkdir -p "$(dirname "$MERKER")" 2>/dev/null
{
  [ -n "$VORHER" ] && printf 'vorher=%s\n' "$VORHER"
  printf 'jetzt=%s\n'  "$JETZT"
  [ -n "$DELTA" ] && printf 'delta=%s\n' "$DELTA"
  printf 'schuld_bytes=%s\n' "$SCHULD"
  # ⛔ v5.65.0: HIER STAND `schuld_tokens=`, die Umrechnung mit dem Faktor
  #    1,917 B/Token. Sie ist weg, die BYTE-Messung bleibt. Grund: eine
  #    geschaetzte Zahl neben einer gemessenen macht die gemessene
  #    unglaubwuerdig — und dieser Hook misst wirklich, er schaetzt nicht.
  #    ⚠ Der Eich-Faktor selbst steht weiter in `werkzeuge-zuerst.md`, als
  #      Umrechnung fuer einen Menschen. ⛔ NIE mit 4 rechnen.
  printf 'anker_ts=%s\n' "${ANKER_TS:-unbekannt}"
  [ -n "$_ABLEHN" ] && printf 'anker_abgelehnt=%s\n' "$_ABLEHN"
  printf 'ts=%s\n'     "$(date +%s)"
} > "$MERKER" 2>/dev/null || exit 1
_merken
exit 0
