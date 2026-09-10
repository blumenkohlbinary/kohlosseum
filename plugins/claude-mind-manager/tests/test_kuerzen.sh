#!/usr/bin/env bash
# =============================================================================
#  KUERZEN duerfen alle fuenf — TEILBAR (3) und das ENTLASTUNGS-Gate  (NEU v5.71.0)
# =============================================================================
#
# ⛔ WAS HIER ENTSCHIEDEN WIRD
#
# Der Nutzer hat am 10.09.2026 entschieden, dass alle fuenf Context-Skills
# kuerzen duerfen. Gemessen am selben Tag (`docs/plugin/d1-trefferquote.md`)
# traegt davon genau EINE Klasse:
#
#     BREMSE     34 % gegen  7 %   Faktor 4,9   -> traegt
#     ANLEITUNG  26 % gegen 25 %                -> traegt NICHT
#     BELEG      12 % gegen 13 %                -> VERKEHRT HERUM
#
# ⭐ Daraus folgt die Bauform, die hier geprueft wird: NICHT nach Klasse
#    umziehen, sondern nach SUBTRAKTION. Was `BREMSE` markiert, bleibt; der
#    Rest des Absatzes geht. Man muss dafuer nur der Klasse trauen, die
#    bestanden hat.
#
# ⛔ ZWEI ZUSICHERUNGEN, und die zweite ist die wichtigere:
#     (1) TEILBAR Fall (3) FEUERT bei einem echten BELEG+ANLEITUNG-Absatz.
#     (2) Er feuert NICHT bei den drei Bauformen, die nie geteilt werden —
#         Doppelzeiger, Tabelle, Geruest. Gemessen 10.09.2026: ohne diesen
#         Ausschluss waeren 15 von 69 Vorschlaegen falsch (22 %).
#
# ⭐ Der DOPPELZEIGER ist der teuerste Fehlvorschlag, den es hier geben kann:
#    er ist die Bauform, die ZIEL 3 zur PFLICHT macht, und ein Vorschlag, ihn
#    zu zerlegen, zerlegt den Zeiger, der das Auslagern ueberhaupt traegt.
#
# ⚠ GEGENPROBE gegen v5.70.0 ist Pflicht und steht in Abschnitt 4 — ohne sie
#   waere gruen nur Schweigen.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EIN="$WURZEL/references/cleaner_einordnung.py"
UMZ="$WURZEL/references/cleaner_umzug.py"

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-56s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-56s ist=%-14s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}

for f in "$EIN" "$UMZ"; do
  [ -f "$f" ] || { echo "ABBRUCH: $f fehlt (Wurzel: $WURZEL)"; exit 2; }
done

D=$(mktemp -d "${TMPDIR:-/tmp}/kuerzenXXXXXX") || exit 2

# ⛔ Die Prueftexte liegen in DATEIEN, nicht in echo/heredoc. Sie enthalten
#   Backticks, und bash fuehrt die in doppelten Anfuehrungszeichen AUS —
#   zweimal am 10.09.2026 passiert, Rueckgabe 0, Text still ersetzt.
schreibe() { cat > "$1"; }

# --- Die Testfaelle, je eine Datei mit EINEM Absatz --------------------------
schreibe "$D/echt.md" <<'EOF'
Der Aufruf ist `python tools/rollback.py list`, und er wurde am 21.08.2026
gemessen: von sieben Snapshots fand die alte Rotation null.
EOF

schreibe "$D/doppelzeiger.md" <<'EOF'
> **Messreihen, Zuschnitt-Tabelle und Herleitung stehen im Command
> `/workflow-agent-rate-limit`.** Wird er nicht angeboten:
> `~/.claude/skills/workflow-agent-rate-limit/SKILL.md` direkt lesen.
EOF

schreibe "$D/tabelle.md" <<'EOF'
| Aufruf | gemessen am |
|---|---|
| `tools/rollback.py list` | 21.08.2026 |
EOF

