#!/usr/bin/env bash
# COMPACT-FAELLIG (v5.7.5) — nach /mind-all ist die Kompaktierung faellig.
#
# Nutzerwunsch 21.08.2026: "er soll nach mind all erst den compact machen damit das andere
# context fenster nicht belastet wird". Bis v5.7.4 endete der Ablauf passiv mit "kommt von
# selbst" — was nur stimmt, wenn der Sync teuer genug ausfaellt.
#
# ⛔ Was hier NICHT geprueft wird, weil es nicht geht: dass tatsaechlich kompaktiert wird.
#    Weder Hook noch Assistent koennen /compact ausloesen. Geprueft wird, dass die Bitte
#    erzwungen wird und dass der Zwang wieder verschwindet.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_compact_faellig.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
H="$CLAUDE_PLUGIN_ROOT/hooks"
OK=0; ROT=0

janein() { # name erwartung(ja|nein) ist(ja|nein)
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; OK=$((OK+1))
  else echo "  [ROT] $1 — erwartet '$2', bekommen '$3'"; ROT=$((ROT+1)); fi
}

neu_projekt() { # -> Pfad
  local d; d=$(mktemp -d); mkdir -p "$d/.claude-mind/rescued"; printf '%s' "$d"
}
marker() { # projekt [blocks]
  printf 'ts=2026-08-21 13:00:00\ntokens=772345\nblocks=%s\n' "${2:-0}" \
    > "$1/.claude-mind/rescued/COMPACT-FAELLIG"
}
stop_lauf() { # projekt [stop_hook_active]
  CLAUDE_PROJECT_DIR="$1" MIND_SYNC_FORCE_TOKENS=0 \
    printf '{"session_id":"s","transcript_path":"","stop_hook_active":%s,"cwd":"%s"}' \
      "${2:-false}" "$1" | CLAUDE_PROJECT_DIR="$1" MIND_SYNC_FORCE_TOKENS=0 bash "$H/stop.sh" 2>/dev/null
}

# ⛔ v5.55.0: stop.sh blockt niemanden mehr. Die Zusicherungen sind deshalb
#    VERSCHOBEN, nicht weggelassen — gemeldet wird jetzt in prompt-submit.sh.
#    Die Regel steht in PLAN-v5.44.0-kein-block.md §3.
prompt_lauf() { # projekt
  printf '{"session_id":"s","transcript_path":"","prompt":"hi","cwd":"%s"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" MIND_SYNC_AT_TOKENS=0 bash "$H/prompt-submit.sh" 2>/dev/null
}

echo "=== COMPACT-FAELLIG ==="

# --- 1 · Merker da -> prompt-submit MELDET, und der Text nennt /compact ---
#     ⛔ v5.55.0: war "stop.sh blockt". Der Block ist entfallen, die AUSSAGE
#        nicht — sie steht jetzt in der Meldung des naechsten Prompts.
P=$(neu_projekt); marker "$P"
O=$(prompt_lauf "$P")
printf '%s' "$O" | grep -q 'Mind Manager' && A=ja || A=nein
janein "Merker vorhanden -> Meldung" ja "$A"
printf '%s' "$O" | grep -q '/compact' && A=ja || A=nein
janein "Meldungstext nennt /compact" ja "$A"
# ⭐ GEGENKONTROLLE zum Umzug: stop.sh schweigt dazu jetzt vollstaendig.
#    Ohne diesen Fall koennte der Block zurueckkommen, ohne dass es auffaellt.
S=$(stop_lauf "$P")
printf '%s' "$S" | grep -q '"decision"' && A=ja || A=nein
janein "⛔ stop.sh blockt NICHT mehr" nein "$A"
# Die Ehrlichkeit MUSS im Text stehen, sonst versucht der Assistent es selbst
# Die AUSSAGE muss stehen, nicht ihr Wortlaut: dass nur der Mensch /compact ausloest.
# Sonst versucht der Assistent es selbst und meldet danach faelschlich Erfolg.
printf '%s' "$O" | grep -qi 'nur der Mensch\|weder ein Hook noch der Assistent\|nicht ausloesbar' && A=ja || A=nein
janein "Meldungstext nennt die Grenze (nur der Mensch loest aus)" ja "$A"
rm -rf "$P"

