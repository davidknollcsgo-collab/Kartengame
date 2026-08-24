## Frachtdrohne, die zwischen einer Baugruppe und dem Kern pendelt.
##
## Rein dekorativ - sie transportiert nichts, was die Rechnung beeinflusst.
## Ihr Zweck ist Rueckmeldung: eine Station, auf der sich nichts bewegt, wirkt
## kaputt, auch wenn die Zahlen laufen.
class_name Drohne
extends Node2D

const TEMPO := 150.0

var von := Vector2.ZERO
var nach := Vector2.ZERO
var farbe := Color.WHITE

var _fortschritt := 0.0
var _rueckweg := false


## Setzt die Drohne auf eine neue Strecke.
func starte(a: Vector2, b: Vector2, f: Color, versatz: float = 0.0) -> void:
    von = a
    nach = b
    farbe = f
    _fortschritt = versatz
    _rueckweg = false


func _process(delta: float) -> void:
    var strecke := von.distance_to(nach)
    if strecke < 1.0:
        return
    _fortschritt += delta * TEMPO / strecke
    if _fortschritt >= 1.0:
        _fortschritt = 0.0
        _rueckweg = not _rueckweg

    var a := nach if _rueckweg else von
    var b := von if _rueckweg else nach
    position = a.lerp(b, _fortschritt)
    rotation = (b - a).angle()
    queue_redraw()


func _draw() -> void:
    # Beladen auf dem Hinweg, leer auf dem Rueckweg - die Richtung bleibt so
    # auch bei einem kurzen Blick erkennbar.
    var koerper := farbe if not _rueckweg else farbe.darkened(0.45)
    # Bewusst groesser als "realistisch": auf einem Handydisplay verschwindet
    # ein zwei Pixel grosser Punkt neben den leuchtenden Baugruppen.
    draw_colored_polygon(PackedVector2Array([
        Vector2(11, 0), Vector2(-6, 6), Vector2(-3, 0), Vector2(-6, -6),
    ]), koerper)
    if not _rueckweg:
        draw_circle(Vector2(-7, 0), 3.0, farbe.lightened(0.45))
