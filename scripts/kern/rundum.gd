class_name Rundum
extends RefCounted

## Die Rechnung fuer den Rundumlauf: ein bewegliches Boot in offenem Wasser,
## Raeuber aus allen Richtungen, Polypen als Begleiter.
##
## **Was hier steht und was nicht.** Der Kegel ist schon rundum: `Schlund.
## beleuchtung()`, `getroffen()`, `zielrichtung()` und `gedreht()` rechnen mit
## freien Vektoren und wissen nichts von oben und unten. Sie werden hier
## unveraendert weiterverwendet - das ist die Zusage, dass gezeichnetes Licht
## und Schaden dieselbe Rechnung sind, und sie soll den Umbau ueberleben.
##
## Was `Schlund` nicht kann, ist der **Weg** eines Raeubers. `Schlund.bahn()`
## laesst ihn zu einer festen Zeile sinken und seitlich pendeln; das ist eine
## reine Funktion der Zeit, weil das Ziel stillsteht. Hier bewegt sich das
## Ziel, also kann der Weg keine geschlossene Formel mehr sein - er wird
## Schritt fuer Schritt gerechnet. Deterministisch bleibt er trotzdem: bei
## gleichem Anfang und gleichen Schritten kommt dasselbe heraus, und nur so
## kann ein Pruefer spaeter eine ganze Welle nachspielen.
##
## Reine Rechnung, keine Szenen- und keine Autoload-Bezuege.


## --- Das Feld ---
##
## Eine Kreisscheibe statt eines Rechtecks. Bei einem Rechteck hiengen die
## Ecken davon ab, wie hoch der Bildschirm ist (siehe `Graben.kamera_y`), und
## eine Ecke, die es auf dem einen Telefon gibt und auf dem anderen nicht,
## ist kein Spielfeld. Ein Kreis ist auf jedem Geraet derselbe.
##
## **Und sie ist viel groesser als das Bild.** Der erste Anlauf legte den
## Radius auf die halbe Bildbreite: das Feld passte auf einen Schirm, die
## Kamera stand still, und man fuhr in einer Schuessel herum. Ein Feld, das
## man ganz sieht, ist kein Ort - man faehrt darin, aber nirgendwohin. Jetzt
## traegt es das Vielfache eines Bildes, und die Kamera folgt.
const FELD_RADIUS := 1500.0

## Wie weit man sieht - ungefaehr die halbe Diagonale des laengsten Telefons
## (720 mal 1600 gibt 877). Alles, was hier drin ist, muss gezeichnet werden;
## alles andere nicht.
const SICHT := 900.0

## Wie weit **ueber** `SICHT` hinaus noch gezeichnet werden muss.
##
## `SICHT` ist auf 720x1600 gerechnet und deckt das mit dreiundzwanzig
## Einheiten Luft. Es gibt aber Telefone mit 21:9, und dort liegt die halbe
## Diagonale bei 914 - also **ausserhalb**. Wer mit `SICHT` keult, schneidet
## dem Spieler dann die Bildecken weg, und zwar genau auf den Geraeten, auf
## denen ohnehin schon `Graben.kamera_y()` nachhelfen muss (Zusage 23).
##
## Die Zahl ist deshalb abgeleitet und nicht gewaehlt: das schmalste Bild,
## das dieses Spiel tragen muss, gegen `SICHT` gerechnet. Wer `SICHT`
## anfasst, bekommt den Rand von allein mit.
##
## Was **nicht** darin steckt, ist der eigene Radius eines Tieres und seine
## Schleppe - beides haengt am Tier und nicht am Bild, und beides fragt
## `schwarm.gd::_im_blick()` einzeln ab.
const SCHMALSTES_BILD := 21.0 / 9.0
const BILD_BREITE := 720.0


static func zeichen_rand() -> float:
    var hoch := BILD_BREITE * SCHMALSTES_BILD
    return maxf(0.0,
        sqrt(BILD_BREITE * BILD_BREITE + hoch * hoch) * 0.5 - SICHT)

