## Pulsierender Ring, der auf das zeigt, was gerade zu tun ist.
##
## Sitzt im Weltraum der Station statt in der Bedienoberfläche - so folgt er
## der Kamera beim Schieben und Zoomen, ohne dass Koordinaten umgerechnet
## werden müssen.
class_name Hinweis
extends Node2D

var _text := ""
var _radius := 60.0
var _puls := 0.0


func setze(text: String, ort: Vector2, radius: float) -> void:
    _text = text
    _radius = radius
    position = ort
    visible = not text.is_empty()
    queue_redraw()


func _process(delta: float) -> void:
    if not visible:
        return
    _puls = fmod(_puls + delta, TAU)
    queue_redraw()


func _draw() -> void:
    if _text.is_empty():
        return
    var schlag := 0.5 + 0.5 * sin(_puls * 2.2)
    var farbe := Color(0.98, 0.86, 0.42)

    # Zwei Ringe, die nach außen laufen - ein einzelner Ring wirkt wie eine
    # Auswahlmarkierung, zwei wandernde lesen sich als Aufforderung.
    for i in 2:
        var t := fmod(_puls / TAU + float(i) * 0.5, 1.0)
        var f := farbe
        f.a = 0.55 * (1.0 - t)
        draw_arc(Vector2.ZERO, _radius + t * 26.0, 0.0, TAU, 40, f, 2.5, true)

    var y := _radius + 44.0
    var breite := 220.0
    var feld := Rect2(-breite * 0.5, y - 26.0, breite, 36.0)
    draw_colored_polygon(Formen.kante(feld, 10.0), Color(0.06, 0.07, 0.10, 0.88))
    draw_polyline(Formen.kante_umriss(feld, 10.0),
        Color(farbe.r, farbe.g, farbe.b, 0.45 + 0.3 * schlag), 1.6, true)
    draw_string(Schrift.titel(), Vector2(-breite * 0.5, y), _text,
        HORIZONTAL_ALIGNMENT_CENTER, breite, 17, farbe)
