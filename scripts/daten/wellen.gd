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


## --- Die Funkenbluete ---
##
## **Der Welle fehlte ein Grund, den Kegel wegzuziehen.** Alles, was
## auftaucht, will zur Brut, und der Kegel gehoert dorthin, wo es herkommt.
## Die einzige Entscheidung war, welchen Raeuber zuerst - und das ist keine,
## denn es ist immer der vorderste.
##
## Die Bluete ist das Gegenteil eines Raeubers: sie greift nichts an, sinkt
## nicht, und sie treibt quer durchs Bild wieder hinaus. Wer sie will, muss
## den Kegel **weg** von der Bahn nehmen, auf der die Raeuber kommen. Das ist
## die Entscheidung, und sie kostet genau das, was sie einbringt: Zeit.
##
## **Sie zahlt keinen Naehrstoff.** Das Einkommen ist aus den Kammerkosten
## abgeleitet (siehe `ertrag()`), und ein Fund, der daneben Naehrstoff
## ausschuettet, verschiebt die ganze Wirtschaft. Sie zahlt Punkte und Kette -
## dieselbe Waehrung wie der Lauf selbst.
##
## **Und nur der Kegel oeffnet sie.** Das Stosslicht laeuft durch sie hindurch.
## Ohne diese Regel waere die Entscheidung keine: man wartet, bis der Ring
## geladen ist, tippt, und bekommt sie geschenkt.
const BLUETE_AB_WELLE := 4
const BLUETE_JE_WELLEN := 3
const BLUETE_SEKUNDEN := 1.7
const BLUETE_DAUER := 9.5
const BLUETE_PUNKTE := 400
const BLUETE_KETTE := 5


static func hat_bluete(nummer: int) -> bool:
    if nummer < BLUETE_AB_WELLE:
        return false
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + nummer * 104729
    return rng.randi() % BLUETE_JE_WELLEN == 0