## Wo Raeuber eintreten: **um das Boot herum**, knapp ausserhalb der Sicht.
##
## Nicht mehr um die Feldmitte. Bei einem Feld von 1500 Einheiten haette ein
## Raeuber am Rand bis zu einer halben Minute zu schwimmen, bevor ihn
## ueberhaupt jemand sieht - die Welle waere dann kein Angriff, sondern eine
## Anreise. Was aus dem Nichts erscheint, sieht nach einem Fehler aus; was
## nie ankommt, ist keins.
const EINTRITT_RADIUS := 980.0


## Wie weit der Daumen vom Boot weg sein muss, bevor es losfaehrt. Darunter
## wird nur gezielt.
##
## **Ein Finger, zwei Aufgaben.** Das ganze Spiel verspricht "halten und
## ziehen"; zwei Steuerkreuze waeren ein anderes Versprechen. Der Finger sagt
## deshalb beides: die Richtung, in die der Kegel zeigt, und - sobald er weit
## genug weg ist - wohin das Boot faehrt. Wer nur zielen will, haelt den
## Daumen nah am Boot.
const TOTZONE := 74.0

## Ab wo die volle Fahrt anliegt, gemessen ab dem Rand der Totzone.
const VOLLE_FAHRT := 190.0


## Der Versatz auf dem Eintrittsring zu einem Winkel. Das Boot kommt dazu -
## die Raeuber treten um den Spieler herum ein und nicht um die Feldmitte.
static func eintritt(winkel: float) -> Vector2:
    return Vector2.RIGHT.rotated(winkel) * EINTRITT_RADIUS


## Haelt einen Ort in der Scheibe. `rand` ist der Abstand, den der Koerper
## selbst noch braucht.
static func gehalten(ort: Vector2, rand := 0.0) -> Vector2:
    var grenze := maxf(1.0, FELD_RADIUS - rand)
    if ort.length_squared() <= grenze * grenze:
        return ort
    return ort.normalized() * grenze


## Wie schnell das Boot fahren soll, wenn der Finger dort liegt.
##
## Null innerhalb der Totzone, dann linear bis `hoechsttempo`. Kein Sprung an
## der Kante: wer den Daumen langsam wegzieht, faehrt langsam an.
static func fahrt(ort: Vector2, finger: Vector2,
        hoechsttempo: float) -> Vector2:
    var versatz := finger - ort
    var weite := versatz.length()
    if weite <= TOTZONE:
        return Vector2.ZERO
    var anteil := clampf((weite - TOTZONE) / VOLLE_FAHRT, 0.0, 1.0)
    return versatz / weite * hoechsttempo * anteil


