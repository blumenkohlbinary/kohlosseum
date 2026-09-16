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
   2. --auswerten <projekt> [--seit <YYYY-MM-DD HH:MM:SS>] [--datei <rule.md>] [--log <pfad>]
      liest das Ladeprotokoll (ladeprotokoll_auswertung.finde_log) SEIT dem Merker aus einer
      ANDEREN Sitzung: Rule geladen mit Grund session_start -> `paths:` filtert NICHT;
      geladen mit path_glob_match -> filtert (Grund belegt); Protokoll traegt neue Sitzung,
      Rule fehlt -> filtert; keine neue Sitzung -> noch nicht messbar. Ergebnis nach
      $MIND_DEBUG_DIR/paths-sonde-<ts>.md und als Satz fuer kontext-anlegen.md.
      ⛔ v5.115.0 (Etappe 23 §1): OHNE Merker geht es auch — der globs->paths-Tausch im
      Zustellplan lief von Hand (15.09., vor v5.108.0), und das Ergebnis lag trotzdem vor:
      13 paths-Rules fehlten beim Sitzungsstart, ein Read lud 3 nach (Sitzung Otto, 16.09.).
      Dann gilt `--seit` als Merkerzeit (fehlt es: der ganze Log) und `--datei` als Rule;
      ohne `--datei` werden ALLE Rules mit `paths:` im Frontmatter gemessen, je Rule ein
      Urteil und eines fuer den Bestand.

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


def andere_ergebnisse(projekt):
    """v5.112.0 (§5): das Messergebnis ist projektuebergreifendes Wissen — was liegt schon in
    $MIND_DEBUG_DIR/paths-sonde-*.md aus ANDEREN Projekten? Liste (projekt, urteil)."""
    d = os.environ.get("MIND_DEBUG_DIR")
    out = []
    if not d or not os.path.isdir(d):
        return out
    for f in sorted(os.listdir(d)):
        if not (f.startswith("paths-sonde-") and f.endswith(".md")):
            continue
        t = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
        mp = re.search(r"^- Projekt: (.+)$", t, re.M)
        mu = re.search(r"^- URTEIL: (.+)$", t, re.M)
        pj = mp.group(1).strip() if mp else "?"
        if pj.replace("\\", "/").rstrip("/") == os.path.abspath(projekt).replace("\\", "/").rstrip("/"):
            continue
        out.append((pj, mu.group(1).strip() if mu else "?"))
    return out


def _andere_melden(projekt):
    a = andere_ergebnisse(projekt)
    if a:
        print("  ⭐ Ergebnis(se) aus anderen Projekten: %d" % len(a))
        for pj, u in a[-3:]:
            print("     %-40s %s" % (os.path.basename(pj)[:40], u))
        print("     -> dieses Projekt bestaetigt oder widerlegt sie; der Satz fuer kontext-anlegen.md gilt erst mit zwei.")
    else:
        print("  ⚠ noch kein Ergebnis aus einem anderen Projekt — dies waere das erste.")


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
    _andere_melden(projekt)
    print("  ⛔ Jetzt eine NEUE Sitzung starten (kann nur der Mensch), dort NICHT die")
    print("     Datei anfassen, die die Rule nennt — dann `/mind-cleaner --paths-sonde`")
    print("     (cleaner_paths_sonde.py --auswerten) erneut. Rueckweg: die Sicherung.")
    return 0


def paths_rules(projekt):
    """Alle Rules unter .claude/rules/ mit `paths:` im Frontmatter (v5.115.0)."""
    rd = os.path.join(projekt, ".claude", "rules")
    out = []
    for f in sorted(os.listdir(rd)) if os.path.isdir(rd) else []:
        if not f.endswith(".md"):
            continue
        p = os.path.join(rd, f)
        t = open(p, encoding="utf-8", errors="replace").read()
        if t.startswith("---") and len(t.split("---", 2)) >= 3 \
                and re.search(r"^\s*paths:", t.split("---", 2)[1], re.M):
            out.append(p)
    return out


