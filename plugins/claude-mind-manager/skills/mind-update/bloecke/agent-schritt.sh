#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update Step 3.5 — EIN Aufruf je Agentenwelle (v5.162.0, Etappe 63 N3 §1+§3).
#
#   bash agent-schritt.sh start <a>[,<b>]                  Quittung anlegen (3/4), dispatch der ersten Welle
#   bash agent-schritt.sh <fertig>[,<fertig2>] [<naechste>[,<naechste2>]]
#                                                           Ergebnis der fertigen Welle quittieren, naechste dispatchen
#   bash agent-schritt.sh <fertig> --ohne-bericht           Agent ohne tool_result: bytes:0 quittieren (ungeprueft)
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): je Bereich VIER Schritte — dispatch, Agent, Bericht per
#    Write abgetippt, ergebnis — dazu Weck-Turns; 16+ Schritte fuer vier Bereiche, jeder bezahlt den ganzen
#    Verlauf (~280k). Jetzt: 3 Bloecke + 2 Wellen; der context-analyzer schreibt seinen Bericht selbst nach
#    `mind_agent_bericht_pfad`. Hoechstens ZWEI je Welle (Anti-Burst, v4.0.1).
# ⛔ Unveraendert: dispatch VOR dem Agentenstart, ergebnis ueber `mind_agent_ergebnis --datei` — eine fehlende
#    oder leere Datei bleibt bytes:0 (LEER, `agent-fehlbericht`), das Hintergrund-Ack und ein Rohdump ebenso.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "ERROR: CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
A="${1:-}"; B="${2:-}"
[ -n "$A" ] || { echo "Aufruf: agent-schritt.sh start <a>[,<b>] | <fertig>[,<f2>] [<naechste>[,<n2>]|--ohne-bericht]" >&2; exit 2; }
liste() { printf '%s\n' "$1" | tr ',' '\n' | sed '/^$/d'; }
anzahl() { liste "$1" | grep -c .; }
[ "$(anzahl "$B")" -le 2 ] && [ "$A" = start -o "$(anzahl "$A")" -le 2 ] \
  || { echo "⛔ hoechstens ZWEI Bereiche je Welle (Anti-Burst, v4.0.1)." >&2; exit 2; }

if [ "$A" = start ]; then
  [ -n "$B" ] || { echo "Aufruf: agent-schritt.sh start <a>[,<b>]" >&2; exit 2; }
  CCF=()
  mapfile -t CCF < "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)" 2>/dev/null   # Step 1.5 (v5.153.0)
  if [ "${#CCF[@]}" -eq 0 ] || [ -z "${CCF[0]:-}" ]; then
    [ -f "$PROJ/.claude-mind/agent-quittung.jsonl" ] || mind_agent_quittung_start "$PROJ" 3
    mind_agent_uebersprungen custom-context 0 "$PROJ"
    echo "custom-context: 0 Dateien — uebersprungen und quittiert (3 Bereiche)."
  else
    [ -f "$PROJ/.claude-mind/agent-quittung.jsonl" ] || mind_agent_quittung_start "$PROJ" 4
  fi
else
  RC=0
  while IFS= read -r a; do
    F=$(mind_agent_bericht_pfad "$a" "$PROJ") || exit 2
    if [ "$B" = "--ohne-bericht" ]; then
      mind_agent_ergebnis "$a" --datei "$F" "$PROJ"; echo "$a: ohne Bericht quittiert (bytes:0, ungeprueft)."
      continue
    fi
    if [ ! -s "$F" ]; then
      echo "⛔ $a: kein Bericht unter $F."
      echo "   Hat der Agent ihn nicht geschrieben (aelteres Paket ohne Write): den tool_result WOERTLICH dorthin"
      echo "   legen und diesen Aufruf wiederholen. Kam gar kein tool_result: '$a --ohne-bericht'."
      RC=3; continue
    fi
    mind_agent_ergebnis "$a" --datei "$F" "$PROJ"
    echo "$a: quittiert ($(wc -c < "$F" | tr -d ' ') B)."
  done < <(liste "$A")
  [ "$B" = "--ohne-bericht" ] && exit 0
  [ "$RC" = 0 ] || { echo "⛔ naechste Welle NICHT dispatcht — erst die fehlenden Berichte." ; exit 3; }
fi

