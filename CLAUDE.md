# Hinweise für Claude Code

## Was hier gebaut wird

**TEN THOUSAND** — einer gegen die Horde.

Von oben, ein Held, hundert Feinde. Der Finger führt **nur den Mann**; die
Waffen schlagen von selbst. Was man entscheidet, ist die Aufstellung — wohin
man läuft, wen man vor sich lässt, wann man durch eine Lücke geht — und bei
jedem Aufstieg eines von drei Angeboten. Zehn Minuten, dann steht der Warlord
da.

Drei Ebenen dahinter, und jede beantwortet eine andere Frage:

* **Die Burg** (`Halle`) ist die stetige Kurve: Mauer, Schmiede, Stall, Münze.
* **Die Ausrüstung** (`Ausruestung`) ist die Fundfreude: vier Plätze, acht
  Stücke, ein Fund nach jedem Lauf — auch nach einem kurzen.
* **Die Helden** (`Helden`) sind die Abwechslung: vier Klassen, jede mit
  **genau einer** Eigenart, freigeschaltet an Taten statt an Sold. Dazu
  zwölf **Gewänder** (`Skins`), ebenfalls an Taten, und sie ändern nur Farben.

**Es gab vor September 2026 zwei andere Spiele in diesem Repository** —
NEKTON (Tiefsee, Lichtkegel) und HUNDRED CUTS (ein Timing-Duell). Beide sind
gelöscht. Wer in älteren Commits über `rundlauf.gd`, `schwarm.gd`, `duell.gd`
oder `fechter.gd` stolpert: die gibt es nicht mehr. **Eine Schleife, eine
Wahrheit.**

Alles Sichtbare und Hörbare entsteht in diesem Repository: Grafik prozedural
(`Tusche`), Ton synthetisiert (`Klang`). `ASSETS.md` ist der Nachweis — es
gibt **keine einzige Bilddatei** außer den App-Symbolen.

### Der Artstyle: farbig, umrandet, mit Schatten

Ruhiger entsaettigter Grund, **farbige Figuren mit dunkler Kante**, ein
Schlagschatten unter jeder, **Zinnober nur für Schaden am Spieler** und
**Gold nur für Sold**. Alle Farben stehen an **einer** Stelle
(`scripts/daten/palette.gd`), und ein Wächter prueft sie.

**Hier stand bis September 2026 ein Holzschnitt auf Pergament** — alles
schwarze Tusche, und die Regel dazu lautete: *eine Sorte muss an ihrer
Silhouette erkennbar sein, nicht an ihrer Farbe.* Sie war in sich schluessig
und im Gedraenge unbrauchbar, und zwar aus einem Grund, der im Code stand:
ab `Streiter.DICHT_AB` Figuren schaltet **jede** davon auf die Sparfassung,
und die wirft die Silhouette weg. Die Regel verlangte genau das, was das Bild
in seinem dichtesten Moment nicht mehr liefern konnte. Uebrig blieben achtzig
gleiche schwarze Umrisse, und einer davon war der Spieler selbst.

Sechs Regeln, die für **jede** neue Zeichnung hier gelten:

* **Kein Strich hat zwei gleiche Enden.** Ein Band gleicher Breite ist ein
  Klebestreifen; ein Pinsel setzt auf, trägt und hebt ab.
* **Erst die Masse, dann die Glieder.** Wer mit den Gliedern anfängt, baut ein
  Skelett und hängt danach vergeblich Kleider daran.
* **Ein Glied ist ein Strang, keine zwei Züge** — sonst hat es am Gelenk eine
  Kerbe, und eine Kerbe ist eine Kante, wo ein Übergang hingehört.
* **Jede Sorte hat ihre eigene Farbe, und die des Helden hat niemand sonst.**
  Das ist die Frage, die ein Spieler bei hundertfünfzig Figuren alle zwei
  Sekunden stellt: *wo bin ich?* Geprueft wird als Abstand im Farbraum und
  nicht als Ungleichheit von drei Fließkommazahlen.
* **Jede Figur hat eine Kante und einen Schatten.** Die Kante trennt sie von
  der Figur daneben, der Schatten vom Boden darunter — ohne den schwebt in
  einem Bild ohne Perspektive alles.
* **Jede Figur hat eine Licht- und eine Schattenseite** (`Palette.LICHT`,
  von links oben). `Tusche.band()` färbt die Körperreihen eines Strichs mit
  Kante zum Licht hin heller und davon weg dunkler, `klecks()` ebenso über
  den Randwinkel — **null zusätzliche Eckpunkte**. Bis Oktober 2026 hatte
  jede Figur eine flache Farbe, und der Nutzer fand zu Recht, das Bild wirke
  wie eine Skizze. Dazu tragen die Figuren **Kleidung statt Strich**:
  Waffenrock, der unter der Hüfte beginnt, Gürtel, Arme mit Ellbogen und
  Kante, Stiefel; der Held einen Umhang und Helm mit Sehschlitz, der Warlord
  Umhang, Kamm und Brustplatte.

  **Gemessen, nicht geraten** (je Figur, Höhe 104, Voll/Spar):
  Strolch 331/160 → 459/187, Ritter 518/200 → 730/227, Warlord 596/200 →
  997/227, Held 451 → 751. Im echten Lauf (Minute 6, 300 Feinde, gleiche
  Saat) braucht `_draw` damit 34–37 ms statt 31–35 ms je Bild. Der erste
  Anlauf rief die Lichtfunktion je Eckpunkt auf und kostete im Netzbau
  +70 % (300 Sparfiguren 26 → 45 ms); **eine Rechnung je Strich, dazwischen
  nur `lerp`**. Und die
  Sparfassung bekam einen Arm (ohne ihn war sie ein Strichmännchen ohne
  Hände), aber keinen Gürtel — er kostete ein Siebtel der Eckpunkte und war
  auf zwanzig Bildpunkten nicht zu sehen.

  **Gezeichnet wird, was im Bild steht** (`zug_lauf._im_bild`). `sichtbar`
  schnitt bei ±720 Punkten in beide Richtungen zu — ein Quadrat von 1440 für
  ein Bild von 720 Breite —, und jede Figur links und rechts daneben wurde
  gebaut, sortiert und weggeworfen. An das Sichtfeld gebunden (Figuren ragen
  nach oben, also unten Rand nach ihrer Höhe): `_draw` in Minute 6 bei 300
  Feinden **35 → 15 ms** je Bild. Das ist der Spielraum für alles, was danach
  an Zeichnung kam.

**Was im Oktober 2026 dazukam** („die Grafik des ganzen Spiels“), und die
Regeln, die dabei entstanden:

* **Ein Schlag hat ein Bild.** `Vorfall.SCHLAG` trägt die Richtung, die das
  Gefecht gerechnet hat, und `zug_lauf._zeichne_hiebe` zeichnet daraus Sichel
  (Schwert), Stoß (Speer) und Bodenwelle (Hammer); Bolzen und Äxte haben
  Form, der Flegel Kettenglieder. **Eine Rechnung, nicht zwei** — das Bild
  nimmt `weite_von`/`bahn_von` des Gefechts.
* **Jeder Held sieht aus, wie er kämpft** (`Streiter.held(..., klasse)`):
  Rundschild, Kapuze mit Köcher und Armbrust, Lederkappe mit langem Speer,
  breiter Hammerträger mit Topfhelm. Die Hand führt **nur die Startwaffe**,
  jede Klasse mit eigener Ruhe und eigenem Schlag. Gold stand an der
  Parierstange — Gold heißt Sold, jetzt Stahl.
