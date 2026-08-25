## Höhlenhintergrund hinter der Kammer.
##
## Feuchter Fels mit vereinzelten Sporenlichtern. Bewusst ruhig und dunkel: das
## Spielfeld muss die hellste Fläche im Bild bleiben, sonst verliert sich der
## Blick.
class_name Hintergrund
extends Node2D

const LICHTER := 40

var _lichter: Array[Vector3] = []
var _zeit := 0.0


func _ready() -> void:
    var zufall := RandomNumberGenerator.new()
    zufall.seed = 20260824
    var raum := KammerDaten.FELD.grow(420.0)
    for i in LICHTER:
        _lichter.append(Vector3(
            zufall.randf_range(raum.position.x, raum.end.x),
            zufall.randf_range(raum.position.y, raum.end.y),
            zufall.randf_range(0.0, TAU)))
    set_process(true)


func _process(delta: float) -> void:
    _zeit += delta
    queue_redraw()


func _draw() -> void:
    var raum := KammerDaten.FELD.grow(600.0)
    draw_rect(raum, Color(0.027, 0.035, 0.031))

    for l in _lichter:
        var puls := 0.5 + 0.5 * sin(_zeit * 0.5 + l.z)
        var p := Vector2(l.x, l.y)
        draw_circle(p, 1.8 + 1.2 * puls, Color(0.34, 0.72, 0.66, 0.10 + 0.14 * puls))
        draw_circle(p, 0.9, Color(0.55, 0.92, 0.86, 0.22 + 0.20 * puls))
