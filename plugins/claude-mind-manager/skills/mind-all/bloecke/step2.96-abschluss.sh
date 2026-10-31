#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-all — aus skills/mind-all/SKILL.md ausgelagert (v5.152.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# --- Was ist tatsaechlich gelaufen? Aus der Spur, nicht aus der Erinnerung. ---
_SF="$SCOPES_FILE"; [ -f "$_SF" ] || _SF="${SCOPES_FILE}.done"   # Step 2.9 hat umbenannt
# ⛔ v5.30.0: NUR DIE EIGENEN MARKEN ZAEHLEN. Vorher zaehlte `grep -c '^skill='`
#    jede Zeile der geteilten Datei — auch die eines fremden Laufs. Genau daraus
#    entstand die Gefahr: zwei Laeufe, deren Summe 5 erreicht, tilgen gemeinsam
#    eine Schuld, die keiner von beiden abgearbeitet hat.
#    ⚠ Faellt `$LAUF` aus (leer), wird auf die alte Zaehlung zurueckgefallen —
#      fail-safe Richtung "eher Teilsync": lieber eine Mahnung zu viel.
if [ -n "${LAUF:-}" ]; then
  _SKILL_IST=$(grep -c "^skill=.*|$LAUF\$" "$_SF" 2>/dev/null)
else
  _SKILL_IST=$(grep -c '^skill=' "$_SF" 2>/dev/null)
fi
_SKILL_IST=${_SKILL_IST:-0}
_SKILL_SOLL=5

_BILANZ="$PROJ/.claude-mind/lauf-bilanz.txt"
mind_agent_bilanz "$PROJ" > "$_BILANZ" 2>/dev/null; _BRC=$?
_DIS=$(sed -n 's/.*DISPATCH=\([0-9]*\).*/\1/p' "$_BILANZ" | head -1); _DIS=${_DIS:-0}
# Soll: 4 Bereiche. 3, wenn custom-context mangels Dateien entfaellt (die EINZIGE
# erlaubte Auslassung, mind-update Step 3.5). 0 nur bei --quick.
# ⛔ v5.104.0: das Entfallen steht als `UEBERSPRUNGEN:`-Zeile in der Bilanz
#    (Quittung `uebersprungen`, mind_agent_uebersprungen) und wird HIER vom Soll
#    abgezogen — `3/3 agents`, nicht `3/4`. Vorher war `AGENT_SOLL` eine Shell-
#    Variable, die niemand setzte: ein Projekt ohne Custom-Context-Dateien blieb
#    per Konstruktion Teilsync (Palvedo, drei Laeufe 10.–13.09.2026).
_UEB=$(grep -c '^ *UEBERSPRUNGEN: ' "$_BILANZ" 2>/dev/null); case "${_UEB:-}" in ''|*[!0-9]*) _UEB=0 ;; esac
_AGENT_SOLL=$(( ${AGENT_SOLL:-4} - _UEB )); [ "$_AGENT_SOLL" -lt 0 ] && _AGENT_SOLL=0

# ⛔ Der Rueckgabewert der Bilanz REICHT NICHT — am Code gemessen, 24.08.2026.
#    mind_agent_bilanz zaehlt nur, was in der Quittung STEHT. Ein Agent, der nie
#    dispatcht wurde, hinterlaesst gar keine Zeile und ist unsichtbar. "2 dispatcht,
#    beide mit Ergebnis" ergibt deshalb Rueckgabe 0 — "alles gut" — und waere als
#    vollstaendig durchgewunken worden. Das ist exakt der Creator-Lauf vom 24.08.
#    Deshalb entscheidet die ZAHL, nicht der Zustand. (tests/test_teilsync.sh, Fall 18)
if [ "$_SKILL_IST" -eq 0 ] 2>/dev/null; then
  SYNC_LIEF="nein"
elif [ "$_BRC" = 0 ] && [ "$_DIS" -ge "$_AGENT_SOLL" ] 2>/dev/null \
     && [ "$_SKILL_IST" -ge "$_SKILL_SOLL" ] 2>/dev/null; then
  SYNC_LIEF="ja"
