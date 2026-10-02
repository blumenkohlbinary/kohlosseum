# -*- coding: utf-8 -*-
u"""Die Ablage fuer /mind-denkstufe: EINE fuer alle Projekte.

Aufrufe
-------
    denkstufe_ablage.py --anlegen [--neu]        Startbestand schreiben (nur wenn leer)
    denkstufe_ablage.py --lesen                  Kennzahlen + Aussagen ausgeben
    denkstufe_ablage.py --alter                  rc 0 = frisch, rc 1 = abgelaufen
    denkstufe_ablage.py --aufgabe "<text>"       gespeicherte Antwort lesen (rc 1 = keine)
    denkstufe_ablage.py --schreiben "<text>" --json <datei>    Antwort speichern
    denkstufe_ablage.py --selbsttest             7 Abschnitte, rc 1 bei rot

⛔ WARUM DIE GATES IM WERKZEUG SITZEN UND NICHT IM SKILL.md
   Der Auftrag verlangt: jede Aussage traegt BELEGT (mit Quelle) oder HERGELEITET, und
   jede Kennzahl nennt Quelle und Datum. Stand das nur als Prosa im Skilltext, waere es
   eine Bitte — und dieses Projekt hat gemessen, dass Prosa-Vorschriften ohne Pruefer
   durchrutschen (die vier Memory-Gates aus `mind-memory` standen als Tabelle da und
   hatten NULL Pruefsammlungen). Deshalb WEIGERT sich dieses Werkzeug zu schreiben,
   wenn ein Feld fehlt: `kontext-anlegen.md` — was durchgesetzt werden muss, gehoert in
   einen Pruefer, nicht in eine Regeldatei.

⛔ AUSGABE IST ASCII-ONLY, mit Absicht.
   stdout ist hier cp1252 (`shell-windows.md`); ein einziges Sonderzeichen in einem
   `print` beendet den Lauf mit UnicodeEncodeError. Das ist am 01.10.2026 in genau
   diesem Projekt passiert.
   ⛔ HIER STAND: 'die DATEN duerfen Unicode tragen, die MELDUNGEN nicht'. Das war
      FALSCH, und der eigene Prueffall hat es gefunden: `--lesen` DRUCKT die Daten,
      also sind sie Meldung. Ein einzelnes Paragraf-Zeichen in einer Quellenangabe
      ergab das Byte 0xa7 in der Ausgabe. Die Trennung Daten/Meldung gibt es nicht,
      wo die Daten ausgegeben werden - deshalb ist ALLES hier ASCII.

⚠ BENANNTE LUECKE: die Ablage liegt unter `~/.claude/` und damit AUSSERHALB des
  Sicherungs-Hooks (der wacht ueber Projekt, `rules`, `CLAUDE.md`, `settings.json`).
  Die Kennzahlen sind ein Zwischenspeicher und jederzeit neu holbar; die gespeicherten
  Antworten je Aufgabe sind es NICHT, die haben Agenten gekostet (gemessen 01.10.2026:
  ein leerer Agentenlauf = 99 635 Tokens). Deshalb legt JEDES Schreiben zusaetzlich eine
  Kopie nach `_claude_backups/<ts>_denkstufe/` (Antons Auflage 02.10.2026, drei Zeilen).
"""
import argparse
import io
import json
import os
import re
import sys
import time

STUFEN = ("low", "medium", "high", "xhigh", "max")
ARTEN = ("BELEGT", "HERGELEITET")
VORGABE_TAGE = 14
SICHERUNG_VORGABE = u"C:/CD/KOHLEKTIV/_claude_backups"


def sicherung_dir():
    u"""Wohin die Mitsicherung geht.

    ⛔ Umschaltbar, und das ist kein Komfort: der erste Selbsttest hat eine ECHTE
       Sicherungsmappe unter C:/CD/KOHLEKTIV/_claude_backups/ angelegt. Ein Test, der
       in die echten Daten schreibt, ist ein Leck - genau die Sorte, die ich in
       fremdem Code melde. Jetzt zeigt MIND_DENKSTUFE_SICHERUNG im Test auf eine
       Wegwerfmappe, und die Zusicherung kann die Kopie trotzdem pruefen.
    """
    d = os.environ.get("MIND_DENKSTUFE_SICHERUNG", "").strip()
    return d if d else SICHERUNG_VORGABE


