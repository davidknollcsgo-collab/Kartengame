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

## Hier stand 0.97, und das war zu dicht am Rand. Der Spielraumlauf zeigte es:
## ab Welle 66 trug nur noch der volle Sollausbau, ein Achtel darunter fiel
## die Sitzung. Eine Kurve, die keinen Schritt Rueckstand verzeiht, ist keine
## Kurve - der Kolonielauf meldete dazu zweiundzwanzig gefallene Sitzungen bei
## einem Leuchtorgan, das im Schnitt eine einzige Stufe hinter dem Soll lag.
const DRUCK_ENDE := 0.90
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
## Sie haengt an der Sollkurve, nicht an der blossen Wellennummer. Damit hoert
## sie dort auf zu wachsen, wo auch die Kolonie aufhoert - sonst stuenden in
## Welle 500 zwei unbezwingbar zaehe Brocken statt eines lesbaren Schwarms.
const ZAEHIGKEIT_JE_STUFE := 0.295

## Sicherung gegen eine Endlosschleife, falls jemand an der Staerke oder den
## Lebenswerten dreht.
const HOECHSTZAHL := 260


## Lebensmultiplikator der Raeuber in dieser Welle.
static func zaehigkeit(nummer: int) -> float:
    return 1.0 + ZAEHIGKEIT_JE_STUFE * Ausbau.stufe_kurve(nummer)


## Wie lange volles Feuer auf **ein** Ziel braucht, um ein Leitwesen zu
## toeten - am Anfang einer Umdrehung und an ihrem Ende.
##
## **Das war zuerst ein Anteil an der Wellenstaerke, und das war falsch.** Die
## Wellenstaerke faellt aus dem *Gesamtdurchsatz*, und der waechst mit der
## Zahl der gleichzeitig gefassten Ziele. Gegen ein einzelnes Leitwesen hilft
## ein zusaetzliches Ziel aber gar nichts. Also wuchs sein Leben schneller als
## der Schaden, den man ihm zufuegen kann: bei Welle 60 waren es 16 Sekunden
## volles Feuer, bei Welle 70 schon 38 - und der Wellenpruefer meldete genau
## dort seine erste Wand.
##
## Jetzt haengt es an dem, was wirklich auf ein Ziel geht. Die Zeit steigt
## ueber die erste Umdrehung und bleibt danach stehen; was das Leitwesen
## spaeter schwerer macht, ist die Umgebung, nicht seine Zahl.
const LEIT_SEKUNDEN_ANFANG := 5.0
const LEIT_SEKUNDEN_ENDE := 16.0

## Untergrenze, damit ein Leitwesen nie zur Zielscheibe wird, falls Panzer und
## Umgebung zusammen einmal alles wegnehmen.
const LEIT_MINDEST_ANTEIL := 0.25


## --- Was ein Raeuber in **dieser** Welle mitbringt ---
##
## Sieben Funktionen, und alle sieben aus demselben Grund: seit es Mutationen
## gibt, gehoert eine Eigenschaft nicht mehr der Art allein, sondern dem Paar
## aus Art und Welle. `Arten.panzer()` ist der Grundwert, `panzer_in()` der
## Wert, der wirklich gilt.
##
## **Spiel und Wellenpruefer fragen ausschliesslich hier.** Frueher haben
## beide `Arten.*` gefragt, und das ging gut, solange es nichts zu mutieren
## gab. Zwei Stellen, die dieselbe Eigenschaft aus verschiedenen Quellen
## holen, sind der Fehler, an dem bei HYPHA Sucher und Pruefer auseinander-
## liefen.

