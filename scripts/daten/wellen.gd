class_name Wellen
extends RefCounted

## Aus welcher Welle was kommt.
##
## Die Zusammensetzung wird aus der Wellennummer **gerechnet**, nicht
## gewuerfelt. Zwei Gruende:
##
## 1. Der Wellenpruefer (`tools/wellenpruefer.gd`) kann jede Welle exakt so
##    durchrechnen, wie sie beim Spieler ankommt. Bei Zufall zur Laufzeit
##    pruefte er etwas anderes als das Spiel spielt.
## 2. Alle Spieler sehen dieselbe Welle 37. Eine Bestenliste ueber
##    unterschiedliche Wellen waere keine.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Wie viel des rohen Durchsatzes ein Spieler wirklich auf die Raeuber bringt.
## Der Rest geht fuer Drehen, Nachfuehren, Luecken und halb beleuchtete Ziele
## drauf. Gemessen wird das vom Wellenpruefer - dieser Wert ist der Ansatz, aus
## dem die Wellenstaerke faellt, nicht das Ergebnis.
const WIRKUNGSGRAD := 0.42

## Der Druck: welchen Anteil seiner Leistung der Spieler in dieser Welle
## abrufen muss. Steigt von bequem auf knapp. **Das ist der einzige Regler fuer
## die Schwierigkeitskurve** - alles andere ergibt sich daraus.
const DRUCK_ANFANG := 0.34
const DRUCK_ENDE := 0.97
const DRUCK_KRUEMMUNG := 0.85

const FENSTER_GRUND := 34.0
const FENSTER_ZUWACHS := 0.62
const FENSTER_MAX := 62.0

## Nach dem letzten Eintritt braucht der letzte Raeuber noch seine Sinkzeit.
## Diese Spanne haelt die Welle innerhalb der im Konzept genannten 40 bis 70
## Sekunden.
const NACHLAUF := 8.0

## Feste Saat. "NEK" als Zahl - beliebig, aber nie wieder zu aendern, weil
## sich sonst jede geprueft Welle veraendert.
const SAAT := 0x4e454b

## Wie zaeh die Raeuber in spaeten Wellen werden.
##
## Ohne das waere die einzige Antwort auf mehr Budget *mehr Tiere*: Welle 60
## haette bei gleichbleibendem Leben ueber zweitausend Raeuber enthalten. Auf
## einem Telefonbildschirm ist das kein Kampf mehr, sondern Rauschen. Mit der
## Zaehigkeit bleibt die Zahl lesbar und der einzelne Treffer schwerer.
const ZAEHIGKEIT_JE_WELLE := 0.10

## Wie stark der Naehrstoffertrag der Zaehigkeit folgt. Voll gekoppelt (1.0)
## ueberschwemmte den Kolonielauf: Welle 60 schon an Tag 23 und 315000
## Naehrstoff ungenutzt auf dem Konto. Knapp die Haelfte laesst den Ertrag
## mitwachsen, ohne den Vorrat bedeutungslos zu machen.
const WERT_ANTEIL := 0.56

## Sicherung gegen eine Endlosschleife, falls jemand an der Staerke oder den
## Lebenswerten dreht.
const HOECHSTZAHL := 260


## Lebensmultiplikator der Raeuber in dieser Welle.
static func zaehigkeit(nummer: int) -> float:
    return 1.0 + ZAEHIGKEIT_JE_WELLE * maxi(0, nummer - 1)


## Lebenspunkte, die ein Raeuber der Art `art` in Welle `nummer` mitbringt.
## Einzige Quelle fuer diesen Wert - Wellenbau, Pruefer und Spiel fragen hier.
static func leben_in(art: int, nummer: int) -> float:
    return Arten.leben(art) * zaehigkeit(nummer)


## Was eine Art in Welle `nummer` vom Budget wegnimmt.
##
## Nicht dasselbe wie ihr Leben: eine Schildkoralle mit Panzer kostet den
## Spieler mehr Zeit, als ihre Lebenspunkte sagen. `leben_in()` bleibt davon
## unberuehrt - sonst waere die Lebensanzeige ueber dem Tier falsch. Siehe
## `Arten.aufwand()`.
static func aufwand_in(art: int, nummer: int) -> float:
    return leben_in(art, nummer) * Arten.aufwand(art)


## Naehrstoff, den er einbringt.
##
## Waechst mit derselben Zaehigkeit wie sein Leben. Ohne diese Kopplung stieg
## der Ertrag ueber 60 Wellen nur um das Siebenfache - allein dadurch, dass
## mehr Tiere kommen -, waehrend die Kammerkosten um ein Vielfaches stiegen.
## Der Kolonielauf zeigte die Folge: dreissig von dreissig Tagen hinter der
## Sollkurve. Ein zaeherer Raeuber muss mehr wert sein.
static func wert_in(art: int, nummer: int) -> int:
    return maxi(1, int(round(Arten.wert(art)
        * (1.0 + WERT_ANTEIL * (zaehigkeit(nummer) - 1.0)))))


