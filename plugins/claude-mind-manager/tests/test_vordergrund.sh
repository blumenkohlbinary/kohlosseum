#!/usr/bin/env bash
# =============================================================================
#  VORDERGRUND-DISPATCH + QUITTUNG PER DATEI  (NEU v5.94.0)
# =============================================================================
#
# ⛔ WOZU. Gemessen 10.09.2026 (docs/plugin/rueckkanal-messung.md): kein Skill setzt
#    `run_in_background`, die Werkzeug-Vorgabe ist Hintergrund. Der tool_result ist
#    dann nur ein Ack; getrennte Tool-Calls serialisieren nichts (vier Agenten
#    gleichzeitig bei "sequenziellen" Aufrufen), und 5 von 8 Ergebnissen kamen nie
#    an — die Quittung trug trotzdem `bytes:800` (geschaetzt), die Bilanz sagte 4/4.
#
# ⭐ Zwei Zusicherungen (Anton, 11.09.2026, nils-etappe-5.md):
#    1  jeder Agent-Dispatch in mind-update / mind-claudemd / mind-memory (+ der
#       project-scanner in mind-files) traegt `run_in_background: false` — TEXT-GATE
#    2  die Quittung luegt nie mit Bytes: `--datei` misst eine Datei, die es gibt,
#       oder schreibt 0 — nie einen Schaetzwert
#    Gegenprobe gegen v5.93.0: dort fehlt beides (beim Bau gefahren: 17 von 22 rot).
# =============================================================================
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
[ -f "$R/hooks/lib.sh" ] || { echo "ABBRUCH: lib.sh fehlt"; exit 2; }

# ⛔ v5.97.0 — DIE QUITTUNG LAESST SICH NICHT MEHR TIPPEN: die Zahlform schreibt bytes:0,
#    und dispatch->ergebnis unter 30 s gilt als nachgetragen. Die Fixture liefert deshalb,
#    was ein echter Lauf liefert: einen Dispatch von vor 120 s und eine DATEI mit n Bytes.
#    Die Zusicherungen darunter sind woertlich die von vor v5.97.0.
_disp() { local q="$2/.claude-mind/agent-quittung.jsonl"; mkdir -p "$2/.claude-mind"
  printf '{"ereignis":"dispatch","bereich":"%s","ts":"%s"}\n' "$1" "$(date -u -d '-120 seconds' +%Y-%m-%dT%H:%M:%SZ)" >> "$q"; }
_erg()  { local f="$3/.claude-mind/agent-$1.md"; mkdir -p "$3/.claude-mind"
  head -c "$2" /dev/zero | tr '\0' x > "$f"; mind_agent_ergebnis "$1" --datei "$f" "$3" 2>/dev/null; }
# shellcheck disable=SC1090
. "$R/hooks/lib.sh" >/dev/null 2>&1

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then printf '    OK   %-64s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else printf '    FEHL %-64s ist=%-10s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1)); fi
}
mind() { if [ "$3" -ge "$2" ] 2>/dev/null; then printf '    OK   %-64s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else printf '    FEHL %-64s ist=%-10s soll>=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1)); fi; }

echo "=============================================================================="
echo "  1) TEXT-GATE: jeder Dispatch traegt run_in_background: false"
echo "=============================================================================="
# Erwartung = Zahl der Dispatch-Stellen je Skill (Launch/Dispatch-Zeilen + der
# Aufruf-Kasten in mind-update). Ein neuer Dispatch ohne die Marke faellt hier auf,
# weil die Marke je Stelle steht, nicht einmal je Datei.
for s in mind-update:2 mind-claudemd:2 mind-memory:1 mind-files:1; do
  n="${s##*:}"; s="${s%%:*}"; f="$R/skills/$s/SKILL.md"
  ist=$(grep -c 'run_in_background: false' "$f" 2>/dev/null)
  mind "$s: mindestens $n Stellen mit run_in_background: false" "$n" "${ist:-0}"
  janein "$s: keine Stelle mit run_in_background: true" 0 "$(grep -c 'run_in_background: true' "$f" 2>/dev/null)"
