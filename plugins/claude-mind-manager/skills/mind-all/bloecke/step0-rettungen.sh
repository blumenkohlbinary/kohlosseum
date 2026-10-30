#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-all — aus skills/mind-all/SKILL.md ausgelagert (v5.152.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# ⛔ v5.143.0 (Etappe 53 §2) — DAS NETZ, unabhaengig von der Ursache: was die
#    Rotations-Ratsche als UNGELESEN fuehrt, `OPEN` aber nicht nennt, wird hier
#    EINGESPEIST und GEMELDET. Gefunden hat die Luecke vom 01.10. nur Noras Gegenzaehlung
#    von Hand — jetzt macht es der Skill selbst, damit niemand mehr flicken muss.
# ⚠ Dieser Block ist ein EIGENER Bash-Aufruf (gemessen Etappe 51). Er laedt lib.sh
#   deshalb selbst — sonst waeren `mind_rettungen` darunter und das Netz hier
#   unbekannte Befehle und `$PROJ` leer. 52 von 81 Bloecken in allen Skills verlassen
#   sich darauf, dass ein frueherer Block es tat (gemessen 28.10.2026, eigener Befund).
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel)}"
mind_rettungen_nachtragen "$PROJ"
OPEN="$PROJ/.claude-mind/rescued/OPEN"
RESCUED_ALL=""; RESUME_FILE=""; COMPACTIONS=""
if [ -f "$OPEN" ]; then
  # v5.4.1: ALLE offenen Rettungen, aelteste zuerst. Bis v5.4.0 stand hier `grep -m1` —
  # bei zwei Kompaktierungen ohne Sync wurde die aeltere NIE eingespeist, obwohl ihre Datei
  # noch dalag. Belegt: 20260816-194132_chat.md, 412 KB, verwaist.
  # ⛔ v5.57.0: DIESELBE AUSWAHL STAND HIER UND IN `mind-update` — zweimal,
  #    und nur eine der beiden war richtig. Die in `mind-update` leerte bei
  #    zwei oder mehr Rettungen ihre eigene Liste (`[ ! -f ]` auf mehrzeiligen
  #    Text) und fiel auf die juengste Datei im Ordner zurueck. GEMESSEN: von
  #    drei Rettungen kam EINE an. Von aussen sah die Kette dabei richtig aus,
  #    weil DIESE Fassung alle drei korrekt AUFZAEHLTE.
  #    Jetzt beide ueber `mind_rettungen` aus `lib.sh`.
  RESCUED_ALL=$(mind_rettungen "$PROJ")
  RESUME_FILE=$(grep '^resume='      "$OPEN" | cut -d= -f2- | tail -1)   # der juengste Auftrag
  # v5.6.0: der ausfuehrliche Arbeitsstand. Er steht BEWUSST nicht in RESUME.md —
  # die Erinnerungs-Hooks kappen die dort bei 30 Zeilen, und das ist richtig so.
  ARBEITSSTAND=$(grep '^arbeitsstand=' "$OPEN" | cut -d= -f2- | tail -1)
  # ⛔ v5.56.0: gezaehlt statt gelesen — `pre-compact.sh` haengt `OPEN` nur
  #    noch an. Die Zahl der `path=`-Zeilen IST die Zahl der Kompaktierungen
  #    seit dem letzten Sync. Alte Merker tragen `compactions=`; deshalb der
  #    groessere der beiden Werte.
  COMPACTIONS=$(grep -c '^path=' "$OPEN" 2>/dev/null)
  _CALT=$(grep -m1 '^compactions=' "$OPEN" 2>/dev/null | cut -d= -f2-)
  case "$COMPACTIONS" in ''|*[!0-9]*) COMPACTIONS=0 ;; esac
  case "$_CALT" in ''|*[!0-9]*) _CALT=0 ;; esac
  [ "$_CALT" -gt "$COMPACTIONS" ] 2>/dev/null && COMPACTIONS="$_CALT"
