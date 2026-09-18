class_name Ronde
extends RefCounted

## **Wer in Ronde `nummer` antritt - gerechnet, nicht gewuerfelt.**
##
## Dieselbe Ronde muss bei jedem Spieler dieselbe sein, sonst laesst sich
## nichts nachmessen und niemand kann ueber eine Stelle reden. Der Zufall
## steckt deshalb in einer Saat, die an der Nummer haengt, und nicht im
## Spielverlauf.
##
## **Die Staerke wird abgeleitet, nicht gewaehlt.** `Schule.fassung()` sagt,
## was ein Spieler auf der Sollkurve leisten kann; die Ronde bekommt davon
## einen wachsenden Anteil. Eine frei hochgezogene Wachstumszahl gibt ein
## Spiel, das zwanzig Ronden lang langweilt und in der einundzwanzigsten
## unmoeglich wird.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

const SAAT := 0x53434e54

## Wie viele Ronden ein Kapitel hat. Am Ende jedes Kapitels steht der
## Meister - allein, ohne Begleitung.
const KAPITEL := 6

## Der Anteil der eigenen Fassung, den eine Ronde abverlangt. Von bequem auf
## knapp ueber das erste Kapitel, dann bleibt er - ueber hundert Prozent
## seiner selbst kann niemand.
const DRUCK_ANFANG := 0.42
const DRUCK_ENDE := 0.95
const DRUCK_STRECKE := 24.0

## Hoechstens so viele Gegner in einer Ronde. Mehr ist keine Ronde mehr,
## sondern eine Warteschlange.
const HOECHSTZAHL := 14


static func kapitel(nummer: int) -> int:
    return (maxi(1, nummer) - 1) / KAPITEL


## Steht am Ende dieses Kapitels der Meister?
static func hat_meister(nummer: int) -> bool:
    return maxi(1, nummer) % KAPITEL == 0


static func druck(nummer: int) -> float:
    var t := clampf(float(maxi(1, nummer) - 1) / DRUCK_STRECKE, 0.0, 1.0)
    return lerpf(DRUCK_ANFANG, DRUCK_ENDE, pow(t, 0.85))


## **Wie lange eine Ronde ungefaehr dauern soll**, in Sekunden. Sie ist die
## Einheit, in der hier ueberhaupt gerechnet wird: eine Ronde ist eine
## Zeitspanne, kein Sack Gegner.
const RONDE_SEKUNDEN := 18.0

## **Wieviel Aufmerksamkeit eine Einheit Aufwand kostet, in Sekunden.**
##
## Abgeleitet am Massstab und nicht gewaehlt: ein Ronin kostet
## `Gegner.ehre(RONIN)` an Aufwand und bindet den Spieler fuer einen vollen
## Takt - Ansatz, Parade, Oeffnung, Atemzug. Wer diese Zahl aendert, aendert
## die Laenge jeder Ronde im Spiel, und genau deshalb steht sie hier einmal
## und nirgends sonst.
static func takt_je_aufwand() -> float:
    var takt := Gegner.ansatz(Gegner.Art.RONIN) \
        + Gegner.oeffnung(Gegner.Art.RONIN) + Duell.PAUSE_KURZ
    return takt / float(Gegner.ehre(Gegner.Art.RONIN))


## Das Budget der Ronde: was in `RONDE_SEKUNDEN` hineinpasst.
##
## `gleichzeitig()` geht mit ein, und das ist keine Doppelzaehlung: wer zwei
## Ansaetze nebeneinander liest, raeumt in derselben Zeit auch zwei Gegner -
## schwerer *und* schneller. Ohne diesen Faktor wuerde die Ronde mit jedem
## Platz laenger statt dichter.
static func staerke(nummer: int) -> float:
    return RONDE_SEKUNDEN * druck(nummer) * float(gleichzeitig(nummer)) \
        / maxf(0.001, takt_je_aufwand())


## **Was ein Gegner im Budget kostet.** Seine Ehre ist bereits aus Fenster
## und Paradenzahl abgeleitet; sie hier ein zweites Mal von Hand zu setzen
## hiesse, zwei Meinungen ueber dieselbe Schwierigkeit zu fuehren.
static func aufwand(art: int) -> float:
    return float(Gegner.ehre(art))


