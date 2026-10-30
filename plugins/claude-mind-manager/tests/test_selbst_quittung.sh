#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Bloecke quittieren ihre Pflichtschritte SELBST, mit Artefakt (v5.162.0, Etappe 63 N3 §3).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): 21 nachgetippte Quittungs-Aufrufe in einem Lauf, jeder ein
#    eigener Schritt (~280k). Die Quittung mit `--datei` ist zugleich die STAERKERE Form: sie nennt das Artefakt.
# Gegen 5.161.0 sind Abschnitt 1 und 2 rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude/rules" "$P/.claude-mind"
printf '# Regel\n- eins\n' > "$P/.claude/rules/a.md"; printf '# Projekt\n' > "$P/CLAUDE.md"
export CLAUDE_CODE_SESSION_ID="aaaa1111-0000-0000-0000-00000000beef"
SQ="$P/.claude-mind/schritt-quittung.jsonl"
q() { grep "\"name\":\"$1\"" "$SQ" 2>/dev/null | tail -1; }

echo "=== 1) Step 5d: drei Werkzeuge, drei Quittungen mit Artefakt ==="
( cd "$P" && PROJ="$P" CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-update/bloecke/step5d-pass.sh" >/dev/null 2>&1 )
for n in mind_kontext_bilanz bestandszahlen_kandidaten cleaner_stichprobe; do
  pruef "$n quittiert" "$(q "$n" | grep -c '"status":"gelaufen"')" "1"
  pruef "  ... mit Datei" "$(q "$n" | grep -c '"quelle":"datei"')" "1"
done

echo "=== 2) Step 0: der Snapshot quittiert sich (MANIFEST) ==="
SN="$P/.claude-mind/snapshots/20261030_010000_pre-mind-all"; mkdir -p "$SN"; printf 'x  y\n' > "$SN/MANIFEST.sha256"
printf 'run_started=%s\nsnapshot=%s\n' "$(date +%s)" "$SN" > "$P/.claude-mind/analyzed-scopes"
( cd "$P" && PROJ="$P" CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-update/bloecke/step0-snapshot.sh" >/dev/null 2>&1 )
pruef "mind_snapshot quittiert mit Datei" "$(q mind_snapshot | grep -c '"quelle":"datei"')" "1"

echo "=== 2b) die vier Einzel-Skills: Bestands-Pass und Snapshot selbst quittiert (v5.163.0) ==="
mkdir -p "$TMP/mem"; printf -- '---
name: x
description: y
---
z
' > "$TMP/mem/x.md"
for s in mind-files mind-claudemd mind-memory mind-rules; do
  rm -f "$SQ"
  ( cd "$P" && PROJ="$P" MEMORY_DIR="$TMP/mem" CLAUDE_PROJECT_DIR="$P" bash "$R/skills/$s/bloecke/pass-bestand.sh" >/dev/null 2>&1 )
  n=0; for w in mind_kontext_bilanz bestandszahlen_kandidaten cleaner_stichprobe; do q "$w" | grep -q '"quelle":"datei"' && n=$((n+1)); done
  pruef "$s: drei Pass-Quittungen mit Datei" "$n" "3"
  ( cd "$P" && PROJ="$P" CLAUDE_PROJECT_DIR="$P" bash "$R/skills/$s/bloecke/02-step0-modus-snapshot.sh" >/dev/null 2>&1 )
  pruef "$s: mind_snapshot quittiert" "$(q mind_snapshot | grep -c '"name":"mind_snapshot"')" "1"
  pruef "$s: Hinweis im Skilltext" "$(grep -c 'Selbst quittiert, NICHT nachtippen' "$R/skills/$s/SKILL.md")" "1"
done

echo "=== 3) der Skill sagt, was NICHT nachgetippt wird ==="
pruef "Hinweis im Skilltext" "$(grep -c 'Selbst quittiert, NICHT nachtippen' "$R/skills/mind-update/SKILL.md")" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
