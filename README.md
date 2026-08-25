# NEKTON

Eine biolumineszente Kolonie in einem Tiefseegraben. Ewige Dunkelheit, Druck,
leuchtende Kreaturen — und ein Lichtkegel am Daumen.

Godot 4.5 · Hochformat · Android · derzeit im Aufbau

## Die Kernschleife: Schlundwache

Am Eingang der Kolonie sitzt ein Wächter. Aus der Dunkelheit sinken Räuber in
Wellen herab. Du ziehst mit **einem Finger** einen Lichtkegel über den Schlund —
was darin liegt, wird verbrannt. Zwischen den Wellen tippst du auf freie
Nischen und setzt dort Wehrpolypen.

Eine Welle dauert 40 bis 70 Sekunden. Der Kegel fasst nur wenige Räuber
gleichzeitig; ein Schwarm lässt sich nicht wegleuchten, sondern muss sortiert
werden.

## Was schon steht

| Bereich | Stand |
|---|---|
| Rechenkern (`Schlund`) | Lichtkegel, Bahnen, Zielauswahl — 23 Tests grün |
| Wellen 1–60 | aus der Ausbaukurve abgeleitet, alle 60 geprüft |
| Schwierigkeitskurve | gemessen, steigt monoton von 0.25 auf 1.00 |
| Schlundwache | spielbar: Wellen, Bauphase, Polypen, Niederlage, Neustart |
| Optik | Wasser-Shader, vier gezeichnete Räuberarten, Kolonie, Funken |

## Was noch fehlt

Die Kolonie als eigener Bildschirm, Brutlinien, Speichern, Tagesziel,
Geisterdaten, Ton, Werbung und Käufe. Der vollständige Bauplan steht im
Projektplan.

## Bauen und prüfen

```bash
godot --headless --import                                  # Registry aufbauen
godot --headless --path . --script tests/run_tests.gd      # Tests
godot --headless --path . --script tools/wellenpruefer.gd  # alle 60 Wellen
```

Weitere Werkzeuge, Screenshot-Schalter und die Zusicherungen, die nicht
aufgeweicht werden dürfen, stehen in [`CLAUDE.md`](CLAUDE.md).

## Rechtliches

Vom Vorbild ist ausschließlich die **Struktur** übernommen — casual
Kernschleife vorn, Aufbauspiel dahinter. Spielmechaniken sind nicht
urheberrechtlich geschützt.

Alles Sichtbare und Lesbare entsteht in diesem Repository: die Grafik
prozedural im Code, der Ton synthetisiert, Namen und Texte selbst geschrieben.
Es gibt **keine einzige Bild- oder Audiodatei** im Projekt. Die Herkunft jedes
Bestandteils ist in [`ASSETS.md`](ASSETS.md) belegt.

Engine: Godot 4 (MIT). Schriften: SIL OFL 1.1.
