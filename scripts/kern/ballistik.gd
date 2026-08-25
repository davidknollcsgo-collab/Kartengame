## Die Abprallrechnung. Reine Mathematik, kein Szenenbezug.
##
## Diese Datei ist das Herz des Spiels. Sie berechnet, wohin eine Spore fliegt,
## wenn sie in einer Kammer voller Wände abprallt.
##
## **Vorschau und echter Flug rufen dieselbe Funktion auf.** Das ist keine
## Bequemlichkeit, sondern die zentrale Zusicherung des Spiels: eine Zielhilfe,
## die etwas anderes zeigt als das, was dann passiert, macht ein Puzzlespiel
## unspielbar. Zwei getrennte Rechnungen driften unweigerlich auseinander.
class_name Ballistik
extends RefCounted

## Sicherheitsabstand, mit dem der Auftreffpunkt von der Wand weggerückt wird.
##
## Ohne ihn trifft der nächste Abschnitt dieselbe Wand sofort wieder, weil der
## Startpunkt rechnerisch genau darauf liegt. Der klassische Fehler bei
## Abprallrechnungen - die Spore bleibt dann in der Wand kleben.
const ABSTAND := 0.08

## Kleinste anerkannte Flugstrecke bis zum nächsten Treffer.
##
## Fängt den Fall ab, dass zwei Wände sich in einer Ecke berühren und die Spore
## zwischen ihnen hin und her springt, ohne voranzukommen.
const MIN_STRECKE := 0.02


## Ergebnis eines Flugs.
class Flug extends RefCounted:
    ## Streckenzug des Flugs, beginnend mit dem Startpunkt.
    var punkte: PackedVector2Array = []

    ## Index der getroffenen Wand je Abprall, gleiche Reihenfolge wie die
    ## Punkte ab dem zweiten.
    var waende: PackedInt32Array = []

    ## Ob der Flug endete, weil die Abpraller aufgebraucht waren.
    var abpraller_erschoepft := false


## Berechnet den Flug einer Spore.
##
## [param waende] ist eine flache Liste von Punktepaaren: je zwei aufeinander
## folgende Vector2 bilden ein Wandsegment. Flach statt verschachtelt, weil
## PackedVector2Array deutlich schneller ist als ein Array von Arrays - und die
## Funktion wird bei jeder Zielbewegung neu gerufen.
##
## Der Flug endet, wenn die Abpraller aufgebraucht sind oder die Reststrecke
## null erreicht.
static func flug(start: Vector2, richtung: Vector2, waende: PackedVector2Array,
        max_abpraller: int, max_strecke: float) -> Flug:
    var e := Flug.new()
    e.punkte.append(start)

    var ort := start
    var dir := richtung.normalized()
    var rest := max_strecke
    var abpraller := 0

    # Die zuletzt getroffene Wand wird beim nächsten Schritt übersprungen.
    # Der Abstand allein genügt bei sehr flachen Winkeln nicht.
    var letzte := -1

    while abpraller <= max_abpraller and rest > MIN_STRECKE:
        var treffer := _naechster_treffer(ort, dir, waende, rest, letzte)
        var index := int(treffer.z)

        if index < 0:
            # Freie Bahn bis zum Ende der Reststrecke.
            e.punkte.append(ort + dir * rest)
            return e

        var punkt := Vector2(treffer.x, treffer.y)
        var strecke := ort.distance_to(punkt)
        rest -= strecke

        if abpraller == max_abpraller:
            # Der letzte erlaubte Treffer beendet den Flug an der Wand.
            e.punkte.append(punkt)
            e.waende.append(index)
            e.abpraller_erschoepft = true
            return e

        var normale := _normale(waende, index, dir)
        dir = dir.bounce(normale).normalized()
        ort = punkt + normale * ABSTAND
        e.punkte.append(punkt)
        e.waende.append(index)
        letzte = index
        abpraller += 1

    e.punkte.append(ort)
    return e


