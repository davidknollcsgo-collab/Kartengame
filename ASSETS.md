# Asset-Register

Verzeichnis **jeder** Datei im Projekt, die kein selbst geschriebener Quelltext
ist: Grafik, Ton, Schrift, Video.

Zweck ist nicht Ordnungsliebe. Bei einer Copyright-Beschwerde gegen eine
Play-Store-App ist dieses Dokument der Nachweis der Herkunft. Ohne es steht
Aussage gegen Aussage, und die App ist in der Zwischenzeit offline.

## Herkunft von TEN THOUSAND

Das Spiel ist **vollständig in diesem Repository entstanden**. Es gibt kein
Vorbild, von dem etwas übernommen wurde — weder Code noch Grafik, Ton,
Figuren, Namen, Texte, Titel oder Store-Material.

Das gilt ausdrücklich auch für die Bildsprache. Tuschemalerei ist eine
jahrhundertealte Technik und als solche gemeinfrei; was hier auf dem Blatt
steht, ist trotzdem keine Kopie irgendeines Blattes, sondern das Ergebnis von
`Tusche.band()` — ein Dreiecksnetz mit wandernder Breite und Deckung. Es gibt
kein Original in einem Grafikprogramm, weil es keines gibt.

**Kein Reverse Engineering, kein Asset-Rip, kein Nachzeichnen nach Vorlage.**
Auch das Abmalen erzeugt eine Bearbeitung und ist ohne Zustimmung unzulässig.

Vorgänger dieses Repositories waren NEKTON (Tiefsee) und HUNDRED CUTS (ein
Timing-Duell), beide vom selben Autor. Beide sind gelöscht; aus ihnen stammen
weder Assets noch Zeichnungen. Was aus ihnen weitergilt, sind gemessene
Eigenschaften der Engine und der Umgebung, und die stehen in `CLAUDE.md`.

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

Derzeit **keine Bilddateien im Projekt** (außer dem App-Symbol, siehe unten).
Die gesamte Darstellung entsteht zur Laufzeit aus `_draw()`-Aufrufen. Es gibt
keinen Shader mehr — Tusche braucht keinen:

| Was | Wo |
|---|---|
| Alle Farben des Spiels, an einer Stelle | `scripts/daten/palette.gd` |
| Die zwölf Gewänder, je Held drei | `scripts/daten/skins.gd` |
| Der Gefährte: er trägt die Farben des Helden | `scripts/spiel/streiter.gd` |
| Der Pinsel selbst: Band, Zug, Strang, Klecks, Kranz, Schraffur, Wisch | `scripts/spiel/tusche.gd` |
| Held und Feinde: Masse, Glieder, Kante, Schatten, Sparfassung | `scripts/spiel/streiter.gd` |
| Das Pergament: Faser, Flecken, Gräser, Sold | `scripts/spiel/feld.gd` |
| Waffenspuren, Funken, Druckring, Zeichenreihenfolge nach y | `scripts/spiel/zug_lauf.gd` |
| Bedienbild, Tafeln, Knöpfe, Balken, Aufstiegskarten | `scripts/spiel/zug_hud.gd` |

Das ist Absicht und nicht nur eine Frage der Dateigröße: prozedural erzeugte
Optik hat genau eine Quelle — dieses Repository. Diese Dateien sind selbst
geschriebener Quelltext und stehen deshalb nicht in der Tabelle unten.

Die einzigen Bilddateien im Projekt sind die App-Symbole. Sie stammen noch aus
dem Vorgängerspiel und sind **offen**: `tools/symbol.gd` zeichnet den alten
Lichtkegel und gehört ersetzt, bevor irgendetwas in einen Laden geht. Auch das
Symbol ist gerechnet und nicht gemalt.

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| `symbol.png` | selbst erzeugt | dieses Projekt | eigen | `tools/symbol.gd` | 2026-08-29 |
| `symbol_192.png` | selbst erzeugt | dieses Projekt | eigen | `tools/symbol.gd` | 2026-08-31 |
| `symbol_hintergrund.png` | selbst erzeugt | dieses Projekt | eigen | `tools/symbol.gd` | 2026-08-31 |
| `symbol_vordergrund.png` | selbst erzeugt | dieses Projekt | eigen | `tools/symbol.gd` | 2026-08-31 |
| `symbol_einfarbig.png` | selbst erzeugt | dieses Projekt | eigen | `tools/symbol.gd` | 2026-08-31 |

Die vier zusaetzlichen Dateien sind der Android-Symbolsatz. Seit
Android 8 schiebt das System zwei Ebenen gegeneinander und schneidet
daraus die Form, die der Hersteller vorsieht — wer nur ein fertiges
Bild abgibt, bekommt es in ein weisses Kaestchen gesetzt. Alle fuenf
entstehen aus demselben Werkzeug und derselben `Schlund.beleuchtung()`.

## Ton

**Keine einzige Audiodatei im Projekt.** Alles entsteht zur Laufzeit in
`scripts/spiel/klang.gd` als `AudioStreamWAV` mit von Hand gefüllten Puffern:
der Hieb, der Treffer, der Bolzen, die Wunde, das Geldstück, der Aufstieg,
das Horn des Warlords und das Tippen im Menü. Metall entsteht dabei aus
**unharmonischen** Teiltönen — ganzzahlige Vielfache klingen nach Ton, krumme
nach Blech. Anfang und Ende jedes Puffers stehen konstruktionsbedingt auf
null; ein Puffer, der bei halber Auslenkung einsetzt, ist ein Knacks und kein
Schlag. Gedrosselt wird auch — in Minute neun fallen dreißig Feinde je
Sekunde. Null Audiodateien heißt null Lizenzrisiko.

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
