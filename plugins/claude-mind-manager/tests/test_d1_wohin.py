# -*- coding: utf-8 -*-
"""D1 „Wohin gehört diese Aussage?" (v5.39.0, ZIEL 3).

⛔ DIE LÜCKE. Die acht Tore des Plugins fragen alle „darf das rein?". KEINES fragt
   „wohin?". B3 prüft, ob eine Aussage am SCHON GEWÄHLTEN Ort wirkt — es kann
   zustimmen oder ablehnen, nicht umleiten. Ein Türsteher, kein Wegweiser.

⭐ DIE POSITIVKONTROLLE HAT DIE ERSTE FASSUNG VERWORFEN, und das ist der Grund,
   warum diese Sammlung existiert. Fassung 1 nahm ⛔/NIE/MUSS als alleiniges
   Merkmal und zählte ZEILEN. Ergebnis:

     Leitplanke (bekannt BREMSE)      38 % BREMSE
     Command-Volltext (bekannt ANL.)  47 % BREMSE   <- MEHR, also falsch herum

   Zwei Fehler auf einmal: der Nutzer schreibt ⛔ auch in langer Prosa, und ein
   einziger 147-Wörter-Absatz überwog beim Zeilenzählen zehn kurze.

Aufruf:  python tests/test_d1_wohin.py
Rückgabe: 0 = alle grün · 1 = mindestens ein Fall rot
"""
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

