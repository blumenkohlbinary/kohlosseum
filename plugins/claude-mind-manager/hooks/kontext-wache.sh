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

# ⛔ OHNE Modus: misst und schreibt NICHTS. Siehe Begruendung im Kopf.
AUSGABE=$(mind_kontext_bilanz "$PROJ" 2>/dev/null) || exit 1
JETZT=$(printf '%s\n' "$AUSGABE" | grep -m1 -oE 'ZEILEN=[0-9]+' | cut -d= -f2)
case "$JETZT" in ''|*[!0-9]*) exit 1 ;; esac
JETZT_B=$(printf '%s\n' "$AUSGABE" | grep -m1 -oE 'BYTES=[0-9]+' | cut -d= -f2)
case "${JETZT_B:-}" in ''|*[!0-9]*) JETZT_B=0 ;; esac
[ "$JETZT" -gt 0 ] 2>/dev/null || exit 1

VORHER=""
[ -f "$STAND" ] && VORHER=$(grep -m1 -oE '^ZEILEN=[0-9]+' "$STAND" 2>/dev/null | cut -d= -f2)
case "${VORHER:-}" in ''|*[!0-9]*) VORHER="" ;; esac

_merken() {
  mkdir -p "$(dirname "$STAND")" 2>/dev/null
  printf 'ZEILEN=%s\nts=%s\n' "$JETZT" "$(date +%s)" > "$STAND" 2>/dev/null
}

# ⚠ Erster Lauf: nur merken, nie melden. Ohne Vorstand ist jeder Wert ein
#   "Zuwachs von 0 auf N" — das waere eine Meldung ueber das Anlegen der
#   Merkdatei, nicht ueber Wachstum.
# ── Deckel-Anker ───────────────────────────────────────────────────────
# ⛔ Steht VOR der Schwellenpruefung. Stuende er dahinter, wuerde er bei
#    jedem kleinen Zuwachs uebersprungen — also in genau dem Fall, fuer
#    den er gebaut ist.
SCHULD=0; ANKER=""; ANKER_TS=""
if [ "$JETZT_B" -gt 0 ] 2>/dev/null; then
  [ -f "$DECKEL" ] && {
    ANKER=$(grep -m1 -oE '^BYTES=[0-9]+' "$DECKEL" 2>/dev/null | cut -d= -f2)
    ANKER_TS=$(grep -m1 '^TS=' "$DECKEL" 2>/dev/null | cut -d= -f2-)
  }
  case "${ANKER:-}" in ''|*[!0-9]*) ANKER="" ;; esac
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
    mkdir -p "$(dirname "$DECKEL")" 2>/dev/null
    printf 'BYTES=%s\nTS=%s\n' "$JETZT_B" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > "$DECKEL" 2>/dev/null
    ANKER="$JETZT_B"
  fi
  SCHULD=$(( JETZT_B - ANKER ))
  [ "$SCHULD" -lt 0 ] 2>/dev/null && SCHULD=0
fi

if [ -z "$VORHER" ]; then
  _merken
  exit 1
fi

DELTA=$(( JETZT - VORHER ))
# ⭐ ODER-Bedingung: gemeldet wird bei einem grossen EINZELSCHRITT ODER
#   bei einer grossen STEHENDEN Schuld. Nur die erste zu pruefen war der
#   Defekt — 90 Zeilen in Schritten von je unter 20 sind so nie gemeldet
#   worden, obwohl jede einzelne Messung stimmte.
if [ "$DELTA" -lt "$SCHWELLE" ] 2>/dev/null \
   && [ "$SCHULD" -lt "$DECKEL_SCHWELLE" ] 2>/dev/null; then
  # ⚠ Auch bei SCHRUMPFEN fortschreiben — sonst meldet der naechste Zuwachs
  #   gegen einen veralteten Hochstand und faellt zu klein aus.
  _merken
  exit 1
fi

mkdir -p "$(dirname "$MERKER")" 2>/dev/null
{
  printf 'vorher=%s\n' "$VORHER"
  printf 'jetzt=%s\n'  "$JETZT"
  printf 'delta=%s\n'  "$DELTA"
  printf 'schuld_bytes=%s\n' "$SCHULD"
  # ⭐ Tokens mit dem gegen /context geeichten Faktor 1,917 B/Token
  #   (03.09.2026, 23 von 23 Dateien getroffen). ⛔ NIE mit 4 rechnen —
  #   das ergibt 2,1x zu wenig.
  printf 'schuld_tokens=%s\n' "$(( SCHULD * 1000 / 1917 ))"
  printf 'anker_ts=%s\n' "${ANKER_TS:-unbekannt}"
  printf 'ts=%s\n'     "$(date +%s)"
} > "$MERKER" 2>/dev/null || exit 1
_merken
exit 0
