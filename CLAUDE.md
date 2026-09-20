# Hinweise für Claude Code

## Was hier gebaut wird

**TEN THOUSAND** — einer gegen die Horde.

Von oben, ein Held, hundert Feinde. Der Finger führt **nur den Mann**; die
Waffen schlagen von selbst. Was man entscheidet, ist die Aufstellung — wohin
man läuft, wen man vor sich lässt, wann man durch eine Lücke geht — und bei
jedem Aufstieg eines von drei Angeboten. Zehn Minuten, dann steht der Warlord
da.

Drei Ebenen dahinter, und jede beantwortet eine andere Frage:

* **Die Burg** (`Halle`) ist die stetige Kurve: Mauer, Schmiede, Stall, Münze.
* **Die Ausrüstung** (`Ausruestung`) ist die Fundfreude: vier Plätze, acht
  Stücke, ein Fund nach jedem Lauf — auch nach einem kurzen.
* **Die Helden** (`Helden`) sind die Abwechslung: vier Klassen, jede mit
  **genau einer** Eigenart, freigeschaltet an Taten statt an Sold.

**Es gab vor September 2026 zwei andere Spiele in diesem Repository** —
NEKTON (Tiefsee, Lichtkegel) und HUNDRED CUTS (ein Timing-Duell). Beide sind
gelöscht. Wer in älteren Commits über `rundlauf.gd`, `schwarm.gd`, `duell.gd`
oder `fechter.gd` stolpert: die gibt es nicht mehr. **Eine Schleife, eine
Wahrheit.**

Alles Sichtbare und Hörbare entsteht in diesem Repository: Grafik prozedural
(`Tusche`), Ton synthetisiert (`Klang`). `ASSETS.md` ist der Nachweis — es
gibt **keine einzige Bilddatei** außer den App-Symbolen.

### Der Artstyle: farbig, umrandet, mit Schatten

Ruhiger entsaettigter Grund, **farbige Figuren mit dunkler Kante**, ein
Schlagschatten unter jeder, **Zinnober nur für Schaden am Spieler** und
**Gold nur für Sold**. Alle Farben stehen an **einer** Stelle
(`scripts/daten/palette.gd`), und ein Wächter prueft sie.

**Hier stand bis September 2026 ein Holzschnitt auf Pergament** — alles
schwarze Tusche, und die Regel dazu lautete: *eine Sorte muss an ihrer
Silhouette erkennbar sein, nicht an ihrer Farbe.* Sie war in sich schluessig
und im Gedraenge unbrauchbar, und zwar aus einem Grund, der im Code stand:
ab `Streiter.DICHT_AB` Figuren schaltet **jede** davon auf die Sparfassung,
und die wirft die Silhouette weg. Die Regel verlangte genau das, was das Bild
in seinem dichtesten Moment nicht mehr liefern konnte. Uebrig blieben achtzig
gleiche schwarze Umrisse, und einer davon war der Spieler selbst.

Fünf Regeln, die für **jede** neue Zeichnung hier gelten:

* **Kein Strich hat zwei gleiche Enden.** Ein Band gleicher Breite ist ein
  Klebestreifen; ein Pinsel setzt auf, trägt und hebt ab.
* **Erst die Masse, dann die Glieder.** Wer mit den Gliedern anfängt, baut ein
  Skelett und hängt danach vergeblich Kleider daran.
* **Ein Glied ist ein Strang, keine zwei Züge** — sonst hat es am Gelenk eine
  Kerbe, und eine Kerbe ist eine Kante, wo ein Übergang hingehört.
* **Jede Sorte hat ihre eigene Farbe, und die des Helden hat niemand sonst.**
  Das ist die Frage, die ein Spieler bei hundertfünfzig Figuren alle zwei
  Sekunden stellt: *wo bin ich?* Geprueft wird als Abstand im Farbraum und
  nicht als Ungleichheit von drei Fließkommazahlen.
