#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Der Audit-Lauf — fuehrt alle Cleaner-Werkzeuge zu EINEM Bericht zusammen.

⛔ DIE REIHENFOLGE IM BERICHT IST ABSICHT

Gruppe 5 ("nicht entscheidbar") steht ZUERST, nicht zuletzt. Sie ist das
ehrliche Mass dafuer, wie viel dieses Audit wirklich wusste — ein Bericht, der
sie ans Ende schiebt, suggeriert eine Sicherheit, die er nicht hat.

## Und Gruppe 5 zerfaellt in ZWEI

    5a  kein Verstoss vorliegend                 -> vielleicht messbar, spaeter
    5b  diese Regelklasse ist NICHT LOGGBAR      -> grundsaetzlich unmessbar

⭐ **5b ist der Kern, nicht der Rest.** Urteils- und Prozessregeln
(`keine-annahmen`, `plan-mode`, `ursache-vor-reparatur`, `autonom-arbeiten`)
erzeugen kaum je einen maschinell erfassbaren Verstoss. Sie landen dort **nicht
weil sie unbeobachtet blieben, sondern weil sie unbeobachtBAR sind.**

Ein Leser, dem das nicht gesagt wird, haelt Gruppe 5 fuer eine Restmenge.

## ⛔ Dieser Lauf AENDERT NICHTS

Er ist Stufe 1 von drei: Bericht -> dein OK -> Plan -> dein OK -> anwenden.

Aufruf:
  python cleaner_audit.py [--bereich <projekt>] [--nur global|projekt|alles]
  python cleaner_audit.py --selbsttest