## Lebenspunkte, die ein Raeuber der Art `art` in Welle `nummer` mitbringt.
## Einzige Quelle fuer diesen Wert - Wellenbau, Pruefer und Spiel fragen hier.
static func leben_in(art: int, nummer: int) -> float:
    if Arten.ist_leitwesen(art):
        var t := clampf(float(maxi(1, nummer) - 1) / float(Graben.ZYKLUS - 1),
            0.0, 1.0)
        var sekunden := lerpf(LEIT_SEKUNDEN_ANFANG, LEIT_SEKUNDEN_ENDE, t)

        # `sekunden` heisst: so lange soll es dauern. Also wird das Leben aus
        # dem gerechnet, was in dieser Sekunde wirklich ankommt - nach der
        # Umgebung und **nach seinem eigenen Panzer**. Vorher stand hier der
        # rohe Kegelwert, und beides zaehlte doppelt: die Umgebung machte den
        # Rest der Welle kleiner und das Leitwesen nicht, und sein Panzer von
        # 3.0 verlaengerte die geplanten sechzehn Sekunden ungezaehlt. Auf
        # Welle 70 kam eine Mutation dazu, die noch einmal Panzer auflegt -
        # der Wellenpruefer meldete die Wand punktgenau dort.
        var kegel := Graben.LEISTUNG * Ausbau.leistung_faktor(nummer)
        var wirksam := maxf(kegel * LEIT_MINDEST_ANTEIL,
            kegel * umgebung(nummer) - panzer_in(art, nummer))
        return wirksam * sekunden
    var roh := Arten.leben(art) * zaehigkeit(nummer)
    if Mutationen.hat(nummer, Mutationen.Mutation.AUFGEDUNSEN):
        roh *= Mutationen.AUFGEDUNSEN_LEBEN
    return roh


## Panzer: was von jedem Schadensschritt abgezogen wird.
##
## Der Zuschlag ist ein Anteil der Leistung, die der Kegel auf der Sollstufe
## bei voller Helligkeit auf ein Ziel bringt - abgeleitet wie das Leben eines
## Leitwesens. Eine feste Zahl waere in Welle 70 eine Wand und in Welle 700
## nicht mehr zu bemerken.
static func panzer_in(art: int, nummer: int) -> float:
    var roh := Arten.panzer(art)
    if Mutationen.hat(nummer, Mutationen.Mutation.PANZERUNG):
        roh += Mutationen.PANZER_ANTEIL * Graben.LEISTUNG \
            * Ausbau.leistung_faktor(nummer)
    return roh


## **Wer schon eine Obergrenze hat, bekommt keine Untergrenze dazu.**
##
## Lichtscheu hebt die Mindesthelligkeit. Auf einem Spiegler, der ohnehin nur
## unterhalb seiner Obergrenze voll brennt, bliebe damit ein Band von 0.42 bis
## 0.78 uebrig - und nur darin wirkt der Strahl. Das ist kein schwierigeres
## Tier mehr, sondern ein unzielbares.
##
## Der Wellenpruefer hat genau das gefunden: eine gefallene Sitzung in
## achtundvierzig, Welle 224, mit Plated, Lightshy und Bloated zugleich und
## drei Spieglern darin. Vorher trugen alle 240 Wellen. Im Kommentar zu
## `hoechst_licht_in()` stand die Begruendung schon - ich hatte sie nur in
## eine Richtung angewandt.
static func mindest_licht_in(art: int, nummer: int) -> float:
    var roh := Arten.mindest_licht(art)
    if Arten.hoechst_licht(art) > 0.0:
        return roh
    if Mutationen.hat(nummer, Mutationen.Mutation.LICHTSCHEU):
        roh = maxf(roh, Mutationen.LICHT_SCHWELLE)
    return roh


## Die Obergrenze des Spieglers. Mutationen fassen sie nicht an: eine
## Lichtscheu-Mutation *darauf* ergaebe ein Tier, das nur in einem hauchduennen
## Helligkeitsband ueberhaupt brennt - rechnerisch reizvoll, im Bild nicht
## unterscheidbar von einem, das gar nicht brennt.
static func hoechst_licht_in(art: int, nummer: int) -> float:
    return Arten.hoechst_licht(art)


static func drift_in(art: int, nummer: int) -> float:
    var roh := Arten.drift(art)
    if Mutationen.hat(nummer, Mutationen.Mutation.UNSTET):
        roh += Mutationen.DRIFT_ZUSATZ
    return roh


static func stoss_in(art: int, nummer: int) -> float:
    var roh := Arten.stoss(art)
    if Mutationen.hat(nummer, Mutationen.Mutation.SCHUB):
        roh += Mutationen.STOSS_ZUSATZ
    return minf(roh, Schlund.STOSS_DECKEL)


