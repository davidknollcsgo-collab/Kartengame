class_name Helden
extends RefCounted

## **Wen man in die Schlacht schickt.**
##
## Vier Klassen, und jede hat **genau eine** Eigenart neben ihrer Startwaffe.
## Das ist keine Sparsamkeit, sondern die Bedingung dafuer, dass eine Klasse
## etwas bedeutet: was einen Helden ausmacht, muss man in der ersten Minute
## merken. Ein Held mit fuenf kleinen Vorteilen fuehlt sich an wie der
## Grundheld mit Rauschen.
##
## **Freigeschaltet wird an Taten, nicht an Sold.** Wer Abwechslung kaufen
## kann, kauft sie am ersten Tag und hat danach nichts mehr vor sich.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Held { SCHWERT, BOGEN, SPEER, HAMMER }

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = ["Swordsman", "Archer", "Spearman", "Hammerman"]

const LEHREN: PackedStringArray = [
    "Stands where others fall. Begins with the arming sword.",
    "Strikes from further than they can reach. Begins with the crossbow.",
    "Outpaces the press. Begins with the boar spear.",
    "Slow, and it does not matter. Begins with the war hammer.",
]

## Womit er anfaengt. **Eine** Waffe - ohne eine schlaegt man die erste halbe
## Minute gar nichts, mit zweien hat der erste Aufstieg nichts mehr zu sagen.
const STARTWAFFE: PackedInt32Array = [
    Waffen.Art.SCHWERT, Waffen.Art.ARMBRUST, Waffen.Art.SPEER, Waffen.Art.HAMMER,
]

## Die Eigenart, als vier Faktoren - aber je Held ist hoechstens einer davon
## ungleich eins (der Hammertraeger zahlt seinen Schaden mit Tempo, und das
## ist der einzige Handel im Satz).
const LEBEN_FAKTOR: PackedFloat32Array = [1.25, 1.00, 1.00, 1.00]
const WEITE_FAKTOR: PackedFloat32Array = [1.00, 1.30, 1.00, 1.00]
const TEMPO_FAKTOR: PackedFloat32Array = [1.00, 1.00, 1.12, 0.92]
const SCHADEN_FAKTOR: PackedFloat32Array = [1.00, 1.00, 1.00, 1.20]

## Was er tun muss, damit er frei wird. Der erste ist von Anfang an da.
enum Tat { KEINE, ZEIT, ERSCHLAGEN, WARLORD }

const BEDINGUNG: PackedInt32Array = [Tat.KEINE, Tat.ZEIT, Tat.ERSCHLAGEN, Tat.WARLORD]
const SCHWELLE: PackedFloat32Array = [0.0, 240.0, 100.0, 1.0]

const BEDINGUNG_TEXT: PackedStringArray = [
    "",
    "Survive four minutes.",
    "Fell a hundred in one run.",
    "Bring down the Warlord.",
]


static func name_von(h: int) -> String:
    return NAMEN[clampi(h, 0, NAMEN.size() - 1)]


static func lehre_von(h: int) -> String:
    return LEHREN[clampi(h, 0, LEHREN.size() - 1)]


static func startwaffe(h: int) -> int:
    return STARTWAFFE[clampi(h, 0, STARTWAFFE.size() - 1)]


static func leben_faktor(h: int) -> float:
    return LEBEN_FAKTOR[clampi(h, 0, LEBEN_FAKTOR.size() - 1)]


static func weite_faktor(h: int) -> float:
    return WEITE_FAKTOR[clampi(h, 0, WEITE_FAKTOR.size() - 1)]


static func tempo_faktor(h: int) -> float:
    return TEMPO_FAKTOR[clampi(h, 0, TEMPO_FAKTOR.size() - 1)]


static func schaden_faktor(h: int) -> float:
    return SCHADEN_FAKTOR[clampi(h, 0, SCHADEN_FAKTOR.size() - 1)]


static func bedingung_text(h: int) -> String:
    return BEDINGUNG_TEXT[clampi(h, 0, BEDINGUNG_TEXT.size() - 1)]


## Ist er nach diesen Bestmarken frei?
static func ist_frei(h: int, beste_zeit: float, meiste: int,
        warlord: bool) -> bool:
    var i := clampi(h, 0, BEDINGUNG.size() - 1)
    match BEDINGUNG[i]:
        Tat.ZEIT:
            return beste_zeit >= SCHWELLE[i]
        Tat.ERSCHLAGEN:
            return float(meiste) >= SCHWELLE[i]
        Tat.WARLORD:
            return warlord
        _:
            return true