## Ein Schritt auf dem Weg zu einem **beweglichen** Ziel.
##
## Das Pendeln sitzt nicht in der Geschwindigkeit, sondern im Ziel: gesteuert
## wird auf einen Punkt, der seitlich neben dem echten liegt und hin und her
## wandert. Andersherum - eine Querbewegung auf die Geschwindigkeit addiert -
## kann das Tier schneller werden als sein Tempo, und ein Raeuber, der beim
## Ausweichen beschleunigt, ist kein Entwurf, sondern ein Vorzeichenfehler.
## `umlauf` ist der Abstand, den ein Tier zum Ziel haelt, statt heranzukommen
## (0 heisst: geradewegs). `weichen` schiebt es zusaetzlich nach aussen,
## solange es im Licht steht - beides sind Wege, die es im Schlund nicht geben
## konnte, weil dort alles dieselbe Bahn nach unten sank.
static func schritt(ort: Vector2, ziel: Vector2, tempo: float,
        schlaengel: float, takt: float, phase: float, zeit: float,
        delta: float, drift := 0.0, umlauf := 0.0, weichen := 0.0) -> Vector2:
    var zum_ziel := ziel - ort
    var weite := zum_ziel.length()
    if weite < 0.001:
        return ort
    var k := zum_ziel / weite
    var quer := k.orthogonal()

    # **Wer nah dran ist, kommt.**
    #
    # Ein Raeuber pendelte quer zu seiner Bahn, driftete seitlich und naeherte
    # sich dabei mit `tempo`. Aus der Ferne ist das genau richtig - es ist der
    # Grund, warum ein Schwarm lebendig aussieht. Direkt vor dem Boot war es
    # falsch: das Pendeln ist dort so gross wie der Weg, den das Tier in
    # derselben Zeit zurueckt, und im Bild schwamm es auf der Stelle herum,
    # statt zuzustossen.
    #
    # Innerhalb von `BEGLEITER_REICHWEITE` faellt das Beiwerk deshalb weg und
    # das Tier zieht gerade durch. **Derselbe Radius, auf dem die Begleiter
    # schiessen**, und das ist keine Sparsamkeit: er ist der Schirm um das
    # Boot, und wer ihn durchbrochen hat, ist nah.
    #
    # **Und der Radius ist gemessen, nicht gewaehlt.** Der erste Anlauf nahm
    # `WECK_RADIUS` (420) - mit derselben Begruendung, die oben steht, nur am
    # falschen Anker. Er ist groesser als der Ring des Kreisers (260): damit
    # kreiste der nie mehr, sondern zog von seinem Ring aus durch, und der
    # Kolonielauf sprang von **35 auf 80** gefallene Sitzungen. Auf 210 sind
    # es 39, und der Ring bleibt ein Ring.
    #
    # Isoliert gemessen, weil in demselben Commit zwei Dinge stecken: nur der
    # Bissfehler ohne den Angriff gibt **37** - er kostet also nichts, und
    # die 80 gingen allein auf den Radius.
    #
    # Linear und nicht quadratisch: quadratisch gemessen 37 statt 39, also
    # derselbe Wert im Rauschen (dieselbe Fassung streut ueber die Saaten von
    # 35 bis 144), aber auf halbem Weg nur die halbe Entschlossenheit. Wo die
    # Messung nichts unterscheidet, entscheidet das Bild.
    var nah := clampf(1.0 - weite / BEGLEITER_REICHWEITE, 0.0, 1.0)
    var angriff := nah

    # **Kreisen statt kommen.** Innerhalb des Umlaufabstands dreht sich die
    # Marschrichtung zur Seite; ausserhalb kommt das Tier weiter heran. Der
    # Uebergang ist weich, sonst schnappt es auf dem Ring hin und her.
    #
    # Die Umlaufrichtung steckt in der Phase - dieselbe Zahl wie beim Pendeln
    # und bei der Drift. Ein eigener Wuerfel dafuer waere eine zweite Quelle
    # fuer denselben Zufall.
    if umlauf > 0.0:
        # **Der Ring wird enger.** Ein Tier, das ewig auf demselben Abstand
        # kreist, kann nie beissen - und ein Hoehepunkt, der nicht wehtun
        # kann, ist keine Bedrohung, sondern eine Uhr. Der Abstand schrumpft
        # deshalb ueber die Lebenszeit: man hat Zeit, aber nicht beliebig
        # viel, und man sieht sie kommen.
        var eng := umlauf * maxf(0.0, 1.0 - zeit * UMLAUF_ENGER)
        var innen := clampf((eng - weite) / maxf(1.0, umlauf * 0.5),
            -1.0, 1.0)
        var herum := quer * (1.0 if sin(phase) >= 0.0 else -1.0)

        # **Quer auf dem Ring, laengs daneben - und das stand hier
        # verkehrt.** Der Anteil `absf(innen)` gewichtete das Kreisen, also
        # gerade dann am staerksten, wenn das Tier **weit weg** vom Ring war.
        # Ein Ringmaul, dessen Ring sich zusammenzieht, entfernte sich damit
        # immer weiter von ihm und kreiste dafuer immer entschlossener: der
        # Ring schrumpfte auf null, `innen` blieb bei -1, und das Tier flog
        # bis in alle Ewigkeit dieselbe Bahn.
        #
        # Gemessen mit `tools/artenkosten.gd`: bei Welle 26 brannte der Kegel
        # **null Sekunden** auf ihm, in vierhundert Sekunden Laufzeit. Nicht
        # zaeh - unerreichbar. Der Kommentar zwei Zeilen darueber sagte seit
        # jeher, wie es gemeint war ("ausserhalb kommt das Tier weiter
        # heran"); nur tat der Code das Gegenteil.
        #
        # Richtig ist: auf dem Ring (`innen` nahe 0) quer, weit davon laengs.
        var ring := 1.0 - absf(innen)
        # **Und aus der Naehe wird aus dem Kreisen ein Zustoss.** Der Term
        # `- k * maxf(0, innen)` schiebt das Tier nach **aussen**, sobald das
        # Boot innerhalb seines Rings steht - wer auf einen Kreiser zufuhr,
        # trieb ihn damit vor sich her, und genau das sah aus wie ein Tier,
        # das nur herumschwimmt. Der Rueckstoss faellt jetzt mit der Naehe
        # weg, und das Kreisen mit ihm.
        #
        # Auf Abstand bleibt beides, wie es war: der Kreiser haelt seinen
        # Ring und zieht ihn langsam enger. Seine Regel ist nicht "er kommt
        # nie an", sondern "er kommt nicht sofort".
        var weg_vom_ring := maxf(0.0, innen) * 1.2 * (1.0 - angriff)
        k = (k * maxf(absf(innen), angriff) + herum * ring * (1.0 - angriff)
            - k * weg_vom_ring).normalized()
        quer = k.orthogonal()
    # **Zurueckweichen, solange es brennt.** `weichen` kommt aus der
    # Helligkeit, in der das Tier gerade steht - wer es anleuchtet, schiebt
    # es weg. Es kehrt nicht um: der Anteil ist gedeckelt, sonst stuende es
    # ausserhalb der Reichweite und die Welle liefe in den Deckel.
    if weichen > 0.0:
        k = (k - (ziel - ort).normalized() * minf(1.6, weichen)).normalized()
    var seitlich := schlaengel * sin(takt * zeit + phase)
    if drift != 0.0:
        # Die Richtung steckt in der Phase - dieselbe Zahl wie beim Pendeln,
        # so wie in `Schlund.bahn()` auch. Ein eigener Wuerfel dafuer waere
        # eine zweite Quelle fuer denselben Zufall.
        seitlich += drift * zeit * (1.0 if cos(phase) >= 0.0 else -1.0)
    # Beides faellt beim Angriff weg - auch die Drift, obwohl sie die Regel
    # des Treibankers ist ("rutscht seitlich weg, waehrend er naeher kommt").
    # Sie bleibt seine Regel auf dem ganzen Anmarsch; was auf den letzten
    # Metern zaehlt, ist, dass er sich entscheidet.
    seitlich *= 1.0 - angriff
    # Gesteuert wird auf einen Punkt neben dem Ziel - bei Umlauf und Weichen
    # auf einen Punkt in Marschrichtung, weil "das Ziel" dann nicht mehr dort
    # liegt, wo das Tier hinwill.
    # Fuer `umlauf == 0` und `weichen == 0` ist das Zeichen fuer Zeichen die
    # alte Rechnung: `k * weite` **ist** `ziel - ort`. Der Weg jedes
    # bestehenden Tieres bleibt damit unveraendert, und das muss er auch -
    # sonst waere aus einer neuen Art eine neue Balance geworden.
    var gelenkt := k * weite + quer * seitlich
    if gelenkt.length_squared() < 0.000001:
        return ort
    return ort + gelenkt.normalized() * tempo * delta


