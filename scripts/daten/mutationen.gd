class_name Mutationen
extends RefCounted

## Damit auch die Raeuber nicht ausgehen.
##
## Der Graben hat keinen Boden mehr - die Wellen laufen weiter, solange jemand
## spielt. Neun gezeichnete Arten laufen aber sehr wohl aus: wer die zweite
## Umdrehung beginnt, hat jede von ihnen hundertmal gesehen. Neue Arten
## nachzuzeichnen ist der teuerste denkbare Weg, mehr vom Gleichen zu
## erzeugen, und irgendwann ist auch er zu Ende.
##
## Stattdessen mutiert der Graben, was schon da ist. Eine Mutation ist ein
## Zug, den eine ganze Welle traegt: ihre Raeuber sind gepanzert, oder sie
## meiden Licht, oder sie treiben quer. Die Bausteine dafuer gibt es alle
## schon - `panzer`, `mindest_licht`, `drift`, `stoss` sind die vier
## Eigenschaften, mit denen die spaeten Arten gebaut sind. Sie auf eine
## fruehe Art zu legen, macht aus einem bekannten Tier ein neues Problem,
## ohne einen einzigen neuen Strich zu zeichnen.
##
## **Die erste Umdrehung bleibt frei davon.** Wer die Arten noch nicht kennt,
## kann nicht sehen, was an ihnen anders ist - eine Mutation waere dann keine
## Abwechslung, sondern eine unerklaerliche Niederlage.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Mutation {
    PANZERUNG,      ## Haut, die Licht abweist
    LICHTSCHEU,     ## nimmt erst ab einer Helligkeit ueberhaupt Schaden
    UNSTET,         ## treibt quer aus dem Kegel
    SCHUB,          ## stoesst sich stossweise vorwaerts
    HAST,           ## schlicht schneller
    AUFGEDUNSEN,    ## weniger, dafuer groesser und zaeher
}

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "Plated", "Lightshy", "Erratic", "Surging", "Swift", "Bloated",
]

## Ein Satz, der sagt, was zu tun ist. Steht im Wellenkopf, bevor es losgeht -
## eine Regel, die man sich erspielen muss, ist keine Regel, sondern eine
## Falle.
const HINWEISE: PackedStringArray = [
    "Their skin turns light aside. Hold the cone still.",
    "Dim light does nothing to them. Keep them in the core.",
    "They drift sideways out of the beam. Lead them.",
    "They surge forward in bursts. Do not follow, wait.",
    "Everything comes faster. Sweep less, hold longer.",
    "Fewer, larger, tougher. One at a time.",
]

## Ab der zweiten Umdrehung. Davor bleibt der Graben so, wie man ihn lernt.
const AB_ZYKLUS := 1

## Mehr als drei Zuege auf einmal sind kein Charakter mehr, sondern Rauschen.
const HOECHSTENS := 3

## Eigene Saat, damit sich die Mutationen aendern lassen, ohne dass sich die
## Zusammensetzung jeder Welle mitverschiebt.
const SAAT := 0x4d555400


## --- Wie stark ---
##
## Alle Staerken sind Anteile, keine festen Zahlen. Ein fester Panzerwert
## waere in Welle 70 eine Wand und in Welle 700 nicht mehr zu bemerken.

## Panzer als Anteil der Leistung, die der Kegel bei voller Helligkeit auf ein
## Ziel bringt. Abgeleitet aus der Sollkurve, nicht gewaehlt - genau wie das
## Leben eines Leitwesens.
const PANZER_ANTEIL := 0.14

## Helligkeit, unter der eine lichtscheue Welle gar nichts abbekommt.
const LICHT_SCHWELLE := 0.42

const DRIFT_ZUSATZ := 0.55
const STOSS_ZUSATZ := 0.45
const HAST_FAKTOR := 1.22
const AUFGEDUNSEN_LEBEN := 1.6
const AUFGEDUNSEN_RADIUS := 1.35


## Was jede Mutation den Spieler an Wirkungsgrad kostet.
##
## **Ohne das ist jede Mutation eine Wand.** `Wellen.staerke()` leitet das
## Budget einer Welle aus dem ab, was ein Spieler leisten kann; kennt sie die
## Mutationen nicht, bekommt eine gepanzerte Welle genauso viele Raeuber wie
## eine nackte. Bei den Abschnittsregeln hat genau dieses Versaeumnis fuenf
## gefallene Sitzungen ab Welle 36 gekostet - siehe `Regeln.wirkungsgrad`.
##
## Gemessen am Wellenpruefer, nicht geschaetzt.
##
## `AUFGEDUNSEN` stand hier auf 1.0, weil ein groesseres Ziel leichter im
## Kegel zu halten sei, als ein zaeheres schwer zu toeten. Das war falsch, und
## der Wellenpruefer hat es sofort gezeigt: **jede einzelne gefallene Sitzung
## lag auf einer aufgedunsenen Welle.** Der Grund liegt nicht am einzelnen
## Tier, sondern an der Zahl: das Budget einer Welle ist Lebenspunkte, also
## bringt zaeheres Leben weniger Tiere. Der Kegel fasst aber `Ausbau.ziele()`
## Ziele gleichzeitig - stehen weniger davon im Wasser, verfaellt der Rest
## seiner Leistung ungenutzt. Genau das kostet eine aufgedunsene Welle.
const WIRKUNGSGRAD: PackedFloat32Array = [0.87, 0.88, 0.93, 0.94, 0.90, 0.80]


static func name_von(m: int) -> String:
    return NAMEN[clampi(m, 0, NAMEN.size() - 1)]


static func hinweis(m: int) -> String:
    return HINWEISE[clampi(m, 0, HINWEISE.size() - 1)]


## Wie viele Zuege eine Welle dieser Tiefe traegt: einer je Umdrehung, bis
## `HOECHSTENS`.
static func zahl_in(nummer: int) -> int:
    return clampi(Graben.zyklus(nummer) - AB_ZYKLUS + 1, 0, HOECHSTENS)


## Welche Mutationen Welle `nummer` traegt - gerechnet, nicht gewuerfelt, aus
## demselben Grund wie die Zusammensetzung der Welle selbst: der Wellenpruefer
## muss dieselbe Welle durchrechnen koennen, die beim Spieler ankommt, und
## alle Spieler sollen dieselbe Welle 137 sehen.
static func in_welle(nummer: int) -> PackedInt32Array:
    var wieviele := zahl_in(nummer)
    var liste := PackedInt32Array()
    if wieviele <= 0:
        return liste

    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + nummer * 104729
    var uebrig: PackedInt32Array = []
    for m in Mutation.size():
        uebrig.append(m)
    for _i in wieviele:
        if uebrig.is_empty():
            break
        var w := rng.randi_range(0, uebrig.size() - 1)
        liste.append(uebrig[w])
        uebrig.remove_at(w)
    liste.sort()
    return liste


static func hat(nummer: int, m: int) -> bool:
    return m in in_welle(nummer)


## Der gemeinsame Wirkungsgrad aller Zuege dieser Welle.
static func wirkungsgrad(nummer: int) -> float:
    var f := 1.0
    for m in in_welle(nummer):
        f *= WIRKUNGSGRAD[clampi(m, 0, WIRKUNGSGRAD.size() - 1)]
    return f