* **Jede Figur hat eine Kante und einen Schatten.** Die Kante trennt sie von
  der Figur daneben, der Schatten vom Boden darunter — ohne den schwebt in
  einem Bild ohne Perspektive alles.

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
godot --headless --import                               # class_name-Registry
godot --headless --path . --script tests/run_tests.gd   # ~5 min, Exitcode 1 bei Fehler
godot --headless --path . --script tools/probe.gd       # volle Läufe, ~8 min
godot --headless --path . --script tools/probe.gd -- --held 1 --stufen 8
godot --headless --path . --quit-after 180              # startet das Spiel wirklich
godot --headless --path . --script tools/lizenzcheck.gd # Herkunft belegt
```

**Der Testlauf allein beweist nicht, dass das Spiel läuft.** Er lädt
`zug_lauf.gd`, `zug_hud.gd` und `feld.gd` nie — ein `--script`-Lauf kennt
keine Autoloads und keine Szene. Ein Parse-Fehler dort bleibt im Testlauf
grün. Das ist in diesem Repository schon dreimal passiert; der Startlauf
findet es in Sekunden.

**`--import` nach jeder neuen Datei mit `class_name`.** Sonst kennt die
Registry die Klasse nicht, und das Skript lädt gar nicht erst.

**`quit()` kehrt zurück.** Also `return` hinter jedes `quit()`, das nicht das
letzte Statement der Funktion ist.

**Achtung beim Fehler-Check in der Shell:** `godot ... | grep ... | head` gibt
immer Erfolg zurück, weil `head` gelingt. Ausgabe in eine Variable fangen.

**Und eine Ersetzung ohne Prüfung ist ein stiller Fehlschlag.** Beim Umbau
von `Gefecht.baue()` lief ein `str.replace()` ins Leere, weil der Suchtext
einen Umlaut anders hatte — die Datei blieb unverändert, und der Fehler kam
erst zwei Schritte später als „Too many arguments" heraus. **Jedes
skriptgesteuerte Ersetzen prüft, dass es genau einmal getroffen hat.**

## Optik prüfen (Screenshots)

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1600 \
  -- --schuss /pfad/bild.png --held 0 --stufen 6 --zeit 200
```

| Schalter | Wirkung |
|---|---|
| `--schuss <datei>` | speichert und beendet |
| `--held <n>` | beginnt sofort einen Lauf mit diesem Helden |
| `--zeit <s>` | rechnet s Sekunden Gefecht mit festem Takt vor |
| `--stufen <n>` | setzt alle vier Bauten auf Stufe n **und den Beutel** |
| `--lage <n>` | zeigt Titel (0), Burg (3), Beutel (4) statt des Laufs |

**`--zeit` führt `Daumen`**, denselben simulierten Daumen wie `tools/probe.gd`.
Ohne ihn zeigte jeder Schuss denselben Stillstandstod nach vierzehn Sekunden.
Zwei Daumen wären zwei Spiele.

**`--stufen` setzt auch den Beutel.** Ein Schalter, der die halbe Wahrheit
setzt, zeigt ein Spiel, das es nicht gibt.

## Zusicherungen, die nicht aufgeweicht werden dürfen

1. **Der Schaden am Spieler hängt an der Zeit, nicht an der Zahl der
   Anliegenden** (`Gefecht.WUNDE_SPERRE`). Der erste Entwurf ließ jeden
   anliegenden Feind für sich zuschlagen: zehn Strolche machten siebzig
   Schaden je Sekunde gegen hundert Leben. Gemessen fiel der Schwertkämpfer
   nach 154 s — mit 384 Erschlagenen auf dem Konto. Ein Horden-Spiel muss
   aber wollen, dass man in die Horde gerät. Der **härteste** Anliegende
   bestimmt, was es kostet; damit bleibt ein Ritter gefährlicher als ein
   Strolch, und zwanzig Strolche sind nicht zwanzigmal ein Strolch.

2. **Nicht wie viele anliegen kostet, sondern aus wie vielen Richtungen**
   (`Gefecht.DRUCK_RADIUS`, `SEKTOREN`, `UMZINGELT_FREI`/`_VOLL`). Der Deckel aus
   1 behob den Sofort-Tod und nahm dabei jeden Grund, sich zu bewegen:
   gemessen hielt Stehenbleiben 465 s und Laufen 473 — die einzige Eingabe
   des Spiels bewirkte nichts. Der Grundwert wird deshalb mit den besetzten
   Fächern multipliziert; zwanzig Strolche auf einer Seite sind so teuer wie
   einer, acht rundum das Dreifache. **Schaden fällt weiter nur bei
   Berührung** — der Ring sagt, wie schlimm es ist, die Berührung sagt, dass
   es passiert. Und die Zahl steht im Bild (`Stand.umzingelt`): eine Strafe,
   die man nicht kommen sieht, ist keine Regel, sondern ein Unfall.
   **Der Faktor spannt um die Eins** — aus einer Richtung kostet es die
   Hälfte, rundum das Vierfache. Als reiner Aufschlag obendrauf war die Regel
   nur eine Verteuerung und kostete alle vier Helden ein Fünftel ihrer Zeit;
   wer eine Flanke freihält, soll nicht verschont, sondern belohnt werden.