## Wo der `index`-te von `anzahl` Begleitern stehen soll.
##
## Ein Faecher **hinter** dem Boot, nicht darum herum. Vor dem Boot staenden
## sie im Kegel und verdeckten genau das, worauf man zielt; ringsherum waere
## keine Formation, sondern ein Kranz, und man saehe nicht mehr, wohin man
## faehrt.
## --- Zahlen, die Spiel und Pruefer beide brauchen ---
##
## **Sie standen in `rundlauf.gd`.** Das ging, solange nur die Szene sie
## brauchte. Seit `tools/simulation.gd` dieselbe Schleife nachrechnet, geht
## es nicht mehr: ein `--script`-Lauf kennt keine Autoloads, `rundlauf.gd`
## haengt an `Fortschritt`, und wer die Zahl deshalb im Pruefer abschreibt,
## hat zwei Beschreibungen desselben Spiels. Genau daran ist bei HYPHA der
## Loesbarkeitspruefer auseinandergelaufen.
##
## Hier stehen deshalb die Zahlen, die **beide** kennen muessen. Was nur das
## Bild betrifft - Kameratraegheit, Zeichenabstaende, Taktfrequenzen der
## Animation -, bleibt drueben.

## Wieviele Wellen gleichzeitig laufen.
##
## Mehr Tiere als in einer einzelnen Welle, und das ist Absicht: man faehrt,
## sieht in alle Richtungen und hat Begleiter dabei. Eine Wellenstaerke, die
## fuer einen festen Posten gerechnet ist, fuehlt sich in Fahrt leer an.
const DICHTE := 3

