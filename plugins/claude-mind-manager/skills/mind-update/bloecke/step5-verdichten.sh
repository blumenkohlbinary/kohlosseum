#!/usr/bin/env bash
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# Kandidat: die groesste Datei aus CLAUDE.md + rules, ohne rollen.md, ohne die schon
# in DIESEM Kettenlauf verdichteten (analyzed-scopes: verdichtet=<pfad>)
_SCHON=$(grep '^verdichtet=' "$PROJ/.claude-mind/analyzed-scopes" 2>/dev/null | cut -d= -f2-)
# ⛔ v5.118.0 (Etappe 26 §6): Rules mit `paths:` sind KEIN Kandidat — sie liegen nicht im
#    Dauerkontext (Zustellplan: routenplaner.md 161 kB, laedt nur bei Beruehrung), das Kriterium
#    „Dauerkontext kleiner" waere unerfuellbar. Gleiche Regel wie mind-rules 9b.
DATEI=$(ls -S "$PROJ/CLAUDE.md" "$PROJ"/.claude/rules/*.md 2>/dev/null | grep -v '/rollen\.md$' \
        | while IFS= read -r f; do
            head -12 "$f" | grep -qi '^paths:' && continue
            case "
$_SCHON
" in *"
$f
"*) ;; *) echo "$f" ;; esac; done \
        | mind_verdicht_kandidat "$PROJ" mind-update merken)   # v5.138.0: kein `break` — die Rotation waehlt aus der ganzen Liste
[ -n "$DATEI" ] || { echo "VERDICHTEN: keine Kandidatin"; }
# ... dann exakt der Lauf aus bestands-pass.md: Snapshot -> Agent (Kasten + Unantastbare
#     ⛔ v5.100.0: der Agent schreibt $PROJ/.claude-mind/verdichten-mind-update.nachher.md (Zeilenenden
#        der Quelle); Anwenden ist `cp` nach Stufe 3 — NIE nachtippen (bestands-pass.md, Schritt 1)
#     ⭐ v5.101.0 im Auftrag: Absatz ins Archiv = seine Code-Spans, Zahlen und ALLCAPS-Woerter
#        bleiben im Zeiger-Satz — Stufe 1 zaehlt jede Marke, auch aus Herleitungen
#     WOERTLICH) -> mind_verdichtung_pruefen -> (CLAUDE.md: Pipeline vorher/nachher)
#     -> ⛔ STUFE 3 (Wort-Diff lesen; ohne Leser NICHT anwenden, ablegen und melden)
#     -> mind_verdichtung_anwenden "$DATEI" "$ERGEBNIS" "$PROJ/.claude-mind/verdichten-<skill>.txt" (v5.125.0:
#        vergleicht die Live-Datei mit dem md5 der Vorher-Fassung aus dem Deponat — seitdem geaendert = rc 1,
#        kein cp, neu verdichten; Ritas CLAUDE.md-Deponat 22:51 hinter Live 23:41 am 18.09.2026)
#     -> mind_kontext_bilanz gegen vorher -> sonst rollback.py restore
# ⛔ v5.140.0 (Etappe 51 §2): ueber die pruefende Funktion, nicht per `echo >>`. Sie
#    weist ein Deponat unter `.claude-mind/` ab — Rita hat zweimal `$ERGEBNIS` gebucht
#    statt `$DATEI`, und nichts hat den Pfad geprueft. rc 2 ist KEIN Laufabbruch.
mind_verdichtet_merken "$PROJ" "$DATEI" || true
