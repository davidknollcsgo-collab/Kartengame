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

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **AAB-Builds nur in CI**
- Export-Templates (1,36 GB) sind über GitHub-Releases erreichbar
- Der Container ist flüchtig; Godot muss je Session neu installiert werden

## Konventionen

- Bezeichner und Kommentare auf Deutsch, passend zum Projekt
- Einrückung: 4 Leerzeichen (durchgängig, nicht mit Tabs mischen)
- `oekonomie.gd` bleibt zustandslos und UI-frei — nur so bleibt es testbar
- Jede Balancing-Änderung gehört in `scripts/data/module.gd`, nirgends sonst
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
