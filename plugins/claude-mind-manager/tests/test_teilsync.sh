#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# TEILSYNC (v5.19.0) — ein abgekuerzter Lauf muss eine Schuld hinterlassen.
#
# ANLASS, dreimal gemessen und in Debug/BEFUNDE.md protokolliert:
#   23.08. 22:21  Claude Mind Manager  Knowledge-Sync-Agents NICHT dispatcht (Kontext)
#   24.08. 23:08  Claude Mind Manager  Knowledge-Sync-Agents NICHT dispatcht (914k)
#   24.08. 23:18  Creator              nur 2 von 4 gefahren (888k)
# Alle drei setzten `sync-stand`, alle drei erzeugten KEINE Schuld, und in allen drei
# Faellen verschwand der ungepruefte Bereich spurlos.
#
# ⛔ Was hier NICHT geprueft wird, weil es nicht geht: dass die Agents wirklich laufen.
#    Geprueft wird, dass ein UNVOLLSTAENDIGER Lauf als solcher erkannt wird und dass die
#    Schuld daraus entsteht.
#
# ⭐ Der wichtigste Fall ist 18: `mind_agent_bilanz` gibt bei "2 dispatcht, beide mit
#    Ergebnis" die Rueckgabe 0 zurueck — "alles gut". Ein NIE dispatchter Agent
#    hinterlaesst keine Zeile und ist unsichtbar. Wer sich auf den Rueckgabewert
#    verlaesst, winkt genau den Creator-Fall durch. Deshalb entscheidet die ZAHL.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_teilsync.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
H="$CLAUDE_PLUGIN_ROOT/hooks"
# shellcheck disable=SC1090
source "$H/lib.sh" 2>/dev/null || { echo "lib.sh nicht ladbar" >&2; exit 2; }

# ⛔ v5.97.0 — DIE QUITTUNG LAESST SICH NICHT MEHR TIPPEN: die Zahlform schreibt bytes:0,
#    und dispatch->ergebnis unter 30 s gilt als nachgetragen. Die Fixture liefert deshalb,
#    was ein echter Lauf liefert: einen Dispatch von vor 120 s und eine DATEI mit n Bytes.
#    Die Zusicherungen darunter sind woertlich die von vor v5.97.0.
_disp() { local q="$2/.claude-mind/agent-quittung.jsonl"; mkdir -p "$2/.claude-mind"
  printf '{"ereignis":"dispatch","bereich":"%s","ts":"%s"}\n' "$1" "$(date -u -d '-120 seconds' +%Y-%m-%dT%H:%M:%SZ)" >> "$q"; }
_erg()  { local f="$3/.claude-mind/agent-$1.md"; mkdir -p "$3/.claude-mind"
  head -c "$2" /dev/zero | tr '\0' x > "$f"; mind_agent_ergebnis "$1" --datei "$f" "$3" 2>/dev/null; }
OK=0; ROT=0

janein() { # name erwartung ist
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; OK=$((OK+1))
  else echo "  [ROT] $1 — erwartet '$2', bekommen '$3'"; ROT=$((ROT+1)); fi
}

neu_projekt() { local d; d=$(mktemp -d); mkdir -p "$d/.claude-mind/rescued"; printf '%s' "$d"; }

# Ein fehlender Befehl (127) darf NICHT als "teil" durchgehen — sonst waere die
# Sammlung auf dem unreparierten Stand teilweise gruen, ohne etwas zu messen.
voll_p() { # datei -> voll|teil|rc<N>
  local rc
  mind_sync_voll "$1" >/dev/null 2>&1; rc=$?
  case $rc in 0) echo voll;; 1) echo teil;; *) echo "rc$rc";; esac
}
frisch_p() { # stand jetzt -> frisch|verbraucht|rc<N>
  local rc
  mind_sync_frisch "$1" "$2" >/dev/null 2>&1; rc=$?
  case $rc in 0) echo frisch;; 1) echo verbraucht;; *) echo "rc$rc";; esac
}
stand() { # projekt umfangzeile-oder-leer [ungepruef]
  { printf 'ts=2026-08-24 23:10:19\ntokens=100000\n'
    [ -n "${2:-}" ] && printf 'umfang=%s\n' "$2"
    [ -n "${3:-}" ] && printf 'ungepruef=%s\n' "$3"
  } > "$1/.claude-mind/rescued/sync-stand"
}

