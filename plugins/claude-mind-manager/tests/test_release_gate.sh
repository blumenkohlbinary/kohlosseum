#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # Fixtures unter einem Pfad MIT Leerzeichen
# v5.119.0 (Etappe 27 §2) — tools/release.sh faehrt die Pruefsammlung als GATE zwischen Bauen und Sync.
#   Anlass: 5.118.0 wurde am 16.09.2026 mit roter Ratsche registriert; das Skript fuhr die
#   Sammlung nicht, die CLAUDE.md verlangte sie nur als Handgriff davor.
#   Zusicherungen:
#     (1) Sammlung rot  -> rc 1, KEIN Sync (die Attrappe schreibt keinen Merker), suite.log liegt
#         ungekuerzt in der Sicherung, Meldung nennt (c2) und "KEIN Sync"
#     (2) --dry-run faehrt die Sammlung ebenfalls
#     (3) Sammlung gruen -> Sync laeuft, und zwar NACH der Sammlung (die Attrappe merkt sich, ob
#         der Sync-Merker beim Lauf schon da war)
#     (4) Positivkontrolle: dasselbe Skript OHNE den (c2)-Block synct trotz roter Sammlung —
#         sonst misst dieser Prueffall nichts
#   ⛔ Alles auf einer KOPIE mit Attrappen (MIND_RELEASE_* zeigen in ein Temp-Verzeichnis), nie am
#      echten Cache, nie an der echten Registry.
set -u
[ -n "${CLAUDE_PROJECT_DIR:-}" ] || { echo "CLAUDE_PROJECT_DIR fehlt (der Workspace mit tools/release.sh)" >&2; exit 2; }
REL="$CLAUDE_PROJECT_DIR/tools/release.sh"
OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }

janein "tools/release.sh liegt im Workspace" ja "$([ -f "$REL" ] && echo ja || echo nein)"
[ -f "$REL" ] || { echo "  $OK ok, $ROT rot"; exit 1; }

T=$(mktemp -d); V=9.9.9
SRC="$T/src"; Q="$SRC/plugins/claude-mind-manager"
mkdir -p "$SRC/.claude-plugin" "$Q/.claude-plugin" "$Q/references" "$Q/tests" "$T/cache" "$T/sich" "$T/ws"
printf '{"name":"claude-mind-manager","version":"%s"}\n' "$V" > "$Q/.claude-plugin/plugin.json"
printf '{"plugins":[{"name":"claude-mind-manager","version":"%s"}]}\n' "$V" > "$SRC/.claude-plugin/marketplace.json"
printf 'print("Attrappe Schutz-Gate: keine lebenden Versionen")\n' > "$Q/references/sync_schutz_gate.py"
# Die Sammlungs-Attrappe: rc aus einer Datei, und sie schreibt auf, ob der Sync-Merker schon da war.
cat > "$Q/tests/alle.sh" <<'EOF'
#!/usr/bin/env bash
echo "ATTRAPPE alle.sh  PLUGIN_ROOT=$CLAUDE_PLUGIN_ROOT  PROJECT_DIR=$CLAUDE_PROJECT_DIR"
[ -f "$STUB_DIR/SYNC-LIEF" ] && echo "SYNC-WAR-SCHON-DA" || echo "SYNC-NOCH-NICHT"
echo "gefunden 1 / gefahren 1 / gruen $([ "$(cat "$STUB_DIR/suite_rc")" = 0 ] && echo 1 || echo 0)"
exit "$(cat "$STUB_DIR/suite_rc")"
EOF
# Die Sync-Attrappe: Merker + Registry, damit (e) gruen werden kann.
cat > "$T/sync.py" <<'EOF'
import json, os, sys
d = os.environ["STUB_DIR"]; ver = sys.argv[3]
open(os.path.join(d, "SYNC-LIEF"), "w").write(ver)
json.dump({"plugins": {"claude-mind-manager@kohlosseum": {"version": ver}}}, open(os.path.join(d, "installed.json"), "w"))
print("Attrappe Sync: registriert", ver)
EOF
w() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
export STUB_DIR="$(w "$T")"
export MIND_RELEASE_SRC="$(w "$SRC")" MIND_RELEASE_CACHE="$(w "$T/cache")" MIND_RELEASE_KLON="$(w "$T/klon")" \
       MIND_RELEASE_SYNC="$(w "$T/sync.py")" MIND_RELEASE_SICHERUNG="$(w "$T/sich")" \
       MIND_RELEASE_REGISTRY="$(w "$T/installed.json")" MIND_RELEASE_WORKSPACE="$(w "$T/ws")"
