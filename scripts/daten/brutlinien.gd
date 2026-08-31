class_name Brutlinien
extends RefCounted

## Die Brutlinien: was man statt Helden zuechtet.
##
## Kingshot hat ein Heldenroster mit Kisten und Wahrscheinlichkeiten. Hier
## nicht. Man waehlt die Linie, Naehrstoff ist der Preis, das Ergebnis steht
## fest - **keine Kiste, keine Quote, kein Zufall.**
##
## Das ist nicht nur der ehrlichere Weg. Es umgeht auch die Lootbox-Auflagen
## mehrerer Maerkte vollstaendig: wo nichts gewuerfelt wird, gibt es nichts zu
## regulieren. Wer gezielt spart, bekommt genau das, wofuer er spart.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Linie {
    KEINE,       ## Vor der ersten Zucht
    STROMSINN,   ## Gegen die Stroemung
    NACHGLUT,    ## Das Licht klingt nach
    KALTBRAND,   ## Weniger Ziele, jedes haerter
    SALZBRAND,   ## Frisst den Panzer statt ihn zu ueberwinden
    TIEFENBLICK, ## Schmaler und weiter - man faengt sie weiter oben
    ZWIELICHT,   ## Nimmt den Schwellen ihre Schaerfe
}

## Was jede Linie kostet und was sie tut. Die Wirkungen sind bewusst
## *unterschiedlich in der Art*, nicht in der Hoehe: eine Linie, die nur mehr
## Schaden macht, waere kein Entwurf, sondern eine Zahl.
const TABELLE: Array[Dictionary] = [
    {
        &"name": "No Line",
        &"wirkung": "The guardian at base values.",
        &"kosten": 0,
        &"farbe": Color(0.62, 0.72, 0.78),
    },
    {
        &"name": "Currentsense",
        &"wirkung": "The cone turns faster and the current pulls weaker.",
        &"kosten": 900,
        &"farbe": Color(0.48, 0.86, 1.00),
    },
    {
        &"name": "Afterglow",
        &"wirkung": "Anything hit keeps burning briefly, even outside the light.",
        &"kosten": 2400,
        &"farbe": Color(1.00, 0.68, 0.42),
    },
    {
        &"name": "Coldburn",
        &"wirkung": "One target fewer, but each one hits far harder.",
        &"kosten": 6000,
        &"farbe": Color(0.78, 0.62, 1.00),
    },
    {
        &"name": "Saltburn",
        &"wirkung": "Eats through armour. Shells and plating count for much less.",
        &"kosten": 14000,
        &"farbe": Color(1.00, 0.84, 0.40),
    },
    {
        &"name": "Deepsight",
        &"wirkung": "A narrower cone that reaches much further. Catch them high.",
        &"kosten": 32000,
        &"farbe": Color(0.52, 0.98, 0.72),
    },
    {
        &"name": "Duskveil",
        &"wirkung": "Blunts every light threshold. The fringe burns what only the core could.",
        &"kosten": 70000,
        &"farbe": Color(0.68, 0.78, 0.96),
    },
]

## --- Stromsinn ---
const STROMSINN_DREHTEMPO := 1.35
const STROMSINN_STROMDAEMPFUNG := 0.55

## --- Nachglut ---
## Wie lange ein Treffer nachbrennt und mit welchem Anteil der Leistung.
const NACHGLUT_DAUER := 1.6
const NACHGLUT_ANTEIL := 0.30

## --- Kaltbrand ---
const KALTBRAND_ZIELE := -1
const KALTBRAND_LEISTUNG := 1.62

## --- Salzbrand ---
##
## **Die Antwort auf eine Klippe, nicht auf eine Zahl.** Panzer wird vom
## Schaden *abgezogen*, nicht mit ihm verrechnet - sinkt die Helligkeit, faellt
## `leistung * hell` irgendwann unter den Panzer, und dann ist der Schaden
## nicht klein, sondern null. Genau das passiert in Dunkelabschnitten mit
## Schildkorallen und der Panzerung-Mutation. Salzbrand nimmt der Klippe die
## Hoehe, statt die Leistung zu erhoehen.
const SALZBRAND_PANZERBRUCH := 0.62

## --- Tiefenblick ---
##
## Weiter und schmaler. Das ist der einzige Ausbau im Spiel, der die **Form**
## des Kegels aendert statt seiner Staerke: man faengt die Tiere weiter oben,
## hat dafuer weniger Breite und muss frueher entscheiden.
const TIEFENBLICK_REICHWEITE := 1.45
const TIEFENBLICK_WINKEL := 0.66

## --- Zwielicht ---
##
## Nimmt beiden Schwellen die Schaerfe: die Glutqualle brennt auch ausserhalb
## ihres Kerns, der Spiegler auch im Kern. Zwei Arten, die man vorher nur mit
## der richtigen Handbewegung erwischt hat, werden damit gewoehnlich - und
## das ist der Preis wert, den die Linie kostet.
const ZWIELICHT_NACHLASS := 0.55


static func zahl() -> int:
    return TABELLE.size()


static func linie(index: int) -> Dictionary:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)]


static func name_von(index: int) -> String:
    return linie(index)[&"name"]


static func wirkung(index: int) -> String:
    return linie(index)[&"wirkung"]


static func kosten(index: int) -> int:
    return linie(index)[&"kosten"]


static func farbe(index: int) -> Color:
    return linie(index)[&"farbe"]


static func drehtempo_faktor(index: int) -> float:
    return STROMSINN_DREHTEMPO if index == Linie.STROMSINN else 1.0


static func stroemung_faktor(index: int) -> float:
    return STROMSINN_STROMDAEMPFUNG if index == Linie.STROMSINN else 1.0


static func nachglut_dauer(index: int) -> float:
    return NACHGLUT_DAUER if index == Linie.NACHGLUT else 0.0


static func nachglut_anteil(index: int) -> float:
    return NACHGLUT_ANTEIL if index == Linie.NACHGLUT else 0.0


static func ziele_zusatz(index: int) -> int:
    return KALTBRAND_ZIELE if index == Linie.KALTBRAND else 0


static func leistung_faktor(index: int) -> float:
    return KALTBRAND_LEISTUNG if index == Linie.KALTBRAND else 1.0


## Wieviel vom Panzer eines Raeubers wegfaellt. 0.0 heisst: der volle Panzer.
static func panzerbruch(index: int) -> float:
    return SALZBRAND_PANZERBRUCH if index == Linie.SALZBRAND else 0.0


static func reichweite_faktor(index: int) -> float:
    return TIEFENBLICK_REICHWEITE if index == Linie.TIEFENBLICK else 1.0


static func winkel_faktor(index: int) -> float:
    return TIEFENBLICK_WINKEL if index == Linie.TIEFENBLICK else 1.0


## Um wieviel jede Lichtschwelle nachlaesst - die Mindesthelligkeit der
## Glutqualle nach unten, die Obergrenze des Spieglers nach oben.
static func schwellen_nachlass(index: int) -> float:
    return ZWIELICHT_NACHLASS if index == Linie.ZWIELICHT else 0.0


## In welcher Reihenfolge die Linien freigeschaltet werden. Eine Linie laesst
## sich erst zuechten, wenn die davor steht - sonst spart man auf die letzte
## und sieht die beiden anderen nie.
static func voraussetzung(index: int) -> int:
    return maxi(Linie.KEINE, index - 1)
