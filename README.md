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
Knospen an den Ranken und setzt dort Wehrpolypen.

Eine Welle dauert 40 bis 70 Sekunden. Der Kegel fasst nur wenige Räuber
gleichzeitig; ein Schwarm lässt sich nicht wegleuchten, sondern muss sortiert
werden.

## Was schon steht

| Bereich | Stand |
|---|---|
| Rechenkern (`Schlund`) | Lichtkegel, Bahnen, Zielauswahl — 61 Tests grün |
| Endloser Graben | die Wellen hören nicht auf; vier volle Umdrehungen sind durchgerechnet |
| Neun Räuberarten | vier mit eigener Regel: Panzer, Mindestlicht, Querdrift, Schub |
| Leitwesen | die Schlundmutter am Ende jedes Abschnitts — ein Höhepunkt alle zehn Wellen |
| Mutationen | ab der zweiten Umdrehung tragen Wellen eigene Züge: gepanzert, lichtscheu, unstet, stoßweise, hastig, aufgedunsen |
| Bestiarium | jede begegnete Art mit ihrer Regel; unbekannte zeigen nur, ab wann sie kommen |
| Grafische Tiefe | offenes Wasser mit Tiefenverlauf, Staub und wandernde Schlieren im Lichtkegel, Randlicht auf jedem Tier, Schlick im Vordergrund |
| Das Stoßlicht | ein Ring, den der Wächter abstößt — er trifft alles, was er kreuzt, auch außerhalb des Kegels, und lädt sich selbst nach. Er steht in `Ausbau.durchsatz()`, ist also Teil der Sollkurve und kein Geschenk |
| Der Einstieg | sieben Schritte mit Titel, Satz und einem Ring auf dem Ding, um das es geht — er schreitet an Ereignissen fort, nicht an einer Uhr |
| Der Wächter | eigene Figur vor dem Kegel: Haftwurzeln, atmende Kiemen, Adernetz und ein Organ, das beim Feuern aufflammt. Er zuckt, wenn die Brut getroffen wird |
| Die Brut | ein Gelege statt einer Punktreihe: die Eier stecken zwischen Bett und Lippe der Membran |
| Leben im Wasser | treibende Quallen und Schwärmchen weit hinten — ausdrücklich keine Spielfiguren |
| Rückmeldung | Zittern bei Treffern, farbiger Bildrand beim Verlust eines Eis, Zeitlupe auf das erlegte Leitwesen |
| Sechs Grabenabschnitte | eigene Regel **und** eigene Farbe je Abschnitt: Strömung, Trübung, Dunkelphasen, Streulicht |
| Grabentiefe | der Tiefenschacht öffnet die Abschnitte — abgeleitet aus der Sollkurve |
| Kolonie | fünf Kammern mit Stufen, Kosten und Bauzeiten; 120 Tage gemessen, ohne Warte- und ohne Fortschrittsmauer |
| Brutlinien | drei Linien, gezüchtet statt gezogen — kein Zufall, keine Kiste |
| Tagesziel | drei Aufgaben, Anwesenheitszähler, Lohn wächst mit dem Fortschritt |
| Ton | vollständig synthetisiert, keine Audiodatei |
| Speichern | verschlüsselt, mit Prüfung jedes gelesenen Werts |
| Android | Debug-APK baut in CI und lässt sich sideloaden |

## Was noch fehlt

Geisterdaten und Bestenliste, Werbung und Käufe — alles drei braucht Konten
und SDKs, die außerhalb dieses Repositorys eingerichtet werden. Der
vollständige Bauplan steht im Projektplan.

## Auf dem Telefon spielen

Bei jedem Push baut die CI (`Veroeffentlichung`) die App und hängt sie an eine
**Vorabveröffentlichung** mit fester Marke — die Adresse bleibt also gleich,
und dort liegt immer der neueste Stand:

**Releases → `test-claude-delete-all-previous-44i1x5` → `nekton.apk`**

Am Telefon reicht es, diesen Link im Browser zu öffnen und die
heruntergeladene Datei anzutippen. Android fragt einmal nach der Erlaubnis,
Apps aus dieser Quelle zu installieren — das ist der normale Weg für eine App,
die nicht aus dem Store kommt.

Die APK ist mit einem Debug-Schlüssel signiert und nur zum Sideloaden gedacht.
Für den Play Store braucht es einen eigenen, dauerhaft aufbewahrten Schlüssel;
geht der verloren, lässt sich die App nie wieder aktualisieren.

### Ohne Installation nachsehen

Derselbe Bau landet als Seite auf **GitHub Pages** — eine Adresse, dieselbe am
Rechner und am Telefon. Zum schnellen Nachsehen ist das der kürzere Weg; die
App auf dem Telefon bleibt die Fassung, um die es geht. Der Link steht im
Actions-Lauf beim Schritt *Seite veröffentlichen*.

Wer die Datei lieber selbst in der Hand hat: an derselben Veröffentlichung
hängt `nekton.html` — das ganze Spiel in einer einzigen Datei, ohne Server.

## Bauen und prüfen

```bash
godot --headless --import                                  # Registry aufbauen
godot --headless --path . --script tests/run_tests.gd      # Tests
godot --headless --path . --script tools/wellenpruefer.gd  # vier Umdrehungen
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