transkript() { # datei
  : > "$1"; local i
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

echo "=== TEILSYNC ==="
echo "--- A · mind_sync_voll: was ist ein vollstaendiger Merker? ---"

# --- 1 · 4 von 4 Agents -> vollstaendig -----------------------------------
P=$(neu_projekt); stand "$P" "5/5 skills 4/4 agents"
janein "4/4 Agents -> vollstaendig" voll "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# --- 2 · 0 von 4 -> Teilsync (mein Lauf, 24.08. 23:08) --------------------
P=$(neu_projekt); stand "$P" "5/5 skills 0/4 agents"
janein "0/4 Agents -> Teilsync" teil "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# --- 3 · 2 von 4 -> Teilsync (der Creator-Lauf, 24.08. 23:18) -------------
P=$(neu_projekt); stand "$P" "5/5 skills 2/4 agents"
janein "2/4 Agents -> Teilsync (Creator-Fall)" teil "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# --- 4 · auch ein unvollstaendiger SKILL-Teil zaehlt ----------------------
P=$(neu_projekt); stand "$P" "3/5 skills 4/4 agents"
janein "3/5 Skills -> Teilsync" teil "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# ===== GEGENKONTROLLEN — ohne sie waere die Sammlung eine Einbahnstrasse =====

# --- 5 · Altbestand ohne umfang= gilt als VOLL ----------------------------
#     Jeder Merker aus v5.18.0 und aelter hat kein umfang=. Wer den als Teilsync
#     wertet, nagelt jede laufende Sitzung fest, die noch einen alten Merker hat.
P=$(neu_projekt); stand "$P" ""
janein "Altbestand ohne umfang= -> vollstaendig" voll "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# --- 6 · unparsbares umfang= gilt als VOLL (nagelt nicht fest) ------------
P=$(neu_projekt); stand "$P" "kaputt"
janein "umfang=kaputt -> vollstaendig (fail-safe)" voll "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# --- 6b · v5.105.0 (Etappe 13 b): ein annotierter Bruch ist TEILSYNC, nie unsichtbar
#     Noras Merker (Palvedo, 13.09.2026), woertlich. Bis v5.104.0 fiel
#     `3/4-echt-1-strukturell-leer` am `*[!0-9/]*`-continue vorbei; Teilsync kam
#     nur aus `3/5 bestand`. Mit 5/5 bestand haette der getippte 3/4 als voll gegolten.
P=$(neu_projekt); stand "$P" "5/5 skills 3/4-echt-1-strukturell-leer agents 3/5 bestand 0/N abdeckung 5/5 echt"
janein "Noras Merker woertlich -> Teilsync" teil "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
stand "$P" "5/5 skills 3/4-echt-1-strukturell-leer agents 5/5 bestand 5/5 abdeckung 5/5 echt"
janein "⛔ derselbe annotierte 3/4 bei sonst 5/5 -> Teilsync (war unsichtbar = voll)" teil "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
stand "$P" "5/5 skills 4/4 agents 5/5 bestand 0/N abdeckung 5/5 echt"
janein "⛔ 0/N (Buchstabe im Nenner) -> Teilsync" teil "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
stand "$P" "5/5 skills 4/4 agents 5/5 bestand 5/5 abdeckung 5/5 echt"
janein "   Gegenprobe: reine Zahlen, alles voll -> voll" voll "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
janein "   Gegenprobe: umfang=kaputt (Wort ohne /) bleibt fail-safe voll" voll "$(stand "$P" "kaputt"; voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

# --- 6c · v5.105.0 (Etappe 13 a): umfang= wird GEBILDET, nicht getippt --------------
#     mind_umfang_bilden liest DISPATCH/UEBERSPRUNGEN aus mind_agent_bilanz, GELAUFEN/TEIL/
#     FORMAL aus mind_schritt_bilanz --alle, skill=/bestand= aus analyzed-scopes.
P=$(neu_projekt); Q="$P/.claude-mind/agent-quittung.jsonl"; SQ="$P/.claude-mind/schritt-quittung.jsonl"
_ALT=$(date -u -d '-120 seconds' +%Y-%m-%dT%H:%M:%SZ); _NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'run_started=1\nskill=mind-files|L1\nskill=mind-claudemd|L1\nskill=mind-memory|L1\nskill=mind-rules|L1\nskill=mind-update|L1\nbestand=mind-files:3/3\nbestand=mind-claudemd:3/3\n' > "$P/.claude-mind/analyzed-scopes"
mind_agent_quittung_start "$P" 4
for b in claude-md memory rules; do
  printf '{"ereignis":"dispatch","bereich":"%s","ts":"%s"}\n' "$b" "$_ALT" >> "$Q"
  printf 'x%.0s' $(seq 1 300) > "$P/.claude-mind/agent-$b.md"
  mind_agent_ergebnis "$b" --datei "$P/.claude-mind/agent-$b.md" "$P" >/dev/null 2>&1
done
mind_agent_uebersprungen custom-context 0 "$P" >/dev/null 2>&1
printf '{"ereignis":"start","skill":"mind-all","erwartet":"mind-files","ts":"%s","code":"5.105.0","text":"5.105.0","versionsbruch":false}\n' "$_ALT" > "$SQ"
printf '{"ereignis":"start","skill":"mind-files","erwartet":"verdichten","ts":"%s","code":"5.105.0","text":"5.105.0","versionsbruch":false}\n{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"%s"}\n' "$_ALT" "$_NOW" >> "$SQ"
U=$(mind_umfang_bilden "$P" "L1" 4)
janein "umfang aus den Bilanzen: skills 5/5 (Laufspur L1)" ja "$(printf '%s' "$U" | grep -q '^5/5 skills ' && echo ja || echo nein)"
janein "   agents 3/3 (Skip abgezogen, nicht 3/4)" ja "$(printf '%s' "$U" | grep -q ' 3/3 agents ' && echo ja || echo nein)"
janein "   bestand 2/5 (zwei Quittungen in der Laufspur)" ja "$(printf '%s' "$U" | grep -q ' 2/5 bestand ' && echo ja || echo nein)"
janein "   nur Ziffern und / in den Bruechen (kein annotierter Wert moeglich)" 0 "$(printf '%s\n' "$U" | tr ' ' '\n' | grep '/' | grep -vc '^[0-9]*/[0-9]*$')"
janein "   fremde Laufkennung -> skills 0/5 (die Spur eines anderen Laufs zaehlt nicht)" ja "$(mind_umfang_bilden "$P" "L2" 4 | grep -q '^0/5 skills ' && echo ja || echo nein)"
rm -rf "$P"
# Text-Gate: mind-all baut UMFANG nicht mehr aus Variablen
# v5.113.0: 2.96a-R bildet den Wert nach der Reparatur ERNEUT — zwei Zuweisungen, beide aus der Funktion (Ziel unveraendert: nie von Hand)
janein "mind-all: UMFANG kommt aus mind_umfang_bilden" 2 "$(grep -c 'UMFANG=$(mind_umfang_bilden "$PROJ"' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md")"
janein "mind-all: kein UMFANG=\"...\" aus Shell-Variablen mehr" 0 "$(grep -c '^UMFANG="' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md")"

