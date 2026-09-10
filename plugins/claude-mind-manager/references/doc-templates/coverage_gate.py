#!/usr/bin/env python3
"""coverage_gate.py — belegt, ob Quellwissen in einer Zieldatei angekommen ist.

WOZU: Wurde Wissen aus mehreren Quelldateien in ein Zieldokument uebertragen (Referenzen ->
Leitfaden, Recherche -> Notiz, Rohmaterial -> Doku), soll Vollstaendigkeit GEMESSEN werden,
nicht behauptet. Das Skript zieht aus jeder Quelle sprachunabhaengige Pruefpunkte und sucht
sie im Zieltext.

Reines Markdown rein, Prozentzahl raus — keine Anbindung an irgendein Notiz-System.
(Hiess bis v5.2.2 `joplin_coverage_gate.py`; der Name behauptete eine Bindung, die es nie gab.)

⛔ DIE GEGENPROBE IST TEIL DES LAUFS, NICHT OPTIONAL.
Vor der eigentlichen Messung wird ein Stichwort geprueft, das nachweislich NICHT im Ziel steht.
Meldet das Gate dafuer "belegt", misst es nichts — dann bricht der Lauf ab und ALLE Ergebnisse
dieses Laufs sind ungueltig. Genau dieser Fehler (Treffer ueber eine beliebige Namensnennung)
steckte am 2026-08-16 real in `mind_check_tools_have_rules` und meldete ein totes Tool als PASS.

⚠ EHRLICHE GRENZE 1: Gemessen wird ERWAEHNUNG, nicht inhaltliche Treue. Ein Stichwort kann
vorkommen, waehrend der Punkt verstuemmelt uebertragen wurde. Das Gate schliesst AUSLASSUNGEN
aus, nicht VERFAELSCHUNGEN. Wer mehr behauptet, benutzt es falsch.

⚠ EHRLICHE GRENZE 2: Die absolute Prozentzahl allein ist wertlos. Gemessen 2026-08-16: gegen
einen Stand, in dem das Material nachweislich FEHLTE, meldete das Gate trotzdem 43 % — teils
echte thematische Ueberlappung, teils Zufallstreffer. Aussagekraeftig ist der ZUWACHS zwischen
Vorher- und Nachher-Stand. Bleibt die Zahl gleich, ist nichts angekommen — egal wie hoch sie ist.

Aufruf:
    python tools/coverage_gate.py <zieltext.md> <quelle1.md> [quelle2.md ...]

Rueckgabe: 0 = alle Pruefpunkte belegt · 1 = offene Punkte (einzeln gelistet)
           2 = falscher Aufruf · 3 = MESSUNG UNGUELTIG (Negativkontrolle hat angeschlagen)
"""
import io
import re
import sys
import unicodedata

# Windows-Konsole ist cp1252 und stirbt an Pfeilen/Umlauten aus den Quelldateien.
# (Eigene Regel, beim ersten Entwurf missachtet und prompt abgestuerzt.)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

NEG_CONTROL = "zzznichtvorhandenerbegriff"


# ⭐ DIE DREI MARKER-MUSTER STEHEN EINMAL. Sie werden von `checkpoints()` benutzt
#    UND von `markenfreie_bytes()` darunter. Zwei Definitionen von "Marke" waeren
#    zwei Instrumente, die sich widersprechen koennen — genau das, wovor
#    `werkzeuge-zuerst.md` warnt. Die Muster sind woertlich die von v5.3.0.
P_CODE = r"`([^`\n]{3,40})`"
P_ZAHL = r"\b\d[\d.,]*\s?(?:%|K\b|T/line|tokens?\b|lines?\b|Zeilen\b)"
P_NAME = r"\b(?:[A-Z][a-z]+[A-Z][A-Za-z]+|[A-Z]{4,})\b"


def hat_marke(zeile: str) -> bool:
    """Traegt diese Zeile etwas, das `checkpoints()` als Pruefpunkt zaehlen wuerde?"""
    return bool(re.search(P_CODE, zeile) or re.search(P_ZAHL, zeile)
                or re.search(P_NAME, zeile))


def markenfreie_bytes(text: str) -> int:
    """Bytes der Zeilen OHNE jede Marke — der Teil, den das Gate NICHT sieht."""
    return sum(len(z.encode("utf-8")) for z in text.split("\n") if not hat_marke(z))