done
# Die Dispatch-Zeilen selbst: jede "Launch **context-analyzer**"- bzw.
# "Dispatch **project-scanner**"-Zeile nennt die Marke IN DERSELBEN Zeile oder der
# Klammer dahinter — hier ueber ein Fenster von 3 Zeilen geprueft.
for s in mind-claudemd mind-memory mind-files; do
  f="$R/skills/$s/SKILL.md"
  fehl=0
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    if ! sed -n "${ln},$((ln + 2))p" "$f" | grep -q 'run_in_background: false'; then fehl=$((fehl + 1)); fi
  done <<EOF
$(grep -nE '^(Launch \*\*context-analyzer\*\*|Dispatch \*\*project-scanner\*\*)' "$f" | cut -d: -f1)
EOF
  janein "$s: jede Launch/Dispatch-Zeile traegt die Marke im 3-Zeilen-Fenster" 0 "$fehl"
done
janein "mind-update: der Aufruf-Kasten nennt subagent_type UND die Marke" ja \
  "$(grep -q 'subagent_type: "claude-mind-manager:context-analyzer", run_in_background: false' "$R/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: die Quittung im Skill-Text laeuft ueber --datei" ja \
  "$(grep -q 'mind_agent_ergebnis "<bereich>" --datei' "$R/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: die alte wc-c-Form steht nicht mehr im Text" 0 \
  "$(grep -c "printf '%s' \"\$RUECKGABE\" | wc -c" "$R/skills/mind-update/SKILL.md")"
janein "mind-memory: 'While the agent runs' ist weg (Hintergrund-Annahme)" 0 \
  "$(grep -c 'While the agent runs' "$R/skills/mind-memory/SKILL.md")"

echo "=============================================================================="
echo "  2) QUITTUNG: --datei misst die Datei, fehlende Datei = 0"
echo "=============================================================================="
T=$(mktemp -d "${TMPDIR:-/tmp}/vgXXXXXX") || exit 2
P="$T/proj"; mkdir -p "$P/.claude-mind"
Q="$P/.claude-mind/agent-quittung.jsonl"
mind_agent_quittung_start "$P" 2
printf 'abcdefghij' > "$P/.claude-mind/agent-claude-md.md"      # 10 Byte
_disp "claude-md" "$P"
mind_agent_ergebnis "claude-md" --datei "$P/.claude-mind/agent-claude-md.md" "$P"
janein "--datei: bytes = Dateigroesse (10)" ja "$(grep -q '"bereich":"claude-md","bytes":10,' "$Q" && echo ja || echo nein)"
janein "   ... und quelle:datei steht dabei" ja "$(grep -q '"bytes":10,"quelle":"datei"' "$Q" && echo ja || echo nein)"
_disp "memory" "$P"
mind_agent_ergebnis "memory" --datei "$P/.claude-mind/gibt-es-nicht.md" "$P"
janein "⛔ --datei auf fehlende Datei: bytes=0, kein Schaetzwert" ja "$(grep -q '"bereich":"memory","bytes":0,"quelle":"datei"' "$Q" && echo ja || echo nein)"
janein "   ... die Bilanz fuehrt memory als UNGEPRUEFT" ja \
  "$(mind_agent_bilanz "$P" 2>/dev/null | grep -q 'UNGEPRUEFT: memory' && echo ja || echo nein)"
janein "   ... Zeile 1: DISPATCH=2 ERGEBNIS=2 LEER=1" "DISPATCH=2 ERGEBNIS=2 LEER=1 STUMM=0" \
  "$(mind_agent_bilanz "$P" 2>/dev/null | head -1)"
# ⛔ v5.97.0: die Zahlform schreibt 0. Bis v5.96.0 stand hier "Zahlform bleibt erlaubt und
#    traegt quelle:zahl" mit bytes:4096 — Ritas Lauf 22:05 (11.09.2026) hat genau damit
#    900/900/900/1000 getippt. Die Zusicherung ist umgekehrt, nicht gestrichen.
mind_agent_ergebnis "rules" 4096 "$P" 2>/dev/null
janein "⛔ Zahlform schreibt bytes:0, quelle:zahl, grund:zahlform" ja "$(grep -q '"bereich":"rules","bytes":0,"quelle":"zahl","grund":"zahlform"' "$Q" && echo ja || echo nein)"
janein "   ... Projekt-Argument an Position 4 bei --datei wird gelesen (Quittung liegt im Projekt)" 3 \
  "$(grep -c '"ereignis":"ergebnis"' "$Q")"