# --- 6d · v5.106.0 (Etappe 14 §2): ungepruef= wird GEBILDET — Doros Lauf als Fixture ----
#     Creator 13.09.2026 22:24:32Z: vier dispatch und vier ergebnis in derselben Sekunde,
#     kein mind-all-Kopf-Block; der Merker sagte von Hand "voll".
P=$(neu_projekt); Q="$P/.claude-mind/agent-quittung.jsonl"; SQ="$P/.claude-mind/schritt-quittung.jsonl"
printf '{"ereignis":"start","lauf":"20260913T222432Z-49590","erwartet":4,"ts":"2026-09-13T22:24:32Z"}\n' > "$Q"
for b in claude-md memory rules custom-context; do
  printf '{"ereignis":"dispatch","bereich":"%s","ts":"2026-09-13T22:24:32Z"}\n' "$b" >> "$Q"
done
printf '{"ereignis":"ergebnis","bereich":"claude-md","bytes":52,"quelle":"datei","ts":"2026-09-13T22:24:32Z"}\n{"ereignis":"ergebnis","bereich":"memory","bytes":59,"quelle":"datei","ts":"2026-09-13T22:24:32Z"}\n{"ereignis":"ergebnis","bereich":"rules","bytes":130,"quelle":"datei","ts":"2026-09-13T22:24:32Z"}\n{"ereignis":"ergebnis","bereich":"custom-context","bytes":73,"quelle":"datei","ts":"2026-09-13T22:24:32Z"}\n' >> "$Q"
printf '{"ereignis":"start","skill":"mind-files","erwartet":"verdichten","ts":"2026-09-13T22:03:08Z","code":"5.105.0","text":"5.105.0","versionsbruch":false}\n{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"2026-09-13T22:03:30Z"}\n' > "$SQ"
printf 'run_started=1\nbestand=mind-files:3/3\nbestand=mind-claudemd:3/3\nbestand=mind-memory:3/3\nbestand=mind-rules:3/3\nbestand=mind-update:3/3\n' > "$P/.claude-mind/analyzed-scopes"
U=$(mind_ungepruef_bilden "$P")
janein "Doros Lauf: ungepruef=claude-md,memory,rules,custom-context,formal-mind-all" "claude-md,memory,rules,custom-context,formal-mind-all" "$U"
# fehlende bestand-Quittung kommt dazu
printf 'run_started=1\nbestand=mind-files:3/3\n' > "$P/.claude-mind/analyzed-scopes"
janein "   ohne bestand-Quittungen: bestand-<skill> je fehlendem Skill" ja "$(mind_ungepruef_bilden "$P" | grep -q 'bestand-mind-claudemd,bestand-mind-memory,bestand-mind-rules,bestand-mind-update' && echo ja || echo nein)"
# nie dispatchter Bereich (nur im Ausschnitt des letzten Laufs) ist ungeprueft
printf '{"ereignis":"start","lauf":"L2","erwartet":4,"ts":"2026-09-13T23:00:00Z"}\n{"ereignis":"dispatch","bereich":"memory","ts":"2026-09-13T23:00:00Z"}\n{"ereignis":"ergebnis","bereich":"memory","bytes":500,"quelle":"datei","ts":"2026-09-13T23:02:00Z"}\n' >> "$Q"
janein "   neuer Lauf, nur memory dispatcht: die drei anderen sind ungeprueft, memory nicht" ja "$(mind_ungepruef_bilden "$P" | grep -q '^claude-md,rules,custom-context,' && echo ja || echo nein)"
rm -rf "$P"
# Text-Gate: mind-all baut UNGEPRUEFT nicht mehr aus Schleifen; Hand wird nur angehaengt
# v5.113.0: 2.96a-R bildet den Wert nach der Reparatur ERNEUT — zwei Zuweisungen, beide aus der Funktion (Ziel unveraendert: nie von Hand)
janein "mind-all: UNGEPRUEFT kommt aus mind_ungepruef_bilden" 2 "$(grep -c 'UNGEPRUEFT=$(mind_ungepruef_bilden "$PROJ"' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md")"
janein "mind-all: keine Schleife mehr, die UNGEPRUEFT zusammensetzt" 0 "$(grep -c 'UNGEPRUEFT="${UNGEPRUEFT}${_b},"' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md")"
janein "mind-all: Handzusatz nur als hand:<text> angehaengt" 1 "$(grep -c 'hand:${UNGEPRUEFT_HAND' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md")"

