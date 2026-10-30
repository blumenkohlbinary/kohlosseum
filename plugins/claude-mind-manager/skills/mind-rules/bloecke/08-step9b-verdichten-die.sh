#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-rules — aus skills/mind-rules/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# Kandidat: die groesste Rule, ohne rollen.md
# ⛔ v5.138.0: was in DIESEM Kettenlauf schon verdichtet wurde, ist kein Kandidat.
#    Die Zeile stand bis dahin NUR in mind-update, obwohl alle vier Traeger
#    `verdichtet=` SCHREIBEN — ein Schreiber ohne Leser. Kosten eines doppelten
#    Durchgangs: 274 063 Token (bestands-pass.md).
_SCHON=$(grep '^verdichtet=' "$PROJ/.claude-mind/analyzed-scopes" 2>/dev/null | cut -d= -f2-)
DATEI=$(ls -S "$PROJ"/.claude/rules/*.md 2>/dev/null | grep -v '/rollen\.md$' \
        | while IFS= read -r f; do
            head -12 "$f" | grep -qi '^paths:' && continue
            case "
$_SCHON
" in *"
$f
"*) ;; *) echo "$f" ;; esac; done \
        | mind_verdicht_kandidat "$PROJ" mind-rules merken)   # v5.118.0: paths:-Rules ausgeschlossen, wie die Tabelle sagt; v5.138.0: kein `break` mehr — die Rotation braucht die ganze Liste
[ -n "$DATEI" ] || { echo "VERDICHTEN: keine Kandidatin"; }
# ... dann exakt der Lauf aus bestands-pass.md: Snapshot -> Agent -> mind_verdichtung_pruefen
#     ⛔ v5.100.0: der Agent schreibt $PROJ/.claude-mind/verdichten-mind-rules.nachher.md (Zeilenenden
#        der Quelle); Anwenden ist `cp` nach Stufe 3 — NIE nachtippen (bestands-pass.md, Schritt 1)
#     ⭐ v5.101.0 im Auftrag: Absatz ins Archiv = seine Code-Spans, Zahlen und ALLCAPS-Woerter
#        bleiben im Zeiger-Satz — Stufe 1 zaehlt jede Marke, auch aus Herleitungen
#     -> ⛔ STUFE 3 (Wort-Diff lesen; ohne Leser NICHT anwenden, ablegen und melden)
#     -> mind_verdichtung_anwenden "$DATEI" "$ERGEBNIS" "$PROJ/.claude-mind/verdichten-<skill>.txt" (v5.125.0:
#        vergleicht die Live-Datei mit dem md5 der Vorher-Fassung aus dem Deponat — seitdem geaendert = rc 1,
#        kein cp, neu verdichten; Ritas CLAUDE.md-Deponat 22:51 hinter Live 23:41 am 18.09.2026)
#     -> mind_kontext_bilanz gegen vorher -> sonst rollback.py restore
# v5.90.0: im Kettenlauf merken, damit mind-update nicht dieselbe Datei nimmt
# ⛔ v5.140.0 (Etappe 51 §2): ueber die pruefende Funktion, nicht per `echo >>`. Sie
#    weist ein Deponat unter `.claude-mind/` ab — Rita hat zweimal `$ERGEBNIS` gebucht
#    statt `$DATEI`, und nichts hat den Pfad geprueft. rc 2 ist KEIN Laufabbruch.
mind_verdichtet_merken "$PROJ" "$DATEI" || true
# ⛔ v5.174.0 (Etappe 67 N2e): ohne BENANNTE Kandidaten entfaellt der Schritt — Ertrag ~5 % (bestands-pass.md)
if [ -n "$DATEI" ]; then
  echo "BENANNTE UEBERHOLT-KANDIDATEN fuer $(basename "$DATEI") (woertlich an den Agenten):"
  if ! mind_verdicht_benannt "$PROJ" "$DATEI"; then
    echo "VERDICHTEN: keine benannten Kandidaten — Schritt entfaellt, kein Agent."
    mind_schritt verdichten "uebersprungen:keine-benannten-kandidaten" 0 "$PROJ"
  fi
fi