* **Tod, Treffer und Lohn sind zu sehen**: Gefallene liegen 0,7 s
  (höchstens 40), Treffer splittern, der Held blitzt in Zinnober und der
  Bildrand mit, Münzen glänzen, Aufsammeln und Aufstieg geben einen Ring.
* **Effekte ziehen nie aus dem Zufall der Simulation** (`_zier` statt
  `_rng`). Der erste Anlauf nahm denselben Generator: jedes Staubwölkchen
  verschob den Lauf, dieselbe Saat zeigte eine andere Szene, und eine
  Zeitmessung „vorher/nachher“ verglich zwei Gefechte — sie sah nach
  doppelten Kosten aus.
* **Die Nächsten voll, der Rest als Vorlage** (`VOLL_NAH` 40,
  `Tusche.vorlage()`/`setze()`). Die Sparfassung bewegt sich nicht, wurde
  aber in jedem Bild Eckpunkt für Eckpunkt in GDScript gebaut — bei 260
  Figuren gut dreißig Millisekunden. Jetzt einmal je Sorte und Blick, zu
  flachen Dreiecken ausgerollt und mit **einer** eingebauten Multiplikation
  verschoben. Flach, weil ein Index je Vorlage um ihren Platz verschoben
  werden müsste, und das wäre wieder eine Schleife je Eckpunkt. Wer gerade
  aufblitzt, wird frisch gezeichnet.

  **Gemessen, alles zusammen** (Saat 7, Debug-Build in diesem Container,
  Median je Bild): Minute 1 **13–14 ms**, Minute 6 (300 Feinde) **22–23 ms**
  statt 34–36 ms vor dem ganzen Durchgang, Minute 9 18–27 ms (zwei Läufe,
  so weit streut es). `VOLL_NAH` 24 kostete 21 ms, 60 schon 30 ms.
  **Messungen nacheinander**, nie parallel: zwei gleichzeitige Läufe
  verfälschen sich gegenseitig.
* **Menüs haben Bilder** (`Zeichen`, 27 Stück auf `Tusche`): Waffen, Züge,
  Bauten, Ausrüstung, Herz, Münze, Schädel. Der Titel zeigt den Helden
  zwischen den Sorten, jede Heldenkarte ihren Helden (gesperrte als
  Schatten), der Bericht ein Bild. Schrift: **Bricolage fett** für Titel,
  Namen und Knöpfe, **Rajdhani** für Zahlen, Fließtext Standardschrift.
* **Ein Blatt ist ein Riegel, kein Wisch.** Der Aufstieg blendete mit
  `wisch()` aus, und der läuft spitz aus: unter den Karten stand ein Keil.
  Wo eine Fläche den Schirm deckt, `_riegel`; wo etwas zu den Seiten
  auslaufen soll (Boden unter einer Szene), `wisch`.
* **Der Boden hat Pfade**, die an Gitterlinien hängen und sich über
  Kacheln fortsetzen, **Stoß an Stoß** (überlappende halbdurchsichtige
  Stücke gaben an jeder Kachelgrenze einen Querstreifen), dazu Steingruppen
  mit halber Kante, Büsche, Stümpfe, Kiesel. Halbe Kante, weil eine volle
  eine Figur wäre.

**Und danach: Pixel-Art nach einer Vorlage des Nutzers** (Oktober 2026).
Der Nutzer schickte ein Mockup — Landkarte aus Sand, Wiese, Bäumen, kleine
Pixel-Soldaten, Menüs als gerahmtes Pergament — und wählte: Pixel-Look,
Sortenfarben bleiben (satter), Kamera etwas weiter weg.

* **Das Feld wird in einem Drittel der Auflösung gezeichnet**
  (`gefecht.tscn`: zwei `SubViewportContainer` mit `stretch_shrink` =
  `zug_lauf.PIXEL` = 3, scharf hochgezogen). Boden und Figuren liegen in
  **zwei** Puffern; die Menüs bleiben scharf im `CanvasLayer`. Der Wurzelknoten
  zeichnet nichts mehr: `welt.gd` (drei Teile, Hinten / Loch / Vorn) fragt
  `zug_lauf.zeichne_teil()`.
* **Der Umriss kommt aus dem Bild, nicht aus dem Pinsel**
  (`shaders/umriss.gdshader`): jedes leere Pixel neben einem gedeckten wird
  dunkel — ein Pixel Umriss um jede Figur und jede Gruppe. Der Puffer ist
  vormultipliziert, der Shader teilt durch die Deckung.
* **Die Kante im Pinsel hat im Pixelbild feste Breite** (`Tusche.kante_fest`,
  `mindest`): als Bruchteil des Strichs war sie unter einem Pixel und
  verschwand, gleichfarbige Figuren flossen zu einem Klumpen, und
  Speerschäfte zerfielen in Punkte. Ausnahme ist der **Wolf** — zwanzig
  Pixel lang, Läufe zwei breit: mit einem Pixel Kante je Seite bestand er
  nur aus Umriss.
* **Die Freistellung ist ein Loch** (Teil 1, `shaders/loch.gdshader`,
  `blend_disabled`): sie schreibt Deckung null in den Figurenpuffer, und der
  wirkliche Boden scheint durch. Eine Fläche in `BODEN` wäre auf einer Wiese
  ein Sandfleck.
* **Eine Wahrheit für das Sichtfeld**: `Gefecht.BILD_HALB_X/_Y` (450 × 800
  bei 720 × 1280, `ZOOM` 0,8). Eintritt, Nachholen, Leine, `Daumen.SICHT`
  und die Wächter, die zählen, was im Bild steht, hängen daran.
* **Ein Pixel-Soldat hat Farbzonen**: Gesicht in `HAUT`, Rock in der
  Sortenfarbe, Hose dunkler, Stahl am Helm (`Streiter.KOPF` 1,6 für große
  Köpfe, `MASSE` 1,18). Einfarbig war jede Figur eine Silhouette. Die Sorte
  trägt ihre Farbe weiter auf der größten Fläche, dem Rock.
* **Der Boden ist eine Karte** (`feld.gd`): warmer Sand, Wiesen als
  zusammenhängende Flächen (Mittel über 3 × 3 Kacheln — ein Wert je Kachel
  gab ein Schachbrett), in Schichten über alle Kacheln gezeichnet (je Kachel
  lief der Rand der nächsten Wiese über die vorige), Wege, selten Bach und
  Teich, Bäume, Büsche, Ruinen, Zäune. **Wasser ist kein Blau** — Blau
  trägt der Held.
* **Menüs sind ein gerahmtes Blatt** (`zug_hud._rahmen`, `_kopfzeile`,
  `_leiste`): Pergament, doppelter brauner Rand, Eckbeschläge, Wappen im
  Kopf (`Zeichen.wappen`, Heldenfarbe), Trennlinien, Knöpfe mit Bild. Der
  Aufstieg ist ein **Banner** mit Spitze und Burg (`Zeichen.burg_bild`).
  Dabei fiel auf: `_riegel` prüfte `bis.x - von.x < 1` und warf jede
  senkrechte und jede nach links laufende Linie weg — jetzt die Länge.

## Godot beschaffen

Godot ist hier nicht vorinstalliert und `godotengine.org` ist durch die
Netzwerkpolicy blockiert. Der Download über GitHub-Release-Assets funktioniert:

```bash
V=4.5-stable
curl -sSL -o /tmp/godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/${V}/Godot_v${V}_linux.x86_64.zip"
unzip -oq /tmp/godot.zip -d /tmp/g
mv "/tmp/g/Godot_v${V}_linux.x86_64" /usr/local/bin/godot && chmod +x /usr/local/bin/godot
```

## Tests und Werkzeuge

```bash
godot --headless --import                               # class_name-Registry
godot --headless --path . --script tests/run_tests.gd   # ~15 min, Exitcode 1 bei Fehler
godot --headless --path . --script tools/probe.gd       # volle Läufe, Auskunft, ~40 min
godot --headless --path . --script tools/probe.gd -- --held 1 --stufen 8
godot --headless --path . --quit-after 180              # startet das Spiel wirklich
godot --headless --path . --script tools/lizenzcheck.gd # Herkunft belegt
xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/symbol.gd  # App-Symbole
tools/ladenbilder.sh build/laden && tools/ladengrafik.sh build/laden          # Ladenbilder
```

**`tools/probe.gd` ist Auskunft, keine Schranke.** Jede Zeile ist ein Lauf
mit einer Saat; derselbe Stand liess den Bogenschützen auf Burgstufe 0 die
zehn Minuten halten und auf Burgstufe 14 fallen. Er fällt nur, wenn ein Lauf
nicht zu Ende rechnet. Die Balance-Schranken stehen in `tests/run_tests.gd`,
über acht Saaten.

**Ein Schritt hinter einem roten ist ungeprüft.** Der Messstand steht in CI
hinter den Tests, und die waren vom ersten Commit von TEN THOUSAND an rot —
er ist dort kein einziges Mal gelaufen, und niemand wusste, dass er einen
Lauf zum Fall eines ganzen Bauauftrags machte. Dasselbe bei der
Veröffentlichung: hinter den roten Tests lag eine APK namens **Nekton** mit
NEKTONs Lichtkegel als Symbol, zwei Spiele alt, und in der
Vorabveröffentlichung, die man aufs Telefon lädt, lag die ganze Zeit HUNDRED
CUTS. Wird ein lange roter Schritt grün,
schaut man nach, was dahinter wartet.

**Der Testlauf allein beweist nicht, dass das Spiel läuft.** Er lädt
`zug_lauf.gd`, `zug_hud.gd` und `feld.gd` nie — ein `--script`-Lauf kennt
keine Autoloads und keine Szene. Ein Parse-Fehler dort bleibt im Testlauf
grün. Das ist in diesem Repository schon dreimal passiert; der Startlauf
findet es in Sekunden.

**`--import` nach jeder neuen Datei mit `class_name`.** Sonst kennt die
Registry die Klasse nicht, und das Skript lädt gar nicht erst.

**`quit()` kehrt zurück.** Also `return` hinter jedes `quit()`, das nicht das
letzte Statement der Funktion ist.

**Achtung beim Fehler-Check in der Shell:** `godot ... | grep ... | head` gibt
immer Erfolg zurück, weil `head` gelingt. Ausgabe in eine Variable fangen.

**Und eine Ersetzung ohne Prüfung ist ein stiller Fehlschlag.** Beim Umbau
von `Gefecht.baue()` lief ein `str.replace()` ins Leere, weil der Suchtext
einen Umlaut anders hatte — die Datei blieb unverändert, und der Fehler kam
erst zwei Schritte später als „Too many arguments" heraus. **Jedes
skriptgesteuerte Ersetzen prüft, dass es genau einmal getroffen hat.**

## Optik prüfen (Screenshots)

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1600 \
  -- --schuss /pfad/bild.png --held 0 --stufen 6 --zeit 200