# --- 2 · ⛔ KEIN Zaehler mehr — die Datei wird nicht mehr umgeschrieben -----
#     Der `blocks=`-Zaehler ist mit dem Block entfallen. Er war genau die
#     Stelle, an der v5.7.6 eine echte Endlosschleife hatte (Zurueckschreiben
#     schlaegt fehl -> Notausgang nie erreicht). Was frueher zugesichert wurde
#     ("der Zaehler kommt an"), wird jetzt in der Umkehrung zugesichert:
#     stop.sh fasst den Merker nicht mehr an.
P=$(neu_projekt); marker "$P"
stop_lauf "$P" >/dev/null
B=$(grep -m1 '^blocks=' "$P/.claude-mind/rescued/COMPACT-FAELLIG" 2>/dev/null | cut -d= -f2-)
janein "⛔ der Zaehler bleibt unveraendert (kein Umschreiben)" 0 "${B:-fehlt}"
grep -q '^tokens=772345' "$P/.claude-mind/rescued/COMPACT-FAELLIG" && A=ja || A=nein
janein "tokens= ist unversehrt" ja "$A"
rm -rf "$P"

# --- 3 · ⛔ KEIN Notausgang mehr — und der Merker BLEIBT liegen -----------
#     Der Notausgang gab es, weil ein Zwang, den der Blockierte nicht aufloesen
#     kann, eine Falle waere. Ohne Zwang gibt es keine Falle. Was an seine
#     Stelle tritt, ist die Umkehrung: stop.sh ENTFERNT den Merker nicht mehr.
#     ⭐ Das ist die wichtigere Zusicherung von beiden. Der alte Notausgang
#        LOESCHTE ihn — die Bitte um /compact verschwand damit nach drei
#        Turns, ohne dass kompaktiert worden waere. Verbraucht wird er allein
#        von pre-compact.sh (Fall 11).
P=$(neu_projekt); marker "$P" 9
O=$(stop_lauf "$P")
printf '%s' "$O" | grep -q '"decision"' && A=ja || A=nein
janein "auch bei blocks=9 kein Block" nein "$A"
[ -f "$P/.claude-mind/rescued/COMPACT-FAELLIG" ] && A=ja || A=nein
janein "⭐ der Merker bleibt liegen (nur pre-compact verbraucht ihn)" ja "$A"
janein "und die Meldung kommt weiter" ja \
       "$(prompt_lauf "$P" | grep -q '/compact' && echo ja || echo nein)"
rm -rf "$P"

# --- 4 · Kein Merker -> kein Block (kein Fehlalarm) ----------------------
P=$(neu_projekt)
O=$(stop_lauf "$P")
printf '%s' "$O" | grep -q 'COMPACT\|/compact' && A=ja || A=nein
janein "ohne Merker kein Kompaktierungs-Zwang" nein "$A"
rm -rf "$P"

# --- 5 · Schleifenschutz geht VOR ---------------------------------------
#     stop_hook_active=true muss auch mit Merker sofort aussteigen, sonst Endlosschleife.
# ⚠ v5.55.0: DIESER FALL MISST SEIT DEM WEGFALL DES BLOCKS NICHTS MEHR —
#   stop.sh gibt in JEDER Lage nichts aus, also auch hier. Er bleibt als
#   Rueckbau-Sperre stehen: kaeme der Block je zurueck, muesste er die
#   Schleifenbremse mitbringen. ⛔ Ein Fall, der nicht mehr unterscheidet,
#   wird BENANNT und nicht stillschweigend als gruen mitgezaehlt.
P=$(neu_projekt); marker "$P"
O=$(stop_lauf "$P" true)
printf '%s' "$O" | grep -q '"decision"' && A=ja || A=nein
janein "stop_hook_active=true schlaegt den Merker" nein "$A"
rm -rf "$P"

# --- 6 · prompt-submit erinnert weiter -----------------------------------
P=$(neu_projekt); marker "$P"
O=$(printf '{"session_id":"s","transcript_path":"","prompt":"hi","cwd":"%s"}' "$P" \
    | CLAUDE_PROJECT_DIR="$P" MIND_SYNC_AT_TOKENS=0 bash "$H/prompt-submit.sh" 2>/dev/null)
