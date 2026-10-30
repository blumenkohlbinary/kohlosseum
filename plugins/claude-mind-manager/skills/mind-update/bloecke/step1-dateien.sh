#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
UNTER_KONTEXT=$(mind_unterordner_kontext "$PROJ" 2>/dev/null)   # leer ohne Rollen-Aufbau
# ---- Block ----
# Hash + Memory-Verzeichnis (v3.2.2: zentralisiert in lib.sh)
# Nutzt cygpath fuer korrektes Windows-Slug-Mapping (siehe lib.sh hash_project_dir)
# M3-Fix: $CLAUDE_PLUGIN_ROOT Guard vor source
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
if [ -z "$CLAUDE_PLUGIN_ROOT" ] || [ ! -f "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" ]; then
  echo "ERROR: \$CLAUDE_PLUGIN_ROOT nicht gesetzt oder lib.sh nicht gefunden" >&2
  exit 1
fi
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
MEMORY_DIR=$(get_memory_dir)
GET_MEM_RC=$?  # H1-Fix Skill-Review v3.3.1: $? in Variable capturen vor naechstem Cmd
# H2-aware: $? = 1 wenn Fallback verwendet wurde
if [ "$GET_MEM_RC" = "1" ]; then
  echo "WARN: MEMORY-Dir-Fallback aktiv — Slug-Mismatch erkannt" >&2
fi

# ⛔ v5.81.0 — UNTERORDNER-AUFBAU: das Memory gehoert zum cwd der RETTUNG, nicht
#    zu $PROJ. Claude Code laedt das Memory des Ordners, in dem die Sitzung lief;
#    $PROJ ist seit v5.80.0 die Wurzel mit dem Roster. Jede Rettung nennt ihren
#    cwd (mind_rettung_cwd) — fehlt er (Rettung vor v5.81.0), gilt $PROJ wie bisher.
#    ⭐ Diese Tabelle geht WOERTLICH an den memory-Agenten in Step 3.5: er schreibt
#    die Erkenntnisse einer Rettung in DEREN Memory (Spalte 3), nie in $MEMORY_DIR,
#    wenn die Spalte abweicht. Das ist kein Rueckfall auf ein fremdes Projekt
#    (v5.70.0-Verbot): der Ordner kommt AUS DER RETTUNG, nicht aus einem `ls -t`.
RETTUNGS_MEMORY=""
while IFS= read -r _r; do
  [ -n "$_r" ] || continue
  _c=$(mind_rettung_cwd "$PROJ" "$_r" 2>/dev/null) || _c="$PROJ"
  _m=$(get_memory_dir "$_c" 2>/dev/null) || true
  RETTUNGS_MEMORY="${RETTUNGS_MEMORY}${_r}|${_c}|${_m}"$'\n'
done < <(mind_rettungen "$PROJ" 2>/dev/null)
[ -n "$RETTUNGS_MEMORY" ] && { echo "Memory je Rettung (rettung|cwd|memory):"; printf '%s' "$RETTUNGS_MEMORY" | sed 's/^/  /'; }

# MEMORY.md (Hauptdatei)
MEMORY_MAIN="$MEMORY_DIR/MEMORY.md"

