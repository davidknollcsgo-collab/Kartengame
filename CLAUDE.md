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
| `--offen` | Rundumlauf ohne Nebel — für Schüsse, die den Grund zeigen sollen |
| `--ende` | Rundumlauf: der Bericht nach der Fahrt, mit Beispielwerten |
| `--pause` | Rundumlauf: die Pausentafel, mit Beispielwerten |
| `--marke` | nur Schriftzug über der Szene — für das Feature-Bild |
| `--stufen <n>` | im Rundumlauf: alle Kammern auf Stufe n |
| `--kolonie <n>` | im Rundumlauf: schlägt den Ausbau auf Reiter n auf |

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

20. **Der Ton wird gemessen, nicht gehört.** Es gibt hier kein Audiogerät und
   in CI erst recht keines — `klang.gd` rechnet seine Puffer seit Beginn ins
   Blinde, und ein falscher Ton wirft keinen Fehler. Die beiden Prüfer lesen
   deshalb die Abtastwerte zurück: Ausschlag, Übersteuerung, Anfang und Ende
   bei null, Ausklang — und beim Grundton die Naht der Schleife. Sie fanden
   auf dem ersten Lauf zwei echte Fehler: der Verlustton setzte nach 2 ms bei
   der halben Spitze ein (ein Knacks, kein Schlag), und die Blende des
   Grundtons mischte zwei Stellen zusammen, die eine Vierteltonne
   auseinanderlagen — der Sprung an der Naht war doppelt so groß wie der
   größte Schritt im Inneren und schlug alle sechs Sekunden einmal. Eine
   Blende braucht **Überhang**: Material von hinter dem Ende, sonst schließt
   sie nichts.

21. **Eine Einstellung, die den Neustart nicht übersteht, ist schlimmer als
   keine.** Die Lautstärke stand nur in `Klang.laut` und wurde nirgends
   gesichert — wer den Ton ausschaltete, hatte ihn beim nächsten Start wieder
   auf 70 %. Beide Regler liegen jetzt im `KolonieStand` (`laut`, `beben`);
   `Fortschritt.uebernimm_einstellungen()` trägt sie beim Start in die
   Autoloads, `merke_einstellungen()` den Weg zurück. Und der Rundlauf-Test
   vergleicht seit demselben Commit **das ganze Wort** statt einer von Hand
   gepflegten Feldliste: ein Feld, das man zu schreiben vergisst, fällt einer
   Liste nicht auf, die man ebenso vergisst.

22. **Das Beben ist sparsam und abschaltbar.** `Tastsinn` (Autoload) bebt nur
   bei vier Ereignissen — Treffer an der Brut, gefallenes Leitwesen,
   Stoßlicht, Ende der Sitzung — mit einer Sperre von 0,14 s, damit
   gleichzeitig Fallendes nicht zu einem Brummen verschmilzt. Ein Beben je
   Treffer wäre in Welle 55 Dauerbrummen und Akkufraß. Der Android-Export
   braucht dafür `permissions/vibrate=true` in **beiden** Ladeständen; ohne
   den Eintrag bleibt `Input.vibrate_handheld()` auf dem Gerät folgenlos,
   und zwar stumm, ohne Fehler und ohne Hinweis.

23. **Der Eintrittsrand darf auf keinem Gerät ins Bild.** Der Entwurf steht auf
   720×1280, `aspect="expand"` zeigt auf höheren Geräten aber mehr Welt — und
   die meisten Telefone sind heute 20:9. Bei 1280 Einheiten beginnt das Bild
   bei y = −640, bei 1600 schon bei −960; `Graben.EINTRITT_Y` liegt bei −760
   und damit **genau dazwischen**. Ein Schuss bei 720×1600 zeigte vierzehn
   Räuber nebeneinander auf einer Reihe, wo bei 720×1280 drei verstreut
   standen: die Linie, auf der sie erscheinen. `Graben.kamera_y()` deckelt das
   und schiebt die Kamera dafür nach **unten** — an `EINTRITT_Y` zu drehen
   hieße, die Anmarschzeit jedes Räubers zu ändern, also das Spiel und nicht
   nur das Bild. `_test_kamera_zeigt_den_eintritt_nie` prüft die Spanne von
   4:3 bis 21:9. **Jede neue Optik gehört bei 720×1600 nachgesehen, nicht nur
   bei 720×1280.**

