#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""cleaner_paths_sonde.py — misst, ob `paths:` in .claude/rules/ wirklich filtert.

⛔ v5.108.0 (Etappe 16 §4). `kontext-anlegen.md` sagt seit Wochen: "dass `paths:` filtert,
   ist dokumentiert, nicht nachgemessen." Zustellplan (14.09.2026): 14 Rules, 865 kB, alle
   `globs:`, alle laden beim Start; 2 766 Ladevorgaenge im Protokoll, nie `path_glob_match`.
   Diese Sonde macht die Messung — in ZWEI Schritten, weil nur der Mensch eine neue Sitzung
   starten kann:

   1. --start <projekt> [--datei <rule.md>]
      waehlt die kleinste Rule mit Datei-Bezug (cleaner_einordnung: dateibezug > 0), sichert
      sie nach $MIND_SONDE_SICHERUNG (Vorgabe C:/CD/KOHLEKTIV/_claude_backups/<ts>_paths-sonde/),
      tauscht `globs:` -> `paths:` (nur im Frontmatter), schreibt den Merker
      <projekt>/.claude-mind/paths-sonde (datei=, ts=, sid=, sicherung=) und sagt:
      "neue Sitzung starten, dann /mind-cleaner erneut".
   2. --auswerten <projekt>
      liest das Ladeprotokoll (ladeprotokoll_auswertung.finde_log) SEIT dem Merker aus einer
      ANDEREN Sitzung: Rule geladen mit Grund session_start -> `paths:` filtert NICHT;
      geladen mit path_glob_match -> filtert (Grund belegt); Protokoll traegt neue Sitzung,
      Rule fehlt -> filtert; keine neue Sitzung -> noch nicht messbar. Ergebnis nach
      $MIND_DEBUG_DIR/paths-sonde-<ts>.md und als Satz fuer kontext-anlegen.md.

⛔ Schritt 1 AENDERT eine Datei. Er laeuft nur nach dem OK des Cleaners, wie jeder Umzug.
   Rueckweg: die Sicherung (der Merker nennt sie). Die Sonde stellt NICHT selbst zurueck.