def ablage_dir():
    d = os.environ.get("MIND_DENKSTUFE_DIR", "").strip()
    if not d:
        d = os.path.join(os.path.expanduser("~"), ".claude", "mind-denkstufe")
    return d


def stale_tage():
    v = os.environ.get("MIND_DENKSTUFE_STALE_DAYS", "").strip()
    if not v:
        return VORGABE_TAGE
    try:
        n = int(v)
    except ValueError:
        return VORGABE_TAGE
    return n if n > 0 else VORGABE_TAGE


def slug(text):
    u"""Aufgabenname -> Dateiname. Stabil, damit der zweite Aufruf dieselbe Datei trifft."""
    s = (text or u"").strip().lower()
    s = re.sub(r"[^a-z0-9]+", u"-", s).strip(u"-")
    return (s or u"ohne-namen")[:80]


def _lesen_json(p):
    if not os.path.exists(p):
        return None
    try:
        return json.loads(io.open(p, encoding="utf-8").read())
    except ValueError:
        return None


def _schreiben_json(p, obj):
    d = os.path.dirname(p)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    # ensure_ascii=True: die Datei bleibt reines ASCII, damit kein Leser an einer
    # Kodierung scheitert. Die Zeichen bleiben als \uXXXX erhalten, nichts geht verloren.
    io.open(p, "w", encoding="utf-8", newline="\n").write(
        json.dumps(obj, ensure_ascii=True, indent=2, sort_keys=True) + u"\n")


def _mitsichern(p):
    u"""Kopie nach _claude_backups. Faellt still aus, wenn der Ort fehlt - eine fehlende
    Sicherung darf das Schreiben nicht verhindern, sonst verliert man BEIDES."""
    try:
        basis = sicherung_dir()
        if not os.path.isdir(basis):
            return None
        ziel = os.path.join(basis,
                            time.strftime("%Y%m%d_%H%M%S") + "_denkstufe")
        if not os.path.isdir(ziel):
            os.makedirs(ziel)
        z = os.path.join(ziel, os.path.basename(p))
        io.open(z, "w", encoding="utf-8", newline="\n").write(
            io.open(p, encoding="utf-8").read())
        return z
    except (OSError, IOError):
        return None


# ----------------------------------------------------------------- die Gates
def kennzahl_fehler(k):
    u"""Was fehlt dieser Kennzahl? Leere Liste = in Ordnung."""
    f = []
    if not isinstance(k, dict):
        return ["keine Zuordnung"]
    for feld in ("id", "wert", "quelle", "datum"):
        if not str(k.get(feld, "")).strip():
            f.append("Feld '%s' fehlt oder ist leer" % feld)
    if "vorbehalt" not in k:
        f.append("Feld 'vorbehalt' fehlt (leer ist erlaubt, fehlend nicht)")
    return f


def aussage_fehler(a):
    u"""BELEGT ohne Quelle ist der Fehler, gegen den dieses Werkzeug gebaut ist."""
    f = []
    if not isinstance(a, dict):
        return ["keine Zuordnung"]
    if not str(a.get("text", "")).strip():
        f.append("Feld 'text' fehlt oder ist leer")
    art = str(a.get("art", "")).strip()
    if art not in ARTEN:
        f.append("Feld 'art' muss %s sein, ist '%s'" % (" oder ".join(ARTEN), art))
    elif art == "BELEGT" and not str(a.get("quelle", "")).strip():
        f.append("BELEGT ohne 'quelle' - genau das ist verboten")
    return f