24. **Das Leitwesen tritt zuletzt ein.** Die Auftrittszeiten werden in
   Gruppenreihenfolge vergeben, und angehängt wurde das Leitwesen als erstes —
   es bekam damit den frühesten Schlitz. Eine Welle, die mit ihrem größten Tier
   anfängt, hat keinen Bogen, sondern ein Nachspiel.
   `_test_leitwesen_tritt_zuletzt_ein` hält es fest.

25. **Der Kolonielauf hat keine Marge mehr.** Er meldet „höchstens 3 Stufen
   (tragbar 3)" — er steht also genau auf seiner eigenen, aus der Sollkurve
   abgeleiteten Schranke. Ein Versuch, die ersten fünf Wellen zu verkürzen
   (`FENSTER_ANFANG`, damit der erste Erfolg in der ersten halben Minute
   fällt), kippte ihn auf 4 und damit auf Rot — bei **identischen
   Kammerstufen** und ganzen neun Nährstoff Unterschied am fünften Tag. Der
   Wellenprüfer blieb dabei grün, und es fiel keine einzige Sitzung.

   Zwei Lehren. Erstens: die Schranke wird **nicht** gelockert, damit eine
   Änderung durchgeht. Sie ist abgeleitet (ein Abschnitt geht als Block auf),
   und wer sie hochsetzt, damit sein Commit grün wird, hat den Prüfer
   abgeschafft und nicht das Problem gelöst. Wer die Wellen wirklich kürzen
   will, muss vorher die Marge schaffen.

   Zweitens — und das stand hier zuerst falsch: schuld war **nicht** die
   Anordnung der Auftritte. Ich hatte notiert, der simulierte Daumen räume
   bei anderer Anordnung einen anderen Bruchteil der Welle. Das Crescendo
   (Zusage 26) hat es widerlegt: es ordnet jede Welle um und der Kolonielauf
   kommt **zahlengleich** heraus, bis auf den letzten Nährstoff. Was den Lauf
   verschob, war das Budget selbst — ein kürzeres Fenster macht `staerke()`
   kleiner, und damit fallen Tierzahl und Rundung des Ertrags anders. Wer die
   Verteilung anfasst, ist frei; wer `staerke()` anfasst, nicht.

26. **Die Welle hat einen Bogen.** `Wellen.anlauf()` bildet den Platz einer
   Gruppe in der Reihe auf ihren Anteil am Eintrittsfenster ab — `pow(lage,
   0.75)`. Vorher war das die Einheitsabbildung, und eine Welle fühlte sich
   am Ende an wie am Anfang: ein Förderband, kein Angriff. Über 240 Wellen
   gemessen liegen die Auftritte jetzt bei **23 / 35 / 42 %** über die drei
   Drittel des Fensters, und die Welle setzt ein bis drei Sekunden später
   ein.

   Zwei Dinge, die dabei zu lernen waren. Erstens: das Budget bleibt
   unberührt — `staerke()` kennt diese Funktion nicht, und der Kolonielauf
   kommt zahlengleich heraus. Was sich ändert, ist wie viel gleichzeitig im
   Kegel steht, und ob das noch spielbar ist, sagt der Wellenprüfer und nicht
   die Rechnung (240 Wellen ohne Verlust). Zweitens: **der Bogen ist eine
   Eigenschaft der Verteilung, nicht jeder einzelnen Welle.** Der erste Test
   verlangte ihn von jeder und fiel bei Welle 22 mit 8 zu 8 um — Gruppen sind
   verschieden groß, ein Schleierschwarm bringt fünf Tiere auf einen Schlag,
   und wo der landet, entscheidet der Wurf. Sechs von 240 Wellen fallen
   daneben, und das ist gewollt: ein Bogen, den jede Welle exakt gleich
   trägt, wäre wieder dasselbe Förderband mit anderer Steigung.

