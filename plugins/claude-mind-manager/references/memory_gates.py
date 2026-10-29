# -*- coding: utf-8 -*-
"""Prueft die vier Gates aus `mind-memory` 4.0c NACHTRAEGLICH — vorher gegen nachher.

⛔ WOZU. Die vier Gates, die beim Zusammenfuehren von Memory-Dateien Datenverlust
   verhindern sollen, stehen in `skills/mind-memory/SKILL.md` als **Tabelle**.
   Gemessen 27.08.2026 am gebauten Paket v5.21.3: keine Funktion in `lib.sh`, kein
   Skript in `references/`, **null Pruefsammlungen** — bei 37 fuer alles andere.
   Und Zusammenfuehren LOESCHT eine Datei.

   Dieses Skript ersetzt die Gates nicht (sie muessten VOR dem Schreiben greifen),
   aber es macht den Vollzug **nachpruefbar**: was ist wirklich passiert?

DIE VIER GATES, soweit mechanisch pruefbar:

  1 Erhaltung   Inhaltszeilen (ohne Frontmatter) vorher == nachher.
                Verdichten ja, fallen lassen nein.
  2 Kein Umbenennen  Zusammengefuehrt wird in eine der BESTEHENDEN Dateien,
                nie in eine dritte, neue.
  3 Verweise    Kein `[[name]]` zeigt auf eine entfernte Datei — weder im
                Bestand noch in MEMORY.md. ⛔ Seit v5.131.0 auch KEIN Zeiger
                aus `CLAUDE.md`/`.claude/rules/*.md` des PROJEKTS ins Memory
                (`memory/<name>.md`): Veras Fund 23.09.2026 — `routenplaner.md`
                und `rollen.md` zeigten eine Woche lang auf eine Datei, die ein
                Lauf zusammengefuehrt hatte. Zwischen zwei Instrumenten
                hindurchgefallen: Gate 3 sah nur INS Memory hinein, die
                Pfadpruefung der Rules nur das Projekt-Dateisystem.
  4 Beschreibung  Die ueberlebende `description` ist 40-200 Zeichen lang.
                ⚠ „nennt BEIDE Themen" ist NICHT mechanisch pruefbar und wird
                  hier ausdruecklich NICHT behauptet.

Zusaetzlich: Index-Integritaet (TOT / PRAEFIX / VERWAIST) und die Dateizahl gegen
`MIND_MEMORY_VISIBILITY_LIMIT`.

Aufruf:
    python "$CLAUDE_PLUGIN_ROOT/references/memory_gates.py" <sicherung-vorher> [--projekt <slug>]

Rueckgabe: 0 = keine Abweichung · 1 = Gate gebrochen · 2 = Aufruffehler
"""
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

WIKILINK = re.compile(r"\[\[([^\]]+)\]\]")

# ⛔ AUF MODULEBENE, NICHT IN EINER CLOSURE. Sie sass bis v5.59.0 in
#    `pruefe()` und war damit fuer jeden zweiten Gebrauch unerreichbar — wer
#    sie brauchte, baute sie nach. `instrument-nachgebaut` per Konstruktion,
#    und genau daran ist die Messung zu dieser Aenderung zuerst gescheitert.
INDEXLINK = re.compile(r"\[[^\]]*\]\(([^)]+?)\)")
# Eine INDEX-Zeile beginnt als Aufzaehlungspunkt und traegt den Link vorn.
INDEXZEILE = re.compile(r"^[-*]\s*\[[^\]]*\]\(([^)]+?)\)")


def zeigt_nur_auf(zeile, weg_namen):
    """Zeigt die Zeile NUR auf entfernte Dateien und traegt sonst nichts?

    ⛔ ZWEI FORMEN, und die zweite fehlte bis v5.59.0:
       1. `[[wikilink]]`  — die Verweisform INNERHALB einer Topic-Datei
       2. `- [Titel](datei.md) — Aufhaenger` — die INDEX-Form in `MEMORY.md`,
          die die Memory-Anweisung von Claude Code woertlich vorschreibt.
    ⭐ GEMESSEN an drei echten Sicherungspaaren: von 30 Meldungen eines
       Versuchs-Gates waren die gezeigten Beispiele ALLE Index-Zeilen. Sie
       galten als Inhalt, ihre Entfernung als Verlust — waehrend Gate 3
       genau diese Entfernung VERLANGT.
    ⚠ Der TITEL zaehlt bei der Index-Form NICHT als Inhalt. Er ist der Name
      der entfernten Datei, kein eigenes Wissen; er verschwindet mit ihr.
    """
    # ⭐ DIE INDEX-ZEILE IST GANZ EIN ZEIGER, Aufhaenger eingeschlossen.
    #    Die Memory-Anweisung von Claude Code schreibt die Form woertlich vor:
    #    `- [Titel](datei.md) — Aufhaenger`. Titel und Aufhaenger beschreiben
    #    die Datei; verschwindet sie, verschwinden sie mit ihr. Sie als Inhalt
    #    zu zaehlen hiess, jedes korrekte Aufraeumen des Index als Verlust zu
    #    melden — an drei echten Sicherungspaaren gemessen.
    # ⛔ ENG GEFASST: nur eine Zeile, die als Aufzaehlungspunkt BEGINNT und
    #    deren Ziel entfernt wurde. Ein Fliesstext-Satz, der zufaellig einen
    #    Link auf eine entfernte Datei enthaelt, bleibt Inhalt — Prueffall 7
    #    haelt beide Richtungen fest.
    m = INDEXZEILE.match(zeile.strip())
    if m:
        ziel = m.group(1).strip()
        if ziel.endswith(".md"):
            ziel = ziel[:-3]
        return ziel in weg_namen

    ziele = [z.strip() for z in WIKILINK.findall(zeile)]
    rest = WIKILINK.sub("", zeile)
    if not ziele or not any(z in weg_namen for z in ziele):
        return False
    rest = re.sub(r"(?i)\b(siehe|auch|vgl|mehr|dazu|und|in|zu|s)\b", "", rest)
    return len(re.sub(r"[^0-9A-Za-z\u00c4\u00d6\u00dc\u00e4\u00f6\u00fc\u00df]", "", rest)) == 0

INDEXLINK = re.compile(r"\]\(([^)]*\.md)\)")
LIMIT = int(os.environ.get("MIND_MEMORY_VISIBILITY_LIMIT", "5"))


