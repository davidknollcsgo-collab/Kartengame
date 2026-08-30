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
godot --headless --path . --script tools/kolonielauf.gd      # 50 Tage Kolonie, ~1 min
```

Der Kolonielauf ist das Werkzeug, das die meisten Fehler gefunden hat. Er
**spielt die Wellen wirklich durch** — mit dem Koloniestand, den ein normaler
Spieler zu diesem Zeitpunkt hat, nicht mit der Sollkurve. Er meldet drei Dinge:
gefallene Sitzungen, eine Wartemauer (Bauzeit, die den Tag blockiert) und eine
Fortschrittsmauer (ein Tag ohne neue Welle **und** ohne neue Kammerstufe).
Die Wellenzahl allein ist kein Fortschrittsmaß — wer heute keine neue Welle
sieht, aber seine Kolonie hebt, steckt nicht fest.

```bash
godot --headless --path . --quit-after 120            # startet das Spiel wirklich
```

**Der Testlauf allein beweist nicht, dass das Spiel laeuft.** Er laedt
`wache.gd`, `hud.gd` und `kolonie_schirm.gd` nie — ein `--script`-Lauf kennt
keine Autoloads, und `Fortschritt` ist einer. Ein Parse-Fehler in einer dieser
Dateien bleibt im Testlauf grün, und das Spiel startet dann *scheinbar*: kein
Fehler im Bild, keine Ausgabe, nur ein Prozess, der hängt. Genau so sieht ein
nicht geladenes Skript aus. Der Startlauf oben findet es in Sekunden — er läuft
auch in CI vor dem APK-Bau.

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
5. **Die Abschnittsregeln stehen im Rechenkern, nicht nur im Spiel.**
   `Regeln.stroemung`, `Regeln.helligkeit`, `Regeln.rand_kern`,
   `Regeln.tiefe_kern` — und ihr Wirkungsgrad geht in `Wellen.staerke()` ein.
   Ohne diese Kopplung wurde jeder neue Abschnitt zur Wand: der Wellenprüfer
   meldete fünf gefallene Sitzungen ab Welle 36.
6. **Es gibt keine Audiodatei und nur eine Bilddatei.** Der Ton entsteht in
   `klang.gd`, das App-Symbol in `tools/symbol.gd` — beide zur Laufzeit
   gerechnet. Das ist der Copyright-Nachweis, nicht nur ein Stil.
7. **Es gibt genau eine Ausbaukurve.** `Ausbau.leistung_faktor`, `.ziele`,
   `.reichweite_faktor`, `.winkel_faktor` sind der Koloniestand *auf*
   `stufe_soll()` — gerechnet mit denselben `Kammern`-Funktionen, die auch der
   Spieler benutzt. Vorher stand daneben eine zweite Kurve mit eigenen
   Steigungen: sie traf die Enden genau und lief in der Mitte auseinander. Bei
   Welle 49 verlangte sie sieben gleichzeitige Ziele, während die zugehörige
   Sollstufe 16 nur sechs hergab — zwölf Wellen lang prüfte der Wellenprüfer
   einen Wächter, den es auf keiner Kammerstufe gab.
8. **Eine Sitzung ist `Graben.WELLEN_JE_SITZUNG` Wellen lang.** Danach volle
   Brut, keine Wehrpolypen. Wellenprüfer und Kolonielauf rechnen seit jeher so;
   das Spiel tat es nicht — dort trug die Brut ihren Schaden über beliebig
   viele Wellen weiter und einmal gesetzte Polypen standen für immer. Gemessen
   wurde damit ein anderes Spiel als gespielt.
9. **Der Graben öffnet sich am Tiefenschacht.** `Ausbau.schacht_fuer_abschnitt`
   leitet aus der Sollkurve ab, welche Schachtstufe einen Abschnitt aufmacht;
   `KolonieStand.naechste_welle()` ist der einzige Weg, an die zu spielende
   Welle zu kommen. Ohne diese Kopplung stand der Spieler an Tag 6 in Welle 36,
   während seine Kolonie bei gut der Hälfte der Sollkurve lag.

## APK bauen

`dl.google.com` ist blockiert, also gibt es hier kein Android SDK. Der Bau
läuft in CI (`.github/workflows/apk.yml`) und lädt die APK als Artefakt hoch.

**Zwei Fallen, die zusammen sieben CI-Läufe gekostet haben:**

1. **Godot verlangt `rendering/textures/vram_compression/import_etc2_astc`.**
   Fehlt es, bricht der Android-Export mit `configuration errors:` und einer
   **leeren** Fehlerliste ab — weil `has_valid_project_configuration` die
   Meldung der vorigen Prüfung überschreibt statt sie zu ergänzen.
2. **`export/android/android_sdk_path` gehört dem Android-Exportmodul.** Von
   Hand in die Editoreinstellungen geschrieben, bevor Godot einmal lief,
   verwirft es den Schlüssel beim nächsten Sichern. Also: Godot einmal laufen
   lassen, dann die Werte per `sed` hineinschreiben.

**Lehre daraus:** raten Sie nicht in CI. Der Fehler lässt sich hier
reproduzieren — Exportvorlagen von GitHub holen und ein Schein-SDK bauen:

```bash
FAKE=/tmp/fakesdk
mkdir -p $FAKE/platform-tools $FAKE/build-tools/34.0.0 $FAKE/platforms/android-34
for f in $FAKE/platform-tools/adb $FAKE/build-tools/34.0.0/{apksigner,zipalign}; do
  printf '#!/bin/sh\nexit 0\n' > "$f"; chmod +x "$f"
done
```

Damit kostet ein Versuch Sekunden statt einer CI-Minute.

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **APK-Builds nur in CI**
- Der Container ist flüchtig; Godot muss je Session neu installiert werden

## Konventionen

- **Bezeichner und Kommentare auf Deutsch, alles Sichtbare auf Englisch.**
  Die Trennung ist Absicht: der Store ist englischsprachig, der Quelltext
  bleibt es, wie er ist. Ein Wächter hält das zusammen —
  `_test_arten_tabelle_vollstaendig` vergleicht `&"kennung"` (deutsch, fest)
  mit dem Enum, nicht den angezeigten Namen (englisch, frei)
- Einrückung: 4 Leerzeichen
- `scripts/kern/` und `scripts/daten/` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so sind sie headless testbar
- Jede Testfunktion endet mit `return true`; der Läufer wertet anderes als
  Abbruch. Und jede muss in `TESTS` stehen — ein Wächter prüft das
- GDScript leitet Typen aus Feldliteralen (`for s in [-1.0, 1.0]`) und aus
  untypisierten Feldern **nicht** ab. Dafür Konstanten mit `Packed…Array` und
  eigene Dateien mit `class_name` verwenden
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
