#!/usr/bin/env bash
# ==========================================================================
# stop.sh — Turn-Ende. ⛔ BLOCKT NIEMANDEN (Nutzer-Entscheidung 08.09.2026).
# ==========================================================================
#
# ⛔ WAS DIESER HOOK NICHT MEHR TUT. Bis v5.54.0 gab er `decision:"block"` aus und
#    erzwang damit einen weiteren Turn — fuer die Sync-Schuld und fuer
#    COMPACT-FAELLIG. Das ist entfallen. Mit ihm entfallen:
#      · die drei Bremsen (stop_hook_active / kein jq / blocks>=MAX)
#      · MIND_STOP_MAX_BLOCKS und MIND_COMPACT_MAX_BLOCKS
#      · MIND_SYNC_FORCE_TOKENS — ohne Blockade kein Zwang
#      · der `blocks=`-Zaehler samt Zurueckschreiben — genau die Stelle, an der
#        v5.7.6 eine echte Endlosschleife hatte
#      · das Rollen-Gate aus v5.54.0, das hier eine Version lang stand
#      · der Modell-Ausnahme-Zweig (MIND_SYNC_AUS_MODELLE) — er nahm vom Zwang
#        aus, den es nicht mehr gibt. ⚠ In `prompt-submit.sh` wirkt er weiter.
#    Sie bremsten etwas, das es nicht mehr gibt.
#
# ⛔ WARUM DAS ROLLEN-GATE HIER WIEDER VERSCHWINDET, eine Version nach seinem
#    Einbau: es unterdrueckte den Zwang fuer Sitzungen, die nicht `sync` sind.
#    Ein Hook, der niemanden mehr zwingt, hat nichts zu unterdruecken. In
#    `prompt-submit.sh` bleibt es — dort gibt es weiter etwas zu sagen.
#
# ⭐ WARUM DER HOOK TROTZDEM BLEIBT: er ruft `kontext-wache.sh`, und die setzt
#    den Merker KONTEXT-GEWACHSEN. Messen muss am Turn-Ende geschehen, melden
#    kann dort nicht — deshalb Merker setzen, beim naechsten Prompt melden.
#
# ⛔ WER MELDET STATTDESSEN: `prompt-submit.sh`. Es liest OPEN und
#    COMPACT-FAELLIG und mahnt beim naechsten Prompt — seit v5.50.0 BEIDE im
#    selben Zweig. Der Umbau brauchte deshalb KEINEN neuen Mechanismus, nur das
#    Entfernen des alten. ⚠ Ohne v5.50.0 waeren die Zusicherungen nicht
#    verschoben, sondern weggefallen: der COMPACT-Zweig stieg vorher vor der
#    Schuld-Meldung aus.
#
# ⛔ WAS DAS KOSTET, ehrlich: `decision:block` war der einzige Mechanismus mit
#    echter Kraft. Ohne ihn haengt der Sync daran, dass jemand die Mahnung liest.
#    Das war der Zustand VOR v5.2.1 und er ist damals gescheitert — 417 KB
#    geretteter Chat (20260816-194132_chat.md) wurden nie eingespeist.
# ⭐ Der Unterschied heute: damals ging die Mahnung an NIEMANDEN. Jetzt gibt es
#    eine Sitzung mit der Rolle `sync`, deren Aufgabe das ist. Der Zwang ist
#    durch eine ZUSTAENDIGKEIT ersetzt — nicht als ueberfluessig erkannt.
#    ⚠ Faellt die Zustaendigkeit aus, faellt der Sync aus. Der Preis ist bekannt.
#
# ⛔ HIER STAND IM ENTWURF: "Die Rolle ist eine ABSPRACHE, kein Mechanismus …
#    wer hier nach dem Schalter sucht: es gibt keinen." Das galt bis zum
#    09.09.2026 und ist seit v5.54.0 UEBERHOLT: die sessionId steht in Spalte 3
#    von `.claude/rules/rollen.md`, und `mind_sync_zustaendig` in `lib.sh` liest
#    sie. Den Schalter gibt es — er sitzt nur nicht in dieser Datei.
set -u

INPUT=$(cat 2>/dev/null)

MIND_LOG_FILE="/tmp/mind-manager.log"
_slog() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1 stop: ${*:2}" >> "$MIND_LOG_FILE" 2>/dev/null; }
_slog DEBUG "aufgerufen"

PROJ="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJ" ] && command -v jq >/dev/null 2>&1; then
  PROJ=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$PROJ" ] && PROJ="$(pwd)"

# --- Kontext-Wache: messen am Turn-Ende, melden beim naechsten Prompt ------
# ⭐ Der einzige Grund, warum dieser Hook noch existiert.
_KW="${CLAUDE_PLUGIN_ROOT:-}/hooks/kontext-wache.sh"
[ -f "$_KW" ] && bash "$_KW" "$PROJ" >/dev/null 2>&1

# ⛔ IMMER 0. Kein Block, kein JSON, keine Ausgabe.
#    Eine Ausgabe waere hier wirkungslos: ohne `decision:block` erreicht der
#    stdout eines Stop-Hooks das Modell nicht. Wer hier etwas ausgibt, baut
#    einen Melder, der niemanden erreicht.
exit 0
