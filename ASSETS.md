# Asset-Register

Verzeichnis **jeder** Datei im Projekt, die kein selbst geschriebener Quelltext
ist: Grafik, Ton, Schrift, Video.

Zweck ist nicht Ordnungsliebe. Bei einer Copyright-Beschwerde gegen eine
Play-Store-App ist dieses Dokument der Nachweis der Herkunft. Ohne es steht
Aussage gegen Aussage, und die App ist in der Zwischenzeit offline.

## Herkunft von NEKTON

Vom Vorbild (Kingshot, Century Games) ist **ausschließlich die Struktur**
übernommen: casual Kernschleife vorn, Aufbauspiel dahinter, Kammern mit
Bauzeiten, gestufte Monetarisierung. Spielmechaniken und Regeln sind nicht
urheberrechtlich geschützt — geschützt ist die Ausdrucksform.

Aus dem Vorbild stammt **nichts** von Folgendem, und es darf auch nie
hineingelangen: Code, entpackte Dateien, Grafik, Modelle, Icons, UI-Layouts,
Animationen, Musik, Geräusche, Figuren, Namen, Story, Texte, Titel, Logo,
Schriftzug, Store-Grafiken oder Videomaterial. Kein Reverse Engineering, kein
Asset-Rip, kein Nachzeichnen nach Vorlage — auch das Abmalen erzeugt eine
Bearbeitung und ist ohne Zustimmung unzulässig.

Das Setting sichert die Grenze zusätzlich ab: Tiefseebiologie ist Natur und
nicht schützbar, es gibt keine anthropomorphen Figuren, und die Kategorie
spielt sonst in Mittelalter oder Schneewüste.

## Regeln

1. **Kein Asset ohne Eintrag.** Der Eintrag gehört in denselben Commit wie die
   Datei.
2. **Erlaubt sind nur:** selbst erzeugt · CC0 / Public Domain · SIL OFL (nur
   Schriften).
3. **Nicht erlaubt:** CC-BY (Namensnennung wird in Apps regelmäßig verletzt) ·
   CC-BY-SA (Copyleft) · „free for personal use" · Unity- oder
   Unreal-Asset-Store-Material · KI-Bildgeneratoren mit unklarer Rechtslage ·
   alles ohne eindeutig belegbare Lizenz.
4. **Im Zweifel nicht verwenden.** Eine unklare Lizenz ist ein Nein.

## Grafik

Derzeit **keine Bilddateien im Projekt**. Die gesamte Darstellung entsteht zur
Laufzeit aus `_draw()`-Aufrufen und eigenen GDShadern:

| Was | Wo |
|---|---|
| Wasser, Meeresschnee, Tiefenverlauf | `shaders/graben.gdshader` |
| Grabenwände, Nischen, Polypen, Wächter, Brut | `scripts/spiel/kolonie.gd` |
| Alle vier Räuberarten | `scripts/spiel/schwarm.gd` |
| Lichtkegel | `scripts/spiel/kegel.gd` |
| Funken und Trefferstrahlen | `scripts/spiel/funken.gd` |

Das ist Absicht und nicht nur eine Frage der Dateigröße: prozedural erzeugte
Optik hat genau eine Quelle — dieses Repository. Diese Dateien sind selbst
geschriebener Quelltext und stehen deshalb nicht in der Tabelle unten.

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| _(keine)_ | | | | | |

## Ton

Noch keiner. Geplant ist Synthese über `AudioStreamWAV` — null Audiodateien
heißt null Lizenzrisiko.

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| _(keine)_ | | | | | |

## Schriften

Beide unter SIL Open Font License 1.1, die das Einbetten in kommerzielle
Anwendungen ausdrücklich erlaubt. Unverändert übernommen. Die Lizenztexte
liegen als `OFL.txt` neben den Dateien und müssen mit ausgeliefert werden —
`export_presets.cfg` schließt sie über `include_filter` ein.

Noch nicht im Spiel verwendet: das HUD zeichnet vorerst mit Godots eingebauter
Standardschrift (Teil der Engine, MIT).

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| `schriften/bricolage/BricolageGrotesque.ttf` | Google Fonts | Mathieu Triay | OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/bricolagegrotesque | 2026-08-25 |
| `schriften/rajdhani/Rajdhani-Medium.ttf` | Google Fonts | Indian Type Foundry | OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/rajdhani | 2026-08-24 |