rm -rf "$T"

echo "=============================================================================="
echo "  3) TURN-LIMIT: Fortsetzung per SendMessage, nie ein neuer Agent (v5.96.0)"
echo "=============================================================================="
# Gemessen 12.09.2026 (Rita): zwei blockierende Agenten trafen das 20-Turn-Limit vor dem
# Bericht; SendMessage {to: <agentId>} brachte beide zum vollstaendigen Bericht. Ein neuer
# Agent-Aufruf waere ein zweiter Agent gegen dieselbe Grenze. Im Desktop-Reiter ist das
# Werkzeug verzoegert — der Kasten muss ToolSearch select:SendMessage nennen.
for s in mind-update mind-claudemd mind-memory mind-files mind-all; do
  f="$R/skills/$s/SKILL.md"
  mind "$s: nennt SendMessage {to: <agentId>} als Fortsetzung" 1 "$(grep -c 'SendMessage {to: <agentId>' "$f")"
  mind "$s: nennt ToolSearch select:SendMessage" 1 "$(grep -c 'ToolSearch select:SendMessage' "$f")"
done
# Die Fortsetzung steht an JEDER Dispatch-Stelle, nicht irgendwo in der Datei: im Fenster
# von 12 Zeilen um jede Launch-/Dispatch-Zeile und den Aufruf-Kasten. Beim Bau gefunden:
# mind-claudemd hat ZWEI Kaesten, der project-scanner-Kasten fehlte beim ersten Schnitt.
for s in mind-update mind-claudemd mind-memory mind-files; do
  f="$R/skills/$s/SKILL.md"
  fehl=0; n=0
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    n=$((n + 1)); von=$((ln - 12)); [ "$von" -lt 1 ] && von=1
    if ! sed -n "${von},$((ln + 12))p" "$f" | grep -q 'SendMessage {to: <agentId>'; then fehl=$((fehl + 1)); fi
  done <<EOF
$(grep -nE '^(Launch \*\*context-analyzer\*\*|Dispatch \*\*project-scanner\*\*|Agent\(subagent_type)' "$f" | cut -d: -f1)
EOF
  mind "$s: mindestens eine Dispatch-Stelle gefunden" 1 "$n"
  janein "$s: SendMessage-Satz an jeder der $n Dispatch-Stellen (Fenster 12 Zeilen)" 0 "$fehl"
done

echo "=============================================================================="
echo "  4) DIE QUITTUNG LAESST SICH NICHT MEHR TIPPEN (v5.97.0, nils-etappe-7.md §2)"
echo "=============================================================================="
# Gemessen an Ritas Lauf 22:05 (11.09.2026): dispatch und ergebnis in derselben Sekunde,
# bytes 900/900/900/1000 mit quelle:zahl, schritt-quittung der vier inneren Skills mit
# denselben getippten Bytes in allen drei Laeufen. Die Agenten fuer claude-md/memory
# LIEFEN (112 s, 159 s, 3 331/2 763 B) — die Quittung sagte 900. Mechanik statt Regel.
T=$(mktemp -d "${TMPDIR:-/tmp}/vqXXXXXX") || exit 2
P="$T/proj"; mkdir -p "$P/.claude-mind"; Q="$P/.claude-mind/agent-quittung.jsonl"
_alt() { date -u -d '-120 seconds' +%Y-%m-%dT%H:%M:%SZ; }