# Topic-Files-Glob (NEU v3.2.1) — alle .md im memory-Verzeichnis AUSSER MEMORY.md
TOPIC_FILES=$(ls "$MEMORY_DIR"/*.md 2>/dev/null | grep -v "/MEMORY.md$")

# Project Rules — v5.106.0: plus die Rules der Roster-Unterordner (leer ohne Rollen-Aufbau)
PROJECT_RULES=$(ls .claude/rules/*.md 2>/dev/null; mind_unterordner_kontext "$PROJ" 2>/dev/null | grep '/rules/')

# Global Rules
GLOBAL_RULES=$(ls "$HOME"/.claude/rules/*.md 2>/dev/null)
# ---- Block ----
# Step 1.5 darf KEINE Files erneut als Custom Context aufnehmen die
# Step 1 schon hat (CLAUDE.md, MEMORY, Topic-Files, Rules) — sonst
# Double-Counting in Step 3a Version-Match (Bug B1 v3.2.2 Skill-Review).
SKIP_SET=("./CLAUDE.md" "./.claude/CLAUDE.md" "$MEMORY_MAIN")

# Add MEMORY-Topic-Files + Project-Rules + Global-Rules (von Step 1)
while IFS= read -r f; do SKIP_SET+=("$f"); done <<< "$TOPIC_FILES"
while IFS= read -r f; do SKIP_SET+=("$f"); done <<< "$PROJECT_RULES"
while IFS= read -r f; do SKIP_SET+=("$f"); done <<< "$GLOBAL_RULES"

is_in_skip_set() {
  local target="$1"
  for skip in "${SKIP_SET[@]}"; do
    [ "$skip" = "$target" ] && return 0
    # Normalize ./path vs path
    [ "$skip" = "./$target" ] && return 0
    [ "./$skip" = "$target" ] && return 0
  done
  return 1
}
# ---- Block ----
# Whitelist nur Doku-Formate (.md/.txt/.rst) — KEINE .json/.yaml/.py
# (das sind Build-Configs/Source-Files, nicht Custom Context)
REFERENCED=$(
  grep -hoE '`[^`]*\.(md|txt|rst)`' \
    CLAUDE.md .claude/rules/*.md ~/.claude/rules/*.md 2>/dev/null |
  sed 's|^`||; s|`$||' |
  sort -u
)
# ---- Block ----
# Optional: User-Override via .mindcontext (EC1)
if [ -f .mindcontext ]; then
  # Explizite Liste — Heuristik skippen
  CUSTOM_CONTEXT_FILES=()
  while IFS= read -r line; do
    # Skip Kommentare + leere Zeilen
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # Glob-Expansion
    for f in $line; do
      [ -f "$f" ] && CUSTOM_CONTEXT_FILES+=("$f")
    done
  done < .mindcontext
else
  # Glob alle .md ausser ignorierte
  ALL_MD=$(find . -name "*.md" \
    -not -path "./.venv/*" \
    -not -path "./.git/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -not -path "./node_modules/*" \
    -not -path "./.pytest_cache/*" \
    -not -path "./.claude-mind/*" \
    -not -path "./CLAUDE.md" \
    -not -path "./.claude/rules/*" \
    2>/dev/null)

  TOTAL_MD=$(echo "$ALL_MD" | wc -l)

  # Tiered Schwelle (EC1: gross-Projekte)
  if [ "$TOTAL_MD" -gt 100 ]; then
    SCORE_THRESHOLD=3
    echo "INFO: $TOTAL_MD .md Files gefunden — Heuristik-Schwelle erhoeht auf score >= 3"
    echo "      Tipp: .mindcontext anlegen fuer explizite User-Konfiguration"
  else
    SCORE_THRESHOLD=2  # User-Direktive Default
  fi

  CUSTOM_CONTEXT_FILES=()

  # 2a: Alle referenzierten Files (deterministisch, Phase 1)
  # ⛔ v5.150.0 (Antons Entscheidung 28.10.2026): ZEILENWEISE, nicht `for ref in $REFERENCED` — das
  #    zerlegte jeden Pfad mit Leerzeichen in Stuecke, die es nicht gibt; eine solche Datei wurde nie
  #    bewertet. Dass sich die Liste damit aendert, ist der Zweck.
  # ⛔ Und die GLOB-Expansion, die das alte `for` nebenbei leistete, bleibt — jetzt ausdruecklich
  #    (`compgen -G`, ohne Zerlegen): ein Verweis wie `wissen/reinraum/*-funktion.md` holt seine Dateien
  #    (CK3: 40). ⚠ Verweise unter `.claude-mind/` fallen heraus: so kamen die geretteten Chats
  #    (`.claude-mind/rescued/*_chat.md`, je mehrere hundert KB) als „Custom Context" in den Sync.
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "${ref#./}" in .claude-mind/*) continue ;; esac
    case "$ref" in
      *[\*\?\[]*)
        while IFS= read -r candidate; do
          [ -n "$candidate" ] && [ -f "$candidate" ] || continue
          case "${candidate#./}" in .claude-mind/*) continue ;; esac
          is_in_skip_set "./${candidate#./}" && continue
          [[ " ${CUSTOM_CONTEXT_FILES[@]} " =~ " ./${candidate#./} " ]] && continue
          CUSTOM_CONTEXT_FILES+=("./${candidate#./}")
        done < <(compgen -G "$ref" 2>/dev/null)
        continue ;;
    esac
    for candidate in "./$ref" "$ref"; do
      if [ -f "$candidate" ] && ! is_in_skip_set "$candidate"; then
        CUSTOM_CONTEXT_FILES+=("$candidate")
        break
      fi
    done
  done <<< "$REFERENCED"

  # 2b: Heuristik fuer nicht-referenzierte .md
  # ⛔ v5.149.0 (Etappe 57 §2, CK3): FUENF grep UEBER ALLE DATEIEN statt fuenf grep JE Datei. Vorher
  #    5 x N Prozesse (CK3: 245 Dateien, ueber 300 s; hier gemessen 84,4 s fuer 401 Eintraege). Dieselben
  #    Muster, derselbe grep — die Zaehlungen sind dieselben, die Ausgabe byteweise gleich (Gegenprobe
  #    an zwei Projekten, alter gegen neuen Block). `-H`, damit auch EINE Datei ihren Namen traegt.
  # ⛔ v5.150.0: ZEILENWEISE (bis v5.149.0 `for f in $ALL_MD`, zerlegte an Leerzeichen — siehe 2a).
  _KAND=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # Skip wenn bereits in Step 1 Liste (B1-Fix)
    is_in_skip_set "$f" && continue
    # Skip wenn bereits via Referenz aufgenommen
    [[ " ${CUSTOM_CONTEXT_FILES[@]} " =~ " $f " ]] && continue
    [[ " ${_KAND[@]} " =~ " $f " ]] && continue
    _KAND+=("$f")
  done <<< "$ALL_MD"
  declare -A _SCORE=()
  if [ "${#_KAND[@]}" -gt 0 ]; then
    while IFS= read -r _z; do
      _f="${_z%:*}"; _c="${_z##*:}"
      case "$_c" in ''|*[!0-9]*) _c=0 ;; esac
      _SCORE["$_f"]=$(( ${_SCORE["$_f"]:-0} + _c ))
    done < <(
      # ⚠ per `xargs -0` in Teilen: EINE Befehlszeile mit allen Pfaden sprengt bei grossen Projekten
      #   das Windows-Limit (~32 000 Zeichen) — dann scheitert grep, und JEDER Wert waere still 0.
      #   `-0` zerlegt nicht an Leerzeichen (die Falle aus „Rotation nie mit xargs" greift hier nicht).
      printf '%s\0' "${_KAND[@]}" | xargs -0 grep -cH '```' -- 2>/dev/null
      printf '%s\0' "${_KAND[@]}" | xargs -0 grep -cHE '`[^`]*[/\\][^`]*`' -- 2>/dev/null
      printf '%s\0' "${_KAND[@]}" | xargs -0 grep -cHE 'v[0-9]+\.[0-9]+' -- 2>/dev/null
      printf '%s\0' "${_KAND[@]}" | xargs -0 grep -cHE '\b[0-9]{2,4}\s+[Tt]ests?\b' -- 2>/dev/null
      printf '%s\0' "${_KAND[@]}" | xargs -0 grep -cHE '`[a-z_][a-zA-Z0-9_]*\(\)`|`[A-Z][a-zA-Z0-9]+\.[a-zA-Z_]+`' -- 2>/dev/null
    )
  fi
  for f in "${_KAND[@]}"; do
    if [ "${_SCORE["$f"]:-0}" -ge "$SCORE_THRESHOLD" ]; then
      CUSTOM_CONTEXT_FILES+=("$f")
    fi
  done
fi

# ⛔ v5.147.0 (Etappe 56 §5, CK3): EINE Schreibweise je Datei. Ein Verweis, der selbst mit `./`
#    beginnt, wurde zu `././docs/x.md` und zaehlte neben `./docs/x.md` aus dem Scan doppelt
#    (CK3: 24 statt 19). Normalisiert auf `./<pfad>`, Reihenfolge bleibt, Doppel fallen weg.
if [ "${#CUSTOM_CONTEXT_FILES[@]}" -gt 0 ]; then
  mapfile -t CUSTOM_CONTEXT_FILES < <(printf '%s\n' "${CUSTOM_CONTEXT_FILES[@]}" \
    | sed 's#^\(\./\)*##; s#^#./#' | awk '!gesehen[$0]++')
fi
echo "Custom Context discovered: ${#CUSTOM_CONTEXT_FILES[@]} files"

# ⛔ v5.153.0: die Liste in eine Datei JE SITZUNG (mind_sampler_pfad, raeumt mind_sampler_aufraeumen weg).
#    Als Array allein war sie im naechsten Block LEER: 3.5 quittierte dann "custom-context uebersprungen,
#    0 Dateien" und senkte die Erwartung auf 3 Agents — der Lauf galt als voll, ohne den Bereich zu pruefen.
_CCF="$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)"
printf '%s\n' "${CUSTOM_CONTEXT_FILES[@]}" | grep . > "$_CCF" 2>/dev/null; : >> "$_CCF"
echo "Custom-Context-Liste ($(grep -c . "$_CCF") Datei(en)) -> $_CCF"