3. **Waffen zielen auf den Nächsten, nicht in die Laufrichtung.** In einem
   Genre, dessen ganze Bewegung Fliehen ist, zeigt der Laufweg *von* der
   Horde weg. Gemessen: 130 Sekunden, 180 Hiebe, **sieben** Erschlagene.
   Ausnahme ist der Speer — siehe 3.

4. **Der Speer stößt nach hinten.** Er war als der eine Zug entworfen, der
   nach dem Laufweg fragt, und stieß nach vorn: zwei Erschlagene in zwei
   Minuten. Die Frage war richtig, die Antwort stand andersherum — er spießt
   auf, was sich an die Fersen heftet. Damit ist er die einzige Waffe, die
   belohnt, dass man gerade flieht.

5. **Eine Sorte, die man am Verhalten nicht erkennt, ist keine.** Vier
   Verhalten (läuft / hält Abstand / stürmt / treibt), und zwei Sorten mit
   demselben Sinn müssen sich deutlich in Tempo oder Zähigkeit unterscheiden.
   Ein Feind mit mehr Leben wäre derselbe Feind mit mehr Wartezeit. **Und sie
   muss ihre eigene Farbe haben** (`Palette.SORTE`), denn die Sparfassung
   wirft die Silhouette weg, die Farbe aber nicht.

6. **Sorten treten gestaffelt ein** (`Andrang.AB`), mindestens
   `NEULING_FENSTER` auseinander, und die jüngste kommt in ihrer ersten
   halben Minute doppelt so oft. Wer in der ersten Minute alles trifft, lernt
   keine Sorte — er lernt nur, dass es voll ist.

7. **Jeder Held hat genau eine Eigenart.** Ein Held mit fünf kleinen
   Vorteilen fühlt sich an wie der Grundheld mit Rauschen. Freigeschaltet
   wird an Taten, nicht an Sold — wer Abwechslung kaufen kann, kauft sie am
   ersten Tag. **Dasselbe gilt für die Skins** (`Skins`): drei je Held, an
   Taten freigeschaltet, und sie ändern **nur Farben**. Sobald eine Skin
   einen Kampfwert trägt, wählt niemand mehr die, die ihm gefällt, sondern
   die, die gewinnt — in `Skins` steht deshalb kein Feld, in das ein Vorteil
   hineinpasste. Und **keine Skin ist eine Tarnkappe**: jede der zwölf hält
   denselben Farbabstand zu jedem Feind wie die Grundfarbe des Helden
   (gemessen, engste 0,45 gegen eine Schranke von 0,18).

8. **Jedes Ausrüstungsstück wirkt auf genau einen Wert**, aus demselben Grund.
   Und `Ausruestung.summe()` gibt ohne alles genau eins zurück, damit
   `Gefecht.baue()` bedingungslos multiplizieren kann und niemand ein `if`
   vergisst.

9. **Der Aufstieg bietet nie dreimal dasselbe** und bei vollen Plätzen nur
   noch Stufen. Drei Buffs nebeneinander sind keine Wahl; ein Angebot, das
   man nicht annehmen kann, ist ein verschenkter Aufstieg.

10. **Man beginnt mit genau einer Waffe**, der seines Helden. Ohne eine
   schlägt man die erste halbe Minute gar nichts; mit zweien hat der erste
   Aufstieg nichts mehr zu sagen.

11. **Einkommen und Kosten wachsen mit derselben Rate.** `Halle.ertrag()`
    **ist** `rundenkosten()` geteilt durch `LAEUFE_JE_RUNDE`. Geprüft wird die
    Ableitung selbst und nicht ein Verhältnis: ein Verhältnis zu prüfen hieße,
    die Rundung bei kleinen Zahlen für eine Abweichung zu halten.

12. **Kein Ausbau verschlechtert etwas**, über alle 25 Stufen. Eine Kurve mit
    einem Exponenten über eins kippt am Ende, und niemand sieht es, weil
    niemand die fünfundzwanzigste Stufe spielt.