static func tempo_in(art: int, nummer: int) -> float:
    var roh := Arten.tempo(art)
    if Mutationen.hat(nummer, Mutationen.Mutation.HAST):
        roh *= Mutationen.HAST_FAKTOR
    return roh


## Nur Anzeige - der Radius entscheidet nichts am Schaden, aber ein
## aufgedunsener Raeuber muss auch aufgedunsen aussehen. Eine Mutation, die
## man nicht sieht, ist keine.
static func radius_in(art: int, nummer: int) -> float:
    var roh := Arten.radius(art)
    if Mutationen.hat(nummer, Mutationen.Mutation.AUFGEDUNSEN):
        roh *= Mutationen.AUFGEDUNSEN_RADIUS
    return roh


## Ob in dieser Welle ein Leitwesen steht: am Ende jedes Grabenabschnitts.
static func hat_leitwesen(nummer: int) -> bool:
    return nummer > 0 and nummer % Graben.WELLEN_JE_ABSCHNITT == 0


## Was eine Art in Welle `nummer` vom Budget wegnimmt.
##
## Nicht dasselbe wie ihr Leben: eine Schildkoralle mit Panzer kostet den
## Spieler mehr Zeit, als ihre Lebenspunkte sagen. `leben_in()` bleibt davon
## unberuehrt - sonst waere die Lebensanzeige ueber dem Tier falsch. Siehe
## `Arten.aufwand()`.
static func aufwand_in(art: int, nummer: int) -> float:
    return leben_in(art, nummer) * Arten.aufwand(art)


## Naehrstoff, den eine ganze Welle einbringt, wenn man sie raeumt.
##
## **Abgeleitet aus dem, was eine Kammerstufe kostet** - so wie die
## Wellenstaerke aus dem Durchsatz abgeleitet ist und nicht frei gewaehlt.
##
## Vorher war der Ertrag eine feste Zahl je Art, die mit der Zaehigkeit
## mitwuchs: linear. Die Kammern kosten geometrisch. Zwei Kurven, von denen
## eine linear und die andere geometrisch waechst, laufen nicht auseinander -
## die eine holt die andere nie wieder ein. Der Kolonielauf zeigte genau das:
## bei Welle 45 kostete eine volle Kammerrunde fuenf Tage Ertrag, bei Welle 75
## vierundsiebzig, bei Welle 120 dreitausend. Ein Spiel, das dauerhaft laufen
## soll, kann sich das nicht leisten.
##
## Jetzt gilt: was ein Tag an Wellen hergibt, traegt `1 - FILTER_ANTEIL` einer
## vollen Kammerrunde in `TAGE_JE_RUNDE` Tagen. Der Rest kommt aus dem
## Filterbecken. Beide zusammen ergeben eine Runde je Takt - fuer immer, weil
## beide Seiten aus derselben Kostenzahl fallen.
static func ertrag(nummer: int) -> float:
    return (1.0 - Kammern.FILTER_ANTEIL) \
        * Kammern.rundenkosten(Ausbau.stufe_soll(nummer)) \
        / (Kammern.TAGE_JE_RUNDE * float(Graben.WELLEN_JE_TAG))


## Naehrstoff, den ein einzelner Raeuber einbringt: sein Anteil am Aufwand der
## Welle.
##
## Damit bringt eine geraeumte Welle genau `ertrag()` ein, gleich wie sie
## zusammengesetzt ist - und wer den zaehen Brocken erlegt statt der drei
## Schleier, bekommt auch dafuer, was er gekostet hat. Eine eigene Wertzahl je
## Art gibt es deshalb nicht mehr: der Aufwand *ist* der Wert.
static func wert_in(art: int, nummer: int) -> int:
    var anteil := aufwand_in(art, nummer) / maxf(1.0, staerke(nummer))
    return maxi(1, int(round(ertrag(nummer) * anteil)))


