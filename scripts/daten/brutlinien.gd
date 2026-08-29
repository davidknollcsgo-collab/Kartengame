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
}

## Was jede Linie kostet und was sie tut. Die Wirkungen sind bewusst
## *unterschiedlich in der Art*, nicht in der Hoehe: eine Linie, die nur mehr
## Schaden macht, waere kein Entwurf, sondern eine Zahl.
const TABELLE: Array[Dictionary] = [
    {
        &"name": "Ohne Linie",
        &"wirkung": "Die Grundwerte des Waechters.",
        &"kosten": 0,
        &"farbe": Color(0.62, 0.72, 0.78),
    },
    {
        &"name": "Stromsinn",
        &"wirkung": "Der Kegel dreht schneller und die Stroemung zerrt schwaecher.",
        &"kosten": 900,
        &"farbe": Color(0.48, 0.86, 1.00),
    },
    {
        &"name": "Nachglut",
        &"wirkung": "Getroffene brennen kurz weiter, auch ausserhalb des Lichts.",
        &"kosten": 2400,
        &"farbe": Color(1.00, 0.68, 0.42),
    },
    {
        &"name": "Kaltbrand",
        &"wirkung": "Ein Ziel weniger, dafuer trifft jedes deutlich haerter.",
        &"kosten": 6000,
        &"farbe": Color(0.78, 0.62, 1.00),
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


## In welcher Reihenfolge die Linien freigeschaltet werden. Eine Linie laesst
## sich erst zuechten, wenn die davor steht - sonst spart man auf die letzte
## und sieht die beiden anderen nie.
static func voraussetzung(index: int) -> int:
    return maxi(Linie.KEINE, index - 1)