# --- 6e · v5.113.0 (Etappe 20 §2): mind_lauf_voll, Reparatur, Meldung an den manager ----
P=$(neu_projekt); Q="$P/.claude-mind/agent-quittung.jsonl"; SQ="$P/.claude-mind/schritt-quittung.jsonl"
_ALT=$(date -u -d '-120 seconds' +%Y-%m-%dT%H:%M:%SZ); _NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'run_started=1\nskill=mind-files|L1\nskill=mind-claudemd|L1\nskill=mind-memory|L1\nskill=mind-rules|L1\nskill=mind-update|L1\nbestand=mind-files:3/3\nbestand=mind-claudemd:3/3\nbestand=mind-memory:3/3\nbestand=mind-rules:3/3\nbestand=mind-update:3/3\n' > "$P/.claude-mind/analyzed-scopes"
mind_agent_quittung_start "$P" 4
for b in claude-md memory rules; do
  printf '{"ereignis":"dispatch","bereich":"%s","ts":"%s"}\n' "$b" "$_ALT" >> "$Q"
  printf 'x%.0s' $(seq 1 300) > "$P/.claude-mind/agent-$b.md"
  mind_agent_ergebnis "$b" --datei "$P/.claude-mind/agent-$b.md" "$P" >/dev/null 2>&1
done
mind_agent_uebersprungen custom-context 0 "$P" >/dev/null 2>&1
# Kopf-Block + fuenf eigene Bloecke, alle mit Artefakt
printf '{"ereignis":"start","skill":"mind-all","erwartet":"mind_snapshot","ts":"%s","code":"5.113.0","text":"5.113.0","versionsbruch":false}\n{"ereignis":"schritt","name":"mind_snapshot","status":"gelaufen","bytes":10,"ts":"%s"}\n' "$_ALT" "$_ALT" > "$SQ"
i=0; for s in mind-files mind-claudemd mind-memory mind-rules mind-update; do i=$((i+1))
  printf '{"ereignis":"start","skill":"%s","erwartet":"verdichten","ts":"%s","code":"5.113.0","text":"5.113.0","versionsbruch":false}\n{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"%s"}\n' "$s" "$(date -u -d "-$((100 - i * 10)) seconds" +%Y-%m-%dT%H:%M:%SZ)" "$_NOW" >> "$SQ"
