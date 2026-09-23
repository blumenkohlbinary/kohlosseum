#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""cleaner_plan.py — EIN Plan ueber mehrere Dateien, EIN OK (v5.110.0, Etappe 19).

Nutzer 14.09.2026, woertlich: "ja mach einen plan ueber mehrere dateien und auch mind memory
muss das gefixt werden mit einem ok" — das ersetzt "GENAU EINE Datei je Umzug" (24.08.2026);
die 73 liegengebliebenen Audit-Befunde vom 25.08. waren der Preis. (/mind-memory bleibt
autonom, Nutzer 15.09.: das ok gehoert NUR zum Cleaner.)

  --neu <projekt> [--nur global|projekt|alles|memory] [--plan <pfad>]
      faehrt cleaner_audit und schreibt ALLE Befunde in EINE Plandatei
      ($MIND_DEBUG_DIR/laeufe/<ts>_plan.md, sonst <projekt>/.claude-mind/): je Zeile
      Nr · Klasse · Datei · Ziel · Gates · Rueckweg · Status. Reihenfolge so, dass kein
      Schritt einen spaeteren bricht: ARCHIV, REBUILD, UMZUG/DOCS (Zeiger nach dem Umzug),
      PATHS; MELDUNG/ZEIGER-Zeilen haben keine Aktion.
  --anwenden <plan> [--ohne 3,7]
      das eine ok: gemeinsamer Snapshot davor (.claude-mind/snapshots/<ts>_pre-cleaner-plan,
      Zweige wie mind_snapshot, rollback.py spielt ihn zurueck), dann Zeile fuer Zeile mit den
      bestehenden Gates (cleaner_rebuild, cleaner_umzug, cleaner_ratsche, cleaner_paths_sonde).
      ⛔ Bricht EIN Gate, stoppt der Lauf: alles davor bleibt, alles danach bleibt
      NICHT ANGEWENDET, der Plan traegt je Zeile den Status und der Bericht nennt die Zeile.
      "ok ohne 3,7" = --ohne 3,7 (gestrichen). Danach --audit erneut, wie nach jedem Umzug.

