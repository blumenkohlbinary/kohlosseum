#!/usr/bin/env bash
# =============================================================================
#  VERDICHTEN — das Gate nach dem Agenten  (NEU v5.78.0)
# =============================================================================
#
# ⛔ WOZU. Nutzer-Auftrag 10.09.2026: "alle duerfen kuerzen". Die Hand ist ein
#    Agent je Datei; `mind_verdichtung_pruefen` entscheidet, ob sein Ergebnis
#    angewendet wird. Vier Faelle, von Anton verlangt:
#
#      1 POSITIV    die Kalibrierung vom 11.09.2026 -> anwenden
#      2 NEGATIV    verschieben statt kuerzen -> VERWERFEN
#      3 0-B        nichts entfernt -> Stufe 2 sagt "0 B" statt zu schweigen
#      4 MARKER     ⛔ entfernt und BENANNT -> gruen · entfernt, unbenannt -> rot
#
# ⭐ Fall 2 ist der Grund fuer das ganze Gate: ein Lauf, der 40 Zeilen von
#    einer immer-ladenden Datei in eine andere schiebt, hat 0 erreicht — und
#    sah bis heute wie ein Erfolg aus (Modularize, seit v5.0.0).
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB="$WURZEL/hooks/lib.sh"
export CLAUDE_PLUGIN_ROOT="$WURZEL"

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-58s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-58s ist=%-12s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}
[ -f "$LIB" ] || { echo "ABBRUCH: $LIB fehlt"; exit 2; }
# shellcheck disable=SC1090
. "$LIB" >/dev/null 2>&1

D=$(mktemp -d "${TMPDIR:-/tmp}/verdXXXXXX") || exit 2

# ⛔ Prueftexte in DATEIEN, nie in echo — Backticks werden sonst ausgefuehrt.
cat > "$D/orig.md" <<'EOF'
# Regel

⛔ NIE ohne Sicherung loeschen. Das ist am 21.08.2026 gemessen worden, als von sieben
Snapshots die alte Rotation null loeschte und die Sicherungen 32 MB gross wurden.

⚠ Die Rotation haelt nur drei Staende. Wer mehr will, setzt die Variable, aber nicht ohne Grund.

⭐ Der Aufruf ist `tools/rollback.py list`, und er zeigt beide Ablagen, die es gibt.

Ein erklaerender Satz ganz ohne Marke, der nur sagt, warum das alles so ist.
EOF

lauf() { mind_verdichtung_pruefen "$D/orig.md" "$1" "${2:-}" probe.md 2>&1; }
rc_von() { mind_verdichtung_pruefen "$D/orig.md" "$1" "${2:-}" probe.md >/dev/null 2>&1; echo $?; }

echo "=============================================================================="
echo "  1) POSITIV — kuerzer, alle Marken da, Stufe 1 voll -> anwenden"
echo "=============================================================================="
cat > "$D/gut.md" <<'EOF'
# Regel

⛔ NIE ohne Sicherung loeschen — gemessen 21.08.2026: sieben Snapshots, null geloescht, 32 MB.

⚠ Die Rotation haelt nur drei Staende; mehr nur mit Grund.

⭐ Der Aufruf ist `tools/rollback.py list`, er zeigt beide Ablagen.

Ein Satz ohne Marke, der sagt, warum das so ist.
EOF
janein "Rueckgabe 0 (anwenden)" "0" "$(rc_von "$D/gut.md")"
janein "der Bericht hat die drei Zeilen: Dauerkontext / Stufe 1 / Stufe 2" "3" \
  "$(lauf "$D/gut.md" | grep -cE 'Dauerkontext  |Stufe 1       coverage|Stufe 2       markenfrei')"
janein "⚠ und den Zusatz 'nur GROESSENORDNUNG' zu Stufe 2" "ja" \
  "$(lauf "$D/gut.md" | grep -q 'GROESSENORDNUNG' && echo ja || echo nein)"