# ⛔ v5.167.0 (Etappe 65 Nachtrag 2): der Block gibt den AUFTRAG je Bereich woertlich aus. Bis 5.166.0 nannte er nur
#    den Bericht-Pfad; das Modell formulierte den Auftrag aus der Prosa-Tabelle selbst. Gemessen im vollen Lauf
#    30.10.2026: alle Agenten ohne run_in_background, keine Bestands-Pruefung, custom-context bekam 412 Dateien
#    (5 MB) fuer 25 Turns und schrieb zweimal keinen Bericht — 12 von 17 echten Befunden des alten Ablaufs fehlten.
# ⛔ v5.169.0 (Etappe 65 Nachtrag 5): die Session-Quellen, wie SKILL.md Step 3.5 sie vorschreibt — ZUERST das
#    Verlaufsbuch je Rettung, dann die Rettungen als PFAD mit Groessen-Guard, dann der Live-Auszug. 5.167.0 nannte nur
#    den Live-Auszug; im Lauf nach einer Kompaktierung ist der fast leer, und kein Agent sah mehr eine Session-Lehre.
#    Gegentest 30.10.2026 auf Stand e66: mit diesen Quellen fand rules `werkzeuge-zuerst.md:38/41`, das fehlende
#    Verlaufsbuch in hooks.md und `$ARGUMENTS`, memory das Zitat in `rotes-gate` — alle vier fehlten in neu168 und n4.
#    ⛔ Nur Pfade und Zaehlungen, nie Inhalt: die Flut-Sperre fuer `*_chat.md` gilt im Hauptkontext weiter.
quellen() {
  local r v
  _N=1
  _R=$(mind_rettungen "$PROJ" 2>/dev/null) || _R=""
  echo "Session-Quellen (mind-update/SKILL.md Step 3.5) — in dieser Reihenfolge lesen:"
  [ -n "$_R" ] || return 0
  echo "$_N. ZUERST das Verlaufsbuch je Rettung (Arbeitsstand + Kompaktierungs-Zusammenfassung):"
  while IFS= read -r r; do
    v=$(mind_verlauf_fuer "$PROJ" "$r") || continue
    r=$(basename "$r"); echo "   - $v ($(wc -c < "$v" | tr -d ' ') B) — Abschnitt rettung=${r%%_*}"
  done <<< "$_R"
  _N=$((_N + 1))
  echo "$_N. Danach die Rettungen, NUR gezielt per Grep (Groessen-Guard: ueber 600 Zeilen oder 60 KB nicht ganz lesen, ±40 Zeilen um Treffer) — ohne Verlaufsbuch-Abschnitt die einzige Quelle:"
  while IFS= read -r r; do
    echo "   - $r ($(wc -c < "$r" | tr -d ' ') B, $(grep -c '^## \[' "$r") Beitraege)"
  done <<< "$_R"
  _N=$((_N + 1))
}