fi
# Rueckfall, falls OPEN fehlt (Rettung aus einer aelteren Version)
[ -z "$RESCUED_ALL" ] && RESCUED_ALL=$(ls -t "$PROJ/.claude-mind/rescued"/*_chat.md 2>/dev/null | head -1)
# ⛔ v5.149.0 (Etappe 57 §3): festhalten, WELCHE Rettungen dieser Lauf einliest — Step 2.96 tilgt
#    nur diese (Veras Lauf: 7 eingelesen, 41 kamen waehrend des Laufs dazu und wurden mitgetilgt).
#    Lauf-ID aus der Kopfzeile: die Sperre ist in Step 2.96 schon frei (Step 2.9).
_GL="$PROJ/.claude-mind/rescued/OPEN.gelesen-$(mind_kopf_lauf "$PROJ" 2>/dev/null || echo ohne-lauf)"
printf '%s\n' "$RESCUED_ALL" | sed 's#.*[/\\]##' | grep . > "$_GL" 2>/dev/null || : > "$_GL"
RESCUED_N=$(printf '%s\n' "$RESCUED_ALL" | grep -c . 2>/dev/null)
case "$RESCUED_N" in ''|*[!0-9]*) RESCUED_N=0 ;; esac

if [ "$RESCUED_N" -gt 0 ]; then
  # NUR ZAEHLEN, NICHT LESEN — siehe Sperre unten
  # v5.2.2: BEIDE Quellen. Die Rettung endet am Kompaktierungs-Zeitpunkt; alles danach steht
  # nur im Live-Transkript — und genau das ist die Arbeit, wegen der der Lauf erzwungen wird.
  echo "Session-Quelle: gerettet+live"
  echo "  gerettet -> $RESCUED_N Rettung(en), aelteste zuerst:"
  i=0
  printf '%s\n' "$RESCUED_ALL" | while IFS= read -r r; do
    [ -n "$r" ] || continue
    i=$((i+1))
    echo "     [$i] $(basename "$r")  $(grep -c '^## \[' "$r") Beitraege"
    # v5.160.0 (Etappe 62): das Verlaufsbuch ist die ERSTE Quelle, die Rettung der Rueckfall
    _vb=$(mind_verlauf_fuer "$PROJ" "$r") && echo "         -> Verlaufsbuch (zuerst lesen): $_vb  — Abschnitt rettung=$(basename "${r%%_*}")"
  done
  echo "  live     -> Sampler ueber das laufende Transkript (die Zeit nach der letzten)"
  [ -n "$COMPACTIONS" ] && [ "$COMPACTIONS" -gt 1 ] 2>/dev/null && \
    echo "ACHTUNG: $COMPACTIONS Kompaktierungen seit dem letzten Sync — bereits verschleppt."
else
  echo "Session-Quelle: live"
fi
# Der Auftrags-Merker ist KLEIN (wenige KB) und wird gelesen — er wird am Ende zurueckgegeben.
[ -n "$RESUME_FILE" ] && [ -f "$RESUME_FILE" ] && \
  { echo "Unterbrochener Auftrag gefunden:"; sed -n "/^## /,\$p" "$RESUME_FILE" | head -30; }

# Arbeitsstand OHNE Kappung — hier gehoert der ausfuehrliche Stand hin (v5.6.0).
# Vier Kategorien: Entscheidungen, aktive Bugs, geaenderte Dateien, Constraints.
if [ -n "$ARBEITSSTAND" ] && [ -s "$ARBEITSSTAND" ]; then
  echo "Arbeitsstand vor der Kompaktierung:"
  python "$CLAUDE_PLUGIN_ROOT/references/arbeitsstand_render.py" "$ARBEITSSTAND" 2>/dev/null \
    || echo "  (Arbeitsstand nicht lesbar — der Lauf geht trotzdem weiter)"
fi