janein "die Marker-Zeile nennt alle vier Zaehlungen" "ja" \
  "$(lauf "$D/gut.md" | grep -qE 'Marker ⛔ 1->1 · ⚠ 1->1 · ⭐ 1->1 · VERBOT' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  2) ⛔ NEGATIV — verschoben statt gekuerzt: Ergebnis NICHT kleiner -> verwerfen"
echo "=============================================================================="
# Der Modularize-Fall: der Text ist umgestellt, aber nicht weniger.
cp "$D/orig.md" "$D/gleich.md"
janein "⛔ gleich gross -> Rueckgabe 1" "1" "$(rc_von "$D/gleich.md")"
janein "   ... und der Grund steht da: 'nicht kleiner'" "ja" \
  "$(lauf "$D/gleich.md" | grep -q 'VERWERFEN: nicht kleiner' && echo ja || echo nein)"
printf '\n\nNoch ein Absatz, der dazukam.\n' >> "$D/gleich.md"
janein "⛔ GROESSER -> ebenfalls 1" "1" "$(rc_von "$D/gleich.md")"

echo
echo "=============================================================================="
echo "  3) 0-B — nichts entfernt: Stufe 2 sagt es, statt zu schweigen"
echo "=============================================================================="
cp "$D/orig.md" "$D/null.md"
janein "Stufe 2 nennt '0 B' ausdruecklich" "ja" \
  "$(lauf "$D/null.md" | grep -q 'markenfrei entfernt 0 B' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  4) MARKER — entfernt und BENANNT gruen, entfernt und unbenannt rot"
# ⛔ GELERNT beim ersten Lauf dieses Falls: BENENNEN entlastet nur die MARKER-
#    Zaehlung, nicht Stufe 1. Trug der entfernte Absatz einen Code-Span oder
#    eine Zahl, ist das ein Stufe-1-Verlust und bleibt rot — zu Recht. Die
#    Fixture stellt deshalb einen ⚠-Absatz OHNE andere Marke.
echo "=============================================================================="
# Der ⚠-Absatz faellt ganz weg. Kuerzer ist es damit auf jeden Fall.
cat > "$D/weg.md" <<'EOF'
# Regel

⛔ NIE ohne Sicherung loeschen — gemessen 21.08.2026: sieben Snapshots, null geloescht, 32 MB.

⭐ Der Aufruf ist `tools/rollback.py list`, er zeigt beide Ablagen.

Ein Satz ohne Marke.
EOF
janein "⛔ ⚠ entfernt, KEIN Bericht -> Rueckgabe 1" "1" "$(rc_von "$D/weg.md")"
janein "   ... und die Ausgabe sagt MARKER VERLOREN" "ja" \
  "$(lauf "$D/weg.md" | grep -q 'MARKER VERLOREN' && echo ja || echo nein)"
printf 'entfernt: ⚠ „Die Rotation haelt nur KEEP=3“\n' > "$D/bericht.md"
janein "⭐ derselbe Verlust, im Bericht BENANNT -> Rueckgabe 0" "0" "$(rc_von "$D/weg.md" "$D/bericht.md")"
janein "   ... Marker-Zeile zeigt '(benannt 1)'" "ja" \
  "$(lauf "$D/weg.md" "$D/bericht.md" | grep -q 'benannt 1' && echo ja || echo nein)"
