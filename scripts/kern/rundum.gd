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
## **Der Radius kommt aus der Breite, nicht aus der Hoehe.** Der erste Anlauf
## stand auf 470, und das Feld war damit breiter als das Bild: `Graben.FELD`
## reicht von -360 bis 360, das Boot konnte also seitlich hinausfahren. Die
## Breite liegt bei `aspect="expand"` auf jedem Geraet fest, die Hoehe nicht -
## wer aus der Hoehe ableitet, gibt Spielern mit langem Telefon mehr Feld.
## Was auf einem hohen Bild uebrig bleibt, ist Hintergrund und kein Spielraum.
const FELD_RADIUS := 330.0

## Wo Raeuber eintreten: ausserhalb des Feldes, aber nicht so weit, dass der
## Anmarsch zur Wartezeit wird. Dieselbe Ueberlegung wie bei
## `Graben.EINTRITT_Y` - was aus dem Nichts erscheint, sieht nach einem
## Fehler aus.
const EINTRITT_RADIUS := 470.0

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


## Der Punkt auf dem Eintrittsring zu einem Winkel.
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
static func schritt(ort: Vector2, ziel: Vector2, tempo: float,
        schlaengel: float, takt: float, phase: float, zeit: float,
        delta: float, drift := 0.0) -> Vector2:
    var zum_ziel := ziel - ort
    var weite := zum_ziel.length()
    if weite < 0.001:
        return ort
    var k := zum_ziel / weite
    var quer := k.orthogonal()
    var seitlich := schlaengel * sin(takt * zeit + phase)
    if drift != 0.0:
        # Die Richtung steckt in der Phase - dieselbe Zahl wie beim Pendeln,
        # so wie in `Schlund.bahn()` auch. Ein eigener Wuerfel dafuer waere
        # eine zweite Quelle fuer denselben Zufall.
        seitlich += drift * zeit * (1.0 if cos(phase) >= 0.0 else -1.0)
    var gelenkt := (ziel + quer * seitlich) - ort
    if gelenkt.length_squared() < 0.000001:
        return ort
    return ort + gelenkt.normalized() * tempo * delta


## Wo der `index`-te von `anzahl` Begleitern stehen soll.
##
## Ein Faecher **hinter** dem Boot, nicht darum herum. Vor dem Boot staenden
## sie im Kegel und verdeckten genau das, worauf man zielt; ringsherum waere
## keine Formation, sondern ein Kranz, und man saehe nicht mehr, wohin man
## faehrt.
const FAECHER := 0.62


static func begleiter_ziel(index: int, anzahl: int, fuehrer: Vector2,
        blick: Vector2, abstand: float) -> Vector2:
    if blick.length_squared() < 0.000001:
        blick = Vector2.UP
    var t := 0.5
    if anzahl > 1:
        t = float(index) / float(anzahl - 1)
    var w := lerpf(-FAECHER, FAECHER, t)
    return fuehrer - blick.normalized().rotated(w) * abstand


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
