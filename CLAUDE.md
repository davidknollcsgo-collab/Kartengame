# Hinweise für Claude Code

## Was hier gebaut wird

**HUNDRED CUTS** — ein Duell aus Linien.

Ein Gegner holt aus. Seine Haltung sagt, welchen Schnitt er führt, und eine
Zinnoberlinie bestätigt es; sie wächst, und wenn sie voll ist, fällt der Hieb.
Der Daumen muss dieselbe Achse treffen, im Fenster um den Schlag. Wer richtig
liest, pariert und stößt nach; wer daneben wischt, steht einen Augenblick
offen. Drei bis sieben Wunden, dann ist die Ronde vorbei.

**Was dieses Spiel nicht ist:** kein Zielen, kein Ausweichen, kein Schaden.
Ein Hieb tötet, wenn er sitzt, und das gilt für beide Seiten — von der ersten
Ronde bis zur hundertsten. Was der Spieler in der Schule gewinnt, ist
**Nachsicht**: längere Ansätze, breitere Fenster, mehr Wunden, längere
Öffnungen. Eine Schule, die den Spieler härter zuschlagen ließe, machte aus
einem Duell ein Rechenspiel.

**Es gab bis September 2026 ein anderes Spiel in diesem Repository**, NEKTON:
eine biolumineszente Kolonie in einem Tiefseegraben, ein Lichtkegel am Finger,
Räuber aus allen Richtungen. Es ist gelöscht. Wer im Quelltext oder in älteren
Commits über `rundlauf.gd`, `schwarm.gd`, `schlund.gd`, `wellen.gd`,
`kolonie_stand.gd` oder `scenes/rundum.tscn` stolpert: die gibt es nicht mehr.
Der Grund steht in einem Satz — **eine Schleife, eine Wahrheit.**

Alles Sichtbare und Hörbare entsteht in diesem Repository: Grafik prozedural
im Code (`Tusche`), Ton synthetisiert (`Stahl`), Namen und Texte selbst
geschrieben. `ASSETS.md` ist der Nachweis.

### Der Artstyle: Tusche auf Papier

Ein Blatt in gebrochenem Weiß, Figuren als schwarze Pinselmassen, ein einziger
Zinnoberton für die Gefahr. Kein Glühen, kein HDR — Tusche leuchtet nicht.

Drei Regeln, die für **jede** neue Zeichnung hier gelten:

* **Kein Strich hat zwei gleiche Enden.** Ein Band gleicher Breite ist ein
  Klebestreifen; ein Pinsel setzt auf, trägt und hebt ab.
* **Kein Strich ist gleichmäßig dunkel.** Tusche läuft satt an und trocknet
  aus.
* **Erst die Masse, dann die Glieder.** Wer mit den Gliedern anfängt, baut ein
  Skelett und hängt danach vergeblich Kleider daran.

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
godot --headless --path . --script tests/run_tests.gd   # ~20 s, Exitcode 1 bei Fehler
godot --headless --path . --quit-after 180              # startet das Spiel wirklich
```

**Der Testlauf allein beweist nicht, dass das Spiel läuft.** Er lädt
`schnitt_lauf.gd`, `schnitt_hud.gd`, `buehne.gd` und `fechter.gd` nie — ein
`--script`-Lauf kennt keine Autoloads und keine Szene. Ein Parse-Fehler in
einer dieser Dateien bleibt im Testlauf grün. Genau das ist hier schon zweimal
passiert, an einem Tag:

* `fechter.gd` hatte **kein `class_name`**. Testlauf 18/18 grün, Spiel tot.
* `schnitt_hud.gd` hatte ein `var lebt := i < st.atem` auf einem untypisierten
  `st` — „Cannot infer the type", Warnung als Fehler. Testlauf grün, Spiel tot.

Der Startlauf findet beides in Sekunden.

**`--import` nach jeder neuen Datei mit `class_name`.** Sonst kennt die
Registry die Klasse nicht, und was dann passiert, sieht nicht nach dem Fehler
aus, der es ist: das Skript lädt gar nicht erst, die Ausgabe bleibt leer.

**`quit()` kehrt zurück.** Es meldet der Hauptschleife nur an, dass sie
aufhören soll — der Rest der Funktion läuft weiter. Also `return` hinter jedes
`quit()`, das nicht das letzte Statement der Funktion ist.

**Achtung beim Fehler-Check in der Shell:** `godot ... | grep ... | head` gibt
immer Erfolg zurück, weil `head` gelingt. Die Ausgabe in eine Variable fangen
und auf leer prüfen.

## Optik prüfen (Screenshots)

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1600 \
  -- --schuss /pfad/bild.png --ronde 11 --stufen 6 --zeit 1.2
```

