class_name Kammern
extends RefCounted

## Die Kammern der Kolonie: was sie kosten, wie lange sie bauen, was sie tun.
##
## **Das Verhaeltnis zu `ausbau.gd` ist der Kern dieser Datei.** Dort steht die
## Sollkurve - wie stark der Waechter bei Welle n *sein soll*. Hier steht, wie
## er dorthin kommt. Beide muessen zusammenpassen, sonst prueft der
## Wellenpruefer ein Spiel, das niemand spielen kann. Ein Test vergleicht sie
## Stufe fuer Stufe.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Kammer {
    LEUCHTORGAN,    ## Der Lichtkegel: Schaden und Zahl der Ziele
    ZUCHTKAMMER,    ## Wehrpolypen: staerker und billiger
    BRUTKAMMER,     ## Mehr Brut, also mehr Fehler erlaubt
    FILTERBECKEN,   ## Naehrstoffe je Stunde, auch waehrend man weg ist
    TIEFENSCHACHT,  ## Deckelt alle anderen Kammern
}

## Hoechste Stufe jeder Kammer. Deckt zugleich den Inhalt von Stufe 1 ab: mehr
## gibt es erst, wenn es mehr Wellen gibt.
const HOECHSTSTUFE := 20

## Der Tiefenschacht deckelt die uebrigen Kammern. Ohne diesen Deckel liesse
## sich das Leuchtorgan allein hochziehen und alles andere ignorieren - eine
## Kolonie mit einem einzigen sinnvollen Knopf.
##
## Bei Vorsprung 2 war er allerdings nicht mehr Gestalter, sondern
## Flaschenhals: der Kolonielauf zeigte das Leuchtorgan an dreissig von
## dreissig Tagen am Deckel klebend, waehrend Naehrstoff ungenutzt lag. Vier
## Stufen lassen Spielraum, ohne die Kammer bedeutungslos zu machen.
const SCHACHT_VORSPRUNG := 4

## --- Bauzeiten ---
##
## Die erste Woche fast ohne echte Wartezeit. Bauzeiten sind der Grund, warum
## ein Aufbauspiel monetarisiert - und der Grund, warum Spieler aufhoeren. Wer
## in den ersten Stunden auf eine Uhr starrt, kommt nicht wieder.
const ZEIT_GRUND := 16.0

## Bei 1.92 stand ein Bau auf Stufe 12 schon bei rund zwanzig Stunden, und der
## Kolonielauf meldete eine Wartemauer von acht Stunden am Tag - die Stelle,
## an der Spieler aufhoeren. 1.56 haelt die spaeten Stufen bedeutsam, ohne den
## Tag zu blockieren.
const ZEIT_WACHSTUM := 1.50
const ZEIT_DECKEL := 172800.0   ## zwei Tage

## Ab dieser Stufe wird aus Sekunden echte Wartezeit. Vorher deckelt
## `ZEIT_SANFT` die Bauzeit auf etwas, das man aussitzen kann.
const ZEIT_SANFT_BIS := 7
const ZEIT_SANFT := 90.0

const TABELLE: Array[Dictionary] = [
    {
        &"name": "Leuchtorgan",
        &"zweck": "Der Kegel brennt heisser und fasst mehr auf einmal.",
        &"kosten": 26.0,
        &"wachstum": 1.49,
        &"zeit_faktor": 1.0,
    },
    {
        &"name": "Zuchtkammer",
        &"zweck": "Wehrpolypen schlagen haerter und kosten weniger.",
        &"kosten": 22.0,
        &"wachstum": 1.58,
        &"zeit_faktor": 0.8,
    },
    {
        &"name": "Brutkammer",
        &"zweck": "Mehr Brut im Schlund - mehr Fehler, die man ueberlebt.",
        &"kosten": 34.0,
        &"wachstum": 1.52,
        &"zeit_faktor": 1.15,
    },
    {
        &"name": "Filterbecken",
        &"zweck": "Naehrstoff je Stunde, auch waehrend du weg bist.",
        &"kosten": 18.0,
        &"wachstum": 1.50,
        &"zeit_faktor": 0.7,
    },
    {
        &"name": "Tiefenschacht",
        &"zweck": "Graebt tiefer und hebt den Deckel aller anderen Kammern.",
        &"kosten": 44.0,
        &"wachstum": 1.55,
        &"zeit_faktor": 1.25,
    },
]


static func zahl() -> int:
    return TABELLE.size()


static func kammer(index: int) -> Dictionary:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)]


static func name_von(index: int) -> String:
    return kammer(index)[&"name"]