## Der Rundumlauf

**Die App startet jetzt im Titelbildschirm** (`scenes/rundum.tscn`), und das
Menü führt in beide Schleifen: `PLAY` in den Rundumlauf, `TRENCH WATCH` in die
Schlundwache. Auf einem Telefon gibt es keine Kommandozeile — hinter einem
Schalter war der Rundumlauf dort überhaupt nicht erreichbar.

Für die Werkzeuge gibt es den Gegenweg: **`--schlund`** springt direkt in die
alte Szene, so wie `--rundum` vorher andersherum. `tools/ladenbilder.sh` und
alle Schuss-Aufrufe brauchen ihn.

```bash
godot --path . -- --schlund --schuss /pfad/bild.png --welle 22
godot --path . -- --schuss /pfad/bild.png --spiel --welle 24 --zeit 30
```

**Kommentare in `project.godot` fangen mit Strichpunkt an.** Mit `#` gesetzt
zerreißt es die Sektion, und Godot meldet `no main scene defined` — was wie
ein fehlender Eintrag aussieht und keiner ist.

## Der Rundumlauf (Versuch, nicht Ersatz)

```bash
godot --path . -- --rundum
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1600 \
  -- --rundum --schuss /pfad/bild.png --welle 14 --zeit 24
```

Ein bewegliches Boot in offenem Wasser, Räuber aus allen Richtungen, Polypen
als Begleiter. Liegt **neben** dem Spiel: `--rundum` schaltet in
`scenes/rundum.tscn` um, ohne den Schalter ändert sich am bestehenden Weg
nichts.

Der Umbau war deutlich billiger als geschätzt, aus zwei Gründen, die beide
schon im Code standen:

* **`Schlund` ist längst rundum.** `beleuchtung()`, `getroffen()`,
  `zielrichtung()`, `gedreht()` rechnen mit freien Vektoren und wissen nichts
  von oben und unten. Sie werden unverändert weiterverwendet — die Zusage,
  dass gezeichnetes Licht und Schaden dieselbe Rechnung sind, überlebt den
  Umbau.
* **Die Tierkunst kennt kein Oben.** Jede der zwölf Arten wird relativ zu
  `t.richtung` und deren Senkrechten gezeichnet. Sie sehen in jeder
  Blickrichtung richtig aus, ohne dass eine Linie neu gezogen wurde. Die
  Kostenschätzung „zwölf Arten von oben neu zeichnen" war damit falsch — es
  war null.

Neu ist nur: `Rundum.schritt()` (der Weg kann keine geschlossene Formel mehr
sein, weil das Ziel sich bewegt — deterministisch bleibt er trotzdem),
`Rundum.fahrt()` (ein Finger für Blick und Fahrt, Totzone dazwischen),
`Rundum.begleiter_ziel()` und die **Hülle anstelle der Brut**: `Arten.wucht()`
sagt weiter, was ein Durchkommen kostet, und die Brutkammer hebt weiter die
Zahl der Fehler, die man übersteht. Die Meta-Ebene gilt unverändert.

**Der Graben liegt im Dunkeln, bis jemand hinfährt.** `Karte` (rein
gerechnet, `scripts/kern/karte.gd`) ist ein Raster aus `ZELLE` großen
Feldern, ein Byte je Feld; die Fahrt deckt im Umkreis von `AUFDECK_RADIUS`
auf, und der ist **kleiner als die Sicht** — sonst wäre alles, was man sehen
kann, schon bekannt, und das Aufdecken hätte keinen Ort. Dazu liegen
`FUNDE` Fundstellen im Feld, die man nur sieht, wo man schon war. Sie zahlen
**Punkte und keinen Nährstoff**, aus demselben Grund wie die Kette
(Zusage 16).