Zeilenform fuer UMZUG/DOCS: das Ziel traegt `kurz=<pfad>` — die vorbereitete Kurz-Rule,
die die Sitzung geschrieben hat; der Treiber prueft die Gates und setzt sie erst dann ein.
"""
import hashlib
import io
import os
import re
import shutil
import sys
import time

_HIER = os.path.dirname(os.path.abspath(__file__))
if _HIER not in sys.path:
    sys.path.insert(0, _HIER)
import cleaner_audit as audit           # noqa: E402
import cleaner_rebuild as reb           # noqa: E402
import cleaner_umzug as umz             # noqa: E402
import cleaner_ratsche as rat           # noqa: E402

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

REIHE = {"ARCHIV": 0, "REBUILD": 1, "UMZUG": 2, "DOCS": 2, "PATHS": 3, "ZEIGER": 4, "MELDUNG": 5}
KOPF = "| # | Klasse | Datei | Ziel | Gates | Rueckweg | Status |\n|---|---|---|---|---|---|---|\n"


def _rel(p, projekt):
    try:
        return os.path.relpath(p, projekt).replace("\\", "/")
    except ValueError:
        return p.replace("\\", "/")


def docs_ziel(projekt):
    """⛔ v5.112.0 (§5): das DOCS-Ziel wird je Projekt abgeleitet — vorhandener Doku-Ordner
    `docs/`, sonst `knowledge/`, sonst `doc/`; fehlt jeder: `docs/` (anlegen, im Bericht
    genannt). Kein Projektname, keine Liste — nur das, was da ist."""
    for k in ("docs", "knowledge", "doc"):
        if os.path.isdir(os.path.join(projekt, k)):
            return k, False
    return "docs", True


ANLAGE = []   # v5.115.0: (abschnitt, dateipaar, [marken]) — von zeilen_aus_gruppen gefuellt, von neu() geschrieben


def anlage_pfad(plan):
    return plan[:-3] + ".anlage.md" if plan.endswith(".md") else plan + ".anlage.md"


def zeilen_aus_gruppen(gruppen, projekt):
    """Planzeilen aus den Audit-Gruppen 2 (falsch platziert), 3 (doppelt), 4 (veraltet)."""
    z = []
    for p, txt in gruppen.get("2", []):
        kl = txt.split(" ", 1)[0].strip(":")
        if kl == "DOCS":
            ordner, anlegen = docs_ziel(projekt)
            z.append(("DOCS", p, "%s/%s%s (kurz=<vorbereitete Kurz-Rule>)"
                      % (ordner, os.path.basename(p), " — Ordner anlegen" if anlegen else ""),
                      "ERHALTUNG ENTLASTUNG PFAD INHALT ZEIGER", "Snapshot"))
        elif kl == "COMMAND":
            z.append(("UMZUG", p, "~/.claude/skills/%s/SKILL.md (kurz=<vorbereitete Kurz-Rule>)"
                      % os.path.splitext(os.path.basename(p))[0],
                      "ERHALTUNG ENTLASTUNG ERREICHBARKEIT PFAD DOPPELZEIGER INHALT BESCHREIBUNG", "Snapshot"))
        elif kl == "RULE-PATHS":
            z.append(("PATHS", p, "paths: setzen, Ladung messen (cleaner_paths_sonde)", "Sonde --start", "Sicherung der Sonde"))
        elif kl == "HOOK-KANDIDAT":
            z.append(("MELDUNG", p, "Hook-Kandidat — nur melden (Nutzer 24.08.2026), --hook-bauen auf Ansage", "-", "-"))
        else:
            z.append(("MELDUNG", p, txt[:80], "-", "-"))
    # ⛔ v5.115.0 (Etappe 23 §5, Veras Zustellplan-Plan: 1 823 Zeilen, 1 796 davon ZEIGER):
    #    je DATEIPAAR eine Zeile („n doppelte Marken zwischen a + b"), die Marken selbst in
    #    die Anlage <plan>.anlage.md (Abschnitt je Paar). Der Plan bleibt lesbar.
    paare = {}
    for a, b in gruppen.get("3", []):
        paare.setdefault(str(b), []).append(str(a))
    for k, (b, marken) in enumerate(sorted(paare.items()), 1):
        if b.startswith("⛔ ZAHLENDRIFT"):
            # v5.120.0 (Etappe 29 §1): die Drift-Zeile traegt beide Fundstellen IM PLAN —
            # <datei>:<zeile> „satz" ↔ <datei>:<zeile> „satz" (die Marke aus dem Audit)
            z.append(("ZEIGER", b[:80], "ZAHLENDRIFT %s; Anlage Abschnitt %d" % ("; ".join(marken), k), "-", "-"))
        else:
            z.append(("ZEIGER", b[:80], "%d doppelte Marke(n) — eine Stelle wird Zeiger (von Hand, Stufe 3); Anlage Abschnitt %d"
                      % (len(marken), k), "-", "-"))
    ANLAGE[:] = [(k, b, marken) for k, (b, marken) in enumerate(sorted(paare.items()), 1)]
    for p, g in gruppen.get("4", []):
        z.append(("ARCHIV", p, ".claude/archiv/ (cleaner_ratsche --archiviere)", "Ratsche: Grund Pflicht", "Snapshot / --entarchiviere"))
    for p, g in gruppen.get("9", []):   # v5.117.0: unantastbar — nur Meldung
        z.append(("MELDUNG", p, g[:100], "-", "-"))
    z.sort(key=lambda x: REIHE.get(x[0], 9))
    return z


def neu(projekt, nur="alles", plan=None):
    audit.lauf(projekt, nur)
    gruppen = audit.LETZTE_GRUPPEN or {}
    z = zeilen_aus_gruppen(gruppen, projekt)
    if not plan:
        d = os.environ.get("MIND_DEBUG_DIR")
        d = os.path.join(d, "laeufe") if d and os.path.isdir(d) else os.path.join(projekt, ".claude-mind")
        os.makedirs(d, exist_ok=True)
        plan = os.path.join(d, time.strftime("%Y-%m-%d_%H%M") + "_plan.md")
    return schreibe_plan(plan, z, projekt, nur)


def schreibe_plan(plan, z, projekt, nur="alles"):
    """Plandatei (+ Anlage fuer die ZEIGER-Marken, v5.115.0) schreiben. rc 0 mit Zeilen, sonst 1."""
    with open(plan, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Cleaner-Plan %s — %s (--nur %s)\n\n" % (time.strftime("%Y-%m-%d %H:%M"), projekt, nur))
        fh.write("EIN ok wendet ALLE Zeilen an (`--anwenden <plan>`); streichen mit `--ohne 3,7`.\n")
        fh.write("Gemeinsamer Snapshot davor; bricht ein Gate, stoppt der Lauf an dieser Zeile.\n\n")
        fh.write(KOPF)
        for i, (kl, p, ziel, gates, rueck) in enumerate(z, 1):
            fh.write("| %d | %s | %s | %s | %s | %s | offen |\n" % (i, kl, _rel(p, projekt), ziel, gates, rueck))
        if not z:
            fh.write("| - | - | (keine Befunde in den Gruppen 2-4) | - | - | - | - |\n")
        if ANLAGE:
            fh.write("\nAnlage (die einzelnen doppelten Marken je Dateipaar): `%s`\n" % os.path.basename(anlage_pfad(plan)))
    if ANLAGE:
        with open(anlage_pfad(plan), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("# Anlage zum Cleaner-Plan %s — doppelte Marken je Dateipaar\n\n" % os.path.basename(plan))
            for k, b, marken in ANLAGE:
                fh.write("## %d · %s (%d)\n\n" % (k, b, len(marken)))
                for m in marken:
                    fh.write("- %s\n" % m)
                fh.write("\n")
    print("Plan: %s  (%d Zeile(n)%s)" % (plan, len(z),
                                         (", Anlage %d Abschnitt(e) mit %d Marke(n)" % (len(ANLAGE), sum(len(m) for _, _, m in ANLAGE))) if ANLAGE else ""))
    return 0 if z else 1


def lies_plan(plan):
    z = []
    for line in open(plan, encoding="utf-8", errors="replace"):
        m = re.match(r"^\|\s*(\d+)\s*\|\s*([A-Z]+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$", line.rstrip("\n"))
        if m:
            z.append({"nr": int(m.group(1)), "klasse": m.group(2), "datei": m.group(3), "ziel": m.group(4),
                      "gates": m.group(5), "rueckweg": m.group(6), "status": m.group(7)})
    return z


def status_setzen(plan, nr, status):
    t = open(plan, encoding="utf-8", errors="replace").read()
    t = re.sub(r"^(\|\s*%d\s*\|(?:[^|]*\|){5})[^|]*\|\s*$" % nr, lambda m: m.group(1) + " %s |" % status, t, flags=re.M)
    open(plan, "w", encoding="utf-8", newline="\n").write(t)


def _projekt_aus(plan):
    m = re.search(r"^# Cleaner-Plan .*? — (.+?) \(--nur", open(plan, encoding="utf-8", errors="replace").readline())
    return m.group(1) if m else os.getcwd()


def snapshot(projekt, dateien):
    """Ein gemeinsamer Snapshot in den Zweigen von mind_snapshot — rollback.py spielt ihn zurueck."""
    snap = os.path.join(projekt, ".claude-mind", "snapshots", time.strftime("%Y%m%d_%H%M%S") + "_pre-cleaner-plan")
    os.makedirs(snap, exist_ok=True)
    zeilen = []
    for d in dateien:
        if not os.path.isfile(d):
            continue
        rel = _rel(d, projekt)
        if rel.startswith(".claude/rules/"):
            ziel = os.path.join(snap, "rules", rel[len(".claude/rules/"):])
        elif rel == "CLAUDE.md":
            ziel = os.path.join(snap, "CLAUDE.md")
        elif "/.claude/projects/" in d.replace("\\", "/") and "/memory/" in d.replace("\\", "/"):
            ziel = os.path.join(snap, "memory", os.path.basename(d))
        elif rel.startswith(".."):
            ziel = os.path.join(snap, "ausserhalb", os.path.basename(d))
        else:
            ziel = os.path.join(snap, "project", rel)
        os.makedirs(os.path.dirname(ziel), exist_ok=True)
        shutil.copy2(d, ziel)
        h = hashlib.sha256(open(ziel, "rb").read()).hexdigest()
        zeilen.append("%s  ./%s" % (h, os.path.relpath(ziel, snap).replace("\\", "/")))
    with open(os.path.join(snap, "MANIFEST.sha256"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# cleaner_plan Snapshot  ts=%s  project=%s  files=%d\n" % (time.strftime("%Y%m%d_%H%M%S"), projekt, len(zeilen)))
        fh.write("\n".join(zeilen) + ("\n" if zeilen else ""))
    return snap


def _kurz_aus(ziel):
    m = re.search(r"kurz=([^)\s]+)", ziel)
    return m.group(1) if m else None


def _ist_memory_pfad(d):
    n = d.replace("\\", "/")
    return "/.claude/projects/" in n and "/memory/" in n


def _yaml_wert(s):
    """description aus dem Frontmatter: aeussere Anfuehrungszeichen weg, innere Escapes aufgeloest
    (v5.117.0 §0b c: `Routenplaner\\" ` blieb stehen)."""
    s = (s or "").strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        q = s[0]; s = s[1:-1]
        if q == "\"":
            s = s.replace("\\\"", "\"").replace("\\\\", "\\")
        else:
            s = s.replace("''", "'")
    return s.strip()


def alte_indexzeile(idx_text, name):
    """(titel, aufhaenger) der bestehenden Indexzeile `- [Titel](name.md) — Aufhaenger`, sonst (None, None)."""
    m = re.search(r"^[-*]\s*\[([^\]]*)\]\(\s*%s\s*\)\s*(?:[—–-]+\s*(.*))?$" % re.escape(name), idx_text, re.M)
    if not m:
        return None, None
    return m.group(1).strip(), (m.group(2) or "").strip()


def memory_index_zeile(topic_p, docs_p, projekt=None, idx_text=None):
    """Die neue Indexzeile (v5.117.0 §0b): `- [Titel](docs/<name>.md) — <alter Aufhaenger> (umgezogen
    nach docs, lies zuerst dort)`. Pfad PROJEKTRELATIV, der alte Aufhaenger bleibt (description nur,
    wenn der Index keinen hatte), YAML-Escapes aufgeloest, der Zeiger steht EINMAL."""
    t = open(topic_p, encoding="utf-8", errors="replace").read()
    name = os.path.basename(topic_p)
    m = re.search(r"^\s*description:\s*(.+)$", t, re.M)
    desc = _yaml_wert(m.group(1)) if m else ""
    m2 = re.search(r"^#\s+(.+)$", t, re.M)
    titel_alt, auf_alt = alte_indexzeile(idx_text or "", name)
    titel = titel_alt or (m2.group(1).strip() if m2 else os.path.splitext(name)[0])
    auf = auf_alt or desc
    dp = docs_p.replace("\\", "/")
    if projekt:
        try:
            rel = os.path.relpath(docs_p, projekt).replace("\\", "/")
            if not rel.startswith(".."):
                dp = rel
        except ValueError:
            pass
    return "- [%s](%s) — %s(umgezogen nach docs, lies zuerst dort)" % (titel, dp, (auf + " ") if auf else "")


def _schreib_mit_zeilenenden(pfad, text_lf, vorlage_roh):
    """Zeilenenden der Zieldatei beibehalten (v5.117.0 §0b a: MEMORY.md kam mit LF zurueck, 128 Zeilen Diff)."""
    nl = "\r\n" if "\r\n" in vorlage_roh else "\n"
    open(pfad, "w", encoding="utf-8", newline="").write(text_lf.replace("\r\n", "\n").replace("\n", nl))


def reparieren_index(mem_dir, projekt, snapshot=None):
    """`--reparieren-index <memory-dir> --projekt <proj> [--snapshot <dir>]` (v5.117.0 §0b e): zieht
    Indexzeilen der 5.115.0-Form (`- [T](<abs>) — umgezogen nach docs, lies zuerst \`<abs>\`: <desc>`)
    auf die neue Form nach — Pfad relativ, Aufhaenger aus dem Snapshot (snapshot/memory/MEMORY.md
    oder <snapshot>/MEMORY.md), Escapes weg, Zeiger einmal, Zeilenenden wie in der Datei."""
    idx = os.path.join(mem_dir, "MEMORY.md")
    if not os.path.isfile(idx):
        print("⛔ kein MEMORY.md unter %s" % mem_dir)
        return 2
    roh = open(idx, encoding="utf-8", errors="replace", newline="").read()
    alt_idx = ""
    for kand in ((os.path.join(snapshot, "memory", "MEMORY.md"), os.path.join(snapshot, "MEMORY.md")) if snapshot else ()):
        if os.path.isfile(kand):
            alt_idx = open(kand, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
            break
    muster = re.compile(r"^([-*])\s*\[([^\]]*)\]\(([^)]+)\)\s*—\s*umgezogen nach docs, lies zuerst `[^`]*`(?::\s*(.*))?$", re.M)
    n = 0
    def ersetze(m):
        nonlocal n
        n += 1
        titel, ziel, desc = m.group(2).strip(), m.group(3).strip(), (m.group(4) or "").strip()
        name = os.path.basename(ziel)
        t_alt, auf_alt = alte_indexzeile(alt_idx, name)
        auf = auf_alt or _yaml_wert(desc) or desc
        titel = t_alt or titel
        dp = ziel.replace("\\", "/")
        try:
            rel = os.path.relpath(ziel, projekt).replace("\\", "/")
            if not rel.startswith(".."):
                dp = rel
        except ValueError:
            pass
        return "%s [%s](%s) — %s(umgezogen nach docs, lies zuerst dort)" % (m.group(1), titel, dp, (auf + " ") if auf else "")
    neu = muster.sub(ersetze, roh.replace("\r\n", "\n"))
    if n == 0:
        print("  nichts zu reparieren: keine Zeile der 5.115.0-Form in %s" % idx)
        return 1
    _schreib_mit_zeilenenden(idx, neu, roh)
    print("  %d Indexzeile(n) repariert in %s (Aufhaenger aus %s, Zeilenenden %s)"
          % (n, idx, snapshot or "der description", "CRLF" if "\r\n" in roh else "LF"))
    return 0


_WIKI = r"\[\[\s*%s\s*\]\]"


def _docs_rel(docs_p, projekt):
    """docs/<name>.md projektrelativ — wie in der Indexzeile; ohne Projekt die letzten zwei Pfadteile."""
    d = docs_p.replace("\\", "/")
    if projekt:
        try:
            r = os.path.relpath(docs_p, projekt).replace("\\", "/")
            if not r.startswith(".."):
                return r
        except ValueError:
            pass
    return "/".join(d.split("/")[-2:])


def wikilink_traeger(mem_dir, name):
    """v5.121.0 (Etappe 31): alle .md im Memory-Verzeichnis (inkl. MEMORY.md), die `[[name]]` tragen."""
    aus = []
    if not os.path.isdir(mem_dir):
        return aus
    rx = re.compile(_WIKI % re.escape(name))
    for f in sorted(os.listdir(mem_dir)):
        if not f.endswith(".md") or f == name + ".md":
            continue
        p = os.path.join(mem_dir, f)
        try:
            if rx.search(open(p, encoding="utf-8", errors="replace", newline="").read()):
                aus.append(p)
        except OSError:
            pass
    return aus


def wikilinks_umschreiben(mem_dir, name, docs_rel):
    """v5.121.0 (Etappe 31, Otto 17.09.2026: `MEMORY.md:20` zeigte per `[[karten-vereinheitlichung]]`
    weiter auf das nach docs/ umgezogene Thema — fuer die Wikilink-Aufloesung `memory/<name>.md` tot).
    Schreibt `[[name]]` im GANZEN Memory-Verzeichnis inkl. MEMORY.md auf `docs/<name>.md` um
    (Zeilenenden je Datei erhalten). Rueckgabe: [(datei, anzahl)]."""
    rx = re.compile(_WIKI % re.escape(name))
    ersatz = "`%s`" % docs_rel.replace("\\", "/")
    aus = []
    for p in wikilink_traeger(mem_dir, name):
        roh = open(p, encoding="utf-8", errors="replace", newline="").read()
        neu, k = rx.subn(ersatz, roh)
        if k:
            _schreib_mit_zeilenenden(p, neu.replace("\r\n", "\n"), roh)
            aus.append((p, k))
    return aus


def memory_docs_zug(topic_p, docs_p, plan, nr, projekt=None):
    """(ok, warum) — Gates ueber alt=Topic, kurz=Indexzeile, ziel=docs; dann Index umschreiben, Topic weg.
    v5.121.0: danach `[[name]]` im ganzen Memory-Verzeichnis auf docs/<name>.md umschreiben."""
    import tempfile
    idx = os.path.join(os.path.dirname(topic_p), "MEMORY.md")
    roh = open(idx, encoding="utf-8", errors="replace", newline="").read() if os.path.isfile(idx) else "# Memory\n\n"
    zeile = memory_index_zeile(topic_p, docs_p, projekt, roh.replace("\r\n", "\n"))
    tf = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8")
    tf.write(zeile + "\n"); tf.close()
    try:
        gates, fehlt = umz.pruefe(topic_p, tf.name, docs_p, "docs")
    finally:
        os.unlink(tf.name)
    if gates is None:
        return False, "nicht messbar: %s" % ", ".join(fehlt)
    bruch = [n for n, g, _ in gates if not g and n != "ENTLASTUNG"]   # eine Indexzeile ist immer kuerzer
    if bruch:
        return False, "Gate gebrochen: %s" % ", ".join(bruch)
    name = os.path.basename(topic_p)
    alt = roh.replace("\r\n", "\n")
    muster = re.compile(r"^[-*]\s*\[[^\]]*\]\(\s*%s\s*\).*$" % re.escape(name), re.M)
    if muster.search(alt):
        neu = muster.sub(lambda m: zeile, alt, count=1)
    else:
        neu = alt.rstrip("\n") + "\n" + zeile + "\n"
    _schreib_mit_zeilenenden(idx, neu, roh)   # v5.117.0: CRLF bleibt CRLF
    os.remove(topic_p)
    print("     Index: %s -> zeigt auf %s; Topic entfernt (im Snapshot unter memory/)" % (name, docs_p.replace("\\", "/")))
    # v5.121.0 (Etappe 31): Wikilinks auf das Thema sterben mit dem Umzug — umschreiben, nicht liegen lassen.
    docs_rel = _docs_rel(docs_p, projekt)
    for p_w, k in wikilinks_umschreiben(os.path.dirname(topic_p), os.path.splitext(name)[0], docs_rel):
        print("     Wikilink: %s — %d x [[%s]] -> `%s`" % (os.path.basename(p_w), k, os.path.splitext(name)[0], docs_rel))
    # ⛔ v5.132.0 (Etappe 43 §4a): WER UMZIEHT, SUCHT DEN ALTEN NAMEN PROJEKTWEIT.
    #    Dieselbe Wurzel wie der Wikilink-Fall oben (17.09., 7bca190) und wie Veras
    #    Rules-Zeiger (23.09.): der alte Name bleibt irgendwo stehen. Die Suche steht in
    #    `references/namens_suche.py` — EINE Stelle, von beiden Wegen gerufen.
    #    ⚠ NUR MELDEN: CLAUDE.md und die Rules gehoeren nicht diesem Werkzeug.
    try:
        import namens_suche as _ns
        _rest = _ns.fundstellen(projekt, [name], os.path.dirname(topic_p))
    except Exception as _e:
        _rest = None
        print("     ⚠ Namens-Suche nicht gefahren (%s) — der alte Name bleibt UNGEPRUEFT" % _e)
    if _rest:
        print("     ⚠ `%s` wird noch an %d Stelle(n) genannt — nur gemeldet, nichts umgeschrieben:"
              % (name, len(_rest)))
        for _f in _rest[:6]:
            print("        %s" % _f)
    elif _rest is not None:
        print("     Namens-Suche: keine weitere Nennung von `%s` in CLAUDE.md, Rules, MEMORY.md, Topics" % name)
    print("     danach: python Learnings/memory_gates.py <snapshot>/memory --wurzel <projekt>  (Gate 3 liest den docs-Zeiger, v5.117.0)")
    return True, ""


def anwenden(plan, ohne=(), projekt=None):
    projekt = projekt or _projekt_aus(plan)
    z = lies_plan(plan)
    if not z:
        print("⛔ Plan ohne Zeilen: %s" % plan)
        return 2
    aktiv = [x for x in z if x["nr"] not in ohne and x["status"] in ("offen", "NICHT ANGEWENDET")]
    for x in z:
        if x["nr"] in ohne:
            status_setzen(plan, x["nr"], "gestrichen")
    betroffen = []
    for x in aktiv:
        d = x["datei"] if os.path.isabs(x["datei"]) else os.path.join(projekt, x["datei"])
        betroffen.append(d)
        k = _kurz_aus(x["ziel"])
        if k:
            betroffen.append(k if os.path.isabs(k) else os.path.join(projekt, k))
        if x["klasse"] == "DOCS" and _ist_memory_pfad(d):
            # v5.121.0 (Etappe 31): jede Memory-Datei mit [[name]] wird umgeschrieben — Snapshot vorher
            betroffen.extend(wikilink_traeger(os.path.dirname(d), os.path.splitext(os.path.basename(d))[0]))
    snap = snapshot(projekt, betroffen)
    print("=" * 72)
    print("CLEANER-PLAN anwenden — %d Zeile(n), Snapshot %s" % (len(aktiv), snap))
    print("=" * 72)
    rc_gesamt = 0
    for i, x in enumerate(aktiv):
        d = x["datei"] if os.path.isabs(x["datei"]) else os.path.join(projekt, x["datei"])
        kl = x["klasse"]
        ok, warum = True, ""
        # ⛔ v5.117.0 (§0a): die Unantastbar-Liste gilt auch fuer einen von Hand geschriebenen Plan
        _u = audit.ist_unantastbar(d) if kl in ("ARCHIV", "UMZUG", "DOCS", "REBUILD") else ""
        if _u:
            status_setzen(plan, x["nr"], "GEBROCHEN: unantastbar (%s)" % _u)
            print("  %2d %-8s %s — ⛔ unantastbar: %s" % (x["nr"], kl, x["datei"], _u))
            for y in aktiv[i + 1:]:
                status_setzen(plan, y["nr"], "NICHT ANGEWENDET")
            rc_gesamt = 1
            break
        if kl in ("MELDUNG", "ZEIGER"):
            status_setzen(plan, x["nr"], "nur gemeldet")
            print("  %2d %-8s %s — keine Aktion" % (x["nr"], kl, x["datei"]))
            continue
        if kl == "ARCHIV":
            e = rat.archiviere(projekt, d, "Cleaner-Plan %s Zeile %d" % (os.path.basename(plan), x["nr"]))
            ok, warum = e is not None, "" if e else "Ratsche: Datei nicht lesbar"
        elif kl == "REBUILD":
            rc = reb.rebuild(projekt, d, auto=True, anwenden=True)
            ok, warum = rc != 2, "" if rc != 2 else "Rebuild: Gate gebrochen (rc 2)"
        elif kl == "DOCS" and _ist_memory_pfad(d):
            # ⛔ v5.115.0 (Etappe 23 §8, Otto/Vera): bis 5.114.0 blieb nach dem DOCS-Zug ein STUB
            #    in memory/ und MEMORY.md blieb unangetastet — die Themenzahl sank nicht, der
            #    Memory-Deckel blieb rot, Zustellplan stellte fuenf Zuege zurueck. Jetzt: die
            #    Indexzeile zeigt direkt auf docs/<name>.md, kein Stub, das Topic ist weg
            #    (Snapshot haelt es unter memory/); die Zeile ist zugleich die Kurz-Fassung fuer
            #    die Gates (PFAD, ZEIGER, INHALT). Danach: Learnings/memory_gates.py auf den
            #    Snapshot — Gate 3 liest den docs-Zeiger seit v5.115.0 als gueltig.
            zielp = x["ziel"].split(" (")[0].strip()
            zielp = os.path.expanduser(zielp)
            if not zielp.startswith(("/", "~")) and not os.path.isabs(zielp):
                zielp = os.path.join(projekt, zielp)
            if not os.path.isfile(zielp):
                ok, warum = False, "Ziel %s fehlt (Sitzung muss die docs-Datei vorbereiten)" % x["ziel"].split(" (")[0]
            else:
                ok, warum = memory_docs_zug(d, zielp, plan, x["nr"], projekt)
        elif kl in ("UMZUG", "DOCS"):
            k = _kurz_aus(x["ziel"])
            zielp = x["ziel"].split(" (")[0].strip()
            zielp = os.path.expanduser(zielp)
            if not zielp.startswith(("/", "~")) and not os.path.isabs(zielp):
                zielp = os.path.join(projekt, zielp)
            kp = (k if os.path.isabs(k) else os.path.join(projekt, k)) if k else None
            if not kp or not os.path.isfile(kp) or not os.path.isfile(zielp):
                ok, warum = False, "kurz= oder Ziel fehlt (Sitzung muss beide vorbereiten)"
            else:
                gates, fehlt = umz.pruefe(d, kp, zielp, "docs" if kl == "DOCS" else "skill")
                if gates is None:
                    ok, warum = False, "nicht messbar: %s" % ", ".join(fehlt)
                else:
                    bruch = [n for n, g, _ in gates if not g]
                    ok, warum = not bruch, ("Gate gebrochen: %s" % ", ".join(bruch)) if bruch else ""
                    if ok:
                        shutil.copy2(kp, d)
        elif kl == "PATHS":
            import cleaner_paths_sonde as sonde
            rc = sonde.start(projekt, d)
            ok, warum = rc == 0, "" if rc == 0 else "Sonde: rc %d" % rc
        else:
            ok, warum = False, "unbekannte Klasse %s" % kl
        if ok:
            status_setzen(plan, x["nr"], "angewendet")
            print("  %2d %-8s %s — angewendet" % (x["nr"], kl, x["datei"]))
        else:
            status_setzen(plan, x["nr"], "GEBROCHEN: %s" % warum)
            print("  %2d %-8s %s — ⛔ %s" % (x["nr"], kl, x["datei"], warum))
            for y in aktiv[i + 1:]:
                status_setzen(plan, y["nr"], "NICHT ANGEWENDET")
            print("  ⛔ STOPP an Zeile %d. Zeilen davor bleiben, Zeilen danach NICHT ANGEWENDET. Rueckweg: rollback.py restore %s"
                  % (x["nr"], os.path.basename(snap)))
            rc_gesamt = 1
            break
    print("  Plan aktualisiert: %s" % plan)
    print("  Danach: --audit erneut (Pflicht nach jedem Umzug).")
    return rc_gesamt


def selbsttest():
    import tempfile
    fehler = 0

    def pruef(name, ist, soll):
        nonlocal fehler
        ok = ist == soll
        fehler += 0 if ok else 1
        print("  %-4s %-58s ist=%s soll=%s" % ("OK" if ok else "FEHL", name, ist, soll))

    print("=" * 72); print("  Selbsttest — ein Plan, ein ok, Stopp am gebrochenen Gate"); print("=" * 72)
    d = tempfile.mkdtemp(); proj = os.path.join(d, "p"); rd = os.path.join(proj, ".claude", "rules")
    os.makedirs(rd); os.makedirs(os.path.join(proj, "docs")); os.makedirs(os.path.join(proj, ".claude-mind"))
    alt1 = os.path.join(rd, "alt1.md"); open(alt1, "w", encoding="utf-8").write("# Alt1\n\nAussage eins, 42 Zeilen.\n")
    alt2 = os.path.join(rd, "alt2.md"); open(alt2, "w", encoding="utf-8").write("# Alt2\n\nAussage zwei, `werk.py`.\n")
    alt3 = os.path.join(rd, "alt3.md"); open(alt3, "w", encoding="utf-8").write("# Alt3\n\nDie Zahl 7 Tage gilt.\n\nEine lange Herleitung, die nur erklaert und im Dauerkontext nichts verloren hat.\n")
    alt4 = os.path.join(rd, "alt4.md"); open(alt4, "w", encoding="utf-8").write("# Alt4\n\nVier.\n")
    docs3 = os.path.join(proj, "docs", "alt3.md"); open(docs3, "w", encoding="utf-8").write("# Wissen\n\nDie Zahl 7 Tage gilt.\n\nEine lange Herleitung, die nur erklaert und im Dauerkontext nichts verloren hat.\n")
    kurz3 = os.path.join(proj, ".claude-mind", "kurz3.md"); open(kurz3, "w", encoding="utf-8").write("---\ndescription: k\n---\n# K\n\nSiehe `docs/alt3.md`.\n")   # KEIN direktiver Zeiger -> ZEIGER bricht
    plan = os.path.join(d, "plan.md")
    with open(plan, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Cleaner-Plan test — %s (--nur projekt)\n\n%s" % (proj, KOPF))
        fh.write("| 1 | ARCHIV | .claude/rules/alt1.md | .claude/archiv/ | Ratsche | Snapshot | offen |\n")
        fh.write("| 2 | ARCHIV | .claude/rules/alt2.md | .claude/archiv/ | Ratsche | Snapshot | offen |\n")
        fh.write("| 3 | DOCS | .claude/rules/alt3.md | docs/alt3.md (kurz=.claude-mind/kurz3.md) | ZEIGER | Snapshot | offen |\n")
        fh.write("| 4 | ARCHIV | .claude/rules/alt4.md | .claude/archiv/ | Ratsche | Snapshot | offen |\n")
    pruef("Plan gelesen: 4 Zeilen", len(lies_plan(plan)), 4)
    vor3 = open(alt3, encoding="utf-8").read()
    rc = anwenden(plan, projekt=proj)
    st = {x["nr"]: x["status"] for x in lies_plan(plan)}
    pruef("Rueckgabe 1 (ein Gate gebrochen)", rc, 1)
    pruef("Zeile 1 und 2 angewendet", (st[1], st[2]), ("angewendet", "angewendet"))
    pruef("Zeile 3 GEBROCHEN mit Gate-Namen", st[3].startswith("GEBROCHEN") and "ZEIGER" in st[3], True)
    pruef("Zeile 4 NICHT ANGEWENDET", st[4], "NICHT ANGEWENDET")
    pruef("alt3 unveraendert (Gate hielt die Hand fest)", open(alt3, encoding="utf-8").read() == vor3, True)
    pruef("alt4 liegt noch (nicht archiviert)", os.path.isfile(alt4), True)
    snaps = os.listdir(os.path.join(proj, ".claude-mind", "snapshots"))
    pruef("ein gemeinsamer Snapshot pre-cleaner-plan", len([s for s in snaps if s.endswith("_pre-cleaner-plan")]), 1)
    s = os.path.join(proj, ".claude-mind", "snapshots", [x for x in snaps if x.endswith("_pre-cleaner-plan")][0])
    pruef("Snapshot traegt alle vier Rules unter rules/", sorted(os.listdir(os.path.join(s, "rules"))), ["alt1.md", "alt2.md", "alt3.md", "alt4.md"])
    pruef("   ... und die Kurz-Rule unter project/", os.path.isfile(os.path.join(s, "project", ".claude-mind", "kurz3.md")), True)
    # --ohne: Zeile 3 gestrichen -> Zeile 4 laeuft durch
    with open(plan, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Cleaner-Plan test — %s (--nur projekt)\n\n%s" % (proj, KOPF))
        fh.write("| 3 | DOCS | .claude/rules/alt3.md | docs/alt3.md (kurz=.claude-mind/kurz3.md) | ZEIGER | Snapshot | offen |\n")
        fh.write("| 4 | ARCHIV | .claude/rules/alt4.md | .claude/archiv/ | Ratsche | Snapshot | offen |\n")
    rc = anwenden(plan, ohne=(3,), projekt=proj)
    st = {x["nr"]: x["status"] for x in lies_plan(plan)}
    pruef("--ohne 3: Zeile 3 gestrichen, Zeile 4 angewendet, rc 0", (rc, st[3], st[4]), (0, "gestrichen", "angewendet"))
    # --neu aus einem Audit: schreibt eine Plandatei
    p2 = os.path.join(d, "p2"); os.makedirs(os.path.join(p2, ".claude", "rules")); os.makedirs(os.path.join(p2, ".claude-mind"))
    open(os.path.join(p2, ".claude", "rules", "nachschlag.md"), "w", encoding="utf-8").write(
        "# Zeitungen\n\nDas Gebiet hat drei Zeitungen.\n\nDie erste erscheint werktags.\n\nDie zweite am Wochenende.\n\nDie dritte monatlich.\n\nDie Strassen stehen in der Karte.\n")
    pl = os.path.join(d, "neu_plan.md")
    os.environ.pop("MIND_DEBUG_DIR", None)
    neu(p2, "projekt", pl)
    t = open(pl, encoding="utf-8").read()
    pruef("--neu: Plandatei mit Kopf und DOCS-Zeile", ("| DOCS |" in t) and t.startswith("# Cleaner-Plan"), True)
    pruef("   ohne Doku-Ordner: Ziel docs/ mit 'Ordner anlegen'", "docs/nachschlag.md — Ordner anlegen" in t, True)
    os.makedirs(os.path.join(p2, "knowledge"))
    neu(p2, "projekt", pl)
    t = open(pl, encoding="utf-8").read()
    pruef("   mit knowledge/: Ziel knowledge/, nichts anlegen", ("knowledge/nachschlag.md" in t) and ("Ordner anlegen" not in t), True)
    print("\n=== %d Abweichung(en) ===" % fehler)
    return 3 if fehler else 0


def main(argv=None):
    a = list(sys.argv[1:] if argv is None else argv)
    if "--selbsttest" in a:
        return selbsttest()

    def hol(f):
        return a[a.index(f) + 1] if f in a and a.index(f) + 1 < len(a) else None
    if "--neu" in a:
        return neu(hol("--neu"), hol("--nur") or "alles", hol("--plan"))
    if "--anwenden" in a:
        ohne = tuple(int(x) for x in (hol("--ohne") or "").split(",") if x.strip().isdigit())
        return anwenden(hol("--anwenden"), ohne, hol("--projekt"))
    if "--reparieren-index" in a:
        return reparieren_index(hol("--reparieren-index"), hol("--projekt") or os.getcwd(), hol("--snapshot"))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
