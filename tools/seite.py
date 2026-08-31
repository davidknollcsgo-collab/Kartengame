#!/usr/bin/env python3
"""Baut die Zusatzseiten fuer GitHub Pages aus den Markdown-Dateien.

    python3 tools/seite.py docs

**Warum ein eigenes Werkzeug und kein fertiger Umwandler.** Der Play Store
verlangt fuer die Datenschutzerklaerung eine oeffentlich erreichbare Adresse.
Die Seite dieses Projekts liegt ohnehin auf GitHub Pages, also gehoert sie
dorthin - aber `PRIVACY.md` ist die Fassung, die gepflegt wird, und zwei
Fassungen desselben Textes laufen frueher oder spaeter auseinander. Also wird
die Seite aus der Markdown-Datei erzeugt und nicht daneben geschrieben.

Der Umfang ist bewusst winzig: Ueberschriften, Absaetze, Tabellen, fette
Stellen. Mehr braucht dieser Text nicht, und eine Abhaengigkeit fuer vier
Zeilen Auszeichnung waere die teurere Loesung.
"""

import html
import re
import sys
from pathlib import Path

VORLAGE = """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titel}</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{
    margin: 0 auto; padding: 2.4rem 1.2rem 5rem; max-width: 42rem;
    background: #06121a; color: #cfe2e8; line-height: 1.65;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  }}
  h1 {{ color: #9fe8f5; font-size: 1.7rem; margin: 0 0 .4rem; }}
  h2 {{ color: #7fc9d8; font-size: 1.15rem; margin: 2.2rem 0 .6rem; }}
  em {{ color: #7e979e; font-style: normal; font-size: .9rem; }}
  strong {{ color: #eaf7fb; }}
  a {{ color: #6fd2e8; }}
  table {{ border-collapse: collapse; width: 100%; margin: 1rem 0; }}
  td {{ border-top: 1px solid #17323f; padding: .5rem .6rem; }}
  td:first-child {{ color: #9ab6be; }}
</style>
{inhalt}
"""


def _inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"_(.+?)_", r"<em>\1</em>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return text


def umwandeln(quelle: Path) -> tuple[str, str]:
    titel = quelle.stem
    zeilen = quelle.read_text(encoding="utf-8").splitlines()
    aus: list[str] = []
    absatz: list[str] = []
    in_tabelle = False

    def absatz_schliessen() -> None:
        if absatz:
            aus.append("<p>%s</p>" % _inline(" ".join(absatz)))
            absatz.clear()

    def tabelle_schliessen() -> None:
        nonlocal in_tabelle
        if in_tabelle:
            aus.append("</table>")
            in_tabelle = False

    for zeile in zeilen:
        z = zeile.rstrip()
        if z.startswith("|"):
            absatz_schliessen()
            felder = [f.strip() for f in z.strip("|").split("|")]
            # Die Trennzeile einer Markdown-Tabelle traegt keine Werte.
            if all(set(f) <= set("-: ") for f in felder):
                continue
            if not in_tabelle:
                aus.append("<table>")
                in_tabelle = True
            aus.append("<tr>%s</tr>" % "".join(
                "<td>%s</td>" % _inline(f) for f in felder))
            continue
        tabelle_schliessen()
        if not z:
            absatz_schliessen()
        elif z.startswith("## "):
            absatz_schliessen()
            aus.append("<h2>%s</h2>" % _inline(z[3:]))
        elif z.startswith("# "):
            absatz_schliessen()
            titel = z[2:].strip()
            aus.append("<h1>%s</h1>" % _inline(titel))
        else:
            absatz.append(z)
    absatz_schliessen()
    tabelle_schliessen()
    return titel, "\n".join(aus)


def main() -> int:
    ziel = Path(sys.argv[1] if len(sys.argv) > 1 else "docs")
    ziel.mkdir(parents=True, exist_ok=True)
    for quelle, name in [(Path("PRIVACY.md"), "privacy.html")]:
        if not quelle.exists():
            print("fehlt: %s" % quelle, file=sys.stderr)
            return 1
        titel, inhalt = umwandeln(quelle)
        (ziel / name).write_text(
            VORLAGE.format(titel=html.escape(titel), inhalt=inhalt),
            encoding="utf-8")
        print("Seite geschrieben: %s" % (ziel / name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