lauf() { rm -f "$T/SYNC-LIEF"; rm -rf "$T/sich"/*; (cd "$T/ws" && bash "$1" "$V" ${2:-}) > "$T/out.txt" 2>&1; echo $?; }

echo "== (1) Sammlung rot -> kein Sync =="
echo 1 > "$T/suite_rc"
RC=$(lauf "$REL")
janein "rc 1" 1 "$RC"
janein "kein Sync gefahren (Merker fehlt)" nein "$([ -f "$T/SYNC-LIEF" ] && echo ja || echo nein)"
SL=$(ls "$T/sich"/*/suite.log 2>/dev/null | head -1)
janein "suite.log liegt in der Sicherung" ja "$([ -n "$SL" ] && echo ja || echo nein)"
janein "   ... ungekuerzt (Attrappen-Ausgabe drin)" ja "$(grep -q 'ATTRAPPE alle.sh' "$SL" 2>/dev/null && echo ja || echo nein)"
janein "   ... CLAUDE_PLUGIN_ROOT zeigt auf das GEBAUTE Paket <cache>/<ver>" ja "$(grep -q "PLUGIN_ROOT=$(w "$T/cache")/$V " "$SL" 2>/dev/null && echo ja || echo nein)"
janein "   ... CLAUDE_PROJECT_DIR ist der Workspace" ja "$(grep -q "PROJECT_DIR=$(w "$T/ws")" "$SL" 2>/dev/null && echo ja || echo nein)"
janein "Meldung nennt (c2) und KEIN Sync" ja "$(grep -q '(c2) Pruefsammlung rc=1 — KEIN Sync' "$T/out.txt" && echo ja || echo nein)"
janein "gebaut wurde vorher (cache/<ver> liegt)" ja "$([ -f "$T/cache/$V/.claude-plugin/plugin.json" ] && echo ja || echo nein)"

echo "== (2) --dry-run faehrt die Sammlung ebenfalls =="
RC=$(lauf "$REL" --dry-run)
janein "dry-run mit roter Sammlung: rc 1" 1 "$RC"
janein "   ... suite.log liegt auch im dry-run" ja "$([ -n "$(ls "$T/sich"/*/suite.log 2>/dev/null)" ] && echo ja || echo nein)"
echo 0 > "$T/suite_rc"
RC=$(lauf "$REL" --dry-run)
janein "dry-run mit gruener Sammlung: rc 0, kein Sync" "0 nein" "$RC $([ -f "$T/SYNC-LIEF" ] && echo ja || echo nein)"

echo "== (3) Sammlung gruen -> Sync, und zwar NACH der Sammlung =="
RC=$(lauf "$REL")
janein "rc 0" 0 "$RC"
janein "Sync gefahren" ja "$([ -f "$T/SYNC-LIEF" ] && echo ja || echo nein)"
SL=$(ls "$T/sich"/*/suite.log 2>/dev/null | head -1)
janein "Sammlung lief VOR dem Sync" ja "$(grep -q 'SYNC-NOCH-NICHT' "$SL" 2>/dev/null && echo ja || echo nein)"
janein "(c2) ok gemeldet" ja "$(grep -q '(c2) Pruefsammlung rc=0' "$T/out.txt" && echo ja || echo nein)"

echo "== (4) Positivkontrolle: ohne (c2)-Block synct das Skript trotz roter Sammlung =="
echo 1 > "$T/suite_rc"
sed '/^# --- (c2) Pruefsammlung/,/^ok "(c2)/d' "$REL" > "$T/release_ohne_c2.sh"
janein "Kontrollskript hat den Block verloren" nein "$(grep -q 'WORKSPACE" bash tests/alle.sh' "$T/release_ohne_c2.sh" && echo ja || echo nein)"
RC=$(lauf "$T/release_ohne_c2.sh")
janein "ohne Gate: Sync laeuft trotz rc 1 der Sammlung (der Prueffall misst also das Gate)" ja "$([ -f "$T/SYNC-LIEF" ] && echo ja || echo nein)"

rm -rf "$T"
echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