# ------------------------------------------------------------- der Startbestand
def startbestand():
    u"""Am 02.10.2026 an der Quelle nachgelesen, nicht aus zweiter Hand uebernommen.

    Jede Zeile traegt Quelle, Datum und - wo einer besteht - den Vorbehalt. Zwei
    Eintraege sind KORREKTUREN an dem, was uns ueberliefert wurde; sie stehen
    ausdruecklich als solche da, damit der alte Stand nicht zurueckkommt.
    """
    Q_EFFORT = u"https://platform.claude.com/docs/en/build-with-claude/effort"
    HEUTE = u"2026-10-02"
    return {
        u"stand": HEUTE,
        u"geholt_am": HEUTE,
        u"kennzahlen": [
            {u"id": u"vorgabe-opus-5-5", u"wert": u"medium", u"quelle": Q_EFFORT,
             u"datum": HEUTE, u"vorbehalt": u"",
             u"text": u"Claude Opus 5.5 laeuft ohne Angabe auf medium."},
            {u"id": u"vorgabe-sonnet-5-5", u"wert": u"high", u"quelle": Q_EFFORT,
             u"datum": HEUTE,
             u"vorbehalt": u"KORREKTUR: der ueberlieferte Startbestand sagte fuer "
                           u"Sonnet 5.5 ebenfalls medium. Die Quelle sagt high.",
             u"text": u"Claude Sonnet 5.5 laeuft ohne Angabe auf high."},
            {u"id": u"vorgabe-allgemein", u"wert": u"high", u"quelle": Q_EFFORT,
             u"datum": HEUTE, u"vorbehalt": u"",
             u"text": u"Alle uebrigen Modelle mit Stufen laufen ohne Angabe auf high."},
            {u"id": u"index-opus-5-5", u"wert": u"low 42 / medium 51 / high 54 / "
                                               u"xhigh 56 / max 58",
             u"quelle": u"https://artificialanalysis.ai/models/claude-opus-5-5",
             u"datum": u"2026-10-01",
             u"vorbehalt": u"Fremd ermittelt (Pc Forschung), von uns nicht nachgemessen. "
                           u"UND: eine Pruefung meldet, dass nur eine von fuenf dieser "
                           u"Punktzahlen einen Modellwechsel im Hintergrund ausschliesst "
                           u"(superpowerdaily.com, review-finds-only-one-of-five). Die "
                           u"Zahlen stehen unter 'with fallback'.",
             u"text": u"Intelligence Index je Stufe, Opus 5.5."},
            {u"id": u"kosten-opus-5-5", u"wert": u"0,55 / 1,34 / 1,82 / 3,46 / 5,98 USD "
                                                u"je Aufgabe (low..max)",
             u"quelle": u"https://www.digitalapplied.com/blog/"
                        u"sonnet-5-5-or-opus-5-5-effort-level-cost-per-task",
             u"datum": u"2026-10-01",
             u"vorbehalt": u"Fremd ermittelt, Drittquelle, von uns nicht nachgemessen.",
             u"text": u"Kosten je Aufgabe nach Stufe, Opus 5.5."},
            {u"id": u"leerer-agent-tokens", u"wert": u"99635",
             u"quelle": u"eigene Messung, Etappe 52, Teil 0a",
             u"datum": u"2026-10-01", u"vorbehalt": u"",
             u"text": u"Ein Agentenlauf mit Minimalauftrag (eine Datei lesen, Zeilen "
                      u"zaehlen, 2 Werkzeugaufrufe, 6,3 s) kostete 99 635 Tokens. Das ist "
                      u"der Grund, warum die Gegenprobe nur beim Erstaufruf laeuft."},
        ],
        u"aussagen": [
            {u"text": u"Effort ist ein Verhaltenssignal, kein festes Token-Budget. Bei "
                      u"niedriger Stufe denkt das Modell bei schwierigen Problemen "
                      u"trotzdem, nur kuerzer.",
             u"art": u"BELEGT", u"quelle": Q_EFFORT, u"datum": HEUTE},
            {u"text": u"Die Stufe wirkt auf ALLE Ausgabetoken, auch auf Werkzeugaufrufe: "
                      u"niedrig heisst weniger und knappere Aufrufe, hoch heisst mehr "
                      u"Aufrufe und Plan-vor-Tat. Fuer eine Pruefaufgabe, die aus vielen "
                      u"Lesezugriffen besteht, ist das der tragende Punkt.",
             u"art": u"BELEGT", u"quelle": Q_EFFORT, u"datum": HEUTE},
            {u"text": u"Die Doku nennt Subagenten ausdruecklich als Einsatzfall fuer low "
                      u"('Simpler tasks that need the best speed and lowest costs, such "
                      u"as subagents'). GEGENSTIMME zu unserem effort: high an den zwei "
                      u"Pruefagenten - nicht unterschlagen, sondern danebengestellt.",
             u"art": u"BELEGT", u"quelle": Q_EFFORT, u"datum": HEUTE},
            {u"text": u"Unsere zwei Pruefagenten sind keine 'simpler tasks': sie lesen "
                      u"Kontextdateien und urteilen ueber Widersprueche. Genau dort meldet "
                      u"ein zu schwacher Pruefer gruen. Deshalb bleibt high, bis eine "
                      u"Messung AN DIESEN AGENTEN etwas anderes zeigt.",
             u"art": u"HERGELEITET", u"quelle": u"", u"datum": HEUTE},
            {u"text": u"xhigh ist fuer Laeufe ueber 30 Minuten mit Token-Budgets in "
                      u"Millionen gedacht; max kann bei strukturierter Ausgabe zu "
                      u"Ueberdenken fuehren.",
             u"art": u"BELEGT", u"quelle": Q_EFFORT, u"datum": HEUTE},
            {u"text": u"Die Doku verlangt mehrfach woertlich einen eigenen Stufen-Durchlauf "
                      u"statt uebernommener Einstellungen ('Run a fresh effort sweep on "
                      u"your own evals rather than carrying settings over'). Das ist die "
                      u"Begruendung fuer --messen.",
             u"art": u"BELEGT", u"quelle": Q_EFFORT, u"datum": HEUTE},
            {u"text": u"Subagenten erben die Stufe der startenden Sitzung, solange ihr "
                      u"Frontmatter kein effort: traegt. An einem echten Lauf belegt, nicht "
                      u"aus der Doku: ein Agent ohne Feld lief auf effort=high wie seine "
                      u"Sitzung. Siehe docs/plugin/denkstufe-messung.md.",
             u"art": u"BELEGT", u"quelle": u"eigene Messung, Etappe 52, Teil 0a",
             u"datum": u"2026-10-01"},
            {u"text": u"effort: im Frontmatter ist ein FESTER Wert, kein Mindestwert - es "
                      u"hebt eine niedrige Sitzung und senkt eine hohe.",
             u"art": u"BELEGT", u"quelle": u"eigene Messung, Etappe 52, Teil 0a",
             u"datum": u"2026-10-01"},
        ],
    }


