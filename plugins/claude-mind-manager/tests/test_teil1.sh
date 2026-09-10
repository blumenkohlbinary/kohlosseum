#!/bin/bash
# Pruefstand fuer den 800k-Ablauf (Teil 1, v5.7.0).
#
# Die Fragen, die zaehlen:
#   1. Schlaegt die Schwelle EXAKT an der Grenze um (799999 still, 800000 laut)?
#   2. Liefert ein Transkript OHNE usage "keine Aussage" — und NICHT 0?
#   3. Schweigt alles, solange sync-stand liegt?
#   4. Uebergibt prompt-submit den Arbeitsstand nach einer Kompaktierung?
#   5. Bleibt der Schuld-Zwang funktionsfaehig, wenn die Token-Erweiterung ausfaellt?

# Respektiert eine bereits gesetzte Wurzel. Bis v5.7.5 stand hier eine harte Zuweisung
# auf den QUELLBAUM — damit lief diese Sammlung nie am gebauten Paket, entgegen ihrer
# eigenen README und entgegen fertig-heisst-fertig.md 1.
export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"
H="$CLAUDE_PLUGIN_ROOT/hooks"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

T=$(mktemp -d)
mkdir -p "$T/proj/.claude-mind/rescued"

# Transkript mit GENAU n Tokens bauen (input + cache_creation + cache_read)
mach_transkript() {   # $1 = Zieldatei, $2 = Tokenzahl
  printf '{"type":"user","message":{"content":"x"}}\n' > "$1"
  printf '{"type":"assistant","message":{"usage":{"input_tokens":2,"cache_creation_input_tokens":8,"cache_read_input_tokens":%d,"output_tokens":50}}}\n' \
    $(( $2 - 10 )) >> "$1"
}

ruf_prompt() {        # $1 = transcript, gibt stdout zurueck
  printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","session_id":"S1","transcript_path":"%s","prompt":"weiter"}' \
    "$T/proj" "$1" | bash "$H/prompt-submit.sh" 2>/dev/null
}
ruf_stop() {
  printf '{"hook_event_name":"Stop","cwd":"%s","session_id":"S1","transcript_path":"%s","stop_hook_active":false}' \
    "$T/proj" "$1" | bash "$H/stop.sh" 2>/dev/null
}

export MIND_SYNC_AT_TOKENS=800000
export MIND_SYNC_FORCE_TOKENS=840000
export CLAUDE_PROJECT_DIR="$T/proj"

echo "=== 1 · ⛔ ES GIBT KEINE MAHN-SCHWELLE MEHR (v5.65.0) ==="
# ⛔ Nutzer-Entscheidung 10.09.2026: "die sollen garnicht mehr tokens messen
#    das soll komplett raus". Hier standen drei Faelle ueber den Umschlagpunkt
#    799 999 / 800 000 und drei weitere in Abschnitt 2 und 4.
#
# ⭐ DER STAERKSTE FALL DER SAMMLUNG STEHT OBEN IM KOPF: `MIND_SYNC_AT_TOKENS`
#    und `MIND_SYNC_FORCE_TOKENS` bleiben GESETZT. Selbst mit gesetztem Regler
#    und einem Transkript weit ueber der alten Schwelle passiert nichts mehr.
#    Ein Fall, der die Regler vorher leert, wuerde das nicht messen.
# ⛔ GEGEN DEN ALTEN STAND ROT.
mach_transkript "$T/t799.jsonl" 799999
mach_transkript "$T/t800.jsonl" 800000
mach_transkript "$T/t950.jsonl" 950000
pruef "799 999 -> still"                      "$(ruf_prompt "$T/t799.jsonl" | grep -c '/mind-all')" "0"
pruef "⛔ 800 000 -> AUCH still"               "$(ruf_prompt "$T/t800.jsonl" | grep -c '/mind-all')" "0"
pruef "⛔ 950 000 -> immer noch still"         "$(ruf_prompt "$T/t950.jsonl" | grep -c '/mind-all')" "0"
pruef "⛔ und keine Zahl in der Ausgabe"       "$(ruf_prompt "$T/t950.jsonl" | grep -c '950000')" "0"

echo
echo "=== 2 · ⛔ Weder Zwang noch Mahnung — stop.sh schweigt ganz ==="
# ⛔ v5.55.0 nahm den Block, v5.65.0 die Mahnung. Die alte Zusicherung
#    "840 000 -> die Mahnung kommt weiter" hat damit ihr Ziel verloren.
# ⭐ WOHIN SIE GING: nirgendwohin, und das ist die Entscheidung. Gemahnt wird
#    an ARBEIT statt an Fuellstand — offene Schuld (Abschnitt 6) und der
#    Commit-Zaehler in prompt-submit.sh. Beides misst, was getan wurde.
mach_transkript "$T/t840.jsonl" 840000
pruef "839 999 -> kein Block" "$(ruf_stop "$T/t839.jsonl" | grep -c 'decision')" "0"
pruef "⛔ 840 000 -> kein Block" "$(ruf_stop "$T/t840.jsonl" | grep -c 'decision')" "0"
pruef "⛔ 840 000 -> auch keine Mahnung" "$(ruf_prompt "$T/t840.jsonl" | grep -c '/mind-all')" "0"
mach_transkript "$T/t839.jsonl" 839999

echo "=== 3 · Transkript OHNE usage -> KEINE Aussage, nicht 0 ==="
printf '{"type":"user"}\n{"foo":1}\n' > "$T/leer.jsonl"
pruef "kein usage -> keine Mahnung" "$(ruf_prompt "$T/leer.jsonl" | grep -c 'Token')" "0"
pruef "kein usage -> kein Block"    "$(ruf_stop  "$T/leer.jsonl" | grep -c 'decision')" "0"
pruef "fehlendes Transkript -> still" "$(ruf_prompt "$T/gibtsnicht.jsonl" | grep -c 'Token')" "0"