def normalize(text: str) -> str:
    """Kleinschreibung + Umlaute/Akzente entfernen, damit ae/ä beide treffen."""
    text = text.lower()
    text = (text.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
                .replace("ß", "ss"))
    text = unicodedata.normalize("NFKD", text)
    return "".join(c for c in text if not unicodedata.combining(c))


def checkpoints(path: str):
    """Pruefpunkte einer Quelldatei — SPRACHUNABHAENGIGE Marker.

    Dieses Verfahren ist der dritte Entwurf. Die beiden verworfenen stehen hier, weil beide
    plausibel aussahen und trotzdem nichts massen:

    ⛔ ENTWURF 1 — EIN Stichwort je Pruefpunkt. Gemessen gegen einen Stand, in dem das Material
    nachweislich fehlte, meldete er **58,6 % belegt**: generische Woerter wie "detection" oder
    "estimation" treffen irgendwo immer. Ein Gate mit dieser Falsch-Positiv-Rate behauptet
    Abdeckung, statt sie zu zeigen — und faellt in die gefaehrliche Richtung.

    ⛔ ENTWURF 2 — mehrere Stichwoerter, aber aus dem QUELLTEXT gezogen (Ueberschriften, fett
    Markiertes). Die Quellen waren englisch, die Uebertragung deutsch. Ein Gate, das
    "programmatic"+"access" sucht, findet "Kein programmatischer Zugriff" nie — es meldete
    Vorher und Nachher fast identisch (4/13 in BEIDEN Faellen), obwohl der Abschnitt
    nachweislich uebertragen war. Die Messung war strukturell blind fuer ihren Gegenstand,
    und die unbewegte Zahl sah aus wie ein Befund.

    Was eine Uebersetzung UEBERLEBT und deshalb hier gezaehlt wird:
      - Zahlen mit Bedeutung:        22.5 · 7.5 · 167K · 96% · 71% · 14,000 · 200
      - Codebezeichner in Backticks: `globs:` · `MEMORY.md` · `@import` · `PreCompact`
      - Eigennamen/Produkte:         SFEIR · Cursor · Cline · Aider · Copilot
    Ein uebersetzter Text, der diese Marker nicht enthaelt, hat den Inhalt tatsaechlich nicht
    uebernommen — das ist der Punkt. Fliesstext-Substantive werden bewusst NICHT gezaehlt:
    die sind genau das, was beim Uebersetzen verschwindet.
    """
    out, seen = [], set()
    text = open(path, encoding="utf-8", errors="replace").read()

    # 1) Inline-Code — Bezeichner, Pfade, Frontmatter-Schluessel
    for m in re.findall(P_CODE, text):
        tok = normalize(m).strip()
        if len(tok) >= 4 and not tok.isdigit():
            out.append((f"`{m}`", (tok,)))

    # 2) Zahlen mit Aussage: Prozent, Tausender, K-Angaben, Dezimalwerte
    for m in re.findall(P_ZAHL, text):
        tok = normalize(re.sub(r"\s+", "", m))
        num = re.match(r"[\d.,]+", tok)
        if num and len(num.group(0).strip(".,")) >= 2:
            out.append((m.strip(), (num.group(0).rstrip(".,"),)))

    # 3) Eigennamen: GrossKleinSchreibung oder Versalien, technisch/Produkt
    for m in re.findall(P_NAME, text):
        out.append((m, (normalize(m),)))

    uniq = []
    for phrase, kw in out:
        if kw not in seen:
            seen.add(kw)
            uniq.append((phrase, kw))
    return uniq


