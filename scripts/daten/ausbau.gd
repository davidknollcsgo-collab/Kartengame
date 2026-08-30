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

## Zuchtkammer: wie viele Wehrpolypen der Spieler bis dahin gewohnt ist zu
## stellen. Nicht wie viele er *kann* - die Nischen sind schon ab Welle 1 alle
## da, aber die Naehrstoffe dafuer nicht.
const WELLEN_JE_POLYP := 8


# --- Der Waechter auf der Sollstufe ---------------------------------------
#
# Es gibt hier genau **eine** Entwurfsentscheidung, und das ist `stufe_soll()`.
# Alles andere ist der Koloniestand *auf* dieser Stufe, gerechnet mit
# denselben Funktionen, die auch der Spieler benutzt.
#
# Frueher stand hier eine zweite, eigene Kurve mit eigenen Steigungen. Die traf
# das Ende genau und lief in der Mitte auseinander: bei Welle 49 verlangte sie
# sieben gleichzeitige Ziele, waehrend die zugehoerige Sollstufe 16 nur sechs
# hergab. Zwoelf Wellen lang rechnete der Wellenpruefer damit einen Waechter
# durch, den es auf keiner Kammerstufe gab - und der Kolonielauf meldete
# genau dort gefallene Sitzungen. Zwei Kurven, die dasselbe beschreiben
# sollen, laufen immer irgendwann auseinander; also gibt es nur noch eine.

static func leistung_faktor(nummer: int) -> float:
    return Kammern.leistung_faktor(stufe_soll(nummer))


static func ziele(nummer: int) -> int:
    return Kammern.ziele(stufe_soll(nummer))


static func reichweite_faktor(nummer: int) -> float:
    return Kammern.reichweite_faktor(stufe_soll(nummer))


static func winkel_faktor(nummer: int) -> float:
    return Kammern.winkel_faktor(stufe_soll(nummer))


static func polypen(nummer: int) -> int:
    return clampi(1 + maxi(0, nummer - 1) / WELLEN_JE_POLYP, 0, Graben.NISCHEN.size())


## Roher Schaden je Sekunde, den dieser Stand aufbringen kann, wenn alle Ziele
## belegt sind.
static func durchsatz(nummer: int) -> float:
    var kegel := Graben.LEISTUNG * leistung_faktor(nummer) * ziele(nummer)
    var polyp := Graben.POLYP_LEISTUNG * polypen(nummer)
    return kegel + polyp


## Welche Kammerstufe die Sollkurve bei Welle `nummer` erwartet.
##
## Bindeglied zwischen dieser Kurve und `kammern.gd`: dort steht die Wirkung
## je Stufe, hier steht, welche Stufe zu welcher Welle gehoert. Die Steigungen
## in `kammern.gd` sind so gewaehlt, dass beide Seiten bei voller Stufe genau
## denselben Wert liefern - `_test_kammern_treffen_die_sollkurve` prueft das
## ueber die ganze Strecke.
## Wie viele Kammerstufen eine volle Umdrehung durch den Graben verlangt.
##
## **Das ist die einzige Entwurfszahl des ganzen Fortschritts.** Sie war
## frueher `Kammern.HOECHSTSTUFE`, weil Welle 60 zugleich das Ende war. Seit
## der Graben keinen Boden mehr hat, sind das zwei verschiedene Dinge: hier
## steht das Tempo, dort die oberste Stufe, die es ueberhaupt gibt.
const STUFEN_JE_ZYKLUS := 20


## Die Kurve endet, wo die Kammern enden. Ohne diesen Deckel verlangte sie ab
## Welle 241 eine Stufe 81, die es auf keiner Kammer gibt - und der
## Wellenpruefer haette wieder einen Waechter durchgerechnet, den niemand
## bauen kann. Der Graben laeuft trotzdem weiter; was ihn ab dort
## unterscheidet, sind Abschnittsregeln und Mutationen, nicht mehr Leistung.
## Dieselbe Kurve ohne Rundung. Wer eine Welle *stetig* mitwachsen lassen
## will - die Zaehigkeit der Raeuber etwa -, braucht sie ungerundet, sonst
## springt sie alle drei Wellen und steht dazwischen still.
static func stufe_kurve(nummer: int) -> float:
    var t := float(maxi(1, nummer) - 1) / float(Graben.ZYKLUS - 1)
    return minf(float(Kammern.HOECHSTSTUFE), t * float(STUFEN_JE_ZYKLUS))


static func stufe_soll(nummer: int) -> int:
    return mini(Kammern.HOECHSTSTUFE, int(round(stufe_kurve(nummer))))


## Ab welcher Welle die Sollkurve am Deckel steht - ab dort waechst nicht mehr
## die Leistung, sondern nur noch die Vielfalt.
static func deckelwelle() -> int:
    return 1 + (Kammern.HOECHSTSTUFE * (Graben.ZYKLUS - 1)) / STUFEN_JE_ZYKLUS


# --- Grabentiefe: was den naechsten Abschnitt oeffnet ----------------------
#
# Ohne diese Kopplung rennt die Wellenzahl der Kolonie davon. Der Kolonielauf
# zeigte einen Spieler, der an Tag 6 schon in Welle 36 stand, waehrend sein
# Leuchtorgan bei gut der Haelfte der Sollkurve lag - und der Spielraumlauf
# des Wellenpruefers verlangt ab Welle 36 die volle Kurve. Das ist keine Wand
# aus Absicht, sondern eine aus Versehen: der Spieler laeuft in Wellen hinein,
# fuer die es seine Kolonie noch nicht gibt.
#
# Der Tiefenschacht ist die Kammer, die dafuer gedacht ist - er deckelt ohnehin
# alle anderen. Jetzt oeffnet er auch den Graben.

## Welche Tiefenschachtstufe den Abschnitt `abschnitt_nr` oeffnet.
##
## Abgeleitet, nicht gewaehlt: verlangt wird genau der Schachtstand, bei dem
## der Deckel die Sollstufe der **letzten** Welle des Abschnitts zulaesst. Wer
## den Abschnitt betritt, kann ihn also ausbauen - nicht bloss betreten.
static func schacht_fuer_abschnitt(abschnitt_nr: int) -> int:
    if abschnitt_nr <= 0:
        return 0
    return maxi(0, stufe_soll(Graben.letzte_welle(abschnitt_nr))
        - Kammern.SCHACHT_VORSPRUNG)


## Bis zu welcher Welle der Graben bei diesem Schachtstand offen ist.
##
## Frueher eine Schleife ueber die sechs Abschnitte; jetzt eine Umkehrung der
## Ableitung oben, weil es keine feste Zahl von Abschnitten mehr gibt.
static func offene_welle(schacht: int) -> int:
    var nr := 0
    while nr < 4096:
        if schacht < schacht_fuer_abschnitt(nr + 1):
            break
        nr += 1
    return Graben.letzte_welle(nr)