## Wie gross das Boot ist - der Radius, ab dem ein Raeuber beisst.
const BOOT_RADIUS := 32.0

## Wie lange ein Raeuber braucht, bis er nach einem Treffer wieder beisst.
const BISS_SPERRE := 0.9

## **Nicht jeder Raeuber kommt von aussen auf einen zu.** Jeder vierte liegt
## schon in der Karte und wartet - am Grund, still, blass. Wer geradeaus
## faehrt, trifft irgendwann einen; wer den Kegel voraushaelt, sieht ihn
## vorher.
##
## Das ist der Grund, warum das Aufdecken der Karte etwas kostet: eine
## unbekannte Ecke ist nicht nur dunkel, es kann auch etwas darin liegen.
const LAUER_ANTEIL := 0.25

## Ab welchem Abstand ein Lauerer erwacht. Kleiner als die Sicht: man soll
## ihn sehen koennen, bevor er kommt.
const WECK_RADIUS := 420.0

## **Und der Angriff ist schneller, ohne dass `tempo` steigt.**
##
## Der erste Anlauf gab dem Tier auf den letzten Metern einen Schub von 0,5
## - und `_test_rundum_verfolgt_ohne_zu_beschleunigen` fiel sofort um, zu
## Recht. `Wellen.tempo_in()` ist die Obergrenze der Geschwindigkeit; an ihr
## haengt jede Messung, die es hier gibt (`tools/artenkosten.gd` rechnet
## Erreichbarkeit daraus, und der Preis je Lebenspunkt haengt daran). Ein
## Tier, das schneller sein darf als sein Tempo, macht aus der Zahl eine
## Behauptung.
##
## Gebraucht wird der Schub auch nicht. Ein Raeuber gibt sein Tempo bisher
## zum Teil **quer** aus: das Pendeln steht senkrecht auf der Marschrichtung,
## und je naeher er kommt, desto groesser der Winkel - auf fuenfzig Einheiten
## Abstand sind von neunzig Grad Pendelausschlag noch dreiundvierzig uebrig,
## und damit kommt nur noch knapp drei Viertel des Tempos beim Boot an. Faellt
## das Beiwerk weg, faellt der ganze Rest auf die Marschrichtung. Der Angriff
## ist also schneller, weil er gerade ist, und nicht, weil er tritt.

## Wie weit vom Boot ein Lauerer gelegt wird. Nicht naeher als der
## Weckradius - sonst waere er schon wach, bevor die Welle laeuft.
const LAUER_NAH := 560.0
const LAUER_WEIT := 1400.0

## Wieviele Begleiter hoechstens mitfahren, wie weit hinter dem Boot sie
## stehen und wie weit sie schiessen.
##
## **Wieviele es wirklich sind, sagt die Zuchtkammer** - siehe
## `Kammern.begleiter()`. Hier standen einmal fest drei, waehrend
## `Ausbau.durchsatz()` mit bis zu acht rechnete: die Sollkurve setzte also
## eine Leistung voraus, die es im Boot nicht gab, und der Wellenpruefer
## meldete ab Welle 86 Faelle. Was in die Kurve eingeht, muss der Spieler
## auch haben.
const BEGLEITER_HOECHSTENS := 8
const BEGLEITER_ABSTAND := 96.0
const BEGLEITER_REICHWEITE := 210.0


