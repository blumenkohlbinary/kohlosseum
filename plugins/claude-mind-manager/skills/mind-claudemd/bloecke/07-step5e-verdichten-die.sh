#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-claudemd — aus skills/mind-claudemd/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# ⭐ Etappe 68: `bash <dieser Block> ende pruefen|anwenden` — Gates + frischer Wortdiff (Stufe 3) bzw. anwenden + Bilanz + Quittung.
#    Der Stand liegt in .claude-mind/verdichten-mind-claudemd.stand (mind_verdicht_start); ohne ihn bricht mind_verdicht_ende mit rc 2 ab.
if [ "${1:-}" = "ende" ]; then mind_verdicht_ende "$PROJ" mind-claudemd "${2:-}"; exit $?; fi
. "$CLAUDE_PLUGIN_ROOT/skills/mind-claudemd/bloecke/_ziele.sh"   # v5.154.0: BEREICH/ZIEL_* aus Step 1
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# Kandidat ist die Zieldatei aus Step 1
DATEI="$ZIEL_MD"
PIPE="$CLAUDE_PLUGIN_ROOT/references/claudemd_pipeline.py"
# (${ZIEL_WURZEL} mit Klammern: test_claudemd_global.sh zaehlt die Step-4c-Form genau einmal)
python "$PIPE" "$DATEI" --projekt "${ZIEL_WURZEL}" > "$PROJ/.claude-mind/pipeline-vorher.txt" 2>&1
# ... dann exakt der Lauf aus bestands-pass.md: Snapshot -> Agent (Kasten + die Unantastbaren
#     ⛔ v5.100.0: der Agent schreibt $PROJ/.claude-mind/verdichten-mind-claudemd.nachher.md (Zeilenenden
#        der Quelle); Anwenden ist `cp` nach Stufe 3 — NIE nachtippen (bestands-pass.md, Schritt 1)
#     ⭐ v5.101.0 im Auftrag: Absatz ins Archiv = seine Code-Spans, Zahlen und ALLCAPS-Woerter
#        bleiben im Zeiger-Satz — Stufe 1 zaehlt jede Marke, auch aus Herleitungen
#     oben WOERTLICH im Auftrag) -> mind_verdichtung_pruefen
#     -> Pipeline auf das ERGEBNIS, gegen pipeline-vorher.txt: kein Check neu rot
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
# ⭐ Etappe 68 (VERDICHTEN als Buendel): MIT ihnen gibt mind_verdicht_start den Agenten-Auftrag WOERTLICH (Kasten, Datei,
#    benannte Kandidaten, Stufe-3-Zeilen, ERGEBNIS-/BERICHT-Pfad) und den naechsten Aufruf aus. Snapshot, VORHER-Bytes und der
#    Stand (`.claude-mind/verdichten-mind-claudemd.stand`) entstehen dort. bestands-pass.md nur bei rotem Gate lesen.
if [ -n "$DATEI" ]; then
  if mind_verdicht_benannt "$PROJ" "$DATEI" >/dev/null; then
    mind_verdicht_start "$PROJ" mind-claudemd "$DATEI"
  else
    echo "VERDICHTEN: keine benannten Kandidaten — Schritt entfaellt, kein Agent."
    mind_schritt verdichten "uebersprungen:keine-benannten-kandidaten" 0 "$PROJ"
  fi
fi