| Schalter | Wirkung |
|---|---|
| `--schuss <datei>` | speichert und beendet |
| `--ronde <n>` | beginnt die Ronde n |
| `--zeit <s>` | rechnet s Sekunden Duell mit festem Takt vor |
| `--stufen <n>` | setzt alle vier Hallen auf Stufe n **und den Kontostand** |
| `--schule` | der Schulschirm |
| `--ende` | der Bericht nach der Ronde |

**`--stufen` setzt auch die Ehre.** Ein Schalter, der die halbe Wahrheit
setzt, zeigt ein Spiel, das es nicht gibt — eine Schule auf Stufe vierzehn
neben null Ehre.

**`--zeit` treibt jeden Knoten mit eigenem `_process`**, nicht nur den
Hauptknoten. Ein Vorlauf, in dem der Hintergrund still steht und die Figuren
altern, zeigt ein Bild, das im Spiel nie vorkommt — **ein Messstand, der die
Wirklichkeit nicht abbildet, ist schlimmer als keiner.**

**Wer eine Form beurteilt, sieht sie in der Größe an, in der sie gespielt
wird**, und bei 720×1600 und nicht nur bei 720×1280: die meisten Telefone sind
20:9.

## Zusicherungen, die nicht aufgeweicht werden dürfen

1. **Was gezeigt wird, gilt.** Die Zinnoberlinie nimmt ihre Länge aus
   `Duell.fuehrungsanteil()` — aus **derselben** Zahl, an der das Fenster
   hängt. Liefen beide auseinander, wäre die Linie eine Lüge und das Spiel
   unlernbar. `_test_fuehrung_und_fenster_teilen_die_zahl` hält es fest.

2. **Die Haltung trägt die Aussage, nicht die Farbe.** Ein Fechter im Ansatz
   muss aus zwanzig Bildpunkten erkennbar machen, *welche* Linie kommt — vor
   der Zinnoberlinie. Deshalb liegt zwischen den fünf Ansätzen der
   größtmögliche Abstand: Klinge über dem Kopf, an der rechten Schulter, tief
   an der linken Hüfte, waagerecht hinter dem Rücken, Spitze voran.

3. **Ruhren verliert.** Ohne die Sperre nach einem Fehlgriff wäre die beste
   Strategie, alle vier Achsen dauernd durchzuwischen, bis eine passt — und
   dann wäre es kein Lesen mehr. `_test_ruehren_verliert` prüft nicht, dass
   Rühren *schlechter* ist, sondern dass es **verliert**: ein Vorteil, den
   man sich errühren kann, ist ein Fehler und kein Schwierigkeitsgrad.

4. **Es gibt kein totes Band zwischen zwei Achsen.** Hier stand einmal eine
   Toleranz von zweiundzwanzig Grad. Eine Schwelle hat einen Rand, und ein
   Rand ist entweder doppeldeutig (eine Richtung gehört zwei Achsen) oder tot
   (ein sauberer Wisch trifft nichts, und der Spieler sucht den Fehler bei
   sich). `Schnitte.naechste_achse()` fragt stattdessen nach der **nächsten**
   Achse — kein Rand, keine Zahl, kein toter Streifen.

5. **Eine Sorte, die man am Rhythmus nicht erkennt, ist keine.** Ein Gegner
   mit denselben vier Zahlen ist derselbe Gegner unter zwei Namen.
   `_test_jede_sorte_hat_einen_eigenen_rhythmus` hält es fest. Ein Gegner mit
   mehr Leben wäre derselbe Gegner mit mehr Wartezeit — deshalb gibt es kein
   Leben, nur Paraden.