printf '%s' "$O" | grep -q '/compact' && A=ja || A=nein
janein "prompt-submit nennt /compact" ja "$A"
rm -rf "$P"

# --- 7 · ohne Merker schweigt prompt-submit dazu -------------------------
P=$(neu_projekt)
O=$(printf '{"session_id":"s","transcript_path":"","prompt":"hi","cwd":"%s"}' "$P" \
    | CLAUDE_PROJECT_DIR="$P" MIND_SYNC_AT_TOKENS=0 bash "$H/prompt-submit.sh" 2>/dev/null)
printf '%s' "$O" | grep -q '/compact' && A=ja || A=nein
janein "ohne Merker schweigt prompt-submit" nein "$A"
rm -rf "$P"

# --- 8 · Merker OHNE blocks=-Zeile -> trotzdem blocken, Zaehler anlegen ---
#     Faellt der Zaehler weg (von Hand editiert, halb geschriebene Datei), darf der
#     Zwang nicht ausfallen — sonst waere Handarbeit ein stiller Notausgang.
P=$(neu_projekt)
printf 'ts=2026-08-21 13:00:00\n' > "$P/.claude-mind/rescued/COMPACT-FAELLIG"
O=$(prompt_lauf "$P")
printf '%s' "$O" | grep -q '/compact' && A=ja || A=nein
janein "Merker ohne blocks= wird trotzdem gemeldet" ja "$A"
# ⛔ v5.55.0: kein Zaehler mehr — die Datei bleibt, wie sie war. Handarbeit
#    darf weder ein stiller Notausgang sein noch eine Datei beschaedigen.
B=$(grep -c '^blocks=' "$P/.claude-mind/rescued/COMPACT-FAELLIG" 2>/dev/null)
janein "und es wird KEIN Zaehler angelegt" 0 "${B:-fehlt}"
rm -rf "$P"

# --- 9 · Pathologisch: Merker ist ein VERZEICHNIS -> nicht abstuerzen ----
#     stop.sh ist der einzige Hook mit Zwangswirkung. Ein Absturz hier ist teurer als
#     ein entfallener Zwang, deshalb muss er fail-open sein.
P=$(neu_projekt); mkdir -p "$P/.claude-mind/rescued/COMPACT-FAELLIG"
O=$(stop_lauf "$P"); R=$?
janein "Verzeichnis statt Datei: sauberer Rueckgabewert" 0 "$R"
rm -rf "$P"

# --- 10 · NEGATIVKONTROLLE, die scheitern KANN ---------------------------
#     Ein Stub, der auf JEDEN Fall blockt, muss an Fall 4 (kein Merker) durchfallen.
#     Damit ist belegt, dass Fall 4 wirklich zwischen "blockt" und "blockt nicht"
#     unterscheidet und nicht bloss immer gruen ist.
stub_blockt_immer() { printf '{"decision":"block","reason":"/compact"}'; }
O=$(stub_blockt_immer)
printf '%s' "$O" | grep -q '"decision"' && A=ja || A=nein
if [ "$A" = "ja" ]; then
  echo "  [ok ] Negativkontrolle: Dauer-Blocker faellt an Fall 4 durch"; OK=$((OK+1))
else
  echo "  [ROT] Negativkontrolle misst nichts — Fall 4 waere immer gruen"; ROT=$((ROT+1))
fi

# --- 11/12 · pre-compact verbraucht den Merker UND protokolliert richtig -------
#     Beim Einbau von v5.7.5 ist die mind_log-Zeile "Sync lief vor dieser Kompaktierung"
#     versehentlich aus dem sync-stand-Block in den COMPACT-FAELLIG-Block gerutscht. Das
#     Verhalten blieb richtig, das Protokoll haette ab dann die falsche Bedingung gemeldet.
#     `bash -n` sieht so etwas nie. Diese zwei Faelle sehen es.
transkript() { # datei
  : > "$1"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf '{"type":"user","message":{"content":[{"type":"text","text":"Frage %s"}]}}\n' "$i" >> "$1"
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"Antwort %s. Entscheidung: Weg A."}],"usage":{"input_tokens":2,"cache_read_input_tokens":1000,"cache_creation_input_tokens":3,"output_tokens":9}}}\n' "$i" >> "$1"
  done
}
precompact() { # projekt logdatei
  printf '{"hook_event_name":"PreCompact","cwd":"%s","session_id":"S1","transcript_path":"%s","trigger":"auto"}' \
    "$1" "$1/t.jsonl" \
    | CLAUDE_PROJECT_DIR="$1" MIND_LOG_FILE="$2" bash "$H/pre-compact.sh" >/dev/null 2>&1
}

