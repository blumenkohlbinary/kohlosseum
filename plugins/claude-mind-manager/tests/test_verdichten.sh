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
