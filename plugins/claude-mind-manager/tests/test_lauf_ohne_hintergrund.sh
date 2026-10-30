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

echo "=== 8) v5.167.0: agent-schritt.sh gibt den AUFTRAG woertlich aus, mit Bestands-Pruefung und kurzer Lese-Liste ==="
# Voller Lauf 30.10.2026: Agenten ohne run_in_background, keine Bestands-Pruefung, custom-context bekam 412 Dateien.
P8="$TMP/ks projekt"; mkdir -p "$P8/.claude-mind" "$P8/docs"
printf '# P\nzuerst `ZIEL.md` und `docs/x.md` lesen; Auftraege `Auftraege/*.md`\n' > "$P8/CLAUDE.md"
echo z > "$P8/ZIEL.md"; echo x > "$P8/docs/x.md"; echo a > "$P8/a.md"
AS() { ( cd "$P8" && env -u PROJ -u LAUF CLAUDE_CODE_SESSION_ID=aaaa1111-0000-0000-0000-00000000beef CLAUDE_PROJECT_DIR="$P8" \
         MIND_LOG_FILE="$TMP/log" bash "$R/skills/mind-update/bloecke/agent-schritt.sh" "$@" 2>&1 ); }
CCF=$( ( cd "$P8"; . "$R/hooks/lib.sh"; export CLAUDE_CODE_SESSION_ID=aaaa1111-0000-0000-0000-00000000beef; PROJ="$P8"; mind_sampler_pfad "$P8" mind-update-ccf.txt ) )
mkdir -p "$(dirname "$CCF")"; printf './ZIEL.md\n./docs/x.md\n./a.md\n' > "$CCF"
O1=$(AS start claude-md,memory)
pruef "Welle 1: zwei woertliche Auftraege" "$(printf '%s\n' "$O1" | grep -c '^----- AUFTRAG ')" "2"
pruef "   ... je Auftrag run_in_background: false im Aufruf" "$(printf '%s\n' "$O1" | grep -c 'Agent(subagent_type: "claude-mind-manager:context-analyzer", run_in_background: false')" "2"
pruef "   ... Bestands-Pruefung genannt" "$(printf '%s\n' "$O1" | grep -c 'BESTAND gegen seine Quellen')" "2"
pruef "   ... memory: Zitat-Pruefung und Fehlplatzierung" "$(printf '%s\n' "$O1" | grep -cE 'ZITAT, das einer Datei zugeschrieben|Fehlplatzierung nach')" "2"
B8() { ( cd "$P8"; . "$R/hooks/lib.sh"; export CLAUDE_CODE_SESSION_ID=aaaa1111-0000-0000-0000-00000000beef; PROJ="$P8"; mind_agent_bericht_pfad "$1" "$P8" ); }
for n in claude-md memory; do printf '## Befunde\n- INFO nichts\n' > "$(B8 $n)"; done
O2=$(AS claude-md,memory rules,custom-context)
pruef "Welle 2: rules mit Werkzeug-Pruefung" "$(printf '%s\n' "$O2" | grep -c 'Rule aelter als Werkzeug')" "1"
pruef "   ... custom-context: ZIEL.md auf der Lese-Liste" "$(printf '%s\n' "$O2" | grep -c '^    ZIEL.md$')" "1"
pruef "   ... docs/x.md auf der Lese-Liste" "$(printf '%s\n' "$O2" | grep -c '^    docs/x.md$')" "1"
pruef "   ... a.md (nicht genannt) NICHT auf der Lese-Liste" "$(printf '%s\n' "$O2" | grep -c '^    a.md$')" "0"
pruef "   ... der Rest nur per Grep" "$(printf '%s\n' "$O2" | grep -c 'Dateien der Liste .* NUR per Grep')" "1"
printf '## Befunde\n1. UPDATE `.claude/rules/x.md:3` — veraltet\n' > "$(B8 rules)"; printf '## Befunde\n- ENRICH ZIEL.md:2\n' > "$(B8 custom-context)"
O3=$(AS rules,custom-context)
pruef "letzte Welle: Befunde stehen im Kontext" "$(printf '%s\n' "$O3" | grep -c '^=== BEFUNDE zum Anwenden')" "1"
pruef "   ... die UPDATE-Zeile aus rules" "$(printf '%s\n' "$O3" | grep -c 'UPDATE `.claude/rules/x.md:3`')" "1"
pruef "   ... die ENRICH-Zeile aus custom-context" "$(printf '%s\n' "$O3" | grep -c 'ENRICH ZIEL.md:2')" "1"