Rueckgabe: 0 = gelaufen · 1 = Befunde vorhanden · 2 = nicht messbar
"""
import os
import re
import sys

_HIER = os.path.dirname(os.path.abspath(__file__))
if _HIER not in sys.path:
    sys.path.insert(0, _HIER)

# ⛔ NICHT nachbauen — jedes dieser Werkzeuge traegt seine eigene Gegenprobe.
#    Ein zweites Instrument daneben hiesse, dass sich ab jetzt zwei Messungen
#    widersprechen koennen.
import cleaner_duplikate as dup                                  # noqa: E402
import cleaner_einordnung as ein                                 # noqa: E402
import cleaner_belege as bel                                     # noqa: E402
import cleaner_aussagen as aus                                   # noqa: E402
import cleaner_grenzen as gre                                    # noqa: E402
import cleaner_urteile as urt                                 # noqa: E402
import cleaner_tor as tor
# L6 (v5.21.0): die Referenz-Existenzpruefung. ⛔ NICHT nachbauen — diese Kette
# traegt die Narben von DREI gescheiterten Nachbauten (20.08.2026: 11
# Slash-Commands als tote Pfade · 21.08.: 9 gemeldet, echte 0 · ein dritter
# Anlauf mit demselben Wurzel-Fehler).
import claudemd_pipeline as pipe                                 # noqa: E402

# ⛔ ERST importieren, DANN reconfigure — nie einen zweiten TextIOWrapper.
sys.stdout.reconfigure(encoding="utf-8", newline="")

# Regeln, deren Verstoesse strukturell nicht loggbar sind (Gruppe 5b).
# ⚠ Das ist eine ENTSCHEIDUNG, keine Messung. Sie steht hier sichtbar, damit
#   sie bestreitbar ist.
NICHT_LOGGBAR = ("keine-annahmen", "plan-mode", "ursache-vor-reparatur",
                 "autonom-arbeiten", "fertig-heisst-fertig", "messung-vor-glauben")


def dateien(projekt, nur="alles", doku=None):
    """Alle Dateien, die DAUERKONTEXT kosten — nicht nur die rules/.

    ⛔ v5.27.0: die CLAUDE.md kam DAZU, und ihr Fehlen war ein BEFUND.
       Bis v5.26.0 sah diese Funktion ausschliesslich `rules/` an. Der
       Nutzer hat sein Duplikat-Problem woertlich an der CLAUDE.md
       festgemacht ("cleaner_duplikate hat mir 447 Duplikate gemeldet") —
       und genau diese Datei hat `--audit` nie angesehen. Ein Audit, das
       die wichtigste Context-Datei auslaesst, meldet "wenig gefunden"
       und meint "wenig angesehen".

    ⚠ `doku` ist optional und NICHT vorgegeben: Doku-Verzeichnisse heissen
      in jedem Projekt anders (`knowledge/`, `docs/`, `Wissen/`). Ein fest
      verdrahteter Name waere ein projektspezifisches Pflaster in einem
      allgemeinen Werkzeug — derselbe Fehler wie der INDEX.md-Vorschlag
      aus `Pc Forschung` (v5.21.3).
    """
    H = os.path.expanduser("~")
    out = []
    wurzeln, einzeln = [], []
    if nur in ("alles", "global"):
        wurzeln.append(os.path.join(H, ".claude", "rules"))
        einzeln.append(os.path.join(H, ".claude", "CLAUDE.md"))
    if nur in ("alles", "projekt"):
        wurzeln.append(os.path.join(projekt, ".claude", "rules"))
        einzeln.append(os.path.join(projekt, "CLAUDE.md"))
        einzeln.append(os.path.join(projekt, ".claude", "CLAUDE.md"))
        # §3 v5.111.0: CLAUDE.local.md laedt beim Sitzungsstart genauso (gemessen: Fixture
        #    mit allen drei Varianten — sie fehlte hier, py 1/4 Treffer, Skill nannte sie nie)
        einzeln.append(os.path.join(projekt, "CLAUDE.local.md"))
        # §1 v5.111.0 (Etappe 17): im Rollen-Aufbau die Roster-Unterordner — v5.106.0 gab sie
        #    mind-claudemd/-rules/-update, der Cleaner sah sie nicht (Creator: 22 Dateien).
        global _UNTER
        _UNTER = {}
        try:
            from learnings_quellen import rollen_ordner
            for _o in rollen_ordner(projekt):
                _UNTER[os.path.abspath(_o)] = os.path.basename(_o)
                wurzeln.append(os.path.join(_o, ".claude", "rules"))
                for _e in ("CLAUDE.md", os.path.join(".claude", "CLAUDE.md"), "CLAUDE.local.md"):
                    einzeln.append(os.path.join(_o, _e))
        except Exception:
            pass
    # ⛔ v5.107.0 (Etappe 15 §1, Nutzer-Entscheidung 14.09.2026: "mind cleaner ist fuer
    #    alles da"): das Memory ist vollwertiger Bestand — bei `projekt`, `alles` und
    #    allein als `memory`. Der Pfad kommt aus dem Slug (cleaner_duplikate._memory_dir,
    #    NIE der Projektpfad); MEMORY.md ist der Index und keine Aussage, sie bleibt
    #    draussen. Die vier Gates aus mind-memory 4.0c gelten VOR jedem Anwenden.
    global _MEMDIR, _MEMDIRS
    _MEMDIR = ""
    _MEMDIRS = {}
    if nur in ("alles", "projekt", "memory"):
        _MEMDIR = dup._memory_dir(H, projekt)
        # v5.109.0 (Etappe 18): auch die Memorys der Roster-Ordner (je eigener Slug),
        #    angezeigt unter dem ORDNERnamen, nicht dem Slug
        if _MEMDIR:
            _MEMDIRS[os.path.abspath(_MEMDIR)] = ""
            wurzeln.append(_MEMDIR)
        try:
            from learnings_quellen import rollen_ordner
            for _o in rollen_ordner(projekt):
                _d = dup._memory_dir(H, _o)
                if _d and os.path.abspath(_d) not in _MEMDIRS:
                    _MEMDIRS[os.path.abspath(_d)] = os.path.basename(_o)
                    wurzeln.append(_d)
        except Exception:
            pass
    if doku:
        wurzeln.append(doku)
    for w in wurzeln:
        for wurzel, unter, fs in os.walk(w):
            unter[:] = [u for u in unter if u not in ("__pycache__", ".git")]
            out += [os.path.join(wurzel, f) for f in sorted(fs)
                    if f.endswith(".md") and not (os.path.abspath(w) in _MEMDIRS and f == "MEMORY.md")]
    for e in einzeln:
        if os.path.isfile(e) and e not in out:
            out.append(e)
    return out


_MEMDIR = ""
_MEMDIRS = {}
_UNTER = {}
LETZTE_GRUPPEN = None


def ist_roster(p):
    """v5.117.0 (§0a): der Roster — .claude/rules/rollen.md mit einer Rollentabelle."""
    if os.path.basename(p) != "rollen.md":
        return False
    try:
        t = open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return False
    return bool(re.search(r"^\|\s*\*{0,2}manager\*{0,2}\s*\|", t, re.M))


def ist_unantastbar(p):
    """v5.117.0 (Etappe 22 §0a, Veras Zustellplan-Audit 16.09.2026: Plan-Zeile 1 = ARCHIV rollen.md,
    der AKTIVE Roster, 2 Tage alt, 1 Commit): Roster, CLAUDE.md (alle drei Formen) und MEMORY.md
    bekommen nie ARCHIV/UMZUG/DOCS — hoechstens MELDUNG. Rueckgabe: Grund oder ''."""
    b = os.path.basename(p)
    if b in ("CLAUDE.md", "CLAUDE.local.md"):
        return "CLAUDE.md ist die Wurzel jedes Kontexts"
    if b == "MEMORY.md":
        return "MEMORY.md ist der Index des Gedaechtnisses"
    if ist_roster(p):
        return "der Roster traegt das Rollen-Gate (v5.54.0) und jede Sitzung"
    return ""


def _ist_memory(p):
    ap = os.path.abspath(p)
    if _MEMDIR and ap.startswith(os.path.abspath(_MEMDIR)):
        return True
    return any(ap.startswith(d) for d in _MEMDIRS)


def memory_beleg(p, z=None):
    """v5.115.0 (§2): Beleg einer Memory-Datei OHNE Git — mtime, eingehende [[Verweise]] aus
    den Nachbarn, Index-Eintrag in MEMORY.md. Ein Satz fuer Gruppe 5a."""
    import time as _t
    d = os.path.dirname(p)
    name = os.path.splitext(os.path.basename(p))[0]
    try:
        tage = int((_t.time() - os.path.getmtime(p)) / 86400)
    except OSError:
        tage = -1
    verweise = 0
    for f in os.listdir(d) if os.path.isdir(d) else []:
        if not f.endswith(".md") or f == os.path.basename(p):
            continue
        try:
            if ("[[%s]]" % name) in open(os.path.join(d, f), encoding="utf-8", errors="replace").read():
                verweise += 1
        except OSError:
            pass
    idx = os.path.join(d, "MEMORY.md")
    im_index = False
    if os.path.isfile(idx):
        try:
            im_index = ("(%s.md)" % name) in open(idx, encoding="utf-8", errors="replace").read()
        except OSError:
            pass
    fz = (" (%d Verstoesse in anderen Projekten)" % z["fremd"]) if z and z.get("fremd") else ""
    return ("nicht messbar (kein Git)%s — Beleg: geaendert vor %s Tagen, %d [[Verweis(e)]], Index %s"
            % (fz, tage if tage >= 0 else "?", verweise, "ja" if im_index else "NEIN"))


def _nm(p):
    """Anzeigename: Memory-Dateien als `memory/<name>` (v5.107.0), die eines Roster-Ordners
    als `memory[<ordner>]/<name>` (v5.109.0), Dateien eines Roster-Unterordners als
    `<ordner>/<name>` (v5.111.0), sonst der Dateiname."""
    ap = os.path.abspath(p)
    for d, kennung in _MEMDIRS.items():
        if ap.startswith(d):
            return ("memory[%s]/" % kennung if kennung else "memory/") + os.path.basename(p)
    if _MEMDIR and ap.startswith(os.path.abspath(_MEMDIR)):
        return "memory/" + os.path.basename(p)
    for d, name in _UNTER.items():
        if ap.startswith(d + os.sep):
            return name + "/" + os.path.basename(p)
    return os.path.basename(p)


# ---------------------------------------------------------------- §2 Skills-Bestand (v5.111.0)
SKILL_DESC_MAX = int(os.environ.get("MIND_SKILL_DESC_MAX", "600"))
SKILL_TOT_TAGE = int(os.environ.get("MIND_SKILL_TOT_TAGE", "30"))
_DIREKTIV = re.compile(r"\b(ALWAYS|MUST|NEVER|invoke|Nutze das|immer|nie)\b", re.I)


def _skill_desc(p):
    try:
        t = open(p, encoding="utf-8", errors="replace").read(6000)
    except OSError:
        return ""
    m = re.search(r"^description:\s*(.+?)(?=^\S|\Z)", t, re.M | re.S)
    if not m:
        return ""
    return re.sub(r"\s+", " ", m.group(1)).strip().strip("\"'|>")


def _skill_zuletzt_aufgerufen(name, tage, projects_dir=None):
    """Wurde `/name` in einem Transkript der letzten `tage` Tage genannt? Liest nur JSONL,
    deren mtime im Fenster liegt (Dateien > 80 MB werden ausgelassen und gemeldet)."""
    import time as _t
    pd = projects_dir or os.path.join(os.path.expanduser("~"), ".claude", "projects")
    if not os.path.isdir(pd):
        return None
    grenze = _t.time() - tage * 86400
    nadel = ("/" + name).encode("utf-8")
    geprueft = 0
    for wurzel, unter, fs in os.walk(pd):
        unter[:] = [u for u in unter if u != "subagents"]
        for f in fs:
            if not f.endswith(".jsonl"):
                continue
            p = os.path.join(wurzel, f)
            try:
                st = os.stat(p)
            except OSError:
                continue
            if st.st_mtime < grenze or st.st_size > 80 * 1024 * 1024:
                continue
            geprueft += 1
            try:
                with open(p, "rb") as fh:
                    while True:
                        b = fh.read(4 * 1024 * 1024)
                        if not b:
                            break
                        if nadel in b:
                            return True
            except OSError:
                continue
    return False if geprueft else None


def skills_bestand(projekt, skills_dir=None, rules_dir=None, plugin_dirs=None, projects_dir=None):
    """§2 (Etappe 17): die 45 descriptions sind Dauerkontext (~7 300 Token) — der Cleaner zog
    Dateien DORTHIN und prueft sie nie. Je Skill: description-Laenge und Direktivitaet, Zeiger
    aus einer Kurz-Rule, Aufruf in den Transkripten der letzten SKILL_TOT_TAGE Tage.
    Rueckgabe: Liste (pfad, urteil, grund). Plugin-Skills werden nur GEMELDET (gehoeren dem Plugin)."""
    H = os.path.expanduser("~")
    sd = skills_dir or os.path.join(H, ".claude", "skills")
    rd = rules_dir or os.path.join(H, ".claude", "rules")
    out = []
    if not os.path.isdir(sd):
        return out
    rules_text = ""
    if os.path.isdir(rd):
        for f in os.listdir(rd):
            if f.endswith(".md"):
                try:
                    rules_text += open(os.path.join(rd, f), encoding="utf-8", errors="replace").read()
                except OSError:
                    pass
    beschr = {}
    for name in sorted(os.listdir(sd)):
        p = os.path.join(sd, name, "SKILL.md")
        if not os.path.isfile(p):
            continue
        d = _skill_desc(p)
        beschr.setdefault(d[:80].lower(), []).append(name)
        zeiger = ("skills/%s/SKILL.md" % name) in rules_text or ("/%s`" % name) in rules_text or ("/%s " % name) in rules_text
        aufgerufen = _skill_zuletzt_aufgerufen(name, SKILL_TOT_TAGE, projects_dir)
        if not d:
            out.append((p, "ZURUECK IN RULE", "keine description — der Auswaehler sieht nichts, die Rule wuerde immer laden"))
        elif len(d) > SKILL_DESC_MAX:
            out.append((p, "ZU LANG", "description %d Zeichen (> %d, Kappung 1536) — Aenderungsprotokoll statt Ausloeser?" % (len(d), SKILL_DESC_MAX)))
        elif not _DIREKTIV.search(d):
            out.append((p, "ZU WEICH", "description ohne direktives Wort (ALWAYS/MUST/invoke/Nutze das) — gemessen half direktiver Stil (20-84 %)"))
        elif aufgerufen is False and not zeiger:
            out.append((p, "TOT-VERDACHT", "kein Aufruf `/%s` in Transkripten seit %d Tagen UND keine Kurz-Rule zeigt hin" % (name, SKILL_TOT_TAGE)))
        elif not zeiger:
            out.append((p, "OHNE ZEIGER", "keine Kurz-Rule in rules/ nennt den Pfad oder `/%s` — Auswahl haengt an der 20-%%-Mechanik" % name))
        elif aufgerufen is False:
            out.append((p, "TOT-VERDACHT", "kein Aufruf `/%s` in Transkripten seit %d Tagen (Zeiger da)" % (name, SKILL_TOT_TAGE)))
        else:
            out.append((p, "BLEIBT", "description %d Zeichen, direktiv, Zeiger da, aufgerufen" % len(d)))
    for k, namen in beschr.items():
        if k and len(namen) > 1:
            for n in namen:
                out.append((os.path.join(sd, n, "SKILL.md"), "DOPPELT", "gleiche description wie %s" % ", ".join(x for x in namen if x != n)))
    for pdir in (plugin_dirs or []):
        if os.path.isdir(pdir):
            n = len([x for x in os.listdir(pdir) if os.path.isfile(os.path.join(pdir, x, "SKILL.md"))])
            out.append((pdir, "PLUGIN", "%d Plugin-Skills — nur gemeldet, sie gehoeren dem Plugin" % n))
    return out


# ---------------------------------------------------------------- §4 tote Regler (v5.111.0)
def tote_regler(settings_pfad=None, leser_wurzeln=None):
    """MIND_*-Variablen in settings.json, die kein Hook/Skill/Werkzeug mehr LIEST (Zuweisung
    `$MIND_X`/`${MIND_X`/`environ.get("MIND_X"`) — Nennung in Prosa zaehlt nicht. Nur melden:
    settings.json ist die Datei des Nutzers."""
    import json
    sp = settings_pfad or os.path.join(os.path.expanduser("~"), ".claude", "settings.json")
    try:
        env = json.load(open(sp, encoding="utf-8")).get("env", {}) or {}
    except (OSError, ValueError):
        return []
    wurzeln = leser_wurzeln or [os.path.join(_HIER, "..", d) for d in ("hooks", "skills", "references")]
    texte = []
    for w in wurzeln:
        for wz, unter, fs in os.walk(w):
            unter[:] = [u for u in unter if u not in ("__pycache__", ".git")]
            for f in fs:
                if f.endswith((".sh", ".md", ".py", ".json")):
                    try:
                        texte.append(open(os.path.join(wz, f), encoding="utf-8", errors="replace").read())
                    except OSError:
                        pass
    ganz = "\n".join(texte)
    out = []
    for k, v in sorted(env.items()):
        if not k.startswith("MIND_"):
            continue
        muster = re.compile(r"\$\{?%s\b|environ(?:\.get)?\(?\[?[\"']%s[\"']" % (re.escape(k), re.escape(k)))
        n = len(muster.findall(ganz))
        if n == 0:
            out.append((k, str(v), "kein Leser in hooks/skills/references — Nutzerdatei, nur du aenderst sie"))
    return out


def lauf(projekt, nur="alles", doku=None):
    ds = dateien(projekt, nur, doku)
    if not ds:
        print("⛔ Keine Regeldatei gefunden. Eher ein falscher Pfad als ein leerer Bestand.")
        return 2

    idx = bel.debug_pfad(projekt)
    gruppen = {"5a": [], "5b": [], "1": [], "2": [], "3": [], "4": [],
               "6": [], "7": [], "8": [], "9": []}   # 9 = unantastbar, nur Meldung (v5.117.0)
    # v5.111.0: Gruppe 7 Skills-Bestand (global; Plugin-Skills nur gemeldet), Gruppe 8 tote Regler
    if nur in ("alles", "global"):
        _plugins = []
        _pr = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if _pr and os.path.isdir(os.path.join(_pr, "skills")):
            _plugins.append(os.path.join(_pr, "skills"))
        gruppen["7"] = skills_bestand(projekt, plugin_dirs=_plugins)
        gruppen["8"] = tote_regler()
    grenzfaelle, blind = [], []

    for p in ds:
        name = os.path.splitext(os.path.basename(p))[0]
        u, grund, z = bel.urteile(p, idx, projekt)
        # ⛔ v5.115.0 (Etappe 23 §2): Memory liegt AUSSERHALB des Repos — die Git-Quelle greift
        #    nie, und „Historie nicht messbar" las sich wie „ohne Beleg -> streichen" (Vera,
        #    40 Memory-Dateien im Zustellplan). Beleg fuer Memory: Datei-Zeiten, [[Verweise]],
        #    Index-Eintrag — und die Zeile sagt „nicht messbar (kein Git)".
        if _ist_memory(p) and u in ("NICHT ENTSCHEIDBAR", "SCHWACHER KANDIDAT", "NICHT MESSBAR"):
            u, grund = "NICHT ENTSCHEIDBAR", memory_beleg(p, z)
        e = ein.mit_skill(p)
        vorschlag = (e or {}).get("vorschlag_zusammen") or (e or {}).get("vorschlag", "?")

        _unant = ist_unantastbar(p)
        if _unant and u in ("VERALTUNGS-KANDIDAT", "SCHWACHER KANDIDAT"):
            gruppen["9"].append((p, "%s — unantastbar (%s), nur Meldung, nie Archiv/Umzug" % (u, _unant)))
            u = "UNANTASTBAR"
        if u == "BELEGT NOETIG":
            gruppen["1"].append((p, grund))
        elif u == "VERALTUNGS-KANDIDAT":
            gruppen["4"].append((p, grund))
        elif u == "SCHWACHER KANDIDAT":
            gruppen["4"].append((p, grund + " (schwach)"))
        elif u == "UNANTASTBAR":
            pass
        elif name in NICHT_LOGGBAR:
            gruppen["5b"].append((p, "Urteils-/Prozessregel — Verstoesse sind mit dem "
                                     "vorhandenen Instrumentarium NICHT loggbar"))
        else:
            gruppen["5a"].append((p, grund))

        # ⛔ KONTEXT-TOR (v5.26.0) — die RUECKWAERTS-Richtung.
        #    Die fuenf Commands fragen VOR dem ADD; hier wird der ganze
        #    Bestand gefragt. Nur vorwaerts liesse den Altbestand stehen.
        try:
            _txt = open(p, encoding="utf-8", errors="replace").read()
            _tr = tor.pruefe_text(_txt)
        except OSError:
            _tr = {}
        for _k in ("A1", "A2", "A3", "C1"):
            if _tr.get(_k):
                gruppen["6"].append(
                    (p, "%s x%d — %s" % (_k, len(_tr[_k]),
                                         _tr[_k][0][1][:40])))

        # Falsch platziert? — v5.108.0: DOCS dazu, und die ZWEITE Klasse steht mit im Bericht
        if _unant and vorschlag in ("COMMAND", "DOCS"):
            gruppen["9"].append((p, "%s — unantastbar (%s), nur Meldung, nie Umzug" % (vorschlag, _unant)))
        elif vorschlag in ("HOOK-KANDIDAT", "COMMAND", "DOCS") and e:
            _txt = "%s — %s" % (vorschlag, e.get("grund_zusammen") or e.get("grund", ""))
            for _k in (e.get("vorschlaege") or [])[1:]:
                _txt += " | ODER %s — %s" % (_k, (e.get("gruende") or {}).get(_k, ""))
            gruppen["2"].append((p, _txt))
        elif e and "RULE-PATHS" in (e.get("vorschlaege") or []):
            gruppen["2"].append((p, "RULE-PATHS — %s" % (e.get("gruende") or {}).get("RULE-PATHS", "")))
        # Lint Leakage
        verd, hook, wieso = ein.lint_leakage(p, projekt)
        if verd:
            gruppen["2"].append((p, "LINT LEAKAGE: %s" % wieso))

        # Grenzen
        b, _ = gre.pruefe(p)
        for schwere, gname, txt in (b or []):
            if schwere == "BRUCH":
                grenzfaelle.append((p, gname, txt))

        # Blinde Verweise
        a = aus.lauf(p)
        if a and a["blind"]:
            blind.append((p, len(a["blind"])))

    # Duplikate
    # v5.107.0: `memory` vergleicht gegen die Projekt-Ablagen (Rules, CLAUDE.md, Memory) —
    #    Duplikate in BEIDE Richtungen, deshalb "projekt" und nicht nur das Memory.
    abl = dup.ablagen(projekt, "alles" if nur == "alles" else ("projekt" if nur == "memory" else nur))
    text, wo = {}, {}
    import collections
    wo = collections.defaultdict(set)
    for nname, pfade in abl.items():
        for p in pfade:
            t = dup._inhalt(p)
            text[p] = t
            for m in dup.marken(t):
                wo[m].add((nname, p))
    for m, stellen in wo.items():
        st = sorted(stellen)
        if len({n for n, _ in st}) < 2:
            continue
        for i in range(len(st)):
            for j in range(i + 1, len(st)):
                (na, pa), (nb, pb) = st[i], st[j]
                if na == nb:
                    continue
                kat, g = dup.einordnen(m, pa, text[pa], pb, text[pb])
                zustand, eintrag = urt.pruefen(projekt, [pa, pb])
                if zustand == "gueltig" and eintrag.get("urteil") in urt.GESCHUETZT:
                    continue          # ⛔ Das Buch hat entschieden.
                if kat == "duplikat":
                    gruppen["3"].append((m, "%s + %s" % (na, nb)))
                elif kat == "zahlendrift":
                    gruppen["3"].append((m, "⛔ ZAHLENDRIFT: %s + %s — %s" % (na, nb, g)))

    # --- Bericht ----------------------------------------------------------
    print("=" * 88)
    print("  /mind-cleaner --audit   ·   %d Regeldatei(en)   ·   Bereich: %s"
          % (len(ds), nur))
    print("=" * 88)
    print("  ⛔ Dieser Lauf AENDERT NICHTS. Stufe 1 von drei.")
    print()

    # ⛔ Gruppe 5 ZUERST.
    print("  " + "=" * 84)
    print("  5 · NICHT ENTSCHEIDBAR — %d Datei(en)"
          % (len(gruppen["5a"]) + len(gruppen["5b"])))
    print("  " + "=" * 84)
    print("     Steht oben, weil es das ehrliche Mass dafuer ist, wie viel dieses")
    print("     Audit wirklich wusste. Eine nie gebrochene Regel kann ueberfluessig")
    print("     sein — oder GENAU DESHALB nie gebrochen worden sein, WEIL sie da ist.")
    print()
    # ⛔ v5.27.0 — BEWEISLAST UMGEKEHRT (Nutzer-Auftrag "richtig aggressiv").
    #    Bis v5.26.0 hiess diese Gruppe "kein Verstoss vorliegend, vielleicht
    #    spaeter messbar" — eine Regel blieb, bis belegt war, dass sie weg
    #    kann. Jetzt umgekehrt: sie muss belegen, WARUM sie da ist.
    #    ⚠ Der Ton ist schaerfer, die MECHANIK nicht: geloescht wird nichts,
    #      der Nutzer sagt weiterhin ja (Dreistufigkeit, 24.08.2026).
    print("  5a · ⛔ OHNE BELEG (%d) — STREICHEN, wenn du nicht widersprichst"
          % len(gruppen["5a"]))
    print("       Kein nachweisbarer Verstoss, kein Beleg fuer ihre Notwendigkeit.")
    print("       ⚠ Widerspruch ist ein gueltiger Grund — eine nie gebrochene")
    print("         Regel kann GENAU DESHALB nie gebrochen worden sein, WEIL")
    print("         sie da ist. Aber der Widerspruch muss jetzt KOMMEN.")
    for p, g in gruppen["5a"]:
        # v5.115.0/v5.117.0: die 5a-Begruendung ist der ganze Punkt der Gruppe („Beweislast umgekehrt") —
        # ungekuerzt, sonst fehlen „kein Git", „zu jung fuer ein Urteil" und die Zahlen dahinter
        print("       %-32s %s" % (_nm(p)[:32], g))
    print()
    print("  5b · ⭐ GRUNDSAETZLICH NICHT LOGGBAR (%d) — der Kern, nicht der Rest"
          % len(gruppen["5b"]))
    for p, g in gruppen["5b"]:
        print("       %-32s %s" % (_nm(p)[:32], g[:44]))
    if gruppen["5b"]:
        print()
        print("       Diese landen hier NICHT weil sie unbeobachtet blieben, sondern")
        print("       weil sie unbeobachtBAR sind. Wer 5b fuer eine Restmenge haelt,")
        print("       liest den Bericht falsch.")

    for nr, titel in (("1", "BELEGT NOETIG — bleibt, wo es ist"),
                      ("2", "FALSCH PLATZIERT — Ort A nach Ort B"),
                      ("3", "DOPPELT — eine Stelle wird Zeiger"),
                      ("4", "BELEGT VERALTET — ins Archiv, mit Beleg"),
                      ("9", "UNANTASTBAR — Roster, CLAUDE.md, MEMORY.md: nur Meldung (v5.117.0)"),
                      ("6", "KONTEXT-TOR — kostet Kontext ohne Gegenwert")):
        print()
        print("  %s · %s (%d)" % (nr, titel, len(gruppen[nr])))
        # ⛔ v5.27.0: keine STILLE Kappung mehr. Vorher wurden ab dem 13.
        #    Eintrag welche weggelassen, ohne es zu sagen — und ein Bericht,
        #    der still kappt, liest sich wie "das war alles".
        for a, b in gruppen[nr][:40]:
            print("       %-32s %s" % (os.path.basename(str(a))[:32], str(b)[:48]))
        if len(gruppen[nr]) > 40:
            print("       … %d weitere NICHT gezeigt (Bericht sonst unlesbar) —"
                  % (len(gruppen[nr]) - 40))
            print("         sie sind NICHT erledigt, nur nicht abgedruckt.")

    if gruppen["6"]:
        print()
        print("       ⚠ A1 (weiss das Modell es?) und C2 (befolgbar?) sind")
        print("         URTEILE, keine Messungen — Kandidaten, kein Befund.")
        print("         Vorschrift: references/kontext-tor.md")

    if gruppen["7"]:
        print()
        _n7 = [x for x in gruppen["7"] if x[1] not in ("BLEIBT", "PLUGIN")]
        print("  7 · SKILLS-BESTAND (v5.111.0) — %d Skill(s), %d mit Befund; descriptions sind"
              % (len([x for x in gruppen["7"] if x[1] != "PLUGIN"]), len(_n7)))
        print("      Dauerkontext (alle immer geladen) und wurden hier nie geprueft")
        for p, u, g in gruppen["7"]:
            if u in ("BLEIBT",):
                continue
            print("       %-14s %-28s %s" % (u, os.path.basename(os.path.dirname(p))[:28] if u != "PLUGIN" else "plugin", g[:70]))
    if gruppen["8"]:
        print()
        print("  8 · TOTE REGLER (v5.111.0) — %d MIND_*-Variable(n) in settings.json ohne Leser"
              % len(gruppen["8"]))
        print("      ⛔ Nutzerdatei — nur du. Nichts hier aendert sie.")
        for k, v, g in gruppen["8"]:
            print("       %-26s = %-12s %s" % (k, v[:12], g))

    if grenzfaelle:
        print()
        print("  ⛔ STILLE KAPPUNGEN — %d (hier verschwindet Inhalt OHNE Meldung)"
              % len(grenzfaelle))
        for p, gname, txt in grenzfaelle[:8]:
            print("       %-28s %-20s %s" % (_nm(p)[:28], gname, txt[:34]))

    if blind:
        print()
        print("  ⚠ BLINDE VERWEISE — %d Datei(en) nennen eine Datei ohne zu sagen wozu"
              % len(blind))
        for p, n in blind[:8]:
            print("       %-32s %d Stelle(n)" % (_nm(p)[:32], n))

    # ======================================================================
    # L6 · TOTE VERWEISE (NEU v5.21.0)
    # ======================================================================
    # ⭐ Die EINZIGE Stelle, an der ohne Verstossdaten "veraltet" geurteilt
    #    werden darf: der genannte Gegenstand existiert nicht mehr. Das ist
    #    eine Existenzpruefung, keine Verhaltensfrage.
    # ⚠ `pfade` mischt Listen und Zaehler — am Code nachgesehen, nicht geraten:
    #   dead/extern sind LISTEN, skip/unsure/befehle sind ZAHLEN. Die erste
    #   Fassung dieses Blocks iterierte ueber `unsure` und brach mit
    #   "'int' object is not iterable" ab.
    tot, extern, unlesbar = [], [], []
    unsure = 0
    for p in ds:
        try:
            erg = pipe.pruefe(p, projekt)
        except Exception as e:                       # noqa: BLE001
            unlesbar.append((p, str(e)[:60]))
            continue
        pf = erg.get("pfade") or {}
        # ⛔ EIN GLOBALER PFAD IST VON HIER AUS NICHT ENTSCHEIDBAR.
        #    Eine Regel in `~/.claude/rules/` nennt Pfade relativ zur
        #    ARBEITSWURZEL des Nutzers, nicht relativ zu diesem Projekt.
        #    GEMESSEN 25.08.2026: der erste Lauf meldete 22 tote Pfade — und
        #    `_claude_backups/_auto`, `_claude_tools/hooks/sicherung.py` und
        #    `_claude_vm/sichtpruef.py` existieren alle, nur eben unter
        #    `C:\CD\KOHLEKTIV`. **Alle 22 stammten aus globalen Regeln.**
        #    Sie als tot zu melden hiesse, gueltige Verweise zum Loeschen
        #    vorzuschlagen — genau der Fehler, den `classify_path` dreimal
        #    gemacht hat, bevor er portiert wurde.
        global_regel = os.path.abspath(p).startswith(
            os.path.abspath(os.path.join(os.path.expanduser("~"), ".claude")))
        if global_regel:
            unsure += len(pf.get("dead") or []) + len(pf.get("extern") or [])
        else:
            tot += [(p, x) for x in (pf.get("dead") or [])]
            extern += [(p, x) for x in (pf.get("extern") or [])]
        # ⛔ UNSURE ist die DRITTE Klasse und wird NIE geurteilt, nur gezaehlt.
        #    Ein Pfad, den das Instrument nicht einordnen kann, ist nicht tot —
        #    er ist UNGEMESSEN. Wer beides gleichsetzt, loescht gueltige Verweise.
        unsure += int(pf.get("unsure") or 0)

    print()
    print("  ⚠ REFERENZ-EXISTENZ [EXPERIMENTELL] — %d fraglich · %d extern · %d ungemessen"
          % (len(tot), len(extern), unsure))
    print("     ⛔ NICHT ALS BEFUNDLISTE AUSGEGEBEN, und das ist Absicht.")
    print("        Gemessen 25.08.2026 am eigenen Bestand: von 11 Meldungen war")
    print("        KEINE EINZIGE ein echter toter Pfad. Darunter `\\|` (maskierte")
    print("        Tabellen-Pipe), `hooks/lib.sh:104-106` (Zitat mit Zeilennummer),")
    print("        `rmdir /s /q` und `2>/dev/null` (Shell-Fragmente).")
    print("        `classify_path` ist fuer CLAUDE.md gebaut, nicht fuer Regeldateien")
    print("        voller Code-Zitate. Eine Liste, die zu 100 Prozent Fehlalarm ist, waere")
    print("        schaedlicher als keine — sie schluege vor, gueltige Verweise zu")
    print("        loeschen. Der Weg steht in werkzeuge-zuerst.md: den Fall als")
    print("        Prueffall ZUM ORIGINAL geben und das Original erweitern.")
    for p, was in unlesbar:
        # ⛔ Ein unlesbarer Lauf ist NICHT MESSBAR, nicht "sauber" — der wird gemeldet.
        print("       %-30s ⛔ NICHT MESSBAR: %s" % (_nm(p)[:30], was))

    # ---------------------------------------------------------------- L5
    # ⛔ Diese Pruefung sieht KEINE andere: `ablagen()` vergleicht Ablagen
    #    GEGENEINANDER. Eine Datei, die dieselbe Sache viermal sagt, ist dort
    #    unauffaellig — sie ist ja nur EINE Ablage.
    # ⚠ Steht bewusst ganz am ENDE. tests/test_audit.sh haengt an der
    #    Reihenfolge (Gruppe 5 vor Gruppe 1) und an einem sed-Bereich von
    #    "5b ·" bis "1 ·"; ein Abschnitt dazwischen braeche beides.
    wdh = []
    for p in ds:
        try:
            wdh.extend(dup.wiederholung_in_datei(p))
        except (OSError, ValueError):
            continue
    if wdh:
        print()
        print("  " + "=" * 84)
        print("  WIEDERHOLUNG INNERHALB EINER DATEI — Vorschlag: SCHNITT (%d)" % len(wdh))
        print("  " + "=" * 84)
        print("     ⚠ KEIN Fehler und NICHT in der Befundzahl. Eine Datei mit")
        print("       Versionsabschnitten SOLL dieselbe Sache mehrfach nennen —")
        print("       jede Nennung gehoert zu ihrer Version. Was fehlt, ist die")
        print("       Trennung zwischen 'gilt heute' und 'galt damals'.")
        print("       ⛔ Wer hier dedupliziert, loescht Historie.")
        for b in wdh[:10]:
            print("     %-28s %dx, Zeilen %s"
                  % (os.path.basename(b["datei"])[:28], b["anzahl"],
                     ", ".join(str(z) for z in b["zeilen"])))
            print("       Kern: %s" % ", ".join(b["geteilt"][:6]))
            if b["nimmt_zurueck"]:
                print("       ⭐ eine der Stellen nimmt eine andere ausdruecklich")
                print("          zurueck — genau das verdient einen Schnitt")
        if len(wdh) > 10:
            print("     ... und %d weitere (nicht gelistet)" % (len(wdh) - 10))
        print("     ⚠ GRENZE: gefunden werden Wiederholungen BENANNTER Dinge")
        print("       (Dateien, Variablen, Pfade). Eine wiederholte Zahlen- oder")
        print("       Prosakaskade findet das NICHT — die Marken dafuer gibt es nicht.")

    print()
    print("  " + "=" * 84)
    print("  NICHT GEPRUEFT — und das gehoert in jeden Bericht")
    print("  " + "=" * 84)
    print("     · ob eine nie verletzte Urteils-Regel ueberfluessig ist (dauerhaft offen)")
    print("     · welche Seite eines Widerspruchs recht hat")
    print("     · ob der Code dasselbe sagt wie die Regel (er sagt WAS, sie oft WARUM)")
    print("     · ob eine Regel FEHLT — ein Audit sieht nur, was da ist")
    print("     · ob eine Regel nur eine Schwaeche AELTERER Modelle behebt —")
    print("       ableitbar, aber die Debug-Daten liegen alle NACH dem letzten")
    print("       Modellwechsel (142 von 142). Trennschaerfe heute: null.")
    if idx is None:
        print("     · ⛔ KEIN Verstoss-Protokoll erreichbar — alle Belege sind leer,")
        print("          und das ist KEIN 'nichts gefunden'")
    print()
    print("  Naechster Schritt: --plan (erst nach deinem OK).")
    befunde = sum(len(gruppen[k]) for k in ("2", "3", "4")) + len(grenzfaelle) \
        + len([x for x in gruppen["7"] if x[1] not in ("BLEIBT", "PLUGIN")]) + len(gruppen["8"])
    # v5.110.0 (Etappe 19): cleaner_plan.py baut aus den Gruppen den Plan — sie bleiben
    #    nach dem Lauf lesbar, statt nur gedruckt zu sein.
    global LETZTE_GRUPPEN
    LETZTE_GRUPPEN = gruppen
    return 1 if befunde else 0


def selbsttest():
    import tempfile
    d = tempfile.mkdtemp()
    fehler = 0

    def pruef(name, ist, soll):
        nonlocal fehler
        ok = ist == soll
        if not ok:
            fehler += 1
        print("    %-4s %-48s ist=%-9s soll=%s"
              % ("OK" if ok else "FEHL", name, ist, soll))

    print("=" * 78)
    print("  Selbsttest — der Audit-Lauf")
    print("=" * 78)

    proj = os.path.join(d, "leer")
    os.makedirs(proj)
    pruef("leerer Bestand -> Rueckgabe 2 (nicht messbar)",
          lauf(proj, "projekt"), 2)

    # v5.107.0: das Memory ist Bestand — ueber den Slug, nie ueber den Projektpfad.
    _alt = dup._memory_dir
    mem = os.path.join(d, "memory"); os.makedirs(mem)
    open(os.path.join(mem, "MEMORY.md"), "w").write("# Index\n")
    open(os.path.join(mem, "topic-a.md"), "w").write("---\nname: a\ndescription: x\n---\nAussage A.\n")
    p2 = os.path.join(d, "p2"); os.makedirs(os.path.join(p2, ".claude", "rules"))
    open(os.path.join(p2, "wurzel-notiz.md"), "w").write("# keine Memory-Datei\n")
    open(os.path.join(p2, ".claude", "rules", "r.md"), "w").write("# r\n")
    try:
        dup._memory_dir = lambda heim, projekt=None: mem
        ds_m = dateien(p2, "memory")
        pruef("--nur memory: nur die Topic-Datei, nicht MEMORY.md, nicht die Wurzel-.md",
              [os.path.basename(x) for x in ds_m], ["topic-a.md"])
        pruef("Anzeige heisst memory/<name>", _nm(ds_m[0]), "memory/topic-a.md")
        pruef("--nur projekt: Rules UND Memory",
              sorted(os.path.basename(x) for x in dateien(p2, "projekt")), ["r.md", "topic-a.md"])
        pruef("--nur global: kein Memory",
              any("topic-a" in x for x in dateien(p2, "global")), False)
        dup._memory_dir = lambda heim, projekt=None: ""
        pruef("ohne Memory-Verzeichnis: --nur memory findet nichts (kein Absturz)",
              dateien(p2, "memory"), [])
    finally:
        dup._memory_dir = _alt

    # v5.111.0 §1/§3: Roster-Unterordner und CLAUDE.local.md im Bestand
    p3 = os.path.join(d, "p3"); os.makedirs(os.path.join(p3, ".claude", "rules"))
    os.makedirs(os.path.join(p3, "Idee", ".claude", "rules"))
    open(os.path.join(p3, "CLAUDE.md"), "w").write("# w\n")
    open(os.path.join(p3, ".claude", "CLAUDE.md"), "w").write("# w2\n")
    open(os.path.join(p3, "CLAUDE.local.md"), "w").write("# lokal\n")
    open(os.path.join(p3, ".claude", "rules", "rollen.md"), "w", encoding="utf-8").write(
        "| Rolle | Name | sessionId | Tut | Ordner |\n|---|---|---|---|---|\n| m | B | x | l | `./` |\n| a | F | o | i | `Idee/` |\n")
    open(os.path.join(p3, "Idee", "CLAUDE.md"), "w").write("# idee\n")
    open(os.path.join(p3, "Idee", ".claude", "rules", "i1.md"), "w").write("# i1\n")
    _alt2 = dup._memory_dir
    try:
        dup._memory_dir = lambda heim, projekt=None: ""
        ds3 = dateien(p3, "projekt")
        namen3 = sorted(_nm(x) for x in ds3)
        pruef("alle drei CLAUDE-Varianten der Wurzel im Bestand",
              all(x in namen3 for x in ("CLAUDE.md", "CLAUDE.local.md")) and len([x for x in namen3 if x == "CLAUDE.md"]) == 2, True)
        pruef("Roster-Unterordner: Idee/CLAUDE.md und Idee/i1.md dabei, mit Ordner angezeigt",
              ("Idee/CLAUDE.md" in namen3) and ("Idee/i1.md" in namen3), True)
    finally:
        dup._memory_dir = _alt2
    # v5.111.0 §2: Skills-Bestand
    sk = os.path.join(d, "skills"); rl = os.path.join(d, "rules"); os.makedirs(rl)
    for n, desc in (("gut", "ALWAYS invoke this skill when working on X. Nutze das bei allem, was X braucht."),
                    ("weich", "Hilft bei Dingen rund um Y."),
                    ("lang", "ALWAYS " + "v13 bis v34 Aenderung " * 40),
                    ("leer", "")):
        os.makedirs(os.path.join(sk, n))
        open(os.path.join(sk, n, "SKILL.md"), "w", encoding="utf-8").write(
            ("---\nname: %s\ndescription: %s\n---\n# %s\n" % (n, desc, n)) if desc else ("---\nname: %s\n---\n# %s\n" % (n, n)))
    open(os.path.join(rl, "kurz.md"), "w", encoding="utf-8").write("# K\n\nVolltext: `~/.claude/skills/gut/SKILL.md`, Command `/gut`.\n")
    pj = os.path.join(d, "projects", "x"); os.makedirs(pj)
    open(os.path.join(pj, "s.jsonl"), "w", encoding="utf-8").write('{"content":"<command-name>/gut</command-name>"}\n')
    b = {os.path.basename(os.path.dirname(p)): u for p, u, g in skills_bestand(d, sk, rl, projects_dir=os.path.join(d, "projects")) if u != "DOPPELT"}
    pruef("Skills: gut -> BLEIBT", b.get("gut"), "BLEIBT")
    pruef("Skills: weich -> ZU WEICH", b.get("weich"), "ZU WEICH")
    pruef("Skills: lang -> ZU LANG", b.get("lang"), "ZU LANG")
    pruef("Skills: ohne description -> ZURUECK IN RULE", b.get("leer"), "ZURUECK IN RULE")
    # ein direktiver Skill ohne Zeiger und ohne Aufruf -> TOT-VERDACHT
    os.makedirs(os.path.join(sk, "tot"))
    open(os.path.join(sk, "tot", "SKILL.md"), "w", encoding="utf-8").write("---\nname: tot\ndescription: ALWAYS invoke when Z. Nutze das bei Z.\n---\n# tot\n")
    b = {os.path.basename(os.path.dirname(p)): u for p, u, g in skills_bestand(d, sk, rl, projects_dir=os.path.join(d, "projects")) if u != "DOPPELT"}
    pruef("Skills: direktiv, kein Zeiger, kein Aufruf -> TOT-VERDACHT", b.get("tot"), "TOT-VERDACHT")
    # v5.111.0 §4: tote Regler
    st = os.path.join(d, "settings.json")
    open(st, "w", encoding="utf-8").write('{"env": {"MIND_TOT": "1", "MIND_LEBT": "2", "ANDERE": "3"}}')
    lw = os.path.join(d, "leser"); os.makedirs(lw)
    open(os.path.join(lw, "h.sh"), "w", encoding="utf-8").write('x="${MIND_LEBT:-5}"\n# MIND_TOT steht hier nur in Prosa\n')
    tr = [k for k, v, g in tote_regler(st, [lw])]
    pruef("tote Regler: MIND_TOT gemeldet, MIND_LEBT nicht, ANDERE ignoriert", tr, ["MIND_TOT"])

    # ⛔ Die Gegenprobe: alle sechs Werkzeuge muessen erreichbar sein.
    #    Ein Audit, das eines nicht laden kann, meldet stillschweigend weniger.
    for m in (dup, ein, bel, aus, gre, urt):
        pruef("Werkzeug erreichbar: %s" % m.__name__.replace("cleaner_", ""),
              hasattr(m, "__file__"), True)

    print("\n=== %d Abweichung(en) ===" % fehler)
    return 3 if fehler else 0


def main():
    argv = sys.argv[1:]
    if "--selbsttest" in argv:
        return selbsttest()

    def hol(f):
        return argv[argv.index(f) + 1] if f in argv and len(argv) > argv.index(f) + 1 else None

    projekt = hol("--bereich") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    nur = hol("--nur") or "alles"
    if nur not in ("global", "projekt", "alles", "memory"):
        print("--nur braucht global|projekt|alles|memory")
        return 2
    doku = None
    if "--doku" in sys.argv:
        _i = sys.argv.index("--doku")
        doku = sys.argv[_i + 1] if _i + 1 < len(sys.argv) else None
    return lauf(projekt, nur, doku)
if __name__ == "__main__":
    sys.exit(main())
