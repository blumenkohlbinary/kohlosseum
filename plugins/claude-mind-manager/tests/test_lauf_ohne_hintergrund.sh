#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Ein /mind-all-Lauf muss auch unter `claude -p` bis zum sync-stand kommen (v5.164.0, Etappe 65 §2).
#
# ⛔ Gemessen im A/B-Lauf vom 30.10.2026 (5.163.0, `claude -p`), drei Ursachen, ein Ergebnis — kein sync-stand:
#    1) Step 2.96 rechnete umfang= und ungepruef= fuenfmal (~143 s) — ueber 120 s schiebt das Bash-Werkzeug
#       den Block in den Hintergrund, die Sitzung „wartete auf Block-Ende“ und war vorbei.
#    2) bestand= fehlte in allen fuenf Skills: der Block sagte „quittiert SELBST — NICHT nachtippen“,
#       die Pass-Quittung `--quittung` stand nur weiter unten im Text und blieb aus.
#    3) die vier Knowledge-Sync-Agents liefen ohne agent-schritt.sh und ohne run_in_background:false —
#       die Agent-Vorlage stand im Text VOR dem Block.
#    Dazu ein eigener Baufehler aus 5.163.0: ein woertliches `\n` in step5d-pass.sh gab cleaner_stichprobe
#    das Argument `n` („PRUEFEN: n“ im Lauf).
# Gegen 5.163.0 sind die Abschnitte 1–5 rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude-mind"
# Aufrufe zaehlen, Kommentarzeilen nicht
aufrufe() { grep -v '^[[:space:]]*#' "$2" | grep -o "$1 " | grep -c .; }

echo "=== 1) mind_voll_aus urteilt wie mind_lauf_voll ==="
V() { ( . "$R/hooks/lib.sh"; mind_voll_aus "$@" ); }
pruef "voll: alle Zaehler voll, ungepruef leer" "$(V '5/5 skills 4/4 agents 5/5 bestand 9/9 abdeckung 5/5 echt' '')" "voll"
pruef "teil: ungepruef gefuellt" "$(V '5/5 skills 4/4 agents 5/5 bestand 9/9 abdeckung 5/5 echt' 'bestand-mind-rules')" "teil"
pruef "teil: 0/5 bestand" "$(V '5/5 skills 4/4 agents 0/5 bestand 9/9 abdeckung 5/5 echt' '')" "teil"
G=$( ( . "$R/hooks/lib.sh"; a=$(mind_lauf_voll "$P" x 4); b=$(mind_voll_aus "$(mind_umfang_bilden "$P" x 4)" "$(mind_ungepruef_bilden "$P" x)"); [ "$a" = "$b" ] && echo gleich || echo "$a/$b" ) 2>/dev/null)
pruef "leeres Projekt: beide Wege dasselbe Urteil" "$G" "gleich"

echo "=== 2) Step 2.96 rechnet umfang= und ungepruef= je EINMAL ==="
A96="$R/skills/mind-all/bloecke/step2.96-abschluss.sh"
pruef "mind_umfang_bilden: 1 Aufruf" "$(aufrufe '\$(mind_umfang_bilden' "$A96")" "1"
pruef "mind_ungepruef_bilden: 1 Aufruf" "$(aufrufe '\$(mind_ungepruef_bilden' "$A96")" "1"
pruef "mind_lauf_voll: kein Aufruf (je ~30 s)" "$(grep -v '^[[:space:]]*#' "$A96" | grep -c 'mind_lauf_voll "')" "0"
pruef "mind-all-Text: timeout 600000 vor dem 2.96-Aufruf" "$(grep -B8 'bloecke/step2.96-abschluss.sh"$' "$R/skills/mind-all/SKILL.md" | grep -c 'timeout: 600000')" "1"

echo "=== 3) mind-update: der Block steht VOR der Agent-Vorlage ==="
MU="$R/skills/mind-update/SKILL.md"
zb=$(grep -n 'agent-schritt.sh' "$MU" | head -1 | cut -d: -f1); za=$(grep -n 'Agent(subagent_type' "$MU" | head -1 | cut -d: -f1)
pruef "erste Nennung agent-schritt.sh vor dem ersten Agent(" "$([ "${zb:-99999}" -lt "${za:-0}" ] && echo ja || echo "nein ($zb/$za)")" "ja"

echo "=== 4) jeder Bestands-Pass-Block endet mit mind_pass_offen, kein woertliches \\n ==="
for b in mind-claudemd:pass-bestand mind-files:pass-bestand mind-memory:pass-bestand mind-rules:pass-bestand mind-update:step5d-pass; do
  s="${b%%:*}"; f="$R/skills/$s/bloecke/${b#*:}.sh"
  pruef "$s: letzte Zeile mind_pass_offen $s" "$(grep -v '^[[:space:]]*$' "$f" | tail -1 | grep -c "^mind_pass_offen $s ")" "1"
  pruef "$s: kein \\n mitten im Befehl" "$(grep -cF '" \n ' "$f")" "0"
done

