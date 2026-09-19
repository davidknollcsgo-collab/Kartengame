# TEN THOUSAND

Einer gegen die Horde. Holzschnitt auf Pergament, ein Daumen, zehn Minuten.

Godot 4.5 · Hochformat · Android · im Aufbau

Die Spieloberfläche ist **englisch**; Bezeichner und Kommentare im Quelltext
bleiben deutsch.

## Die Schleife

Von oben, ein Held, hundert Feinde. Der Finger führt **nur den Mann** — die
Waffen schlagen von selbst, auf den Nächsten, in ihrem eigenen Takt. Was man
entscheidet, ist die Aufstellung: wohin man läuft, wen man vor sich lässt,
wann man durch eine Lücke geht.

Und bei jedem Aufstieg eines von drei Angeboten: eine neue Waffe, eine Stufe
auf eine alte, oder einen der fünf Züge (Rüstung, Stiefel, Wetzstein,
Laterne, Zehrung). Nie dreimal dasselbe, nie ein Angebot, das man nicht
annehmen kann.

Nach zehn Minuten steht der Warlord da. Danach kommt nichts mehr nach — ein
Höhepunkt, den man im Gedränge nicht sieht, ist keiner.

**Stehenbleiben kostet.** Nicht *wie viele* anliegen entscheidet, was ein
Treffer wert ist, sondern *aus wie vielen Richtungen*. Zwanzig Strolche auf
einer Seite sind so teuer wie einer; wer sich einschließen lässt, zahlt ein
Vielfaches. Der Zinnoberbogen am Boden zeigt, aus welchen Fächern es drückt,
und zwar aus derselben Zahl, aus der der Schaden fällt.

## Drei Ebenen dahinter

| Ebene | Frage | Was sie gibt |
|---|---|---|
| **Die Burg** (`Halle`) | die stetige Kurve | Mauer, Schmiede, Stall, Münze — 25 Stufen, keine verschlechtert etwas |
| **Die Ausrüstung** (`Ausruestung`) | die Fundfreude | vier Plätze, acht Stücke, ein Fund nach jedem Lauf |
| **Die Helden** (`Helden`) | die Abwechslung | vier Klassen, jede mit **genau einer** Eigenart, freigeschaltet an Taten statt an Sold |

Einkommen und Kosten wachsen mit derselben Rate: `Halle.ertrag()` **ist**
`rundenkosten()` geteilt durch `LAEUFE_JE_RUNDE`, und geprüft wird die
Ableitung selbst.

## Sechs Waffen, sieben Sorten

Die Waffen zielen auf den Nächsten und nicht in die Laufrichtung — in einem
Genre, dessen ganze Bewegung Fliehen ist, zeigt der Laufweg *von* der Horde
weg. Der Speer ist die Ausnahme: **er stößt nach hinten** und spießt auf, was
sich an die Fersen heftet. Damit ist er die einzige Waffe, die belohnt, dass
man gerade flieht.

Die Feinde haben vier Verhalten — läuft, hält Abstand, stürmt, treibt — und
treten **gestaffelt** ein (`Andrang.AB`). Die jüngste Sorte kommt in ihrer
ersten halben Minute doppelt so oft: wer in der ersten Minute alles trifft,
lernt keine Sorte, sondern nur, dass es voll ist.

## Der Artstyle: Holzschnitt auf Pergament

Warmes Pergament, schwarze Tusche, Schraffur für Schatten, **Zinnober nur für
Gefahr** und **Gold nur für Sold**. Zwei Farben, zwei Bedeutungen.

Alles Sichtbare entsteht in diesem Repository: `Tusche` sammelt jede Figur in
**ein** Dreiecksnetz und spült sie in einem einzigen Zeichenaufruf — bei
hundertfünfzig Feinden ist das keine vorgezogene Optimierung, sondern die
Form, in der dieses Bild überhaupt bezahlbar ist. Der Ton wird in `Klang`
synthetisiert; es gibt keine einzige Audiodatei. `ASSETS.md` ist der Nachweis.

## Bauen und Prüfen

```bash
godot --headless --import                               # class_name-Registry
godot --headless --path . --script tests/run_tests.gd   # die Waechter
godot --headless --path . --script tools/probe.gd       # volle Laeufe
godot --headless --path . --quit-after 180              # startet das Spiel wirklich
godot --headless --path . --script tools/lizenzcheck.gd # Herkunft belegt
```

Der Startlauf ist kein Doppel des Testlaufs: ein `--script`-Lauf kennt keine
Autoloads und keine Szene, also lädt er `zug_lauf.gd`, `zug_hud.gd` und
`feld.gd` nie. Ein Parse-Fehler dort bleibt im Testlauf grün. Das ist in
diesem Repository dreimal passiert.

Schüsse vom laufenden Spiel:

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1600 \
  -- --schuss /tmp/bild.png --held 0 --stufen 6 --zeit 200
```

`--zeit` führt `Daumen`, denselben simulierten Daumen wie `tools/probe.gd` —
zwei Daumen wären zwei Spiele. `--lage` zeigt Titel (0), Burg (3) und Beutel
(4).

## Vorgeschichte

In diesem Repository lagen vor September 2026 zwei andere Spiele: NEKTON
(Tiefsee, Lichtkegel) und HUNDRED CUTS (ein Timing-Duell). Beide sind
gelöscht. Wer in älteren Commits über `rundlauf.gd`, `schwarm.gd`, `duell.gd`
oder `fechter.gd` stolpert: die gibt es nicht mehr. **Eine Schleife, eine
Wahrheit.**
