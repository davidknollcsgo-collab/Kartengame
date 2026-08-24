# Lizenzen der Abhängigkeiten

MIT und Apache 2.0 verlangen, dass der Lizenztext mit der Anwendung
ausgeliefert wird. Diese Datei speist deshalb den Bildschirm **Lizenzen** im
Optionsmenü. Fehlt dieser Bildschirm, verletzt die App die Lizenzen — auch wenn
niemand klagt.

## Godot Engine

- Version: 4.5 stable
- Lizenz: MIT
- Quelle: https://github.com/godotengine/godot
- Copyright (c) 2014-present Godot Engine contributors
- Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur

Godot bringt eigene Drittanbieter-Komponenten mit. Deren Lizenztexte liefert
die Engine über `Engine.get_license_text()` und
`Engine.get_copyright_info()` — der Lizenz-Bildschirm liest sie zur Laufzeit
aus, statt sie hier zu duplizieren.

## Noch nicht eingebunden

Kommen in Phase 5 dazu und werden dann hier ergänzt:

| Komponente | Lizenz | Zweck |
|---|---|---|
| `godot-google-play-billing` | MIT | In-App-Käufe |
| AdMob-Plugin | MIT / Apache 2.0 | Rewarded + Interstitial |
| Google Mobile Ads SDK | Google-Lizenz | Werbeauslieferung |