def lies(pfad):
    try:
        return open(pfad, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def ohne_frontmatter(text):
    """Rumpf ab der ersten Nicht-Frontmatter-Zeile.

    ⚠ Ein Frontmatter beginnt mit '---' in Zeile 1 und endet an der NAECHSTEN
      '---'-Zeile. Eine Datei mit nur EINEM '---' ist kaputt (mind-rules-Befund)
      und wird hier als 'kein Frontmatter' behandelt, statt die ganze Datei
      wegzuwerfen.
    """
    zeilen = text.replace("\r\n", "\n").split("\n")
    if not zeilen or zeilen[0].strip() != "---":
        return zeilen
    for i in range(1, len(zeilen)):
        if zeilen[i].strip() == "---":
            return zeilen[i + 1:]
    return zeilen


def inhaltszeilen(text):
    """Nicht-leere Zeilen des Rumpfes. Leerzeilen zaehlen nicht — sonst meldet
    jede Formatierung einen Verlust."""
    return [z for z in ohne_frontmatter(text) if z.strip()]


# Etappe 34 (Anton, Ritas Verdichtung 17.09.2026: 39 -> 37 Zeilen, coverage 26/26, kein Fakt weg —
# Gate 1 sagte GEBROCHEN, weil es physische Zeilen zaehlte). Gate 1 vergleicht seither INHALT:
# die MARKEN wie coverage_gate (Code-Spans, Zahlen mit Einheit, CamelCase/ALLCAPS) sind das Gate —
# 100 % oder rot, wie Stufe 1; fehlende markenfreie Woerter (ab 5 Zeichen) werden AUSGEWIESEN, wie
# Stufe 2 — das Urteil hat Stufe 3. Ein Umbruch aendert keine der Mengen; eine Verdichtung verliert
# Woerter, nie Marken; eine verlorene Zeile mit Marke ist rot.
_P_CODE = re.compile(r"`([^`\n]{3,40})`")
_P_ZAHL = re.compile(r"\b\d[\d.,]*\s?(?:%|K\b|T/line|tokens?\b|lines?\b|Zeilen\b|B\b|KB\b|MB\b|s\b|min\b)")
_P_NAME = re.compile(r"\b(?:[A-Z][a-z]+[A-Z][A-Za-z]+|[A-Z][A-Z0-9_]{3,})\b")   # auch KEEP_VERSIONS, MIND_DEBUG_DIR
_P_WORT = re.compile(r"[0-9a-zäöüß]{5,}")


def inhaltsmenge(zeilen):
    """-> (marken, woerter) der Zeilen, normalisiert (Kleinschreibung, ohne Sonderzeichen)."""
    marken, woerter = set(), set()
    for z in zeilen:
        for m in _P_CODE.findall(z):
            k = _norm(m)
            if len(k) >= 4 and not k.isdigit() and re.search(r"[a-z0-9]", k):
                marken.add("`" + k + "`")
        for m in _P_ZAHL.findall(z):
            marken.add(re.sub(r"\s+", "", m).lower())
        for m in _P_NAME.findall(z):
            marken.add(m.lower())
        woerter.update(_P_WORT.findall(z.lower()))
    return marken, woerter


def beschreibung(text):
    for z in text.replace("\r\n", "\n").split("\n"):
        if z.startswith("description:"):
            return z[len("description:"):].strip().strip('"').strip("'")
    return ""


def sammle(verz):
    """{dateiname: text} fuer alle .md ausser MEMORY.md, plus MEMORY.md separat."""
    dateien, index = {}, ""
    if not os.path.isdir(verz):
        return dateien, index
    for name in sorted(os.listdir(verz)):
        if not name.endswith(".md"):
            continue
        text = lies(os.path.join(verz, name))
        if name == "MEMORY.md":
            index = text
        else:
            dateien[name] = text
    return dateien, index


def ausgelagert(index, verz, wurzel=None):
    """v5.115.0 (Etappe 23 §8): Index-Eintraege, die auf eine EXISTIERENDE Datei ausserhalb
    des Memory-Ordners zeigen (der DOCS-Zug des Cleaners: `- [T](<projekt>/docs/x.md) …`).
    {ziel: text} — ihr Inhalt zaehlt in Gate 1/1b als wiedergefunden, in Gate 3 als gueltig."""
    out = {}
    for ziel in INDEXLINK.findall(index or ""):
        z = ziel.strip()
        if "/" not in z.replace("\\", "/") and not os.path.isabs(z):
            continue                      # blosser Name: eine Memory-Datei, nicht ausgelagert
        kand = [z] if os.path.isabs(z) else ([os.path.join(wurzel, z)] if wurzel else []) + [os.path.join(verz, z)]
        for p in kand:
            if os.path.isfile(p):
                out[z] = lies(p)
                break
    return out


def _norm(z):
    return re.sub(r"[^0-9a-zäöüß]", "", z.lower())


def benannte_entfernungen(pfad):
    """Zitate aus einem Bericht: Zeilen `entfernt: … „<zitat>“` (coverage_gate-Form) oder
    `ENTFERNT: Zeilen 54-55 "<zitat>"` (verdichten-<skill>.txt). Rueckgabe: normalisierte
    Zitate, mindestens 20 Zeichen — kuerzere waeren Zufallstreffer.
    ⛔ v5.100.0 (Etappe 8 §5.2): Gate 1 brach an einer BENANNTEN Entfernung (Ritas
       Memory-Kandidat, 289 -> 287 Zeilen), waehrend coverage_gate.py --entfernt gruen war.
       Benannt heisst: der Bericht nennt den Wortlaut, Stufe 3 hat ihn gelesen. Unbenannt
       bleibt rot — das ist der ganze Unterschied zwischen kuerzen und verlieren."""
    out = []
    if not pfad:
        return out
    try:
        text = open(pfad, encoding="utf-8", errors="replace").read()
    except OSError:
        return out
    for zeile in text.splitlines():
        if not re.match(r"\s*entfernt\s*:", zeile, re.I):
            continue
        rest = zeile.split(":", 1)[1]
        for m in re.finditer(r"[„\"“”]\s*(.+?)\s*[“”\"]", rest):
            z = _norm(m.group(1))
            if len(z) >= 20:
                out.append(z)
    return out


def slug_von(pfad):
    """Der Ordnername unter ~/.claude/projects fuer einen Windows-Pfad — VORWAERTS
    gerechnet (`:` und `\\` und Leerzeichen werden `-`), weil der Rueckweg mehrdeutig
    ist: `Plugin - Entwicklung` und `Plugin---Entwicklung` ergeben denselben Slug."""
    p = os.path.abspath(pfad)
    if len(p) > 1 and p[1] == ":":
        p = p[0].upper() + p[1:]
    return p.replace(":", "-").replace("\\", "-").replace("/", "-").replace(" ", "-")


def projekt_zu_slug(slug, wurzel=None, basis=None):
    """Welcher Projektordner gehoert zu diesem Slug? `--wurzel` zuerst; sonst werden die
    Ordner unter der Basis (Vorgabe `MIND_PROJEKT_BASIS` bzw. C:/CD/KOHLEKTIV) zwei Ebenen
    tief VORWAERTS verglichen. Kein Treffer -> None, und der Aufrufer WEIST DAS AUS."""
    if wurzel and slug_von(wurzel) == slug:
        return os.path.abspath(wurzel)
    basis = basis or os.environ.get("MIND_PROJEKT_BASIS") or "C:/CD/KOHLEKTIV"
    if not os.path.isdir(basis):
        return None
    for tiefe1 in sorted(os.listdir(basis)):
        p1 = os.path.join(basis, tiefe1)
        if not os.path.isdir(p1):
            continue
        if slug_von(p1) == slug:
            return p1
        try:
            unter = sorted(os.listdir(p1))
        except OSError:
            continue
        for tiefe2 in unter:
            p2 = os.path.join(p1, tiefe2)
            if os.path.isdir(p2) and slug_von(p2) == slug:
                return p2
    return None


MEMZEIGER = re.compile(r"memory/([A-Za-z0-9._-]+?)(?:\.md)?\b")


def _namens_suche():
    """Das gemeinsame Modul aus dem Plugin (v5.132.0, Etappe 43 §4a) — EINE Suche fuer
    beide Wege: den Memory-Merge hier und den DOCS-Zug in `cleaner_plan.py`.
    ⛔ Ist es nicht erreichbar, wird das AUSGEWIESEN statt still uebersprungen — eine
    Pruefung, die ausfaellt, sieht sonst aus wie eine, die nichts gefunden hat."""
    wurzel = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    if not wurzel:
        return None
    pfad = os.path.join(wurzel, "references")
    if pfad not in sys.path:
        sys.path.insert(0, pfad)
    try:
        import namens_suche
        return namens_suche
    except Exception:
        return None


def rules_memory_zeiger(projekt):
    """Alle `memory/<name>`-Zeiger aus CLAUDE.md und .claude/rules/*.md — als
    (datei, zeile, name). Grundlage fuer die Pruefung gegen den HEUTIGEN Bestand."""
    # ⛔ v5.138.0 (Etappe 49 §1): fehlendes Modul gibt `None`, NICHT `[]`. Eine leere
    #    Liste hiesse "keine toten Zeiger" und wuerde von "konnte nicht nachsehen" nicht
    #    zu unterscheiden sein — genau die Klasse, gegen die dieses Gate gebaut ist.
    #    `rules_zeiger` daneben macht es seit v5.132.0 richtig.
    aus = []
    ns = _namens_suche()
    if ns is None:
        return None
    if not projekt:
        return None
    for d in ns.suchdateien(projekt):
        try:
            text = io.open(d, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for nr, z in enumerate(text.split("\n"), 1):
            for name in MEMZEIGER.findall(z):
                aus.append((os.path.basename(d), nr, name))
    return aus


def rules_zeiger(projekt, namen):
    """⛔ NUR MELDEN. Ruft `namens_suche.fundstellen` aus dem Plugin — die Suche steht seit
    v5.132.0 an EINER Stelle (Ottos Einordnung: eine Wurzel, zwei Faelle).
    Rueckgabe: Liste `<datei>:<zeile> -> <name>`; `None`, wenn das Modul fehlt."""
    ns = _namens_suche()
    if ns is None:
        return None
    if not projekt or not namen:
        return []
    return ns.fundstellen(projekt, namen)


def pruefe_projekt(slug, vorher_dir, nachher_dir, benannt=None, wurzel=None):
    benannt = benannt or []
    v, _ = sammle(vorher_dir)          # der Vorher-Index wird nicht gebraucht:
    n, n_index = sammle(nachher_dir)   # Gate 3 fragt, ob der NEUE Index ins Leere zeigt
    n_aus = ausgelagert(n_index, nachher_dir, wurzel)   # v5.115.0: docs-Ziele aus dem Index; v5.117.0: relativ zur --wurzel
    if not v and not n:
        return None

    entfernt = sorted(set(v) - set(n))
    neu = sorted(set(n) - set(v))
    geblieben = sorted(set(v) & set(n))

    # ⛔ NICHT nur die Dateimenge vergleichen. Erster echter Einsatz am 27.08.2026:
    #    ein /mind-memory-Lauf aenderte VIER Dateien, ohne eine zu loeschen — und
    #    dieses Skript meldete "14 Projekte unveraendert". Ein Instrument, das den
    #    haeufigsten Fall (ergaenzen statt loeschen) gar nicht sieht, misst nichts.
    veraendert = sorted(k for k in geblieben if v[k] != n[k])
    if not entfernt and not neu and not veraendert:
        return ("STILL", slug, len(v), len(n), [])

    befunde = []

    # --- Gate 1 JE DATEI: eine einzelne darf keinen Inhalt verlieren -------
    # ⚠ Die SUMME kann wachsen, waehrend eine Datei Inhalt einbuesst. Gate 1 auf
    #   der Summe verdeckt das — deshalb zuerst je Datei.
    # ⛔ v5.100.0: eine Zeile gilt als BENANNT entfernt, wenn ihr Wortlaut in einem
    #    Zitat des Berichts steht (oder das Zitat in ihr) UND sie im Nachher fehlt.
    #    Steht sie noch da, war die Benennung leer — sie zaehlt nicht (wie coverage_gate).
    n_heu = {_norm(z) for tx in n.values() for z in inhaltszeilen(tx)}
    n_heu.discard("")

    def ist_benannt(zeile):
        k = _norm(zeile)
        if not k or k in n_heu:
            return False
        return any(k in b or (len(k) >= 20 and b in k) for b in benannt)

    benannt_weg = [z for tx in v.values() for z in inhaltszeilen(tx) if ist_benannt(z)]
    # Etappe 34: Marken aus BENANNT entfernten oder reinen Zeiger-Zeilen duerfen fehlen
    weg_namen_1 = {name[:-3] for name in entfernt}
    frei_m, frei_w = inhaltsmenge(benannt_weg + [z for tx in v.values() for z in inhaltszeilen(tx)
                                                  if zeigt_nur_auf(z, weg_namen_1)])
    geschrumpft, wort_hinweis = [], []
    for k in veraendert:
        vz = inhaltszeilen(v[k]); nz = inhaltszeilen(n[k])
        m_v, w_v = inhaltsmenge(vz); m_n, w_n = inhaltsmenge(nz)
        fehlt = sorted((m_v - m_n) - frei_m)
        if fehlt:
            geschrumpft.append("%s (Zeilen %d -> %d; Marke(n) weg: %s)" % (k, len(vz), len(nz), ", ".join(fehlt[:4])))
        _wf = sorted((w_v - w_n) - frei_w)
        if _wf:
            wort_hinweis.append("%s: %d Wort(e) markenfrei weg (%s)" % (k, len(_wf), ", ".join(_wf[:4])))
    if veraendert:
        befunde.append("geaendert ohne Loeschung: %d Datei(en) — %s"
                       % (len(veraendert), ", ".join(veraendert[:4])))
    if geschrumpft:
        befunde.append("GATE 1 je Datei GEBROCHEN: %d Datei(en) verloren Marken — %s"
                       % (len(geschrumpft), ", ".join(geschrumpft[:4])))
    elif veraendert:
        _refl = ["%s (%d -> %d Zeilen)" % (k, len(inhaltszeilen(v[k])), len(inhaltszeilen(n[k])))
                 for k in veraendert if len(inhaltszeilen(v[k])) != len(inhaltszeilen(n[k]))]
        befunde.append("gate 1 je Datei ok: keine geaenderte Datei hat eine Marke verloren"
                       + ("; Zeilenzahl geaendert (Umbruch/Verdichtung): %s" % ", ".join(_refl[:4]) if _refl else ""))
    if wort_hinweis:
        befunde.append("  ⚠ markenfrei fehlende Woerter (kein Gate — Stufe 3 liest den Wort-Diff): %s" % " · ".join(wort_hinweis[:3]))

    # --- Gate 1: Erhaltung -------------------------------------------------
    # ⛔ Zeilen, die NUR auf eine entfernte Datei zeigen, zaehlen NICHT als Verlust:
    #    ihre Entfernung verlangt Gate 3 (keine toten `[[Verweise]]`). Ohne diese
    #    Ausnahme wird JEDES korrekte Zusammenfuehren rot — am eigenen Prueffall
    #    gemessen (5 -> 4, die fehlende Zeile war `Siehe auch [[thema-b]].`).
    # ⚠ Sie werden getrennt AUSGEWIESEN, nicht stillschweigend geschluckt.
    weg_namen = {name[:-3] for name in entfernt}

    def ist_nur_zeiger(zeile):
        return zeigt_nur_auf(zeile, weg_namen)

    v_alle = [z for t in v.values() for z in inhaltszeilen(t)]
    n_alle = [z for t in n.values() for z in inhaltszeilen(t)] \
        + [z for t in n_aus.values() for z in inhaltszeilen(t)]   # v5.115.0: ausgelagerter Inhalt zaehlt
    zeiger_v = [z for z in v_alle if ist_nur_zeiger(z)]
    zeilen_v, zeilen_n = len(v_alle) - len(zeiger_v) - len(benannt_weg), len(n_alle)
    # Etappe 34: Marken statt Zeilen; benannt Entferntes und Zeiger-Zeilen sind frei
    _mv, _wv = inhaltsmenge(v_alle); _mn, _wn = inhaltsmenge(n_alle)
    _fm, _fw = inhaltsmenge(zeiger_v + benannt_weg)
    _fehlt = sorted((_mv - _mn) - _fm); _wfehlt = sorted((_wv - _wn) - _fw)
    if _fehlt:
        befunde.append("GATE 1 (Erhaltung) GEBROCHEN: %d Marke(n) aus dem Vorher fehlen — %s (Zeilen %d -> %d)"
                       % (len(_fehlt), ", ".join(_fehlt[:5]), zeilen_v, zeilen_n))
    else:
        befunde.append("gate 1 ok: alle %d Marken erhalten; Zeilen %d -> %d%s"
                       % (len(_mv), zeilen_v, zeilen_n,
                          " (weniger Zeilen, keine Marke weg — Umbruch oder Verdichtung)" if zeilen_n < zeilen_v else ""))
    if _wfehlt:
        befunde.append("  ⚠ %d markenfreie(s) Wort(e) aus dem Vorher fehlen (%s) — kein Gate, Stufe 3 liest"
                       % (len(_wfehlt), ", ".join(_wfehlt[:5])))
    if zeiger_v:
        befunde.append("  (dabei %d reine Zeiger-Zeile(n) auf entfernte Dateien "
                       "nicht als Verlust gezaehlt — Gate 3 verlangt ihre Entfernung)"
                       % len(zeiger_v))
    if benannt_weg:
        befunde.append("  (dabei %d BENANNT entfernte Zeile(n) aus --entfernt nicht als "
                       "Verlust gezaehlt — Stufe 3 hat den Wortlaut gelesen)" % len(benannt_weg))
    elif benannt:
        befunde.append("⚠ --entfernt nennt %d Zitat(e), aber keine Vorher-Zeile fehlt dazu — "
                       "Benennung ohne Wirkung, zaehlt nicht" % len(benannt))

    # --- Gate 1b: der INHALT der entfernten Datei muss wiederauffindbar sein --
    # ⛔ WARUM ES 1b BRAUCHT. Die Spezifikation in 4.0c sagt nur „Inhaltszeilen
    #    vorher == nachher". Am eigenen Prueffall gemessen: ein Lauf, der eine
    #    Datei loescht und eine gleich lange neue anlegt, kommt damit auf
    #    4 -> 4 und gilt als sauber — obwohl der ganze Inhalt weg ist.
    #    Gleiche ANZAHL ist nicht erhaltener INHALT.
    def norm(z):
        return re.sub(r"[^0-9a-zäöüß]", "", z.lower())

    heuhaufen = {norm(z) for t in list(n.values()) + list(n_aus.values()) for z in inhaltszeilen(t)}
    heuhaufen.discard("")
    verloren = []
    for name in entfernt:
        for z in inhaltszeilen(v[name]):
            if ist_nur_zeiger(z):
                continue
            k = norm(z)
            if k and k not in heuhaufen and not any(k in h for h in heuhaufen):
                verloren.append("%s: %s" % (name, z.strip()[:52]))
    if verloren:
        befunde.append("GATE 1b (Inhalt wiedergefunden) GEBROCHEN: %d Zeile(n) aus "
                       "entfernten Dateien nirgends mehr auffindbar — %s"
                       % (len(verloren), " · ".join(verloren[:3])))
    elif entfernt:
        befunde.append("gate 1b ok: jede Zeile der entfernten Datei(en) ist wiederauffindbar")

    # --- Gate 2: kein Umbenennen ------------------------------------------
    # ⛔ Etappe 38 §4 (Z397, 09.09.2026): hier stand `if neu:` — jede neue Datei brach das
    #    Gate, auch ein reiner ADD-Lauf (neues Thema, nichts entfernt). 4.0c definiert
    #    Gate 2 nur fuer das ZUSAMMENFUEHREN: zwei Dateien verschwinden, eine DRITTE
    #    entsteht. Ein falsches Rot zwang Rita zum Rollback ohne Grund (backup-usage.md:
    #    „rotes Gate nach cp heisst zurueck"). Jetzt: rot nur bei neu UND entfernt.
    if neu and entfernt:
        befunde.append("GATE 2 (kein Umbenennen) GEBROCHEN: entfernt %s, neu %s — zusammengefuehrt "
                       "wird in eine BESTEHENDE Datei, nie in eine dritte"
                       % (", ".join(entfernt), ", ".join(neu)))
    elif neu:
        befunde.append("gate 2 ok: neue Datei(en) %s ohne Entfernung — Anlegen, kein Zusammenfuehren"
                       % ", ".join(neu))
    else:
        befunde.append("gate 2 ok: keine neue Datei angelegt")

    # --- Gate 3: Verweise --------------------------------------------------
    weg = {name[:-3] for name in entfernt}
    tote = []
    # v5.121.0 (Etappe 31, Otto 17.09.2026): ein `[[name]]` ist NUR gueltig, wenn `<name>.md` im
    # Memory liegt — ein docs-Zeiger in der Indexzeile rettet ihn nicht, Claude Code loest
    # Wikilinks als memory/<name>.md auf. Und MEMORY.md selbst wird mitgelesen: der Fall vom
    # 16.09. (`MEMORY.md:20` -> [[karten-vereinheitlichung]], Thema nach docs/) war fuer das
    # alte Gate unsichtbar, weil nur die Topic-Dateien nach Wikilinks durchsucht wurden.
    da = {name[:-3] for name in n}
    vorher_da = {name[:-3] for name in v}
    schon_vorher = []
    for name, text in list(n.items()) + [("MEMORY.md", n_index)]:
        for ziel in WIKILINK.findall(text):
            zn = ziel.strip().split("|")[0].strip()
            if zn in da:
                continue
            if zn in weg or zn in vorher_da:
                tote.append("%s -> [[%s]]" % (name, zn))
            else:
                schon_vorher.append("%s -> [[%s]]" % (name, zn))
    if schon_vorher:
        befunde.append("⚠ %d Wikilink(s) zeigten schon vorher ins Leere (kein Gate-Bruch dieses Laufs): %s"
                       % (len(schon_vorher), " · ".join(schon_vorher[:3])))
    for ziel in INDEXLINK.findall(n_index):
        if ziel.strip() in n_aus:
            continue                      # v5.115.0: existierender docs-Zeiger ist gueltig
        if os.path.basename(ziel) in entfernt:
            tote.append("MEMORY.md -> %s" % ziel)
    # ⛔ v5.131.0 (Etappe 43 §1, Veras Fund Zustellplan 23.09.2026): die Zeiger von AUSSEN.
    #    `routenplaner.md:1629` und `rollen.md:40` zeigten seit dem 16.09. auf
    #    `memory/routen-stand-15-08.md`, das ein Lauf zusammengefuehrt hatte — eine Woche
    #    unbemerkt, von Hand gefunden. Beide Instrumente waren gruen: Gate 3 sah nur INS
    #    Memory hinein, die Pfadpruefung der Rules nur das Projekt-Dateisystem, und
    #    `memory/<name>.md` liegt unter ~/.claude/projects/<slug>/memory.
    #    ⚠ Ist das Projekt nicht bestimmbar, wird das AUSGEWIESEN — nie still uebersprungen.
    # ⛔ v5.138.0 (Etappe 49 §1, Veras Fund Zustellplan 26.09.2026): DER ALTBESTANDS-GREP
    #    LAEUFT IMMER. Bis 5.137.0 stand er INNERHALB von `if entfernt:` — und das ist die
    #    gefaehrliche Haelfte des Baus vom 23.09.: der Lauf, der einen Zeiger toetet, meldet
    #    ihn, und DANACH SCHWEIGT DAS GATE FUER IMMER, weil die meisten Laeufe nichts
    #    entfernen. Gemessen: Gate 3 sagte „ok — auch keiner aus CLAUDE.md/.claude/rules",
    #    Veras Handpruefung fand zwei. Nur der MERGE-spezifische Teil bleibt im `if`.
    _proj = projekt_zu_slug(slug, wurzel)
    if not _proj:
        befunde.append("⚠ Rules-Zeiger ungeprueft: Projekt zu Slug %s nicht bestimmbar "
                       "(--wurzel <projekt> setzen oder MIND_PROJEKT_BASIS)" % slug)
    else:
        if entfernt:
            _rz = rules_zeiger(_proj, entfernt)
            if _rz is None:
                befunde.append("⚠ Rules-Zeiger ungeprueft: references/namens_suche.py nicht erreichbar "
                               "(CLAUDE_PLUGIN_ROOT setzen) — keine Messung, kein gruenes Gate")
            elif _rz:
                tote += ["%s (Rules)" % x for x in _rz]
        # ⚠ Der ALTBESTAND: Veras Zeiger lag eine WOCHE, weil ihn der Lauf, der ihn toetete,
        #   nicht meldete und danach niemand mehr suchte. Kein Gate-Bruch DIESES Laufs
        #   (fail-safe wie bei den Wikilinks) — aber sichtbar, und zwar in JEDEM Lauf.
        _zeiger = rules_memory_zeiger(_proj)
        if _zeiger is None:
            # ⛔ Nicht mit "keine Treffer" verwechseln — siehe rules_memory_zeiger.
            befunde.append("⚠ Altbestands-Zeiger ungeprueft: references/namens_suche.py nicht "
                           "erreichbar (CLAUDE_PLUGIN_ROOT setzen) — keine Messung, kein gruenes Gate")
        else:
            _alt = [(d, nr, nm) for d, nr, nm in _zeiger
                    if nm not in {k[:-3] for k in n} and ("%s.md" % nm) not in n]
            _alt = [x for x in _alt if x[2] not in {k[:-3] for k in entfernt}]
            if _alt:
                befunde.append("⚠ %d Rules-Zeiger ins Leere, schon vor diesem Lauf "
                               "(kein Gate-Bruch, nur melden): %s"
                               % (len(_alt), " · ".join("%s:%d -> memory/%s" % x for x in _alt[:4])))
    if tote:
        befunde.append("GATE 3 (Verweise) GEBROCHEN: %d toter Zeiger — %s"
                       % (len(tote), " · ".join(tote[:4])))
    else:
        befunde.append("gate 3 ok: kein Zeiger auf eine entfernte Datei — auch keiner aus "
                       "CLAUDE.md/.claude/rules (v5.131.0)")

    # --- Gate 4: Beschreibung (nur Laenge) ---------------------------------
    schlecht = []
    for name in geblieben:
        d = beschreibung(n[name])
        if not d or not (40 <= len(d) <= 200):
            schlecht.append("%s (%d Zeichen)" % (name, len(d)))
    if schlecht:
        befunde.append("GATE 4 (Beschreibung) AUFFAELLIG: %s" % ", ".join(schlecht[:4]))
    else:
        befunde.append("gate 4 ok: alle Beschreibungen 40-200 Zeichen")
    befunde.append("⚠ gate 4 prueft NUR die Laenge — ob sie BEIDE Themen nennt, "
                   "ist nicht mechanisch pruefbar und wird hier nicht behauptet")

    # --- Index-Integritaet --------------------------------------------------
    verwaist = [k for k in n if ("(%s)" % k) not in n_index]
    if verwaist:
        befunde.append("VERWAIST (nicht im Index): %s" % ", ".join(verwaist[:4]))

    return ("GEAENDERT", slug, len(v), len(n), befunde, entfernt, neu)


def _schreib(pfad, text):
    d = os.path.dirname(pfad)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    io.open(pfad, "w", encoding="utf-8", newline="\n").write(text)


def _topic(name, zeilen):
    return ("---\nname: %s\ndescription: %s\nmetadata:\n  type: project\n---\n\n%s\n"
            % (name, "x" * 45, "\n".join(zeilen)))


def selbsttest():
    """Die fuenf Kontrollen aus `backup-usage.md` — bis v5.59.0 nur Prosa.

    ⛔ Sie standen dort als Aufzaehlung ("belegt mit fuenf Kontrollen") und
       waren VON HAND gefahren. Eine Kontrolle, die niemand wiederholen kann,
       belegt den Stand von damals und nichts danach.
    """
    import shutil
    import tempfile
    rot = [0]

    def pruef(was, ist, soll):
        if ist == soll:
            print("  [ok ] %s" % was)
        else:
            rot[0] += 1
            print("  [ROT] %s (erwartet %r, war %r)" % (was, soll, ist))

    def lauf(vor, nach):
        """vor/nach: {dateiname: text} -> Liste der Befunde."""
        t = tempfile.mkdtemp()
        try:
            for name, txt in vor.items():
                _schreib(os.path.join(t, "v", "proj", name), txt)
            for name, txt in nach.items():
                _schreib(os.path.join(t, "n", "proj", name), txt)
            if not os.path.isdir(os.path.join(t, "n", "proj")):
                os.makedirs(os.path.join(t, "n", "proj"))
            e = pruefe_projekt("proj", os.path.join(t, "v", "proj"),
                               os.path.join(t, "n", "proj"))
            # pruefe_projekt gibt ein TUPEL zurueck; die Befunde stehen an
            # Stelle 4. Ein `None` heisst "beide Seiten leer".
            if not e:
                return []
            return e[4] if e[0] != "UNVERAENDERT" else []
        finally:
            shutil.rmtree(t, ignore_errors=True)

    def gebrochen(b):
        return [x for x in b if "GEBROCHEN" in x]

    A = _topic("thema-a", ["Satz A eins.", "Satz A zwei."])
    B = _topic("thema-b", ["Satz B eins.", "Satz B zwei."])
    IDX = "# Memory\n\n- [A](thema-a.md) — Aufhaenger A\n- [B](thema-b.md) — Aufhaenger B\n"

    print("=== 1) ⭐ POSITIVKONTROLLE: sauberes Zusammenfuehren -> gruen ===")
    AB = _topic("thema-a", ["Satz A eins.", "Satz A zwei.",
                            "Satz B eins.", "Satz B zwei."])
    IDX1 = "# Memory\n\n- [A](thema-a.md) — Aufhaenger A\n"
    b = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
             {"MEMORY.md": IDX1, "thema-a.md": AB})
    pruef("kein gebrochenes Gate", gebrochen(b), [])

    print()
    print("=== 2) ⛔ kaputtes Zusammenfuehren -> Gate 1b schlaegt an ===")
    LEER = _topic("thema-a", ["Satz A eins.", "Satz A zwei."])
    b = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
             {"MEMORY.md": IDX1, "thema-a.md": LEER})
    pruef("mindestens ein Gate gebrochen", len(gebrochen(b)) >= 1, True)
    pruef("und es ist 1 oder 1b",
          any("GATE 1" in x for x in gebrochen(b)), True)

    print()
    print("=== 3) unveraendert -> STILL ===")
    b = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
             {"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B})
    pruef("keine Befunde", b, [])

    print()
    print("=== 4) nur gewachsen -> gruen ===")
    MEHR = _topic("thema-a", ["Satz A eins.", "Satz A zwei.", "Satz A drei."])
    b = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
             {"MEMORY.md": IDX, "thema-a.md": MEHR, "thema-b.md": B})
    pruef("kein gebrochenes Gate", gebrochen(b), [])

    print()
    print("=== 5) ⛔ Summe waechst, EINE Datei verliert -> ROT ===")
    # ⭐ Nicht aus 4.0c. Ohne Gate 1 JE DATEI bleibt das Summen-Gate gruen.
    # Etappe 34: Gate 1 misst Marken, nicht Zeilen — die verlorenen Zeilen tragen deshalb Marken
    # (`a.py`, 12 Zeilen); Ziel unveraendert: EINE Datei verliert Inhalt, die Summe waechst -> ROT
    AMARK = _topic("thema-a", ["Satz A eins mit `a.py`.", "Satz A zwei, 12 Zeilen."])
    AVERL = _topic("thema-a", [])
    BVIEL = _topic("thema-b", ["Satz B eins.", "Satz B zwei.", "B drei.",
                               "B vier.", "B fuenf.", "B sechs."])
    b = lauf({"MEMORY.md": IDX, "thema-a.md": AMARK, "thema-b.md": B},
             {"MEMORY.md": IDX, "thema-a.md": AVERL, "thema-b.md": BVIEL})
    pruef("ein Gate ist gebrochen", len(gebrochen(b)) >= 1, True)

    print()
    print("=== 8) v5.100.0: --entfernt — benannt zaehlt nicht, unbenannt bleibt rot ===")
    # Vorher: eine Datei mit vier Inhaltszeilen; nachher fehlt eine.
    _vd, _nd = tempfile.mkdtemp(), tempfile.mkdtemp()
    _z = [u"Erste Aussage, die bleibt und lang genug ist.",
          u"⛔ **Das korrigiert die aeltere Notiz**, die KEEP_VERSIONS=2 als Schutz beschrieb.",
          u"Dritte Aussage, ebenfalls bleibend.", u"Vierte Aussage zum Schluss."]
    _schreib(os.path.join(_vd, "p", "topic.md"), _topic("topic", _z))
    _schreib(os.path.join(_nd, "p", "topic.md"), _topic("topic", [_z[0], _z[2], _z[3]]))
    _b = os.path.join(_vd, "bericht.txt")
    _schreib(_b, u'ENTFERNT: Zeilen 2-2 "⛔ **Das korrigiert die aeltere Notiz**, die KEEP_VERSIONS=2 als Schutz beschrieb." (Provenienz)\n')
    _ohne = pruefe_projekt("p", os.path.join(_vd, "p"), os.path.join(_nd, "p"))
    _mit = pruefe_projekt("p", os.path.join(_vd, "p"), os.path.join(_nd, "p"), benannte_entfernungen(_b))
    pruef("ohne --entfernt: Gate 1 je Datei rot", bool(gebrochen(_ohne[4])), True)
    pruef("mit --entfernt (Ritas Berichtform): kein Gate gebrochen", bool(gebrochen(_mit[4])), False)
    pruef("   ... und die Benennung wird ausgewiesen",
          any("BENANNT entfernte" in b for b in _mit[4]), True)
    _falsch = os.path.join(_vd, "falsch.txt")
    _schreib(_falsch, u'entfernt: ⛔ „Eine Zeile, die es nie gab, aber lang genug ist“\n')
    _f = pruefe_projekt("p", os.path.join(_vd, "p"), os.path.join(_nd, "p"), benannte_entfernungen(_falsch))
    pruef("erfundene Benennung deckt den Verlust NICHT: weiter rot", bool(gebrochen(_f[4])), True)
    _leer = os.path.join(_vd, "leer.txt")
    _schreib(_leer, u'entfernt: „Erste Aussage, die bleibt und lang genug ist.“\n')
    _l = pruefe_projekt("p", os.path.join(_vd, "p"), os.path.join(_nd, "p"), benannte_entfernungen(_leer))
    pruef("Benennung einer Zeile, die noch dasteht, zaehlt nicht: weiter rot", bool(gebrochen(_l[4])), True)
    pruef("   ... und wird als 'ohne Wirkung' gemeldet",
          any("ohne Wirkung" in b for b in _l[4]), True)
    shutil.rmtree(_vd, ignore_errors=True); shutil.rmtree(_nd, ignore_errors=True)

    print("=== 6) ⛔ gleiche ZEILENZAHL, anderer Inhalt -> Gate 1b ===")
    # Der Fall, wegen dem 1b ueberhaupt existiert: 4 -> 4 und alles weg.
    NEUB = _topic("thema-a", ["Satz A eins.", "Satz A zwei.",
                              "Ganz was anderes.", "Und noch etwas."])
    b = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
             {"MEMORY.md": IDX1, "thema-a.md": NEUB})
    pruef("Gate 1b schlaegt an",
          any("1b" in x for x in gebrochen(b)), True)

    print()
    print("=== 7) ⛔ DIE INDEX-FORM — bis v5.59.0 zaehlte sie als Verlust ===")
    # ⭐ GEMESSEN an drei echten Sicherungspaaren: die Zeiger-Erkennung kannte
    #    nur `[[wikilinks]]`. Die Index-Form `- [Titel](datei.md) — Aufhaenger`,
    #    die die Memory-Anweisung woertlich vorschreibt, galt als Inhalt — und
    #    ihre Entfernung, die Gate 3 VERLANGT, als Verlust.
    pruef("die Index-Zeile einer entfernten Datei ist ein Zeiger",
          zeigt_nur_auf("- [B](thema-b.md) — Aufhaenger B", {"thema-b"}), True)
    pruef("⛔ GEGENPROBE: zeigt sie auf eine GEBLIEBENE Datei, ist sie Inhalt",
          zeigt_nur_auf("- [A](thema-a.md) — Aufhaenger A", {"thema-b"}), False)
    pruef("⛔ GEGENPROBE: eine Zeile mit eigenem Text ist KEIN Zeiger",
          zeigt_nur_auf("Der Fehler kam von [[thema-b]] und kostete zwei Tage.",
                        {"thema-b"}), False)
    pruef("die Wikilink-Form wirkt unveraendert",
          zeigt_nur_auf("Siehe auch [[thema-b]].", {"thema-b"}), True)

    print()
    print("=== 9) ⭐ DER DOCS-ZUG (v5.115.0, Etappe 23 §8): Topic weg, Index zeigt auf docs/ ===")
    # Der Cleaner zieht ein Memory-Thema nach <projekt>/docs/<name>.md und setzt die
    # Indexzeile direkt darauf — kein Stub. Gate 3 muss den EXISTIERENDEN docs-Zeiger als
    # gueltig lesen, Gate 1/1b den ausgelagerten Inhalt als wiedergefunden.
    _t8 = tempfile.mkdtemp()
    try:
        _docs = os.path.join(_t8, "proj", "docs", "thema-b.md")
        _schreib(_docs, "# B\n\n" + "\n".join(["Satz B eins.", "Satz B zwei."]) + "\n")
        _IDX8 = ("# Memory\n\n- [A](thema-a.md) — Aufhaenger A\n- [B](%s) — umgezogen nach docs, lies zuerst `%s`\n"
                 % (_docs.replace("\\", "/"), _docs.replace("\\", "/")))
        for name, txt in {"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B}.items():
            _schreib(os.path.join(_t8, "v", "proj", name), txt)
        for name, txt in {"MEMORY.md": _IDX8, "thema-a.md": A}.items():
            _schreib(os.path.join(_t8, "n", "proj", name), txt)
        _e8 = pruefe_projekt("proj", os.path.join(_t8, "v", "proj"), os.path.join(_t8, "n", "proj"))
        _b8 = _e8[4] if _e8 else []
        pruef("DOCS-Zug: kein Gate gebrochen (Topic weg, Inhalt in docs/, Index zeigt dorthin)",
              gebrochen(_b8), [])
        pruef("   ... Gate 3 nennt den docs-Zeiger nicht als tot",
              any("gate 3 ok" in x for x in _b8), True)
        # Gegenprobe: die docs-Datei FEHLT -> Gate 3 (toter Zeiger) und 1b (Inhalt weg) rot
        os.remove(_docs)
        _e9 = pruefe_projekt("proj", os.path.join(_t8, "v", "proj"), os.path.join(_t8, "n", "proj"))
        _b9 = _e9[4] if _e9 else []
        pruef("   Gegenprobe: docs-Datei fehlt -> Gate 3 UND 1b gebrochen",
              any("GATE 3" in x for x in _b9) and any("1b" in x for x in _b9), True)
    finally:
        shutil.rmtree(_t8, ignore_errors=True)

    print()
    print("=== 10) v5.118.0 (Etappe 26 §2): flache Sicherung ist keine Messung ===")
    # Veras Lauf 22:41: <dir>/*.md statt <dir>/<slug>/*.md -> „0 Projekte · 0 gebrochen", gruen ohne Messung
    import subprocess as _sp
    _t10 = tempfile.mkdtemp()
    try:
        _schreib(os.path.join(_t10, "thema-a.md"), A)
        _r = _sp.run([sys.executable, os.path.abspath(__file__), _t10], capture_output=True)
        pruef("flache Sicherung -> rc 2", _r.returncode, 2)
        pruef("   ... und die Meldung nennt das Layout", b"kein Slug-Ordner" in _r.stdout, True)
        _r2 = _sp.run([sys.executable, os.path.abspath(__file__), os.path.join(_t10, "leer_" )], capture_output=True)
        pruef("   ... fehlende Sicherung bleibt rc 2", _r2.returncode, 2)
    finally:
        shutil.rmtree(_t10, ignore_errors=True)

    print()
    print("=== 11) v5.121.0 (Etappe 31): ein [[Wikilink]] auf ein umgezogenes Thema ist TOT — auch im Index ===")
    # Otto, 17.09.2026: `MEMORY.md:20` zeigte per [[karten-vereinheitlichung]] weiter auf das nach docs/
    # umgezogene Thema; das Gate zaehlte den Link als gueltig, weil die Indexzeile auf docs/ zeigt.
    # Claude Code loest [[name]] als memory/<name>.md auf — der docs-Zeiger rettet ihn nicht.
    _t11 = tempfile.mkdtemp()
    try:
        _docs11 = os.path.join(_t11, "proj", "docs", "thema-b.md")
        _schreib(_docs11, "# B\n\n" + "\n".join(["Satz B eins.", "Satz B zwei."]) + "\n")
        _IDXV = IDX + "\nAktueller Stand: [[thema-b]] (14.08.).\n"
        _IDXN_TOT = ("# Memory\n\n- [A](thema-a.md) — Aufhaenger A\n- [B](docs/thema-b.md) — Aufhaenger B (umgezogen nach docs, lies zuerst dort)\n"
                     "\nAktueller Stand: [[thema-b]] (14.08.).\n")
        _IDXN_OK = _IDXN_TOT.replace("[[thema-b]]", "`docs/thema-b.md`")
        _A_TOT = A + "\nSiehe [[thema-b]].\n"
        for name, txt in {"MEMORY.md": _IDXV, "thema-a.md": _A_TOT, "thema-b.md": B}.items():
            _schreib(os.path.join(_t11, "v", "proj", name), txt)
        # (1) der 16.09.-Fall: Index UND thema-a tragen den Wikilink weiter -> Gate 3 rot
        for name, txt in {"MEMORY.md": _IDXN_TOT, "thema-a.md": _A_TOT}.items():
            _schreib(os.path.join(_t11, "n", "proj", name), txt)
        _e11 = pruefe_projekt("proj", os.path.join(_t11, "v", "proj"), os.path.join(_t11, "n", "proj"),
                              wurzel=os.path.join(_t11, "proj"))
        _b11 = _e11[4] if _e11 else []
        pruef("der 16.09.-Fall: [[thema-b]] in MEMORY.md nach dem DOCS-Zug -> Gate 3 GEBROCHEN",
              any("GATE 3" in x and "MEMORY.md -> [[thema-b]]" in x for x in _b11), True)
        pruef("   ... und der Wikilink in thema-a.md ebenso",
              any("GATE 3" in x and "thema-a.md -> [[thema-b]]" in x for x in _b11), True)
        # (2) umgeschrieben (cleaner_plan v5.121.0): `docs/thema-b.md` statt [[thema-b]] -> gruen
        _schreib(os.path.join(_t11, "n", "proj", "MEMORY.md"), _IDXN_OK)
        _schreib(os.path.join(_t11, "n", "proj", "thema-a.md"), A + "\nSiehe `docs/thema-b.md`.\n")
        _e12 = pruefe_projekt("proj", os.path.join(_t11, "v", "proj"), os.path.join(_t11, "n", "proj"),
                              wurzel=os.path.join(_t11, "proj"))
        _b12 = _e12[4] if _e12 else []
        pruef("   Positivkontrolle: Wikilinks auf docs/ umgeschrieben -> kein Gate gebrochen", gebrochen(_b12), [])
        # (3) ein Wikilink, der SCHON VORHER ins Leere zeigte, ist kein Bruch dieses Laufs — nur Meldung
        _schreib(os.path.join(_t11, "v", "proj", "thema-a.md"), A + "\nSiehe [[nie-da]].\n")
        _schreib(os.path.join(_t11, "n", "proj", "thema-a.md"), A + "\nSiehe [[nie-da]].\n")
        _e13 = pruefe_projekt("proj", os.path.join(_t11, "v", "proj"), os.path.join(_t11, "n", "proj"),
                              wurzel=os.path.join(_t11, "proj"))
        _b13 = _e13[4] if _e13 else []
        pruef("   schon vorher toter Wikilink: Meldung, kein Gate-Bruch",
              gebrochen(_b13) == [] and any("schon vorher ins Leere" in x for x in _b13), True)
    finally:
        shutil.rmtree(_t11, ignore_errors=True)

    print()
    print("=== 12) Etappe 34: Gate 1 misst Marken, nicht Zeilen — Umbruch/Verdichtung gruen, verlorene Marke rot ===")
    # Ritas Verdichtung 17.09.2026 (hook-events-greifen-mid-session.md, 39 -> 37 Zeilen, coverage 26/26):
    # kein Fakt, keine Marke weg — das alte Gate 1 zaehlte Zeilen und sagte GEBROCHEN.
    _R_V = _topic("thema-r", ["Der Hook `stop.sh` feuerte um 01:19:30 in einer Sitzung,",
                              "die am Vortag begann — lange vor der Version, die das Event einfuehrte.",
                              "Gemessen am 17.08.2026 mit KEEP_VERSIONS=2, Beleg im Log."])
    _R_N = _topic("thema-r", ["Der Hook `stop.sh` feuerte um 01:19:30 in einer Sitzung, die am Vortag begann.",
                              "Gemessen 17.08.2026 mit KEEP_VERSIONS=2, Beleg im Log."])
    _b12 = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-r.md": _R_V},
                {"MEMORY.md": IDX, "thema-a.md": A, "thema-r.md": _R_N})
    pruef("Reflow/Verdichtung (3 -> 2 Zeilen, alle Marken da): kein Gate gebrochen", gebrochen(_b12), [])
    pruef("   ... die Bilanz weist die fehlenden markenfreien Woerter aus (kein Gate)",
          any("markenfrei" in x and "einfuehrte" in x for x in _b12), True)
    _R_W = _topic("thema-r", ["Der Hook `stop.sh` feuerte um 01:19:30 in einer Sitzung, die am Vortag begann."])
    _b13 = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-r.md": _R_V},
                {"MEMORY.md": IDX, "thema-a.md": A, "thema-r.md": _R_W})
    pruef("   Gegenprobe: die Zeile mit KEEP_VERSIONS=2 fehlt -> Gate 1 je Datei rot, nennt die Marke",
          any("GATE 1 je Datei" in x and "keep_versions" in x for x in _b13), True)
    pruef("   ... und das Summen-Gate 1 ebenso", any(x.startswith("GATE 1 (Erhaltung)") for x in _b13), True)

    print("=== 13) Etappe 38 §4 (Z397): Gate 2 nur beim ZUSAMMENFUEHREN — ein ADD-Lauf ist gruen ===")
    # 09.09.2026: `if neu:` machte jede neue Topic-Datei rot; 4.0c meint „nie in eine dritte, neue".
    C = _topic("thema-c", ["Satz C eins.", "Satz C zwei."])
    IDX_C = IDX + "- [C](thema-c.md) — Aufhaenger C\n"
    _b14 = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
                {"MEMORY.md": IDX_C, "thema-a.md": A, "thema-b.md": B, "thema-c.md": C})
    pruef("reiner ADD-Lauf (thema-c neu, nichts entfernt): kein Gate gebrochen", gebrochen(_b14), [])
    pruef("   ... Gate 2 nennt das Anlegen als ok", any(x.startswith("gate 2 ok: neue Datei") for x in _b14), True)
    IDX_AB = "# Memory\n\n- [AB](thema-ab.md) — Aufhaenger AB\n"
    ABn = _topic("thema-ab", ["Satz A eins.", "Satz A zwei.", "Satz B eins.", "Satz B zwei."])
    _b15 = lauf({"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B},
                {"MEMORY.md": IDX_AB, "thema-ab.md": ABn})
    pruef("   Gegenprobe: A+B in eine DRITTE Datei thema-ab -> Gate 2 rot",
          any(x.startswith("GATE 2 (kein Umbenennen) GEBROCHEN") for x in _b15), True)

    print()
    print("=== 14) v5.131.0 (Etappe 43 §1, Veras Fund 23.09.2026): Zeiger von den RULES ins Memory ===")
    # `routenplaner.md:1629` zeigte seit dem 16.09. auf `memory/routen-stand-15-08.md`, das ein Lauf
    # zusammengefuehrt hatte — eine Woche unbemerkt, weil Gate 3 nur INS Memory sah und die
    # Pfadpruefung der Rules nur das Projekt-Dateisystem. Gegen 5.130.0 sind die drei ersten Faelle rot.
    if _namens_suche() is None:
        print("  [--] UEBERSPRUNGEN: references/namens_suche.py nicht erreichbar "
              "(CLAUDE_PLUGIN_ROOT setzen). ⚠ Ein uebersprungener Fall ist KEIN bestandener.")
    else:
        _t14 = tempfile.mkdtemp()
        try:
            _pr = os.path.join(_t14, "proj")
            _schreib(os.path.join(_pr, "CLAUDE.md"),
                     "# P\n\nDer Stand steht in `memory/thema-b.md`.\n")
            _schreib(os.path.join(_pr, ".claude", "rules", "regel.md"),
                     "---\ndescription: x\n---\n\nZeile eins.\n\nSiehe `memory/thema-b.md` fuer den Rest.\n")
            _s14 = slug_von(_pr)          # der Slug, den dieses Projekt wirklich haette
            _v14 = os.path.join(_t14, "v", _s14); _n14 = os.path.join(_t14, "n", _s14)
            for _name, _txt in {"MEMORY.md": IDX, "thema-a.md": A, "thema-b.md": B}.items():
                _schreib(os.path.join(_v14, _name), _txt)
            for _name, _txt in {"MEMORY.md": IDX1, "thema-a.md": AB}.items():
                _schreib(os.path.join(_n14, _name), _txt)
            _e14 = pruefe_projekt(_s14, _v14, _n14, None, _pr)
            _b16 = _e14[4] if _e14 else []
            pruef("Rule zeigt auf die zusammengefuehrte Datei -> Gate 3 GEBROCHEN",
                  any("GATE 3" in x and "GEBROCHEN" in x for x in _b16), True)
            pruef("   ... die Meldung nennt Datei:Zeile und (Rules)",
                  any("regel.md:7" in x and "(Rules)" in x for x in _b16), True)
            pruef("   ... auch die CLAUDE.md-Fundstelle",
                  any("CLAUDE.md:3" in x for x in _b16), True)
            # Gegenprobe: dieselbe Lage, aber die Rule zeigt auf die UEBERLEBENDE Datei -> still
            _schreib(os.path.join(_pr, "CLAUDE.md"), "# P\n\nDer Stand steht in `memory/thema-a.md`.\n")
            _schreib(os.path.join(_pr, ".claude", "rules", "regel.md"),
                     "---\ndescription: x\n---\n\nZeile eins.\n\nSiehe `memory/thema-a.md`.\n")
            _e14b = pruefe_projekt(_s14, _v14, _n14, None, _pr)
            _b17 = _e14b[4] if _e14b else []
            pruef("   ⭐ Gegenprobe: Zeiger auf die ueberlebende Datei -> kein Gate-Bruch",
                  gebrochen(_b17), [])
            # Projekt nicht bestimmbar -> AUSGEWIESEN, nie still
            _e14c = pruefe_projekt("C--gibt-es-nicht-xyz", _v14, _n14, None, None)
            _b18 = _e14c[4] if _e14c else []
            pruef("   ⛔ Projekt nicht bestimmbar -> ausgewiesen statt still",
                  any("Rules-Zeiger ungeprueft" in x for x in _b18), True)
            # Altbestand: ein Zeiger, der schon vor diesem Lauf ins Leere ging
            _schreib(os.path.join(_pr, ".claude", "rules", "regel.md"),
                     "---\ndescription: x\n---\n\nZeile eins.\n\nSiehe `memory/laengst-weg.md`.\n")
            _schreib(os.path.join(_pr, "CLAUDE.md"), "# P\n\nnichts.\n")
            _e14d = pruefe_projekt(_s14, _v14, _n14, None, _pr)
            _b19 = _e14d[4] if _e14d else []
            pruef("   alter Zeiger ins Leere -> gemeldet, aber KEIN Gate-Bruch dieses Laufs",
                  any("schon vor diesem Lauf" in x for x in _b19) and not gebrochen(_b19), True)
            # ⛔ faellt das gemeinsame Modul aus, ist das eine LUECKE, keine Entwarnung
            _merk = os.environ.pop("CLAUDE_PLUGIN_ROOT", None)
            try:
                _e14e = pruefe_projekt(_s14, _v14, _n14, None, _pr)
                _b20 = _e14e[4] if _e14e else []
            finally:
                if _merk is not None:
                    os.environ["CLAUDE_PLUGIN_ROOT"] = _merk
            pruef("   ⛔ Modul nicht erreichbar -> ausgewiesen, kein gruenes Gate",
                  any("namens_suche.py nicht erreichbar" in x for x in _b20), True)
        finally:
            shutil.rmtree(_t14, ignore_errors=True)

    print()
    print("=== 15) v5.132.0 (Etappe 43 §3, Debug 522): NULL verglichene Projekte sind keine Messung ===")
    # Veras Lauf 23.09.2026 meldete „0 Projekte · 0 gebrochene Gates" und rc 0. Gemessen: der
    # Layout-Waechter aus v5.118.0 fragt `not _slugs and _flach` — EIN Fremdordner schaltet ihn ab.
    # Kein Rueckfall, ein Loch. Der Fall (2) ist gegen 5.131.0 rot.
    import subprocess
    _t15 = tempfile.mkdtemp()
    try:
        def _rc(ordner):
            r = subprocess.run([sys.executable, os.path.abspath(__file__), ordner],
                               capture_output=True)
            return r.returncode, (r.stdout + r.stderr).decode("utf-8", "replace")
        _f = os.path.join(_t15, "flach"); os.makedirs(_f)
        _schreib(os.path.join(_f, "a.md"), _topic("a", ["Satz eins."]))
        _r, _aus = _rc(_f)
        pruef("(1) rein flach -> rc 2 mit Layout-Satz", (_r, "kein Slug-Ordner" in _aus), (2, True))
        _fo = os.path.join(_t15, "flach mit ordner"); os.makedirs(os.path.join(_fo, "_verlauf"))
        _schreib(os.path.join(_fo, "a.md"), _topic("a", ["Satz eins."]))
        _schreib(os.path.join(_fo, "_verlauf", "alt.txt"), "x\n")
        _r, _aus = _rc(_fo)
        pruef("(2) ⛔ flach + EIN Fremdordner -> rc 2 KEINE MESSUNG (war rc 0 gruen)",
              (_r, "KEINE MESSUNG" in _aus), (2, True))
        _l = os.path.join(_t15, "leer"); os.makedirs(_l)
        pruef("(3) leerer Ordner -> rc 2", _rc(_l)[0], 2)
        _s = os.path.join(_t15, "richtig", "C--kein-projekt-dieses-namens"); os.makedirs(_s)
        _schreib(os.path.join(_s, "a.md"), _topic("a", ["Satz eins."]))
        _r, _aus = _rc(os.path.join(_t15, "richtig"))
        pruef("(4) ⭐ Slug-Layout -> MISST (rc 1, Gate gebrochen), keine Abweisung",
              (_r, "KEINE MESSUNG" in _aus), (1, False))
    finally:
        shutil.rmtree(_t15, ignore_errors=True)

    print()
    print("=== 16) v5.138.0 (Etappe 49 §1, Veras Fund Zustellplan 26.09.2026): der")
    print("        ALTBESTANDS-Hinweis lief nur, wenn etwas ENTFERNT wurde ===")
    # ⛔ Die gefaehrliche Haelfte des Baus vom 23.09.: der Lauf, der einen Zeiger toetet,
    #    meldet ihn — danach schweigt das Gate fuer immer, denn die meisten Laeufe entfernen
    #    nichts. Gemessen: Gate 3 sagte "ok", Veras Handpruefung fand zwei tote Zeiger.
    #    Faelle (1) und (3) sind gegen 5.137.0 rot.
    _t16 = tempfile.mkdtemp()
    _alt_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    try:
        def _lauf16(rules_text, memory_dateien, plugin_root=None):
            """Ein Projekt MIT Rules und ein Memory OHNE Entfernung -> Befunde."""
            pr = os.path.join(_t16, "proj-%d" % len(os.listdir(_t16)))
            _schreib(os.path.join(pr, ".claude", "rules", "zeiger.md"), rules_text)
            v = os.path.join(pr, "v"); nn = os.path.join(pr, "n")
            for name, txt in memory_dateien.items():
                _schreib(os.path.join(v, name), txt)
                # ⭐ NICHTS ENTFERNT, aber Inhalt GEAENDERT — das ist der haeufigste
                #   /mind-memory-Lauf. Identische Seiten kehren vorher als STILL zurueck,
                #   und dann wird Gate 3 nie erreicht: mein erster Anlauf war deshalb rot,
                #   ohne dass am Bau etwas fehlte.
                _schreib(os.path.join(nn, name), txt + u"Ein Satz mehr.\n")
            if plugin_root is None:
                os.environ["CLAUDE_PLUGIN_ROOT"] = _alt_root
            else:
                os.environ["CLAUDE_PLUGIN_ROOT"] = plugin_root
            e = pruefe_projekt(slug_von(pr), v, nn, wurzel=pr)
            return (e[4] if e else [])

        _mem = {"lessons.md": _topic("lessons", ["Satz eins."])}
        # (1) toter Zeiger, KEINE Entfernung -> Hinweis MUSS erscheinen
        _b = _lauf16("Siehe `memory/gibt-es-nicht.md` fuer den Rest.\n", _mem)
        pruef("(1) ⛔ toter Rules-Zeiger OHNE Entfernung -> Hinweis erscheint",
              any("schon vor diesem Lauf" in x for x in _b), True)
        # (2) Zeiger auf eine EXISTIERENDE Datei -> still
        _b = _lauf16("Siehe `memory/lessons.md`.\n", _mem)
        pruef("(2) ⭐ Zeiger auf vorhandene Datei -> KEIN Hinweis (sonst waere (1) wertlos)",
              any("schon vor diesem Lauf" in x for x in _b), False)
        # (3) ohne `namens_suche` darf es nicht STILL sein, sondern ausgewiesen
        # ⛔ Das Modul muss WIRKLICH entladen werden: `_namens_suche` bindet sich beim
        #    ersten Erfolg fest (`sys.modules`), ein kaputter CLAUDE_PLUGIN_ROOT allein
        #    macht den Import nicht kaputt — die Faelle (1)/(2) haben es schon geladen.
        #    Mein erster Anlauf war deshalb rot, ohne etwas zu pruefen.
        _mod_vorher = sys.modules.pop("namens_suche", None)
        _pfade_vorher = [p for p in sys.path if p.endswith("references")]
        for _p in _pfade_vorher:
            sys.path.remove(_p)
        try:
            _b = _lauf16("Siehe `memory/gibt-es-nicht.md`.\n", _mem, plugin_root="/gibt/es/nicht")
        finally:
            for _p in _pfade_vorher:
                sys.path.insert(0, _p)
            if _mod_vorher is not None:
                sys.modules["namens_suche"] = _mod_vorher
        pruef("(3) ⛔ ohne namens_suche -> AUSGEWIESEN, nicht still",
              any("Altbestands-Zeiger ungeprueft" in x for x in _b), True)
        # ⚠ RESTLUECKE, absichtlich als Fall festgehalten: ein Lauf, der GAR NICHTS aendert,
        #   kehrt als STILL zurueck und meldet den Altbestand nicht. Das zu aendern waere ein
        #   Eingriff in den STILL-Vertrag (Aufrufer zaehlen "unveraendert") — eigener Schnitt.
        #   Der Fall steht hier, damit die Luecke nicht als Versehen gelesen wird.
        pr4 = os.path.join(_t16, "proj-still")
        _schreib(os.path.join(pr4, ".claude", "rules", "zeiger.md"),
                 "Siehe `memory/gibt-es-nicht.md`.\n")
        for _d in ("v", "n"):
            _schreib(os.path.join(pr4, _d, "lessons.md"), _topic("lessons", ["Satz eins."]))
        os.environ["CLAUDE_PLUGIN_ROOT"] = _alt_root
        _e4 = pruefe_projekt(slug_von(pr4), os.path.join(pr4, "v"), os.path.join(pr4, "n"),
                             wurzel=pr4)
        pruef("(4) ⚠ BEKANNTE LUECKE: Lauf ohne JEDE Aenderung -> STILL, kein Hinweis",
              (_e4[0] if _e4 else None), "STILL")
    finally:
        if _alt_root:
            os.environ["CLAUDE_PLUGIN_ROOT"] = _alt_root
        else:
            os.environ.pop("CLAUDE_PLUGIN_ROOT", None)
        shutil.rmtree(_t16, ignore_errors=True)

    print()
    print("  %s" % ("alle Selbsttests bestanden" if not rot[0]
                    else "%d ROT" % rot[0]))
    return rot[0]


def main():
    if "--selbsttest" in sys.argv:
        return 1 if selbsttest() else 0
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    sicherung = sys.argv[1]
    nur = None
    if "--projekt" in sys.argv:
        nur = sys.argv[sys.argv.index("--projekt") + 1]
    # ⛔ `--nachher` ist KEINE Bequemlichkeit, sondern die Bedingung dafuer, dass
    #    dieses Skript ueberhaupt pruefbar ist. Mit fest verdrahtetem Ziel liesse
    #    sich kein Prueffall bauen — genau die Klasse `instrument-misst-nichts`,
    #    gegen die es gerichtet ist.
    nachher_wurzel = None
    if "--nachher" in sys.argv:
        nachher_wurzel = sys.argv[sys.argv.index("--nachher") + 1]
    benannt = []
    if "--entfernt" in sys.argv:
        benannt = benannte_entfernungen(sys.argv[sys.argv.index("--entfernt") + 1])
    wurzel = None   # v5.117.0: Projektwurzel fuer projektrelative docs-Zeiger im Index
    if "--wurzel" in sys.argv:
        wurzel = sys.argv[sys.argv.index("--wurzel") + 1]
    if not os.path.isdir(sicherung):
        print("Sicherung nicht gefunden: %s" % sicherung, file=sys.stderr)
        return 2

    heim = os.path.expanduser("~")
    rot = still = verglichen = 0
    print("=" * 74)
    print("  Memory-Gates — Sicherung gegen Ist-Stand")
    print("  vorher: %s" % sicherung)
    print("=" * 74)

    # ⛔ v5.118.0 (Etappe 26 §2, Veras Lauf 22:41): eine FLACHE Sicherung (<dir>/*.md statt
    #    <dir>/<slug>/*.md) ergab „0 Projekte · 0 gebrochen" — gruen ohne Messung. Jetzt rc 2.
    _slugs = [d for d in os.listdir(sicherung) if os.path.isdir(os.path.join(sicherung, d))]
    _flach = [f for f in os.listdir(sicherung) if f.endswith(".md")]
    if not _slugs and _flach:
        print("  ⛔ kein Slug-Ordner in %s — Layout? Erwartet <sicherung>/<slug>/*.md, gefunden %d .md direkt "
              "(rc 2, keine Messung)" % (sicherung, len(_flach)))
        return 2
    if not _slugs:
        print("  ⛔ leere Sicherung %s — kein Slug-Ordner, keine Datei (rc 2, keine Messung)" % sicherung)
        return 2
    for slug in sorted(os.listdir(sicherung)):
        vd = os.path.join(sicherung, slug)
        if not os.path.isdir(vd):
            continue
        if nur and nur not in slug:
            continue
        if nachher_wurzel:
            nd = os.path.join(nachher_wurzel, slug)
        else:
            nd = os.path.join(heim, ".claude", "projects", slug, "memory")
        e = pruefe_projekt(slug, vd, nd, benannt, wurzel)
        if e is None:
            continue
        verglichen += 1
        if e[0] == "STILL":
            still += 1
            continue
        _, s, av, an, befunde, entfernt, neu = e
        print()
        print("  %s" % s[:66])
        print("    Dateien %d -> %d   entfernt: %s   neu: %s"
              % (av, an, ", ".join(entfernt) or "(keine)", ", ".join(neu) or "(keine)"))
        for b in befunde:
            marke = "⛔" if "GEBROCHEN" in b else ("⚠ " if b.startswith("⚠") or "AUFFAELLIG" in b
                                                  or b.startswith("VERWAIST") else "  ")
            print("    %s %s" % (marke, b))
            if "GEBROCHEN" in b:
                rot += 1

    print()
    print("  %d Projekt(e) unveraendert · %d gebrochene Gates" % (still, rot))
    # ⛔ v5.132.0 (Etappe 43 §3, Veras Lauf 23.09.2026, Debug 522): NULL VERGLICHENE PROJEKTE
    #    SIND KEINE MESSUNG. Der Layout-Waechter oben fragt `not _slugs and _flach` — ein
    #    einziger Fremdordner (`_verlauf/`, `.git/`) macht `_slugs` nichtleer und schaltet ihn ab;
    #    gemessen ergab das rc 0 und „0 Projekt(e) unveraendert · 0 gebrochene Gates", byteweise
    #    Veras Wortlaut. ⛔ KEIN Rueckfall des v5.118.0-Fixes — ein Loch in seiner Bedingung.
    #    Diese Pruefung liegt eine Ebene hoeher und faengt JEDEN Aufruf, der seinen Gegenstand
    #    nicht beruehrt hat: falsches Gruen kostet die Messung, „nicht messbar" eine Nachfrage.
    if verglichen == 0:
        print("  ⛔ KEINE MESSUNG: kein einziges Projekt verglichen (rc 2). Geprueft wurde gegen %s; "
              "erwartet <sicherung>/<slug>/*.md mit einem Slug, den es unter ~/.claude/projects "
              "(oder --nachher) auch gibt." % (nachher_wurzel or os.path.join(heim, ".claude", "projects")))
        return 2
    if rot == 0:
        print("  ⚠ NULL gebrochene Gates heisst NICHT 'sicher' — die Gates greifen hier")
        print("    NACHTRAEGLICH. Im Skill stehen sie als Prosa und werden VOR dem")
        print("    Schreiben von nichts geprueft. .claude/rules/backup-usage.md.")
    return 1 if rot else 0


if __name__ == "__main__":
    sys.exit(main())
