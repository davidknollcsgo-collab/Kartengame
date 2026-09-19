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
(`Tusche`), Ton synthetisiert (`Klang`). `ASSETS.md` ist der Nachweis.

### Der Artstyle: Holzschnitt auf Pergament

Warmes Pergament, schwarze Tusche, Schraffur für Schatten, **Zinnober nur für
Gefahr** und **Gold nur für Sold**. Zwei Farben, zwei Bedeutungen.

Vier Regeln, die für **jede** neue Zeichnung hier gelten:

* **Kein Strich hat zwei gleiche Enden.** Ein Band gleicher Breite ist ein
  Klebestreifen; ein Pinsel setzt auf, trägt und hebt ab.
* **Erst die Masse, dann die Glieder.** Wer mit den Gliedern anfängt, baut ein
  Skelett und hängt danach vergeblich Kleider daran.
* **Ein Glied ist ein Strang, keine zwei Züge** — sonst hat es am Gelenk eine
  Kerbe, und eine Kerbe ist eine Kante, wo ein Übergang hingehört.
* **Eine Sorte muss an ihrer Silhouette erkennbar sein, nicht an ihrer Farbe.**
  Es stehen hundert schwarze Figuren auf hellem Grund; wer eine Sorte nur am
  Farbton unterscheidet, hat sie nicht unterschieden.

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

2. **Waffen zielen auf den Nächsten, nicht in die Laufrichtung.** In einem
   Genre, dessen ganze Bewegung Fliehen ist, zeigt der Laufweg *von* der
   Horde weg. Gemessen: 130 Sekunden, 180 Hiebe, **sieben** Erschlagene.
   Ausnahme ist der Speer — siehe 3.

3. **Der Speer stößt nach hinten.** Er war als der eine Zug entworfen, der
   nach dem Laufweg fragt, und stieß nach vorn: zwei Erschlagene in zwei
   Minuten. Die Frage war richtig, die Antwort stand andersherum — er spießt
   auf, was sich an die Fersen heftet. Damit ist er die einzige Waffe, die
   belohnt, dass man gerade flieht.

4. **Eine Sorte, die man am Verhalten nicht erkennt, ist keine.** Vier
   Verhalten (läuft / hält Abstand / stürmt / treibt), und zwei Sorten mit
   demselben Sinn müssen sich deutlich in Tempo oder Zähigkeit unterscheiden.
   Ein Feind mit mehr Leben wäre derselbe Feind mit mehr Wartezeit.

5. **Sorten treten gestaffelt ein** (`Andrang.AB`), mindestens
   `NEULING_FENSTER` auseinander, und die jüngste kommt in ihrer ersten
   halben Minute doppelt so oft. Wer in der ersten Minute alles trifft, lernt
   keine Sorte — er lernt nur, dass es voll ist.

6. **Jeder Held hat genau eine Eigenart.** Ein Held mit fünf kleinen
   Vorteilen fühlt sich an wie der Grundheld mit Rauschen. Freigeschaltet
   wird an Taten, nicht an Sold — wer Abwechslung kaufen kann, kauft sie am
   ersten Tag.

7. **Jedes Ausrüstungsstück wirkt auf genau einen Wert**, aus demselben Grund.
   Und `Ausruestung.summe()` gibt ohne alles genau eins zurück, damit
   `Gefecht.baue()` bedingungslos multiplizieren kann und niemand ein `if`
   vergisst.

8. **Der Aufstieg bietet nie dreimal dasselbe** und bei vollen Plätzen nur
   noch Stufen. Drei Buffs nebeneinander sind keine Wahl; ein Angebot, das
   man nicht annehmen kann, ist ein verschenkter Aufstieg.

9. **Man beginnt mit genau einer Waffe**, der seines Helden. Ohne eine
   schlägt man die erste halbe Minute gar nichts; mit zweien hat der erste
   Aufstieg nichts mehr zu sagen.

10. **Einkommen und Kosten wachsen mit derselben Rate.** `Halle.ertrag()`
    **ist** `rundenkosten()` geteilt durch `LAEUFE_JE_RUNDE`. Geprüft wird die
    Ableitung selbst und nicht ein Verhältnis: ein Verhältnis zu prüfen hieße,
    die Rundung bei kleinen Zahlen für eine Abweichung zu halten.

11. **Kein Ausbau verschlechtert etwas**, über alle 25 Stufen. Eine Kurve mit
    einem Exponenten über eins kippt am Ende, und niemand sieht es, weil
    niemand die fünfundzwanzigste Stufe spielt.

12. **Eine Dauerwaffe rechnet Schaden je Zeit, nicht je Bild.** Hängt der
    Flegel am Takt, ist er auf einem 120-Hz-Telefon doppelt so stark — und
    eine Einstellung im Anzeigemenü verstellte den Schwierigkeitsgrad.

13. **Nach y sortiert zeichnen.** In einem Bild ohne Perspektive ist die
    Zeichenreihenfolge die einzige Tiefe, die es gibt; ohne sie steht ein
    Feind vor dem Helden, der hinter ihm ist.

14. **Der Held wird freigestellt.** Eine Fläche in Pergamentton unter ihm,
    etwas größer als er — im leeren Feld unsichtbar, im Gedränge steht er in
    einer Lücke. Es ist die einzige Stelle im Spiel, an der Pergament über
    Tusche liegt. Ein heller Saum *unter* der Figur (der erste Anlauf) macht
    sie blass statt auffindbar.

15. **Der Stick sitzt, wo der Daumen aufsetzt.** Kein fester Knüppel an einer
    Ecke — auf einem Telefon hält niemand den Daumen dort, wo ein Entwerfer
    ihn hingelegt hat.

16. **Im Lauf gehört der Finger dem Helden** — außer beim Aufstieg. Ein Knopf,
    der einen Zug verschluckt, kostet Leben.

17. **Kein Angebot nach einer Niederlage.** Der Bericht hat zwei Wege.

18. **`get_display_safe_area()` nur auf dem Telefon fragen** und jeden Rand auf
    12 % der Bildkante deckeln: auf dem Schreibtisch liefert sie den ganzen
    Bildschirm und nicht das Fenster.

19. **Der Ton wird gemessen, nicht gehört.** Anfang und Ende jedes Puffers
    stehen konstruktionsbedingt auf null (`_huelle`); ein Puffer, der bei
    halber Auslenkung einsetzt, ist ein Knacks und kein Schlag. Und er wird
    **gedrosselt**: in Minute neun fallen dreißig Feinde je Sekunde.

## Was beim Bau gelernt wurde

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