# --- 4a  --datei mit dem Hintergrund-Ack ist KEIN Ergebnis --------------------------
mind_agent_quittung_start "$P" 4
printf '{"ereignis":"dispatch","bereich":"claude-md","ts":"%s"}\n' "$(_alt)" >> "$Q"
printf 'Async agent launched successfully.\nagentId: abc\n' > "$P/.claude-mind/agent-claude-md.md"
mind_agent_ergebnis "claude-md" --datei "$P/.claude-mind/agent-claude-md.md" "$P" 2>/dev/null
janein "4a --datei auf das Hintergrund-Ack: bytes:0, grund:hintergrund" ja \
  "$(grep -q '"bereich":"claude-md","bytes":0,"quelle":"datei","grund":"hintergrund"' "$Q" && echo ja || echo nein)"
janein "   ... die Bilanz nennt den Grund" ja \
  "$(mind_agent_bilanz "$P" 2>/dev/null | grep -q 'UNGEPRUEFT: claude-md (Hintergrund-Ack' && echo ja || echo nein)"

# --- 4b  dispatch und ergebnis in derselben Sekunde = nachgetragen -----------------
mind_agent_quittung_start "$P" 4
printf 'abcdefghijklmnopqrstuvwxyz' > "$P/.claude-mind/agent-memory.md"
mind_agent_dispatch "memory" "$P"
mind_agent_ergebnis "memory" --datei "$P/.claude-mind/agent-memory.md" "$P" 2>/dev/null
janein "4b Datei mit 26 B, aber 0 s nach dem Dispatch: UNGEPRUEFT (nachgetragen)" ja \
  "$(mind_agent_bilanz "$P" 2>/dev/null | grep -q 'UNGEPRUEFT: memory (dispatch und ergebnis 0 s auseinander' && echo ja || echo nein)"
janein "   ... Rueckgabe 1" 1 "$(mind_agent_bilanz "$P" >/dev/null 2>&1; echo $?)"
# Positivkontrolle: derselbe Inhalt, Dispatch 120 s frueher -> geprueft
mind_agent_quittung_start "$P" 4
printf '{"ereignis":"dispatch","bereich":"memory","ts":"%s"}\n' "$(_alt)" >> "$Q"
mind_agent_ergebnis "memory" --datei "$P/.claude-mind/agent-memory.md" "$P" 2>/dev/null
janein "   Positivkontrolle: 120 s nach dem Dispatch, 26 B -> LEER=0" "DISPATCH=1 ERGEBNIS=1 LEER=0 STUMM=0" \
  "$(mind_agent_bilanz "$P" 2>/dev/null | head -1)"

# --- 4c  RITAS QUITTUNG, woertlich (echtes kaputtes Material) -------------------------
mind_agent_quittung_start "$P" 4
cat >> "$Q" <<'EOF'
{"ereignis":"dispatch","bereich":"claude-md","ts":"2026-09-11T22:05:30Z"}
{"ereignis":"ergebnis","bereich":"claude-md","bytes":900,"quelle":"zahl","ts":"2026-09-11T22:05:30Z"}
{"ereignis":"dispatch","bereich":"memory","ts":"2026-09-11T22:05:30Z"}
{"ereignis":"ergebnis","bereich":"memory","bytes":900,"quelle":"zahl","ts":"2026-09-11T22:05:30Z"}
{"ereignis":"dispatch","bereich":"rules","ts":"2026-09-11T22:05:30Z"}
{"ereignis":"dispatch","bereich":"custom-context","ts":"2026-09-11T22:05:30Z"}
{"ereignis":"ergebnis","bereich":"rules","bytes":900,"quelle":"zahl","ts":"2026-09-11T22:12:17Z"}
{"ereignis":"ergebnis","bereich":"custom-context","bytes":1000,"quelle":"zahl","ts":"2026-09-11T22:12:17Z"}
EOF
_B=$(mind_agent_bilanz "$P" 2>/dev/null); _RC=$?
janein "4c ⛔ Ritas Quittung 22:05: Rueckgabe 1, nicht 0 (bis v5.96.0: 4/4, rc 0)" 1 "$_RC"
janein "   ... alle vier UNGEPRUEFT (bytes getippt)" 4 "$(printf '%s\n' "$_B" | grep -c 'getippt, quelle:zahl')"
janein "   ... Kopfzeile LEER=4" "DISPATCH=4 ERGEBNIS=4 LEER=4 STUMM=0" "$(printf '%s\n' "$_B" | head -1)"