# ⛔ Und ein BENANNTES ⚠ deckt kein verlorenes ⛔.
printf 'entfernt: ⚠ „irgendwas“\n' > "$D/falsch.md"
sed -i 's/^⛔ NIE/NIE/' "$D/weg.md"
janein "⛔ benanntes ⚠ deckt kein verlorenes ⛔ -> Rueckgabe 1" "1" "$(rc_von "$D/weg.md" "$D/falsch.md")"
# ⛔ v5.79.0: eine Benennung wird ABGEGLICHEN, nicht nur gezaehlt. Gemessen am
#    ersten echten Lauf (hooks.md, 11.09.2026): der Agent benannte zwei ⚠ als
#    entfernt, die nur UMFORMULIERT waren — das Gate war zufrieden. Eine
#    Ueberbenennung koennte so einen echten Verlust decken.
cp "$D/orig.md" "$D/noch.md"
sed -i '/^⚠ Die Rotation/,/^$/d' "$D/noch.md"          # ⚠ weg …
printf 'entfernt: ⚠ „Der Aufruf ist“
' > "$D/leer.md"     # … aber der ⭐-Absatz benannt, der noch da ist
janein "⛔ Benennung eines NOCH VORHANDENEN Absatzes deckt nichts -> Rueckgabe 1" "1" "$(rc_von "$D/noch.md" "$D/leer.md")"
janein "   ... und die Ausgabe sagt BENENNUNG LEER" "ja"   "$(lauf "$D/noch.md" "$D/leer.md" | grep -q 'BENENNUNG LEER' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  4b) v5.83.0: Stufe 3 steht als PFLICHT in der Vorschrift und im Traeger"
echo "=============================================================================="
janein "bestands-pass.md: 'STUFE 3 IST PFLICHT'" "ja" "$(grep -q 'STUFE 3 IST PFLICHT' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
janein "bestands-pass.md: ohne Stufe 3 wird NICHT angewendet" "ja" "$(grep -q 'ohne Stufe 3 wendet NICHT an' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
janein "bestands-pass.md: der Aufrufer-Satz (Ertrag)" "ja" "$(grep -q 'Ertrag hängt am AUFRUFER' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
# v5.99.0: die Schwelle steht VOR dem Lauf — ein bezahltes, korrektes Ergebnis wird nicht mehr verworfen
janein "bestands-pass.md: Ertragsschwelle VOR dem Lauf, nie hinter dem Urteil (v5.99.0)" "ja" "$(grep -q 'Ertragsschwelle steht VOR dem Lauf, nie hinter dem Urteil' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
janein "bestands-pass.md: bezahlt heisst anwenden, auch bei 2 %" "ja" "$(grep -q 'auch wenn es 2 % sind' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
# v5.100.0: das Ergebnis ist eine DATEI — der Agent schreibt .nachher.md, Anwenden ist cp, nie nachtippen
janein "bestands-pass.md: ERGEBNIS = verdichten-<skill>.nachher.md, vom Agenten geschrieben" "ja" "$(grep -q 'verdichten-<skill>.nachher.md' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
janein "bestands-pass.md: NIE NACHTIPPEN" "ja" "$(grep -q 'NIE NACHTIPPEN' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"
janein "alle fuenf Traeger nennen die .nachher.md-Datei" "5" "$(grep -l 'verdichten-mind-[a-z]*\.nachher\.md' "$WURZEL"/skills/mind-{claudemd,files,memory,rules,update}/SKILL.md | wc -l | tr -d ' ')"
janein "mind-rules Step 9b: Stufe 3 vor dem Anwenden" "ja" "$(grep -q 'STUFE 3 (Wort-Diff lesen' "$WURZEL/skills/mind-rules/SKILL.md" && echo ja || echo nein)"
# v5.85.0: zweiter Traeger mind-claudemd — mit den CLAUDE.md-eigenen Unantastbaren
janein "mind-claudemd: Step 5e VERDICHTEN vorhanden" "ja" "$(grep -q '^## Step 5e: .*VERDICHTEN' "$WURZEL/skills/mind-claudemd/SKILL.md" && echo ja || echo nein)"
janein "mind-claudemd: Pipeline vorher/nachher als Gate" "ja" "$(grep -q 'kein Check neu rot' "$WURZEL/skills/mind-claudemd/SKILL.md" && echo ja || echo nein)"
janein "mind-claudemd: Stufe 3 vor dem Anwenden" "ja" "$(grep -q 'STUFE 3 (Wort-Diff lesen' "$WURZEL/skills/mind-claudemd/SKILL.md" && echo ja || echo nein)"
janein "mind-claudemd: verdichten als PFLICHTSCHRITT und in mind_schritt_start" "2" "$(grep -cE '^verdichten$|^mind_schritt_start .* verdichten' "$WURZEL/skills/mind-claudemd/SKILL.md")"
# v5.89.0: dritter Traeger mind-memory — Frontmatter und [[Verweise]] unantastbar, MEMORY.md nie
janein "mind-memory: Step 6e VERDICHTEN vorhanden" "ja" "$(grep -q '^## Step 6e: .*VERDICHTEN' "$WURZEL/skills/mind-memory/SKILL.md" && echo ja || echo nein)"
janein "mind-memory: MEMORY.md ist nie Kandidatin" "ja" "$(grep -q "grep -v '/MEMORY\\\\.md\$'" "$WURZEL/skills/mind-memory/SKILL.md" && echo ja || echo nein)"
janein "mind-memory: Frontmatter und Wikilinks unantastbar, Stufe 3 Pflicht" "2" "$(grep -cE 'Frontmatter \(`---`|STUFE 3 \(Wort-Diff lesen' "$WURZEL/skills/mind-memory/SKILL.md")"
janein "mind-memory: verdichten als PFLICHTSCHRITT und in mind_schritt_start" "2" "$(grep -cE '^verdichten$|^mind_schritt_start .* verdichten' "$WURZEL/skills/mind-memory/SKILL.md")"
# v5.90.0: vierter Traeger mind-update — ersetzt "Lossless Compression" (Kuerzen ohne Gate)
janein "mind-update: Step 5 ist VERDICHTEN, nicht mehr Lossless Compression" "ja" "$(grep -q '^## Step 5: .*VERDICHTEN' "$WURZEL/skills/mind-update/SKILL.md" && ! grep -q '^## Step 5: Lossless Compression' "$WURZEL/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: Stufe 3 vor dem Anwenden" "ja" "$(grep -q 'STUFE 3 (Wort-Diff lesen' "$WURZEL/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: verdichten als PFLICHTSCHRITT und in mind_schritt_start" "2" "$(grep -cE '^verdichten$|^mind_schritt_start .* verdichten' "$WURZEL/skills/mind-update/SKILL.md")"
janein "⭐ alle Datei-Traeger merken 'verdichtet=' in analyzed-scopes (nie dieselbe Datei zweimal je Kette)" "4" \
  "$(grep -l 'echo "verdichtet=$DATEI" >> "$PROJ/.claude-mind/analyzed-scopes"' "$WURZEL"/skills/mind-rules/SKILL.md "$WURZEL"/skills/mind-claudemd/SKILL.md "$WURZEL"/skills/mind-update/SKILL.md "$WURZEL"/skills/mind-files/SKILL.md | wc -l | tr -d ' ')"
# v5.91.0: fuenfter Traeger mind-files — nur die eigenen Companion-Rules, Tool->Rule-Nachweis als Gate
janein "mind-files: Step 5g VERDICHTEN vorhanden" "ja" "$(grep -q '^## Step 5g: .*VERDICHTEN' "$WURZEL/skills/mind-files/SKILL.md" && echo ja || echo nein)"
janein "mind-files: mind_check_tools_have_rules als Gate nach dem Lauf" "ja" "$(grep -q 'mind_check_tools_have_rules "$PROJ" auf das ERGEBNIS' "$WURZEL/skills/mind-files/SKILL.md" && echo ja || echo nein)"
janein "mind-files: verdichten als PFLICHTSCHRITT und in mind_schritt_start" "2" "$(grep -cE '^verdichten$|^mind_schritt_start .* verdichten' "$WURZEL/skills/mind-files/SKILL.md")"
janein "⭐ ZIEL 4: alle fuenf Context-Skills tragen 'verdichten' als PFLICHTSCHRITT" "5" \
  "$(grep -l '^verdichten$' "$WURZEL"/skills/mind-rules/SKILL.md "$WURZEL"/skills/mind-claudemd/SKILL.md "$WURZEL"/skills/mind-memory/SKILL.md "$WURZEL"/skills/mind-update/SKILL.md "$WURZEL"/skills/mind-files/SKILL.md | wc -l | tr -d ' ')"
janein "   ... und alle fuenf den Lister" "5" \
  "$(grep -l 'references/bestandszahlen_kandidaten.py' "$WURZEL"/skills/mind-rules/SKILL.md "$WURZEL"/skills/mind-claudemd/SKILL.md "$WURZEL"/skills/mind-memory/SKILL.md "$WURZEL"/skills/mind-update/SKILL.md "$WURZEL"/skills/mind-files/SKILL.md | wc -l | tr -d ' ')"

echo
echo "=============================================================================="
echo "  4c) v5.84.0: ZEILENENDEN — die Form muss bleiben (Antons Befund: die Hand schrieb CRLF)"
echo "=============================================================================="
# gut.md ist LF und kleiner -> gruen. Dieselbe Datei als CRLF -> rot, obwohl Stufe 1/2 gleich.
sed 's/$/\r/' "$D/gut.md" > "$D/gut-crlf.md"          # LF -> CRLF (GNU sed)
janein "Fixture: gut-crlf.md ist wirklich CRLF" "CRLF" "$(_mind_ze_form "$(mind_zeilenenden "$D/gut-crlf.md")")"
janein "LF-Original, LF-Ergebnis -> anwenden (0)" "0" "$(rc_von "$D/gut.md")"
janein "⛔ LF-Original, CRLF-Ergebnis -> VERWERFEN (1)" "1" "$(rc_von "$D/gut-crlf.md")"
janein "   ... und die Ausgabe nennt 'Zeilenenden geaendert'" "ja" "$(lauf "$D/gut-crlf.md" | grep -q 'Zeilenenden geaendert' && echo ja || echo nein)"
# umgekehrt: CRLF-Original bleibt CRLF -> gruen
sed 's/$/\r/' "$D/orig.md" > "$D/orig-crlf.md"
janein "CRLF-Original, CRLF-Ergebnis -> anwenden (0)" "0" "$(mind_verdichtung_pruefen "$D/orig-crlf.md" "$D/gut-crlf.md" "" probe.md >/dev/null 2>&1; echo $?)"
janein "⛔ CRLF-Original, LF-Ergebnis -> VERWERFEN (1)" "1" "$(mind_verdichtung_pruefen "$D/orig-crlf.md" "$D/gut.md" "" probe.md >/dev/null 2>&1; echo $?)"

echo
echo "=============================================================================="
echo "  5) NICHT MESSBAR ist kein bestandenes Gate"
echo "=============================================================================="
janein "fehlendes Ergebnis -> Rueckgabe 3" "3" "$(rc_von "$D/gibtsnicht.md")"

# --- 6) Die ECHTE Kalibrierung, wenn der Workspace erreichbar ist -------------
echo
echo "=============================================================================="
echo "  6) ⭐ Die echte Kalibrierung vom 11.09.2026 — wenn erreichbar"
echo "=============================================================================="
K="${CLAUDE_PROJECT_DIR:-}/Learnings/kalibrierung-manager-chats"
if [ -f "$K/original.md" ] && [ -f "$K/agent2.md" ]; then
  janein "Agent 2 (Regel b) -> anwenden" "0" \
    "$(mind_verdichtung_pruefen "$K/original.md" "$K/agent2.md" "$K/agent2-bericht.md" >/dev/null 2>&1; echo $?)"
  janein "⛔ Antons Handfassung -> VERWERFEN (Marker verloren)" "1" \
    "$(mind_verdichtung_pruefen "$K/original.md" "$K/anton.md" >/dev/null 2>&1; echo $?)"
  janein "Agent 1 (Regel a, 31 B) -> anwenden, aber winzig" "0" \
    "$(mind_verdichtung_pruefen "$K/original.md" "$K/agent.md" >/dev/null 2>&1; echo $?)"
else
  echo "  [--- ] UEBERSPRUNGEN: Kalibrierungsmaterial nicht unter CLAUDE_PROJECT_DIR."
  echo "         ⚠ Ein uebersprungener Fall ist KEIN bestandener."
fi

rm -rf "$D"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
