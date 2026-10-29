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
S="$(skill_text_datei "$R" mind-update)"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ⭐ v5.153.0: Step 1 + 1.5 sind das Skript bloecke/step1-dateien.sh — gefahren wird das ECHTE Skript,
#    die Liste kommt aus der Sitzungsdatei (wie im Lauf). Ohne Skript: die Bloecke zwischen
#    „## Step 1.5:" und „## Step 2:" wie bisher (Gegenprobe gegen den alten Stand).
SKRIPT="$R/skills/mind-update/bloecke/step1-dateien.sh"
if [ -f "$SKRIPT" ]; then
  tr -d '\r' < "$SKRIPT" > "$TMP/step15.sh"
else
tr -d '\r' < "$S" | awk '/^## Step 1\.5:/{a=1} /^## Step 2:/{a=0} a' \
  | awk '/^```bash/{f=1; next} /^```/{f=0; next} f' > "$TMP/step15.sh"
fi
pruef "Step-1.5-Bloecke gefunden" "$([ -s "$TMP/step15.sh" ] && echo ja || echo nein)" "ja"
pruef "⛔ Bauform: kein grep je Datei mehr (\"\$f\" als grep-Ziel)" "$(grep -c 'grep -c[A-Z]* .* "\$f"' "$TMP/step15.sh")" "0"
pruef "Bauform: grep ueber die Liste, mit -H"   "$( [ "$(grep -c 'xargs -0 grep -cH' "$TMP/step15.sh")" -ge 5 ] && echo ja || echo nein)" "ja"

lauf() {  # $1 = Projektordner -> Liste der Custom-Context-Dateien
  if [ -f "$SKRIPT" ]; then
    ( cd "$1" && CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="$R" CLAUDE_CODE_SESSION_ID=pruef-1 \
        MIND_LOG_FILE="$TMP/log" bash "$SKRIPT" >/dev/null 2>&1
      cat "$1/.claude-mind/sampler/mind-update-ccf.pruef.txt" 2>/dev/null ) | grep .
    return
  fi
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

echo "=== 3) ⛔ v5.150.0: ein Pfad MIT LEERZEICHEN wird bewertet (vorher in Stuecke zerlegt, nie bewertet) ==="
P="$TMP/p3"; mkdir -p "$P/docs"
printf '# A\n\n```\nx\n```\nStand v1.2 in `docs/b.md`\n' > "$P/docs/recherche 1.md"
L=$(lauf "$P")
pruef "docs/recherche 1.md ist Custom Context" "$(printf '%s\n' "$L" | grep -cxF './docs/recherche 1.md')" "1"

echo "=== 4) ein GLOB-Verweis holt weiter seine Dateien — aber nie aus .claude-mind/ ==="
P="$TMP/p4"; mkdir -p "$P/wissen" "$P/.claude-mind/rescued"
printf '# P\n\nWissen: `wissen/*-funktion.md` und `.claude-mind/rescued/*_chat.md`.\n' > "$P/CLAUDE.md"
printf 'nur Prosa\n' > "$P/wissen/a-funktion.md"; printf 'nur Prosa\n' > "$P/wissen/b-funktion.md"
printf 'ein geretteter Chat\n' > "$P/.claude-mind/rescued/x_chat.md"
L=$(lauf "$P")
pruef "beide Glob-Treffer drin (ohne Heuristik-Punkte)" "$(printf '%s\n' "$L" | grep -c 'wissen/.-funktion.md')" "2"
pruef "⛔ kein geretteter Chat als Custom Context"     "$(printf '%s\n' "$L" | grep -c '_chat.md')" "0"

echo "=== 5) ⛔ v5.153.0: die Agent-Quittung (3.5) LIEST die Liste — im eigenen Prozess war das Array leer ==="
if [ -f "$SKRIPT" ]; then
  pruef "3.5 laedt CUSTOM_CONTEXT_FILES aus der Sitzungsdatei" \
    "$(grep -c 'mapfile -t CUSTOM_CONTEXT_FILES < "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)"' "$(skill_text_datei "$R" mind-update)")" "1"
  pruef "der Agenten-Auftrag serialisiert die Datei, nicht das leere Array" \
    "$(grep -c '^cat "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)"' "$(skill_text_datei "$R" mind-update)")" "1"
fi

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
