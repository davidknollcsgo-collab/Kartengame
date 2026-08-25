# Hinweise für Claude Code

## Was hier gebaut wird

**NEKTON** — eine biolumineszente Kolonie in einem Tiefseegraben.

Die Kernschleife heißt **Schlundwache**: ein Finger zieht einen Lichtkegel über
den Grabeneingang, was darin liegt wird verbrannt, zwischen den Wellen setzt
man Wehrpolypen in feste Nischen.

Die Struktur ist von Kingshot abgeschaut — casual Kernschleife vorn,
Aufbauspiel dahinter. **Nur die Struktur.** Kein Code, kein Asset, keine Figur,
kein Text von dort. Alles Sichtbare und Lesbare entsteht in diesem Repository:
Grafik prozedural im Code, Ton synthetisiert, Story und Namen selbst
geschrieben. Der Plan hat dazu einen eigenen Abschnitt; `ASSETS.md` ist der
Nachweis.

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
godot --headless --import                                     # class_name-Registry
godot --headless --path . --script tests/run_tests.gd         # ~3 s, Exitcode 1 bei Fehler
godot --headless --path . --script tools/wellenpruefer.gd     # alle 60 Wellen, ~2 min
godot --headless --path . --script tools/wellenpruefer.gd -- --spielraum
```

**`--import` nach jeder neuen Datei mit `class_name`.** Sonst kennt die
Registry die Klasse nicht, und was dann passiert, sieht nicht nach dem Fehler
aus, der es ist: das Skript lädt gar nicht erst, die Ausgabe bleibt leer, und
der Lauf wirkt wie eine Endlosschleife. Das hat hier schon zwanzig Minuten
gekostet.

`--check-only --script <datei>` prüft eine Datei **isoliert** und kennt die
Registry ebenfalls nicht — Klassen erscheinen dort fälschlich als undeklariert.
Für echte Prüfung immer `--import` und den Testlauf verwenden.

**Achtung beim Fehler-Check in der Shell:** `godot ... | grep ... | head` gibt
immer Erfolg zurück, weil `head` gelingt. Die Ausgabe in eine Variable fangen
und auf leer prüfen.

## Optik prüfen (Screenshots)

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 \
  -- --schuss /pfad/bild.png --welle 22 --zeit 20
```

| Schalter | Wirkung |
|---|---|
| `--schuss <datei>` | speichert und beendet |
| `--welle <n>` | beginnt bei Welle n |
| `--zeit <s>` | rechnet n Sekunden Welle mit festem Takt vor |
| `--polypen <n>` | stellt n Wehrpolypen auf |
| `--bauen` | nimmt die Bauphase auf, statt die Welle zu starten |

## Spielbare Einzeldatei

```bash
godot --headless --path . --export-release "Web" docs/index.html
python3 tools/einzeldatei.py /pfad/nekton.html
```

Packt den Web-Export in **eine** HTML-Datei (gzip + base64, im Browser
entpackt). Der Start kommt ohne jede Netzanfrage aus, weil die Artifact-Seite
unter einer strengen Inhaltsrichtlinie läuft, die `data:` und `blob:` abweist.

## Zusicherungen, die nicht aufgeweicht werden dürfen

1. **Spiel und Wellenprüfer rechnen mit denselben Funktionen.**
   `Schlund.bahn`, `Schlund.beleuchtung`, `Schlund.brennende`,
   `Wellen.leben_in`. Der einzige erlaubte Unterschied ist, wer zielt: dort
   eine Rechnung, hier ein Daumen. Bei HYPHA hatten Sucher und Prüfer getrennte
   Rechnungen und kamen zu verschiedenen Ergebnissen.
2. **Was hell gezeichnet wird, macht Schaden.** `kegel.gd` fragt für jeden
   Eckpunkt dieselbe `Schlund.beleuchtung()`, die auch den Schaden bestimmt.
   Ein Kegel, der anders aussieht als er wirkt, ist unlernbar.
3. **Die Wellenstärke wird aus der Sollkurve abgeleitet, nicht frei gewählt.**
   `Wellen.staerke()` rechnet aus `Ausbau.durchsatz()`. Eine frei hochgezogene
   Wachstumszahl ergab 55 Wellen ohne einen einzigen Verlust und dann
   Totalverlust in Welle 56.
4. **Kein Ausbau darf etwas verschlechtern.** Ein Test hält das fest.

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **AAB-Builds nur in CI**
- Der Container ist flüchtig; Godot muss je Session neu installiert werden

## Konventionen

- Bezeichner und Kommentare auf Deutsch
- Einrückung: 4 Leerzeichen
- `scripts/kern/` und `scripts/daten/` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so sind sie headless testbar
- Jede Testfunktion endet mit `return true`; der Läufer wertet anderes als
  Abbruch. Und jede muss in `TESTS` stehen — ein Wächter prüft das
- GDScript leitet Typen aus Feldliteralen (`for s in [-1.0, 1.0]`) und aus
  untypisierten Feldern **nicht** ab. Dafür Konstanten mit `Packed…Array` und
  eigene Dateien mit `class_name` verwenden
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