# --------------------------------------------------------------------- Befehle
def tu_anlegen(neu):
    p = os.path.join(ablage_dir(), "messwerte.json")
    if os.path.exists(p) and not neu:
        print("vorhanden, nichts getan: %s" % p)
        print("  (--neu ueberschreibt)")
        return 0
    daten = startbestand()
    fehler = []
    for k in daten["kennzahlen"]:
        for f in kennzahl_fehler(k):
            fehler.append("Kennzahl %r: %s" % (k.get("id"), f))
    for a in daten["aussagen"]:
        for f in aussage_fehler(a):
            fehler.append("Aussage %r...: %s" % (str(a.get("text"))[:40], f))
    if fehler:
        sys.stderr.write("ABBRUCH, eigener Startbestand haelt die Gates nicht:\n")
        for f in fehler:
            sys.stderr.write("  " + f + "\n")
        return 2
    _schreiben_json(p, daten)
    print("angelegt: %s" % p)
    print("  %d Kennzahlen, %d Aussagen, alle mit Quelle und Datum"
          % (len(daten["kennzahlen"]), len(daten["aussagen"])))
    return 0


def tu_lesen():
    p = os.path.join(ablage_dir(), "messwerte.json")
    d = _lesen_json(p)
    if d is None:
        sys.stderr.write("keine Ablage unter %s - erst --anlegen\n" % p)
        return 2
    print("Ablage: %s" % p)
    print("Stand:  %s" % d.get("stand", "unbekannt"))
    print("")
    for k in d.get("kennzahlen", []):
        print("[%s] %s" % (k.get("id"), k.get("wert")))
        print("    %s" % k.get("text", ""))
        print("    Quelle: %s  (%s)" % (k.get("quelle"), k.get("datum")))
        if str(k.get("vorbehalt", "")).strip():
            print("    VORBEHALT: %s" % k.get("vorbehalt"))
    print("")
    for a in d.get("aussagen", []):
        print("%-12s %s" % (a.get("art"), a.get("text")))
        if str(a.get("quelle", "")).strip():
            print("             Quelle: %s  (%s)" % (a.get("quelle"), a.get("datum")))
    return 0