WURZEL = os.environ.get("CLAUDE_PLUGIN_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(WURZEL, "references"))

from cleaner_einordnung import d1_wohin, _D1_MAX_WOERTER  # noqa: E402

gruen = rot = 0


def pruef(name, bed, zusatz=""):
    global gruen, rot
    if bed:
        gruen += 1
        print("  [ok ] %s" % name)
    else:
        rot += 1
        print("  [ROT] %s %s" % (name, zusatz))


LANG = " ".join(["wort"] * (_D1_MAX_WOERTER + 10))

print("=== 1) Die vier Klassen ===")
pruef("kurzes Verbot -> BREMSE",
      d1_wohin("⛔ NIE `git push` aus diesem Workspace.") == "BREMSE",
      "(ist %s)" % d1_wohin("⛔ NIE `git push` aus diesem Workspace."))
pruef("Aufruf mit Schalter -> ANLEITUNG",
      d1_wohin("Aufruf: `python tools/rollback.py list --alle`") == "ANLEITUNG",
      "(ist %s)" % d1_wohin("Aufruf: `python tools/rollback.py list --alle`"))
pruef("Messung mit Datum -> BELEG",
      d1_wohin("Gemessen am 21.08.2026 lagen dort 32 MB in neun Kopien.") == "BELEG",
      "(ist %s)" % d1_wohin("Gemessen am 21.08.2026 lagen dort 32 MB in neun Kopien."))
pruef("⚠ nichts trifft -> UNBESTIMMT, NICHT Anleitung",
      d1_wohin("Dieser Abschnitt beschreibt den Aufbau des Ordners.") == "UNBESTIMMT",
      "(ist %s)" % d1_wohin("Dieser Abschnitt beschreibt den Aufbau des Ordners."))

print()
print("=== 2) ⭐ Der Fehler, an dem Fassung 1 gescheitert ist ===")
kurz = "⛔ NIE mit Edit auf Z: schreiben."
lang = "⛔ " + LANG
pruef("kurzer Absatz mit ⛔ -> BREMSE", d1_wohin(kurz) == "BREMSE")
pruef("⭐ LANGER Absatz mit ⛔ -> NICHT Bremse, sondern ANLEITUNG",
      d1_wohin(lang) == "ANLEITUNG", "(ist %s)" % d1_wohin(lang))
pruef("   ... denn das Zeichen allein hob den Command ueber die Leitplanke",
      d1_wohin(kurz) != d1_wohin(lang))

print()
print("=== 3) Die Schwelle steht zwischen zwei Messungen ===")
# 39,5 Woerter = gui-Leitplanke (BREMSE) · 56,0 = z-mount-Command (ANLEITUNG)
pruef("Schwelle liegt ueber der gemessenen Bremse (39,5)", _D1_MAX_WOERTER > 40,
      "(ist %d)" % _D1_MAX_WOERTER)
pruef("Schwelle liegt unter der gemessenen Anleitung (56,0)", _D1_MAX_WOERTER < 56,
      "(ist %d)" % _D1_MAX_WOERTER)
knapp_drunter = "⛔ " + " ".join(["w"] * (_D1_MAX_WOERTER - 2))
knapp_drueber = "⛔ " + " ".join(["w"] * (_D1_MAX_WOERTER + 2))
pruef("knapp darunter -> BREMSE", d1_wohin(knapp_drunter) == "BREMSE")
pruef("knapp darueber -> ANLEITUNG", d1_wohin(knapp_drueber) == "ANLEITUNG")

print()
print("=== 4) ⭐ POSITIVKONTROLLE an ECHTEN Dateien ===")
# ⛔ Konstruierte Faelle bilden die eigene Erwartung ab. Diese fuenf sind echt
#    und ihre Rolle steht fest: zwei Leitplanken, zwei Commands, ein Archiv.
H = os.path.expanduser("~")
PROJ = os.path.dirname(os.path.dirname(os.path.dirname(WURZEL)))
FAELLE = [
    ("Leitplanke z-mount", os.path.join(H, ".claude/rules/z-mount-rclone.md"), "hoch"),
    ("Leitplanke gui", os.path.join(H, ".claude/rules/gui-pruefung-in-vm.md"), "hoch"),
    ("Command z-mount", os.path.join(H, ".claude/skills/z-mount-rclone/SKILL.md"), "niedrig"),
    ("Command gui", os.path.join(H, ".claude/skills/gui-pruefung-in-vm/SKILL.md"), "niedrig"),
]


def bremse_anteil(pfad):
    from cleaner_einordnung import absaetze
    with io.open(pfad, encoding="utf-8", errors="replace") as fh:
        a, _, _ = absaetze(fh.read())
    if not a:
        return None
    return 100.0 * sum(1 for x in a if d1_wohin(x) == "BREMSE") / len(a)


werte = {}
for name, pfad, erwartet in FAELLE:
    if not os.path.isfile(pfad):
        print("  [uebersprungen] %s fehlt — ein uebersprungener Fall ist KEIN"
              " bestandener" % name)
        continue
    p = bremse_anteil(pfad)
    werte[name] = p
    print("      %-22s BREMSE %4.0f %%  (erwartet %s)" % (name, p, erwartet))

if len(werte) == 4:
    tiefste_leitplanke = min(werte["Leitplanke z-mount"], werte["Leitplanke gui"])
    hoechster_command = max(werte["Command z-mount"], werte["Command gui"])
    pruef("⭐ JEDE Leitplanke hat mehr BREMSE als JEDER Command",
          tiefste_leitplanke > hoechster_command,
          "(niedrigste Leitplanke %.0f %% vs hoechster Command %.0f %%)"
          % (tiefste_leitplanke, hoechster_command))
    pruef("   ... und der Abstand ist nicht knapp (Faktor >= 2)",
          tiefste_leitplanke >= 2 * hoechster_command,
          "(%.0f %% gegen %.0f %%)" % (tiefste_leitplanke, hoechster_command))
else:
    print("  [uebersprungen] nicht alle vier Dateien vorhanden")

# ⛔ v5.114.0 (Etappe 21 §2): die Negativkontrolle „ein Archiv hat 0 % BREMSE" hatte
#    ihre Praemisse verloren UND wurde am Paket uebersprungen-gruen.
#    (a) Der Archivpfad kam aus CLAUDE_PLUGIN_ROOT — im Cache gibt es ihn nicht, der Fall
#        stand als [uebersprungen] da, die Sammlung war gruen, ohne zu messen (dieselbe
#        Klasse wie CLAUDE_PROJECT_DIR/v5.72.0). Jetzt: CLAUDE_PROJECT_DIR/.claude/archiv/,
#        und FEHLT er, ist das rc 3 „nicht messbar" — nie ein bestandener Lauf.
#    (b) Seit dem Verdichten (v5.100.0, 12.09.2026) haelt das Archiv Entferntes WOERTLICH,
#        samt ⛔-Absaetzen — env-vars.archiv.md traegt 8 % Bremsanteil, gewollt. Das ZIEL
#        der Kontrolle bleibt (reine Erklaerung ist keine Bremse): sie misst jetzt ein
#        festes Fixture ohne verbatim-Bremsen. Dazu die Kontrolle, die seit dem Verdichten
#        zaehlt: jeder ⛔-Absatz im Archiv hat seine Marker (Code-Spans, Zahlen, Namen —
#        coverage_gate.checkpoints) noch in der LEBENDEN Datei (Kasten-Zeile v5.101.0).
import tempfile as _tempfile
_fx = _tempfile.mkdtemp(prefix="d1 neg ")
_neg = os.path.join(_fx, "erklaerung.md")
with io.open(_neg, "w", encoding="utf-8") as fh:
    fh.write(u"# Warum es diese Datei gibt\n\n"
             u"Die Rotation der Snapshots wurde am 16.08.2026 gemessen, weil neun Kopien mit 32 MB im\n"
             u"Ordner lagen. Ursache war eine Zeile, die Pfade an Leerzeichen zerlegte; seither gibt es\n"
             u"die Funktion nur noch einmal.\n\n"
             u"Der Auswaehler fuer das Gedaechtnis sieht nur Dateiname und Beschreibung. Deshalb traegt\n"
             u"eine gute Beschreibung mehr als eine kurze Datei, und die Zahl der Dateien allein sagt\n"
             u"wenig ueber die Erreichbarkeit.\n\n"
             u"Die Formel fuer die Kompaktierung lautete lange 880 000 und wurde am 27.08.2026 an drei\n"
             u"Werten widerlegt; gemessen greift sie bei etwa 966 000.\n")
p = bremse_anteil(_neg)
pruef("⭐ NEGATIVKONTROLLE: reine Erklaerung hat 0 %% BREMSE (festes Fixture)", p == 0,
      "(ist %.0f %%)" % (p if p is not None else -1))
import shutil as _shutil
_shutil.rmtree(_fx, ignore_errors=True)

PROJEKT = os.environ.get("CLAUDE_PROJECT_DIR") or ""
arch = os.path.join(PROJEKT, ".claude/archiv/env-vars.archiv.md")
lebend = os.path.join(PROJEKT, ".claude/rules/env-vars.md")
if not (PROJEKT and os.path.isfile(arch) and os.path.isfile(lebend)):
    print("  [ROT] NICHT MESSBAR: Archiv/lebende Datei nicht unter CLAUDE_PROJECT_DIR"
          " (%s) — rc 3, kein bestandener Lauf" % (PROJEKT or "leer"))
    print()
    print("  %d gruen · %d rot · 1 nicht messbar" % (gruen, rot))
    sys.exit(3)
# ⛔ v5.117.0 (Anton, 16.09.2026): die Marker eines Archiv-Absatzes muessen NICHT in der
#    gleichnamigen Datei liegen — der 09.09.-Umzug („UMZIEHEN, nicht kopieren") trug vier
#    Marker aus rollen.archiv.md nach werkzeuge-zuerst.md, kontext-anlegen.md und
#    manager-chats.md. Gemessen wird deshalb gegen ALLE lebenden Dauerkontext-Dateien
#    (global + Projekt, die Liste von mind_kontext_bilanz) und ueber ALLE Archive. Bekannte
#    Loecher sind Historie (Anton, gemessen 16.09.): backup-usage 1, hooks 1, rollen 1 —
#    die Ratsche laesst sie zu und wird rot, sobald ein Archiv MEHR verliert.
import glob as _glob
_H = os.path.expanduser("~")
_lebend = [os.path.join(PROJEKT, "CLAUDE.md"), os.path.join(PROJEKT, ".claude", "CLAUDE.md"),
           os.path.join(_H, ".claude", "CLAUDE.md")] \
    + _glob.glob(os.path.join(PROJEKT, ".claude", "rules", "*.md")) \
    + _glob.glob(os.path.join(_H, ".claude", "rules", "*.md"))
_BEKANNT = {"backup-usage": 1, "hooks": 1, "rollen": 1}
sys.path.insert(0, os.path.join(WURZEL, "references", "doc-templates"))
_halte = sys.stdout  # coverage_gate legt beim Import einen neuen Wrapper um .buffer; ohne Referenz schloesse der GC unseren und damit den Puffer
from coverage_gate import checkpoints, normalize  # noqa: E402,F841 — _halte bleibt referenziert, der neue Wrapper schreibt weiter
from cleaner_einordnung import absaetze  # noqa: E402
_leb = normalize("\n".join(io.open(f, encoding="utf-8", errors="replace").read()
                            for f in _lebend if os.path.isfile(f)))


def _loecher(archiv):
    with io.open(archiv, encoding="utf-8", errors="replace") as fh:
        _abs, _, _ = absaetze(fh.read())
    _brems = [a for a in _abs if a.lstrip().startswith(u"\u26d4")]
    _fehl = []
    for _a in _brems:
        _tf = _tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8")
        _tf.write(_a); _tf.close()
        _miss = [ph for ph, kw in checkpoints(_tf.name) if kw[0] not in _leb]
        os.unlink(_tf.name)
        if _miss:
            _fehl.append((_a[:60].replace("\n", " "), _miss[:3]))
    return _abs, _brems, _fehl


_abs, _brems, _fehl = _loecher(arch)
p = bremse_anteil(arch)
print("      Archiv env-vars: %d Absaetze, BREMSE %.0f %%, %d \u26d4-Absaetze" % (len(_abs), p, len(_brems)))
pruef("\u26d4 Archiv: das Verdichten haelt Bremsen WOERTLICH (Bremsanteil > 0, Praemisse seit v5.100.0)",
      p is not None and p > 0, "(ist %s)" % p)
pruef("\u2b50 jeder \u26d4-Absatz im env-vars-Archiv hat seine Marker im lebenden Dauerkontext (Kasten-Zeile v5.101.0)",
      len(_brems) > 0 and not _fehl,
      "(%d von %d ohne Marker: %s)" % (len(_fehl), len(_brems), _fehl[:2]))
for _ap in sorted(_glob.glob(os.path.join(PROJEKT, ".claude", "archiv", "*.archiv.md"))):
    _n = os.path.basename(_ap)[:-len(".archiv.md")]
    if _n == "env-vars":
        continue
    _abs2, _brems2, _fehl2 = _loecher(_ap)
    _erlaubt = _BEKANNT.get(_n, 0)
    pruef("   Ratsche %s: hoechstens %d bekannte(s) Loch/Loecher (Historie), gemessen %d von %d \u26d4-Absaetzen"
          % (_n, _erlaubt, len(_fehl2), len(_brems2)), len(_fehl2) <= _erlaubt,
          "(neu ohne Marker: %s)" % _fehl2[:2])

print()
print("  %d gruen · %d rot" % (gruen, rot))
sys.exit(1 if rot else 0)