P=$(neu_projekt); transkript "$P/t.jsonl"; marker "$P"
LG="$P/log.txt"; : > "$LG"
precompact "$P" "$LG"
[ -f "$P/.claude-mind/rescued/COMPACT-FAELLIG" ] && A=ja || A=nein
janein "pre-compact verbraucht COMPACT-FAELLIG" nein "$A"
rm -rf "$P"

P=$(neu_projekt); transkript "$P/t.jsonl"
# sync-stand da, COMPACT-FAELLIG NICHT — die Protokollzeile muss trotzdem kommen
printf 'ts=2026-08-21 13:00:00\n' > "$P/.claude-mind/rescued/sync-stand"
LG="$P/log.txt"; : > "$LG"
precompact "$P" "$LG"
grep -q 'Sync lief vor dieser Kompaktierung' "$LG" && A=ja || A=nein
janein "Protokollzeile haengt an sync-stand, nicht an COMPACT-FAELLIG" ja "$A"
rm -rf "$P"

# ======================================================================
#  v5.7.6 — die Befunde der adversarischen Pruefung von v5.7.5
# ======================================================================
echo
echo "=== v5.7.6: adversarische Befunde ==="

# --- 13 · Datei enthaelt NUR blocks= -> `grep -v` gibt 1 zurueck ----------
#     In v5.7.5 fiel das Zurueckschreiben damit in den else-Zweig: der Zaehler blieb
#     stehen, der Notausgang wurde NIE erreicht, und jeder Stop-Event blockte erneut mit
#     derselben Nummer. Eine echte Endlosschleife, nur von Hand aufloesbar.
P=$(neu_projekt)
printf 'blocks=0\n' > "$P/.claude-mind/rescued/COMPACT-FAELLIG"
O=$(prompt_lauf "$P")
printf '%s' "$O" | grep -q '/compact' && A=ja || A=nein
janein "nur blocks= in der Datei: wird trotzdem gemeldet" ja "$A"
# ⭐ Die Endlosschleife von v5.7.6 ist mit dem Zaehler ENTFALLEN, nicht
#    behoben. Zugesichert wird deshalb ihre Unmoeglichkeit: derselbe Aufruf
#    zweimal hintereinander veraendert die Datei kein einziges Mal.
S1=$(cat "$P/.claude-mind/rescued/COMPACT-FAELLIG" 2>/dev/null)
stop_lauf "$P" >/dev/null; stop_lauf "$P" >/dev/null
S2=$(cat "$P/.claude-mind/rescued/COMPACT-FAELLIG" 2>/dev/null)
janein "⛔ zwei stop-Laeufe veraendern die Datei nicht" ja \
       "$([ "$S1" = "$S2" ] && echo ja || echo nein)"
rm -rf "$P"

# --- 14 · Zaehler nicht schreibbar -> KEIN Block, Merker weg -------------
#     Grundsatz: wer nicht zaehlen kann, blockt nicht. Ein entfallener Zwang kostet eine
#     Kompaktierung; ein unaufloesbarer kostet die Sitzung.
P=$(neu_projekt); marker "$P"
chmod 500 "$P/.claude-mind/rescued" 2>/dev/null
if ( : > "$P/.claude-mind/rescued/.schreibprobe" ) 2>/dev/null; then
  rm -f "$P/.claude-mind/rescued/.schreibprobe" 2>/dev/null
  echo "  [ -- ] Schreibsperre wirkt auf diesem Dateisystem nicht — Fall UEBERSPRUNGEN"
  echo "         (kein gruenes Ergebnis vortaeuschen: hier wurde nichts gemessen)"
else
  O=$(stop_lauf "$P")
  printf '%s' "$O" | grep -q '"decision"' && A=ja || A=nein
  janein "unschreibbarer Zaehler: KEIN Block" nein "$A"
