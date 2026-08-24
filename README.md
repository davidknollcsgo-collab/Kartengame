# STERNWERFT

Ein 2D-Top-Down-Idle-Spiel: eine treibende Werft-Station wird Modul für Modul
wieder in Betrieb genommen. Drohnen transportieren die Fracht sichtbar zwischen
den Modulen — die Station läuft weiter, auch wenn niemand zusieht.

> Arbeitstitel. Der endgültige Name steht erst nach der Markenrecherche fest.

## Stand

Phase 1 von 7 — der Rechenkern steht und ist headless getestet.
Noch ohne Darstellung.

| Phase | Inhalt | Status |
|---|---|---|
| 1 | Ökonomie, Formeln, Formatter, Tests | ✅ |
| 2 | Station, Module, Drohnen, Kamera | offen |
| 3 | Prestige-UI, Offline-Dialog, Speichern | offen |
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

Der Testlauf endet mit Code 1, sobald eine Zusicherung fehlschlägt.

## Aufbau

```
scripts/data/module.gd        Stammdaten der 8 Module — hier wird gebalanced
scripts/autoload/oekonomie.gd Reine Mathematik, zustandslos, statisch
scripts/autoload/zahl.gd      Zahlen- und Zeitformatierung
scripts/autoload/spielstand.gd Zustand + Signale (Autoload "Spielstand")
tests/run_tests.gd            Headless-Testlauf
```

`oekonomie.gd` kennt weder Szenenbaum noch UI. Genau deshalb lässt sich das
gesamte Balancing testen, ohne das Spiel zu starten.

## Rechtliches

Kein fremder Code, keine fremden Assets. Herkunft und Lizenz jeder Datei stehen
in [ASSETS.md](ASSETS.md), die Lizenzen der Abhängigkeiten in
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