schreibe "$D/geruest.md" <<'EOF'
Verschoben am 03.09.2026. NICHTS ist geloescht — `cleaner_ratsche.py
--entarchiviere <n>` holt es zurueck.
EOF

klasse_teilbar() {
  # gibt "ja"/"nein" zurueck: markiert D1 den Absatz als TEILBAR?
  #
  # ⛔ DIE ERSTE FASSUNG GREPPTE 'TEILBAR' UND WAR FALSCH — sie traf die
  #   LEGENDE unter der Tabelle ("⭐ N Absaetze sind TEILBAR: ...") und meldete
  #   deshalb bei JEDER Datei "ja", auch bei den drei Ausschluessen und auch
  #   unter v5.70.0, das den Fall gar nicht kennt.
  # ⭐ Achtes Vorkommen der Klasse `nennung-statt-zuweisung` in diesem Projekt,
  #   und diesmal in einem Prueffall, der genau diese Klasse absichern soll.
  #   Gefunden hat es die GEGENPROBE in Abschnitt 4: dass die alte Fassung
  #   dasselbe meldete, kann nur am Messgeraet liegen.
  # ⚠ Die Markierung am ABSATZ heisst `⭐TEILBAR` OHNE Leerzeichen und steht am
  #   Zeilenende einer nummerierten Zeile. Die Legende heisst "sind TEILBAR:".
  python "$EIN" --wohin "$1" 2>/dev/null \
    | grep -qE '^[[:space:]]+[0-9]+[[:space:]].*⭐TEILBAR[[:space:]]*$' \
    && echo ja || echo nein
}

echo "=============================================================================="
echo "  1) TEILBAR Fall (3) — BELEG **und** ANLEITUNG im selben Absatz"
echo "=============================================================================="
janein "der echte Mischabsatz wird als TEILBAR markiert" "ja" "$(klasse_teilbar "$D/echt.md")"

echo
echo "=============================================================================="
echo "  2) ⛔ DIE DREI AUSSCHLUESSE — hier darf er NICHT feuern"
echo "=============================================================================="
janein "⛔ DOPPELZEIGER bleibt ganz (Pflicht-Bauform aus ZIEL 3)" "nein" \
       "$(klasse_teilbar "$D/doppelzeiger.md")"
janein "⛔ TABELLE bleibt ganz (eine Zeile weniger zerreisst sie)" "nein" \
       "$(klasse_teilbar "$D/tabelle.md")"
janein "⛔ GERUEST bleibt ganz (beim Erzeuger aendern)" "nein" \
       "$(klasse_teilbar "$D/geruest.md")"

echo
echo "=============================================================================="
echo "  3) ⭐ Das ENTLASTUNGS-Gate — ein Umzug muss den Dauerkontext senken"
echo "=============================================================================="
# ⛔ Der Fall, den es fangen soll: die Kurz-Rule ist NICHT kuerzer als vorher.
#   Bis v5.70.0 bestand genau das alle vier Gates — Gate 1 zaehlt ueber BEIDE
#   Orte und ist blind dafuer, ob der IMMER LADENDE Anteil gesunken ist.
mkdir -p "$D/skill"
schreibe "$D/alt.md" <<'EOF'
# Regel
⛔ NIE ohne Sicherung loeschen. Gemessen am 21.08.2026: sieben Snapshots,
null geloescht. Der Aufruf ist `tools/rollback.py list`, und die Herleitung
steht im Archiv unter `.claude/archiv/regel.archiv.md`.
EOF
# (a) Kurz ist GENAUSO lang wie Alt -> ENTLASTUNG muss BRECHEN
cp "$D/alt.md" "$D/kurz-gleich.md"
# (b) Kurz ist wirklich kuerzer -> ENTLASTUNG muss HALTEN
schreibe "$D/kurz-klein.md" <<'EOF'
# Regel
⛔ NIE ohne Sicherung loeschen. Volltext: `.claude/archiv/regel.archiv.md`.
EOF
schreibe "$D/skill/SKILL.md" <<'EOF'
---
name: regel
description: Die vollstaendige Regel samt Herleitung, Messreihen und Aufrufen fuer den Umgang mit Sicherungen.
---
# Regel — Volltext
Gemessen am 21.08.2026: sieben Snapshots, null geloescht.
Der Aufruf ist `tools/rollback.py list`.
Herleitung und Belege stehen hier vollstaendig.
EOF