echo "=== 5) mind_pass_offen nennt den Aufruf mit der Stichprobe ==="
mkdir -p "$P/.claude-mind/pass-mind-rules"
printf '  Bestand: 8 Eintraege · Stichprobe: 2 · Restbudget im Lauf: 4\n' > "$P/.claude-mind/pass-mind-rules/cleaner_stichprobe.txt"
O=$( ( . "$R/hooks/lib.sh"; PROJ="$P"; mind_pass_offen mind-rules ) 2>&1 )
pruef "nennt --quittung --skill mind-rules" "$(printf '%s\n' "$O" | grep -c -- '--quittung --skill mind-rules --geprueft <n> --stichprobe 2')" "1"
printf '  (nichts) — kein ungepruefter Eintrag uebrig\n  bestand=mind-rules:0/0\n' > "$P/.claude-mind/pass-mind-rules/cleaner_stichprobe.txt"
O=$( ( . "$R/hooks/lib.sh"; PROJ="$P"; mind_pass_offen mind-rules ) 2>&1 )
pruef "leere Stichprobe: nichts offen" "$(printf '%s\n' "$O" | grep -c 'nichts offen')" "1"
pruef "kein Skill: rc 2" "$( ( . "$R/hooks/lib.sh"; PROJ="$P"; mind_pass_offen '' >/dev/null 2>&1; echo $? ) )" "2"

echo "=== 6) ⛔ v5.165.0: ein Block der fuenf Ketten-Skills laeuft nur hinter SEINEM Kopf ==="
# A/B-Lauf 30.10.2026 (5.164.0): Bloecke direkt aus bloecke/ gefahren, ohne Kopf-Fence — 17/58, 1/5 echt.
ST="$TMP/wurzel"; mkdir -p "$ST/hooks" "$ST/skills/mind-rules/bloecke" "$ST/skills/mind-all/bloecke"
cp "$R/hooks/lib.sh" "$ST/hooks/"
for s in mind-rules mind-all; do
  printf '#!/usr/bin/env bash\n. "%s/hooks/lib.sh"\nmind_block_umgebung\necho LIEF > "$PROJ/lief-%s"\n' "$ST" "$s" > "$ST/skills/$s/bloecke/probe.sh"
done
Q="$P/.claude-mind/schritt-quittung.jsonl"
blk() { ( cd "$P" && env -u PROJ MIND_KOPF_PFLICHT=an CLAUDE_PROJECT_DIR="$P" MIND_LOG_FILE="$TMP/log" bash "$ST/skills/$1/bloecke/probe.sh" >/dev/null 2>"$TMP/err"; echo $? ); }
printf '{"ereignis":"start","skill":"mind-claudemd","ts":"2026-10-30T08:00:00Z"}\n' > "$Q"
pruef "letzte Startzeile mind-claudemd: mind-rules-Block rc 3" "$(blk mind-rules)" "3"
pruef "   ... nichts gefahren" "$([ -e "$P/lief-mind-rules" ] && echo da || echo fehlt)" "fehlt"
pruef "   ... Meldung nennt KOPF FEHLT und den Skill" "$(grep -c 'KOPF FEHLT: mind-rules' "$TMP/err")" "1"
rm -f "$Q"
pruef "gar keine Quittung: rc 3" "$(blk mind-rules)" "3"
printf '{"ereignis":"start","skill":"mind-rules","ts":"2026-10-30T08:01:00Z"}\n{"ereignis":"schritt","name":"x","status":"gelaufen","ts":"2026-10-30T08:01:01Z"}\n' > "$Q"
pruef "hinter dem eigenen Kopf: rc 0" "$(blk mind-rules)" "0"
pruef "   ... gefahren" "$([ -e "$P/lief-mind-rules" ] && echo da || echo fehlt)" "da"
pruef "mind-all-Bloecke sind nicht gesperrt (laufen hinter mind-update)" "$(blk mind-all)" "0"

echo "=== 7) v5.166.0: der Knowledge-Sync-Analyzer verweigert ohne Dispatch-Zeile (Anton, Nachtrag 1 — kein Hook) ==="
AG="$R/agents/context-analyzer.md"
pruef "Agent: Pruefung auf die Dispatch-Zeile nach der letzten Start-Zeile" "$(grep -c '"ereignis":"dispatch","bereich":"<dein scope>"' "$AG")" "1"
pruef "Agent: liest agent-quittung.jsonl als ERSTES" "$(grep -c 'Erster Werkzeugaufruf: `Read <project>/.claude-mind/agent-quittung.jsonl`' "$AG")" "1"
pruef "Agent: Antwort UNDISPATCHED, nichts schreiben" "$(grep -c '^> `UNDISPATCHED: kein mind_agent_dispatch' "$AG")" "1"
pruef "Agent: Read im Werkzeugsatz" "$(sed -n '/^tools:/,/^disallowedTools:/p' "$AG" | grep -c '^  - Read$')" "1"
pruef "mind-update: UNDISPATCHED heisst Block fahren, nicht nachtragen" "$(grep -c 'UNDISPATCHED: …' "$R/skills/mind-update/SKILL.md")" "1"
pruef "agent-schritt.sh dispatcht VOR dem Agent (mind_agent_dispatch im Block)" "$(grep -c 'mind_agent_dispatch "\$n" "\$PROJ"' "$R/skills/mind-update/bloecke/agent-schritt.sh")" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