static func zweck(index: int) -> String:
    return kammer(index)[&"zweck"]


## Was der Schritt von `stufe` auf `stufe + 1` kostet.
static func kosten(index: int, stufe: int) -> int:
    var k := kammer(index)
    return int(round(k[&"kosten"] * pow(k[&"wachstum"], maxi(0, stufe))))


## Wie lange dieser Schritt baut, in Sekunden.
static func bauzeit(index: int, stufe: int) -> float:
    var roh := ZEIT_GRUND * pow(ZEIT_WACHSTUM, maxi(0, stufe)) \
        * float(kammer(index)[&"zeit_faktor"])
    # Der Sanftdeckel greift **nach** dem Kammerfaktor. Andersherum kam die
    # Brutkammer mit ihrem Faktor 1.15 auf 103 s und riss die Zusage fuer die
    # erste Woche - der Test hat es sofort gemeldet.
    if stufe < ZEIT_SANFT_BIS:
        roh = minf(roh, ZEIT_SANFT)
    return minf(roh, ZEIT_DECKEL)


## Hoechste Stufe, die `index` beim gegebenen Schachtstand annehmen darf.
static func deckel(index: int, schacht: int) -> int:
    if index == Kammer.TIEFENSCHACHT:
        return HOECHSTSTUFE
    return clampi(schacht + SCHACHT_VORSPRUNG, 1, HOECHSTSTUFE)


static func ausbaubar(index: int, stufe: int, schacht: int) -> bool:
    return stufe < deckel(index, schacht)


# --- Wirkung der Stufen ----------------------------------------------------
#
# Die Steigungen sind so gewaehlt, dass die Sollkurve aus `ausbau.gd` bei
# voller Stufe genau erreicht wird. Wer hier dreht, muss dort mitdrehen -
# `_test_kammern_treffen_die_sollkurve` faengt das Auseinanderlaufen.

## Leuchtorgan, erste Bahn: Schaden je Sekunde.
const LEISTUNG_JE_STUFE := 0.16225

## Leuchtorgan, zweite Bahn: gleichzeitig gefasste Ziele. Der spuerbarste
## Ausbau im Spiel - ein Ziel mehr aendert, wie sich ein Schwarm anfuehlt.
const STUFEN_JE_ZIEL := 5

const REICHWEITE_JE_STUFE := 0.0177
const WINKEL_JE_STUFE := 0.01475

## Zuchtkammer.
const POLYP_JE_STUFE := 0.14
const POLYP_RABATT_JE_STUFE := 0.035
const POLYP_RABATT_DECKEL := 0.55

## Brutkammer: ein Ei alle zwei Stufen.
const STUFEN_JE_EI := 2

## Filterbecken.
const FILTER_GRUND := 7.0
const FILTER_WACHSTUM := 1.26


static func leistung_faktor(leuchtorgan: int) -> float:
    return 1.0 + LEISTUNG_JE_STUFE * maxi(0, leuchtorgan)


static func ziele(leuchtorgan: int) -> int:
    return Graben.ZIELE + maxi(0, leuchtorgan) / STUFEN_JE_ZIEL


static func reichweite_faktor(leuchtorgan: int) -> float:
    return 1.0 + REICHWEITE_JE_STUFE * maxi(0, leuchtorgan)


static func winkel_faktor(leuchtorgan: int) -> float:
    return 1.0 + WINKEL_JE_STUFE * maxi(0, leuchtorgan)


static func polyp_leistung(zuchtkammer: int) -> float:
    return Graben.POLYP_LEISTUNG * (1.0 + POLYP_JE_STUFE * maxi(0, zuchtkammer))


## Wehrpolypen werden mit der Zuchtkammer billiger - aber nie geschenkt.
static func polyp_kosten(zuchtkammer: int, gebaut: int) -> int:
    var rabatt := minf(POLYP_RABATT_DECKEL, POLYP_RABATT_JE_STUFE * maxi(0, zuchtkammer))
    return maxi(1, int(round(Graben.polyp_kosten(gebaut) * (1.0 - rabatt))))


static func brut_leben(brutkammer: int) -> int:
    return Graben.BRUT_LEBEN + maxi(0, brutkammer) / STUFEN_JE_EI


## Naehrstoff je Stunde. Stufe 0 liefert nichts - das Filterbecken muss erst
## gebaut werden, sonst gaebe es Einkommen fuer eine Kammer, die es nicht gibt.
static func filter_je_stunde(filterbecken: int) -> float:
    if filterbecken <= 0:
        return 0.0
    return FILTER_GRUND * pow(FILTER_WACHSTUM, filterbecken - 1)
