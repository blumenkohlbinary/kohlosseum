#!/usr/bin/env bash
# /mind-all — aus skills/mind-all/SKILL.md ausgelagert (v5.152.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
LISTE="$PROJ/listeverbesserungen.md"
[ -f "$LISTE" ] || printf '# Verbesserungsliste\n\nAngehaengt von /mind-all. Neueste Abschnitte stehen UNTEN.\n' > "$LISTE"

# 1) Abschnitt in eine Zwischendatei schreiben (Aufbau siehe unten), dann anhaengen.
#    mind_append statt '>>' — es erhaelt die Zeilenenden der Zieldatei.
ABSCHNITT="$PROJ/.claude-mind/lauf-abschnitt.md"
# ⛔ v5.152.0: Abschnitt und Befunde schreibt das Modell VORHER mit Write — ein Skript kann nicht
#    mittendrin auf eine Eingabe warten. Bis v5.151.0 stand hier `: > "$BEFUNDE"` unmittelbar vor
#    `mind_debug_write`: jeder vorher geschriebene Befund wurde geleert, bevor er gemeldet wurde.
AUSLOESER="${1:-${AUSLOESER:-}}"
if [ ! -s "$ABSCHNITT" ]; then
  echo "⛔ $ABSCHNITT fehlt oder ist leer — zuerst den Abschnitt mit Write anlegen, dann diesen Block erneut."
  exit 1
fi
mind_append "$LISTE" < "$ABSCHNITT"

# 2) Befunde MASCHINENLESBAR danebenlegen — eine Zeile je Befund.
#    Ohne die feste Klassenliste heisst derselbe Fehler dreimal anders und wird nie als
#    Wiederholung erkannt. Gueltige Klassen stehen in references/debug_auswertung.py.
BEFUNDE="$PROJ/.claude-mind/lauf-befunde.jsonl"
[ -f "$BEFUNDE" ] || : > "$BEFUNDE"   # keine Befunde ist zulaessig — dann eine leere Datei
# je Befund eine Zeile, z.B.:
#   {"ts":"2026-08-21 01:20","projekt":"<PROJ>","klasse":"instrument-nachgebaut",
#    "kurz":"Pipeline statt claudemd_pipeline.py nachgebaut","lauf":"<ts>"}
# ⛔ v5.141.0: `modell` und `stufe` NICHT von Hand dazuschreiben — `mind_debug_write`
#    setzt beide selbst (nicht bestimmbar -> `unbekannt`, nie leer und nie weggelassen).
#    ⚠ Eine SELBST geschriebene Angabe bleibt stehen (`//`-Vorrang, damit nachtraeglich
#      eingespeiste Befunde nicht die Stufe von HEUTE bekommen) — eine falsch geratene also auch.

# 3) zentral melden (still, wenn MIND_DEBUG_DIR nicht gesetzt ist)
mind_debug_write "$PROJ" "$AUSLOESER" "$ABSCHNITT" "$BEFUNDE"
rm -f "$ABSCHNITT" "$BEFUNDE" 2>/dev/null