6. **Das Fenster passt in den Ansatz**, und zwar auf **jeder** Schulstufe.
   Wäre es breiter als der halbe Ansatz, begänne es, bevor die Führungslinie
   gewachsen ist: man parierte, bevor man gelesen hat, und das Lesen ist der
   ganze Inhalt. Der erste Test prüfte nur Stufe null und war grün, während
   die Kombination aus vollem Handgelenk und schnellstem Gegner längst
   kaputt war — **wer zwei Zahlen prüft, die zusammen wachsen, prüft sie
   zusammen.**

7. **Die Täuschung lässt Zeit zum zweiten Lesen.** Bleibt nach dem Wechsel
   weniger als eine Reaktionszeit, ist sie keine Täuschung mehr, sondern ein
   Würfel.

8. **Einkommen und Kosten wachsen mit derselben Rate.** Hallen kosten
   geometrisch; ein Einkommen, das linear oder auch nur langsamer geometrisch
   wächst, holt das nie wieder ein. `Ronde.ehre()` **ist** deshalb
   `Schule.rundenkosten()` geteilt durch `RONDEN_JE_RUNDE`. Geprüft wird die
   Ableitung selbst und nicht ein Verhältnis: ein Verhältnis zu prüfen hieße,
   die Rundung bei kleinen Zahlen für eine Abweichung zu halten.

9. **Die Schule macht die Ronde nicht kleiner, sondern überlebbar.** Hier
   stand einmal eine `Schule.fassung()`, aus der die Rondengröße fiel. Das
   war falsch: die vier Hallen geben Nachsicht, nicht Durchsatz. Wer daraus
   eine größere Ronde ableitet, nimmt mit der einen Hand, was er mit der
   anderen gibt — der Spieler kauft eine Stufe und merkt nichts. Wie groß
   eine Ronde ist, sagt allein die Ronde; wie schwer sie sich anfühlt, die
   Schule.

10. **Eine Ronde ist eine Zeitspanne, kein Sack Gegner.** `Ronde.staerke()`
    rechnet aus `RONDE_SEKUNDEN` und `takt_je_aufwand()`, und letzteres ist am
    Ronin abgeleitet (Ansatz + Öffnung + Atemzug, geteilt durch seine Ehre).
    Der erste Anlauf setzte Budget und Preis in **verschiedenen Einheiten** —
    das Budget in Sekunden mal Wunden, den Preis in Ehre — und jede Ronde
    bestand daraufhin aus genau einem Gegner. Eine Ableitung, deren beide
    Seiten nicht dieselbe Einheit haben, ist keine.

11. **Der Meister tritt zuletzt an, und er tritt allein an.** Eine Ronde, die
    mit ihrem größten Gegner anfängt, hat keinen Bogen, sondern ein Nachspiel.

12. **Kein Ausbau darf etwas verschlechtern.** Ein Test hält das über alle
    vierzig Stufen fest — eine Kurve mit einem Exponenten über eins kippt am
    Ende, und niemand sieht es, weil niemand die vierzigste Stufe spielt.

13. **Zwei Gegner stehen nie auf derselben Stelle.** Der Kern weiß nicht, wo
    eine Stelle im Bild liegt; er weiß nur, dass zwei sie nicht teilen
    dürfen. Ohne das fällt im Bild einer durch den anderen hindurch.

14. **`get_display_safe_area()` nur auf dem Telefon fragen.** Auf dem
    Schreibtisch liefert sie den ganzen *Bildschirm* und nicht das Fenster,
    und aus der Differenz wird ein Rand von vierhundert Bildpunkten. Also
    `OS.has_feature("mobile")` davor und jeden Rand auf 12 % der Bildkante
    deckeln.

15. **Im Duell gehört der Finger der Klinge.** Das Bedienbild fasst dort
    nichts an — ein Knopf, der einen Wisch verschluckt, kostet eine Wunde.