# --- 4d  agent-quittung haengt an, die Bilanz liest den letzten Lauf -----------------
janein "4d die Datei traegt jetzt mehrere Start-Zeilen (angehaengt, nicht geleert)" 4 "$(grep -c '"ereignis":"start"' "$Q")"
janein "   ... jede mit Laufkennung" 4 "$(grep -c '"ereignis":"start","lauf":"' "$Q")"
mind_agent_quittung_start "$P" 1
printf '{"ereignis":"dispatch","bereich":"rules","ts":"%s"}\n' "$(_alt)" >> "$Q"
printf 'x%.0s' $(seq 1 40) > "$P/.claude-mind/agent-rules.md"
mind_agent_ergebnis "rules" --datei "$P/.claude-mind/agent-rules.md" "$P" 2>/dev/null
janein "   ... und die Bilanz sieht NUR den letzten Lauf (DISPATCH=1, LEER=0)" "DISPATCH=1 ERGEBNIS=1 LEER=0 STUMM=0" \
  "$(mind_agent_bilanz "$P" 2>/dev/null | head -1)"

# --- 4e  mind_schritt: die fuenf Context-Skills und verdichten brauchen ein Artefakt ---
S="$P/.claude-mind/schritt-quittung.jsonl"
: > "$S"
mind_schritt mind-files gelaufen 300 "$P" 2>/dev/null
janein "4e mind_schritt mind-files gelaufen 300 -> uebersprungen:kein-artefakt, bytes 0" ja \
  "$(grep -q '"name":"mind-files","status":"uebersprungen:kein-artefakt","bytes":0,' "$S" && echo ja || echo nein)"
printf '# Bericht mind-files\n1 Datei angelegt\n' > "$P/.claude-mind/bericht-mind-files.md"
mind_schritt mind-files gelaufen --datei "$P/.claude-mind/bericht-mind-files.md" "$P" 2>/dev/null
janein "   ... mit --datei: gelaufen, Bytes der Datei, quelle:datei" ja \
  "$(grep -q "\"name\":\"mind-files\",\"status\":\"gelaufen\",\"bytes\":$(wc -c < "$P/.claude-mind/bericht-mind-files.md" | tr -d ' '),\"quelle\":\"datei\"" "$S" && echo ja || echo nein)"
mind_schritt verdichten gelaufen 5 "$P" 2>/dev/null
janein "   verdichten gelaufen ohne Datei -> kein-artefakt" ja \
  "$(grep -q '"name":"verdichten","status":"uebersprungen:kein-artefakt"' "$S" && echo ja || echo nein)"
mind_schritt verdichten "uebersprungen:kein-kandidat" 0 "$P" 2>/dev/null
janein "   verdichten uebersprungen:kein-kandidat bleibt, wie es ist" ja \
  "$(grep -q '"name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,' "$S" && echo ja || echo nein)"
mind_schritt claudemd_pipeline gelaufen 500 "$P" 2>/dev/null
janein "   ein Werkzeug-Schritt nimmt weiter die Zahl (nur die Skills brauchen ein Artefakt)" ja \
  "$(grep -q '"name":"claudemd_pipeline","status":"gelaufen","bytes":500,' "$S" && echo ja || echo nein)"