# ⛔ DIE BREMSEN-ZEICHEN SIND KEINE MARKE — gemessen 11.09.2026 an der Kalibrierung
#    des Verdichtens: eine Handfassung verlor 2 ⛔ und 5 ⚠, drei ALLCAPS-Verbote
#    wurden Kleinschreibung, und dieses Gate meldete 78/78. P_CODE/P_ZAHL/P_NAME
#    sehen ⛔, ⚠, ⭐ nicht, und NIE/NUR/MUSS/KEIN sind kuerzer als die vier
#    Buchstaben, die P_NAME verlangt. Ein Lauf konnte also jedes Verbotszeichen
#    entfernen und 100 % melden.
# ⭐ IN das Instrument gebaut, nicht daneben — dieselbe Entscheidung wie bei
#    Stufe 2: dann gilt es fuer den Wissenstransfer genauso wie fuers Verdichten.
# ⛔ HART mit EINER OEFFNUNG: ein Marker DARF verschwinden, wenn er im Bericht
#    EINZELN BENANNT ist (`--entfernt <bericht.md>`, Zeilen wie
#    `entfernt: ⛔ „Die sync-Rolle ist …“`). Zaehlung minus benannte = 0, sonst rot.
#    Ein Gate, das jede Entfernung verbietet, verbietet richtiges Aufraeumen; eines,
#    das sie STILL durchlaesst, ist Modus E. Benannt ist die Deckel-Doktrin:
#    erlaubt, ausgewiesen.
MARKER = (("⛔", "⛔"), ("⚠", "⚠"), ("⭐", "⭐"))
P_VERBOT = r"\b(?:NIE|NIEMALS|NUR|MUSS|KEINE?|NEVER|MUST|ALWAYS)\b"


def marker_zaehlung(text: str):
    z = {name: text.count(zeichen) for name, zeichen in MARKER}
    z["VERBOT"] = len(re.findall(P_VERBOT, text))
    # weich, nur Ausweis: Absaetze, die mit ⛔ BEGINNEN — geht einer in einem
    # Nachbarn auf, sinkt diese Zahl, waehrend die ⛔-Zaehlung gleich bleiben kann.
    z["⛔-Absaetze"] = sum(1 for a in re.split(r"\n\s*\n", text)
                          if a.lstrip().startswith("⛔"))
    return z


def benannte_entfernungen(pfad):
    """Wie viele Marker der Bericht als 'entfernt: <zeichen>' EINZELN benennt."""
    out = {name: 0 for name, _ in MARKER}
    out["VERBOT"] = 0
    if not pfad:
        return out
    try:
        t = open(pfad, encoding="utf-8", errors="replace").read()
    except OSError:
        return out
    for zeile in t.splitlines():
        if not re.match(r"\s*entfernt\s*:", zeile):
            continue
        rest = zeile.split(":", 1)[1]
        for name, zeichen in MARKER:
            if zeichen in rest:
                out[name] += 1
        if re.search(P_VERBOT, rest):
            out["VERBOT"] += 1
    return out