16. **Kein Angebot nach einer Niederlage.** Der Bericht hat zwei Wege: noch
    einmal, oder zurück. Nie mehr.

17. **Der Ton wird gemessen, nicht gehört.** Es gibt hier kein Audiogerät und
    in CI erst recht keines — `stahl.gd` rechnet seine Puffer ins Blinde.
    Anfang und Ende jedes Puffers stehen deshalb konstruktionsbedingt auf
    null (`_huelle`): ein Puffer, der bei halber Auslenkung einsetzt, ist ein
    Knacks und kein Schlag.

18. **Der Ansatzton ist ein Taktgeber, keine Stimmung.** Wer ihn hört, weiß,
    dass eine Linie angefangen hat, auch wenn er gerade woanders hinsieht.
    Deshalb ist er kurz, trocken und für jeden Gegner gleich — ein Ansatzton,
    der je nach Sorte anders klingt, wäre eine zweite Aussage über dieselbe
    Sache.

19. **Das Beben ist sparsam und abschaltbar.** Vier Ereignisse, Sperre 0,12 s.
    Ein Beben je Parade wäre in einer vollen Ronde ein Dauerbrummen und
    Akkufraß. Der Android-Export braucht `permissions/vibrate=true` in
    **beiden** Ladeständen; ohne den Eintrag bleibt `vibrate_handheld()` auf
    dem Gerät folgenlos, und zwar stumm.

## Was beim Bau gelernt wurde

**Eine Figur aus Strichen ist ein Strichmännchen, egal wie gut die Haltung
stimmt.** Der erste Anlauf stand bei 0,115 Rumpfbreite und 0,082 fürs Bein.
Im Bild: ein Draht mit einem Kopf darauf. Der zweite Anlauf ging auf 0,30 und
0,21 — und war ein **Käfer**: die Masse verschluckte die Glieder. Getragen hat
erst der dritte (0,195 / 0,142) zusammen mit dem eigentlichen Fund darunter.

**Ein Glied ist ein Strang, keine zwei Züge.** Schenkel und Schienbein als
zwei Züge haben am Knie eine **Kerbe**: der eine läuft auf seine Spitze aus,
der andere setzt mit voller Breite an. Zwei gebogene Arme nebeneinander
ergaben aus demselben Grund einen **Reifen** statt zweier Arme.
`Tusche.strang()` zieht eine Kurve durch die Stützstellen mit einer Breite je
Stützstelle. Dieselbe alte Regel: **wo ein Übergang hingehört, wird keine
Kante gezeichnet** — und eine Kerbe ist eine Kante.

**Ein Klecks braucht sein Rauschen über dem Winkel, nicht je Ecke.** Ein Wurf
je Eckpunkt gibt bei vielen Ecken einen **Stern**: zwischen zwei Nachbarn
liegt der volle Sprung. Und die Zahl der Ecken muss mit dem Radius wachsen —
elf sind auf einem Kopf ein Klecks und auf einer Sonnenscheibe ein sichtbares
Vieleck.

**Eine Bühne braucht Tiefe, und Tiefe heißt zweierlei zugleich.** Der erste
Anlauf setzte den Spieler auf dieselbe Bodenlinie wie die Gegner, nur etwas
tiefer und etwas größer. Im Bild war das ein **Knäuel**: vier Köpfe auf
derselben Höhe. Getragen hat erst beides zusammen — deutlich tiefer im Bild
*und* deutlich größer. Ein Fechter, der nur größer ist, sieht aus wie derselbe
Fechter weiter vorn im selben Gedränge.

**Eine Führungslinie bleibt bei ihrem Gegner.** Mit 0,66 Radien je Seite ragte
sie weiter, als der Fechter hoch ist, und der Stoß-Zeiger querte den halben
Schirm. Dann liest man einen Strahl und sucht seinen Absender. Sie liegt jetzt
**innerhalb** der Figur, die sie meint.

**Ein Wisch, den man als Strich lesen kann, ist kein Dunst mehr.** Drei
schmale Lavierungen als ferne Berge waren im Bild graue **Kratzer**, die quer
über dem Blatt hingen. Zwei sehr breite und sehr blasse tun, was sie sollen.

