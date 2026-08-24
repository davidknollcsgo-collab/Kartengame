# Asset-Register

Verzeichnis **jeder** Datei im Projekt, die kein selbst geschriebener Quelltext
ist: Grafik, Ton, Schrift, Video.

Zweck ist nicht Ordnungsliebe. Bei einer Copyright-Beschwerde gegen eine
Play-Store-App ist dieses Dokument der Nachweis der Herkunft. Ohne es steht
Aussage gegen Aussage, und die App ist in der Zwischenzeit offline.

## Regeln

1. **Kein Asset ohne Eintrag.** Der Eintrag gehört in denselben Commit wie die
   Datei.
2. **Erlaubt sind nur:** selbst erzeugt · CC0 / Public Domain · SIL OFL (nur
   Schriften).
3. **Nicht erlaubt:** CC-BY (Namensnennung wird in Apps regelmäßig verletzt) ·
   CC-BY-SA (Copyleft) · „free for personal use" · Unity- oder
   Unreal-Asset-Store-Material · alles ohne eindeutig belegbare Lizenz.
4. **Im Zweifel nicht verwenden.** Eine unklare Lizenz ist ein Nein.

## Grafik

Derzeit **keine Bilddateien im Projekt**. Die gesamte Darstellung entsteht zur
Laufzeit aus `Polygon2D`, `Line2D`, `_draw()` und eigenen GDShadern. Das ist
Absicht: prozedural erzeugte Optik hat genau eine Quelle — dieses Repository.

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| _(keine)_ | | | | | |

## Ton

Noch keiner. Geplant ist Synthese über `AudioStreamGenerator`, ersatzweise CC0.

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| _(keine)_ | | | | | |

## Schriften

Noch keine. Zulässig ausschließlich SIL OFL, etwa Orbitron, Rajdhani oder Exo 2.
Systemschriften werden nicht vorausgesetzt — sie unterscheiden sich je Gerät.

| Datei | Herkunft | Autor | Lizenz | Quelle | Datum |
|---|---|---|---|---|---|
| _(keine)_ | | | | | |
