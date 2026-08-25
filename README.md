# HYPHA

Ein Ricochet-Puzzle mit einem Kniff: **jeder Schuss baut die Bahn für den
nächsten.** Die Spore zieht eine Wurzelspur hinter sich her, und diese Spur
bleibt liegen — als Wand, an der der nächste Schuss abprallt.

> Arbeitstitel. Der endgültige Name steht erst nach der Markenrecherche fest.

## Stand

Kernschleife läuft und ist headless geprüft. Noch ohne Meta-Progression.

| Abschnitt | Inhalt | Status |
|---|---|---|
| Ballistik | Abprallrechnung, Vorschau == Flug | ✅ |
| Kernschleife | Ziehen, Feuern, Spur wird Wand | ✅ |
| Inhalt | 30 geprüfte Kammern, Biom 1 | ✅ |
| Juiciness | Partikel, Shake, Tonkette | offen |
| Meta | Myzel, Stämme, Speichern | offen |
| Android | Export, Werbung, Käufe | offen |

## Entwickeln

Godot 4.5. Ohne lokale Installation:

```bash
V=4.5-stable
curl -sSL -o godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/${V}/Godot_v${V}_linux.x86_64.zip"
unzip -q godot.zip && sudo mv "Godot_v${V}_linux.x86_64" /usr/local/bin/godot
```

```bash
godot --headless --import                                  # class_name-Registry
godot --headless --path . --script tests/run_tests.gd      # Tests, ~4 s
godot --headless --path . --script tools/loesbarkeit.gd    # alle 30 Kammern prüfen
godot --headless --path . --script tools/kammersuche.gd    # Kammertabelle neu suchen
```

## Aufbau

```
scripts/kern/ballistik.gd     Abprallrechnung — reine Mathematik, testbar
scripts/daten/kammer_daten.gd Kammeraufbau und geprüfte Streuwerte
scripts/spiel/kammer.gd       Zustand: Wände, Knoten, Spuren
scripts/spiel/spore.gd        Fliegende Spore
scripts/spiel/werfer.gd       Werfer und Zielvorschau
scripts/spiel/spiel.gd        Ablauf und Eingabe
tools/sucher.gd               Gieriger Löser, von beiden Werkzeugen genutzt
```

### Zwei Zusicherungen, die das Spiel tragen

**Vorschau und Flug rufen dieselbe Funktion.** Eine Zielhilfe, die etwas
anderes zeigt als das, was dann passiert, macht ein Puzzlespiel unspielbar.

**Kammersuche und Lösbarkeitsprüfung nutzen denselben Löser.** Der erste Anlauf
hatte zwei mit verschiedener Winkelauflösung — die Suche meldete Kammern als
gelöst, die der Prüfer danach für unlösbar hielt.

## Rechtliches

Kein fremder Code, keine fremden Assets. Herkunft und Lizenz jeder Datei stehen
in [ASSETS.md](ASSETS.md), die Lizenzen der Abhängigkeiten in
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

Das vorherige Projekt (Sternwerft) liegt archiviert unter `sternwerft/`.