**Ein Strich je Zeichenaufruf ist auf einem Telefon sofort zu teuer.** Ein
Hintergrund aus hundertvierzig Fasern wäre hundertvierzig Aufrufe für etwas,
das man kaum sieht; ein Handy-Grafikchip will unter tausend für das ganze
Bild. `Tusche` sammelt deshalb alles in **ein** Dreiecksnetz und setzt es mit
einem `canvas_item_add_triangle_array` ab: eine Figur, ein Aufruf. Das ist
keine vorgezogene Optimierung, sondern die Form, in der dieses Bild überhaupt
bezahlbar ist.

**Und die Zahlen dazu, in diesem Renderer gemessen** (sie gelten weiter, sie
sind eine Eigenschaft der Engine und nicht des alten Spiels):

| Aufruf | Zeichenaufrufe |
|---|---|
| `draw_line`, auch geglättet | 50 Stück = **1** |
| `draw_colored_polygon` | 1 je Stück, **auch mit Deckung null** |
| `draw_circle` hart / geglättet | 1 / **2** je Stück |
| `draw_arc` | **3** je Stück |
| `draw_polyline` geglättet | **3 je Zug**, unabhängig von der Länge |

**Und über das Messen selbst, teuer bezahlt am vorigen Spiel:** eine
Einzelmessung aus einer streuenden Verteilung ist ein Zug und kein Befund. Die
Bildrate dieses Behälters streut um gut zehn Prozent zwischen zwei Läufen
desselben Codes; wer damit eine Änderung von zehn Prozent beurteilen will,
braucht mehr als einen Lauf je Seite, und er misst **abwechselnd** und nicht
gegen eine Zahl von vorhin.

**Wenn im Bild etwas steht, das keine Zeichnung erklärt**, ist der nächste
Schritt nicht Nachdenken, sondern **einen Knoten stillstellen und noch einmal
schießen**. Das kostet zwanzig Sekunden je Versuch und beantwortet die Frage
endgültig.

**Und eine Notiz über eine Einschränkung der Engine altert.** Wer eine findet,
prüft sie nach, bevor er ihr eine Konstruktion hinterherbaut.

## Grenzen der Umgebung

- `dl.google.com` ist blockiert → kein Android SDK → **APK-Builds nur in CI**
- Der Container ist flüchtig; Godot muss je Session neu installiert werden
- MSAA-2D gibt es im Kompatibilitäts-Renderer nicht (`2D MSAA is not yet
  supported for GLES3`). Weiche Kanten kommen hier aus dem Zeichnen selbst:
  jeder `Tusche`-Strich hat zwei durchsichtige Außenreihen. Das ist kein
  Glättungstrick, sondern die Form eines Haarpinsels — die weiche Kante ist
  hier das Motiv und nicht ihre Behebung.

## Konventionen

- **Bezeichner und Kommentare auf Deutsch, alles Sichtbare auf Englisch.**
  Die Trennung ist Absicht: der Store ist englischsprachig, der Quelltext
  bleibt es, wie er ist.
- Einrückung: 4 Leerzeichen
- `scripts/kern/` und `scripts/daten/` bleiben frei von Szenen- und
  Autoload-Bezügen — nur so sind sie headless testbar
- Jede Testfunktion endet mit `return true`; der Läufer wertet anderes als
  Abbruch. Und jede muss in `TESTS` stehen — ein Wächter prüft das
- GDScript leitet Typen aus untypisierten Werten **nicht** ab, und die
  Warnung ist hier ein Fehler. `var x := <Variant>` bricht die Datei; also
  `var x: Duell.Stand = ...` schreiben, wo der Rückgabetyp nicht feststeht
- Neue Assets **immer** im selben Commit in `ASSETS.md` eintragen
- Kein `draw_polyline` für breite Züge in der Welt: dafür gibt es `Tusche`.
  Schrift und Knopfkästen sind die Ausnahme, dort ist die Polylinie richtig
