#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# v5.175.0 (Etappe 68 N1 Schnitte E und D): das Ende jedes Ketten-Skills ist EIN Block (`mind-all/bloecke/skill-ende.sh`),
# und die Schlussbloecke von /mind-all nennen den naechsten Aufruf woertlich (`WEITER:`).
# Gemessen an Ritas Lauf 20261030-225134: Stichprobe, Quittung, Laufspur, Scope-Marke und Bilanz waren je Skill von Hand
# getippt, der naechste Schritt aus SKILL.md nachgelesen. Gegen 5.174.0 ist jeder Abschnitt rot (Block und Zeilen fehlen).
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R" MIND_KOPF_PFLICHT=aus
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
E="$R/skills/mind-all/bloecke/skill-ende.sh"
P=$(mktemp -d); trap 'rm -rf "${P:?}"' EXIT
mkdir -p "$P/.claude-mind"; echo "snapshot=$P/snap" > "$P/.claude-mind/analyzed-scopes"
ende() { ( cd "$P" && PROJ="$P" LAUF=L1 CLAUDE_PROJECT_DIR="$P" bash "$E" "$@" 2>&1 ); }

echo "=== 1) Aufruffehler und fehlender Bericht ==="
pruef "Block liegt im Paket" "$([ -f "$E" ] && echo ja || echo nein)" "ja"
ende mind-unbekannt >/dev/null; pruef "unbekannter Skill: rc 2" "$?" "2"
ende mind-files >/dev/null; pruef "ohne Bericht: rc 1" "$?" "1"
pruef "ohne Bericht: Quittung fehler:kein-bericht" "$(grep -c 'kein-bericht' "$P/.claude-mind/schritt-quittung.jsonl" 2>/dev/null)" "1"
pruef "ohne Bericht: keine Laufspur" "$(grep -c '^skill=' "$P/.claude-mind/analyzed-scopes")" "0"

echo "=== 2) mit Bericht: Quittung, Laufspur, Scope-Marke, WEITER ==="
for s in mind-claudemd mind-memory mind-rules mind-update; do echo "bericht $s" > "$P/.claude-mind/bericht-$s.md"; done
o=$(ende mind-claudemd); pruef "mind-claudemd: rc 0" "$?" "0"
pruef "Laufspur mit Laufkennung" "$(grep -c '^skill=mind-claudemd|L1$' "$P/.claude-mind/analyzed-scopes")" "1"
pruef "Scope-Marke claude-md" "$(grep -c '^claude-md=mind-claudemd:default$' "$P/.claude-mind/analyzed-scopes")" "1"
pruef "Quittung gelaufen mit Datei" "$(grep '"mind-claudemd"' "$P/.claude-mind/schritt-quittung.jsonl" | grep -c 'gelaufen')" "1"
pruef "WEITER nennt mind-memory" "$(printf '%s' "$o" | grep -c '^WEITER: Skill mind-memory')" "1"
pruef "ohne Zahlen: Stichprobe-Hinweis" "$(printf '%s' "$o" | grep -c 'Stichprobe: keine Zahlen')" "1"
o=$(ende mind-memory); pruef "WEITER: mind-rules mit check migrate" "$(printf '%s' "$o" | grep -c 'mind-rules mit dem Argument "check migrate"')" "1"
pruef "Scope-Marke memory" "$(grep -c '^memory=mind-memory:default$' "$P/.claude-mind/analyzed-scopes")" "1"
ende mind-rules >/dev/null; pruef "mind-rules: KEINE rules-Marke" "$(grep -c '^rules=' "$P/.claude-mind/analyzed-scopes")" "0"
o=$(ende mind-update); pruef "mind-update: WEITER Step 2.9" "$(printf '%s' "$o" | grep -c 'WEITER: .*step2.9-kettenmarke.sh')" "1"

echo "=== 3) Skill-Text und Schlussbloecke ==="
S="$R/skills/mind-all/SKILL.md"
pruef "mind-all SKILL.md ruft skill-ende.sh" "$(grep -c 'bloecke/skill-ende.sh' "$S")" "1"
pruef "Write und Block in DERSELBEN Nachricht" "$(grep -c 'in DERSELBEN Nachricht wie das `Write` des Berichts' "$S")" "1"
for b in step2.9-kettenmarke step2.95-liste step2.95-waechter step2.96-abschluss; do
  pruef "$b nennt den naechsten Aufruf" "$(grep -c '^.*echo "WEITER: ' "$R/skills/mind-all/bloecke/$b.sh")" "1"
done

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
