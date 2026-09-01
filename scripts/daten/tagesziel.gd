class_name Tagesziel
extends RefCounted

## Ein Grund, morgen wiederzukommen.
##
## Drei kleine Aufgaben je Tag, dazu ein Anwesenheitszaehler. Bewusst so
## gebaut, dass **nichts davon verfaellt, was man schon erreicht hat**: wer
## einen Tag auslaesst, verliert die Strecke nicht, sondern nur den Tag. Eine
## Strecke, die bei einem verpassten Tag auf null faellt, erzeugt Druck statt
## Gewohnheit - und Druck vertreibt genau die Spieler, die man halten will.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Ziel { WELLEN, RAEUBER, AUSBAU, KETTE }

const TABELLE: Array[Dictionary] = [
    {
        &"name": "Hold three waves",
        &"menge": 3,
        &"lohn": 120,
    },
    {
        &"name": "Burn sixty raiders",
        &"menge": 60,
        &"lohn": 150,
    },
    {
        &"name": "Upgrade one chamber",
        &"menge": 1,
        &"lohn": 200,
    },
    {
        # **Das einzige Ziel, das Koennen verlangt statt Ausdauer.** Die drei
        # anderen erfuellt man, indem man spielt; dieses erfuellt man, indem
        # man gut spielt. Genau deshalb steht es dabei: ein Tagespensum aus
        # lauter Anwesenheitshaken ist eine Pflicht, keines mit einer Probe
        # darin ist ein Angebot.
        &"name": "Hold a chain of twelve",
        &"menge": 12,
        &"lohn": 180,
    },
]

## Der Lohn waechst mit dem Fortschritt - ein Ziel, das an Tag 30 dasselbe
## abwirft wie an Tag 1, ist an Tag 30 keines mehr.
const LOHN_JE_WELLE := 0.06


static func zahl() -> int:
    return TABELLE.size()


static func name_von(index: int) -> String:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)][&"name"]


static func menge(index: int) -> int:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)][&"menge"]


static func lohn(index: int, hoechste_welle: int) -> int:
    var grund: int = TABELLE[clampi(index, 0, TABELLE.size() - 1)][&"lohn"]
    return int(round(grund * (1.0 + LOHN_JE_WELLE * maxi(0, hoechste_welle - 1))))


## Der heutige Tag als Zahl. Ortszeit, nicht UTC - der Spieler lebt in seiner
## Zeitzone, nicht in Greenwich.
static func heute() -> int:
    var t := Time.get_datetime_dict_from_system()
    return int(t["year"]) * 10000 + int(t["month"]) * 100 + int(t["day"])