Der Nebel wird **nicht feldweise als Rechteck** gezeichnet. Das war der erste
Anlauf, und es sah aus wie ein Tabellenblatt: die Grenze zwischen bekannt und
unbekannt lief in rechten Winkeln durchs Bild. Stattdessen bekommt jede
**Ecke** des Rasters ihre Deckung aus den vier Feldern, die sie berührt, und
`RenderingServer.canvas_item_add_triangle_array` zeichnet das ganze Netz in
einem Aufruf mit Farbe an den Ecken. Die Deckung läuft damit über eine ganze
Feldbreite aus, und das Raster verschwindet, obwohl es dasselbe geblieben
ist.

**Nicht jedes Tier will an das Boot.** `wild.gd` zieht Fischschwärme über den
Grund, die vor dem Licht auseinanderstieben und sonst nichts tun: kein
Schaden in beide Richtungen, kein Nährstoff, keine Punkte, in keiner
`Wellen.auftritte()`. Dieselbe Begründung wie bei der Funkenblüte
(Zusage 18) — was nichts kostet und nichts zahlt, verschiebt auch nichts.
Sie hängen als eigener Knoten **hinter** dem Grund, damit sie über dem Nebel
liegen: ein Glimmen weit draußen im Dunkeln ist der beste Grund, dorthin zu
fahren.

Ein Schwarm ist dabei genau das, was er von weitem ist: **viele, die in
dieselbe Richtung sehen.** Der erste Anlauf gab jedem Fisch einen festen
Platz im Weltraster und ließ ihn dorthin blicken, wo sein Platz lag — im
Bild war das kein Schwarm, sondern ein Seeigel.

**Nicht jeder Räuber kommt von außen.** Jeder vierte (`LAUER_ANTEIL`) liegt
schon in der Karte und wartet — still und blass (`Schwarm.deckung`), bis das
Boot auf `WECK_RADIUS` herankommt oder ein Treffer ihn weckt. Das ist der
Grund, warum das Aufdecken der Karte etwas kostet: eine unbekannte Ecke ist
nicht nur dunkel, es kann auch etwas darin liegen. **Kein Leitwesen lauert** —
ein Höhepunkt, den man verpasst, weil man zufällig woanders fährt, ist keiner.

Zwei Fallen dabei, beide schon hineingetreten. Erstens: wenn sonst nichts
mehr steht, erwachen die Übrigen von selbst — sonst hängt die Welle an einem
Lauerer, der vierzehnhundert Einheiten entfernt im Dunkeln liegt, und der
Spieler fährt die Karte ab, um „1 LEFT" zu suchen. Zweitens: diese Prüfung
darf **nicht** nach `alter >= 0` fragen. Zu Wellenbeginn steht noch nichts im
Feld, weil jeder Auftritt seine Zeit hat — damit erwachten alle Lauerer in der
ersten Sekunde, und der Hinterhalt war eine Ankündigung.

**Die Fahrt endet, und sie zahlt.** Bei Hülle null steht `Lage.ENDE`: ein
Bericht mit Nährstoff, Punkten, Welle, Erlegten, Fundstellen und der besten
Kette, und genau zwei Wegen — noch einmal, oder zurück. **Keine Werbung und
kein Angebot an dieser Stelle**; der Plan sagt es in einem Satz: niemals nach
einer Niederlage.

Der Nährstoff fällt je erlegtem Tier, **geteilt durch `DICHTE`**. Im Schlund
summiert sich `Wellen.wert_in()` über eine Welle genau zu `Wellen.ertrag()`;
hier laufen drei Wellen ineinander, also liegen dreimal so viele Körper im
Feld, und wer jeden voll bezahlte, zahlte für eine Welle den dreifachen
Ertrag. Einkommen und Kosten sind aneinander gekoppelt (Zusage 10) — eine
Schleife, die dasselbe Spiel dreimal so schnell bezahlt, ist eine zweite
Wirtschaft. Der Bruchteil wird mitgenommen und nicht weggerundet.