"""
import io
import os
import re
import sys
import time

_HIER = os.path.dirname(os.path.abspath(__file__))
if _HIER not in sys.path:
    sys.path.insert(0, _HIER)
import cleaner_einordnung as ein            # noqa: E402
import ladeprotokoll_auswertung as lp       # noqa: E402

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


def _merker(projekt):
    return os.path.join(projekt, ".claude-mind", "paths-sonde")


def _lies_merker(projekt):
    p = _merker(projekt)
    if not os.path.isfile(p):
        return None
    d = {}
    for z in open(p, encoding="utf-8", errors="replace").read().splitlines():
        if "=" in z:
            k, v = z.split("=", 1)
            d[k.strip()] = v.strip()
    return d


def kandidat(projekt, datei=None):
    """Die kleinste Rule mit Datei-Bezug — oder die genannte."""
    rd = os.path.join(projekt, ".claude", "rules")
    if datei:
        p = datei if os.path.isabs(datei) else os.path.join(rd, datei)
        return p if os.path.isfile(p) else None
    beste = None
    for f in sorted(os.listdir(rd)) if os.path.isdir(rd) else []:
        if not f.endswith(".md") or f == "rollen.md":
            continue
        p = os.path.join(rd, f)
        e = ein.einordnen(p)
        if not e or e.get("dateibezug", 0) <= 0:
            continue
        if beste is None or e["bytes"] < beste[0]:
            beste = (e["bytes"], p)
    return beste[1] if beste else None


def globs_zu_paths(text):
    """Nur im Frontmatter (bis zum zweiten ---)."""
    if not text.startswith("---"):
        return text, False
    teile = text.split("---", 2)
    if len(teile) < 3:
        return text, False
    kopf, rest = teile[1], teile[2]
    neu = re.sub(r"^(\s*)globs:", r"\1paths:", kopf, flags=re.M)
    return "---" + neu + "---" + rest, neu != kopf


def start(projekt, datei=None, sicherung_wurzel=None):
    p = kandidat(projekt, datei)
    if not p:
        print("⛔ keine Rule mit Datei-Bezug unter .claude/rules/ — nichts zu messen")
        return 2
    ts = time.strftime("%Y%m%d_%H%M%S")
    sw = sicherung_wurzel or os.environ.get("MIND_SONDE_SICHERUNG") \
        or "C:/CD/KOHLEKTIV/_claude_backups"
    sdir = os.path.join(sw, ts + "_paths-sonde")
    os.makedirs(sdir, exist_ok=True)
    roh = open(p, "rb").read()
    open(os.path.join(sdir, os.path.basename(p)), "wb").write(roh)
    text = roh.decode("utf-8", "replace")
    neu, getauscht = globs_zu_paths(text)
    if getauscht:
        open(p, "wb").write(neu.encode("utf-8"))
    elif not re.search(r"^\s*paths:", text.split("---", 2)[1] if text.startswith("---") else "", re.M):
        print("⛔ %s traegt weder globs: noch paths: — als Sonde untauglich" % os.path.basename(p))
        return 2
    os.makedirs(os.path.dirname(_merker(projekt)), exist_ok=True)
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID", "") or "unbekannt"
    with open(_merker(projekt), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("datei=%s\nts=%s\nsid=%s\nsicherung=%s\ngetauscht=%s\n"
                 % (p, time.strftime("%Y-%m-%d %H:%M:%S"), sid,
                    os.path.join(sdir, os.path.basename(p)), "ja" if getauscht else "nein"))
    print("=" * 72)
    print("PATHS-SONDE gesetzt")
    print("=" * 72)
    print("  Rule:       %s" % p)
    print("  Sicherung:  %s" % os.path.join(sdir, os.path.basename(p)))
    print("  globs->paths: %s" % ("getauscht" if getauscht else "war schon paths:"))
    print("  Merker:     %s" % _merker(projekt))
    print()
    print("  ⛔ Jetzt eine NEUE Sitzung starten (kann nur der Mensch), dort NICHT die")
    print("     Datei anfassen, die die Rule nennt — dann `/mind-cleaner --paths-sonde`")
    print("     (cleaner_paths_sonde.py --auswerten) erneut. Rueckweg: die Sicherung.")
    return 0


def auswerten(projekt, log=None):
    m = _lies_merker(projekt)
    if not m:
        print("⛔ kein Merker paths-sonde — zuerst --start")
        return 2
    log = log or lp.finde_log()
    if not os.path.isfile(log):
        print("⛔ kein Ladeprotokoll: %s" % log)
        return 2
    base = os.path.basename(m["datei"])
    seit, sid = m.get("ts", ""), m.get("sid", "")
    neue_sitzungen, treffer = set(), []
    for z in open(log, encoding="utf-8", errors="replace"):
        t = z.rstrip("\n").split("\t")
        if len(t) < 3 or t[0] <= seit:
            continue
        s = t[3] if len(t) > 3 else ""
        if sid and s and sid.startswith(s):
            continue                      # dieselbe Sitzung zaehlt nicht
        neue_sitzungen.add(s or "?")
        if t[2].replace("\\", "/").endswith("/" + base):
            treffer.append((t[0], t[1], s))
    print("=" * 72)
    print("PATHS-SONDE auswerten — %s" % base)
    print("=" * 72)
    print("  Merker seit %s (Sitzung %s), Protokoll %s" % (seit, sid[:8], log))
    print("  neue Sitzungen seit dem Merker: %d, Ladungen der Rule: %d" % (len(neue_sitzungen), len(treffer)))
    if not neue_sitzungen:
        urteil, satz = "NOCH NICHT MESSBAR", "keine neue Sitzung im Protokoll seit dem Merker"
        rc = 3
    else:
        gruende = set(g for _, g, _ in treffer)
        if not treffer:
            urteil = "paths: FILTERT"
            satz = ("`paths:` filtert: die Rule `%s` wurde in %d neuen Sitzung(en) NICHT geladen "
                    "(gemessen %s)" % (base, len(neue_sitzungen), time.strftime("%d.%m.%Y")))
            rc = 0
        elif gruende == {"path_glob_match"}:
            urteil = "paths: FILTERT (Grund path_glob_match)"
            satz = ("`paths:` filtert: die Rule `%s` lud nur mit Grund `path_glob_match` "
                    "(gemessen %s)" % (base, time.strftime("%d.%m.%Y")))
            rc = 0
        else:
            urteil = "paths: FILTERT NICHT"
            satz = ("`paths:` filtert NICHT: die Rule `%s` lud in einer neuen Sitzung mit Grund %s "
                    "(gemessen %s)" % (base, ", ".join(sorted(gruende)), time.strftime("%d.%m.%Y")))
            rc = 1
    print("  URTEIL: %s" % urteil)
    print("  Satz fuer kontext-anlegen.md: %s" % satz)
    print("  Rueckweg: cp \"%s\" \"%s\"" % (m.get("sicherung", "?"), m["datei"]))
    d = os.environ.get("MIND_DEBUG_DIR")
    if d and os.path.isdir(d):
        out = os.path.join(d, "paths-sonde-%s.md" % time.strftime("%Y%m%d-%H%M%S"))
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("# paths-Sonde %s\n\n- Rule: `%s`\n- Merker seit: %s\n- neue Sitzungen: %d\n"
                     "- Ladungen: %s\n- URTEIL: %s\n- Satz: %s\n"
                     % (time.strftime("%Y-%m-%d %H:%M"), m["datei"], seit, len(neue_sitzungen),
                        "; ".join("%s %s %s" % t for t in treffer) or "keine", urteil, satz))
        print("  Ergebnis: %s" % out)
    return rc


def selbsttest():
    import tempfile
    fehler = 0

    def pruef(name, ist, soll):
        nonlocal fehler
        ok = ist == soll
        fehler += 0 if ok else 1
        print("  %-4s %-52s ist=%s soll=%s" % ("OK" if ok else "FEHL", name, ist, soll))

    d = tempfile.mkdtemp()
    os.environ.pop("MIND_DEBUG_DIR", None)   # der Selbsttest schreibt NIE in den echten Debug-Ordner
    proj = os.path.join(d, "proj"); rd = os.path.join(proj, ".claude", "rules"); os.makedirs(rd)
    open(os.path.join(rd, "gross.md"), "w", encoding="utf-8").write(
        "---\ndescription: x\nglobs: [\"src/**/*.py\"]\n---\n# G\n\n" + ("⛔ NIE `a.py` aendern.\n\n" * 20))
    open(os.path.join(rd, "klein.md"), "w", encoding="utf-8").write(
        "---\ndescription: y\nglobs: [\"tools/b.py\"]\n---\n# K\n\n⛔ NIE `b.py` ohne Test.\n")
    open(os.path.join(rd, "prosa.md"), "w", encoding="utf-8").write(
        "---\ndescription: z\n---\n# P\n\nNur Prosa ohne Datei.\n")
    print("=" * 72); print("  Selbsttest — die paths-Sonde"); print("=" * 72)
    pruef("Kandidat ist die kleinste Rule mit Datei-Bezug", os.path.basename(kandidat(proj) or ""), "klein.md")
    os.environ["CLAUDE_CODE_SESSION_ID"] = "aaaaaaaa-1111"
    rc = start(proj, None, os.path.join(d, "sich"))
    pruef("--start rc 0", rc, 0)
    m = _lies_merker(proj)
    pruef("Merker traegt datei/ts/sid/sicherung", sorted(k for k in (m or {}) if k in ("datei", "ts", "sid", "sicherung")),
          ["datei", "sicherung", "sid", "ts"])
    text = open(os.path.join(rd, "klein.md"), encoding="utf-8").read()
    pruef("globs: -> paths: nur im Frontmatter", ("paths:" in text.split("---")[1]) and ("globs:" not in text), True)
    pruef("Sicherung ist byte-gleich mit dem Stand davor",
          open(m["sicherung"], encoding="utf-8").read().startswith("---\ndescription: y\nglobs:"), True)
    # Ladeprotokoll: (a) keine neue Sitzung, (b) geladen beim Start, (c) neue Sitzung ohne die Rule
    log = os.path.join(d, "lade.log")
    spaeter = "2099-01-01 00:00:01"
    open(log, "w", encoding="utf-8").write("2000-01-01 00:00:00\tsession_start\t%s\tbbbbbbbb\n" % os.path.join(rd, "klein.md"))
    pruef("(a) nur alte Eintraege -> noch nicht messbar (3)", auswerten(proj, log), 3)
    open(log, "a", encoding="utf-8").write("%s\tsession_start\t%s\taaaaaaaa\n" % (spaeter, os.path.join(rd, "klein.md")))
    pruef("(a2) dieselbe Sitzung zaehlt nicht (3)", auswerten(proj, log), 3)
    open(log, "a", encoding="utf-8").write("%s\tsession_start\t%s\tcccccccc\n" % (spaeter, os.path.join(rd, "klein.md")))
    pruef("(b) neue Sitzung laedt die Rule beim Start -> filtert NICHT (1)", auswerten(proj, log), 1)
    open(log, "w", encoding="utf-8").write("%s\tsession_start\t%s\tdddddddd\n" % (spaeter, os.path.join(rd, "gross.md")))
    pruef("(c) neue Sitzung, Rule nicht dabei -> filtert (0)", auswerten(proj, log), 0)
    open(log, "w", encoding="utf-8").write("%s\tpath_glob_match\t%s\teeeeeeee\n" % (spaeter, os.path.join(rd, "klein.md")))
    pruef("(d) geladen mit path_glob_match -> filtert (0)", auswerten(proj, log), 0)
    pruef("Rule ohne globs/paths ist als Sonde untauglich (2)", start(proj, "prosa.md", os.path.join(d, "sich")), 2)
    print("\n=== %d Abweichung(en) ===" % fehler)
    return 3 if fehler else 0


def main(argv=None):
    a = list(sys.argv[1:] if argv is None else argv)
    if "--selbsttest" in a:
        return selbsttest()

    def hol(f):
        return a[a.index(f) + 1] if f in a and a.index(f) + 1 < len(a) else None
    if "--start" in a:
        return start(hol("--start"), hol("--datei"))
    if "--auswerten" in a:
        return auswerten(hol("--auswerten"), hol("--log"))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