## Wieviel Umlaufabstand ein kreisendes Tier je Sekunde verliert, als Anteil
## seines Anfangsabstands. Bei 0.02 ist es nach knapp einer Minute heran -
## lange genug, dass man es umkreisen sieht, kurz genug, dass Ignorieren
## etwas kostet.
const UMLAUF_ENGER := 0.02


const FAECHER := 0.62


## Wie tief die hintere der zwei Reihen hinter der vorderen liegt, als
## Anteil von `BEGLEITER_ABSTAND`. Die Reihen liegen **symmetrisch** um den
## Abstand - 0,88 und 1,12 -, und genau daran haengt alles: nicht die
## Streuung kostet, sondern ein Mittelwert daneben. Gemessen 0,93 im Mittel:
## neunundachtzig gefallene Sitzungen. Mittelwert auf `abstand`: fuenfunddreissig.
const REIHE_TIEFE := 0.24

## Wieviel ein Begleiter aus der Reihe weicht, als Anteil des Winkelabstands
## zu seinem Nachbarn - **nicht** der Faecherbreite. Der Unterschied ist die
## Zahl der Begleiter: die Breite steht fest, die Luecke wird mit jedem
## weiteren kleiner. An der Breite gemessen zitterte ein Begleiter bei acht
## Mann weiter, als seine Luecke breit war, und zwei landeten uebereinander.
##
## Bei einem Fuenftel der Luecke koennen zwei Nachbarn hoechstens zwei
## Fuenftel davon verlieren - die Reihenfolge bleibt in jedem Fall, und
## `_test_rundum_begleiter_bleiben_hinten` haelt den Rest fest.
const ZITTERN := 0.20


static func begleiter_ziel(index: int, anzahl: int, fuehrer: Vector2,
        blick: Vector2, abstand: float) -> Vector2:
    if blick.length_squared() < 0.000001:
        blick = Vector2.UP
    var t := 0.5
    if anzahl > 1:
        t = float(index) / float(anzahl - 1)
    # **Ein Schwarm steht nicht auf einem Kreisbogen - aber der Abstand ist
    # nicht die Stelle, an der man das loest.**
    #
    # Sie sassen einmal auf exakt gleichem Abstand in exakt gleichen
    # Winkeln, und im Bild war das ein Bogen aus sechs gleichen Marken ueber
    # dem Boot: eine Anzeige, keine Tiere. Der Ausweg war, Winkel **und**
    # Abstand zu verschieben - und der Abstand hat das Spiel verschoben.
    # Gemessen mit dem Kolonielauf, jede Groesse einzeln:
    #
    #   | Formation | Mittel | gefallene Sitzungen |
    #   |---|---|---|
    #   | Bogen, fester Abstand | 1,00 | 38 |
    #   | Zittern im Winkel, fester Abstand | 1,00 | 36 |
    #   | Bogenwinkel, Abstand 0,80 bis 1,06 | 0,93 | 89 |
    #   | beides zusammen | 0,93 | 89 |
    #   | zwei Reihen 0,82/1,06 | 0,94 | 90 |
    #   | zwei Reihen 0,88/1,12 | 1,00 | 35 |
    #
    # **Nicht die Streuung kostet, sondern ein Mittelwert daneben.** Das war
    # nicht zu erraten: zwei Reihen um 0,94 stehen bei neunzig, dieselben
    # zwei Reihen um 1,00 bei fuenfunddreissig. Die Tiefe darf also sein,
    # was das Bild braucht - ihr Mittel muss `abstand` sein, denn das ist
    # die Zahl, gegen die `Ausbau.durchsatz()` und mit ihm die ganze
    # Sollkurve gemessen wurde.
    #
    # Gewuerfelt wird nichts: die Verschiebung kommt allein aus dem Platz,
    # ist also je Begleiter fest und ueber die ganze Fahrt dieselbe. Ein
    # Polyp, der seinen Platz jede Sekunde neu sucht, waere ein Flackern.
    var luecke := 2.0 * FAECHER / float(maxi(1, anzahl - 1))
    var versatz := sin(float(index) * 2.39 + 0.7)
    var w := lerpf(-FAECHER, FAECHER, t) + versatz * luecke * ZITTERN
    # Ein einzelner Polyp bildet keine zwei Reihen - er steht auf dem
    # Abstand, gegen den die Sollkurve gemessen ist, und fertig.
    var weit := abstand
    if anzahl > 1:
        weit = abstand * (1.0 + REIHE_TIEFE * (float(index % 2) - 0.5))
    return fuehrer - blick.normalized().rotated(w) * weit


