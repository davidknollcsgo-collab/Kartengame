## Aufbau einer Kammer: Wände, Befallsknoten, Sporenvorrat.
##
## Kammern werden aus einem Bauplan erzeugt statt einzeln gezeichnet.
## Hundertfünfzig Kammern von Hand zu setzen ist machbar, hundertfünfzig zu
## zeichnen nicht - und ein Bauplan lässt sich balancieren, ein Bild nicht.
##
## Der Aufbau ist **bestimmt durch die Kammernummer**, nicht zufällig: Kammer 7
## sieht bei jedem Spieler gleich aus. Das ist Voraussetzung dafür, dass man
## über eine Kammer sprechen und sie im Testlauf nachrechnen kann.
class_name KammerDaten
extends RefCounted

## Spielfeld in Weltkoordinaten. Der Werfer sitzt unten, die Knoten oben.
const FELD := Rect2(-320.0, -600.0, 640.0, 1010.0)

## Standort des Werfers.
const WERFER := Vector2(0.0, 372.0)

## Radius eines Befallsknotens.
const KNOTEN_R := 17.0

## Kleinster Abstand zwischen zwei Knoten, damit sie nicht verschmelzen.
const KNOTEN_ABSTAND := 52.0


class Bauplan extends RefCounted:
    var nummer := 1
    ## Zusätzliche Hindernisse, flach als Punktepaare.
    var hindernisse: PackedVector2Array = []
    var knoten: PackedVector2Array = []
    var sporen := 6
    var abpraller := 4


## Erzeugt den Bauplan für eine Kammer.
## Geprüfte Streuwerte je Kammer.
##
## Der erste Entwurf streute die Knoten frei. Die Lösbarkeitsprüfung fand
## darauf **sechs von dreißig Kammern unlösbar** und keinerlei
## Schwierigkeitskurve: Kammer 3 war mit einem Schuss geräumt, Kammer 6
## brauchte sieben.
##
## Diese Werte sind mit tools/kammersuche.gd ermittelt: für jede Kammer wurde
## so lange gestreut, bis ein gieriger Sucher sie mit der vorgesehenen Zahl
## übriger Sporen räumt. Ein Mensch denkt weiter voraus als der Sucher - was
## der schafft, schafft ein Spieler erst recht.
const STREUUNG: PackedInt32Array = [
    3, 0, 3, 0, 0, 0, 0, 0, 1, 1,
    0, 0, 0, 0, 2, 0, 4, 0, 0, 0,
    0, 3, 0, 3, 1, 0, 3, 0, 5, 2,
]


## Streuwert einer Kammer. Jenseits der geprüften Kammern ohne Versatz.
static func streuung(nummer: int) -> int:
    var i := maxi(nummer, 1) - 1
    return STREUUNG[i] if i < STREUUNG.size() else 0


## Erzeugt den Bauplan für eine Kammer.
##
## [param versatz] überschreibt den geprüften Streuwert; das braucht nur die
## Kammersuche, das Spiel selbst nie.
static func baue(nummer: int, versatz: int = -1) -> Bauplan:
    var b := Bauplan.new()
    b.nummer = maxi(nummer, 1)

    var streu := versatz if versatz >= 0 else streuung(b.nummer)
    var zufall := RandomNumberGenerator.new()
    # Aus Kammernummer und Streuwert abgeleitet: derselbe Aufbau für jeden
    # Spieler, aber suchbar.
    zufall.seed = hash("hypha-kammer-%d-%d" % [b.nummer, streu])

    var stufe := _stufe(b.nummer)
    b.knoten = _setze_knoten(zufall, stufe)
    b.hindernisse = _setze_hindernisse(zufall, stufe)
    # Sporen wachsen langsamer als die Knoten - so wird es fordernder.
    b.sporen = clampi(4 + int(ceil(float(b.knoten.size()) * 0.55)), 4, 11)
    b.abpraller = clampi(3 + stufe / 3, 3, 7)
    return b


## Schwierigkeitsstufe 0 bis 9, abgeleitet aus der Kammernummer.
static func _stufe(nummer: int) -> int:
    return clampi((nummer - 1) / 3, 0, 9)


## Verteilt Befallsknoten im oberen Bereich des Feldes.
##
## Bewusst nicht im unteren Drittel: Knoten direkt vor dem Werfer wären ohne
## jeden Abprall zu treffen und würden das Spiel um seinen Kern bringen.
static func _setze_knoten(zufall: RandomNumberGenerator, stufe: int) -> PackedVector2Array:
    var anzahl := 3 + stufe
    var oben := FELD.position.y + 70.0
    var unten := FELD.position.y + FELD.size.y * 0.58
    var links := FELD.position.x + 60.0
    var rechts := FELD.end.x - 60.0

    var punkte := PackedVector2Array()
    var versuche := 0
    while punkte.size() < anzahl and versuche < 400:
        versuche += 1
        var p := Vector2(zufall.randf_range(links, rechts),
            zufall.randf_range(oben, unten))
        var frei := true
        for vorhanden in punkte:
            if vorhanden.distance_to(p) < KNOTEN_ABSTAND:
                frei = false
                break
        if frei:
            punkte.append(p)
    return punkte


## Setzt schräge Hindernisse ins Feld.
##
## Schräg und nicht waagerecht: eine waagerechte Wand wirft die Spore einfach
## zurück, eine schräge lenkt sie um - und genau darum geht es.
static func _setze_hindernisse(zufall: RandomNumberGenerator, stufe: int) -> PackedVector2Array:
    var anzahl := clampi(stufe - 1, 0, 5)
    var w := PackedVector2Array()

    for i in anzahl:
        var mitte := Vector2(
            zufall.randf_range(FELD.position.x + 80.0, FELD.end.x - 80.0),
            zufall.randf_range(FELD.position.y + 180.0, FELD.position.y + FELD.size.y * 0.72))
        var laenge := zufall.randf_range(70.0, 150.0)
        # Winkel meiden, die fast waagerecht oder fast senkrecht liegen.
        var winkel := zufall.randf_range(0.35, PI - 0.35)
        if zufall.randf() < 0.5:
            winkel = -winkel
        var halb := Vector2(cos(winkel), sin(winkel)) * laenge * 0.5
        w.append(mitte - halb)
        w.append(mitte + halb)
    return w


## Alle Wände einer Kammer: Feldbegrenzung plus Hindernisse.
static func waende(b: Bauplan) -> PackedVector2Array:
    var w := Ballistik.rechteck(FELD)
    w.append_array(b.hindernisse)
    return w


## Biomasse für eine geschaffte Kammer.
##
## Wächst mit der Kammernummer und mit der Zahl der übrigen Sporen - wer
## sparsam löst, verdient mehr. Das belohnt gutes Spiel, ohne jemanden zu
## bestrafen, der einfach durchkommt.
static func ertrag(nummer: int, uebrige_sporen: int) -> float:
    var grund := 12.0 * pow(1.16, float(maxi(nummer, 1) - 1))
    return grund * (1.0 + 0.22 * float(maxi(uebrige_sporen, 0)))