# --- 4f  schritt_bilanz --alle: Ritas Lauf 00:02 nachgestellt ---------------------------
: > "$S"; : > "$P/.claude-mind/analyzed-scopes"
cat >> "$S" <<'EOF'
{"ereignis":"start","skill":"mind-all","erwartet":"mind_agent_bilanz","ts":"2026-09-11T22:01:44Z","code":"5.94.0","text":"unbekannt","versionsbruch":false}
{"ereignis":"schritt","name":"mind-files","status":"gelaufen","bytes":300,"ts":"2026-09-11T22:02:03Z"}
{"ereignis":"schritt","name":"mind-claudemd","status":"gelaufen","bytes":700,"ts":"2026-09-11T22:02:03Z"}
{"ereignis":"schritt","name":"mind-memory","status":"gelaufen","bytes":400,"ts":"2026-09-11T22:02:03Z"}
{"ereignis":"schritt","name":"mind-rules","status":"gelaufen","bytes":300,"ts":"2026-09-11T22:02:03Z"}
{"ereignis":"schritt","name":"mind-update","status":"gelaufen","bytes":6000,"ts":"2026-09-11T22:12:33Z"}
{"ereignis":"schritt","name":"mind_agent_bilanz","status":"gelaufen","bytes":50,"ts":"2026-09-11T22:12:52Z"}
EOF
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null); _ARC=$?
janein "4f ⛔ Ritas Lauf 00:02: Rueckgabe 1 (bis v5.96.0: 0)" 1 "$_ARC"
janein "   ... FORMAL=5: kein Skill hat einen eigenen Start-Block" ja "$(printf '%s\n' "$_A" | grep -q '^  FORMAL=5$' && echo ja || echo nein)"
janein "   ... und sagt, warum" ja "$(printf '%s\n' "$_A" | grep -q 'FORMAL: mind-files (kein eigener Start-Block' && echo ja || echo nein)"
janein "   ... Stempel text:unbekannt ist ein Meldegrund" ja "$(printf '%s\n' "$_A" | grep -q 'STEMPEL UNGELESEN (text:unbekannt): mind-all' && echo ja || echo nein)"
# dieselben Zeilen, aber mit eigenen Bloecken -> (b) Bytes getippt und (c) gleiche Sekunde
for s in mind-files mind-claudemd mind-memory mind-rules mind-update; do
  printf '{"ereignis":"start","skill":"%s","erwartet":"x","ts":"2026-09-11T22:02:00Z","code":"5.97.0","text":"5.97.0","versionsbruch":false}\n{"ereignis":"schritt","name":"x","status":"gelaufen","bytes":1,"ts":"2026-09-11T22:02:01Z"}\n' "$s" >> "$S"
done
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "   mit eigenen Bloecken: FORMAL=5 bleibt — Bytes getippt (kein --datei)" ja "$(printf '%s\n' "$_A" | grep -q '^  FORMAL=5$' && echo ja || echo nein)"
janein "   ... Grund: Bytes getippt, kein Bericht" 5 "$(printf '%s\n' "$_A" | grep -c 'Bytes getippt, kein Bericht per --datei')"
# Positivkontrolle: Berichte per Datei, jede Sekunde ein Skill -> FORMAL fehlt, rc 0
: > "$S"
printf '{"ereignis":"start","skill":"mind-all","erwartet":"mind_agent_bilanz","ts":"2026-09-11T22:01:44Z","code":"5.97.0","text":"5.97.0","versionsbruch":false}\n' >> "$S"
i=0
for s in mind-files mind-claudemd mind-memory mind-rules mind-update; do
  i=$((i + 1))
  printf '{"ereignis":"start","skill":"%s","erwartet":"verdichten","ts":"2026-09-11T22:02:0%dZ","code":"5.97.0","text":"5.97.0","versionsbruch":false}\n' "$s" "$i" >> "$S"
  printf '{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"2026-09-11T22:02:0%dZ"}\n' "$i" >> "$S"
  printf '{"ereignis":"schritt","name":"%s","status":"gelaufen","bytes":300,"quelle":"datei","ts":"2026-09-11T22:03:0%dZ"}\n' "$s" "$i" >> "$S"
done
printf '{"ereignis":"schritt","name":"mind_agent_bilanz","status":"gelaufen","bytes":50,"ts":"2026-09-11T22:12:52Z"}\n' >> "$S"
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null); _ARC=$?
janein "   Positivkontrolle: eigene Bloecke, --datei, verschiedene Sekunden, verdichten quittiert -> rc 0" 0 "$_ARC"
janein "   ... ohne FORMAL-Zeile" nein "$(printf '%s\n' "$_A" | grep -q 'FORMAL' && echo ja || echo nein)"
# (c) zwei in derselben Sekunde
sed -i 's/"ts":"2026-09-11T22:03:02Z"/"ts":"2026-09-11T22:03:01Z"/' "$S"
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "   (c) mind-claudemd in derselben Sekunde wie mind-files -> FORMAL=1" ja "$(printf '%s\n' "$_A" | grep -q 'FORMAL: mind-claudemd (dieselbe Sekunde' && echo ja || echo nein)"

