# Hinweise für Claude Code

## Godot beschaffen

Godot ist in dieser Umgebung nicht vorinstalliert und `godotengine.org` ist
durch die Netzwerkpolicy blockiert. Der Download über GitHub-Release-Assets
funktioniert jedoch:

```bash
V=4.5-stable
curl -sSL -o /tmp/godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/${V}/Godot_v${V}_linux.x86_64.zip"
unzip -oq /tmp/godot.zip -d /tmp/g
mv "/tmp/g/Godot_v${V}_linux.x86_64" /usr/local/bin/godot && chmod +x /usr/local/bin/godot
```

## Tests

```bash
godot --headless --import                                # class_name-Registry
godot --headless --path . --script tests/run_tests.gd    # Exitcode 1 bei Fehler
```

`--check-only --script <datei>` prüft eine Datei **isoliert** und kennt die
`class_name`-Registry nicht — `Modul`, `Oekonomie` und `Zahl` erscheinen dort
fälschlich als undeklariert. Für echte Prüfung immer `--import` und den
Testlauf verwenden.

## Optik prüfen (Screenshots)

Godot rendert hier über einen virtuellen Bildschirm mit Mesa-Software-GL. Damit
lässt sich die Darstellung tatsächlich ansehen statt zu erraten:

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 \
  -- --schuss /pfad/bild.png --vorrat
```

`--schuss <datei>` speichert nach 45 Bildern und beendet. `--vorrat` baut eine
laufende Station auf — der Anfangszustand zeigt nur dunkle Baugruppen und sagt
über die Optik im Betrieb nichts aus. Beide Schalter greifen nur im
Debug-Build (`OS.is_debug_build()`).

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **AAB-Builds nur in CI**
- Export-Templates (1,36 GB) sind über GitHub-Releases erreichbar
- Der Container ist flüchtig; Godot muss je Session neu installiert werden

## Konventionen

- Bezeichner und Kommentare auf Deutsch, passend zum Projekt
- Einrückung: 4 Leerzeichen (durchgängig, nicht mit Tabs mischen)
- `oekonomie.gd` und `raster.gd` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so lassen sie sich headless testen. Wer `Spielstand`
  in einer Datei referenziert, macht sie für `--script` unbrauchbar
- Jede Testfunktion endet mit `return true`; der Läufer wertet einen anderen
  Rückgabewert als Abbruch. Ohne das meldet ein abgestürzter Test grün
- Jede Balancing-Änderung gehört in `scripts/data/module.gd`, nirgends sonst
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