done
janein "voller Lauf: mind_lauf_voll sagt voll (rc 0)" "voll" "$(mind_lauf_voll "$P" L1 4 2>/dev/null)"
# ein formal-: mind-memory OHNE eigenen Block -> teil; Reparatur (Block nachgefahren) -> voll
grep -v '"skill":"mind-memory"' "$SQ" > "$SQ.tmp"; mv "$SQ.tmp" "$SQ"
janein "ein formal-mind-memory -> teil" "teil" "$(mind_lauf_voll "$P" L1 4 2>/dev/null)"
janein "   ... ungepruef nennt formal-mind-memory" ja "$(mind_ungepruef_bilden "$P" L1 | grep -q 'formal-mind-memory' && echo ja || echo nein)"
printf '{"ereignis":"start","skill":"mind-memory","erwartet":"verdichten","ts":"%s","code":"5.113.0","text":"5.113.0","versionsbruch":false}\n{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"%s"}\n' "$_NOW" "$_NOW" >> "$SQ"
janein "   Reparatur: Block nachgefahren -> voll" "voll" "$(mind_lauf_voll "$P" L1 4 2>/dev/null)"
# toter Agent bleibt tot: nach zwei Paessen -> Meldung an den manager (Datei + Kennung aus dem Roster)
mkdir -p "$P/.claude/rules"; printf '| Rolle | Name | sessionId | Tut |\n|---|---|---|---|\n| manager | Anton | `62ca5f72-5e0e-452c-a165-fcde84811771` | liest |\n| arbeiter | Nils | `1be7f7a8-88a7-4842-99ac-56140694935c` | baut |\n' > "$P/.claude/rules/rollen.md"
printf '{"ereignis":"dispatch","bereich":"rules","ts":"%s"}\n{"ereignis":"ergebnis","bereich":"rules","bytes":0,"quelle":"datei","grund":"keine-datei","ts":"%s"}\n' "$_NOW" "$_NOW" >> "$Q"
janein "toter Agent -> teil" "teil" "$(mind_lauf_voll "$P" L1 4 2>/dev/null)"
janein "mind_manager_kennung liest Spalte 3 der manager-Zeile" "62ca5f72-5e0e-452c-a165-fcde84811771" "$(mind_manager_kennung "$P")"
mind_teilsync_meldung "$P" "$(mind_ungepruef_bilden "$P" L1)" "$(mind_umfang_bilden "$P" L1 4)" >/dev/null 2>&1
janein "Meldung liegt: teilsync-meldung mit manager= und satz=" ja "$(grep -q '^manager=62ca5f72' "$P/.claude-mind/rescued/teilsync-meldung" && grep -q '^satz=Teilsync nach zwei' "$P/.claude-mind/rescued/teilsync-meldung" && grep -q 'rules' "$P/.claude-mind/rescued/teilsync-meldung" && echo ja || echo nein)"
janein "   ... rc 0 — Information, der Lauf laeuft weiter (Nutzer 16.09.: verboten zu stoppen)" 0 "$(mind_teilsync_meldung "$P" x y >/dev/null 2>&1; echo $?)"
rm -rf "$P"
# Text-Gate: mind-all sagt es oben und repariert vor dem Schreiben
janein "mind-all: der Satz steht oben (Teilsync ist kein Ergebnis)" ja "$(grep -q 'Ein Teilsync ist kein Ergebnis' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && echo ja || echo nein)"
janein "mind-all: Reparatur ohne Pass-Limit, Meldung nach dem zweiten Pass, sync-stand nur bei ja" ja "$(grep -q 'while \[ "$(mind_lauf_voll "$PROJ" "${LAUF:-}" "${AGENT_SOLL:-4}")" = "teil" \]; do' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && grep -q '_PASS" -eq 2 \] && mind_teilsync_meldung' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && grep -q '\[ "$SYNC_LIEF" = "ja" \]; then' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && ! grep -q '"$SYNC_LIEF" = "teil" \] && \' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && echo ja || echo nein)"

# --- 7 · gar kein Merker ist nicht unsere Frage ---------------------------
P=$(neu_projekt)
janein "kein sync-stand -> vollstaendig" voll "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
# --- 7b · v5.113.0 (Etappe 20 §5a): ein FALSCHES Argument ist kein Merker — rc 3, nie still 0
#     Noras Lauf 11: mind_sync_voll "$UMFANG" (der String) sagte voll.
janein "umfang-String statt Pfad -> rc 3" rc3 "$(voll_p "5/5 skills 3/4 agents 5/5 bestand")"
janein "leeres Argument -> rc 3" rc3 "$(voll_p "")"
janein "Verzeichnis statt Datei -> rc 3" rc3 "$(voll_p "$P/.claude-mind/rescued")"
janein "   ... WARN auf stderr nennt den Aufruffehler" ja "$(mind_sync_voll "5/5 skills" 2>&1 >/dev/null | grep -q 'kein Dateipfad' && echo ja || echo nein)"
# --- 7c · v5.113.1: Pfade MIT Leerzeichen — jedes Projekt hier (`Plugin - Entwicklung`, `APP - Palvedo`).
#     5.113.0 lehnte sie mit `*[[:space:]]*` ab (rc 3 am existierenden Palvedo-Merker, Anton 16.09.):
#     pre-compact haette bei jeder Kompaktierung Schuld angelegt, 2.96a-R waere endlos gelaufen.
PS="$P/APP - Palvedo/.claude-mind/rescued"; mkdir -p "$PS"
printf 'ts=x\numfang=5/5 skills 4/4 agents 5/5 bestand 5/5 echt\nungepruef=\n' > "$PS/sync-stand"
janein "voller Merker unter Pfad MIT Leerzeichen -> voll (nicht rc 3)" voll "$(voll_p "$PS/sync-stand")"
printf 'ts=x\numfang=5/5 skills 0/4 agents\nungepruef=\n' > "$PS/sync-stand"
janein "   ... Teil-Merker unter Pfad MIT Leerzeichen -> teil" teil "$(voll_p "$PS/sync-stand")"
rm -f "$PS/sync-stand"
janein "   ... fehlender Merker in existierendem Ordner mit Leerzeichen -> voll (kein Merker)" voll "$(voll_p "$PS/sync-stand")"
janein "   ... Elternordner fehlt -> rc 3" rc3 "$(voll_p "$P/gibt es nicht/sync-stand")"
# pre-compact: rc 3 ist AUFRUFFEHLER, Text-Gates
janein "pre-compact: rc 3 -> grund=aufruffehler, nicht teilsync" ja "$(grep -q 'SYNC_LIEF_SCHON="aufruffehler"' "$CLAUDE_PLUGIN_ROOT/hooks/pre-compact.sh" && grep -q 'echo "grund=aufruffehler"' "$CLAUDE_PLUGIN_ROOT/hooks/pre-compact.sh" && echo ja || echo nein)"
janein "mind-all 2.96a: rc 3 -> AUFRUFFEHLER, kein Reparatur-Pass" ja "$(grep -q 'elif \[ "$_SV_RC" -eq 3 \]; then' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && echo ja || echo nein)"
# Text-Gate §4a: das Urteil ist mind_sync_voll auf dem frischen Merker, kein teil-Merker bleibt
janein "mind-all 2.96a: SYNC_LIEF ist mind_sync_voll auf dem geschriebenen sync-stand" ja "$(grep -q 'mind_sync_voll "$PROJ/.claude-mind/rescued/sync-stand"; _SV_RC=$?' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && grep -q 'if \[ "$_SV_RC" -eq 0 \]; then SYNC_LIEF="ja"' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && echo ja || echo nein)"
janein "mind-all 2.96a-R: ab Pass 3 warten (60 s x Pass, Deckel 600), nie abbrechen" ja "$(grep -q 'if \[ "$_PASS" -ge 3 \]; then _W=$((60 \* _PASS)); \[ "$_W" -gt 600 \] && _W=600' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && echo ja || echo nein)"
janein "mind-all 2.96: OPEN nur nach mind_sync_voll rc 0, alle RESUME (mind_schuld_begleichen)" ja "$(grep -q '&& mind_sync_voll "$PROJ/.claude-mind/rescued/sync-stand"; then' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && grep -q 'mind_schuld_begleichen "$PROJ"' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && ! grep -v '^ *#' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" | grep -q "RF=\$(grep -m1 '^resume='" && echo ja || echo nein)"   # gezaehlt wird die AUSFUEHRBARE Zeile, nicht die Erwaehnung im Kommentar
rm -rf "$P"