# --- 4g  FEHLT je Block: verdichten fehlt in EINEM inneren Skill -------------------------
sed -i 's/"ts":"2026-09-11T22:03:01Z"/"ts":"2026-09-11T22:03:02Z"/' "$S"   # (c) zuruecknehmen
grep -v '"name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"2026-09-11T22:02:03Z"' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null); _ARC=$?
janein "4g verdichten fehlt in mind-memory -> FEHLT nennt mind-memory/verdichten" ja "$(printf '%s\n' "$_A" | grep -q 'FEHLT.*mind-memory/verdichten' && echo ja || echo nein)"
janein "   ... Rueckgabe 1 (bis v5.96.0: nur die Liste des ERSTEN Blocks zaehlte)" 1 "$_ARC"

# --- 4h  RITAS KALIBRIERLAUF 23:21 (12.09.2026), woertlich — v5.98.0 ---------------------
# Alle Schritte mit --datei, Verdichten fuenfmal quittiert, agent-quittung echt — und
# trotzdem kein eigener Start-Block je Skill: mind-all/SKILL.md:45 fuehrte die fuenf als
# SCHRITTE, die Bilanz verlangt BLOECKE. Bis v5.97.0 griff (a) nur ueber die Schrittzeile;
# seit v5.98.0 ueber den Kettenlauf selbst. context-analyzer/project-scanner liefen nie.
: > "$S"; : > "$P/.claude-mind/analyzed-scopes"
cat >> "$S" <<'EOF'
{"ereignis":"start","skill":"mind-all","erwartet":"arbeitsstand_render debug_auswertung mind_agent_bilanz mind_check_tools_have_rules mind_debug_write mind_hook_health mind_snapshot mind_zeilenenden_waechter","ts":"2026-09-11T23:21:36Z","code":"5.97.0","text":"5.97.0","versionsbruch":false}
{"ereignis":"schritt","name":"mind_snapshot","status":"gelaufen","bytes":109,"quelle":"datei","ts":"2026-09-11T23:21:36Z"}
{"ereignis":"schritt","name":"mind_hook_health","status":"gelaufen","bytes":173,"quelle":"datei","ts":"2026-09-11T23:21:36Z"}
{"ereignis":"schritt","name":"mind-files","status":"gelaufen","bytes":1217,"quelle":"datei","ts":"2026-09-11T23:22:02Z"}
{"ereignis":"schritt","name":"verdichten","status":"gelaufen","bytes":1123,"quelle":"datei","ts":"2026-09-11T23:30:41Z"}
{"ereignis":"schritt","name":"verdichten","status":"gelaufen","bytes":823,"quelle":"datei","ts":"2026-09-11T23:30:41Z"}
{"ereignis":"schritt","name":"verdichten","status":"gelaufen","bytes":478,"quelle":"datei","ts":"2026-09-11T23:30:42Z"}
{"ereignis":"schritt","name":"verdichten","status":"gelaufen","bytes":834,"quelle":"datei","ts":"2026-09-11T23:30:42Z"}
{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"2026-09-11T23:30:42Z"}
{"ereignis":"schritt","name":"mind-claudemd","status":"gelaufen","bytes":938,"quelle":"datei","ts":"2026-09-11T23:30:56Z"}
{"ereignis":"schritt","name":"mind-memory","status":"gelaufen","bytes":112,"quelle":"datei","ts":"2026-09-11T23:30:56Z"}
{"ereignis":"schritt","name":"mind-rules","status":"gelaufen","bytes":4,"quelle":"datei","ts":"2026-09-11T23:30:56Z"}
{"ereignis":"schritt","name":"mind-update","status":"gelaufen","bytes":50,"quelle":"datei","ts":"2026-09-11T23:38:41Z"}
{"ereignis":"schritt","name":"mind_zeilenenden_waechter","status":"gelaufen","bytes":36,"quelle":"datei","ts":"2026-09-11T23:38:54Z"}
{"ereignis":"schritt","name":"mind_check_tools_have_rules","status":"gelaufen","bytes":1217,"quelle":"datei","ts":"2026-09-11T23:38:56Z"}
{"ereignis":"schritt","name":"debug_auswertung","status":"gelaufen","bytes":51,"quelle":"datei","ts":"2026-09-11T23:38:56Z"}
{"ereignis":"schritt","name":"arbeitsstand_render","status":"uebersprungen:kein-arbeitsstand-kein-rescue","bytes":0,"ts":"2026-09-11T23:38:56Z"}
{"ereignis":"schritt","name":"mind_agent_bilanz","status":"gelaufen","bytes":50,"quelle":"datei","ts":"2026-09-11T23:38:58Z"}
{"ereignis":"schritt","name":"mind_debug_write","status":"gelaufen","bytes":0,"ts":"2026-09-11T23:39:27Z"}
EOF
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null); _ARC=$?
janein "4h ⛔ Ritas Kalibrierlauf: Rueckgabe 1" 1 "$_ARC"
janein "   ... FORMAL=5, alle fuenf ohne eigenen Start-Block" 5 "$(printf '%s\n' "$_A" | grep -c 'FORMAL: mind-.* (kein eigener Start-Block')"
# Gegenprobe: fuenf eigene Bloecke OHNE Schrittzeile je Skill -> kein FORMAL (a) mehr
: > "$S"
printf '{"ereignis":"start","skill":"mind-all","erwartet":"mind_agent_bilanz","ts":"2026-09-12T00:00:00Z","code":"5.98.0","text":"5.98.0","versionsbruch":false}\n' >> "$S"
i=0
for s in mind-files mind-claudemd mind-memory mind-rules mind-update; do
  i=$((i + 1))
  printf '{"ereignis":"start","skill":"%s","erwartet":"verdichten","ts":"2026-09-12T00:0%d:00Z","code":"5.98.0","text":"5.98.0","versionsbruch":false}\n' "$s" "$i" >> "$S"
  printf '{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"2026-09-12T00:0%d:30Z"}\n' "$i" >> "$S"
