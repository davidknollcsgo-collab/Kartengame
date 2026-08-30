# NEKTON

Eine biolumineszente Kolonie in einem Tiefseegraben. Ewige Dunkelheit, Druck,
leuchtende Kreaturen — und ein Lichtkegel am Daumen.

Godot 4.5 · Hochformat · Android · derzeit im Aufbau

Die Spieloberfläche ist **englisch**; Bezeichner und Kommentare im Quelltext
bleiben deutsch.

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
| Rechenkern (`Schlund`) | Lichtkegel, Bahnen, Zielauswahl — 53 Tests grün |
| Wellen 1–60 | aus der Ausbaukurve abgeleitet, alle 60 geprüft |
| Neun Räuberarten | vier mit eigener Regel: Panzer, Mindestlicht, Querdrift, Schub |
| Leitwesen | die Schlundmutter am Ende jedes Abschnitts — sechs Höhepunkte statt sechzig gleicher Wellen |
| Bestiarium | jede begegnete Art mit ihrer Regel; unbekannte zeigen nur, ab wann sie kommen |
| Sechs Grabenabschnitte | eigene Regel je Abschnitt: Strömung, Trübung, Dunkelphasen, Streulicht |
| Grabentiefe | der Tiefenschacht öffnet die Abschnitte — abgeleitet aus der Sollkurve |
| Kolonie | fünf Kammern mit Stufen, Kosten und Bauzeiten; 50 Tage gemessen, keine gefallene Sitzung |
| Brutlinien | drei Linien, gezüchtet statt gezogen — kein Zufall, keine Kiste |
| Tagesziel | drei Aufgaben, Anwesenheitszähler, Lohn wächst mit dem Fortschritt |
| Ton | vollständig synthetisiert, keine Audiodatei |
| Speichern | verschlüsselt, mit Prüfung jedes gelesenen Werts |
| Android | Debug-APK baut in CI und lässt sich sideloaden |

## Was noch fehlt

Geisterdaten und Bestenliste, Werbung und Käufe — alles drei braucht Konten
und SDKs, die außerhalb dieses Repositorys eingerichtet werden. Der
vollständige Bauplan steht im Projektplan.

## APK

Der Bau läuft in CI: Actions → **APK** → letzter Lauf → Artefakt
`nekton-apk`. Die APK ist mit einem Debug-Schlüssel signiert und nur zum
Sideloaden gedacht — für den Play Store braucht es einen eigenen,
dauerhaft aufbewahrten Schlüssel. Geht der verloren, lässt sich die App nie
wieder aktualisieren.

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
