class_name Schlund
extends RefCounted

## Die Rechenmitte der Schlundwache.
##
## Hier steht, was der Lichtkegel beleuchtet und wie stark. Diese Datei bleibt
## frei von Szenen- und Autoload-Bezügen, damit sie sich headless laden und
## pruefen laesst.
##
## **Zusicherung:** Das gezeichnete Licht und der Schaden kommen aus derselben
## Funktion `beleuchtung()`. Ein Kegel, der anders aussieht als er wirkt, macht
## die Kernschleife unlesbar - der Spieler kann nicht lernen, was er tut.
##
## Einzige Abhaengigkeit nach aussen ist `Graben` - selbst reine Daten, ohne
## Szenen- und Autoload-Bezug und ohne Rueckbezug hierher. `bahn()` braucht die
## Feldbreite, um driftende Tiere im Bild zu halten; die Zahl daneben noch
## einmal hinzuschreiben waere die zweite Quelle fuer denselben Wert.


## Der Kegel liegt nicht am Rand hart an, sondern verlaeuft. Innerhalb dieses
## Anteils der Halbbreite ist er voll hell, danach faellt er zum Rand hin ab.
const RAND_KERN := 0.62

## Ebenso in der Tiefe: bis hierhin volle Staerke, danach Abfall bis zur
## Reichweite. Ohne das haette der Kegel eine sichtbare Abbruchkante.
const TIEFE_KERN := 0.55

## Ganz nah an der Spitze ist die Winkelrechnung bedeutungslos - jeder Punkt
## liegt dort im Kegel. Unterhalb dieses Abstands wird sie uebersprungen.
const NAHFELD := 4.0


## Wie stark ein Punkt beleuchtet wird: 0.0 heisst unbeleuchtet, 1.0 voll.
##
## `richtung` muss nicht normiert sein. `halbwinkel` ist der halbe
## Oeffnungswinkel in Bogenmass, `reichweite` die Laenge des Kegels.
## `rand_kern` und `tiefe_kern` sind ueberschreibbar, weil die Grabenabschnitte
## sie veraendern (truebes Wasser, Streulicht). Sie bleiben Parameter dieser
## einen Funktion, statt eine zweite Rechnung daneben zu stellen - Anzeige und
## Schaden duerfen nie auseinanderlaufen.
static func beleuchtung(spitze: Vector2, richtung: Vector2, halbwinkel: float,
        reichweite: float, punkt: Vector2,
        rand_kern := RAND_KERN, tiefe_kern := TIEFE_KERN) -> float:
    if reichweite <= 0.0 or halbwinkel <= 0.0:
        return 0.0

    var versatz := punkt - spitze
    var abstand := versatz.length()
    if abstand > reichweite:
        return 0.0
    if abstand < NAHFELD:
        return 1.0
    if richtung.length_squared() <= 0.0:
        return 0.0

    var abweichung := absf(angle_difference(richtung.angle(), versatz.angle()))
    if abweichung > halbwinkel:
        return 0.0

    var quer := 1.0 - abweichung / halbwinkel
    var laengs := abstand / reichweite

    var rand := smoothstep(0.0, maxf(0.001, 1.0 - rand_kern), quer)
    var tiefe := 1.0 - smoothstep(clampf(tiefe_kern, 0.0, 0.999), 1.0, laengs)
    return rand * tiefe


## Ob ein Punkt ueberhaupt getroffen wird. Bequemer Name fuer den haeufigsten
## Fall; die Schwelle haelt Streifschuesse am aeussersten Rand heraus.
static func getroffen(spitze: Vector2, richtung: Vector2, halbwinkel: float,
        reichweite: float, punkt: Vector2, schwelle := 0.02) -> bool:
    return beleuchtung(spitze, richtung, halbwinkel, reichweite, punkt) > schwelle


## Schaden je Sekunde auf einen Punkt.
static func schaden_je_sekunde(leistung: float, helligkeit: float) -> float:
    return leistung * helligkeit


