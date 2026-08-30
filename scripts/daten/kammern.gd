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

## Hoechste Stufe jeder Kammer.
##
## Das war einmal dieselbe Zahl wie das Ende des Grabens - Welle 60, Stufe 20,
## fertig. Seit der Graben keinen Boden hat, sind es zwei verschiedene Dinge:
## `Ausbau.STUFEN_JE_ZYKLUS` sagt, wie schnell die Kolonie waechst, und hier
## steht, wo sie aufhoert.
##
## Warum ueberhaupt ein Ende, wenn der Graben keines hat? Weil Kosten
## geometrisch wachsen und eine ganze Zahl irgendwann ueberlaeuft. Bei 1.58 je
## Stufe steht die Zuchtkammer auf Stufe 80 bei rund 10^17 - noch bequem
## innerhalb eines 64-Bit-Werts, auf Stufe 100 nicht mehr. Der Deckel liegt
## also dort, wo die Zahlen noch stimmen.
##
## Was danach weitergeht, ist nicht die Zahl, sondern das Spiel:
## `Ausbau.stufe_soll()` bleibt hier stehen, die Wellen laufen weiter, und was
## sie unterscheidet, sind Abschnittsregeln und Mutationen - nicht mehr
## Leistung. Eine ausgebaute Kolonie hoert nicht auf zu spielen, sie hoert auf
## zu wachsen.
const HOECHSTSTUFE := 80

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

## Laenger als der Abstand zwischen zwei Besuchen darf kein Bau dauern.
##
## Hier stand einmal `172800.0` - zwei Tage, wie es der Plan fuer den
## Tiefenschacht vorsah. Das war die Zahl, an der der endlose Graben starb:
## von Stufe 24 an lagen alle fuenf Kammern am Deckel, eine volle Runde
## kostete zehn Tage Bauzeit, und der Kolonielauf meldete an Tag 79 vierund-
## zwanzig Stunden Leerlauf. Ein Aufbauspiel lebt von Wartezeit, aber nur von
## solcher, die zwischen zwei Besuchen vergeht. Wer dreimal am Tag
## hereinschaut und dreimal dasselbe halbfertige Bild sieht, kommt nicht
## wieder - deshalb ist der Deckel abgeleitet und nicht gewaehlt.
##
## Und deshalb liegt er *unter* dem Abstand, nicht genau darauf. Bei genau
## acht Stunden wurde ein Bau, der eine Sitzung lang lief, erst sieben Minuten
## nach dem naechsten Besuch fertig - der Spieler kam also jedes zweite Mal
## umsonst. Der Kolonielauf meldete dafuer acht bis sechzehn Stunden leere
## Sitzungen am Tag, bei voll laufender Kolonie.
const ZEIT_DECKEL := 0.9 * 86400.0 / float(Graben.SITZUNGEN_JE_TAG)

## Ab dieser Stufe wird aus Sekunden echte Wartezeit. Vorher deckelt
## `ZEIT_SANFT` die Bauzeit auf etwas, das man aussitzen kann.
const ZEIT_SANFT_BIS := 7
const ZEIT_SANFT := 90.0

const TABELLE: Array[Dictionary] = [
    {
        &"name": "Light Organ",
        &"zweck": "The cone burns hotter and holds more at once.",
        &"kosten": 26.0,
        &"wachstum": 1.49,
        &"zeit_faktor": 1.0,
    },
    {
        &"name": "Polyp Chamber",
        &"zweck": "Guard polyps hit harder and cost less.",
        &"kosten": 22.0,
        &"wachstum": 1.58,
        &"zeit_faktor": 0.8,
    },
    {
        &"name": "Brood Chamber",
        &"zweck": "More brood in the maw - more mistakes you survive.",
        &"kosten": 34.0,
        &"wachstum": 1.52,
        &"zeit_faktor": 1.15,
    },
    {
        &"name": "Filter Basin",
        &"zweck": "Nutrients per hour, even while you are away.",
        &"kosten": 18.0,
        &"wachstum": 1.50,
        &"zeit_faktor": 0.7,
    },
    {
        &"name": "Deep Shaft",
        &"zweck": "Digs deeper, opens the trench and raises the cap on every other chamber.",
        &"kosten": 44.0,
        &"wachstum": 1.55,
        &"zeit_faktor": 0.9,
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

## --- Filterbecken ---
##
## **Hier lag der Fehler, an dem der endlose Graben scheiterte.** Kammern
## kosten geometrisch - 1.49 bis 1.58 je Stufe -, das Filterbecken lieferte
## aber nur 1.26 je Stufe. Jede Stufe dauerte also rund ein Fuenftel laenger
## als die davor, und was sich fuenfzig Stufen lang um zwanzig Prozent
## verlaengert, ist keine Kurve mehr, sondern eine Wand: der Kolonielauf
## meldete zwischen Tag 40 und Tag 120 ganze sechs neue Kammerstufen.
##
## Jetzt ist das Einkommen nicht mehr gewaehlt, sondern **aus den Kosten
## abgeleitet**: ein Filterbecken auf Stufe n traegt `FILTER_ANTEIL` einer
## vollen Kammerrunde in `TAGE_JE_RUNDE` Tagen bei. Damit kann es gar nicht
## mehr auseinanderlaufen - egal, wie jemand spaeter an den Kostenzahlen
## dreht.

## Wie lange eine volle Runde dauern soll: alle fuenf Kammern eine Stufe
## hoeher. Das ist der Taktgeber der ganzen Kolonie. Die Bauzeit einer Runde
## liegt bei 4.55 * ZEIT_DECKEL, also rund 1.5 Tagen - der Naehrstoff soll
## knapp davor liegen, damit gebaut und nicht gewartet wird.
const TAGE_JE_RUNDE := 1.4

## Welchen Teil einer Runde das Filterbecken traegt. Der Rest kommt aus den
## Wellen (`Wellen.ertrag`). Die Kernschleife muss die groessere Haelfte
## bleiben - sonst ist das Spiel ein Bildschirm, den man zumacht.
const FILTER_ANTEIL := 0.38


## Was eine volle Runde kostet: jede Kammer einen Schritt von `stufe` aufwaerts.
static func rundenkosten(stufe: int) -> float:
    var summe := 0.0
    for i in TABELLE.size():
        var k := TABELLE[i]
        summe += float(k[&"kosten"]) * pow(float(k[&"wachstum"]), float(maxi(0, stufe)))
    return summe


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
    return FILTER_ANTEIL * rundenkosten(filterbecken - 1) / (TAGE_JE_RUNDE * 24.0)