auftrag() {  # <bereich>
  local n="$1" f prio
  f=$(mind_agent_bericht_pfad "$n" "$PROJ")
  echo "----- AUFTRAG $n (woertlich als prompt uebergeben) -----"
  echo "Agent(subagent_type: \"claude-mind-manager:context-analyzer\", run_in_background: false, description: \"knowledge-sync $n\", prompt: <alles bis ----- ENDE>)"
  echo "scope: $n · mode: knowledge-sync · Projekt: $PROJ"
  quellen
  echo "$_N. Live-Auszug: $(mind_sampler_pfad "$PROJ" mind-update.json) (leer = keine neuen Ereignisse)"
  echo "Pruefe ZWEI Richtungen: (1) Session gegen Context-Dateien (UPDATE/ENRICH/ADD/NEW_FILE/INFO) und (2) BESTAND gegen seine Quellen:"
  case "$n" in
    claude-md) echo "- Jede NEVER/Gotcha-Zeile: nennt ihre Alternative noch den heutigen Weg? Vergleiche mit den juengsten 15 Eintraegen von docs/plugin/design-history.md (falls vorhanden) — betrifft eine neuere Faehigkeit denselben Gegenstand: ENRICH."
                echo "- Jeder Zeiger (\"Begruendung: X\", \"Details: X\"): steht der Gegenstand noch in X? Sonst UPDATE mit dem heutigen Ort." ;;
    memory)    echo "- Memory-Verzeichnis: ${MEMORY_DIR:-<get_memory_dir>}. Jedes ZITAT, das einer Datei zugeschrieben ist: steht der Wortlaut dort noch (auch ~/.claude/rules/)? Sonst UPDATE."
                echo "- Fehlplatzierung nach ~/.claude/rules/file-handling.md (Abschnitt Context files): Architektur, Pfade, Debug-Fixes, Versionshistorie gehoeren NICHT ins Memory — je Datei Ziel nennen (INFO, Klasse misplaced)." ;;
    # ⛔ v5.170.0: auch die Optionen, die das Werkzeug AUSWERTET. Gegentest 30.10.2026: `--entfernt` steht in
    #    `coverage_gate.py` erst ab Z. 152 (Docstring endet Z. 32) — „Aufruf-Kopf lesen“ reichte nicht hin.
    rules)     echo "- Jede Rule, die ein Werkzeug nennt (tools/*.py, Learnings/*.py, references/*.py): lies dessen Aufruf-Kopf/Docstring UND die Optionen, die es auswertet (grep -nE -- '--[a-z][a-z-]+' <werkzeug>, auch Kommentare und Argument-Teil). Fehlen dort dokumentierte Optionen, Stufen oder Rueckgabewerte in der Rule: UPDATE (Rule aelter als Werkzeug)."
                echo "- Jeder zitierte Wortlaut einer anderen Datei: steht er dort noch? Zahlen mit Messbefehl daneben: Befehl NICHT fahren, nur als INFO melden." ;;
    custom-context)
      prio=$(grep -oE '`[^`*?]*\.md`' "$PROJ/CLAUDE.md" 2>/dev/null | tr -d '`' | sed 's#^\./##' | awk '!g[$0]++' \
             | while IFS= read -r p; do [ -f "$PROJ/$p" ] && grep -qxF "./$p" "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)" 2>/dev/null && echo "$p"; done | head -15)
      echo "- ZUERST ganz lesen (von CLAUDE.md namentlich genannt, hoechstens 15):"
      printf '%s\n' "$prio" | sed '/^$/d; s/^/    /'
      echo "  Darin: als offen markierte Kriterien, die laut Bestand erledigt sind · Zeiger auf Auftraege/Etappen, die nicht mehr die juengsten sind · Zahlen ohne Messbefehl: UPDATE."
      echo "- Die uebrigen $(grep -c . "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)" 2>/dev/null) Dateien der Liste $(mind_sampler_pfad "$PROJ" mind-update-ccf.txt) NUR per Grep, nicht einzeln lesen." ;;
  esac
  echo "Nenne zu JEDEM Zitat die Datei und die Zeilennummer, aus der du es gelesen hast. Was du ohne Fundstelle schreibst, kennzeichne als UNGEPRUEFT."
  echo "Lege den Bericht nach SPAETESTENS 10 Werkzeugaufrufen mit Write als Zwischenstand an ($f) und ueberschreibe ihn am Ende mit dem VOLLEN Bericht — genau diese eine Datei, sonst nichts. Hoere erst auf, wenn er geschrieben ist."
  echo "----- ENDE $n -----"
}

if [ -n "$B" ]; then
  while IFS= read -r n; do
    mind_agent_dispatch "$n" "$PROJ" || exit 2
    echo "dispatch $n — Bericht-Pfad fuer den Auftrag: $(mind_agent_bericht_pfad "$n" "$PROJ")"
    auftrag "$n"
  done < <(liste "$B")
  echo "Jetzt die Welle starten: $(anzahl "$B") Agent(s) in EINER Nachricht, run_in_background: false — die Auftraege oben WOERTLICH."
  echo "⛔ Nicht mit ScheduleWakeup/sleep warten — die Rueckmeldung kommt von selbst."
else
  echo "Alle Bereiche quittiert — weiter mit der Agent-Bilanz."
  # ⛔ v5.167.0: die Befunde in den KONTEXT. Seit 5.162.0 stehen sie nur in Dateien; der volle Lauf 30.10.2026 wendete
  #    0 an (alt 4) — Step 4 hatte nichts vor sich. Rollen-Aufbau aendert das nicht: angewendet wird, was der Skill
  #    vorschreibt (manager-chats.md: die Linie ist die VORSCHRIFT).
  echo "=== BEFUNDE zum Anwenden (Step 4, AUTO_MODE=yes: UPDATE/ENRICH/ADD/NEW_FILE anwenden, DESIGN nicht) ==="
  for n in claude-md memory rules custom-context; do
    f=$(mind_agent_bericht_pfad "$n" "$PROJ" 2>/dev/null) || continue
    [ -s "$f" ] || continue
    echo "--- $n ($f)"
    grep -nE '\b(UPDATE|ENRICH|ADD|NEW_FILE)\b' "$f" 2>/dev/null | head -15 | cut -c1-240
  done
  echo "Je Befund: Ziel-Datei lesen, anwenden oder mit Grund als nicht angewendet melden — Schweigen zaehlt nicht."
fi