fi
chmod 700 "$P/.claude-mind/rescued" 2>/dev/null; rm -rf "$P"

# --- 15 · pre-compact raeumt auf, AUCH wenn die Chat-Rettung scheitert ---
#     In v5.7.5 lag die Entfernung im Erfolgspfad der Rettung. Scheiterte sie, blockte
#     stop.sh danach fuer eine Kompaktierung, die bereits gelaufen war.
P=$(neu_projekt); marker "$P"          # KEIN Transkript -> die Rettung kann nicht gelingen
LG="$P/log.txt"; : > "$LG"
printf '{"hook_event_name":"PreCompact","cwd":"%s","session_id":"S1","transcript_path":"%s","trigger":"auto"}' \
  "$P" "$P/gibtesnicht.jsonl" \
  | CLAUDE_PROJECT_DIR="$P" MIND_LOG_FILE="$LG" bash "$H/pre-compact.sh" >/dev/null 2>&1
[ -f "$P/.claude-mind/rescued/COMPACT-FAELLIG" ] && A=ja || A=nein
janein "Merker weg auch OHNE gelungene Chat-Rettung" nein "$A"
rm -rf "$P"

# --- 16 · prompt-submit liefert GUELTIGES JSON ---------------------------
#     Die erste Fassung schrieb Klartext und lief weiter; kam danach die OPEN-Erinnerung
#     als JSON, standen beide im selben stdout — kein gueltiges JSON mehr.
if command -v jq >/dev/null 2>&1; then
  P=$(neu_projekt); marker "$P"
  printf 'path=%s/x_chat.md\nresume=\nevents=1\ncompactions=1\nblocks=0\n' "$P/.claude-mind/rescued" \
    > "$P/.claude-mind/rescued/OPEN"
  : > "$P/.claude-mind/rescued/x_chat.md"; echo "## [x]" >> "$P/.claude-mind/rescued/x_chat.md"
  O=$(printf '{"session_id":"s","transcript_path":"","prompt":"hi","cwd":"%s"}' "$P" \
      | CLAUDE_PROJECT_DIR="$P" MIND_SYNC_AT_TOKENS=0 bash "$H/prompt-submit.sh" 2>/dev/null)
  printf '%s' "$O" | jq -e . >/dev/null 2>&1 && A=ja || A=nein
  janein "Ausgabe ist gueltiges JSON (auch mit OPEN daneben)" ja "$A"
  rm -rf "$P"
else
  echo "  [ -- ] kein jq — JSON-Fall UEBERSPRUNGEN, nichts gemessen"
fi

# --- 17 · Der Token-Zwang-Text sagt NICHT mehr "kommt von selbst" --------
#     stop.sh widersprach sich selbst: der eine Codepfad sagte, nur der Mensch koenne
#     kompaktieren, der andere, es komme von allein.
P=$(neu_projekt)
printf '{"type":"assistant","message":{"role":"assistant","content":"y","usage":{"input_tokens":900000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":5}}}\n' \
  > "$P/t.jsonl"
O=$(printf '{"session_id":"s","transcript_path":"%s","stop_hook_active":false,"cwd":"%s"}' "$P/t.jsonl" "$P" \
    | CLAUDE_PROJECT_DIR="$P" MIND_SYNC_FORCE_TOKENS=770000 bash "$H/stop.sh" 2>/dev/null)
# ⛔ v5.55.0: MIND_SYNC_FORCE_TOKENS IST ENTFALLEN — ohne Blockade kein
#    Zwang. Der Regler wird von keinem Hook mehr gelesen; er hier zu setzen
#    aendert nichts. Die MAHNUNG an der Schwelle MIND_SYNC_AT_TOKENS bleibt und
#    wird in test_teil1.sh §1 zugesichert.
printf '%s' "$O" | grep -q '"decision"' && A=ja || A=nein
janein "⛔ Token-Zwang entfallen: kein Block bei 900k" nein "$A"
printf '%s' "$O" | grep -q 'von selbst' && A=ja || A=nein
janein "und sagt NICHT mehr 'kommt von selbst'" nein "$A"
rm -rf "$P"

echo
echo "=================================="
echo "  $OK bestanden, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