## Schaden je Sekunde auf einen Raeuber - mit seiner Haut.
##
## Zwei Eigenschaften, und beide aendern das Zielen statt der Zahl:
##
##   * `panzer` zieht einen festen Betrag je Sekunde ab. Eine schwache Quelle
##     kommt damit gar nicht mehr durch - ein Wehrpolyp kratzt an einer
##     Schildkoralle, der Kegel nicht.
##   * `mindest_licht` verlangt eine Mindesthelligkeit. Wer am Rand des Kegels
##     mitlaeuft, nimmt keinen Schaden; das Tier muss in den Kern.
##   * `hoechst_licht` ist das Gegenstueck: darueber prallt der Strahl
##     groesstenteils ab. Ein Spiegler gehoert ins **Randlicht**, und das
##     kehrt den Griff um, den man sich bei allen anderen angewoehnt hat.
##
## Alles drei gehoert **hierher** und nicht in Spiel und Pruefer getrennt: was
## brennt, muss in beiden dieselbe Rechnung sein.
##
## `hoechst_licht <= 0.0` heisst "keine Obergrenze" - so bleibt der Wert fuer
## die acht Arten, die keine haben, aus der Rechnung heraus.
##
## **Ueber der Grenze bleibt ein Rest, und der ist keine Feigheit.** Der erste
## Entwurf gab dort null zurueck, also volle Unverwundbarkeit im Kern. Der
## Wellenpruefer hat das sofort erledigt: achtunddreissig gefallene Sitzungen
## und eine Wand genau bei Welle 55, dort wo der Spiegler auftritt. Vorher
## waren es null.
##
## Der Grund ist kein Zahlenwert, sondern ein Entwurfsfehler. Ein Daumen zielt
## auf die hellste Stelle - dorthin, wo die meisten Tiere stehen. Ein Tier,
## das ausgerechnet dort nichts abbekommt, laesst sich nicht mehr durch
## Zielen erledigen, sondern nur noch durch einen Trick, den niemand von
## selbst findet. Das ist keine Fertigkeit, das ist eine Wand.
##
## Mit einem Rest wird daraus ein Gefaelle: wer ihn im Kern haelt, toetet ihn
## langsam; wer lernt, ihn im Randlicht mitlaufen zu lassen, fuenfmal so
## schnell. Der Unterschied ist gross genug, dass man ihn merkt, und klein
## genug, dass niemand steckenbleibt.
const SPIEGEL_REST := 0.45


static func schaden_an(leistung: float, helligkeit: float, panzer: float,
        mindest_licht: float, hoechst_licht := 0.0) -> float:
    if helligkeit < mindest_licht:
        return 0.0
    var roh := maxf(0.0, schaden_je_sekunde(leistung, helligkeit) - panzer)
    if hoechst_licht > 0.0 and helligkeit > hoechst_licht:
        return roh * SPIEGEL_REST
    return roh


## Welche der beleuchteten Raeuber der Kegel tatsaechlich verbrennt.
##
## Gibt die Indizes der bis zu `ziele` **wirksamsten** Eintraege zurueck.
## Alles, was null Schaden naehme, bleibt draussen.
##
## **Es war einmal die Helligkeit, und das war ein Fehler.** Die Auswahl nahm
## die hellsten Tiere, den Schaden rechnete danach `schaden_an()` - und die
## gibt fuer eine Glutqualle unterhalb ihrer Mindesthelligkeit null zurueck.
## Eine Glutqualle im Randlicht belegte damit einen der wenigen Zielplaetze
## und nahm keinen Schaden: der Ausbau "ein Ziel mehr", der sich am
## deutlichsten anfuehlen soll, verpuffte an einem Tier, das gar nicht
## brennen konnte. Kein Test und kein Bild zeigt das; man merkt es nur als
## Spieler daran, dass der Kegel nichts tut.
##
## Wer auswaehlt, muss dieselbe Zahl kennen wie der, der Schaden macht.
## Deshalb bekommt diese Funktion jetzt die **Wirkung** je Tier und nicht
## seine Helligkeit - und mit `hoechst_licht` gaebe es sonst ohnehin keine
## Ordnung mehr: der Spiegler ist genau dann angreifbar, wenn er dunkel steht.
##
## **Warum es diese Grenze gibt.** Ohne sie nahm jedes Tier im Licht den vollen
## Schaden, und die Gesamtleistung des Kegels wuchs mit der Zahl der Gegner.
## Der Wellenpruefer hat das sichtbar gemacht: Welle 60 mit 254 Raeubern ging
## mit den Grundwerten ohne einen einzigen Durchbruch aus - grosse Wellen waren
## *leichter* als kleine. Die Schwierigkeitskurve lief rueckwaerts.
##
## Mit der Grenze wird ein Schwarm zu dem, was er sein soll: eine Bedrohung,
## die man nicht wegleuchten kann. Und das Leuchtorgan bekommt einen Ausbau,
## der sich anfuehlt - ein Ziel mehr ist spuerbar, mehr Reichweite kaum.
static func brennende(wirkungen: PackedFloat32Array, ziele: int) -> PackedInt32Array:
    var treffer := PackedInt32Array()
    if ziele <= 0:
        return treffer

    # Auswahlsortieren statt vollstaendiges Sortieren: `ziele` ist klein
    # (typisch 3 bis 6), die Liste kann Hunderte Eintraege haben.
    var vergeben := {}
    while treffer.size() < ziele:
        var beste := -1
        var hell := 0.0
        for i in wirkungen.size():
            if vergeben.has(i) or wirkungen[i] <= hell:
                continue
            hell = wirkungen[i]
            beste = i
        if beste < 0:
            break
        vergeben[beste] = true
        treffer.append(beste)
    return treffer


