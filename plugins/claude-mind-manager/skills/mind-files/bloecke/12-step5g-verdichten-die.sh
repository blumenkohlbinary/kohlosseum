#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files — aus skills/mind-files/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# Kandidatin: die groesste Companion-Rule, die es im Projekt gibt — v5.138.0: nicht die,
# die in den letzten N Laeufen schon dran war (kein `head -1`, die Funktion waehlt).
# ⛔ v5.138.0: was in DIESEM Kettenlauf schon verdichtet wurde, ist kein Kandidat.
#    Die Zeile stand bis dahin NUR in mind-update, obwohl alle vier Traeger
#    `verdichtet=` SCHREIBEN — ein Schreiber ohne Leser. Kosten eines doppelten
#    Durchgangs: 274 063 Token (bestands-pass.md).
_SCHON=$(grep '^verdichtet=' "$PROJ/.claude-mind/analyzed-scopes" 2>/dev/null | cut -d= -f2-)
DATEI=$(ls -S "$PROJ"/.claude/rules/{backup-usage,wissenstransfer-pruefen,zaehlwerte-pruefen,release-hygiene,release-build}.md 2>/dev/null \
        | while IFS= read -r f; do
            case "
$_SCHON
" in *"
$f
"*) ;; *) echo "$f" ;; esac; done \
        | mind_verdicht_kandidat "$PROJ" mind-files merken)
[ -n "$DATEI" ] || { echo "VERDICHTEN: keine Kandidatin (keine Companion-Rule installiert)"; }
# ... dann exakt der Lauf aus bestands-pass.md: Snapshot -> Agent (Kasten + Aufrufformen und
#     ⛔ v5.100.0: der Agent schreibt $PROJ/.claude-mind/verdichten-mind-files.nachher.md (Zeilenenden
#        der Quelle); Anwenden ist `cp` nach Stufe 3 — NIE nachtippen (bestands-pass.md, Schritt 1)
#     ⭐ v5.101.0 im Auftrag: Absatz ins Archiv = seine Code-Spans, Zahlen und ALLCAPS-Woerter
#        bleiben im Zeiger-Satz — Stufe 1 zaehlt jede Marke, auch aus Herleitungen
#     globs: als unantastbar WOERTLICH) -> mind_verdichtung_pruefen
#     -> mind_check_tools_have_rules "$PROJ" auf das ERGEBNIS: rc 0, sonst verwerfen
#     -> ⛔ STUFE 3 (Wort-Diff lesen; ohne Leser NICHT anwenden, ablegen und melden)
#     -> mind_verdichtung_anwenden "$DATEI" "$ERGEBNIS" "$PROJ/.claude-mind/verdichten-<skill>.txt" (v5.125.0:
#        vergleicht die Live-Datei mit dem md5 der Vorher-Fassung aus dem Deponat — seitdem geaendert = rc 1,
#        kein cp, neu verdichten; Ritas CLAUDE.md-Deponat 22:51 hinter Live 23:41 am 18.09.2026)
#     -> mind_kontext_bilanz gegen vorher -> sonst rollback.py restore
# ⛔ v5.140.0 (Etappe 51 §2): ueber die pruefende Funktion, nicht per `echo >>`. Sie
#    weist ein Deponat unter `.claude-mind/` ab — Rita hat zweimal `$ERGEBNIS` gebucht
#    statt `$DATEI`, und nichts hat den Pfad geprueft. rc 2 ist KEIN Laufabbruch.
mind_verdichtet_merken "$PROJ" "$DATEI" || true