13. **Eine Dauerwaffe rechnet Schaden je Zeit, nicht je Bild.** Hängt der
    Flegel am Takt, ist er auf einem 120-Hz-Telefon doppelt so stark — und
    eine Einstellung im Anzeigemenü verstellte den Schwierigkeitsgrad.

14. **Nach y sortiert zeichnen.** In einem Bild ohne Perspektive ist die
    Zeichenreihenfolge die einzige Tiefe, die es gibt; ohne sie steht ein
    Feind vor dem Helden, der hinter ihm ist.

15. **Der Held wird freigestellt.** Eine Fläche in Pergamentton unter ihm,
    etwas größer als er — im leeren Feld unsichtbar, im Gedränge steht er in
    einer Lücke. Es ist die einzige Stelle im Spiel, an der Pergament über
    Tusche liegt. Ein heller Saum *unter* der Figur (der erste Anlauf) macht
    sie blass statt auffindbar.

16. **Der Stick sitzt, wo der Daumen aufsetzt.** Kein fester Knüppel an einer
    Ecke — auf einem Telefon hält niemand den Daumen dort, wo ein Entwerfer
    ihn hingelegt hat.

17. **Im Lauf gehört der Finger dem Helden** — außer beim Aufstieg. Ein Knopf,
    der einen Zug verschluckt, kostet Leben.

18. **Kein Angebot nach einer Niederlage.** Der Bericht hat zwei Wege.

19. **`get_display_safe_area()` nur auf dem Telefon fragen** und jeden Rand auf
    12 % der Bildkante deckeln: auf dem Schreibtisch liefert sie den ganzen
    Bildschirm und nicht das Fenster.

20. **Der Ton wird gemessen, nicht gehört.** Anfang und Ende jedes Puffers
    stehen konstruktionsbedingt auf null (`_huelle`); ein Puffer, der bei
    halber Auslenkung einsetzt, ist ein Knacks und kein Schlag. Und er wird
    **gedrosselt**: in Minute neun fallen dreißig Feinde je Sekunde.

## Was beim Bau gelernt wurde

**Die Sparfassung ist nicht der Randfall, sondern der Normalfall.** Bei
`DICHT_AB = 70` steht ein Lauf ab Minute drei fast durchgehend in ihr — und
sie zeichnete den Wolf als **Balken mit zwei Nadeln**. Wer eine Figur
verbessert, verbessert zuerst ihre Sparfassung: die Vollfassung sieht man in
der ersten Minute, die andere den Rest des Spiels.

**Ein Vierbeiner braucht drei Dinge gleichzeitig, und zwei reichen nicht.**
Der Wolf war dreimal ein Möbelstück. Erst lagen Rücken und Kopf auf einer
Höhe — ein Tisch. Dann stimmte die Neigung, aber mit sieben Bildpunkten
Gefälle auf fünfzig Länge sah sie niemand — wieder ein Tisch. Dann stimmte
die Neigung sichtbar, aber der Rumpf war sechzig Punkte lang und zehn dick
mit vier Nadeln darunter — ein **Kleiderständer**. Es braucht **Neigung**
(Kruppe hoch, Schulter tiefer, Kopf darunter), **Masse** (gut anderthalbmal
so lang wie tief, mit eingezogener Weiche) und **geknickte Läufe** zugleich.

**Ein Umriss braucht ein deckendes Band *und* einen scharfen Sprung.** Erster
Anlauf: Kantenreihen auf 0,88, Körper ab 0,62 — dazwischen ein Verlauf über
ein Viertel der Breite, also kein Umriss. Zweiter Anlauf, in die falsche
Richtung korrigiert: 0,78 und 0,74 — der Sprung war scharf, das *deckende*
Band aber vier Hundertstel breit, bei einem Glied von zwanzig Punkten ein
halbes Pixel. Auf dem Schuss war zweimal nichts zu sehen. Beides zugleich
gehört hin.

**Farbe kostet in diesem Sammler nichts.** `Tusche.band()` schrieb immer
schon eine Farbe **je Eckpunkt**; der ganze Stilwechsel von Tusche auf Farbe
hat **keinen einzigen** Zeichenaufruf gekostet. Teuer war allein die Kante —
und auch die ging ohne zweiten Durchgang, weil die äußeren Reihen einfach
eine andere Farbe bekommen (neun Reihen statt fünf, Faktor 1,8 auf die
Eckpunkte, statt Faktor 2,0 für ein zweites Zeichnen der ganzen Figur).