# --- ⭐ v5.67.0: das Paar `abdeckung` ------------------------------------
#     ⛔ Hier wird der PARSER geprueft, nicht der Ablauf: `mind_sync_voll`
#     muss ein VIERTES a/b-Paar genauso sehen wie die drei bekannten. Genau
#     darauf beruht Teil C von v5.67.0 — es kam ohne eine einzige Zeile in
#     `mind_sync_voll` aus, und dieser Fall haelt das fest.
#     ⚠ Der ABLAUF (Ritas Lauf) steht in tests/test_schritt_quittung.sh.
P=$(neu_projekt); stand "$P" "5/5 skills 4/4 agents 5/5 bestand 4/5 abdeckung"
janein "⛔ 4/5 abdeckung -> Teilsync, obwohl alles andere voll ist" teil \
       "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"
# ⭐ GEGENPROBE: volle Abdeckung darf NICHT zum Teilsync machen.
P=$(neu_projekt); stand "$P" "5/5 skills 4/4 agents 5/5 bestand 5/5 abdeckung"
janein "⭐ GEGENPROBE: 5/5 abdeckung -> vollstaendig" voll \
       "$(voll_p "$P/.claude-mind/rescued/sync-stand")"
rm -rf "$P"

echo "--- B · ⛔ mind_sync_frisch ist ENTFALLEN (v5.65.0) ---"
# ⛔ HIER STANDEN VIER FAELLE ueber den ZUWACHS seit dem Sync. Nutzer-
#    Entscheidung 10.09.2026: "die sollen garnicht mehr tokens messen das soll
#    komplett raus". Ohne `tokens=` im Merker konnte die Funktion nur noch EINE
#    Antwort geben, und ihr einziger Aufrufer (die Token-Mahnung) ist mit
#    entfallen — also geht sie ganz.
#
# ⭐ IHRE TRAGENDE ZUSICHERUNG STAND NIE IN IHR: "ein TEILSYNC ist kein Sync"
#    entscheidet `mind_sync_voll`. Das ist Abschnitt A dieser Sammlung, direkt
#    darueber, und Abschnitt C prueft die Folge (die Schuld entsteht).
#    Die Kette ist damit LUECKENLOS geblieben, nur um eine Stufe kuerzer.
# ⛔ UMGEKEHRT STATT GELOESCHT — gegen den alten Stand ROT.
if type mind_sync_frisch >/dev/null 2>&1; then N=definiert; else N=weg; fi
janein "mind_sync_frisch ist nicht mehr definiert" weg "$N"
janein "kein Hook ruft sie noch auf" 0 \
       "$(grep -rhoE 'mind_sync_frisch "' "$CLAUDE_PLUGIN_ROOT/hooks/" 2>/dev/null | wc -l | tr -d ' ')"