## Richtung vom Waechter zum Finger. Faellt auf `ersatz` zurueck, wenn der
## Finger genau auf der Spitze liegt - sonst zuckt der Kegel beim Antippen.
static func zielrichtung(spitze: Vector2, finger: Vector2,
        ersatz := Vector2.UP) -> Vector2:
    var versatz := finger - spitze
    if versatz.length_squared() < NAHFELD * NAHFELD:
        return ersatz
    return versatz.normalized()


## Dreht `von` um hoechstens `tempo * zeit` in Richtung `nach`.
##
## Der Kegel folgt dem Finger traege. Ohne diese Grenze koennte man ihn in
## einem Bildschritt quer ueber den Schlund reissen, und Zielen waere keine
## Faehigkeit mehr, sondern eine Formalitaet.
static func gedreht(von: Vector2, nach: Vector2, tempo: float,
        zeit: float) -> Vector2:
    if von.length_squared() <= 0.0:
        return nach
    if nach.length_squared() <= 0.0:
        return von
    var rest := angle_difference(von.angle(), nach.angle())
    var schritt := clampf(rest, -tempo * zeit, tempo * zeit)
    return von.rotated(schritt).normalized()


## Wie stark ein Schub die Sinkgeschwindigkeit hoechstens veraendern darf.
##
## Bei 1.0 stuende das Tier im Umkehrpunkt still, darueber stiege es wieder
## auf - und ein Raeuber, der rueckwaerts schwimmt, ist kein Entwurf, sondern
## ein Vorzeichenfehler.
const STOSS_DECKEL := 0.9


## Der Weg eines Raeubers zu einem Zeitpunkt.
##
## Raeuber sinken zur Brut und schlaengeln dabei seitlich. Drei Zusaetze
## veraendern, wie schwer sie im Kegel zu halten sind:
##
##   * `schlaengel` - seitliches Pendeln um die Eintrittsspur
##   * `drift`      - stetige Querbewegung; das Tier wandert durch das Bild
##   * `stoss`      - Sinken in Schueben statt gleichmaessig
##
## Alles drei bleibt eine **reine Funktion der Zeit**. Das ist keine Zierde:
## nur so kann der Wellenpruefer eine Welle vollstaendig durchrechnen, ohne
## die Szene zu bauen, und nur so sehen Spiel und Pruefer dasselbe Tier.
static func bahn(start: Vector2, ziel_y: float, tempo: float, schlaengel: float,
        takt: float, phase: float, zeit: float,
        drift := 0.0, stoss := 0.0) -> Vector2:
    var weg := tempo * zeit
    if stoss > 0.0:
        # Das Integral des Schubs, damit der Weg stetig bleibt. Der Mittelwert
        # der Geschwindigkeit aendert sich dadurch nicht - `laufzeit()` gilt
        # weiter.
        var s := minf(stoss, STOSS_DECKEL)
        weg += tempo * s * (sin(takt * zeit + phase) - sin(phase)) / maxf(0.001, takt)
    var y := minf(start.y + weg, ziel_y)

    var x := start.x + schlaengel * sin(takt * zeit + phase)
    if drift != 0.0:
        # Die Richtung steckt in der Phase - dieselbe Zahl, die schon das
        # Pendeln versetzt. Ein eigener Wuerfel dafuer waere eine zweite
        # Quelle fuer denselben Zufall.
        x += drift * zeit * (1.0 if cos(phase) >= 0.0 else -1.0)

    # Am Rand wird gespiegelt, nicht angehalten. Gekappt klebte ein driftendes
    # Tier an der Grabenwand - im Bild sah das nach einem Fehler aus, und im
    # Spiel war es einer: dort steht es dann still und ist trivial zu treffen.
    return Vector2(gespiegelt(x, RAND_ABSTAND), y)


## Wie weit der Weg vom Bildrand fernbleibt. Deckt den groessten Tierradius ab,
## damit kein Leib halb aus dem Bild ragt.
const RAND_ABSTAND := 28.0


## Spiegelt `x` in das Feld zurueck - so oft, wie noetig.
##
## Eigene Funktion, weil sie testbar sein muss: dass ein Weg im Bild bleibt,
## ist eine Zusicherung und keine Nebenwirkung.
static func gespiegelt(x: float, abstand: float) -> float:
    var halb := maxf(1.0, Graben.FELD.size.x * 0.5 - abstand)
    return pingpong(x + halb, halb * 2.0) - halb


## Wie lange ein Raeuber von `start_y` bis zur Brut braucht.
static func laufzeit(start_y: float, ziel_y: float, tempo: float) -> float:
    if tempo <= 0.0:
        return INF
    return maxf(0.0, (ziel_y - start_y) / tempo)