**Ein Messstand, der bei gleicher Saat andere Zahlen liefert, misst gar
nichts.** `Gunst.ziehe()` mischte seinen Topf mit `Array.shuffle()`, und der
greift auf Godots **globalen** Generator zu statt auf den übergebenen `rng`.
Damit war kein Lauf wiederholbar: zwei Messungen mit denselben Saaten meldeten
für dasselbe Stehenbleiben einmal 232 und einmal 300 Sekunden, und mehrere
Balance-Befunde dieser Session waren Rauschen. In einem Repository, dessen
ganze Balance auf gesäten Vergleichen steht, ist das kein Detail. **Jede
Ziehung im Kern nimmt den übergebenen `rng`** — `shuffle()`, `pick_random()`
und `randi()` ohne Empfänger gehören nicht nach `scripts/kern/` oder
`scripts/daten/`.

**Eine Strafe für eine Lage, die das Spiel nie herstellt, ist ein toter
Buchstabe.** Der Druckring stand zuerst bei 110 Punkten, knapp außerhalb der
Berührung. Gezählt standen darin im Mittel **0,8 Feinde**, und alle acht
Fächer waren in **0,0 %** der Bilder besetzt — die Waffen räumen den Ring
schneller, als die Horde ihn füllt. Die Mechanik war richtig gebaut und feuerte
auf nichts. Erst die Messung über 110/180/260/340/420 fand die Weite, bei der
Stehen und Laufen am weitesten auseinanderliegen. **Bevor man an einer Zahl
dreht, misst man, ob die Regel überhaupt greift.**

**Eine Messung, die an eine Decke stößt, ist keine.** Der gestellte
Umzingelungstest ließ den Helden mit hundert Leben antreten: rundum war er nach
der halben Zeit tot, danach fiel kein Schaden mehr, und acht Feinde rundum
meldeten denselben Wert wie acht auf einer Flanke. Nicht die Mechanik war
stumpf, sondern das Messgerät voll.

**Eine Waffenverbesserung nuetzt dem Stehenden mehr als dem Laufenden.** Der
Speer ist die schwaechste Waffe — er zielt als einziger blind (`-s.lauf`
statt auf den Naechsten), und sein Kegel ist mit `BREITE 0.58` nur
dreiunddreissig Grad breit. Vier Fassungen wurden ueber je acht Saaten
gemessen, und **jede, die den Speertraeger auf die Quote hebt, schiebt
`_test_stehenbleiben_verliert` ueber seine Schranke** (0,585 → 0,754 → 0,829).
Der Grund steht in der letzten Messung: dort stieg auch die Zeit des
**Stehenden**, von 323 auf 382 Sekunden. Er fuehrt dieselbe Waffe und ist
dabei *rundum* von Zielen umgeben, waehrend der Fliehende nur nach hinten
trifft. Das ist keine Eigenheit des Speers — dieser Waechter steht **jeder**
Waffenverbesserung im Weg, und wer ihn anfasst, nimmt das zuerst
auseinander. Die Einzelheiten und zwei bereits **widerlegte** Erklaerungen
stehen bei `Waffen.BREITE`.

**Eine Einzelmessung aus einer streuenden Verteilung ist ein Zug und kein
Befund** — und dieses Genre streut enorm. Derselbe Stand meldete für den
Flegel 298 Erschlagene bei einer Saat und 169 über drei. Stehenbleiben fällt
bei zwei Saaten nach gut drei Minuten und überlebt bei der dritten die vollen
zehn, weil es sich in eine Lawine hineingespielt hat. **Jeder Balance-Test
hier mittelt über mehrere Saaten**, und wo eine absolute Schwelle zu wackelig
wäre, prüft er *vergleichend* (Stehen gegen Laufen) statt absolut.

**Der Messstand gehört in den Kern, nicht ins Werkzeug.** `Daumen` steht in
`scripts/kern/`, weil ihn sowohl `tools/probe.gd` als auch der Schuss
benutzen. Zwei Daumen wären zwei Spiele, und dann misst der Messstand nicht
das, was das Bild zeigt.

**Eine Sparfassung darf weglassen, was Zierde ist — nicht das, woran man eine
Figur erkennt.** Der erste Anlauf zeichnete bei vielen Feinden *einen* Strang
plus Kopfklecks: im Bild fünfzig schwarze **Pillen**. Zwei Beine, eine
Schulterlinie und ein Kopf sind das Minimum; das sind vier Züge statt
siebzehn, und das ist der Handel.