echo "--- C · pre-compact.sh: entsteht die Schuld? ---"

# --- 12 · Vollmerker -> KEINE Schuld (bestehendes Verhalten) --------------
P=$(neu_projekt); transkript "$P/t.jsonl"; stand "$P" "5/5 skills 4/4 agents"
LG="$P/log.txt"; : > "$LG"; precompact "$P" "$LG"
[ -f "$P/.claude-mind/rescued/OPEN" ] && A=ja || A=nein
janein "Vollsync -> kein OPEN" nein "$A"
grep -q "keine Schuld angelegt" "$LG" && A=ja || A=nein
janein "Protokoll nennt 'keine Schuld angelegt'" ja "$A"
rm -rf "$P"

# --- 13 · Teilmerker -> Schuld ENTSTEHT ----------------------------------
P=$(neu_projekt); transkript "$P/t.jsonl"
stand "$P" "5/5 skills 0/4 agents" "claude-md,memory,rules,custom-context"
LG="$P/log.txt"; : > "$LG"; precompact "$P" "$LG"
[ -f "$P/.claude-mind/rescued/OPEN" ] && A=ja || A=nein
janein "Teilsync -> OPEN entsteht" ja "$A"
grep -q '^grund=teilsync' "$P/.claude-mind/rescued/OPEN" 2>/dev/null && A=ja || A=nein
janein "OPEN traegt grund=teilsync" ja "$A"
grep -q '^ungepruef=.*custom-context' "$P/.claude-mind/rescued/OPEN" 2>/dev/null && A=ja || A=nein
janein "OPEN nennt die ungeprueften Bereiche" ja "$A"
grep -qi "teilsync" "$LG" && A=ja || A=nein
janein "Protokoll nennt TEILSYNC" ja "$A"
rm -rf "$P"

# --- 14 · der Merker wird in BEIDEN Faellen verbraucht --------------------
#     Ein liegengebliebener sync-stand waere eine Dauersperre (v5.11.0-Lehre).
P=$(neu_projekt); transkript "$P/t.jsonl"; stand "$P" "5/5 skills 0/4 agents"
precompact "$P" "$P/log.txt"
[ -f "$P/.claude-mind/rescued/sync-stand" ] && A=ja || A=nein
janein "Teilsync: sync-stand wird trotzdem verbraucht" nein "$A"
rm -rf "$P"

# --- 15 · gar kein Merker -> Schuld wie bisher, ABER ohne grund=teilsync --
P=$(neu_projekt); transkript "$P/t.jsonl"
LG="$P/log.txt"; : > "$LG"; precompact "$P" "$LG"
[ -f "$P/.claude-mind/rescued/OPEN" ] && A=ja || A=nein
janein "kein sync-stand -> OPEN wie bisher" ja "$A"
grep -q '^grund=teilsync' "$P/.claude-mind/rescued/OPEN" 2>/dev/null && A=ja || A=nein
janein "und NICHT als teilsync markiert" nein "$A"
rm -rf "$P"

# --- 16 · Altbestand: umfang= fehlt -> keine Schuld (Rueckwaertsvertrag) --
P=$(neu_projekt); transkript "$P/t.jsonl"; stand "$P" ""
precompact "$P" "$P/log.txt"
[ -f "$P/.claude-mind/rescued/OPEN" ] && A=ja || A=nein
janein "Merker ohne umfang= -> kein OPEN (Altbestand)" nein "$A"
rm -rf "$P"

echo "--- D · die Bilanz als Belegquelle ---"

# --- 17 · ohne Quittung ist die Rueckgabe 2 (Negativkontrolle) -----------
P=$(neu_projekt)
mind_agent_bilanz "$P" >/dev/null 2>&1; RC=$?
janein "keine Quittung -> Bilanz-Rueckgabe 2" 2 "$RC"
rm -rf "$P"

# --- 18 ⭐ 2 dispatcht, beide mit Ergebnis -> Rueckgabe 0 -----------------
#     DAS ist der Grund, warum die ZAHL entscheiden muss und nicht der
#     Rueckgabewert: ein nie dispatchter Agent hinterlaesst keine Zeile.
#     Ohne diesen Fall haette der Creator-Lauf (2 von 4) als vollstaendig
#     gegolten — genau der Ausfall, den diese Sammlung fangen soll.
P=$(neu_projekt)
mind_agent_quittung_start "$P" >/dev/null 2>&1
_disp "claude-md" "$P" >/dev/null 2>&1
_erg "claude-md" 4096 "$P" >/dev/null 2>&1
_disp "memory" "$P" >/dev/null 2>&1
_erg "memory" 2048 "$P" >/dev/null 2>&1
BIL=$(mind_agent_bilanz "$P" 2>/dev/null); RC=$?
janein "2 dispatcht + 2 Ergebnisse -> Rueckgabe 0 ('alles gut')" 0 "$RC"
D=$(printf '%s' "$BIL" | sed -n 's/.*DISPATCH=\([0-9]*\).*/\1/p' | head -1)
janein "aber DISPATCH= sagt die Wahrheit: 2" 2 "${D:-fehlt}"
rm -rf "$P"