gate_stand() {
  # $1 = Kurz-Datei -> "ja" wenn ENTLASTUNG haelt, sonst "nein"
  python "$UMZ" --alt "$D/alt.md" --kurz "$1" --skill "$D/skill/SKILL.md" 2>/dev/null \
    | grep -E 'ENTLASTUNG' | grep -qE '\bOK\b|✅|haelt|bestanden' && echo ja || echo nein
}

_A=$(python "$UMZ" --alt "$D/alt.md" --kurz "$D/kurz-gleich.md" --skill "$D/skill/SKILL.md" 2>&1)
janein "das Gate ist ueberhaupt vorhanden" "ja" \
       "$(printf '%s' "$_A" | grep -q 'ENTLASTUNG' && echo ja || echo nein)"
janein "⛔ Kurz genauso lang wie Alt -> ENTLASTUNG bricht" "nein" \
       "$(gate_stand "$D/kurz-gleich.md")"
janein "⭐ Kurz wirklich kuerzer -> ENTLASTUNG haelt" "ja" \
       "$(gate_stand "$D/kurz-klein.md")"
janein "die Meldung nennt BYTES, nicht Zeilen" "ja" \
       "$(printf '%s' "$_A" | grep -A1 'ENTLASTUNG' | grep -q ' B' && echo ja || echo nein)"
janein "⭐ und rechnet die Tokenzahl daneben aus" "ja" \
       "$(printf '%s' "$_A" | grep -A1 'ENTLASTUNG' | grep -q 'Token' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  4) ⚠ GEGENPROBE gegen v5.70.0 — waren diese Faelle vorher WIRKLICH rot?"
echo "=============================================================================="
# ⛔ Ohne diesen Abschnitt ist gruen nur Schweigen. Gefahren wird gegen das
#   INSTALLIERTE Vorgaengerpaket, nicht gegen eine nachgebaute alte Fassung.
ALT_ROOT="$HOME/.claude/plugins/cache/kohlosseum/claude-mind-manager/5.70.0"
if [ -f "$ALT_ROOT/references/cleaner_einordnung.py" ]; then
  # ⛔ DIESELBE Markierung wie oben, nicht die Legende — sonst misst die
  #   Gegenprobe etwas anderes als der Prueffall, den sie absichern soll.
  _alt_teil=$(python "$ALT_ROOT/references/cleaner_einordnung.py" --wohin "$D/echt.md" 2>/dev/null \
              | grep -cE '^[[:space:]]+[0-9]+[[:space:]].*⭐TEILBAR[[:space:]]*$')
  janein "v5.70.0 kannte Fall (3) NICHT (0 Treffer)" "0" "$_alt_teil"
  _alt_gate=$(python "$ALT_ROOT/references/cleaner_umzug.py" --alt "$D/alt.md" \
              --kurz "$D/kurz-gleich.md" --skill "$D/skill/SKILL.md" 2>&1 | grep -c 'ENTLASTUNG')
  janein "v5.70.0 hatte KEIN ENTLASTUNGS-Gate (0 Treffer)" "0" "$_alt_gate"
else
  echo "    UEBERSPRUNGEN — v5.70.0 nicht installiert, Gegenprobe nicht fahrbar."
  echo "    ⚠ Ein uebersprungener Fall ist KEIN bestandener."
fi

rm -rf "$D"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
