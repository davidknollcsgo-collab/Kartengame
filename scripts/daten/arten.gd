class_name Arten
extends RefCounted

## Die Raeuber des Grabens.
##
## Erfundene Tiere, keine Vorlage. Die Namen sind deutsche Wortbildungen nach
## dem Muster echter Tiefseefauna - Aussehen und Werte stammen aus diesem
## Projekt. Gezeichnet wird jede Art im Code, es gibt keine Bilddateien.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Art {
    ZAHNKIEFER,   ## Grundgegner. Sinkt gerade, stirbt schnell.
    SCHLEIER,     ## Schwarmtier. Sehr schnell, fast kein Leben.
    PANZERKREBS,  ## Traeger Brocken. Zwingt zum Verweilen im Ziel.
    GRABNATTER,   ## Schlaengelt breit - schwer im Kegel zu halten.
}

## Reihenfolge entspricht `Art`. Auf einen Wert je Feld verzichtet, weil eine
## Tabelle die Balance an einer Stelle sichtbar macht.
const TABELLE: Array[Dictionary] = [
    {
        &"name": "Zahnkiefer",
        &"leben": 22.0,
        &"tempo": 92.0,
        &"radius": 17.0,
        &"wert": 3,
        &"wucht": 1,
        &"schlaengel": 14.0,
        &"takt": 1.7,
        &"farbe": Color(0.62, 0.86, 0.95),
        &"ab_welle": 1,
    },
    {
        &"name": "Schleier",
        &"leben": 8.0,
        &"tempo": 168.0,
        &"radius": 12.0,
        &"wert": 2,
        &"wucht": 1,
        &"schlaengel": 26.0,
        &"takt": 3.1,
        &"farbe": Color(0.72, 0.62, 0.98),
        &"ab_welle": 3,
    },
    {
        &"name": "Panzerkrebs",
        &"leben": 74.0,
        &"tempo": 54.0,
        &"radius": 25.0,
        &"wert": 8,
        &"wucht": 3,
        &"schlaengel": 6.0,
        &"takt": 0.9,
        &"farbe": Color(0.98, 0.68, 0.42),
        &"ab_welle": 6,
    },
    {
        &"name": "Grabnatter",
        &"leben": 34.0,
        &"tempo": 104.0,
        &"radius": 15.0,
        &"wert": 5,
        &"wucht": 2,
        &"schlaengel": 82.0,
        &"takt": 2.2,
        &"farbe": Color(0.55, 0.98, 0.72),
        &"ab_welle": 10,
    },
]


static func zahl() -> int:
    return TABELLE.size()


static func art(index: int) -> Dictionary:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)]


static func leben(index: int) -> float:
    return art(index)[&"leben"]


static func tempo(index: int) -> float:
    return art(index)[&"tempo"]


static func radius(index: int) -> float:
    return art(index)[&"radius"]


static func wert(index: int) -> int:
    return art(index)[&"wert"]


static func wucht(index: int) -> int:
    return art(index)[&"wucht"]


static func farbe(index: int) -> Color:
    return art(index)[&"farbe"]


static func name_von(index: int) -> String:
    return art(index)[&"name"]


## Welche Arten in Welle `nummer` ueberhaupt auftreten duerfen.
static func verfuegbar(nummer: int) -> PackedInt32Array:
    var liste := PackedInt32Array()
    for i in TABELLE.size():
        if nummer >= int(TABELLE[i][&"ab_welle"]):
            liste.append(i)
    return liste
