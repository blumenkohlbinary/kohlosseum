#!/bin/bash
# Claude Mind Manager — Rollen-Gate (NEU v5.54.0)
#
# Aufruf:  bash rollen-gate.sh <session_id> <projekt>
# Rueckgabe: 0 = eine ANDERE Sitzung ist fuer den Sync zustaendig -> STILL SEIN
#            1 = niemand sonst, oder nicht entscheidbar           -> reden wie heute
# Auf stdout steht bei Rueckgabe 0 die eigene Rolle — fuer das Protokoll des Aufrufers.
#
# ⛔ WARUM EINE HUELLE UND KEIN `source` IM HOOK.
#    `prompt-submit.sh` laeuft bei JEDER Nachricht und sourct `lib.sh` bewusst
#    nicht im Kopf (Startkosten je Tastendruck). Dieselbe Bauform wie
#    `plan-pause.sh` (v5.28.0) und `kontext-wache.sh` (v5.33.0): ein
#    Subprozess, der nur dann ueberhaupt startet, wenn es etwas zu pruefen gibt.
#    ⚠ Der Aufrufer prueft VORHER, ob `.claude/rules/rollen.md` existiert —
#      ohne Roster gibt es keinen Fork.
#
# ⛔ HIER WIRD NICHTS ENTSCHIEDEN. Die Entscheidung steht in
#    `mind_sync_zustaendig` in lib.sh, an genau einer Stelle. Diese Datei
#    reicht sie durch. Wer sie hier nachbaut, faellt unter
#    `instrument-nachgebaut` (7 Vorkommen, kein Nachbau war besser).

SID="${1:-}"
PROJ="${2:-}"

[ -n "$SID" ] || exit 1
[ -n "$PROJ" ] || exit 1
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 1
[ -f "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" ] || exit 1

# shellcheck disable=SC1091
. "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" 2>/dev/null

# ⚠ Fail-safe: ist die Funktion nicht da (alte lib.sh, kaputtes Paket), wird
#   geredet wie heute. Ein stummer Hook ist der teurere Fehler.
command -v mind_sync_zustaendig >/dev/null 2>&1 || exit 1

if mind_sync_zustaendig "$SID" "$PROJ"; then
  printf '%s' "$(mind_rolle "$SID" "$PROJ")"
  exit 0
fi
exit 1
