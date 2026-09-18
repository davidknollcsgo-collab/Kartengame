# HUNDRED CUTS

Ein Duell aus Linien. Tusche auf Papier, ein Daumen, ein Schwert.

Godot 4.5 · Hochformat · Android · im Aufbau

Die Spieloberfläche ist **englisch**; Bezeichner und Kommentare im Quelltext
bleiben deutsch.

## Die Schleife

Ein Gegner holt aus. Seine Haltung sagt, welchen Schnitt er führt — Klinge
über dem Kopf, an der Schulter, tief an der Hüfte, waagerecht hinter dem
Rücken, oder die Spitze voran. Eine Zinnoberlinie bestätigt es und wächst;
wenn sie voll ist, fällt der Hieb.

Der Daumen muss dieselbe Achse treffen, im Fenster um den Schlag:

* **wischen** entlang der Linie — das pariert,
* **tippen** — das schlägt eine Spitze nieder,
* noch ein Wisch auf den, der danach offen steht — das tötet.

Wer daneben greift, steht einen Augenblick selbst offen. Drei bis sieben
Wunden, dann ist die Ronde vorbei.

**Es gibt keinen Schaden.** Ein Hieb tötet, wenn er sitzt, für beide Seiten,
von der ersten Ronde bis zur hundertsten.

## Dahinter: die Schule

Vier Hallen, und jede greift genau eine Stelle des Duells an:

| Halle | Was sie gibt |
|---|---|
| **Eye** | längerer Ansatz — mehr Lesezeit |
| **Wrist** | breiteres Fenster — mehr Nachsicht beim Zeitpunkt |
| **Breath** | eine Wunde mehr |
| **Edge** | der Parierte bleibt länger offen |

Alles davon ist **Nachsicht**, nichts davon ist Wucht. Eine Schule, die den
Spieler härter zuschlagen ließe, machte aus einem Duell ein Rechenspiel.

## Wie es aussieht

Ein Blatt in gebrochenem Weiß, Figuren als schwarze Pinselmassen, ein
einziger Zinnoberton für die Gefahr. Kein Bild im Projekt und keine
Tondatei: jeder Strich entsteht in `scripts/spiel/tusche.gd`, jeder Klang in
`scripts/spiel/stahl.gd`. `ASSETS.md` ist der Nachweis.

## Bauen und prüfen

```bash
godot --headless --import                               # class_name-Registry
godot --headless --path . --script tests/run_tests.gd   # Tests
godot --headless --path . --quit-after 180              # startet das Spiel wirklich
godot --headless --path . --script tools/lizenzcheck.gd # Herkunft aller Dateien
```

Einen Blick auf das Bild:

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1600 \
  -- --schuss /tmp/bild.png --ronde 11 --stufen 6 --zeit 1.2
```

`CLAUDE.md` hat die ausführliche Fassung, samt der Zusicherungen, die nicht
aufgeweicht werden dürfen.