```

| Schalter | Wirkung |
|---|---|
| `--schuss <datei>` | speichert und beendet |
| `--held <n>` | beginnt sofort einen Lauf mit diesem Helden |
| `--zeit <s>` | rechnet s Sekunden Gefecht mit festem Takt vor |
| `--stufen <n>` | setzt alle vier Bauten auf Stufe n, **den Beutel und die Züge** |
| `--lage <n>` | zeigt Titel (0), Burg (3), Beutel (4) statt des Laufs |
| `--neu` | mit `--held`: als erster Lauf, also mit Einstiegshinweis |
| `--saat <n>` | feste Saat — vorher und nachher zeigen dieselbe Szene |
| `--wahl` | nach dem Vorlauf steht ein Aufstieg offen (Kartenschirm) |
| `--ende` | nach dem Vorlauf endet der Lauf (Bericht) |

**Ein Schuss spielt mit leerem Spielstand und schreibt keinen**
(`Burg.schreibt`). Vorher las er die Funde aller Schüsse davor und
speicherte seine eigenen: dieselbe Saat gab zwei verschiedene Gefechte, und
ein Vergleich zweier Zeichnungen war ein Vergleich zweier Läufe.

**`--zeit` führt `Daumen`**, denselben simulierten Daumen wie `tools/probe.gd`.
Ohne ihn zeigte jeder Schuss denselben Stillstandstod nach vierzehn Sekunden.
Zwei Daumen wären zwei Spiele.

**`--stufen` setzt auch den Beutel und die Züge.** Ein Schalter, der die halbe
Wahrheit setzt, zeigt ein Spiel, das es nicht gibt — `Daumen` nimmt lieber
neue Waffen als neue Züge, und ohne das bekäme man den **Gefährten** auf
keinem Schuss zu sehen, obwohl er im Spiel steht.

## Zusicherungen, die nicht aufgeweicht werden dürfen

1. **Der Schaden am Spieler hängt an der Zeit, nicht an der Zahl der
   Anliegenden** (`Gefecht.WUNDE_SPERRE`). Der erste Entwurf ließ jeden
   anliegenden Feind für sich zuschlagen: zehn Strolche machten siebzig
   Schaden je Sekunde gegen hundert Leben. Gemessen fiel der Schwertkämpfer
   nach 154 s — mit 384 Erschlagenen auf dem Konto. Ein Horden-Spiel muss
   aber wollen, dass man in die Horde gerät. Der **härteste** Anliegende
   bestimmt, was es kostet; damit bleibt ein Ritter gefährlicher als ein
   Strolch, und zwanzig Strolche sind nicht zwanzigmal ein Strolch.

2. **Nicht wie viele anliegen kostet, sondern aus wie vielen Richtungen**
   (`Gefecht.DRUCK_RADIUS`, `SEKTOREN`, `UMZINGELT_FREI`/`_VOLL`). Der Deckel aus
   1 behob den Sofort-Tod und nahm dabei jeden Grund, sich zu bewegen:
   gemessen hielt Stehenbleiben 465 s und Laufen 473 — die einzige Eingabe
   des Spiels bewirkte nichts. Der Grundwert wird deshalb mit den besetzten
   Fächern multipliziert; zwanzig Strolche auf einer Seite sind so teuer wie
   einer, acht rundum das Dreifache. **Schaden fällt weiter nur bei
   Berührung** — der Ring sagt, wie schlimm es ist, die Berührung sagt, dass
   es passiert. Und die Zahl steht im Bild (`Stand.umzingelt`): eine Strafe,
   die man nicht kommen sieht, ist keine Regel, sondern ein Unfall.
   **Der Faktor spannt um die Eins** — aus einer Richtung kostet es die
   Hälfte, rundum das Vierfache. Als reiner Aufschlag obendrauf war die Regel
   nur eine Verteuerung und kostete alle vier Helden ein Fünftel ihrer Zeit;
   wer eine Flanke freihält, soll nicht verschont, sondern belohnt werden.

   **Bewacht wird das in zwei Stücken**, denn die Kette hat zwei Glieder:
   `_test_umzingelung_kostet_mehr_als_eine_flanke` zeigt gestellt, dass mehr
   besetzte Fächer mehr kosten, und `_test_stehen_wird_umzingelt`, dass
   Stehenbleiben mehr Fächer besetzt (gemessen Faktor 2,8, und die
   Verteilungen überlappen nicht). `_test_stehenbleiben_verliert` ist nur noch
   die Probe aufs Ganze — **paarweise je Saat**, siehe unten.

3. **Waffen zielen auf den Nächsten, nicht in die Laufrichtung.** In einem
   Genre, dessen ganze Bewegung Fliehen ist, zeigt der Laufweg *von* der
   Horde weg. Gemessen: 130 Sekunden, 180 Hiebe, **sieben** Erschlagene.
   Ausnahme ist der Speer — siehe 4.

4. **Der Speer stößt nach hinten.** Er war als der eine Zug entworfen, der
   nach dem Laufweg fragt, und stieß nach vorn: zwei Erschlagene in zwei
   Minuten. Die Frage war richtig, die Antwort stand andersherum — er spießt
   auf, was sich an die Fersen heftet. Damit ist er die einzige Waffe, die
   belohnt, dass man gerade flieht.

5. **Eine Sorte, die man am Verhalten nicht erkennt, ist keine.** Vier
   Verhalten (läuft / hält Abstand / stürmt / treibt), und zwei Sorten mit
   demselben Sinn müssen sich deutlich in Tempo oder Zähigkeit unterscheiden.
   Ein Feind mit mehr Leben wäre derselbe Feind mit mehr Wartezeit. **Und sie
   muss ihre eigene Farbe haben** (`Palette.SORTE`), denn die Sparfassung
   wirft die Silhouette weg, die Farbe aber nicht.

6. **Sorten treten gestaffelt ein** (`Andrang.AB`), mindestens
   `NEULING_FENSTER` auseinander, und die jüngste kommt in ihrer ersten
   halben Minute doppelt so oft. Wer in der ersten Minute alles trifft, lernt
   keine Sorte — er lernt nur, dass es voll ist.

7. **Jeder Held hat genau eine Eigenart.** Ein Held mit fünf kleinen
   Vorteilen fühlt sich an wie der Grundheld mit Rauschen. Freigeschaltet
   wird an Taten, nicht an Sold — wer Abwechslung kaufen kann, kauft sie am
   ersten Tag. **Dasselbe gilt für die Skins** (`Skins`): drei je Held, an
   Taten freigeschaltet, und sie ändern **nur Farben**. Sobald eine Skin
   einen Kampfwert trägt, wählt niemand mehr die, die ihm gefällt, sondern
   die, die gewinnt — in `Skins` steht deshalb kein Feld, in das ein Vorteil
   hineinpasste. Und **keine Skin ist eine Tarnkappe**: jede der zwölf hält
   denselben Farbabstand zu jedem Feind wie die Grundfarbe des Helden
   (gemessen, engste 0,29 gegen eine Schranke von 0,18, seit die Sorten
   satter sind).

8. **Jedes Ausrüstungsstück wirkt auf genau einen Wert**, aus demselben Grund.
   Und `Ausruestung.summe()` gibt ohne alles genau eins zurück, damit
   `Gefecht.baue()` bedingungslos multiplizieren kann und niemand ein `if`
   vergisst.

9. **Der Aufstieg bietet nie dreimal dasselbe** und bei vollen Plätzen nur
   noch Stufen. Drei Buffs nebeneinander sind keine Wahl; ein Angebot, das
   man nicht annehmen kann, ist ein verschenkter Aufstieg. **Der Gefährte
   steht als sechster `Gunst.Zug` darin** und nicht als dritte Sorte: als
   eigene hätte er `ist_waffe` an einem Dutzend Stellen zu einer Aufzählung
   gemacht und die Regel „höchstens zwei Waffen und höchstens zwei Züge unter
   dreien" verdreifacht — für eine Unterscheidung, die der Spieler an der
   Karte ohnehin sieht.

10. **Ein Gefährte trägt deine Farben und hat kein Leben.** Dieselbe Farbe
    heißt dieselbe Seite, und das muss man niemandem erklären; eine eigene
    wäre eine achte Sorte zum Merken. Vom Helden unterscheidet er sich an
    dem, woran man den Helden findet: deutlich kleiner, **kein Standring**,
    **kein Lebensbalken**, nicht freigestellt. Und er fällt nicht — ein
    Begleiter, der fällt, macht aus einem Aufstieg eine Ausgabe, die später
    verfällt, und schützen kann man ihn nicht, weil der Finger dem Helden
    gehört.

11. **Ring und Lebensbalken werden zuletzt gezeichnet, über allem.** Sie
    lagen in der y-Sortierung wie eine Figur — sobald Gefährten mitliefen,
    stand einer davor und die Marke war verdeckt. Eine Figur gehört in die
    Tiefe, eine **Marke** nicht: sie beantwortet *wo bin ich*, und eine
    Antwort, die verdeckt sein kann, ist keine.

12. **Man beginnt mit genau einer Waffe**, der seines Helden. Ohne eine
   schlägt man die erste halbe Minute gar nichts; mit zweien hat der erste
   Aufstieg nichts mehr zu sagen.

13. **Einkommen und Kosten wachsen mit derselben Rate.** `Halle.ertrag()`
    **ist** `rundenkosten()` geteilt durch `LAEUFE_JE_RUNDE`. Geprüft wird die
    Ableitung selbst und nicht ein Verhältnis: ein Verhältnis zu prüfen hieße,
    die Rundung bei kleinen Zahlen für eine Abweichung zu halten.

14. **Kein Ausbau verschlechtert etwas**, über alle 25 Stufen. Eine Kurve mit
    einem Exponenten über eins kippt am Ende, und niemand sieht es, weil
    niemand die fünfundzwanzigste Stufe spielt.

15. **Eine Dauerwaffe rechnet Schaden je Zeit, nicht je Bild.** Hängt der
    Flegel am Takt, ist er auf einem 120-Hz-Telefon doppelt so stark — und
    eine Einstellung im Anzeigemenü verstellte den Schwierigkeitsgrad.

16. **Nach y sortiert zeichnen.** In einem Bild ohne Perspektive ist die
    Zeichenreihenfolge die einzige Tiefe, die es gibt; ohne sie steht ein
    Feind vor dem Helden, der hinter ihm ist.

17. **Der Held wird freigestellt.** Ein Loch im Figurenpuffer in seiner
    Form, etwas größer als er (`zeichne_teil`, Teil 1) — im leeren Feld
    unsichtbar, im Gedränge steht er in einer Lücke, durch die der wirkliche
    Boden scheint. Bis Oktober 2026 war es eine Fläche in `Palette.BODEN`;
    auf einem Boden mit Wiesen wäre das ein Sandfleck. Es ist die einzige
    Stelle im Spiel, an der Boden über Figuren liegt. Ein heller Saum *unter*
    der Figur (der erste Anlauf) macht sie blass statt auffindbar.

18. **Der Stick sitzt, wo der Daumen aufsetzt.** Kein fester Knüppel an einer
    Ecke — auf einem Telefon hält niemand den Daumen dort, wo ein Entwerfer
    ihn hingelegt hat.

19. **Im Lauf gehört der Finger dem Helden** — außer beim Aufstieg. Ein Knopf,
    der einen Zug verschluckt, kostet Leben.

20. **Kein Angebot nach einer Niederlage.** Der Bericht hat zwei Wege.

21. **`get_display_safe_area()` nur auf dem Telefon fragen** und jeden Rand auf
    12 % der Bildkante deckeln: auf dem Schreibtisch liefert sie den ganzen
    Bildschirm und nicht das Fenster.

22. **Der Ton wird gemessen, nicht gehört.** Anfang und Ende jedes Puffers
    stehen konstruktionsbedingt auf null (`_huelle`); ein Puffer, der bei
    halber Auslenkung einsetzt, ist ein Knacks und kein Schlag. Und er wird
    **gedrosselt**: in den dichten Minuten fallen Feinde im Dutzend je
    Sekunde.

23. **Die Horde bleibt beim Helden.** Drei Teile, und keiner reicht allein
    (`Gefecht.NACHHOL_RADIUS`, `_trenne_feinde`, `Andrang.HOECHSTENS_LEBEND`):
    Wer weiter als `NACHHOL_RADIUS` (1184, aus `BILD_HALB_Y`) zurückfällt, wird auf den Eintrittsring geholt,
    **rundum** und nicht nach vorn (nach vorn trug der Speerträger 2 von 8,
    weil hinter ihm niemand mehr stand). Feinde **weichen einander aus**, im
    Raster, 30-mal je Sekunde, mit bis zu 16 Prüfungen je Feind
    (`TRENN_NACHBARN`; mit 10 kam ein Wolfsrudel nicht auseinander, sobald
    die weitere Kamera es beim Heranlaufen zeigte: 7 % statt 0 %), nach ihrer **gezeichneten Breite**
    (`Feinde.ABSTAND`) und nicht nach dem Trefferradius. Der quer liegende
    Wolf wird dafür gestaucht gezeichnet (`Streiter.WOLF_MASS`): was die
    Simulation für breit hält, muss das Bild auch so zeichnen. Und **höchstens 300 leben**, gemessen an
    der Rechenzeit (200 Lebende 1,3 ms je Schritt, 400 schon 2,7 ms). Vorher
    lief der Held der Horde davon: nach zehn Minuten lebten 2269, im Bild
    standen meist 10 bis 60, und von 880 im Bild standen 779 auf einem
    anderen. Bewacht von `_test_die_horde_steht_im_bild` (Anteil im Bild,
    Median 0,09 vorher, 0,22 nachher) und
    `_test_feinde_stehen_nicht_aufeinander` (gedeckt 0,94 vorher, 0,00 nachher).

24. **Wer gefallen ist, bleibt gefallen** (`Stand.gefallen`). `lebt()`
    fragte nur nach `leben > 0`, und `_zehre()` heilte nach dem tödlichen
    Treffer im selben Schritt nach. Mit *Rations* endete kein Lauf mehr, im
    Spiel wie im Messstand.

25. **Ein harter Treffer ist angesagt, und wer rechtzeitig aus der Bahn
    tritt, bleibt heil.** Der Ritter legt seine Sturmbahn `STURM_ANSAGE`
    (0,6 s) vorher fest, sie liegt als Zinnoberband am Boden und wird nicht
    nachgeführt; getroffen wird einmal je Sturm mit `STURM_WUCHT`, wie von
    einem Geschoss. Bolzen wiegen doppelt und ziehen einen Schweif. Die
    Sturmbahn hat ihr eigenes Feld (`Feind.bahn`) — vorher lag sie in
    `stoss`, dem Rückstoß der Waffen, und ein Treffer lenkte den Sturm um.
    Bewacht von `_test_ansturm_ist_auszuweichen` (gestellt). Der Daumen
    weicht aus angesagten Bahnen und Bolzen aus (`Daumen._ausweichen`).

26. **Der Warlord stellt sich.** Er hatte den Sinn des Ritters, sammelte mit
    33 Punkten je Sekunde, fiel zurück und wurde vom Nachholen auf den
    Eintrittsring **außerhalb des Bildes** gesetzt; jeder Treffer stieß ihn
    zusätzlich zurück. Gemessen stand er dadurch in einem gestellten Lauf
    16 % der Zeit im Sichtfeld, und in 9 von 96 vollen Läufen stand der Held
    bei 900 s noch. Jetzt: er sammelt mit vollem Tempo, holt jenseits von
    `Gefecht.WARLORD_LEINE` (412, **unter der halben Bildbreite** 450, nicht der
    Höhe) mit `WARLORD_AUFHOLEN` × dem Tempo **des Helden** auf, wird nie
    versetzt und von keinem Treffer zurückgestoßen. Sein Leben ist fest
    (`Feinde.LEBEN`, 8000) und **ohne** `Andrang.zaehigkeit`: es ist eine
    Kampfdauer, keine Wand. Bewacht von `_test_der_warlord_stellt_sich`.
    Steht er außerhalb des Bildes — beim Eintritt immer, er kommt auf dem
    Eintrittsring —, zeigt ein **Pfeil in Zinnober** am Bildrand auf ihn
    (`zug_lauf._zeichne_randpfeil`). Ein Horn, das man nicht orten kann, ist
    nur ein Geräusch. Der erste Pfeil mit 34 Punkten las sich als Blut am
    Rand; er ist jetzt 52 groß.

27. **Der erste Lauf erklärt sich, einmal.** Zwei Zeilen im unteren Drittel
    — „Drag anywhere to move. / Your weapons strike on their own.“ —, solange
    `BurgStand.einstieg` null ist, also bis zum Ende des ersten Laufs. Sie
    blenden aus, sobald der Held 0,8 s geführt wurde (`HINWEIS_WEG`), und
    haben **kein Zeitlimit**: wer nicht zieht, braucht sie noch. Keine Tafel
    dahinter, keine Pause, kein Knopf — Zusicherung 19 gilt auch hier. Das
    Feld `einstieg` stand schon im Spielstand und wurde nur gesetzt, nie
    gelesen.

## Was beim Bau gelernt wurde

**Ein Untoter sieht in jeder Tabelle aus wie ein Überlebender.** Mit
*Rations* stand der Held nach dem Tod mit einem Zehntel Leben wieder auf,
und jeder Messstand zählte ihn als „600 s durchgehalten“. Stehenbleiben
schien dadurch gleichauf mit Laufen (in der Hälfte der Saaten „600 s“), und
jede Messung der vollen zehn Minuten war zweigeteilt. Gefunden hat es erst eine
Aufschlüsselung des Schadens nach Quelle: 10692 Schaden durch Bolzen bei
einem Helden mit 156 Leben. **Wenn eine Verteilung zweigeteilt ist, schaut
man nach, was die eine Hälfte am Leben hält**, bevor man sie erklärt.

**Eine Horde, die man nicht sieht, ist keine.** Gezählt wurde lange, wie
viele leben — nicht, wie viele im Bild stehen. Der Held ist zwei- bis
dreimal so schnell wie das Fußvolk; er lief ihm davon, und die Horde stand
als Schleppe außer Sicht. **Zu zählen ist, was im Bild steht.**

**Ein Klumpen ist eine Flächenwaffe wert.** Solange Feinde aufeinander
standen, traf jeder Stoß ein Dutzend. Als sie einander auswichen, fielen der
Speer, der Hammer und die Armbrust unter ihre Schranken — nicht weil sie
schwächer wurden, sondern weil ihr Ziel nicht mehr gestapelt war. Die
Kehrseite: der Bogenschütze, dessen Armbrust als einzige Startwaffe keine
Fläche hat, stand deshalb als offener Posten in `Helden` (fiel bei einer von
drei Saaten vor Minute drei). Nachgemessen hält er 24 von 24 Saaten mit dem
meisten Leben der vier — einer Flächenwaffe fehlt ohne Klumpen der Vorsprung.
**Ein offener Posten wird nach jedem großen Umbau neu gemessen, bevor man ihn
behebt.**

**Tempo ist kein Wert an sich.** Seit die Horde rundum steht, macht mehr
Tempo den simulierten Daumen schlechter: der Speerträger mit Faktor 1,12
hielt 12 von 16 Saaten, mit 1,25 nur 10, mit 1,40 nur 8 — er läuft schneller
in die Horde hinein. Seine Eigenart („Outpaces the press“) war damit ein
**offener Posten**; getragen wurde er von der Reichweite seines Speers, und
die stand als Notbehelf für **jeden** Helden auf 310. **Aufgelöst** (siehe
unten): Tempo bleibt neutral, und die Reichweite ist jetzt seine Eigenart.
Dasselbe galt für den **Stall**: gepaart über acht Saaten auf Stufe 14 im
Median 249 s gegen 231 s ohne Burg, aber in vier Saaten früher gefallen.

**Nachgemessen, und die Hälfte davon war das Messgerät.** Der Schaden durch
Berührung verdoppelte sich mit Tempo (78 → 144), bei gleich vielen
Erschlagenen und gleich viel eingesammeltem Sold. Schuld war das **Heimweh**
des Daumens: gebaut gegen die Schleppe, die es seit Zusicherung 23 nicht mehr
gibt, zog es ihn nur noch quer durch die Horde zur Mitte zurück. Ohne es hält
der Speerträger bei Tempo 1,0 / 1,12 / 1,25 jeweils 23 bis 24 von 24, und
der Stall liegt mit 6 von 8 Saaten über „ohne Burg“ gleichauf mit der
Schmiede. **Offen bleibt:** einen *Vorteil* bringt Tempo nicht. Gepaart bis
300 s gewinnt 1,25 gegen 1,0 genau 4 von 8 Saaten, auch mit gierigerem Daumen
oder kürzer liegendem Sold. Tempo ist neutral — ein Zweck dafür wäre eine
neue Regel im Spiel, keine neue Zahl.

**Die Regel kam, der Vorteil nicht.** Angesagte Stürme und schwere Bolzen
(Zusicherung 25) machen das Spiel lesbarer und fairer, aber gemessen tragen
sie kaum Schaden: bis 420 s brachten Stürme meist 0, Bolzen 0 bis 50, die
Berührung 150 bis 500. Mit 0,6 s Ansage reicht schon das Grundtempo zum
Ausweichen (120 Punkte gegen eine Bahn von gut 110). Mit 0,3 s und
schnelleren Bolzen traf es öfter — aber 1,25 gewann dann nur 2 von 8,
weil der schnellere Daumen nicht besser ausweicht, sondern in mehr
hineinläuft. **Tempo bleibt neutral** — keine Eigenart hängt mehr daran
(siehe den Speerträger unten) —, **und der Engpass ist der Daumen:** ein Fluchtvektor nutzt Tempo nicht. Was ein Mensch mit Tempo tut —
eine Lücke erreichen, bevor sie sich schließt —, kann er nicht.

**Eine Eigenart gehört dahin, wo sie gemessen trägt, nicht wo ihr Satz
klingt.** Der Speerträger hieß „Outpaces the press“ und lief 1,12-mal so
schnell; getragen hat ihn die Weite seines Speers, und die stand für alle
Helden auf 310. Jetzt läuft er so schnell wie jeder, und nur *sein* Speer
reicht weiter (`Helden.SPEER_FAKTOR` 1,25 auf eine Grundweite von 250):
24 von 24 Saaten statt 23 bis 24, der Schwertkämpfer 16 von 16, der Speer
allein 8 von 8. Eine kürzere Grundweite mit größerem Faktor (168 × 1,85)
hielt den Helden, riss aber den Speer für alle anderen (4 von 8).
Bewacht von `_test_speerlaenge_gilt_nur_dem_speer`.

**Drei Minuten sind nicht zehn.** Jeder Wächter endet bei 180 s, und dort
hielten alle vier Helden 24 von 24. Über die vollen Läufe (Daumen, bis
Sieg, Tod oder 900 s, acht Saaten je Zelle) sieht es anders aus:

| Held | Burg 0 | Burg 8 | Burg 14 |
|---|---|---|---|
| Swordsman | 0 Siege, Median 267 s | 0, 420 s | 3, 674 s |
| Archer | 3, 338 s | 3, 690 s | 7, 687 s |
| Spearman | 0, 304 s | 1, 446 s | 4, 686 s |
| Hammerman | 1, 259 s | 0, 396 s | 2, 465 s |

Drei Befunde. **Die Burg trägt**, und zwar deutlich — was bei 180 s gleich
aussah, trennt sich ab Minute vier. **Gestorben wird in Minute vier bis
sieben**, fast nur durch Berührung; Stürme und Bolzen bleiben Nebensache.
Und **der Warlord ist zäh**: wer ihn erreicht, braucht im Median gut zwei
Minuten für ihn, und in 9 von 96 Läufen stand der Held bei 900 s noch mit
vollem oder halbem Leben da, den Warlord mit 1800 bis 8800 Leben irgendwo
**außerhalb des Bildes** — der Daumen flieht auch vor dem letzten Feind.
Es war das Spiel (Zusicherung 26): Nachholen setzte ihn außerhalb des Bildes
ab, und jeder Treffer stieß ihn weiter weg. Danach, dieselben 96 Läufe:
**1** statt 9 stehen bei 900 s, **30** statt 22 Siege, der Endkampf dauert im
Median **72 s** (Quartile 49 / 111), und er steht 97 bis 99 % der Zeit im
Bild. Der eine übrige Lauf ist ein Speerträger, dessen Waffen lieber die
letzten vierzig Feinde der Horde treffen (Zusicherung 3: auf den Nächsten).

**Und die Tabelle vergleicht keine Helden.** Ihre Saat enthielt die Nummer
des Helden, also spielte jeder Held andere Läufe. Der Hammerträger sah darin
wie der schwächste aus (0 / 0 / 2 Siege). Auf **denselben** 16 Saaten
(Burg 8, bis 480 s) steht er mit den anderen gleichauf, und keiner der
beiden naheliegenden Hebel hilft ihm:

| Held | Median | bis 480 s | gepaart gegen Hammerträger |
|---|---|---|---|
| Swordsman | 454 s | 7/16 | 8 besser, 5 schlechter |
| Archer | 480 s | 14/16 | 10 besser, 2 schlechter |
| Spearman | 409 s | 6/16 | 6 besser, 8 schlechter |
| Hammerman | 434 s | 6/16 | — |
| Hammerman, Tempo 1,0 | 408 s | 2/16 | 5 besser, 9 schlechter |
| Hammerman, Schaden 1,5 | 456 s | 7/16 | 6 besser, 7 schlechter |

Der Ausreißer ist der **Bogenschütze**, nach oben. **Wer Helden vergleicht,
gibt ihnen dieselben Saaten** — sonst vergleicht er Würfel.

**Und seine Eigenart ist es nicht.** `WEITE_FAKTOR` 1,60 / 1,45 / 1,30 / 1,15
brachte auf Burg 8 14 / 10 / 6 / 9 von 16 bis 480 s — keine Kurve, sondern
Streuung —, und auf Burg 14 hielten 1,60 und 1,30 beide 14 von 16
(Schwertkämpfer 8, Hammerträger 11). Der Faktor blieb deshalb stehen. Wo der
Vorsprung sitzt, ist **offen**; naheliegend ist die Armbrust als einzige
Startwaffe, die aus der Ferne trifft, sodass der Daumen gar nicht erst in die
Horde muss. **Eine Zahl, die man senkt, ohne dass die Messung mitgeht, war
nicht die Ursache.**

Dazu ein Messfehler: `tools/probe.gd` zählte jeden Lauf, der 600 s
erreichte, als „heil“. Das Spiel kennt aber keine Zeitgrenze
(`Gefecht.vorbei`) — gewonnen ist erst, wenn der Warlord fällt. Jetzt
rechnet er bis 900 s und unterscheidet Sieg, „steht“ und Fall.

**Ein Schuss ist ein Augenblick, keine Verteilung.** Auf einem Bild aus
Minute 6 stand ein Block aus Rittern und Wölfen, und die naheliegende
Erklärung war, dass die Zähen die Obergrenze füllen, weil die Schwachen
zuerst fallen. Gemessen (Daumen, Held unsterblich, vier Saaten, Burg 4 und 8)
liegt der Ritter bei 7 bis 17 % der Lebenden gegen 9 % der Gezogenen, also
höchstens beim Doppelten, und der Wolf darunter. Am stärksten verschoben sind
die **Armbrustschützen** (22 bis 27 % gegen 11 %), und zwar mit Absicht: sie
halten Abstand und sind deshalb schwer zu erreichen. Der Block war ein
Rudel, das zufällig mit Rittern zusammenlief. **Bevor man eine Regel gegen
ein Bild baut, zählt man, ob das Bild die Regel zeigt.**

**Ein Bau mit zwei Wirkungen wird an der stärkeren gewählt.** Die Münze
buchte ihren Faktor auch als Erfahrung und war damit gemessen der stärkste
Bau, obwohl sie laut Beschreibung nur Sold bringt. Seit `Muenze.erfahrung`
liefert sie auf Stufe 14 Saat für Saat dieselben Zeiten wie gar keine Burg —
genau das, was ein reiner Geldbau tun soll.

**Die Sparfassung ist nicht der Randfall, sondern der Normalfall.** Bei
`DICHT_AB = 70` steht ein Lauf ab Minute drei fast durchgehend in ihr — und
sie zeichnete den Wolf als **Balken mit zwei Nadeln**. Wer eine Figur
verbessert, verbessert zuerst ihre Sparfassung: die Vollfassung sieht man in
der ersten Minute, die andere den Rest des Spiels.

**Ein Vierbeiner braucht drei Dinge gleichzeitig, und zwei reichen nicht.**
Der Wolf war dreimal ein Möbelstück. Erst lagen Rücken und Kopf auf einer
Höhe — ein Tisch. Dann stimmte die Neigung, aber mit sieben Bildpunkten
Gefälle auf fünfzig Länge sah sie niemand — wieder ein Tisch. Dann stimmte
die Neigung sichtbar, aber der Rumpf war sechzig Punkte lang und zehn dick
mit vier Nadeln darunter — ein **Kleiderständer**. Es braucht **Neigung**
(Kruppe hoch, Schulter tiefer, Kopf darunter), **Masse** (gut anderthalbmal
so lang wie tief, mit eingezogener Weiche) und **geknickte Läufe** zugleich.

**Ein Umriss braucht ein deckendes Band *und* einen scharfen Sprung.** Erster
Anlauf: Kantenreihen auf 0,88, Körper ab 0,62 — dazwischen ein Verlauf über
ein Viertel der Breite, also kein Umriss. Zweiter Anlauf, in die falsche
Richtung korrigiert: 0,78 und 0,74 — der Sprung war scharf, das *deckende*
Band aber vier Hundertstel breit, bei einem Glied von zwanzig Punkten ein
halbes Pixel. Auf dem Schuss war zweimal nichts zu sehen. Beides zugleich
gehört hin.

**Farbe kostet in diesem Sammler nichts.** `Tusche.band()` schrieb immer
schon eine Farbe **je Eckpunkt**; der ganze Stilwechsel von Tusche auf Farbe
hat **keinen einzigen** Zeichenaufruf gekostet. Teuer war allein die Kante —
und auch die ging ohne zweiten Durchgang, weil die äußeren Reihen einfach
eine andere Farbe bekommen (neun Reihen statt fünf, Faktor 1,8 auf die
Eckpunkte, statt Faktor 2,0 für ein zweites Zeichnen der ganzen Figur).

**Ein Messstand, der bei gleicher Saat andere Zahlen liefert, misst gar
nichts.** `Gunst.ziehe()` mischte seinen Topf mit `Array.shuffle()`, und der
greift auf Godots **globalen** Generator zu statt auf den übergebenen `rng`.
Damit war kein Lauf wiederholbar: zwei Messungen mit denselben Saaten meldeten
für dasselbe Stehenbleiben einmal 232 und einmal 300 Sekunden, und mehrere
Balance-Befunde dieser Session waren Rauschen. In einem Repository, dessen
ganze Balance auf gesäten Vergleichen steht, ist das kein Detail. **Jede
Ziehung im Kern nimmt den übergebenen `rng`** — `shuffle()`, `pick_random()`
und `randi()` ohne Empfänger gehören nicht nach `scripts/kern/` oder
`scripts/daten/`.

**Eine Strafe für eine Lage, die das Spiel nie herstellt, ist ein toter
Buchstabe.** Der Druckring stand zuerst bei 110 Punkten, knapp außerhalb der
Berührung. Gezählt standen darin im Mittel **0,8 Feinde**, und alle acht
Fächer waren in **0,0 %** der Bilder besetzt — die Waffen räumen den Ring
schneller, als die Horde ihn füllt. Die Mechanik war richtig gebaut und feuerte
auf nichts. Erst die Messung über 110/180/260/340/420 fand die Weite, bei der
Stehen und Laufen am weitesten auseinanderliegen. **Bevor man an einer Zahl
dreht, misst man, ob die Regel überhaupt greift.**

**Eine Messung, die an eine Decke stößt, ist keine.** Der gestellte
Umzingelungstest ließ den Helden mit hundert Leben antreten: rundum war er nach
der halben Zeit tot, danach fiel kein Schaden mehr, und acht Feinde rundum
meldeten denselben Wert wie acht auf einer Flanke. Nicht die Mechanik war
stumpf, sondern das Messgerät voll.

**Und ein Mittelwert aus abgeschnittenen Daten ist erst recht keine.**
`_test_stehenbleiben_verliert` verglich die mittlere Überlebenszeit stehend
gegen laufend. Die Läufe enden aber bei 600 Sekunden, und **drei von acht**
stehenden sowie **sieben von acht** laufenden Läufen stoßen an diese Decke —
ein Lauf, der neunhundert Sekunden gehalten hätte, steht als 600 in der Liste.
Das Verhältnis maß damit vor allem, wie viele Läufe gerade anstießen: derselbe
Umbau verschob es um siebenundzwanzig Prozent (0,585 auf 0,743), während die
**paarweise** Bilanz je Saat sich kaum rührte (5/1/2 auf 5/2/1). Drei
Änderungen in Folge scheiterten an dieser Form, bei zweieinhalb Prozent
Spielraum. **Wo eine Obergrenze im Spiel ist, vergleicht man paarweise und
nimmt den Median** — oder man misst gleich die Mechanik statt ihrer
Fernwirkung.

**Die Mechanik zu messen ist billiger und ruhiger als ihre Fernwirkung.** Statt
zu fragen, ob der Stehende früher stirbt (600-Sekunden-Läufe, Werte von 59 bis
600), fragt `_test_stehen_wird_umzingelt`, ob er **mehr Fächer besetzt** —
gemittelt über Bilder in 150 Sekunden: 0,176 gegen 0,062, und der niedrigste
stehende Wert liegt über dem höchsten laufenden. Dieselbe Aussage, ein Viertel
der Rechenzeit, keine Decke.

**Ein Befund über das Spiel kann ein Befund über das Messgerät sein.** Der
Speer zielte als einzige Nahkampfwaffe blind (`-s.lauf`), und jede Fassung,
die ihn verbesserte, schob den alten Stehen-gegen-Laufen-Wächter über seine
Schranke (0,585 → 0,754 → 0,829). Das stand hier eine Weile als Gesetz:
*eine Waffenverbesserung nützt dem Stehenden mehr als dem Laufenden*, samt
zwei gemessen widerlegten Erklärungen. Tatsächlich verglich der Wächter
Mittelwerte aus abgeschnittenen Läufen. Paarweise gemessen besteht derselbe
Speer-Griff ohne Mühe — und der Gefährte, der an derselben Wand gescheitert
war, ebenso. **Drei gescheiterte Änderungen hintereinander an derselben
Schranke sind ein Hinweis auf die Schranke**, bevor sie einer auf die
Änderungen sind.

**Eine Einzelmessung aus einer streuenden Verteilung ist ein Zug und kein
Befund** — und dieses Genre streut enorm. Derselbe Stand meldete für den
Flegel 298 Erschlagene bei einer Saat und 169 über drei. Stehenbleiben fällt
bei zwei Saaten nach gut drei Minuten und überlebt bei der dritten die vollen
zehn, weil es sich in eine Lawine hineingespielt hat. **Jeder Balance-Test
hier mittelt über mehrere Saaten**, und wo eine absolute Schwelle zu wackelig
wäre, prüft er *vergleichend* (Stehen gegen Laufen) statt absolut.

**Der Messstand gehört in den Kern, nicht ins Werkzeug.** `Daumen` steht in
`scripts/kern/`, weil ihn sowohl `tools/probe.gd` als auch der Schuss
benutzen. Zwei Daumen wären zwei Spiele, und dann misst der Messstand nicht
das, was das Bild zeigt.

**Eine Sparfassung darf weglassen, was Zierde ist — nicht das, woran man eine
Figur erkennt.** Der erste Anlauf zeichnete bei vielen Feinden *einen* Strang
plus Kopfklecks: im Bild fünfzig schwarze **Pillen**. Zwei Beine, eine
Schulterlinie und ein Kopf sind das Minimum; das sind vier Züge statt
siebzehn, und das ist der Handel.

**Ein Balken hat überall dieselbe Höhe, eine Tafel auch.** Beide waren als
`zug()` gebaut, und der schwillt zur Mitte an: über dem Schirm stand eine
**Linse** mit spitzen Enden. Man liest einen Balken an seiner Länge, und eine
Länge mit spitzen Enden lässt sich nicht ablesen.

**Ein Vierbeiner ist geneigt.** Rücken und Kopf auf einer Höhe gaben im Bild
einen Tisch mit vier Beinen. Kruppe hoch, Schulter tiefer, Kopf darunter.

**Der Bahnradius einer kreisenden Waffe muss dort liegen, wo das Gedränge
steht.** Der Flegel kreiste bei 96 Punkten, die Feinde drängen sich bei rund
vierzig — er traf fast nie (37 gegen 268 bei der Axt). Das ist zugleich seine
Aussage: *lass sie nah heran.*

**Und die Zeichenaufrufe, in diesem Renderer gemessen** (eine Eigenschaft der
Engine, nicht eines Spiels):

| Aufruf | Zeichenaufrufe |
|---|---|
| `draw_line`, auch geglättet | 50 Stück = **1** |
| `draw_colored_polygon` | 1 je Stück, **auch mit Deckung null** |
| `draw_circle` hart / geglättet | 1 / **2** je Stück |
| `draw_arc` | **3** je Stück |
| `draw_polyline` geglättet | **3 je Zug**, unabhängig von der Länge |

Deshalb sammelt `Tusche` alles in **ein** Dreiecksnetz: eine Figur, ein
Aufruf. Bei hundertfünfzig Feinden ist das keine vorgezogene Optimierung,
sondern die Form, in der dieses Bild überhaupt bezahlbar ist.

**`Tusche` sammelt, `draw_string` nicht.** Der Pinsel häuft alles in einem
Netz an und spült es am Ende in **einem** Aufruf; `draw_string` geht sofort
aufs Blatt. Damit lag jede Beschriftung **unter** ihrer eigenen Tafel — und
eine Tafel ist ein Pergamentwisch mit zweiundsechzig Prozent Deckung. Im Bild
stand auf jedem Knopf und jeder Karte graue Schrift, wo schwarze stehen sollte,
und die Baukosten in der Burg sahen aus, als könne man sie sich nicht leisten.
**Wer neben Tusche zeichnet, sammelt mit** (`zug_hud.gd._worte`).

**Eine Beschriftung, die breiter ist als das, was sie beschriftet, ist keine.**
Der Satz des Bogenschützen lief über den Rand seiner Karte und rechts aus dem
Bild. Gekürzt wird nicht — ein abgeschnittener Satz sagt weniger als ein
kleinerer; die Größe fällt, bis er hineingeht (`_zeile_eng`).

**Ein Schirm, der oben klebt, ist für ein anderes Gerät entworfen.** Die Menüs
waren von oben gesetzt und standen auf einem 720x1600-Telefon im oberen
Drittel, darunter ein leeres Viertel Pergament. Der Block sitzt mittig in dem,
was da ist (`_luft`); wird es eng, klebt er wieder oben.

**Wenn im Bild etwas steht, das keine Zeichnung erklärt**, ist der nächste
Schritt nicht Nachdenken, sondern **einen Knoten stillstellen und noch einmal
schießen**.

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **APK-Builds nur in CI**
- Der Container ist flüchtig; Godot muss je Session neu installiert werden
- MSAA-2D gibt es im Kompatibilitäts-Renderer nicht. Weiche Kanten kommen aus
  dem Zeichnen selbst: jeder `Tusche`-Strich hat zwei durchsichtige
  Außenreihen — die Form eines Haarpinsels, nicht ein Glättungstrick

## Konventionen

- **Bezeichner und Kommentare auf Deutsch, alles Sichtbare auf Englisch.**
- Einrückung: 4 Leerzeichen
- `scripts/kern/` und `scripts/daten/` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so sind sie headless testbar
- Jede Testfunktion endet mit `return true` und steht in `TESTS` — ein
  Wächter prüft das
- GDScript leitet Typen aus untypisierten Werten **nicht** ab, und die Warnung
  ist hier ein Fehler: `var x: Gefecht.Stand = ...` schreiben, wo der
  Rückgabetyp nicht feststeht
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