else
  SYNC_LIEF="teil"
fi
# v5.22.0: der Bestands-Pass zaehlt mit. Jeder der fuenf Skills quittiert
# `bestand=<skill>:<geprueft>/<stichprobe>` in `analyzed-scopes`; fehlt eine
# Quittung, hat der Skill seinen Bestand nicht angesehen.
#
# ⭐ Es braucht KEIN neues Feld und KEINE Aenderung an mind_sync_voll: die
#    zerlegt `umfang=` schon in a/b-Paare und macht aus jedem a<b einen
#    Teilsync. Ein angehaengtes `<n>/5 bestand` wirkt damit sofort.
#
# ⛔ Gezaehlt wird in `.done`, falls Step 2.9 die Marke schon umbenannt hat —
#    sonst zaehlt dieser Block je nach Reihenfolge mal 5 und mal 0, und das
#    saehe wie ein Befund ueber die Skills aus statt wie ein Lesefehler.
_SC="$PROJ/.claude-mind/analyzed-scopes"
[ -f "$_SC" ] || _SC="$PROJ/.claude-mind/analyzed-scopes.done"
_BEST=$(grep -c '^bestand=' "$_SC" 2>/dev/null); _BEST=${_BEST:-0}
case "$_BEST" in ''|*[!0-9]*) _BEST=0 ;; esac

# ⛔ v5.67.0: DIE ABDEKUNG ZAEHLT MIT — Nutzer-Auftrag 10.09.2026, woertlich:
#    "rita und nora sind fertig und nicht komplett gefahren das darf nicht sein
#     die sollen alles fahren".
#
# DER FALL, an dem es auffiel: Ritas Lauf vom 13:25 liess den
# context-analyzer-Dispatch in `mind-claudemd` aus und quittierte ihn korrekt
# als Teilabdeckung `1/2`. Der Lauf zaehlte trotzdem `5/5 skills 4/4 agents`,
# hinterliess KEINE Schuld und galt als beglichen. Sie hat es gesagt; das
# Werkzeug hat sie durchgewunken.
#
# ⭐ ES BRAUCHT KEIN NEUES FELD UND KEINE AENDERUNG AN `mind_sync_voll`:
#    die zerlegt `umfang=` schon in a/b-Paare und macht aus jedem a<b einen
#    Teilsync. Ein angehaengtes `<voll>/<gesamt> abdeckung` wirkt sofort —
#    derselbe Trick wie beim Bestands-Pass in v5.22.0.
#
# ⚠ GEZAEHLT WERDEN SCHRITTE, NICHT SKILLS. Die Bilanz kennt Schrittnamen,
#   keine Skillnamen; ein Skill mit zwei halben Schritten waere sonst falsch
#   verrechnet. Jede Teilabdeckung macht a<b — mehr braucht das Tor nicht.
# ⛔ `--alle` IST HIER PFLICHT. Ohne den Schalter saehe die Bilanz nur den
#    LETZTEN Block (mind-update) — und genau so ist Ritas Beleg verschwunden.
_ABD=$(mind_schritt_bilanz "$PROJ" --alle 2>/dev/null)
_ATEIL=$(printf '%s' "$_ABD" | sed -n 's/.*TEIL=\([0-9]*\).*/\1/p' | head -1)
_AGEL=$(printf '%s' "$_ABD"  | sed -n 's/.*GELAUFEN=\([0-9]*\).*/\1/p' | head -1)
case "${_ATEIL:-}" in ''|*[!0-9]*) _ATEIL=0 ;; esac
case "${_AGEL:-}"  in ''|*[!0-9]*) _AGEL=0 ;; esac

