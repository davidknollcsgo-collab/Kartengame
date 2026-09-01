# Hinweise für Claude Code

## Was hier gebaut wird

**NEKTON** — eine biolumineszente Kolonie in einem Tiefseegraben.

Die Kernschleife heißt **Schlundwache**: ein Finger zieht einen Lichtkegel über
den Grabeneingang, was darin liegt wird verbrannt, zwischen den Wellen setzt
man Wehrpolypen in die Knospen der beiden Ranken.

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
godot --headless --path . --script tools/wellenpruefer.gd     # 4 Umdrehungen, ~6 min
godot --headless --path . --script tools/wellenpruefer.gd -- --spielraum
godot --headless --path . --script tools/kolonielauf.gd      # 120 Tage Kolonie, ~4 min
```

Der Kolonielauf ist das Werkzeug, das die meisten Fehler gefunden hat. Er
**spielt die Wellen wirklich durch** — mit dem Koloniestand, den ein normaler
Spieler zu diesem Zeitpunkt hat, nicht mit der Sollkurve. Er meldet drei Dinge:
gefallene Sitzungen, eine Wartemauer und eine Fortschrittsmauer (ein Tag ohne
neue Welle **und** ohne neue Kammerstufe). Die Wellenzahl allein ist kein
Fortschrittsmaß — wer heute keine neue Welle sieht, aber seine Kolonie hebt,
steckt nicht fest.

**Die Wartemauer zählt leere Sitzungen, keine Wartesekunden.** Der Simulator
setzt sich nicht mehr vor einen laufenden Bau — er schaut dreimal am Tag
herein, im Abstand von `Graben.SITZUNGEN_JE_TAG`, und entweder ist etwas zu
tun oder nicht. Leer ist eine Sitzung, in der weder ein Bau fertig wurde noch
einer begann noch eine neue Welle fiel. Vorher wartete er bis zu acht Stunden
vor einem laufenden Bau und meldete das als Mauer: vierundzwanzig Stunden am
Tag, obwohl die Kolonie durchgehend baute.

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

**`quit()` kehrt zurueck.** Es meldet der Hauptschleife nur an, dass sie
aufhören soll — der Rest der Funktion läuft weiter. In `kolonielauf.gd` fiel
der gute Ausgang deshalb unten in `quit(1)` hinein und überschrieb seinen
eigenen Exitcode: der Lauf meldete auf dem Bild „Die Kolonie trägt die
Sollkurve" und in der Schale einen Fehler. In CI stand ein rotes Kreuz an
einem Schritt, der grün war. Also `return` hinter jedes `quit()`, das nicht
das letzte Statement der Funktion ist.

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
| `--stau` | dreht den Kegel weg und macht die Brut unverwundbar |
| `--pause` | haelt das Spiel an, wie Android es im Hintergrund tut |
| `--bauen` | nimmt die Bauphase auf, statt die Welle zu starten |
| `--kolonie <n>` | öffnet den Koloniebildschirm: 0 Kammern, 1 Linien, 2 Arten, 3 Züge, 4 Tag |
| `--endschirm <n>` | 0 gefallen, 1 Sitzung gehalten, 2 Graben durchgestanden |
| `--stufen <n>` | setzt alle Kammern auf Stufe n |
| `--lehre <n>` | setzt den Lehrpfad auf Schritt n (0–7) |
| `--heim` | zeigt die Rückkehrtafel mit Beispielwerten |
| `--stoss <s>` | stößt das Stoßlicht s Sekunden vor dem Bild ab |

**`--stau` braucht man oefter, als es aussieht.** Im Vorlauf steht der
Finger fest ueber dem Schlund, und der Kegel raeumt in spaeten Wellen alles
weg, was eintritt: ein Bild von Welle 30 nach sechs Sekunden zeigte achtzehn
verbleibende Tiere in der Anzeige und kein einziges im Bild. Wer die Tiere
ansehen will, braucht den Schalter.

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

   Dazu gehören seit den Mutationen auch die **Eigenschaften**: `Arten.panzer`
   ist der Grundwert, `Wellen.panzer_in(art, welle)` der Wert, der gilt.
   Ebenso `mindest_licht_in`, `drift_in`, `stoss_in`, `tempo_in`, `radius_in`.
   Wer eine Eigenschaft direkt bei `Arten` holt, umgeht die Mutation — und
   zeichnet dann ein Tier, das sich anders verhält, als es aussieht.
2. **Was hell gezeichnet wird, macht Schaden.** `kegel.gd` fragt für jeden
   Eckpunkt dieselbe `Schlund.beleuchtung()`, die auch den Schaden bestimmt.
   Ein Kegel, der anders aussieht als er wirkt, ist unlernbar.

   Der **einzige** Zusatz darauf ist `kegel.gd::_schlieren()`: ein wanderndes
   Streiflicht, das die gezeichnete Deckung um höchstens ±20 % moduliert und
   sich über die Fläche zu null mittelt. Es ist Wasser vor dem Licht, nicht
   mehr Licht — Form und Reichweite des Kegels bleiben unberührt, und wo er
   hell ist, bleibt er hell. `_test_schlieren_bleiben_schmuck` hält die
   Grenze fest; alles darüber wäre wieder eine zweite Wahrheit.
3. **Die Wellenstärke wird aus der Sollkurve abgeleitet, nicht frei gewählt.**
   `Wellen.staerke()` rechnet aus `Ausbau.durchsatz()`. Eine frei hochgezogene
   Wachstumszahl ergab 55 Wellen ohne einen einzigen Verlust und dann
   Totalverlust in Welle 56.
4. **Kein Ausbau darf etwas verschlechtern.** Ein Test hält das fest.
5. **Was die Welle leichter macht, geht ebenfalls in `Ausbau.durchsatz()`
   ein.** Das Stoßlicht ist eine zweite Schadensquelle, die jeder Spieler in
   jeder Welle hat. Fällt es aus dem Durchsatz heraus, wächst die
   Wellenstärke an einer Leistung vorbei, die es tatsächlich gibt — und der
   Wellenprüfer misst ein Spiel, das leichter ist als das gespielte.
   `_test_stosslicht_steht_in_der_sollkurve` hält es fest, und
   `tools/simulation.gd` **ruft es ab**: ein Prüfer, der eine eingerechnete
   Leistung nicht benutzt, meldet Wände, die es nicht gibt.

6. **Was die Welle schwerer macht, geht in `Wellen.staerke()` ein.**
   `Regeln.wirkungsgrad` und `Mutationen.wirkungsgrad`, zusammengefasst in
   `Wellen.umgebung()`. Ohne diese Kopplung wurde jeder neue Abschnitt zur
   Wand: der Wellenprüfer meldete fünf gefallene Sitzungen ab Welle 36. Bei
   den Mutationen ist es genauso ausgegangen — jede gefallene Sitzung lag auf
   einer Welle mit `AUFGEDUNSEN`, der einzigen, der ich keinen Wirkungsgrad
   zugetraut hatte.

   Und das Leitwesen zählt mit: sein Leben ist `(Kegel · Umgebung − Panzer) ·
   Sekunden`. `LEIT_SEKUNDEN` heißt „so lange soll es dauern"; wird der
   Gegenwind nicht herausgerechnet, dauert es länger, und zwar genau dort, wo
   ohnehin der Höhepunkt steht.
7. **Es gibt keine Audiodatei und nur eine Bilddatei.** Der Ton entsteht in
   `klang.gd`, das App-Symbol in `tools/symbol.gd` — beide zur Laufzeit
   gerechnet. Das ist der Copyright-Nachweis, nicht nur ein Stil.
8. **Es gibt genau eine Ausbaukurve.** `Ausbau.leistung_faktor`, `.ziele`,
   `.reichweite_faktor`, `.winkel_faktor` sind der Koloniestand *auf*
   `stufe_soll()` — gerechnet mit denselben `Kammern`-Funktionen, die auch der
   Spieler benutzt. Vorher stand daneben eine zweite Kurve mit eigenen
   Steigungen: sie traf die Enden genau und lief in der Mitte auseinander. Bei
   Welle 49 verlangte sie sieben gleichzeitige Ziele, während die zugehörige
   Sollstufe 16 nur sechs hergab — zwölf Wellen lang prüfte der Wellenprüfer
   einen Wächter, den es auf keiner Kammerstufe gab.
9. **Eine Sitzung ist `Graben.WELLEN_JE_SITZUNG` Wellen lang.** Danach volle
   Brut, keine Wehrpolypen. Wellenprüfer und Kolonielauf rechnen seit jeher so;
   das Spiel tat es nicht — dort trug die Brut ihren Schaden über beliebig
   viele Wellen weiter und einmal gesetzte Polypen standen für immer. Gemessen
   wurde damit ein anderes Spiel als gespielt.
10. **Einkommen und Kosten wachsen mit derselben Rate.** Kammern kosten
   geometrisch; ein Einkommen, das linear oder auch nur langsamer geometrisch
   wächst, holt das nie wieder ein. Deshalb sind **beide Einkommensquellen aus
   den Kosten abgeleitet**: `Kammern.filter_je_stunde()` und `Wellen.ertrag()`
   rechnen aus `Kammern.rundenkosten()`, geteilt durch `TAGE_JE_RUNDE`. Vorher
   stand dort `FILTER_WACHSTUM := 1.26` gegen Kosten von 1.49 bis 1.58 — der
   Kolonielauf meldete zwischen Tag 40 und Tag 120 sechs neue Kammerstufen und
   250 000 ungenutzten Nährstoff. Ein Test hält das Verhältnis über 400 Wellen
   fest.

11. **Kein Bau dauert länger als der Abstand zwischen zwei Besuchen.**
   `Kammern.ZEIT_DECKEL` ist aus `Graben.SITZUNGEN_JE_TAG` abgeleitet, mit
   Sicherheitsabstand nach unten. Bei zwei Tagen Deckel lagen ab Stufe 24 alle
   fünf Kammern daran, eine Runde kostete zehn Tage, und der Kolonielauf
   meldete an Tag 79 vierundzwanzig Stunden Leerlauf. Bei *genau* acht Stunden
   wurde ein Bau sieben Minuten nach dem nächsten Besuch fertig — der Spieler
   kam jedes zweite Mal umsonst.

12. **Die Sollkurve endet, wo die Kammern enden.** `Ausbau.stufe_soll()` ist
   auf `Kammern.HOECHSTSTUFE` gedeckelt, ebenso die Zähigkeit über
   `Ausbau.stufe_kurve()`. Der Graben läuft weiter; was ihn ab dort
   unterscheidet, sind Abschnittsregeln und Mutationen, nicht mehr Leistung.
   Ohne den Deckel verlangte die Kurve ab Welle 241 eine Stufe, die es auf
   keiner Kammer gibt.

13. **Der Graben öffnet sich am Tiefenschacht.** `Ausbau.schacht_fuer_abschnitt`
   leitet aus der Sollkurve ab, welche Schachtstufe einen Abschnitt aufmacht;
   `KolonieStand.naechste_welle()` ist der einzige Weg, an die zu spielende
   Welle zu kommen. Ohne diese Kopplung stand der Spieler an Tag 6 in Welle 36,
   während seine Kolonie bei gut der Hälfte der Sollkurve lag.

14. **Nische und Ranke kommen aus derselben Kurve.** `Graben.ranke()` sagt,
   wo die Ranke verläuft; `Graben.NISCHEN` liest die Knospenorte von dort ab.
   Vorher stand eine feste Liste aus acht Punkten im Quelltext, und die Wände,
   in denen sie saßen, gibt es nicht mehr. Zwei Beschreibungen derselben Kurve
   laufen auseinander, und dann liegt die Tippfläche neben der Knospe —
   `_test_nischen_liegen_auf_den_ranken` hält es fest.

15. **Ein gepanzertes Leitwesen darf nie in einem abgedunkelten Abschnitt
   stehen.** Der Panzer zieht einen *festen* Betrag je Sekunde ab, und
   `Regeln.DUNKEL` nimmt dem Kegel einen großen Teil seiner Helligkeit — von
   einem Fünftel frisst ein fester Abzug alles. Beides zusammen ist kein
   schwerer Kampf, sondern ein unbesiegbares Tier, und der Wellenprüfer
   meldet es als Wand, ohne zu sagen warum. `Arten.LEITFOLGE` ordnet die drei
   Leitwesen von Hand den acht Abschnitten zu;
   `_test_gepanzertes_leitwesen_nie_im_dunkeln` ist der Grund, warum das von
   Hand bleiben darf.

16. **Die Kette zahlt Punkte, niemals Nährstoff.** Einkommen und Kosten sind
   aneinander gekoppelt (Punkt 10); ein Multiplikator, der am Können hängt,
   hätte daneben keinen Platz — wer gut spielt, wäre nicht schneller fertig,
   sondern in einer anderen Wirtschaft. Die Kette ist deshalb bewusst keine
   Währung, sondern eine Bestmarke.
   `_test_kette_zahlt_punkte_und_keinen_naehrstoff` liest den Quelltext:
   `Fortschritt.aendere()` und `verdient` dürfen nie in derselben Anweisung
   stehen wie `kette`.

17. **`get_display_safe_area()` nur auf dem Telefon fragen.** Auf dem
   Schreibtisch liefert sie den ganzen *Bildschirm* und nicht das Fenster —
   und der ist gerne kleiner als ein Hochformatfenster von 1280 Pixeln. Aus
   der Differenz wurde ein unterer Rand von vierhundert Pixeln, und die
   Knopfzeile sprang mitten ins Bild. Also `OS.has_feature("mobile")` davor
   und jeden Rand auf 12 % der Bildkante deckeln: was darüber liegt, ist eine
   Fehlmessung und keine Kerbe.

18. **Was Zeit kostet und nichts zahlt, steht außerhalb des Budgets.** Die
   Funkenblüte ist kein Räuber: sie steht in keiner `Wellen.auftritte()`,
   zahlt keinen Nährstoff und wird vom Stoßlicht nicht getroffen. Alle drei
   Regeln haben denselben Grund — sie ist **optional**. Ein Körper im
   Wellenbudget müsste bezahlt sein; ein Fund, der Nährstoff ausschüttet,
   verschöbe die Wirtschaft; und ein Ziel, das der Stoß gratis mitnimmt, ist
   keine Entscheidung. `_test_bluete_bleibt_ausserhalb_der_wirtschaft` hält
   die ersten beiden fest.

19. **Weltpunkt zu Bildschirmpunkt geht über den Viewport, nicht über das
   Control.** `Control.get_canvas_transform()` liefert die Verschiebung der
   CanvasLayer, in der das Bedienbild hängt — und die ist die
   Einheitsabbildung. Gebraucht wird `get_viewport().get_canvas_transform()`,
   die Abbildung der Kamera. Der Fehler stand lange unbemerkt in
   `_schwebende_zahlen()`: die Ausbeutezahlen werden an den Bildrand geklemmt,
   also standen sie da — nur nie über dem Tier, das gestorben war. Sichtbar
   wurde er erst, als der Lehrring auf eine Knospe zeigen sollte und gar nicht
   im Bild auftauchte.

## Fuer den Laden

`STORE.md` ist die Abgabemappe: was der Bauauftrag liefert, was nur von Hand
geht, die Texte fuer den Eintrag und die Antworten fuer Datensicherheit und
Inhaltseinstufung.

```bash
godot --headless --path . --script tools/symbol.gd   # Symbolsatz neu rechnen
tools/ladenbilder.sh build/laden                     # Screenshots, 1080x1920
python3 tools/seite.py docs                          # privacy.html aus PRIVACY.md
```

**Der Ladestand `Play` baut ein App Bundle, nicht eine APK.** Play nimmt fuer
neue Apps kein APK mehr an. Er braucht `use_gradle_build=true`, weil `min_sdk`
und `target_sdk` sonst wirkungslos bleiben, und einen Freigabeschluessel aus
den Repository-Geheimnissen - im Quelltext hat der nichts zu suchen.

**In Ladenbildern darf nichts stehen, was es im Spiel nicht gibt.** `--stau`
setzte die Brut auf 1000000, und in der Kopfzeile stand "999997 / 44". Jetzt
macht der Schalter die Brut unverwundbar, statt die Anzeige zu faelschen.

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
- Große Zahlen im Sichtbaren durch `Zahl.kurz()`. Seit die Kolonie kein Ende
  hat, kostet eine volle Kammerrunde auf Stufe 40 knapp fünf Milliarden —
  sechzehn Ziffern nebeneinander sind auf einem Telefon keine Zahl mehr
- Eigenschaften eines Räubers über `Wellen.*_in(art, welle)`, nie über
  `Arten.*` direkt. Sonst umgeht man die Mutation, und das Tier verhält sich
  anders, als es aussieht
