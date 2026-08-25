# Hinweise für Claude Code

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
godot --headless --import                                # class_name-Registry
godot --headless --path . --script tests/run_tests.gd    # ~4 s, Exitcode 1 bei Fehler
godot --headless --path . --script tools/loesbarkeit.gd  # alle 30 Kammern prüfen
godot --headless --path . --script tools/kammersuche.gd  # Kammertabelle neu suchen
```

`--check-only --script <datei>` prüft eine Datei **isoliert** und kennt die
`class_name`-Registry nicht — Klassen erscheinen dort fälschlich als
undeklariert. Für echte Prüfung immer `--import` und den Testlauf verwenden.

**Achtung beim Fehler-Check in der Shell:** `godot ... | grep ... | head` gibt
immer Erfolg zurück, weil `head` gelingt. Die Ausgabe in eine Variable fangen
und auf leer prüfen.

## Optik prüfen (Screenshots)

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 \
  -- --schuss /pfad/bild.png --kammer 7 --feuere 3
```

| Schalter | Wirkung |
|---|---|
| `--schuss <datei>` | speichert und beendet |
| `--kammer <n>` | lädt Kammer n |
| `--gezielt` | zeigt eine gezogene Zielhilfe |
| `--feuere <n>` | feuert n Schüsse auf Knoten und wartet den Flug ab |
| `--mitten` | nimmt **während** des Flugs auf (Spur und Funken sichtbar) |
| `--myzel` | öffnet den Myzel-Bildschirm mit Guthaben |

## Spielbare Einzeldatei

```bash
godot --headless --path . --export-release "Web" docs/index.html
python3 tools/einzeldatei.py /pfad/hypha.html
```

Packt den Web-Export in **eine** HTML-Datei (gzip + base64, im Browser
entpackt). Roh sind es 38 MB, als Artifact sind höchstens 16 MB erlaubt.

Der Start kommt ohne jede Netzanfrage aus, weil die Artifact-Seite unter einer
strengen Inhaltsrichtlinie läuft, die `data:` und `blob:` abweist.

## Zwei Zusicherungen, die nicht aufgeweicht werden dürfen

1. **Vorschau und Flug rufen dieselbe Funktion** (`Ballistik.flug`). Eine
   Zielhilfe, die etwas anderes zeigt als das, was passiert, macht ein
   Puzzlespiel unspielbar.
2. **Kammersuche und Lösbarkeitsprüfung nutzen denselben Löser**
   (`tools/sucher.gd`). Getrennte Löser hatten verschiedene Winkelauflösungen
   und kamen zu verschiedenen Ergebnissen.

Dazu: **kein Myzel-Knoten darf etwas verschlechtern.** Die Lösbarkeit aller
Kammern ist mit den Grundwerten geprüft; ein erschwerender Knoten könnte eine
geprüfte Kammer unlösbar machen. Ein Test hält das fest.

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **AAB-Builds nur in CI**
- Der Container ist flüchtig; Godot muss je Session neu installiert werden

## Konventionen

- Bezeichner und Kommentare auf Deutsch
- Einrückung: 4 Leerzeichen
- `ballistik.gd` und `kammer_daten.gd` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so sind sie headless testbar
- Jede Testfunktion endet mit `return true`; der Läufer wertet anderes als
  Abbruch. Und jede muss in `TESTS` stehen — ein Wächter prüft das
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