def main(argv):
    # --entfernt <datei> herausloesen, bevor die Positionsargumente gelesen werden
    entfernt_pfad = None
    argv = list(argv)
    if "--entfernt" in argv:
        i = argv.index("--entfernt")
        if i + 1 < len(argv):
            entfernt_pfad = argv[i + 1]
            del argv[i:i + 2]
        else:
            del argv[i]
    if len(argv) < 3:
        print("Aufruf: coverage_gate.py <ziel.md> <quelle.md> [...] [--entfernt <bericht.md>]")
        return 2

    target = normalize(open(argv[1], encoding="utf-8", errors="replace").read())

    # --- Gegenprobe zuerst: die Messung muss scheitern koennen ---
    if NEG_CONTROL in target:
        print("ABBRUCH: Negativkontrolle im Ziel gefunden — Messung unbrauchbar.")
        return 3
    print("Gegenprobe: Kontrollbegriff NICHT im Ziel -> das Gate kann scheitern. OK\n")

    total_ok = total = 0
    for src in argv[2:]:
        pts = checkpoints(src)
        missing = [(p, k) for p, k in pts if not all(t in target for t in k)]
        ok = len(pts) - len(missing)
        total_ok += ok
        total += len(pts)
        name = src.replace("\\", "/").split("/")[-1]
        print(f"{name}: {ok}/{len(pts)} belegt")
        for phrase, kw in missing:
            print(f"    OFFEN  [{'+'.join(kw)}]  {phrase}")
        if missing:
            print()

    pct = (100 * total_ok / total) if total else 0
    print(f"\nGESAMT: {total_ok}/{total} Pruefpunkte belegt ({pct:.1f} %)")
    print("HINWEIS: gemessen wurde ERWAEHNUNG, nicht inhaltliche Treue.")

    # --- STUFE 2: der AUSWEIS (NEU 10.09.2026) ---------------------------
    # ⛔ WARUM DAS NOETIG WURDE. Gemessen am 10.09.2026: eine markenERHALTENDE
    #    Verdichtung entfernte **34 % von `werkzeuge-zuerst.md` — und dieses Gate
    #    meldete 100 %**. Das ist kein Fehler; die Zeile darueber sagt seit jeher
    #    "Erwaehnung, nicht Treue". Nur konnte niemand SEHEN, wieviel dabei
    #    ungeprueft blieb.
    #
    # ⛔ DAS HIER IST KEIN GATE UND WIRD NIE EINS. Markenfreien Text zu entfernen
    #    ist genau das, was eine gute Verdichtung TUN soll — ein Schwellwert
    #    darauf wuerde jeden gelungenen Lauf anschwaerzen. Es MELDET eine Zahl.
    #    Der Rueckgabewert bleibt unberuehrt.
    #
    # ⭐ DAS VORBILD IST DIE DECKEL-SCHULD: man darf anlegen, man muss es
    #    ausweisen. Hier: man darf verdichten, man muss ausweisen, wieviel davon
    #    kein Instrument geprueft hat.
    try:
        ziel_txt = open(argv[1], encoding="utf-8", errors="replace").read()
        quell_txt = "".join(open(s, encoding="utf-8", errors="replace").read()
                            for s in argv[2:])
        mf_q = markenfreie_bytes(quell_txt)
        mf_z = markenfreie_bytes(ziel_txt)
        weg = mf_q - mf_z
        if weg > 0:
            anteil = (100.0 * weg / mf_q) if mf_q else 0.0
            print(f"AUSWEIS: markenfrei entfernt: {weg} B von {mf_q} B ({anteil:.1f} %)")
            print(f"⚠ Diese {weg} B hat KEIN Instrument geprueft — sie muessen gelesen"
                  " werden, sonst gilt der Lauf als ungeprueft.")
        else:
            # ⚠ Auch das wird GESAGT. Ein stiller Ausweis ist von einem fehlenden
            #   nicht zu unterscheiden — dieselbe Klasse wie ein Hook, der
            #   schweigt, weil er tot ist.
            print(f"AUSWEIS: markenfrei entfernt: 0 B von {mf_q} B "
                  f"(Ziel traegt {-weg} B mehr)")
    except OSError as e:
        # ⛔ FAIL-OPEN, aber LAUT: der Ausweis darf das Gate nie toeten.
        print(f"⚠ AUSWEIS nicht messbar ({e}) — die Stufe-1-Aussage gilt trotzdem.")

    # --- MARKER-ZAEHLUNG (NEU 11.09.2026) — hart, mit der benannten Oeffnung ---
    marker_rot = False
    try:
        mq = marker_zaehlung(quell_txt)
        mz = marker_zaehlung(ziel_txt)
        benannt = benannte_entfernungen(entfernt_pfad)
        teile = []
        for k in ("⛔", "⚠", "⭐", "VERBOT"):
            fehl = max(0, mq[k] - mz[k])
            offen = fehl - benannt[k]
            teile.append(f"{k} {mq[k]}->{mz[k]}" + (f" (benannt {benannt[k]})" if benannt[k] else ""))
            if offen > 0:
                marker_rot = True
                print(f"⛔ MARKER VERLOREN: {offen}x {k} weniger als in der Quelle, "
                      f"und im Bericht NICHT benannt.")
        print("MARKER: " + " · ".join(teile) + ("" if marker_rot else "   OK"))
        # weich — nur Ausweis, kein Rueckgabewert
        if mz["⛔-Absaetze"] < mq["⛔-Absaetze"]:
            print(f"⚠ AUSWEIS: ⛔-Absaetze {mq['⛔-Absaetze']} -> {mz['⛔-Absaetze']} — "
                  f"mindestens einer ist in einem Nachbarn aufgegangen. Kein Gate, ein Blick.")
        if marker_rot:
            print("   Ein Bremsen-Zeichen darf verschwinden — aber nur BENANNT:"
                  " `entfernt: ⛔ „…“` im Bericht, dann --entfernt <bericht>.")
    except NameError:
        print("⚠ MARKER nicht messbar — Quelltexte fehlen.")

    if marker_rot:
        return 1
    return 0 if total_ok == total else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