# ⛔ v5.97.0: FORMAL — Quittungen, die da sind und nichts belegen (kein eigener
#    Start-Block, Bytes getippt statt --datei, zwei Skills in derselben Sekunde).
#    Gemessen am Lauf 00:02 (12.09.2026): alle vier inneren Skills. `<5-n>/5 echt`
#    macht daraus ueber mind_sync_voll einen Teilsync, `formal-<skill>` sagt welchen.
# ⛔ v5.104.0: gezaehlt werden nur die FUENF — `FORMAL: mind-all` (kein Kopf-Block,
#    Etappe 12 §3) geht als `formal-mind-all` in `ungepruef=`.
# ⛔ v5.106.0: beides bilden seither `mind_umfang_bilden` und `mind_ungepruef_bilden`
#    aus der Bilanz — hier steht keine Zaehlung mehr, die man abtippen koennte.

# ⛔ v5.105.0 (Etappe 13 a): der Wert kommt aus `mind_umfang_bilden` — gelesen aus den
#    beiden Bilanzen und der Laufspur, NICHT aus den Variablen dieses Blocks. Die
#    Variablen oben tragen nur noch SYNC_LIEF und `ungepruef=`. Gemessen 13.09.2026
#    (Palvedo, Nora): `umfang=5/5 skills 3/4-echt-1-strukturell-leer agents 3/5 bestand
#    0/N abdeckung 5/5 echt` — von Hand getippt, kein Wert aus einer Datei, und
#    `mind_sync_voll` sah den 3/4 nicht einmal. ⛔ NIE `UMFANG="..."` aus Variablen bauen.
UMFANG=$(mind_umfang_bilden "$PROJ" "${LAUF:-}" "${AGENT_SOLL:-4}")

# ⛔ v5.106.0 (Etappe 14 §2): `ungepruef=` kommt aus `mind_ungepruef_bilden` — nie
#    dispatchte und UNGEPRUEFT-Bereiche aus der Agent-Bilanz, `bestand-<skill>` ohne
#    Quittung, `abdeckung-<schritt>` aus TEILABDECKUNG, `formal-<skill>` inkl.
#    `formal-mind-all`, `fehlt-<skill>:<schritt>` aus FEHLT (v5.130.0, Etappe 42 — Noras
#    Palvedo-Lauf 20.09.2026: `cleaner_duplikate` im mind-rules-Block nie quittiert, Bilanz
#    sagte FEHLT, der Merker sagte voll). Gemessen 14.09.2026 (Creator, Doro): Bilanz LEER=4 + FORMAL=1,
#    Merker von Hand „voll" — OPEN getilgt, `letzter-sync` geschrieben, zu Unrecht.
#    ⛔ NIE `UNGEPRUEFT="..."` aus Schleifen bauen. Was der Lauf SELBST weiss (z. B. ein
#    Bereich, den kein Werkzeug sieht), haengt er in UNGEPRUEFT_HAND an — es wird als
#    `hand:<text>` ANGEHAENGT, ersetzt nichts und kann nichts wegnehmen.
UNGEPRUEFT=$(mind_ungepruef_bilden "$PROJ" "${LAUF:-}"); _UG_WERKZEUG="$UNGEPRUEFT"
if [ -n "${UNGEPRUEFT_HAND:-}" ]; then
  UNGEPRUEFT="${UNGEPRUEFT:+$UNGEPRUEFT,}hand:${UNGEPRUEFT_HAND//,/;}"
