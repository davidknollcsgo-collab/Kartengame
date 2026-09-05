# STERNWERFT

Ein 2D-Top-Down-Idle-Spiel: eine treibende Werft-Station wird Modul für Modul
wieder in Betrieb genommen. Drohnen transportieren die Fracht sichtbar zwischen
den Modulen — die Station läuft weiter, auch wenn niemand zusieht.

> Arbeitstitel. Der endgültige Name steht erst nach der Markenrecherche fest.

## Stand

Phase 3 von 7 — **spielbar**. Aufbau, Kaufmengen, Prestige, Offline-Ertrag und
Speichern funktionieren; der Fortschritt überlebt den Neustart. Es fehlen
Android-Export, Werbung und In-App-Käufe.

Erstes Prestige nach rund zwei Stunden (gemessen, siehe `tools/balance.gd`).

| Phase | Inhalt | Status |
|---|---|---|
| 1 | Ökonomie, Formeln, Formatter, Tests | ✅ |
| 2 | Station, Module, Drohnen, Kamera | ✅ |
| 3 | Prestige-UI, Offline-Dialog, Speichern | ✅ |
| 4 | Android-Export, AAB | offen |
| 5 | AdMob, Play Billing, Consent | offen |
| 6 | Datenschutz, Data Safety, Lizenz-Screen | offen |
| 7 | Closed Test, Balancing, Release | offen |

## Entwickeln

Godot 4.5 wird benötigt. Ohne lokale Installation:

```bash
V=4.5-stable
curl -sSL -o godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/${V}/Godot_v${V}_linux.x86_64.zip"
unzip -q godot.zip && sudo mv "Godot_v${V}_linux.x86_64" /usr/local/bin/godot
```

```bash
godot --headless --import                          # class_name-Registry bauen
godot --headless --path . --script tests/run_tests.gd   # Tests
```

Der Testlauf endet mit Code 1, sobald eine Zusicherung fehlschlägt **oder** ein
Test durch einen Laufzeitfehler abbricht.

Darstellung ansehen (virtueller Bildschirm, Software-Rendering):

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 \
  -- --schuss bild.png --vorrat
```

## Aufbau

```
scripts/data/module.gd        Stammdaten der 8 Module — hier wird gebalanced
scripts/station/raster.gd     Layoutgeometrie, szenenfrei und testbar
scripts/station/*.gd          Station, Baugruppen, Kern, Drohnen, Kamera
scripts/ui/hud.gd             Kopfzeile
shaders/sterne.gdshader       Sternenfeld, gerechnet statt gezeichnet
scripts/autoload/oekonomie.gd Reine Mathematik, zustandslos, statisch
scripts/autoload/zahl.gd      Zahlen- und Zeitformatierung
scripts/autoload/spielstand.gd Zustand + Signale (Autoload "Spielstand")
scripts/autoload/speicher.gd  Verschlüsseltes Speichern, dateiebene, testbar
scripts/ui/leiste.gd          Kaufmenge und Prestige
scripts/ui/dialog.gd          Modales Fenster
scripts/ui/ausbau_schirm.gd   Ausbauten gegen Quanten
scripts/ui/bericht_schirm.gd  Kennzahlen und Errungenschaften
scripts/data/waehrung.gd      Namen und Zeichen der drei Währungen
scripts/data/ausbau.gd        Stammdaten der Ausbauten
scripts/data/errungenschaft.gd Errungenschaften und Belohnungen
tests/run_tests.gd            Headless-Testlauf
tools/balance.gd              Balancing-Messung über 48 Spielstunden
```

`oekonomie.gd` kennt weder Szenenbaum noch UI. Genau deshalb lässt sich das
gesamte Balancing testen, ohne das Spiel zu starten.

## Rechtliches

Kein fremder Code, keine fremden Assets. Herkunft und Lizenz jeder Datei stehen
in [ASSETS.md](ASSETS.md), die Lizenzen der Abhängigkeiten in
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## Weitere Projekte im selben Verzeichnisbaum

Zwei eigenständige Werkzeuge, die mit dem Spiel nichts zu tun haben. Jedes hat
eigene Abhängigkeiten, eigene Tests und einen eigenen CI-Arbeitsablauf.

- `vertragsfristen-waechter/` — überwacht Kündigungsfristen von
  Versicherungen, Software-Abos, Miet- und Wartungsverträgen
- `lizenzlotse/` — findet ungenutzte Microsoft-365-Lizenzen und beziffert sie
  in Euro