## Sucht den nächsten Wandtreffer.
##
## Gibt (x, y, index) zurück; index ist -1, wenn nichts getroffen wird.
## Ein Vector3 statt eines Dictionary, weil diese Funktion in der inneren
## Schleife steckt und pro Zielbewegung hunderte Male läuft.
static func _naechster_treffer(ort: Vector2, dir: Vector2,
        waende: PackedVector2Array, rest: float, ausser: int) -> Vector3:
    var beste := rest
    var punkt := Vector2.ZERO
    var index := -1

    var anzahl := waende.size() / 2
    for i in anzahl:
        if i == ausser:
            continue
        var t := _strahl_segment(ort, dir, waende[i * 2], waende[i * 2 + 1])
        if t < 0.0 or t >= beste or t < MIN_STRECKE:
            continue
        beste = t
        punkt = ort + dir * t
        index = i

    return Vector3(punkt.x, punkt.y, float(index))


## Entfernung vom Strahlursprung bis zum Segment, oder -1 ohne Schnitt.
static func _strahl_segment(ort: Vector2, dir: Vector2, a: Vector2, b: Vector2) -> float:
    var kante := b - a
    var nenner := dir.cross(kante)
    # Nenner nahe null: Strahl und Segment sind parallel.
    if absf(nenner) < 0.000001:
        return -1.0

    var zu_a := a - ort
    var t := zu_a.cross(kante) / nenner      # Strecke entlang des Strahls
    var u := zu_a.cross(dir) / nenner        # Lage auf dem Segment, 0 bis 1

    if t < 0.0 or u < 0.0 or u > 1.0:
        return -1.0
    return t


## Normale des Segments, immer der ankommenden Richtung entgegen.
##
## Ohne die Umkehr prallt eine Spore, die eine Wand von hinten trifft, in die
## Wand hinein statt von ihr weg.
static func _normale(waende: PackedVector2Array, index: int, dir: Vector2) -> Vector2:
    var kante := (waende[index * 2 + 1] - waende[index * 2]).normalized()
    var n := Vector2(-kante.y, kante.x)
    return -n if n.dot(dir) > 0.0 else n


## Wandelt einen Streckenzug in Wandsegmente um.
##
## So wird die Wurzelspur eines Schusses zur Bande für den nächsten - der
## eigentliche Kniff des Spiels.
static func als_waende(punkte: PackedVector2Array) -> PackedVector2Array:
    var w := PackedVector2Array()
    for i in range(punkte.size() - 1):
        # Entartete Abschnitte überspringen; sie hätten keine brauchbare Normale.
        if punkte[i].distance_squared_to(punkte[i + 1]) < 0.5:
            continue
        w.append(punkte[i])
        w.append(punkte[i + 1])
    return w


## Tastet einen Streckenzug in gleichmaessigen Schritten ab.
##
## Wird sowohl beim Flug als auch bei der Loesbarkeitspruefung verwendet.
## Zwei getrennte Abtastungen wuerden unterschiedlich viele Treffer finden -
## und dann sagt der Pruefer etwas anderes als das Spiel.
static func abtasten(punkte: PackedVector2Array, schritt: float) -> PackedVector2Array:
    var aus := PackedVector2Array()
    if punkte.size() < 2 or schritt <= 0.0:
        return aus
    for i in range(punkte.size() - 1):
        var a := punkte[i]
        var b := punkte[i + 1]
        var laenge := a.distance_to(b)
        var anzahl := maxi(int(ceil(laenge / schritt)), 1)
        for k in anzahl:
            aus.append(a.lerp(b, float(k) / float(anzahl)))
    aus.append(punkte[punkte.size() - 1])
    return aus


## Baut aus einem Rechteck vier Wandsegmente, im Uhrzeigersinn.
static func rechteck(r: Rect2) -> PackedVector2Array:
    var o := r.position
    var u := r.end
    return PackedVector2Array([
        Vector2(o.x, o.y), Vector2(u.x, o.y),
        Vector2(u.x, o.y), Vector2(u.x, u.y),
        Vector2(u.x, u.y), Vector2(o.x, u.y),
        Vector2(o.x, u.y), Vector2(o.x, o.y),
    ])