## Wie hoch der Anteil der eigenen Leistung ist, den diese Welle abverlangt.
## Der Druck steigt ueber die erste Umdrehung von bequem auf knapp und
## bleibt dann dort. Weiter kann er nicht: er ist der Anteil der eigenen
## Leistung, den die Welle abverlangt, und ueber hundert Prozent gibt es
## nichts. Was danach noch waechst, ist die Sollkurve selbst.
static func druck(nummer: int) -> float:
    var t := clampf(float(maxi(1, nummer) - 1) / float(Graben.ZYKLUS - 1), 0.0, 1.0)
    return lerpf(DRUCK_ANFANG, DRUCK_ENDE, pow(t, DRUCK_KRUEMMUNG))


## Lebenspunkte-Budget der Welle.
##
## Abgeleitet aus dem, was ein Spieler auf dieser Stufe leisten kann - nicht
## aus einer freien Wachstumszahl. Siehe die Begruendung in `ausbau.gd`.
static func staerke(nummer: int) -> float:
    return Ausbau.durchsatz(nummer) * WIRKUNGSGRAD * umgebung(nummer) \
        * fenster(nummer) * druck(nummer)


## Was Abschnittsregel und Mutationen zusammen an Wirkungsgrad kosten. Eine
## Stelle, weil beide dasselbe bedeuten: wieviel von seiner Leistung ein
## Spieler in dieser Welle ueberhaupt auf die Raeuber bringt.
##
## Gemerkt wie bei `Mutationen.in_welle()`, und aus demselben Grund: seit der
## Naehrstoff je Raeuber sein Anteil an der Welle ist, haengt `wert_in()` an
## `staerke()` und damit hier. `Regeln.wirkungsgrad()` integriert dafuer ueber
## ein Gitter von 24 mal 24 und einen vollen Dunkelzyklus - einmal je Welle
## ist das nichts, einmal je erlegtem Tier waere es viel.
static var _umgebung_nummer := -1
static var _umgebung_wert := 1.0


static func umgebung(nummer: int) -> float:
    if nummer != _umgebung_nummer:
        _umgebung_wert = Regeln.wirkungsgrad(nummer) * Mutationen.wirkungsgrad(nummer)
        _umgebung_nummer = nummer
    return _umgebung_wert


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

    # Das Leitwesen zuerst, und aus demselben Budget. Es kommt also nicht
    # obendrauf - die Welle wird nicht schwerer, sondern anders: ein Brocken
    # statt eines Dutzends.
    # **Welches** Leitwesen, haengt am Abschnitt und nicht am Zufall - sonst
    # waere der Hoehepunkt eine Ueberraschung statt eines Ortes.
    var leit := Arten.leitwesen_fuer(Graben.abschnitt(nummer))
    if hat_leitwesen(nummer) and leit >= 0:
        budget -= aufwand_in(leit, nummer)
        var allein: Array[int] = [leit]
        gruppen.append(allein)

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
                var halb := (gruppe.size() - 1) * 0.5
                streu = (float(k) - halb) * 46.0
                # **Ein Schwarm zieht in Staffel, nicht in einer Reihe.**
                #
                # Hier stand `rng.randf_range(0.0, 0.5)` je Tier. Gemessen
                # ueber die Bahnen einer Welle: drei Schleier standen in
                # Welle 40 bei y = 21, -1 und -1 - zwei davon auf denselben
                # Pixel, sechsundvierzig Pixel nebeneinander. Bei einem Tempo
                # von 168 sind fuenf Hundertstel Sekunde Unterschied acht
                # Pixel, und der Wuerfel liefert solche Paare regelmaessig.
                #
                # Jedes Tier tritt ein Stueck spaeter ein als sein Nachbar -
                # eine Schraege quer zum Graben. Ein Keil war der erste
                # Einfall und hat den Fehler nur halbiert: er ist
                # spiegelsymmetrisch, also stehen die beiden Flanken wieder
                # auf demselben Pixel. Eine Staffel wiederholt keine Hoehe.
                #
                # Es ist dieselbe Streuung wie vorher - null bis knapp eine
                # halbe Sekunde -, nur nicht mehr zufaellig, sondern als
                # Form. Das Budget der Welle bleibt unberuehrt: es aendert
                # sich nur, wann innerhalb einer halben Sekunde ein Tier
                # eintritt, nicht welches und nicht wie viele.
                versatz = 0.44 * float(k) / float(gruppe.size() - 1)
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
