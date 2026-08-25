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
static func beleuchtung(spitze: Vector2, richtung: Vector2, halbwinkel: float,
        reichweite: float, punkt: Vector2) -> float:
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

    var rand := smoothstep(0.0, 1.0 - RAND_KERN, quer)
    var tiefe := 1.0 - smoothstep(TIEFE_KERN, 1.0, laengs)
    return rand * tiefe


## Ob ein Punkt ueberhaupt getroffen wird. Bequemer Name fuer den haeufigsten
## Fall; die Schwelle haelt Streifschuesse am aeussersten Rand heraus.
static func getroffen(spitze: Vector2, richtung: Vector2, halbwinkel: float,
        reichweite: float, punkt: Vector2, schwelle := 0.02) -> bool:
    return beleuchtung(spitze, richtung, halbwinkel, reichweite, punkt) > schwelle


## Schaden je Sekunde auf einen Punkt.
static func schaden_je_sekunde(leistung: float, helligkeit: float) -> float:
    return leistung * helligkeit


## Welche der beleuchteten Raeuber der Kegel tatsaechlich verbrennt.
##
## Gibt die Indizes der bis zu `ziele` hellsten Eintraege zurueck, absteigend
## nach Helligkeit. Unbeleuchtetes (0.0) bleibt immer draussen.
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
static func brennende(helligkeiten: PackedFloat32Array, ziele: int) -> PackedInt32Array:
    var treffer := PackedInt32Array()
    if ziele <= 0:
        return treffer

    # Auswahlsortieren statt vollstaendiges Sortieren: `ziele` ist klein
    # (typisch 3 bis 6), die Liste kann Hunderte Eintraege haben.
    var vergeben := {}
    while treffer.size() < ziele:
        var beste := -1
        var hell := 0.0
        for i in helligkeiten.size():
            if vergeben.has(i) or helligkeiten[i] <= hell:
                continue
            hell = helligkeiten[i]
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


## Der Weg eines Raeubers zu einem Zeitpunkt.
##
## Raeuber sinken geradlinig zur Brut und schlaengeln dabei seitlich. Reine
## Funktion der Zeit - deshalb kann der Wellenpruefer eine Welle vollstaendig
## durchrechnen, ohne die Szene zu bauen.
static func bahn(start: Vector2, ziel_y: float, tempo: float, schlaengel: float,
        takt: float, phase: float, zeit: float) -> Vector2:
    var y := minf(start.y + tempo * zeit, ziel_y)
    var x := start.x + schlaengel * sin(takt * zeit + phase)
    return Vector2(x, y)


## Wie lange ein Raeuber von `start_y` bis zur Brut braucht.
static func laufzeit(start_y: float, ziel_y: float, tempo: float) -> float:
    if tempo <= 0.0:
        return INF
    return maxf(0.0, (ziel_y - start_y) / tempo)
