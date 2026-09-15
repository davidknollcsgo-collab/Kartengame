class_name Riff
extends RefCounted

## Die Form eines Felsens - **einmal**, fuer Bild und Kollision.
##
## Der Grund, warum das hier steht und nicht im Zeichenskript: ein Fels, der
## anders aussieht als er sich anfuehlt, ist unlernbar. Dieselbe Regel, die im
## Schlund fuer den Kegel gilt (`Schlund.beleuchtung()` bestimmt Bild **und**
## Schaden), gilt hier fuer den Umriss. Zwei Beschreibungen derselben Kante
## laufen auseinander - das ist in diesem Projekt schon dreimal passiert.
##
## Ein Fels ist deshalb kein Punktehaufen, sondern eine Handvoll Zahlen, und
## `radius()` macht daraus die Kante. Das Zeichenskript tastet sie in 48
## Schritten ab, die Kollision fragt sie an genau einem Winkel - beide sehen
## denselben Stein.
##
## Reine Rechnung, keine Szenen- und keine Autoload-Bezuege.


## Ein Fels als Woerterbuch: `ort`, `gross`, drei Amplituden, drei Phasen,
## zwei Wellenzahlen. `bauen()` legt eins an, damit die Schluessel an genau
## einer Stelle stehen.
static func bauen(rng: RandomNumberGenerator, ort: Vector2,
        gross: float) -> Dictionary:
    return {
        &"ort": ort,
        &"gross": gross,
        &"a1": rng.randf_range(0.07, 0.16),
        &"a2": rng.randf_range(0.04, 0.11),
        &"a3": rng.randf_range(0.02, 0.06),
        &"p1": rng.randf_range(0.0, TAU),
        &"p2": rng.randf_range(0.0, TAU),
        &"p3": rng.randf_range(0.0, TAU),
        &"n1": float(rng.randi_range(2, 3)),
        &"n2": float(rng.randi_range(5, 6)),
        # **Die Streckung, und sie ist der Grund, warum es diese Zeilen
        # gibt.** Ohne sie ist `radius()` radialsymmetrisch: ein Kreis mit
        # einer Welle darauf, und `gross` ist eine einzige Zahl. Gemessen
        # ueber 190 Felsen lag Laenge zu Breite im Median bei **1,48**, und
        # **kein einziger** kam ueber 2,0 - also vierzig gleiche Kleckse im
        # Bild, die groessten Formen der ganzen Szene.
        #
        # Die Regel dagegen steht in CLAUDE.md, aufgeschrieben fuer die
        # Tiere: *Laenge und Breite muessen sich um mehr als das Doppelte
        # unterscheiden, oder der Umriss muss Ecken haben.* Ecken sind hier
        # ausgeschlossen (gerade Kanten waeren ein Kristall, siehe
        # `radius()`), also bleibt die Streckung.
        #
        # Sie ist **flaechentreu**: die Halbachsen sind `sqrt(s)` und
        # `1/sqrt(s)`, ihr Produkt ist eins. Ein langer Ruecken nimmt damit
        # nicht mehr Platz ein als ein Findling derselben `gross` - sonst
        # waere die Streckung zugleich ein Groessenregler, und die Dichte
        # des Feldes haenge an ihr.
        #
        # Die meisten bleiben rundlich (`pow`, 1,6), einige wenige werden
        # zu Ruecken. Ein Feld, in dem *jeder* Stein gestreckt ist, ist
        # wieder ein Muster.
        &"dehn": 1.0 + pow(rng.randf(), 1.6) * 2.2,
        &"dehn_winkel": rng.randf_range(0.0, TAU),
    }


## Der flaechentreue Streckfaktor in Richtung `winkel`.
##
## Eine Ellipse mit den Halbachsen `a` und `b` hat bei `t` den Radius
## `a·b / sqrt(b²cos²t + a²sin²t)`. Mit `a·b = 1` bleibt die Flaeche gleich,
## und der Ausdruck bleibt eine **reine Funktion des Winkels** - das ist die
## Bedingung, unter der `beruehrt()` und `abgestossen()` unveraendert weiter
## gelten und Bild und Kollision derselbe Stein bleiben.
static func streckung(fels: Dictionary, winkel: float) -> float:
    var s := float(fels.get(&"dehn", 1.0))
    if s <= 1.0001:
        return 1.0
    var a := sqrt(s)
    var b := 1.0 / a
    var t := winkel - float(fels.get(&"dehn_winkel", 0.0))
    var c := b * cos(t)
    var d := a * sin(t)
    return 1.0 / sqrt(c * c + d * d)


## Der Abstand vom Mittelpunkt zur Kante in Richtung `winkel`.
##
## Drei Sinus mit unrunden Vielfachen - unregelmaessig und glatt zugleich,
## und im sichtbaren Bereich wiederholt sich nichts. Ein Kreis waere ein
## Kiesel; gerade Kanten waeren ein Kristall.
static func radius(fels: Dictionary, winkel: float) -> float:
    return float(fels[&"gross"]) * streckung(fels, winkel) * (1.0
        + float(fels[&"a1"]) * sin(float(fels[&"n1"]) * winkel + float(fels[&"p1"]))
        + float(fels[&"a2"]) * sin(float(fels[&"n2"]) * winkel + float(fels[&"p2"]))
        + float(fels[&"a3"]) * sin(9.0 * winkel + float(fels[&"p3"])))


## Der groesste Radius, den dieser Fels annehmen kann. Fuer die Vorauswahl:
## was weiter weg ist als das, kann nicht beruehren.
## Die Streckung geht mit ihrem **groessten** Wert ein (`sqrt(dehn)`, auf der
## langen Achse) - der Deckel muss ueber jedem Winkel liegen, sonst keult die
## Vorauswahl einen Fels weg, an dem man gerade anstoesst.
static func hoechster_radius(fels: Dictionary) -> float:
    return float(fels[&"gross"]) * sqrt(float(fels.get(&"dehn", 1.0))) \
        * (1.0 + float(fels[&"a1"])
        + float(fels[&"a2"]) + float(fels[&"a3"]))


## Ob ein Koerper vom Radius `dick` an `ort` den Fels beruehrt.
static func beruehrt(fels: Dictionary, ort: Vector2, dick: float) -> bool:
    var versatz: Vector2 = ort - fels[&"ort"]
    var weite := versatz.length()
    if weite > hoechster_radius(fels) + dick:
        return false
    if weite < 0.001:
        return true
    return weite < radius(fels, versatz.angle()) + dick


## Schiebt einen Koerper aus dem Fels heraus - nach aussen, auf dem kuerzesten
## Weg.
##
## **Herausschieben und nicht anhalten.** Wer anhaelt, klebt am Stein und ist
## trivial zu treffen; wer herausgeschoben wird, gleitet daran entlang. Es ist
## dieselbe Ueberlegung, aus der `Schlund.gespiegelt()` am Rand spiegelt statt
## zu kappen.
static func abgestossen(fels: Dictionary, ort: Vector2,
        dick: float) -> Vector2:
    var versatz: Vector2 = ort - fels[&"ort"]
    var weite := versatz.length()
    if weite < 0.001:
        # Genau im Mittelpunkt gibt es keine Richtung. Irgendeine nehmen ist
        # besser als durch null zu teilen.
        versatz = Vector2.RIGHT
        weite = 0.001
    var soll := radius(fels, versatz.angle()) + dick
    if weite >= soll:
        return ort
    return Vector2(fels[&"ort"]) + versatz / weite * soll