def _urteil(base, neue_sitzungen, treffer):
    gruende = set(g for _, g, _ in treffer)
    if not neue_sitzungen:
        return "NOCH NICHT MESSBAR", "keine neue Sitzung im Protokoll seit dem Merker", 3
    if not treffer:
        return ("paths: FILTERT",
                "`paths:` filtert: die Rule `%s` wurde in %d neuen Sitzung(en) NICHT geladen "
                "(gemessen %s)" % (base, len(neue_sitzungen), time.strftime("%d.%m.%Y")), 0)
    if gruende == {"path_glob_match"}:
        return ("paths: FILTERT (Grund path_glob_match)",
                "`paths:` filtert: die Rule `%s` lud nur mit Grund `path_glob_match` "
                "(gemessen %s)" % (base, time.strftime("%d.%m.%Y")), 0)
    return ("paths: FILTERT NICHT",
            "`paths:` filtert NICHT: die Rule `%s` lud in einer neuen Sitzung mit Grund %s "
            "(gemessen %s)" % (base, ", ".join(sorted(gruende)), time.strftime("%d.%m.%Y")), 1)


def auswerten(projekt, log=None, seit=None, datei=None):
    """Mit Merker wie bisher (eine Rule, seit dem Merker, eigene Sitzung ausgenommen).
    ⛔ v5.115.0: OHNE Merker gilt --seit als Merkerzeit (fehlt es: der ganze Log), --datei als
    Rule; ohne --datei ALLE Rules mit paths: — je Rule ein Urteil, eines fuer den Bestand."""
    m = _lies_merker(projekt)
    if m and not datei:
        rules = [m["datei"]]
        seit = seit or m.get("ts", "")
        sid = m.get("sid", "")
        quelle = "Merker"
    else:
        if datei:
            p = datei if os.path.isabs(datei) else os.path.join(projekt, ".claude", "rules", datei)
            if not os.path.isfile(p):
                print("⛔ Rule nicht gefunden: %s" % datei)
                return 2
            rules = [p]
        else:
            rules = paths_rules(projekt)
            if not rules:
                print("⛔ kein Merker paths-sonde und keine Rule mit paths: unter .claude/rules/ — "
                      "zuerst --start, oder --datei <rule>")
                return 2
        seit = seit or ""
        sid = os.environ.get("CLAUDE_CODE_SESSION_ID", "") or ""
        quelle = "ohne Merker (--seit %s)" % (seit or "Anfang des Protokolls")
    log = log or lp.finde_log()
    if not os.path.isfile(log):
        print("⛔ kein Ladeprotokoll: %s" % log)
        return 2
    basen = dict((os.path.basename(r), r) for r in rules)
    neue_sitzungen = set()
    treffer = dict((b, []) for b in basen)
    for z in open(log, encoding="utf-8", errors="replace"):
        t = z.rstrip("\n").split("\t")
        if len(t) < 3 or (seit and t[0] <= seit):
            continue
        s = t[3] if len(t) > 3 else ""
        if sid and s and sid.startswith(s):
            continue                      # dieselbe Sitzung zaehlt nicht
        neue_sitzungen.add(s or "?")
        pf = t[2].replace("\\", "/")
        for b in basen:
            if pf.endswith("/" + b):
                treffer[b].append((t[0], t[1], s))
    print("=" * 72)
    print("PATHS-SONDE auswerten — %s" % (", ".join(sorted(basen)) if len(basen) <= 3 else "%d Rules" % len(basen)))
    print("=" * 72)
    print("  Quelle %s, Sitzung %s, Protokoll %s" % (quelle, sid[:8] or "-", log))
    print("  neue Sitzungen seit dem Merker: %d" % len(neue_sitzungen))
    zeilen, rcs, urteile_ = [], [], {}
    for b in sorted(basen):
        u, satz, rc = _urteil(b, neue_sitzungen, treffer[b])
        urteile_[b] = (u, satz, rc, treffer[b])
        rcs.append(rc)
        print("  %-40s Ladungen %2d  %s" % (b[:40], len(treffer[b]), u))
    if len(basen) == 1:
        b = list(basen)[0]
        urteil, satz, rc = urteile_[b][0], urteile_[b][1], urteile_[b][2]
    else:
        n_f = sum(1 for b in basen if urteile_[b][2] == 0)
        n_n = sum(1 for b in basen if urteile_[b][2] == 1)
        n_nach = sum(1 for b in basen if urteile_[b][3] and set(g for _, g, _ in urteile_[b][3]) == {"path_glob_match"})
        if not neue_sitzungen:
            urteil, satz, rc = "NOCH NICHT MESSBAR", "keine neue Sitzung im Protokoll", 3
        elif n_n == 0:
            urteil = "paths: FILTERT (%d von %d Rules nicht beim Start, %d bei Dateiberuehrung nachgeladen)" % (n_f, len(basen), n_nach)
            satz = ("`paths:` filtert — gemessen %s, %s, %d Rules, Nachladen bei Dateiberuehrung (%d)"
                    % (time.strftime("%d.%m.%Y"), os.path.basename(os.path.abspath(projekt)), len(basen), n_nach))
            rc = 0
        else:
            urteil = "paths: FILTERT NICHT bei %d von %d Rules" % (n_n, len(basen))
            satz = ("`paths:` filtert NICHT durchgehend: %d von %d Rules luden in einer neuen Sitzung mit "
                    "session_start (gemessen %s, %s)" % (n_n, len(basen), time.strftime("%d.%m.%Y"),
                                                         os.path.basename(os.path.abspath(projekt))))
            rc = 1
    print("  URTEIL: %s" % urteil)
    print("  Satz fuer kontext-anlegen.md: %s" % satz)
    _andere_melden(projekt)
    if m and not datei:
        print("  Rueckweg: cp \"%s\" \"%s\"" % (m.get("sicherung", "?"), m["datei"]))
    d = os.environ.get("MIND_DEBUG_DIR")
    if d and os.path.isdir(d):
        out = os.path.join(d, "paths-sonde-%s.md" % time.strftime("%Y%m%d-%H%M%S"))
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("# paths-Sonde %s\n\n- Projekt: %s\n- Rule: `%s`\n- Merker seit: %s\n- neue Sitzungen: %d\n"
                     "- Ladungen: %s\n- URTEIL: %s\n- Satz: %s\n"
                     % (time.strftime("%Y-%m-%d %H:%M"), os.path.abspath(projekt),
                        "`, `".join(sorted(basen)), seit or "Anfang", len(neue_sitzungen),
                        "; ".join("%s %s %s %s" % (b, t[0], t[1], t[2]) for b in sorted(basen) for t in treffer[b]) or "keine",
                        urteil, satz))
            if len(basen) > 1:
                fh.write("\n## je Rule\n\n")
                for b in sorted(basen):
                    fh.write("- `%s`: %s (%d Ladungen)\n" % (b, urteile_[b][0], len(treffer[b])))
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
    os.makedirs(os.path.join(proj, "tools")); open(os.path.join(proj, "a.py"), "w").write("")
    open(os.path.join(proj, "tools", "b.py"), "w").write("")   # lebende Dateien fuer den Dateibezug
    open(os.path.join(rd, "gross.md"), "w", encoding="utf-8").write(
        "---\ndescription: x\nglobs: [\"src/**/*.py\"]\n---\n# G\n\n" + ("⛔ NIE `a.py` aendern.\n\n" * 20))
    open(os.path.join(rd, "klein.md"), "w", encoding="utf-8").write(
        "---\ndescription: y\nglobs: [\"tools/b.py\"]\n---\n# K\n\n⛔ NIE `tools/b.py` ohne Test.\n")
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
    # v5.112.0: Ergebnisse aus anderen Projekten werden gemeldet
    dbg = os.path.join(d, "debug"); os.makedirs(dbg); os.environ["MIND_DEBUG_DIR"] = dbg
    open(os.path.join(dbg, "paths-sonde-1.md"), "w", encoding="utf-8").write("# x\n\n- Projekt: C:/anderes/projekt\n- URTEIL: paths: FILTERT NICHT\n")
    open(os.path.join(dbg, "paths-sonde-2.md"), "w", encoding="utf-8").write("# y\n\n- Projekt: %s\n- URTEIL: egal\n" % os.path.abspath(proj))
    a = andere_ergebnisse(proj)
    pruef("andere Projekte: eines gemeldet, das eigene nicht", a, [("C:/anderes/projekt", "paths: FILTERT NICHT")])
    os.environ.pop("MIND_DEBUG_DIR", None)
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
        return auswerten(hol("--auswerten"), hol("--log"), hol("--seit"), hol("--datei"))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