fi
# ---- Block ----
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# Vor dem Schreiben: Reparatur-Paesse, so viele wie noetig — der Lauf stoppt NICHT bei teil.
# Je Eintrag in ungepruef=:
#   formal-<skill>      -> den Skill-Block ERNEUT ausfuehren (Kopf-Block liegt, §1) — nicht nachtippen
#   <bereich>           -> mind_agent_dispatch + Agent (blockierend) + mind_agent_ergebnis --datei, JETZT
#                          (v5.126.0: ergebnis ohne dispatch desselben Laufs = rc 2, nichts geschrieben);
#                          stirbt er, engerer Auftrag, wieder JETZT (workflow-agent-rate-limit.md)
#   bestand-<skill>     -> den Bestands-Pass des Skills nachfahren, bestand= quittieren
#   abdeckung-<schritt> -> den Schritt nachfahren und mit --datei quittieren
#   fehlt-<skill>:<schritt> -> der Pflichtschritt wurde NIE quittiert (uebersprungen): den
#                          Skill-Block VOLLSTAENDIG erneut fahren — alle Schritte seiner
#                          Erwartung, jeden quittieren; nicht den einen Schritt nachtippen
#                          (v5.130.0). `fehlt-mind-all:<skill>` heisst: der Skill fehlt im
#                          Kopf-Block — nach seinem Block dort quittieren
#   formal-mind-all     -> kann seit §1 nicht mehr entstehen; steht es doch da: Kopf-Block und
#                          die fuenf Bloecke erneut, in dieser Reihenfolge
# ⛔ v5.152.0: der Zaehler liegt in einer Datei JE LAUF. Als Shell-Variable begann er bei jedem
#    erneuten Aufruf wieder bei 0 — die Meldung nach Pass 2 und das Warten ab Pass 3 traten nie ein.
_PASSF="$PROJ/.claude-mind/reparatur-pass-${LAUF:-ohne-lauf}"
_PASS=$(cat "$_PASSF" 2>/dev/null); case "${_PASS:-}" in ''|*[!0-9]*) _PASS=0 ;; esac
# ⛔ v5.164.0: umfang= und ungepruef= aus Zeile oben, nicht neu gerechnet (je ~15 s). Fuenfmal gerechnet waren es
#    ~143 s, mehr als die 120 s, nach denen das Bash-Werkzeug den Block in den Hintergrund schiebt (A/B-Lauf 30.10.2026).
#    Geurteilt wird ueber die WERKZEUG-Werte ohne hand: — wie bisher mind_lauf_voll; und wie bisher geht hand: nicht
#    in den Merker (die zweite Rechnung unten ueberschrieb UNGEPRUEFT ohne hand:, das Verhalten bleibt).
_VOLL=$(mind_voll_aus "$UMFANG" "$_UG_WERKZEUG")
UNGEPRUEFT="$_UG_WERKZEUG"
while [ "$_VOLL" = "teil" ]; do
  _PASS=$((_PASS + 1))
  printf '%s\n' "$_PASS" > "$_PASSF" 2>/dev/null
  echo "⚠ Lauf ist teil — Reparatur-Pass $_PASS: $UNGEPRUEFT"
  # Anton 16.09.2026: ab Pass 3 WARTEN, nie abbrechen — 60 s je Pass, Deckel 10 min. Kein Stopp,
  # aber kein Haemmern auf ein Rate-Limit. (python statt `sleep`: das Bash-Werkzeug der
  # Desktop-App blockt ein Vordergrund-sleep laut seiner Werkzeugbeschreibung.)
  if [ "$_PASS" -ge 3 ]; then _W=$((60 * _PASS)); [ "$_W" -gt 600 ] && _W=600
    echo "   warte ${_W}s vor Pass $_PASS — warten, nie abbrechen"; python -c "import time; time.sleep($_W)"; fi
  [ "$_PASS" -eq 2 ] && mind_teilsync_meldung "$PROJ" "$UNGEPRUEFT" "$UMFANG"
  #   -> nach dem ZWEITEN Pass: Kennung aus .claude-mind/rescued/teilsync-meldung (manager=), per
  #      mcp__ccd_session_mgmt__list_sessions die local_-Kennung, send_message mit der satz=-Zeile —
  #      als INFORMATION. Der Lauf laeuft weiter; er wartet nicht auf eine Antwort.
  # ... hier die Eintraege ABARBEITEN (oben) ...
  break   # ⛔ der Skill fuehrt die Reparatur als Werkzeugaufrufe aus und ruft diesen Block danach ERNEUT — so lange, bis mind_lauf_voll voll sagt