done
printf '{"ereignis":"schritt","name":"mind_agent_bilanz","status":"gelaufen","bytes":50,"ts":"2026-09-12T00:09:00Z"}\n' >> "$S"
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null); _ARC=$?
janein "   Gegenprobe: fuenf eigene Bloecke, keine Skill-Schrittzeile -> rc 0" 0 "$_ARC"
# der Kern von v5.98.0: mind-all-Block OHNE Schrittzeile fuer die fuenf und OHNE Bloecke
# -> bis v5.97.0 unsichtbar (rc 0), jetzt FORMAL=5
: > "$S"
printf '{"ereignis":"start","skill":"mind-all","erwartet":"mind_agent_bilanz","ts":"2026-09-12T00:00:00Z","code":"5.98.0","text":"5.98.0","versionsbruch":false}
{"ereignis":"schritt","name":"mind_agent_bilanz","status":"gelaufen","bytes":50,"ts":"2026-09-12T00:09:00Z"}
' >> "$S"
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null); _ARC=$?
janein "   ⛔ Kette ohne die fuenf Skills (weder Schritt noch Block): rc 1 (bis v5.97.0: 0)" 1 "$_ARC"
janein "   ... FORMAL=5" ja "$(printf '%s
' "$_A" | grep -q '^  FORMAL=5$' && echo ja || echo nein)"
# und ohne mind-all-Startzeile (Einzellauf) gilt (a) nicht
: > "$S"
printf '{"ereignis":"start","skill":"mind-files","erwartet":"verdichten","ts":"2026-09-12T00:01:00Z","code":"5.98.0","text":"5.98.0","versionsbruch":false}\n{"ereignis":"schritt","name":"verdichten","status":"uebersprungen:kein-kandidat","bytes":0,"ts":"2026-09-12T00:01:30Z"}\n' >> "$S"
_A=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "   Einzellauf ohne mind-all-Start: kein FORMAL fuer die vier fehlenden" nein "$(printf '%s\n' "$_A" | grep -q 'FORMAL' && echo ja || echo nein)"
rm -rf "$T"

echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
