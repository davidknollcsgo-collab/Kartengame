class_name Bluete
extends RefCounted

## Eine Funkenbluete im Schlund.
##
## Kein Raeuber: sie greift nichts an, sinkt nicht und steht in keinem
## Wellenbudget. Sie treibt quer durchs Bild und geht wieder. Wer sie will,
## muss den Kegel von der Bahn der Raeuber nehmen - das ist ihr ganzer Zweck.
##
## Eigene Datei mit `class_name` aus demselben Grund wie `Raeuber`: `wache.gd`
## fuehrt sie, `schwarm.gd` zeichnet sie, und als verschachtelte Klasse kaeme
## beim Zeichnen nur `Variant` an.

## Sekunden ab Wellenbeginn, zu denen sie eintritt.
var eintritt: float = 0.0

## Von welcher Seite sie kommt: -1 links, 1 rechts.
var seite: float = 1.0

var bahn_y: float = 0.0
var hub: float = 40.0
var phase: float = 0.0

var leben: float = 1.0
var leben_voll: float = 1.0
var lebendig: bool = true

## Sekunden seit dem Eintritt. Negativ, solange sie noch nicht da ist.
var alter: float = -1.0

var ort := Vector2.ZERO

## Wie hell sie gerade im Kegel steht - dieselbe Zahl, aus der auch der
## Schaden faellt.
var licht: float = 0.0
var hitze: float = 0.0


func anteil() -> float:
    return clampf(leben / maxf(0.001, leben_voll), 0.0, 1.0)


## Wo sie zum Zeitpunkt `seit` steht. Eine Gerade quer durchs Bild mit einem
## flachen Heben und Senken darauf - eine schnurgerade Bahn liest sich als
## Geschoss, eine wellige als etwas, das treibt.
func ort_bei(seit: float) -> Vector2:
    var weit := Graben.FELD.size.x * 0.5 + 90.0
    var t := clampf(seit / Wellen.BLUETE_DAUER, 0.0, 1.0)
    return Vector2(
        lerpf(-seite * weit, seite * weit, t),
        bahn_y + sin(seit * 0.9 + phase) * hub)


## Ob sie das Bild verlassen hat.
func vorbei(seit: float) -> bool:
    return seit >= Wellen.BLUETE_DAUER