# --- 19 · 4 dispatcht, 2 leer -> Rueckgabe 1 -----------------------------
P=$(neu_projekt)
mind_agent_quittung_start "$P" >/dev/null 2>&1
for b in claude-md memory rules custom-context; do
  _disp "$b" "$P" >/dev/null 2>&1
done
_erg "claude-md" 4096 "$P" >/dev/null 2>&1
_erg "memory" 2048 "$P" >/dev/null 2>&1
_erg "rules" 0 "$P" >/dev/null 2>&1
_erg "custom-context" 0 "$P" >/dev/null 2>&1
mind_agent_bilanz "$P" >/dev/null 2>&1; RC=$?
janein "4 dispatcht, 2 leer -> Rueckgabe 1" 1 "$RC"
rm -rf "$P"

echo "--- E · der Blocktext nennt den Grund ---"

offen() { # projekt [grund] [ungepruef]
  : > "$1/x_chat.md"
  { printf 'path=%s/x_chat.md\nresume=\nts=x\ncompactions=1\nblocks=0\n' "$1"
    [ -n "${2:-}" ] && printf 'grund=%s\nungepruef=%s\n' "$2" "${3:-}"
  } > "$1/.claude-mind/rescued/OPEN"
}
stop_lauf() { # projekt
  printf '{"session_id":"s","transcript_path":"","stop_hook_active":false,"cwd":"%s"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" MIND_SYNC_FORCE_TOKENS=0 bash "$H/stop.sh" 2>/dev/null
}
# ⛔ v5.55.0: stop.sh blockt niemanden mehr. Der Teilsync-GRUND wird seither
#    in `prompt-submit.sh` gemeldet — in der COMPACT-Meldung (v5.50.0) UND in
#    der reinen Schuld-Meldung (v5.55.0). Die zweite Stelle ist beim Verschieben
#    dieser Faelle entstanden: ohne sie haetten sie kein Ziel gehabt, und die
#    Zusicherung waere weggefallen statt umgezogen.
prompt_lauf() { # projekt
  printf '{"session_id":"s","transcript_path":"","prompt":"hi","cwd":"%s"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" MIND_SYNC_AT_TOKENS=0 bash "$H/prompt-submit.sh" 2>/dev/null
}

# --- 20 · Teilsync-Schuld -> die MELDUNG sagt WARUM ----------------------
#     ⛔ v5.55.0: war "der Blocktext". Der Block ist entfallen, die Aussage
#        nicht — sie steht jetzt in der Schuld-Meldung des naechsten Prompts.
P=$(neu_projekt); offen "$P" teilsync "claude-md,memory"
O=$(prompt_lauf "$P")
printf '%s' "$O" | grep -q "TEILSYNC" && A=ja || A=nein
janein "Meldung nennt TEILSYNC" ja "$A"
printf '%s' "$O" | grep -q "claude-md,memory" && A=ja || A=nein
janein "Meldung nennt die ungeprueften Bereiche" ja "$A"
# ⛔ Zwei Ausgaben in einem stdout sind kein gueltiges JSON mehr — der
#    v5.7.6-Fehler. Die Zusicherung wandert mit: genau EIN Objekt.
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$O" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1 \
    && A=ja || A=nein
  janein "Ausgabe bleibt genau EIN gueltiges JSON-Objekt" ja "$A"
else
  echo "  [--] jq fehlt — JSON-Fall UEBERSPRUNGEN, nichts gemessen"
fi
rm -rf "$P"

# --- 21 · GEGENKONTROLLE: normale Schuld -> KEIN Teilsync-Text -----------
#     Ohne diesen Fall koennte der Text immer erscheinen und die Pruefung
#     waere blind dafuer.
P=$(neu_projekt); offen "$P"
O=$(prompt_lauf "$P")
printf '%s' "$O" | grep -q "TEILSYNC" && A=ja || A=nein
janein "normale Schuld -> KEIN Teilsync-Text" nein "$A"
# ⛔ v5.55.0: war "und sie blockt trotzdem". Ohne Block lautet die tragende
#    Richtung: sie wird trotzdem GEMELDET. Ein Melder, der bei einer normalen
#    Schuld schweigt, waere durch den Umbau kaputtgegangen — und der Fall
#    daneben (kein Teilsync-Text) haette es nicht bemerkt.
printf '%s' "$O" | grep -qi 'sync-schuld' && A=ja || A=nein
janein "⭐ und sie wird trotzdem gemeldet" ja "$A"
S=$(stop_lauf "$P")
printf '%s' "$S" | grep -q '"decision"' && A=ja || A=nein
janein "⛔ stop.sh blockt dabei nicht mehr" nein "$A"
rm -rf "$P"

echo
echo "  gruen: $OK   rot: $ROT"
[ "$ROT" -eq 0 ] || exit 1