Und: **bezahlt wird nur in `Lage.SPIEL`.** Hinter dem Titelbild und hinter dem
Bericht läuft die Szene weiter, und der Vorführdaumen erlegt dabei Tiere —
ohne diese Abfrage verdient ein Telefon, das auf dem Titelbild liegen bleibt,
echten Nährstoff. Aufgefallen ist es an einer 9261 im Schuss des Berichts, wo
9260 hineingeschrieben war.

**Der Ausbau ist derselbe Bildschirm wie im Schlund**, nicht ein zweiter.
`kolonie_schirm.gd` ist eine Ebene und keine Szene, hängt an `Fortschritt`
und `Kammern` und kennt seinen Wirt nicht — er passt in `rundum.tscn`, ohne
dass eine Zeile in ihm geändert werden musste (nur `zurueck_beschriftung`
kam dazu: „BACK TO THE MAW" in einem Boot mitten im Graben ist schlicht
falsch). Ein eigener Ausbaubildschirm für diese Schleife wäre eine zweite
Wahrheit über dieselben Kammern. Erreichbar über `COLONY` im Titelbild **und**
im Bericht — nach der Fahrt liegt der Nährstoff frisch in der Kolonie, und
das ist der Moment, in dem man ihn ausgeben will.

**Und die Werte des Bootes kommen aus der Kolonie**, nicht aus der Sollkurve.
Das stand zuerst falsch: der Kegel rechnete mit
`Ausbau.leistung_faktor(welle)`, also mit dem Stand, den ein Spieler auf
dieser Welle *haben sollte*. Damit war jede Kammer, die man vom verdienten
Nährstoff hob, im Rundumlauf folgenlos — man verdiente, baute, und nichts
wurde stärker. Eine geschlossene Schleife, in der der zweite Halbkreis nichts
bewirkt, ist keine. Es sind dieselben vier Funktionen wie in
`wache.gd::_stelle_ausbau_ein()`, aus demselben `KolonieStand`; die Hülle
hängt an der Brutkammer, weil sie die Brut ist.

Zwei Dinge, die dabei zu beachten waren. Die Ebene braucht ein Kind namens
`Flaeche` in der Szene, sonst bricht sie in `_ready()` ab und schreibt
zweihundert Zeilen `queue_redraw() on a null value`. Und `rund_menue.gd`
setzt seine Sichtbarkeit je Bild selbst — ohne `lauf.kolonie_offen()` stünde
das Titelbild eine Zehntelsekunde nach dem Öffnen wieder darüber.

**Die Tagesziele zählen auch hier.** Sie wurden ausschließlich aus `wache.gd`
gemeldet — wer nur fährt, konnte keines davon erfüllen, obwohl `DAILY` im
Titelbild steht und einen Lohn verspricht. Ein Ziel, das man in der Schleife,
die man spielt, nicht erreichen kann, ist kein Ziel, sondern ein Vorwurf.
Nachgemessen an sechs Wellen: Wellen 3/3, Räuber 60/60, Kette 12/12.

**Die Fahrt lässt sich anhalten.** Ohne Pause steckte man in ihr fest: auf
einem Telefon gibt es kein Fenster zum Schließen, `quit_on_go_back` steht auf
`false`, und der einzige Ausgang war die gebrochene Hülle. Jetzt gibt es
`Lage.PAUSE` — ein Knopf oben in der Mitte, die Android-Zurück-Taste und der
Wechsel in den Hintergrund führen dorthin, dieselbe Regelung wie in
`wache.gd::_notification()`. Drei Wege heraus: weiter, bauen, abbrechen. Beim
Zurückkommen wird der Finger losgelassen — wer aus der Pause kommt, hat den
Daumen nicht mehr da, wo er ihn hatte, und ein Boot, das sofort weiterfährt,
fährt in die falsche Richtung.

