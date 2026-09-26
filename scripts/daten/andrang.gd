class_name Andrang
extends RefCounted

## **Wie der Druck steigt.**
##
## Ein Lauf ist eine Kurve und keine Liste. Was hier steht, sagt für jeden
## Augenblick: wie viele kommen je Sekunde, und welche Sorten überhaupt schon
## im Feld sind.
##
## **Die Sorten kommen einzeln dazu, nicht alle auf einmal.** Wer in der
## ersten Minute schon Schützen, Treiber und Ritter gleichzeitig trifft,
## lernt keinen von ihnen - er lernt nur, dass es voll ist. Jede neue Sorte
## bekommt deshalb ihre eigene halbe Minute, in der sie die einzige Neuigkeit
## ist.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezüge.

## Wie lange ein Lauf dauert, bis der Warlord kommt.
const LAUF_SEKUNDEN := 600.0

## Wann der Warlord auftritt, und wie lange man vorher Ruhe hat: die letzte
## halbe Minute läuft leer, damit er nicht in eine volle Horde hineinfällt.
## Ein Höhepunkt, den man im Gedränge nicht sieht, ist keiner.
const WARLORD_ZEIT := LAUF_SEKUNDEN - 30.0

## **Wie viele höchstens leben.** Ist die Zahl erreicht, kommt nichts nach.
##
## Gemessen an der Rechenzeit je `Gefecht.schritt()` auf dem Entwicklungs-
## rechner, mit Abstoßung: 200 Lebende 1,3 ms, 400 Lebende 2,7 ms, 800
## Lebende 5,8 ms. Dreihundert sind rund zwei Millisekunden - auf einem
## Telefon ein Mehrfaches, und das Zeichnen kommt noch dazu. Vorher gab es
## keine Grenze, und in Minute neun lebten 3000.
const HOECHSTENS_LEBEND := 300

## Eintritte je Sekunde, von bequem auf dicht.
## **1,3 statt 1,6**, seit die Horde beim Helden bleibt: was vorher in der
## Schleppe außer Sicht verpuffte, kommt jetzt an.
const RATE_ANFANG := 1.3
const RATE_ENDE := 11.0

## Alle so viele Sekunden ein Schwall: dreifache Rate für ein paar Sekunden.
## Ein gleichmäßiger Strom ist ein Förderband; ein Lauf braucht Atemzüge und
## Augenblicke, in denen es eng wird.
const SCHWALL_TAKT := 72.0
const SCHWALL_DAUER := 7.0
const SCHWALL_STAERKE := 3.2

## Ab welcher Sekunde eine Sorte überhaupt auftritt.
const AB: PackedFloat32Array = [
    0.0,     ## Strolch
    45.0,    ## Wolf
    110.0,   ## Spießer
    185.0,   ## Armbruster
    270.0,   ## Treiber
    355.0,   ## Ritter
    WARLORD_ZEIT,
]

## Wie oft eine Sorte gezogen wird, sobald sie da ist. Der Strolch bleibt
## häufig: er ist die Masse, gegen die man sich aufstellt, und ohne Masse
## schlägt keine Waffe ins Leere.
const GEWICHT: PackedFloat32Array = [5.0, 3.2, 2.2, 1.5, 0.7, 1.2, 0.0]


static func rate(zeit: float) -> float:
    var t := clampf(zeit / LAUF_SEKUNDEN, 0.0, 1.0)
    var grund := lerpf(RATE_ANFANG, RATE_ENDE, pow(t, 0.85))
    if ist_schwall(zeit):
        grund *= SCHWALL_STAERKE
    return grund


static func ist_schwall(zeit: float) -> bool:
    if zeit < SCHWALL_TAKT * 0.5:
        return false
    return fmod(zeit, SCHWALL_TAKT) < SCHWALL_DAUER


## **Wie zäh die Horde in diesem Augenblick ist.** Ein Feind, der in Minute
## neun genauso schnell fällt wie in Minute eins, macht den zweiten Teil des
## Laufs zur Mähwiese - und die Waffenstufen, die man bis dahin gewählt hat,
## bedeutungslos. Multipliziert auf Leben, nicht auf Schaden: wer härter
## zuschlägt, soll das merken, aber niemand soll aus dem Nichts sterben.
static func zaehigkeit(zeit: float) -> float:
    return 1.0 + 2.6 * pow(clampf(zeit / LAUF_SEKUNDEN, 0.0, 1.0), 1.45)


## Welche Sorten jetzt auftreten dürfen (ohne den Warlord).
static func verfuegbar(zeit: float) -> PackedInt32Array:
    var liste := PackedInt32Array()
    for a in Feinde.Art.size():
        if Feinde.ist_warlord(a):
            continue
        if zeit >= AB[a]:
            liste.append(a)
    return liste


## Eine Sorte ziehen - gewichtet, und mit einem Vorzug für die jüngste.
##
## **Die neueste Sorte kommt in ihrer ersten halben Minute doppelt so oft.**
## Sonst führt man sie zwar ein, aber der Spieler sieht sie zwischen
## dreißig Strolchen nicht und lernt sie nie.
const NEULING_FENSTER := 30.0
const NEULING_VORZUG := 2.2

static func ziehe(zeit: float, rng: RandomNumberGenerator) -> int:
    var moeglich := verfuegbar(zeit)
    if moeglich.is_empty():
        return Feinde.Art.STROLCH
    var summe := 0.0
    var gewichte := PackedFloat32Array()
    for a in moeglich:
        var g := GEWICHT[a]
        if zeit - AB[a] < NEULING_FENSTER:
            g *= NEULING_VORZUG
        gewichte.append(g)
        summe += g
    var wurf := rng.randf() * summe
    for i in moeglich.size():
        wurf -= gewichte[i]
        if wurf <= 0.0:
            return moeglich[i]
    return moeglich[moeglich.size() - 1]
