#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# mind-update Step 1.5: fuenf grep UEBER ALLE Dateien statt fuenf JE Datei (v5.149.0, Etappe 57 §2).
#
# ⛔ GEMESSEN 28.10.2026: dieser Workspace 84,4 s -> 4,1 s, Zustellplan 24,2 s -> 1,7 s, die Liste
#    in beiden Projekten BYTEWEISE gleich (alter gegen neuen Block, dieselbe Eingabe).
# ⭐ Der Prueffall faehrt die Bloecke AUS DEM SKILL.md, nicht eine Kopie — und den Fall mit genau
#    EINER Kandidatin: ohne `-H` schreibt grep bei einer Datei keinen Namen, und jeder Wert waere 0.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
S="$R/skills/mind-update/SKILL.md"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Die bash-Bloecke zwischen „## Step 1.5:" und „## Step 2:"
tr -d '\r' < "$S" | awk '/^## Step 1\.5:/{a=1} /^## Step 2:/{a=0} a' \
  | awk '/^```bash/{f=1; next} /^```/{f=0; next} f' > "$TMP/step15.sh"
pruef "Step-1.5-Bloecke gefunden" "$([ -s "$TMP/step15.sh" ] && echo ja || echo nein)" "ja"
pruef "⛔ Bauform: kein grep je Datei mehr (\"\$f\" als grep-Ziel)" "$(grep -c 'grep -c[A-Z]* .* "\$f"' "$TMP/step15.sh")" "0"
pruef "Bauform: grep ueber die Liste, mit -H"   "$( [ "$(grep -c 'xargs -0 grep -cH' "$TMP/step15.sh")" -ge 5 ] && echo ja || echo nein)" "ja"

lauf() {  # $1 = Projektordner -> Liste der Custom-Context-Dateien
  ( cd "$1" && MEMORY_MAIN="" TOPIC_FILES="" PROJECT_RULES="" GLOBAL_RULES="" bash -c \
      ". '$TMP/step15.sh' >/dev/null 2>&1; printf '%s\n' \"\${CUSTOM_CONTEXT_FILES[@]}\"" ) | grep .
}

echo "=== 1) mehrere Kandidaten: wer Punkte hat, kommt hinein ==="
P="$TMP/p1"; mkdir -p "$P/docs"
printf '# A\n\n```\nx\n```\nStand v1.2 in `docs/b.md`\n' > "$P/docs/a.md"     # score >= 2
printf '# B\n\nnur Prosa ohne Merkmale\n'                        > "$P/docs/b.md" # score 0
L=$(lauf "$P")
pruef "a.md ist Custom Context"    "$(printf '%s\n' "$L" | grep -c 'docs/a.md')" "1"
pruef "b.md ist es nicht"          "$(printf '%s\n' "$L" | grep -c 'docs/b.md')" "0"

echo "=== 2) ⛔ genau EINE Kandidatin — der Fall, an dem ein fehlendes -H alles auf 0 setzt ==="
P="$TMP/p2"; mkdir -p "$P/docs"
printf '# A\n\n```\nx\n```\nStand v1.2 in `docs/b.md`\n' > "$P/docs/a.md"
L=$(lauf "$P")
pruef "die eine Datei wird erkannt" "$(printf '%s\n' "$L" | grep -c 'docs/a.md')" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