## Welche Sorten in diesem Kapitel ueberhaupt auftreten. Der Graben oeffnet
## sich langsam: wer im ersten Kapitel schon den Taeuscher trifft, lernt die
## Grundlinie nie.
static func verfuegbar(nummer: int) -> PackedInt32Array:
    var k := kapitel(nummer)
    var liste := PackedInt32Array([Gegner.Art.RONIN])
    if k >= 1 or nummer >= 3:
        liste.append(Gegner.Art.SCHNELL)
    if k >= 1:
        liste.append(Gegner.Art.STOSSER)
    if k >= 2:
        liste.append(Gegner.Art.FEINT)
    if k >= 2:
        liste.append(Gegner.Art.SCHWER)
    return liste


## Die Gegner der Ronde, in der Reihenfolge, in der sie antreten.
##
## **Der Meister steht zuletzt.** Eine Ronde, die mit ihrem groessten Gegner
## anfaengt, hat keinen Bogen, sondern ein Nachspiel - und wer ihn als
## ersten faellt, hat danach nichts mehr zu tun.
static func gegner(nummer: int) -> PackedInt32Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + nummer * 7919

    var moeglich := verfuegbar(nummer)
    var budget := staerke(nummer)
    var liste := PackedInt32Array()

    # Der Meister zahlt aus demselben Budget: die Ronde wird nicht laenger,
    # sondern anders - ein Brocken statt dreier Ronin.
    var mit_meister := hat_meister(nummer)
    if mit_meister:
        budget -= aufwand(Gegner.Art.MEISTER)

    var billigst := 9999.0
    for a in moeglich:
        billigst = minf(billigst, aufwand(a))

    while budget >= billigst and liste.size() < HOECHSTZAHL:
        var art: int = moeglich[rng.randi_range(0, moeglich.size() - 1)]
        var preis := aufwand(art)
        if preis > budget:
            # Zu teuer fuer den Rest: mit der guenstigsten Sorte auffuellen.
            for a in moeglich:
                if aufwand(a) <= budget:
                    art = a
                    preis = aufwand(a)
                    break
        if preis > budget:
            break
        budget -= preis
        liste.append(art)

    # Wenigstens einer, sonst steht der Spieler vor einer leeren Buehne.
    if liste.is_empty() and not mit_meister:
        liste.append(Gegner.Art.RONIN)

    if mit_meister:
        liste.append(Gegner.Art.MEISTER)
    return liste


## **Wie viele zugleich in der Mensur stehen.**
##
## Das ist der zweite Schwierigkeitsregler und der ehrlichere: zwei Ansaetze
## gleichzeitig zu lesen ist etwas voellig anderes, als zweimal
## nacheinander einen zu lesen. Er waechst langsam und ist gedeckelt - bei
## vier gleichzeitigen Fuehrungslinien liest niemand mehr, er raet.
const GLEICHZEITIG_HOECHST := 3

static func gleichzeitig(nummer: int) -> int:
    if hat_meister(nummer):
        return 1  ## Der Meister tritt allein an.
    return clampi(1 + (maxi(1, nummer) - 1) / 5, 1, GLEICHZEITIG_HOECHST)


## **Die Ehre, die eine geraeumte Ronde einbringt.**
##
## Abgeleitet aus dem, was eine Schulrunde kostet - so wie die Staerke aus
## der Fassung faellt. Beide Seiten wachsen damit mit derselben Rate, und
## das Spiel bleibt auch in der hundertsten Ronde rechenbar.
static func ehre(nummer: int) -> int:
    return maxi(1, int(round(
        Schule.rundenkosten(Schule.stufe_soll(nummer)) / Schule.RONDEN_JE_RUNDE)))


## Was ein einzelner Gegner einbringt: sein Anteil am Aufwand der Ronde.
## Damit zahlt eine ganz geraeumte Ronde genau `ehre()`, gleich wie sie
## zusammengesetzt ist.
static func wert_von(art: int, nummer: int) -> int:
    var summe := 0.0
    for a in gegner(nummer):
        summe += aufwand(a)
    var anteil := aufwand(art) / maxf(0.001, summe)
    return maxi(1, int(round(float(ehre(nummer)) * anteil)))