## Wie hoch der Anteil der eigenen Leistung ist, den diese Welle abverlangt.
static func druck(nummer: int) -> float:
    var t := float(clampi(nummer, 1, Graben.WELLEN_GESAMT) - 1) \
        / float(maxi(1, Graben.WELLEN_GESAMT - 1))
    return lerpf(DRUCK_ANFANG, DRUCK_ENDE, pow(t, DRUCK_KRUEMMUNG))


## Lebenspunkte-Budget der Welle.
##
## Abgeleitet aus dem, was ein Spieler auf dieser Stufe leisten kann - nicht
## aus einer freien Wachstumszahl. Siehe die Begruendung in `ausbau.gd`.
static func staerke(nummer: int) -> float:
    return Ausbau.durchsatz(nummer) * WIRKUNGSGRAD * Regeln.wirkungsgrad(nummer) \
        * fenster(nummer) * druck(nummer)


## Wie lange Raeuber eintreten. Die Welle selbst dauert laenger - der letzte
## muss noch sinken.
static func fenster(nummer: int) -> float:
    return minf(FENSTER_MAX, FENSTER_GRUND + FENSTER_ZUWACHS * (nummer - 1))


## Ungefaehre Gesamtdauer der Welle in Sekunden. Fuer Anzeige und Balance.
static func dauer(nummer: int) -> float:
    return fenster(nummer) + NACHLAUF


## Alle Auftritte einer Welle, nach Zeit sortiert.
##
## Jeder Eintrag: `art` (Index in `Arten.TABELLE`), `zeit` (Sekunden ab
## Wellenbeginn), `x` (Eintrittsstelle), `phase` (Versatz des Schlaengelns).
static func auftritte(nummer: int) -> Array[Dictionary]:
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + nummer * 7919

    var moeglich := Arten.verfuegbar(nummer)
    var billig := billigste(moeglich)
    var budget := staerke(nummer)

    # Erst die Gruppen bilden, dann die Zeiten verteilen. Wuerfelte man die
    # Zeit je Gruppe frei, klumpten sie sichtbar - die Welle haette Loecher
    # und Spitzen, die niemand entworfen hat.
    var gruppen: Array[Array] = []
    while budget > 0.0 and gruppen.size() < HOECHSTZAHL:
        var index := moeglich[rng.randi_range(0, moeglich.size() - 1)]
        var anzahl := 1
        if index == Arten.Art.SCHLEIER:
            anzahl = rng.randi_range(3, 5)

        var kosten := aufwand_in(index, nummer) * anzahl
        if kosten > budget:
            # Zu teuer fuer den Rest: mit der billigsten Art auffuellen.
            index = billig
            anzahl = 1
            kosten = aufwand_in(index, nummer)
            if kosten > budget:
                break

        budget -= kosten
        var gruppe: Array[int] = []
        for _i in anzahl:
            gruppe.append(index)
        gruppen.append(gruppe)

    var breite := fenster(nummer)
    var schritt := breite / maxf(1.0, float(gruppen.size()))
    var liste: Array[Dictionary] = []

    for g in gruppen.size():
        # Gleichmaessig verteilt, mit begrenztem Wackeln. Der Rhythmus bleibt
        # dadurch lesbar, ohne mechanisch zu wirken.
        var zeit := schritt * (float(g) + rng.randf_range(0.18, 0.82))
        var mitte := rng.randf_range(-Graben.EINTRITT_SEITE, Graben.EINTRITT_SEITE)
        var gruppe: Array = gruppen[g]

        for k in gruppe.size():
            var streu := 0.0
            var versatz := 0.0
            if gruppe.size() > 1:
                streu = (float(k) - (gruppe.size() - 1) * 0.5) * 46.0
                versatz = rng.randf_range(0.0, 0.5)
            liste.append({
                &"art": gruppe[k],
                &"zeit": maxf(0.0, zeit + versatz),
                &"x": clampf(mitte + streu, -Graben.EINTRITT_SEITE, Graben.EINTRITT_SEITE),
                &"phase": rng.randf_range(0.0, TAU),
            })

    liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a[&"zeit"] < b[&"zeit"])
    return liste


## Summe der Lebenspunkte, die tatsaechlich in der Welle stehen. Kann leicht
## unter `staerke()` liegen, weil das Budget selten glatt aufgeht.
static func lebenssumme(nummer: int) -> float:
    var summe := 0.0
    for a in auftritte(nummer):
        summe += leben_in(a[&"art"], nummer)
    return summe


static func billigste(moeglich: PackedInt32Array) -> int:
    var beste := moeglich[0]
    for i in moeglich:
        if Arten.leben(i) * Arten.aufwand(i) < Arten.leben(beste) * Arten.aufwand(beste):
            beste = i
    return beste