**Drei Sätze Einstieg, während gespielt wird.** Der Rundumlauf erklärte
bisher nichts: man sah ein Boot und musste raten, dass man ziehen soll.
`rundlauf.gd::LEHRE` ist kein Lehrpfad wie im Schlund — es gibt nur eine
Handlung und einen Knopf. Jeder Schritt wartet auf **die Handlung**, nicht
auf eine Uhr (fahren, zwei erlegen, das Stoßlicht auslösen), hält nichts an
und verlangt nichts; wer ihn nicht liest, spielt trotzdem. Danach steht
`KolonieStand.einstieg_fahrt` auf 1, und er kommt nie wieder — eine **eigene**
Zahl neben `einstieg`, weil wer die Schlundwache kennt noch nicht weiß, dass
man hier fährt.

**Eine Fahrt ist `Graben.WELLEN_JE_SITZUNG` Wellen lang** — genau wie eine
Sitzung im Schlund (Zusage 9), und danach steht der Bericht: „DIVE COMPLETE"
statt „HULL BREACHED", dasselbe Blatt in einer anderen Farbe. Das ist nicht
nur Rhythmus. Die ganze Wirtschaft rechnet mit `Graben.WELLEN_JE_TAG` Wellen
am Tag; die Fahrprobe zeigte einen Piloten, der **einundzwanzig** Wellen in
einem Zug spielt, also anderthalb Tage Einkommen in einer Sitzung — und dann
gleich wieder anfängt.

Und die nächste Welle kommt aus dem **Koloniestand** (Zusage 13), nicht aus
einer eigenen Zählung. Vorher fing jede Fahrt bei eins an: dieselben fünf
Wellen für immer, und der Ertrag von Welle eins dazu. `--welle` sticht das
aus, weil ein Werkzeug zeigen können soll, was es zeigen will.

### Die Fahrprobe

```bash
godot --headless --path . -- --fahrprobe 45      # ~4 min, Exitcode 1 bei Fall
```

**Ein simulierter Daumen ersetzt kein Fahrkönnen** — das bleibt wahr. Was er
ersetzt, ist das Raten. Der Pilot kann genau eine Sache: das Licht auf dem
nächsten Tier halten und näher heranfahren, wenn es weit weg ist. Kein
Ausweichen, kein Timing, kein Bogen um die Felsen — alles, was ein Spieler
zusätzlich kann, geht als Reserve in das Ergebnis ein. Gemessen wird deshalb
eine **untere Schranke**, und sie wird auch so gemeldet.

Die Kolonie steht dabei je Welle auf `Ausbau.stufe_soll()` — dieselbe
Vorgabe, gegen die der Wellenprüfer misst. Ohne das misst man nicht das
Spiel, sondern den Spielstand, der zufällig auf der Platte liegt.

**Was noch offen ist:** es gibt keine Wellenpausen — wer im Rundumlauf baut,
tut es zwischen den Fahrten und nicht in ihnen. Der Wellenprüfer
kann diese Schleife **nicht** messen: ein simulierter Daumen ersetzt kein
Fahrkönnen. Die Wellenstärke ist deshalb hier von Hand gesetzt
(`rundlauf.gd::DICHTE`) und von Hand nachgesehen; an ihr hängt keine Zusage.

## Fuer den Laden

`STORE.md` ist die Abgabemappe: was der Bauauftrag liefert, was nur von Hand
geht, die Texte fuer den Eintrag und die Antworten fuer Datensicherheit und
Inhaltseinstufung.

```bash
godot --headless --path . --script tools/symbol.gd   # Symbolsatz neu rechnen
tools/ladenbilder.sh build/laden                     # Screenshots, 1080x1920
tools/ladengrafik.sh build/laden                     # Feature-Bild, 1024x500
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
