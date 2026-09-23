# -*- coding: utf-8 -*-
"""Wo wird dieser Name noch genannt? — EINE Stelle fuer beide Wege (NEU v5.132.0, Etappe 43 §4a).

⛔ WOZU. Zweimal derselbe Fehler, einmal von innen, einmal von aussen:

  17.09.2026  ein DOCS-Zug schob ein Thema nach `docs/`, die `[[wikilinks]]` darauf blieben
              stehen und zeigten ins Leere (repariert in `cleaner_plan.wikilinks_umschreiben`,
              Commit 7bca190) — Zeiger INNERHALB des Memory.
  23.09.2026  ein Memory-Merge fuehrte `routen-stand-15-08.md` in eine andere Datei; in
              `.claude/rules/routenplaner.md:1629` blieb `memory/routen-stand-15-08.md`
              stehen und lag eine WOCHE unbemerkt (Veras Fund, Zustellplan) — Zeiger von
              aussen HINEIN.

⭐ EINE Wurzel (Ottos Einordnung): **beim Umbenennen, Zusammenfuehren oder Verschieben wird
   der alte Name nicht projektweit gesucht.** Deshalb steht die Suche hier EINMAL und wird
   von beiden Wegen gerufen — nicht als zwei Kopien, die getrennt veralten.

⛔ DIESES MODUL SCHREIBT NICHTS. Es nennt Fundstellen mit `datei:zeile`. Die Rules gehoeren
   dem arbeiter, das Memory der sync-Rolle; wer beide anfassen darf, entscheidet der Mensch.
"""
import io
import os
import re

# Zeiger-Formen, die auf eine Memory-Datei zielen. Der blanke Dateiname zaehlt NUR ohne
# vorangehenden Pfadteil: `docs/<name>.md` ist das ZIEL des DOCS-Zugs und kein toter Zeiger
# (gemessen am eigenen Prueffall, der dadurch faelschlich rot wurde).
def _treffer(zeile, stamm):
    if ("memory/%s" % stamm) in zeile or ("[[%s]]" % stamm) in zeile:
        return True
    return bool(re.search(r"(?<![\w/.-])%s\.md\b" % re.escape(stamm), zeile))


def suchdateien(projekt, memory_dir=None):
    """CLAUDE.md + .claude/rules/*.md + MEMORY.md + Topic-Dateien — die Menge aus §4a."""
    aus = []
    if projekt:
        c = os.path.join(projekt, "CLAUDE.md")
        if os.path.isfile(c):
            aus.append(c)
        rdir = os.path.join(projekt, ".claude", "rules")
        if os.path.isdir(rdir):
            aus += [os.path.join(rdir, f) for f in sorted(os.listdir(rdir)) if f.endswith(".md")]
    if memory_dir and os.path.isdir(memory_dir):
        aus += [os.path.join(memory_dir, f) for f in sorted(os.listdir(memory_dir)) if f.endswith(".md")]
    return aus


def fundstellen(projekt, namen, memory_dir=None, ausser=()):
    """Liste `<datei>:<zeile> -> <name>` fuer jeden Namen, der noch genannt wird.

    `namen`: Dateinamen oder Staemme der entfernten/umbenannten Themen.
    `ausser`: Pfade, die uebersprungen werden (z. B. die Datei, die gerade umgeschrieben wurde).
    """
    treffer = []
    stamm = {n[:-3] if n.endswith(".md") else n for n in (namen or []) if n}
    if not stamm:
        return treffer
    ausser = {os.path.abspath(p) for p in (ausser or ())}
    for d in suchdateien(projekt, memory_dir):
        if os.path.abspath(d) in ausser:
            continue
        try:
            text = io.open(d, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for nr, z in enumerate(text.split("\n"), 1):
            for s in sorted(stamm):
                if _treffer(z, s):
                    treffer.append("%s:%d -> %s" % (os.path.basename(d), nr, s))
                    break
    return treffer


def selbsttest():
    import shutil
    import tempfile
    rot = 0

    def pruef(was, ist, soll):
        nonlocal rot
        if ist == soll:
            print("  [ok ] %s" % was)
        else:
            rot += 1
            print("  [ROT] %s (erwartet %r, war %r)" % (was, soll, ist))

    t = tempfile.mkdtemp(prefix="namens suche ")
    try:
        pr = os.path.join(t, "proj")
        mem = os.path.join(t, "memory")
        os.makedirs(os.path.join(pr, ".claude", "rules"))
        os.makedirs(mem)
        io.open(os.path.join(pr, "CLAUDE.md"), "w", encoding="utf-8").write(
            "# P\n\nDer Stand steht in `memory/thema-b.md`.\n")
        io.open(os.path.join(pr, ".claude", "rules", "regel.md"), "w", encoding="utf-8").write(
            "---\ndescription: x\n---\n\nSiehe `memory/thema-b.md`.\n\nUnd `docs/thema-b.md` ist das Ziel.\n")
        io.open(os.path.join(mem, "MEMORY.md"), "w", encoding="utf-8").write(
            "# Memory\n\n- [B](thema-b.md) - Aufhaenger\n")
        io.open(os.path.join(mem, "anderes.md"), "w", encoding="utf-8").write(
            "---\nname: anderes\n---\n\nSiehe [[thema-b]].\n")
        f = fundstellen(pr, ["thema-b.md"], mem)
        pruef("CLAUDE.md-Zeiger gefunden", any(x.startswith("CLAUDE.md:3") for x in f), True)
        pruef("Rules-Zeiger gefunden", any(x.startswith("regel.md:5") for x in f), True)
        pruef("MEMORY.md-Indexzeile gefunden", any(x.startswith("MEMORY.md:3") for x in f), True)
        pruef("Wikilink in einer Topic-Datei gefunden", any(x.startswith("anderes.md:5") for x in f), True)
        pruef("⛔ `docs/<name>.md` ist KEIN Treffer (das ZIEL des DOCS-Zugs)",
              any(x.startswith("regel.md:7") for x in f), False)
        pruef("⭐ Gegenprobe: ein Name, den niemand nennt -> leer",
              fundstellen(pr, ["gibt-es-nicht.md"], mem), [])
        pruef("`ausser` ueberspringt die gerade umgeschriebene Datei",
              any(x.startswith("anderes.md") for x in
                  fundstellen(pr, ["thema-b.md"], mem, ausser=[os.path.join(mem, "anderes.md")])), False)
        pruef("ohne Projekt, nur Memory: findet trotzdem",
              any(x.startswith("MEMORY.md") for x in fundstellen(None, ["thema-b.md"], mem)), True)
    finally:
        shutil.rmtree(t, ignore_errors=True)
    print()
    print("  %s" % ("alle Selbsttests bestanden" if not rot else "%d ROT" % rot))
    return rot


if __name__ == "__main__":
    import sys
    if "--selbsttest" in sys.argv:
        sys.exit(1 if selbsttest() else 0)
    print(__doc__)