done
if [ "$_VOLL" = "voll" ]; then SYNC_LIEF="ja"; elif [ "$SYNC_LIEF" != "nein" ]; then SYNC_LIEF="teil"; fi
[ "$SYNC_LIEF" = "ja" ] && rm -f "$_PASSF" 2>/dev/null
# ⛔ Mit SYNC_LIEF=teil geht es hier NICHT weiter: kein sync-stand, kein Bericht, kein Ende —
#    zurueck in die Schleife oben. Ein Teilsync wird nie mehr geschrieben.
# ---- Block ----
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# ⛔ v5.113.0: NUR bei `ja`. Ein Merker fuer teil entsteht nicht mehr — teil ist kein Zustand,
#    in dem dieser Block erreicht wird (2.96a-R laeuft, bis voll).
if [ "$SYNC_LIEF" = "ja" ]; then
  mkdir -p "$PROJ/.claude-mind/rescued"
  # ⛔ v5.65.0: HIER STAND `tokens=` UND DIE ERZEUGUNG VON `COMPACT-FAELLIG`.
  #    Beides ist weg. Nutzer-Entscheidung 10.09.2026: "die sollen garnicht
  #    mehr tokens messen das soll komplett raus".
  #
  #    `tokens=` speiste `mind_sync_frisch` (Zuwachs seit dem Sync). Die
  #    Funktion ist in v5.65.0 entfallen; ohne sie hat die Zahl keinen Leser.
  #    Der Merker wird jetzt wieder von `pre-compact.sh` verbraucht — der
  #    Zustand von v5.7.0 bis v5.10.0.
  #
  #    `COMPACT-FAELLIG` entstand AUSSCHLIESSLICH token-getriggert. ⚠ Damit
  #    bittet ab jetzt niemand mehr um eine Kompaktierung; das traegt die
  #    Auto-Kompaktierung (gemessen ~966 000, `env-vars.md`).
  #
  # ⭐ WAS BLEIBT UND JETZT ALLEIN TRAEGT: `umfang=` ist der Beleg,
  #    `ungepruef=` sagt WAS fehlt. Ohne beide sieht ein Teilsync im Merker aus
  #    wie ein Vollsync — und `pre-compact.sh` loescht dann die Schuld fuer
  #    Arbeit, die nie stattgefunden hat.
  # ⛔ v5.143.0 (Etappe 53 §1): `sid=` sagt, WESSEN Verlauf dieser Sync gelesen hat.
  #    Ein Sync liest seinen eigenen laufenden Verlauf und die eingetragenen Rettungen —
  #    NICHT den laufenden Verlauf einer anderen Sitzung. Ohne diese Zeile hielt jede
  #    Sitzung den Merker fuer ihren eigenen (Palvedo 01.10.2026, 5 090 Beitraege verloren).
  printf 'ts=%s\numfang=%s\nungepruef=%s\nsid=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$UMFANG" "$UNGEPRUEFT" "${CLAUDE_CODE_SESSION_ID:-unbekannt}" \
    > "$PROJ/.claude-mind/rescued/sync-stand"
  # ⛔ v5.113.0 (Etappe 20 §4a): das Urteil IST mind_sync_voll auf dem GERADE geschriebenen
  #    Merker — nicht die Zaehler oben. Noras Lauf 10 (16.09. 17:00): `ungepruef=abdeckung-…`,
  #    mind_sync_voll rc 1, und SYNC_LIEF stand trotzdem auf ja — OPEN getilgt, letzter-sync
  #    geschrieben, zu Unrecht. Sagt es teil, bleibt KEIN teil-Merker liegen (Nutzer 16.09.):
  #    zurueck nach 2.96a-R, die Eintraege abarbeiten, diesen Block erneut.
  mind_sync_voll "$PROJ/.claude-mind/rescued/sync-stand"; _SV_RC=$?
  if [ "$_SV_RC" -eq 0 ]; then SYNC_LIEF="ja"
  elif [ "$_SV_RC" -eq 3 ]; then
    # ⛔ v5.113.1: rc 3 ist ein AUFRUFFEHLER (Pfad falsch, Ordner fehlt) — KEIN teil, KEIN
    #    Reparatur-Pass: 2.96a-R kann daran nichts reparieren, die Schleife liefe endlos.
    #    Melden, Merker entfernen, den Pfad pruefen (PROJ, .claude-mind/rescued vorhanden?).
    SYNC_LIEF="nein"; rm -f "$PROJ/.claude-mind/rescued/sync-stand"
    echo "⛔ AUFRUFFEHLER: mind_sync_voll rc 3 auf $PROJ/.claude-mind/rescued/sync-stand — kein Urteil. Pfad und Ordner pruefen; OPEN bleibt, kein letzter-sync."
  else
    SYNC_LIEF="teil"; rm -f "$PROJ/.claude-mind/rescued/sync-stand"
    echo "⛔ Der geschriebene Merker ist TEIL (mind_sync_voll) — entfernt. Zurueck nach 2.96a-R: ${UNGEPRUEFT:-?}"
  fi
  # v5.86.0: der Merker der Rotations-Ratsche — NUR bei einem vollen Sync, und er
  #   wird von niemandem verbraucht. Was juenger ist als diese Zeit, rotiert nicht.
  #   v5.88.0: `utc=` dazu — die Beitraege der Rettungen sind in UTC gestempelt;
  #   `mind_rettung_nach_sync` vergleicht damit, ob eine Rettung Material nach
  #   dem Sync traegt (Ja/Nein, keine Schwelle).
  [ "$SYNC_LIEF" = "ja" ] && printf 'ts=%s\nutc=%s\n' "$(date +%Y%m%d-%H%M%S)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$PROJ/.claude-mind/rescued/letzter-sync"