echo
echo "=== 4 · ⛔ sync-stand entscheidet nichts mehr ueber Tokens ==="
# ⛔ HIER STANDEN VIER FAELLE ueber `mind_sync_frisch` (frisch = still,
#    verbraucht = laut, gemessen am ZUWACHS). Die Funktion ist in v5.65.0
#    entfallen; ohne `tokens=` im Merker konnte sie nur noch EINE Antwort
#    geben, und ihr einziger Aufrufer war die Token-Mahnung.
#
# ⭐ WAS DER MERKER NOCH TUT: er sagt `pre-compact.sh`, ob ein VOLLER Sync
#    lief (`umfang=`/`ungepruef=`) — sonst entsteht dort eine Schuld. Das ist
#    `mind_sync_voll`, abgesichert in tests/test_teilsync.sh Abschnitt A und C.
# ⚠ WAS AUFHOERT: der Merker loest sich nicht mehr selbst auf. Verbraucht
#   wird er von pre-compact.sh — der Zustand von v5.7.0 bis v5.10.0.
SS="$T/proj/.claude-mind/rescued/sync-stand"

# ⛔ Ein Merker mit ALTEM Inhalt (tokens=) darf nichts mehr bewirken — in
#   KEINE Richtung. Das ist die Umkehrung beider alten Faelle in einem.
printf 'ts=jetzt\ntokens=700000\n' > "$SS"           # 140k Zuwachs: mahnte frueher
pruef "⛔ Alt-Merker mit tokens= -> trotzdem still" "$(ruf_prompt "$T/t840.jsonl" | grep -c '/mind-all')" "0"
printf 'ts=2026-08-21 08:00:00\n' > "$SS"             # ohne Zahl: mahnte frueher
pruef "⛔ Merker ohne tokens= -> trotzdem still"    "$(ruf_prompt "$T/t840.jsonl" | grep -c '/mind-all')" "0"
pruef "⛔ und kein Block"                          "$(ruf_stop  "$T/t840.jsonl" | grep -c 'decision')" "0"

rm -f "$SS"

echo "=== 5 · Uebergabe nach der Kompaktierung ==="
cat > "$T/proj/.claude-mind/rescued/as.json" <<'JSON'
{"total_events": 42, "top_n": 5, "long_session": false,
 "decisions": [{"line": 1, "text": "Der Sync laeuft ab v5.7.0 VOR der Kompaktierung."}],
 "decisions_total": 1,
 "bugs": [], "bugs_total": 0,
 "constraints": [{"line": 2, "text": "Nie eine Umgebungsvariable still setzen."}],
 "constraints_total": 1,
 "files": [], "files_total": 0, "files_weg": 0}
JSON
printf '## Zuletzt beauftragt\n\n1. Den Debug-Ordner bauen\n' > "$T/proj/.claude-mind/rescued/rs.md"
printf 'ts=X\narbeitsstand=%s\nresume=%s\n' \
  "$T/proj/.claude-mind/rescued/as.json" "$T/proj/.claude-mind/rescued/rs.md" \
  > "$T/proj/.claude-mind/rescued/UEBERGABE"
AUS=$(ruf_prompt "$T/t800.jsonl")
pruef "Arbeitsstand wird injiziert"  "$(echo "$AUS" | grep -c 'kompaktiert')" "1"
pruef "Entscheidung taucht auf"      "$(echo "$AUS" | grep -c 'VOR der Kompaktierung')" "1"
pruef "Auftrag taucht auf"           "$(echo "$AUS" | grep -c 'Debug-Ordner bauen')" "1"
pruef "Merker danach verbraucht"     "$([ -f "$T/proj/.claude-mind/rescued/UEBERGABE" ] && echo da || echo weg)" "weg"

echo
echo "=== 6 · GEGENPROBE: Token-Erweiterung faellt aus, Schuld-Zwang bleibt ==="
printf 'path=%s\nresume=%s\nevents=99\nblocks=0\n' "$T/proj/.claude-mind/rescued/chat.md" \
  "$T/proj/.claude-mind/rescued/rs.md" > "$T/proj/.claude-mind/rescued/OPEN"
printf 'x\n' > "$T/proj/.claude-mind/rescued/chat.md"
ALT="$CLAUDE_PLUGIN_ROOT"
export CLAUDE_PLUGIN_ROOT="/pfad/den/es/nicht/gibt"     # lib.sh unerreichbar
# ⛔ v5.55.0: es gibt keinen Zwang mehr, der ueberleben koennte. Was bleibt,
#    ist die FAIL-OPEN-Eigenschaft: stop.sh laeuft auch mit unerreichbarer
#    lib.sh sauber durch (Rueckgabe 0) und stuerzt nicht ab. Er ist der Hook,
#    der am Turn-Ende die Kontext-Wache ruft — ein Absturz hier waere teurer
#    als alles, was er meldet.
ruf_stop "$T/t840.jsonl" >/dev/null 2>&1
pruef "ohne lib.sh: stop.sh laeuft sauber durch" "$?" "0"
pruef "und gibt dabei nichts aus" "$(ruf_stop "$T/t840.jsonl" 2>/dev/null | wc -c | tr -d ' ')" "0"
export CLAUDE_PLUGIN_ROOT="$ALT"

rm -rf "$T"
echo
echo "=================================="
echo "  $ok bestanden, $rot rot"
[ "$rot" -eq 0 ]
