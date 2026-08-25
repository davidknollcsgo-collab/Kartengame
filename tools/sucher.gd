## Gieriger Sucher, der eine Kammer durchspielt.
##
## Wird von der Kammersuche **und** von der Lösbarkeitsprüfung verwendet.
##
## Das ist kein Sparen an Code, sondern eine Zusicherung: der erste Anlauf
## hatte zwei Sucher mit verschiedener Winkelauflösung - 150 gegen 180. Die
## Suche meldete Kammern als gelöst, die der Prüfer danach für unlösbar hielt.
## Zwei getrennte Rechnungen über dieselbe Frage driften immer auseinander.
## Dasselbe Prinzip wie bei Zielvorschau und Flug.
class_name Sucher
extends RefCounted

## Geprüfte Richtungen je Schuss.
const WINKEL := 180

## Geprüfte Zugstärken je Richtung.
const STAERKEN: PackedFloat32Array = [0.3, 0.5, 0.7, 0.85, 1.0]

const STRECKE_MIN := 900.0
const STRECKE_MAX := 3400.0


## Spielt eine Kammer durch.
##
## Gibt zurück: geschafft, uebrig, schuesse, knoten, sporen.
static func spiele(nummer: int, versatz: int = -1) -> Dictionary:
    var plan := KammerDaten.baue(nummer, versatz)
    var k: Node = load("res://scripts/spiel/kammer.gd").new()
    k.setze(plan)

    var uebrig := plan.sporen
    var schuesse := 0

    while uebrig > 0 and k.knoten_uebrig() > 0:
        var bahn := bester_schuss(k, plan)
        if bahn.is_empty():
            # Kein Schuss trifft mehr etwas. Trotzdem feuern: die Spuren altern
            # dadurch, und der verbaute Weg kann sich wieder öffnen.
            bahn = flugbahn(k, plan, PI * 0.5, 0.7)
        uebrig -= 1
        schuesse += 1
        k.pruefe_bahn(bahn, Spore.RADIUS)
        k.lege_spur(bahn)

    var ergebnis := {
        "geschafft": k.knoten_uebrig() == 0,
        "uebrig": uebrig,
        "schuesse": schuesse,
        "knoten": plan.knoten.size(),
        "sporen": plan.sporen,
    }
    k.free()
    return ergebnis


## Sucht den Schuss, der die meisten Knoten trifft.
##
## Gierig, nicht optimal - ein Mensch denkt weiter voraus. Was der Sucher
## schafft, schafft ein Spieler erst recht; die Prüfung ist also konservativ.
static func bester_schuss(k: Node, plan: KammerDaten.Bauplan) -> PackedVector2Array:
    var beste := PackedVector2Array()
    var meiste := 0
    for i in WINKEL:
        # Nur nach oben zielen; nach unten steht sofort die Wand.
        var winkel := PI + PI * float(i) / float(WINKEL - 1)
        for staerke in STAERKEN:
            var bahn := flugbahn(k, plan, winkel, staerke)
            var treffer := zaehle(k, bahn)
            if treffer > meiste:
                meiste = treffer
                beste = bahn
    return beste if meiste > 0 else PackedVector2Array()


static func flugbahn(k: Node, plan: KammerDaten.Bauplan, winkel: float,
        staerke: float) -> PackedVector2Array:
    return Ballistik.flug(KammerDaten.WERFER, Vector2(cos(winkel), sin(winkel)),
        k.alle_waende(), plan.abpraller,
        lerpf(STRECKE_MIN, STRECKE_MAX, staerke)).punkte


## Zählt Treffer, ohne die Kammer zu verändern.
static func zaehle(k: Node, bahn: PackedVector2Array) -> int:
    var offen: PackedVector2Array = k._knoten
    var getroffen := {}
    var reichweite := KammerDaten.KNOTEN_R + Spore.RADIUS
    for p in Ballistik.abtasten(bahn, Spore.RADIUS):
        for i in offen.size():
            if not getroffen.has(i) and offen[i].distance_to(p) <= reichweite:
                getroffen[i] = true
    return getroffen.size()
