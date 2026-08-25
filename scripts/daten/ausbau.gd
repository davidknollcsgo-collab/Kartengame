class_name Ausbau
extends RefCounted

## Der Koloniestand, den ein normaler Spieler bei Welle `n` hat.
##
## Das ist eine Entwurfsentscheidung, keine Messung: hier steht, wie stark der
## Waechter sein *soll*, wenn er dort ankommt. Die Kolonie (Leuchtorgan,
## Zuchtkammer) fuellt diese Kurve spaeter mit Gebaeudestufen aus - die Kurve
## selbst bleibt die Vorgabe, an der sich beides messen laesst.
##
## **Warum das vor den Wellen steht.** Erst wurde die Wellenstaerke blind
## hochgerechnet und hinterher geprueft. Ergebnis laut Wellenpruefer: 55 Wellen
## ohne einen einzigen Verlust, dann in Welle 56 sofortiger Totalverlust. Keine
## Kurve, eine Klippe. Seitdem wird die Wellenstaerke **aus** dieser Kurve
## abgeleitet (siehe `Wellen.staerke`), und die Schwierigkeit ist eine Zahl,
## die man einstellt, statt eine, die sich ergibt.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Leuchtorgan: Schaden je Sekunde. Bewusst flach - der Zuwachs soll aus der
## Zahl der Ziele kommen, nicht aus einer immer groesseren Zahl je Ziel.
const LEISTUNG_JE_WELLE := 0.055

## Leuchtorgan, zweite Bahn: gleichzeitig erfasste Ziele. Der spuerbarste
## Ausbau im Spiel - ein Ziel mehr aendert, wie sich ein Schwarm anfuehlt.
const WELLEN_JE_ZIEL := 12

const REICHWEITE_JE_WELLE := 0.006
const WINKEL_JE_WELLE := 0.005

## Zuchtkammer: wie viele Wehrpolypen der Spieler bis dahin gewohnt ist zu
## stellen. Nicht wie viele er *kann* - die Nischen sind schon ab Welle 1 alle
## da, aber die Naehrstoffe dafuer nicht.
const WELLEN_JE_POLYP := 8


static func leistung_faktor(nummer: int) -> float:
    return 1.0 + LEISTUNG_JE_WELLE * maxi(0, nummer - 1)


static func ziele(nummer: int) -> int:
    return Graben.ZIELE + maxi(0, nummer - 1) / WELLEN_JE_ZIEL


static func reichweite_faktor(nummer: int) -> float:
    return 1.0 + REICHWEITE_JE_WELLE * maxi(0, nummer - 1)


static func winkel_faktor(nummer: int) -> float:
    return 1.0 + WINKEL_JE_WELLE * maxi(0, nummer - 1)


static func polypen(nummer: int) -> int:
    return clampi(1 + maxi(0, nummer - 1) / WELLEN_JE_POLYP, 0, Graben.NISCHEN.size())


## Roher Schaden je Sekunde, den dieser Stand aufbringen kann, wenn alle Ziele
## belegt sind.
static func durchsatz(nummer: int) -> float:
    var kegel := Graben.LEISTUNG * leistung_faktor(nummer) * ziele(nummer)
    var polyp := Graben.POLYP_LEISTUNG * polypen(nummer)
    return kegel + polyp