## Welches Tier ein Begleiter nimmt: das naechste in seiner Reichweite.
##
## Gibt den Index in `orte` zurueck, oder -1. Eigene Funktion, weil sie
## testbar sein muss - ein Begleiter, der auf ein Tier ausserhalb seiner
## Reichweite schiesst, ist eine zweite Wahrheit ueber seine Reichweite.
static func naechstes_ziel(von: Vector2, orte: Array[Vector2],
        reichweite: float) -> int:
    var beste := reichweite * reichweite
    var treffer := -1
    for i in orte.size():
        var d := von.distance_squared_to(orte[i])
        if d < beste:
            beste = d
            treffer = i
    return treffer


# --- Die Schwaerme, die nicht angreifen ---------------------------------------
#
# **Nicht jedes Tier im Graben will an das Boot.** Vorher war jedes bewegte
# Ding auf dem Bild ein Raeuber, der geradewegs auf einen zuhielt - eine Karte
# voller Feinde und sonst nichts. Ein Schwarm Kleinfische, der vor dem Licht
# auseinanderstiebt, kostet nichts und macht aus der Flaeche einen Ort.
#
# Sie stehen **ausserhalb des Wellenbudgets**, aus demselben Grund wie die
# Funkenbluete (Zusage 18): sie tauchen in keiner `Wellen.auftritte()` auf,
# zahlen keinen Naehrstoff und koennen niemanden verletzen. Was nichts kostet
# und nichts zahlt, verschiebt auch nichts.

## Ab wann ein Schwarm das Boot bemerkt.
const SCHEU_RADIUS := 300.0

## Wie schnell er dann davonzieht - schneller als er ruhig zieht, aber
## langsamer als das Boot. Ein Schwarm, den man nie einholt, ist eine
## Verhoehnung; einer, der stehen bleibt, ist ein Sack.
const SCHEU_TEMPO := 210.0

## Wie schnell er zieht, wenn ihn nichts stoert.
const ZUG_TEMPO := 46.0


## Wie erschrocken ein Schwarm ist: 0 ausserhalb von `SCHEU_RADIUS`, 1 direkt
## am Boot. Quadratisch, damit die Flucht nicht auf der ganzen Strecke gleich
## heftig ist, sondern erst kurz vorher losgeht.
static func schreck(mitte: Vector2, boot: Vector2) -> float:
    var d := mitte.distance_to(boot)
    if d >= SCHEU_RADIUS:
        return 0.0
    var t := 1.0 - d / SCHEU_RADIUS
    return t * t


## Ein Schritt der Schwarmmitte.
##
## Ruhig zieht sie auf `ruhe_ziel` zu - eine Bahn, die der Aufrufer vorgibt.
## Kommt das Boot naeher, mischt sich die Fluchtrichtung dazu, und mit ihr das
## hoehere Tempo. Gehalten wird das Ergebnis im Feld: ein Schwarm, der aus der
## Karte gescheucht wird, kommt nie wieder.
static func schwarmschritt(mitte: Vector2, ruhe_ziel: Vector2,
        boot: Vector2, delta: float) -> Vector2:
    var s := schreck(mitte, boot)
    var ruhig := (ruhe_ziel - mitte).normalized() * ZUG_TEMPO
    var weg := Vector2.ZERO
    if s > 0.0:
        weg = (mitte - boot).normalized() * SCHEU_TEMPO
        # Am Rand des Feldes hilft geradeaus fliehen nicht - dort geht es
        # seitlich weiter, sonst drueckt sich der Schwarm in die Wand.
        if mitte.length() > FELD_RADIUS * 0.86:
            weg = weg.rotated(PI * 0.5 * signf(weg.cross(mitte)))
    return gehalten(mitte + ruhig.lerp(weg, s) * delta, 40.0)