fi
# ---- Block ----
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# ⛔ v5.113.0 (Etappe 20 §4): getilgt wird NUR, wenn mind_sync_voll den frischen Merker
#    mit rc 0 bestaetigt — und die resume=-Zeilen der EINGELESENEN Rettungen werden .done (mind_schuld_begleichen, seit v5.149.0 mit Liste).
#    Bis v5.112.0 stand hier `grep -m1 '^resume='`: nur die aelteste RESUME wurde .done,
#    zwei juengere blieben liegen (Noras Fund, 16.09.2026).
if [ "$SYNC_LIEF" = "ja" ] \
   && mind_sync_voll "$PROJ/.claude-mind/rescued/sync-stand"; then
  # ⛔ v5.149.0: nur die Rettungen, die Step 0 eingelesen hat (Liste mit der Lauf-ID der Kopfzeile).
  _GL="$PROJ/.claude-mind/rescued/OPEN.gelesen-$(mind_kopf_lauf "$PROJ" 2>/dev/null || echo ohne-lauf)"
  _BEGL=$(mind_schuld_begleichen "$PROJ" "$_GL") && echo "Sync-Schuld beglichen: $_BEGL."
fi

# ⛔ v5.28.0: Die PLAN-PAUSE wird IMMER aufgehoben — ausserhalb des
#    SYNC_LIEF-Blocks und auch, wenn gar keine Schuld bestand.
#    Sonst liefe ein von Hand gestarteter Sync waehrend eines Plans zwar
#    durch, der Merker bliebe aber liegen und legte die naechsten Stunden
#    still. Ein Merker, der einen erledigten Zustand behauptet, ist genau
#    der `PENDING`-Fehler aus v5.2.1 — eine Quittung fuers Reden statt einer
#    fuer die Arbeit.
#    ⚠ Der Merker ist Ablaufzustand, kein Inhalt — deshalb haengt er nicht daran,
#      ob eine Context-Datei geaendert wurde.
if command -v mind_plan_frei >/dev/null 2>&1 \
   && [ -f "$PROJ/.claude-mind/PLAN-AKTIV" ]; then
  mind_plan_frei "$PROJ" && echo "Plan-Pause aufgehoben (PLAN-AKTIV entfernt)."
fi
echo "ABSCHLUSS: SYNC_LIEF=${SYNC_LIEF:-?} — bei teil reparieren (Step 2.96a-R) und dieses Skript ERNEUT aufrufen."
# v5.175.0 (Etappe 68 N1 Schnitt D): bei voll der naechste Aufruf woertlich.
[ "${SYNC_LIEF:-}" = "ja" ] && echo "WEITER: bash \"$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/tools-rules.sh\", danach Step 3 (Schlussbericht)"