## Wann und wo sie eintritt. Gewuerfelt wie alles andere: aus der Wellenzahl,
## damit dieselbe Welle immer dieselbe Bluete hat.
static func bluete_in(nummer: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + nummer * 104729 + 13
    var seite := -1.0 if rng.randi() % 2 == 0 else 1.0
    return {
        &"zeit": rng.randf_range(4.0, 16.0),
        &"y": rng.randf_range(-260.0, 190.0),
        &"seite": seite,
        &"hub": rng.randf_range(24.0, 70.0),
        &"phase": rng.randf_range(0.0, TAU),
    }


## Wie zaeh sie ist - in Sekunden Kegel auf der Sollstufe, wie beim Leitwesen.
## Ein fester Wert waere in Welle 200 ein Streifschuss.
static func bluete_leben(nummer: int) -> float:
    return Graben.LEISTUNG * Ausbau.leistung_faktor(nummer) * BLUETE_SEKUNDEN


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
## **Geteilt durch `Rundum.DICHTE`.** Gespielt wird nie eine Welle allein:
## eine Fahrtrunde nimmt `DICHTE` Wellen auf einmal und schiebt sie
## ineinander. `Ausbau.durchsatz()` sagt, was ein Spieler in **einer** Welle
## leisten kann - drei davon gleichzeitig sind das Dreifache an Leben gegen
## dieselbe Leistung.
##
## Das war die Luecke, die der umgebaute Wellenpruefer als erstes fand:
## fuenfunddreissig gefallene Fahrten, die erste Wand bei Welle 67 - und der
## Pilot der Fahrprobe stand bei Welle 60 auf vier von zwanzig Huelle, also
## unabhaengig davon dasselbe Bild. Solange es zwei Schleifen gab, hing an
## `DICHTE` ausdruecklich keine Zusage ("von Hand gesetzt und von Hand
## nachgesehen"); seit es nur noch eine gibt, haengt die ganze Kurve daran.
##
## Der Ertrag bleibt davon unberuehrt: `wert_in()` ist ein **Anteil** an
## `staerke()`, und die Fahrt teilt ihn noch einmal durch `DICHTE`. Drei
## Drittel einer gedrittelten Welle sind eine ganze.
static func staerke(nummer: int) -> float:
    return Ausbau.durchsatz(nummer) * WIRKUNGSGRAD * umgebung(nummer) \
        * fenster(nummer) * druck(nummer) / float(Rundum.DICHTE)


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


## Wo eine Gruppe in der Zeit landet, gemessen an ihrem Platz in der Reihe.
##
## **Vorher war das die Einheitsabbildung**, also gleiche Abstaende vom ersten
## bis zum letzten Auftritt. Eine Welle fuehlte sich damit am Ende genauso an
## wie am Anfang: ein Foerderband, kein Angriff. Wellen sind aber das, was
## dieses Spiel dreissig Sekunden lang zeigt, und ein Foerderband hat keinen
## Bogen.
##
## `lage` laeuft von 0 bis 1 (erste bis letzte Gruppe), heraus kommt der
## Anteil des Eintrittsfensters. `pow` mit einem Exponenten **unter** eins
## schiebt alles nach hinten und verdichtet dabei: die Dichte je Zeit ist
## `lage^(1-ANSTIEG) / ANSTIEG`, waechst also ueber die Welle. Bei 0.75
## kommen im letzten Drittel rund anderthalbmal so viele Gruppen an wie im
## ersten - spuerbar, ohne dass die Welle vorne leer steht.
##
## **Am Budget aendert das nichts.** Es ist dieselbe Menge Tier in derselben
## Zeit, nur anders verteilt; `staerke()` sieht diese Funktion nicht. Was sich
## sehr wohl aendert, ist wieviel davon gleichzeitig im Kegel steht - und
## genau das ist der Punkt. Ob es dabei spielbar bleibt, sagt nicht die
## Rechnung, sondern der Wellenpruefer.
##
## Die Ordnung bleibt erhalten: `anlauf()` steigt streng monoton, und das
## Wackeln von 0.18 bis 0.82 ist kleiner als ein ganzer Platz. Deshalb sind
## die Auftritte weiter nach Zeit sortiert.
const ANSTIEG := 0.75

## Wie weit eine volle Gruppe (neun Tiere) in der Reihe nach hinten rutscht,
## als Anteil des Fensters. Siehe `auftritte()`.
const SCHWARM_SPAET := 0.16

## Wieviele Sekunden hinter dem letzten Kleinvieh das Leitwesen eintritt,
## falls es sonst ueberholt wuerde.
const LEIT_ABSTAND := 0.8


static func anlauf(lage: float) -> float:
    return pow(clampf(lage, 0.0, 1.0), ANSTIEG)


## Ungefaehre Gesamtdauer **einer** Welle in Sekunden. Fuer Anzeige.
static func dauer(nummer: int) -> float:
    return fenster(nummer) + NACHLAUF


## Das Eintrittsfenster einer **Fahrtrunde**: `Rundum.DICHTE` Wellen,
## ineinander statt hintereinander.
##
## **Nicht `fenster(nummer)`.** Gespielt wird nie eine Welle allein - eine
## Runde nimmt `DICHTE` auf einmal und schiebt sie um hoechstens 1.6 s je
## Versatz auseinander. Das laengste der drei Fenster ist das der letzten.
##
## Steht hier und nicht in `rundlauf.gd`, weil drei Stellen dieselbe Zahl
## brauchen: die Fahrprobe misst den Rueckstand daran, der Kolonielauf die
## Sitzungslaenge, und die Szene selbst richtet sich danach. Drei
## Abschriften derselben Formel laufen auseinander - das ist in diesem
## Projekt schon zweimal passiert.
static func rundenfenster(nummer: int) -> float:
    return fenster(nummer + Rundum.DICHTE - 1) \
        + float(Rundum.DICHTE - 1) * 1.6


## Wie lange eine Fahrtrunde ungefaehr dauert, samt Nachlauf.
static func rundendauer(nummer: int) -> float:
    return rundenfenster(nummer) + NACHLAUF


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

    # Das Leitwesen zahlt aus demselben Budget. Es kommt also nicht obendrauf
    # - die Welle wird nicht schwerer, sondern anders: ein Brocken statt
    # eines Dutzends.
    # **Welches** Leitwesen, haengt am Abschnitt und nicht am Zufall - sonst
    # waere der Hoehepunkt eine Ueberraschung statt eines Ortes.
    #
    # **Es steht aber am Ende und nicht am Anfang.** Die Zeiten werden weiter
    # unten in Gruppenreihenfolge vergeben; angehaengt wurde das Leitwesen
    # bisher als erstes und bekam damit den fruehesten Schlitz. Der
    # Hoehepunkt eines ganzen Grabenabschnitts trat also als Erster ein, und
    # danach kam ein Rinnsal aus Kleinvieh. Eine Welle, die mit ihrem
    # groessten Tier anfaengt, hat keinen Bogen - sie hat ein Nachspiel.
    var leit := Arten.leitwesen_fuer(Graben.abschnitt(nummer))
    var mit_leit := hat_leitwesen(nummer) and leit >= 0
    var deckel := HOECHSTZAHL - 1 if mit_leit else HOECHSTZAHL
    if mit_leit:
        budget -= aufwand_in(leit, nummer)

    while budget > 0.0 and gruppen.size() < deckel:
        var index := moeglich[rng.randi_range(0, moeglich.size() - 1)]
        # **Wieviele auf einen Schlag, sagt die Art.** Hier stand der
        # Schleier namentlich; jede weitere Schwarmart haette an zwei Stellen
        # eingetragen werden muessen, und die zweite vergisst man.
        var g := Arten.gruppe(index)
        var anzahl := rng.randi_range(g.x, g.y)

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

    if mit_leit:
        var allein: Array[int] = [leit]
        gruppen.append(allein)

    var breite := fenster(nummer)
    var liste: Array[Dictionary] = []

    for g in gruppen.size():
        # Der Reihe nach, mit begrenztem Wackeln - der Rhythmus bleibt
        # dadurch lesbar, ohne mechanisch zu wirken. Der Platz in der Reihe
        # ist die Rohlage; wohin sie in der Zeit faellt, sagt `anlauf()`.
        var lage := (float(g) + rng.randf_range(0.18, 0.82)) \
            / maxf(1.0, float(gruppen.size()))
        # **Die Masse kommt spaeter.**
        #
        # Solange jede Gruppe ein bis fuenf Tiere gross war, trug `anlauf()`
        # den Bogen allein. Seit es Schwaerme von sechs bis neun gibt,
        # entscheidet ein einziger frueher Wurf ueber ein Drittel der Welle:
        # gemessen fiel der Bogen von 23/42 auf 26/36 Prozent und damit unter
        # die Zusage.
        #
        # Eine grosse Gruppe wird deshalb **geschoben**, nicht einsortiert.
        # Der erste Anlauf hat nach Groesse sortiert; heraus kam 14/64
        # Prozent und keine einzige Welle ohne Bogen - also genau das
        # Foerderband mit Steigung, gegen das der Bogen gebaut wurde. Ein
        # Schub laesst die Reihenfolge zufaellig und verschiebt nur das
        # Gewicht.
        var gross: Array = gruppen[g]
        lage = minf(1.0, lage + SCHWARM_SPAET
            * float(gross.size() - 1) / 8.0)
        var zeit := breite * anlauf(lage)
        var mitte := rng.randf_range(-Graben.EINTRITT_SEITE, Graben.EINTRITT_SEITE)
        var gruppe: Array = gross

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

    # **Das Leitwesen tritt zuletzt ein** (Zusage 24), und zwar nicht nur
    # meistens. Es steht als letzte Gruppe in der Reihe und bekaeme damit von
    # allein den spaetesten Schlitz - aber `SCHWARM_SPAET` schiebt grosse
    # Gruppen nach hinten, und ein Schwarm von neun kann daran vorbeiziehen.
    # Genau das meldete Welle 170.
    #
    # Geschoben wird deshalb hinterher, und nur wenn noetig: der Hoehepunkt
    # setzt einen Atemzug hinter dem letzten Kleinvieh ein.
    if mit_leit:
        var spaetestes := 0.0
        for e in liste:
            if int(e[&"art"]) != leit:
                spaetestes = maxf(spaetestes, float(e[&"zeit"]))
        for e in liste:
            if int(e[&"art"]) == leit:
                e[&"zeit"] = maxf(float(e[&"zeit"]),
                    spaetestes + LEIT_ABSTAND)

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