def tu_alter():
    p = os.path.join(ablage_dir(), "messwerte.json")
    d = _lesen_json(p)
    if d is None:
        print("keine Ablage - gilt als abgelaufen")
        return 1
    stand = str(d.get("geholt_am", "")).strip()
    try:
        t = time.mktime(time.strptime(stand, "%Y-%m-%d"))
    except ValueError:
        print("Datum '%s' nicht lesbar - gilt als abgelaufen" % stand)
        return 1
    tage = int((time.time() - t) // 86400)
    grenze = stale_tage()
    print("geholt am %s, Alter %d Tage, Grenze %d Tage" % (stand, tage, grenze))
    if tage > grenze:
        print("ABGELAUFEN - eine Websuche ist erlaubt")
        return 1
    print("frisch - KEINE Websuche")
    return 0


def tu_aufgabe(text):
    p = os.path.join(ablage_dir(), "aufgaben", slug(text) + ".json")
    d = _lesen_json(p)
    if d is None:
        print("keine gespeicherte Antwort fuer %r" % slug(text))
        return 1
    print("gespeichert am %s (Gegenprobe gelaufen: %s)"
          % (d.get("erstellt"), d.get("gegenprobe_gelaufen")))
    print("Empfehlung: Modell %s, Stufe %s"
          % (d.get("empfehlung", {}).get("modell"),
             d.get("empfehlung", {}).get("stufe")))
    for a in d.get("aussagen", []):
        print("  %-12s %s" % (a.get("art"), a.get("text")))
    return 0


def tu_schreiben(text, jsonpfad):
    neu = _lesen_json(jsonpfad)
    if neu is None:
        sys.stderr.write("Antwortdatei fehlt oder ist kein JSON: %s\n" % jsonpfad)
        return 2
    emp = neu.get("empfehlung")
    if not isinstance(emp, dict) or str(emp.get("stufe", "")).strip() not in STUFEN:
        sys.stderr.write("ABBRUCH: 'empfehlung.stufe' muss eine von %s sein\n"
                         % ", ".join(STUFEN))
        return 2
    aussagen = neu.get("aussagen")
    if not isinstance(aussagen, list) or not aussagen:
        sys.stderr.write("ABBRUCH: 'aussagen' fehlt oder ist leer - eine Empfehlung "
                         "ohne Begruendung wird nicht gespeichert\n")
        return 2
    fehler = []
    for a in aussagen:
        for f in aussage_fehler(a):
            fehler.append("Aussage %r...: %s" % (str(a.get("text"))[:40], f))
    if fehler:
        sys.stderr.write("ABBRUCH, Gates nicht gehalten:\n")
        for f in fehler:
            sys.stderr.write("  " + f + "\n")
        return 2
    neu["aufgabe"] = text
    neu["slug"] = slug(text)
    neu.setdefault("erstellt", time.strftime("%Y-%m-%d %H:%M"))
    neu.setdefault("gegenprobe_gelaufen", False)
    p = os.path.join(ablage_dir(), "aufgaben", slug(text) + ".json")
    _schreiben_json(p, neu)
    print("gespeichert: %s" % p)
    kopie = _mitsichern(p)
    print("mitgesichert: %s" % (kopie if kopie else "NICHT (Sicherungsort fehlt)"))
    return 0


# ------------------------------------------------------------------ Selbsttest
def tu_selbsttest():
    import shutil
    import tempfile
    ok = [0]
    rot = [0]

    def pruef(name, ist, soll):
        if ist == soll:
            print("  [ok ] %s" % name)
            ok[0] += 1
        else:
            print("  [ROT] %s - erwartet %r, bekommen %r" % (name, soll, ist))
            rot[0] += 1

    t = tempfile.mkdtemp()
    alt = os.environ.get("MIND_DENKSTUFE_DIR")
    alt_sich = os.environ.get("MIND_DENKSTUFE_SICHERUNG")
    os.environ["MIND_DENKSTUFE_DIR"] = t
    # Kein Schreiben in die ECHTE Sicherungsmappe - siehe sicherung_dir().
    os.environ["MIND_DENKSTUFE_SICHERUNG"] = os.path.join(t, "sicherung")
    os.makedirs(os.path.join(t, "sicherung"))
    try:
        print("1/7  die Gates lehnen ab, was sie ablehnen muessen")
        pruef("BELEGT ohne Quelle wird abgelehnt",
              bool(aussage_fehler({"text": "x", "art": "BELEGT"})), True)
        pruef("BELEGT MIT Quelle geht durch",
              aussage_fehler({"text": "x", "art": "BELEGT", "quelle": "u"}), [])
        pruef("HERGELEITET ohne Quelle geht durch",
              aussage_fehler({"text": "x", "art": "HERGELEITET"}), [])
        pruef("erfundene Art wird abgelehnt",
              bool(aussage_fehler({"text": "x", "art": "GEFUEHLT"})), True)
        pruef("leerer Text wird abgelehnt",
              bool(aussage_fehler({"text": "  ", "art": "HERGELEITET"})), True)

        print("2/7  Kennzahl ohne Quelle oder Datum wird abgelehnt")
        pruef("ohne Quelle", bool(kennzahl_fehler(
            {"id": "a", "wert": "1", "datum": "2026-10-02", "vorbehalt": ""})), True)
        pruef("ohne Datum", bool(kennzahl_fehler(
            {"id": "a", "wert": "1", "quelle": "u", "vorbehalt": ""})), True)
        pruef("FEHLENDES vorbehalt-Feld wird abgelehnt", bool(kennzahl_fehler(
            {"id": "a", "wert": "1", "quelle": "u", "datum": "2026-10-02"})), True)
        pruef("leeres vorbehalt-Feld ist erlaubt", kennzahl_fehler(
            {"id": "a", "wert": "1", "quelle": "u", "datum": "2026-10-02",
             "vorbehalt": ""}), [])

        print("3/7  der eigene Startbestand haelt seine eigenen Gates")
        pruef("--anlegen rc 0", tu_anlegen(False), 0)
        d = _lesen_json(os.path.join(t, "messwerte.json"))
        pruef("Datei da", d is not None, True)
        # VAKUUM-WAECHTER: erst die Existenz, dann der Inhalt. Ohne das urteilen die
        # vier Zeilen darunter ueber ein None und reissen den Lauf mit einem Traceback
        # ab, statt rot zu melden.
        kz = d.get("kennzahlen", []) if d else []
        au = d.get("aussagen", []) if d else []
        pruef("jede Kennzahl vollstaendig",
              sum(len(kennzahl_fehler(k)) for k in kz), 0)
        pruef("jede Aussage vollstaendig",
              sum(len(aussage_fehler(a)) for a in au), 0)
        pruef("die Gegenstimme ist drin (nicht weggelassen)",
              any("such as subagents" in a.get("text", "") for a in au), True)
        pruef("die Korrektur an Sonnet 5.5 ist drin",
              any("KORREKTUR" in str(k.get("vorbehalt", "")) for k in kz), True)

        print("4/7  --anlegen ueberschreibt nicht ohne --neu")
        _schreiben_json(os.path.join(t, "messwerte.json"), {"stand": "MARKE"})
        tu_anlegen(False)
        d2 = _lesen_json(os.path.join(t, "messwerte.json")) or {}
        pruef("Marke steht noch da", d2.get("stand"), "MARKE")
        pruef("--neu ersetzt", tu_anlegen(True), 0)
        d3 = _lesen_json(os.path.join(t, "messwerte.json")) or {}
        pruef("Marke weg", d3.get("stand") != "MARKE", True)

        print("5/7  Alter und Ablauf")
        os.environ["MIND_DENKSTUFE_STALE_DAYS"] = "14"
        pruef("frisch -> rc 0", tu_alter(), 0)
        d = _lesen_json(os.path.join(t, "messwerte.json")) or {}
        d["geholt_am"] = "2020-01-01"
        _schreiben_json(os.path.join(t, "messwerte.json"), d)
        pruef("alt -> rc 1", tu_alter(), 1)
        d["geholt_am"] = "kein Datum"
        _schreiben_json(os.path.join(t, "messwerte.json"), d)
        pruef("unlesbares Datum -> rc 1, nicht rc 0", tu_alter(), 1)

        print("6/7  Antwort speichern und wiederfinden")
        aw = os.path.join(t, "antwort.json")
        _schreiben_json(aw, {
            "empfehlung": {"modell": "opus", "stufe": "high"},
            "aussagen": [{"text": "weil", "art": "HERGELEITET"}]})
        pruef("speichern rc 0", tu_schreiben(u"/mind-all pruefen", aw), 0)
        pruef("wiederfinden rc 0", tu_aufgabe(u"/mind-all pruefen"), 0)
        pruef("anderer Wortlaut, gleicher Slug -> gefunden",
              tu_aufgabe(u"  /MIND-ALL   PRUEFEN  "), 0)
        pruef("unbekannte Aufgabe -> rc 1", tu_aufgabe(u"gibt es nicht"), 1)
        # Die Mitsicherung wird GEMESSEN. Ohne diese Zeile waere Antons Auflage
        # eingebaut und unbelegt - und ein stiller Rueckfall faellt nie auf.
        kopien = []
        for wurzel, _, dateien in os.walk(os.path.join(t, "sicherung")):
            for f in dateien:
                kopien.append(os.path.join(wurzel, f))
        pruef("Mitsicherung hat genau eine Kopie angelegt", len(kopien), 1)
        pruef("   ... und sie heisst wie die Antwort",
              os.path.basename(kopien[0]) if kopien else "", "mind-all-pruefen.json")

        print("7/7  eine Empfehlung ohne Begruendung wird NICHT gespeichert")
        _schreiben_json(aw, {"empfehlung": {"modell": "opus", "stufe": "high"},
                             "aussagen": []})
        pruef("leere aussagen -> rc 2", tu_schreiben(u"leer", aw), 2)
        _schreiben_json(aw, {"empfehlung": {"modell": "opus", "stufe": "hoch"},
                             "aussagen": [{"text": "x", "art": "HERGELEITET"}]})
        pruef("erfundene Stufe -> rc 2", tu_schreiben(u"falschestufe", aw), 2)
        _schreiben_json(aw, {"empfehlung": {"modell": "opus", "stufe": "high"},
                             "aussagen": [{"text": "x", "art": "BELEGT"}]})
        pruef("BELEGT ohne Quelle -> rc 2", tu_schreiben(u"ohnequelle", aw), 2)
        pruef("nichts davon wurde angelegt",
              os.path.exists(os.path.join(t, "aufgaben", "leer.json")), False)
    finally:
        if alt is None:
            os.environ.pop("MIND_DENKSTUFE_DIR", None)
        else:
            os.environ["MIND_DENKSTUFE_DIR"] = alt
        if alt_sich is None:
            os.environ.pop("MIND_DENKSTUFE_SICHERUNG", None)
        else:
            os.environ["MIND_DENKSTUFE_SICHERUNG"] = alt_sich
        shutil.rmtree(t, ignore_errors=True)

    print("")
    print("  %d gruen - %d rot" % (ok[0], rot[0]))
    return 1 if rot[0] else 0


def main():
    p = argparse.ArgumentParser(add_help=True)
    p.add_argument("--anlegen", action="store_true")
    p.add_argument("--neu", action="store_true")
    p.add_argument("--lesen", action="store_true")
    p.add_argument("--alter", action="store_true")
    p.add_argument("--aufgabe")
    p.add_argument("--schreiben")
    p.add_argument("--json")
    p.add_argument("--selbsttest", action="store_true")
    a = p.parse_args()

    if a.selbsttest:
        return tu_selbsttest()
    if a.anlegen:
        return tu_anlegen(a.neu)
    if a.lesen:
        return tu_lesen()
    if a.alter:
        return tu_alter()
    if a.schreiben:
        if not a.json:
            sys.stderr.write("--schreiben braucht --json <datei>\n")
            return 2
        return tu_schreiben(a.schreiben, a.json)
    if a.aufgabe:
        return tu_aufgabe(a.aufgabe)
    p.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
