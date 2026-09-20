class_name Skins
extends RefCounted

## **Womit man sich schmueckt.**
##
## Je Held drei Gewaender. Eine Skin aendert **nur Farben** und niemals eine
## Zahl - kein Leben, kein Tempo, kein Schaden. Das ist keine Sparsamkeit,
## sondern die Bedingung dafuer, dass man sie frei waehlen kann: sobald eine
## Skin einen Kampfwert traegt, waehlt niemand mehr die, die ihm gefaellt,
## sondern die, die gewinnt. Deshalb steht hier auch keine einzige Zahl
## ausser den Freischaltschwellen - es gibt schlicht kein Feld, in das ein
## Vorteil hineinpasste.
##
## **Freigeschaltet wird an Taten, nicht an Sold** - dieselbe Regel wie bei
## den Helden, und aus demselben Grund: wer Abwechslung kaufen kann, kauft
## sie am ersten Tag und hat danach nichts mehr vor sich.
##
## **Und jede Skin muss sich von jedem Feind unterscheiden.** Daran haengt
## die ganze farbige Fassung: die Farbe des Helden traegt niemand sonst. Eine
## Skin in Lederbraun waere keine Zierde, sondern eine Tarnkappe - und wer
## sich im Gedraenge nicht findet, hat nichts davon, dass er gut aussieht.
## Darum liegen alle zwoelf im kalten Teil des Kreises: Braun, Gruen, Rot und
## Violett gehoeren den Feinden, und was ihnen gehoert, bleibt ihnen. Ein
## Waechter misst das, statt es zu behaupten.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Wie viele Gewaender je Held. Das erste ist von Anfang an da.
const JE_HELD := 3

## Sichtbar, also englisch. Vier Helden mal drei, in der Reihenfolge von
## `Helden.Held`.
const NAMEN: PackedStringArray = [
    "Retainer", "Hoarfrost", "Kingfisher",
    "Ranger", "Seafoam", "Deep Current",
    "Pikeman", "Glacier", "Steel Tide",
    "Smith", "Cold Iron", "Thunderhead",
]

const KOERPER: PackedColorArray = [
    Color(0.310, 0.655, 0.925), Color(0.800, 0.898, 0.957), Color(0.098, 0.400, 0.780),
    Color(0.239, 0.729, 0.729), Color(0.627, 0.925, 0.867), Color(0.055, 0.451, 0.510),
    Color(0.404, 0.573, 0.898), Color(0.741, 0.831, 0.906), Color(0.169, 0.333, 0.600),
    Color(0.365, 0.694, 0.839), Color(0.678, 0.729, 0.776), Color(0.200, 0.267, 0.400),
]

## Was er sonst noch traegt - Stahl, Helmzier, Parierstange. **Gerechnet und
## nicht getafelt:** zwoelf weitere Farben von Hand waeren zwoelf weitere
## Gelegenheiten, eine davon zu dunkel zu setzen, und ein Glanz, der dunkler
## ist als der Koerper, ist kein Glanz.
const GLANZ_ZIEL := Color(1.0, 1.0, 1.0)

## Woran sie haengen. Dieselbe Aufzaehlung wie bei den Helden - eine zweite
## Sorte von Taten waere eine zweite Wahrheit darueber, was zaehlt.
const BEDINGUNG: PackedInt32Array = [
    Helden.Tat.KEINE, Helden.Tat.ERSCHLAGEN, Helden.Tat.ZEIT,
    Helden.Tat.KEINE, Helden.Tat.ERSCHLAGEN, Helden.Tat.ZEIT,
    Helden.Tat.KEINE, Helden.Tat.ERSCHLAGEN, Helden.Tat.WARLORD,
    Helden.Tat.KEINE, Helden.Tat.ERSCHLAGEN, Helden.Tat.ZEIT,
]

const SCHWELLE: PackedFloat32Array = [
    0.0, 300.0, 300.0,
    0.0, 600.0, 420.0,
    0.0, 900.0, 1.0,
    0.0, 1200.0, 540.0,
]

const BEDINGUNG_TEXT: PackedStringArray = [
    "", "Fell three hundred in one run.", "Last five minutes.",
    "", "Fell six hundred in one run.", "Last seven minutes.",
    "", "Fell nine hundred in one run.", "Bring down the Warlord.",
    "", "Fell twelve hundred in one run.", "Last nine minutes.",
]


## Der laufende Platz in den Tafeln oben. Held und Nummer statt einer
## verschachtelten Tabelle: sieben Tafeln mit zwoelf Zeilen lassen sich
## lesen, vier Tabellen mit drei Zeilen nicht.
static func platz(held: int, nummer: int) -> int:
    return clampi(held, 0, Helden.NAMEN.size() - 1) * JE_HELD \
        + clampi(nummer, 0, JE_HELD - 1)


static func name_von(held: int, nummer: int) -> String:
    return NAMEN[platz(held, nummer)]


static func koerper(held: int, nummer: int) -> Color:
    return KOERPER[platz(held, nummer)]


## Der helle Ton derselben Skin: Klinge, Nasal, Parierstange.
static func glanz(held: int, nummer: int) -> Color:
    return koerper(held, nummer).lerp(GLANZ_ZIEL, 0.55)


static func bedingung_text(held: int, nummer: int) -> String:
    return BEDINGUNG_TEXT[platz(held, nummer)]


## Ist sie nach diesen Bestmarken frei? Gebaut wie `Helden.ist_frei` und mit
## denselben drei Taten - wer hier eine vierte einfuehrt, hat zwei
## Wahrheiten darueber, was ein Spieler geleistet hat.
static func ist_frei(held: int, nummer: int, beste_zeit: float, meiste: int,
        warlord: bool) -> bool:
    var i := platz(held, nummer)
    match BEDINGUNG[i]:
        Helden.Tat.ZEIT:
            return beste_zeit >= SCHWELLE[i]
        Helden.Tat.ERSCHLAGEN:
            return float(meiste) >= SCHWELLE[i]
        Helden.Tat.WARLORD:
            return warlord
        _:
            return true