**Ein Balken hat überall dieselbe Höhe, eine Tafel auch.** Beide waren als
`zug()` gebaut, und der schwillt zur Mitte an: über dem Schirm stand eine
**Linse** mit spitzen Enden. Man liest einen Balken an seiner Länge, und eine
Länge mit spitzen Enden lässt sich nicht ablesen.

**Ein Vierbeiner ist geneigt.** Rücken und Kopf auf einer Höhe gaben im Bild
einen Tisch mit vier Beinen. Kruppe hoch, Schulter tiefer, Kopf darunter.

**Der Bahnradius einer kreisenden Waffe muss dort liegen, wo das Gedränge
steht.** Der Flegel kreiste bei 96 Punkten, die Feinde drängen sich bei rund
vierzig — er traf fast nie (37 gegen 268 bei der Axt). Das ist zugleich seine
Aussage: *lass sie nah heran.*

**Und die Zeichenaufrufe, in diesem Renderer gemessen** (eine Eigenschaft der
Engine, nicht eines Spiels):

| Aufruf | Zeichenaufrufe |
|---|---|
| `draw_line`, auch geglättet | 50 Stück = **1** |
| `draw_colored_polygon` | 1 je Stück, **auch mit Deckung null** |
| `draw_circle` hart / geglättet | 1 / **2** je Stück |
| `draw_arc` | **3** je Stück |
| `draw_polyline` geglättet | **3 je Zug**, unabhängig von der Länge |

Deshalb sammelt `Tusche` alles in **ein** Dreiecksnetz: eine Figur, ein
Aufruf. Bei hundertfünfzig Feinden ist das keine vorgezogene Optimierung,
sondern die Form, in der dieses Bild überhaupt bezahlbar ist.

**`Tusche` sammelt, `draw_string` nicht.** Der Pinsel häuft alles in einem
Netz an und spült es am Ende in **einem** Aufruf; `draw_string` geht sofort
aufs Blatt. Damit lag jede Beschriftung **unter** ihrer eigenen Tafel — und
eine Tafel ist ein Pergamentwisch mit zweiundsechzig Prozent Deckung. Im Bild
stand auf jedem Knopf und jeder Karte graue Schrift, wo schwarze stehen sollte,
und die Baukosten in der Burg sahen aus, als könne man sie sich nicht leisten.
**Wer neben Tusche zeichnet, sammelt mit** (`zug_hud.gd._worte`).

**Eine Beschriftung, die breiter ist als das, was sie beschriftet, ist keine.**
Der Satz des Bogenschützen lief über den Rand seiner Karte und rechts aus dem
Bild. Gekürzt wird nicht — ein abgeschnittener Satz sagt weniger als ein
kleinerer; die Größe fällt, bis er hineingeht (`_zeile_eng`).

**Ein Schirm, der oben klebt, ist für ein anderes Gerät entworfen.** Die Menüs
waren von oben gesetzt und standen auf einem 720x1600-Telefon im oberen
Drittel, darunter ein leeres Viertel Pergament. Der Block sitzt mittig in dem,
was da ist (`_luft`); wird es eng, klebt er wieder oben.

**Wenn im Bild etwas steht, das keine Zeichnung erklärt**, ist der nächste
Schritt nicht Nachdenken, sondern **einen Knoten stillstellen und noch einmal
schießen**.

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **APK-Builds nur in CI**
- Der Container ist flüchtig; Godot muss je Session neu installiert werden
- MSAA-2D gibt es im Kompatibilitäts-Renderer nicht. Weiche Kanten kommen aus
  dem Zeichnen selbst: jeder `Tusche`-Strich hat zwei durchsichtige
  Außenreihen — die Form eines Haarpinsels, nicht ein Glättungstrick

## Konventionen

- **Bezeichner und Kommentare auf Deutsch, alles Sichtbare auf Englisch.**
- Einrückung: 4 Leerzeichen
- `scripts/kern/` und `scripts/daten/` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so sind sie headless testbar
- Jede Testfunktion endet mit `return true` und steht in `TESTS` — ein
  Wächter prüft das
- GDScript leitet Typen aus untypisierten Werten **nicht** ab, und die Warnung
  ist hier ein Fehler: `var x: Gefecht.Stand = ...` schreiben, wo der
  Rückgabetyp nicht feststeht
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