echo "=== 9) v5.168.0: genug Turns, Bericht frueh, Anwenden ist die Vorschrift (Anton, Nachtrag 3) ==="
# Voller Lauf 5.167.0: drei von vier KS-Agenten erschoepften 25 Turns ohne Write; „als Sync darf ich nichts aendern“ — 0 angewendet.
pruef "Agent: maxTurns 50" "$(grep -c '^maxTurns: 50' "$AG")" "1"
pruef "Agent: Bericht frueh anlegen" "$(grep -c 'Den Bericht FRUEH anlegen' "$AG")" "1"
pruef "Auftrag: Zwischenstand nach spaetestens 10 Werkzeugaufrufen" "$(printf '%s\n' "$O1" | grep -c 'nach SPAETESTENS 10 Werkzeugaufrufen mit Write als Zwischenstand')" "2"
pruef "mind-all: Anwenden IST die Vorschrift, auch im Rollen-Aufbau" "$(grep -c 'Anwenden IST die Vorschrift — auch im Rollen-Aufbau' "$R/skills/mind-all/SKILL.md")" "1"
pruef "   ... steht in Step 2, vor den fuenf Skills" "$(awk '/^## Step 2: Ausfuehrung je Skill/{s=1} s&&/Anwenden IST die Vorschrift/{print "ja";exit} /^1\. \*\*ZUERST die SKILL.md/{if(s){print "nein";exit}}' "$R/skills/mind-all/SKILL.md")" "ja"
pruef "keine SKILL-Zeile nennt mehr maxTurns 25 als gueltig" "$(grep -c '(`maxTurns`, 25 seit' "$R"/skills/*/SKILL.md | grep -vc ':0$')" "0"

echo "=== 10) v5.169.0: der Auftrag nennt die Session-Quellen — Verlaufsbuch zuerst, Rettungen als Pfad (Nachtrag 5) ==="
# Gegentest 30.10.2026: 5.167.0 nannte nur den Live-Auszug; mit den Quellen fanden rules/memory vier verlorene Befunde.
pruef "ohne Rettung (P8): kein Verlaufsbuch-Punkt" "$(printf '%s\n' "$O1" | grep -c 'ZUERST das Verlaufsbuch')" "0"
pruef "   ... aber der Live-Auszug je Auftrag" "$(printf '%s\n' "$O1" | grep -c '^1\. Live-Auszug: ')" "2"
P10="$TMP/ks rettung"; mkdir -p "$P10/.claude-mind/rescued" "$P10/.claude-mind/verlauf"
printf '## [1] USER\nx\n## [2] ASSISTANT_TEXT\ny\n' > "$P10/.claude-mind/rescued/20261030-010000-111-0000beef_chat.md"
printf '## [1] USER\nz\n' > "$P10/.claude-mind/rescued/20261030-020000-222-0000beef_chat.md"
printf 'path=%s\npath=%s\n' "$P10/.claude-mind/rescued/20261030-010000-111-0000beef_chat.md" "$P10/.claude-mind/rescued/20261030-020000-222-0000beef_chat.md" > "$P10/.claude-mind/rescued/OPEN"
printf '# Verlaufsbuch\n\n## Kompaktierung 2026-10-30 01:00:00 · sid=x · rettung=20261030-010000-111-0000beef\nStand\n' > "$P10/.claude-mind/verlauf/aaaa1111.md"
printf '# P\n' > "$P10/CLAUDE.md"
O10=$( cd "$P10" && env -u PROJ -u LAUF CLAUDE_CODE_SESSION_ID=aaaa1111-0000-0000-0000-00000000beef CLAUDE_PROJECT_DIR="$P10" \
         MIND_LOG_FILE="$TMP/log" bash "$R/skills/mind-update/bloecke/agent-schritt.sh" start memory 2>&1 )
pruef "mit Rettung: Verlaufsbuch ZUERST (Punkt 1)" "$(printf '%s\n' "$O10" | grep -c '^1\. ZUERST das Verlaufsbuch')" "1"
pruef "   ... das Buch mit seinem Abschnitt" "$(printf '%s\n' "$O10" | grep -c "verlauf/aaaa1111.md (.* B) — Abschnitt rettung=20261030-010000-111-0000beef")" "1"
pruef "   ... Rettung ohne Buch-Abschnitt NICHT als Buch" "$(printf '%s\n' "$O10" | grep -c 'Abschnitt rettung=20261030-020000-222-0000beef')" "0"
pruef "   ... beide Rettungen als Pfad mit Bytes und Beitraegen (Punkt 2)" "$(printf '%s\n' "$O10" | grep -cE '^   - .*_chat\.md \([0-9]+ B, [12] Beitraege\)$')" "2"
pruef "   ... mit Groessen-Guard" "$(printf '%s\n' "$O10" | grep -c '^2\. Danach die Rettungen, NUR gezielt per Grep (Groessen-Guard')" "1"
pruef "   ... Live-Auszug als Punkt 3" "$(printf '%s\n' "$O10" | grep -c '^3\. Live-Auszug: ')" "1"
pruef "   ... ⛔ kein Inhalt der Rettung im Auftrag" "$(printf '%s\n' "$O10" | grep -c 'ASSISTANT_TEXT')" "0"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
