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
