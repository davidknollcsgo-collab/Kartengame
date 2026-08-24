## Der Stationskern in der Mitte - zugleich die Flaeche zum manuellen Anzapfen.
##
## In der Anfangsphase ist das Antippen die einzige Einnahmequelle. Deshalb
## liegt der Kern mittig und dreht sich sichtbar: er soll das Erste sein,
## worauf ein neuer Spieler tippt.
class_name Kern
extends Node2D

const RADIUS := 68.0

var _winkel := 0.0
var _blitz := 0.0


func _process(delta: float) -> void:
    _winkel = fmod(_winkel + delta * 0.35, TAU)
    if _blitz > 0.0:
        _blitz = maxf(_blitz - delta * 3.0, 0.0)
    queue_redraw()


## Loest die Rueckmeldung fuer ein Antippen aus.
func aufblitzen() -> void:
    _blitz = 1.0


func trefferflaeche() -> Rect2:
    return Rect2(position - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)


func _draw() -> void:
    var grund := Color(0.30, 0.80, 0.95)
    var hell := grund.lightened(0.25 + 0.45 * _blitz)

    # Aussenring, der sich langsam dreht.
    var aussen := PackedVector2Array()
    for i in 6:
        var a := _winkel + TAU * float(i) / 6.0
        aussen.append(Vector2(cos(a), sin(a)) * RADIUS)
    aussen.append(aussen[0])
    draw_polyline(aussen, grund.darkened(0.25), 3.0, true)

    # Gegenlaeufiger Innenring - erzeugt Bewegung ohne Animationsdaten.
    var innen := PackedVector2Array()
    for i in 6:
        var a := -_winkel * 1.6 + TAU * float(i) / 6.0
        innen.append(Vector2(cos(a), sin(a)) * (RADIUS * 0.62))
    draw_colored_polygon(innen, Color(0.09, 0.13, 0.18))
    innen.append(innen[0])
    draw_polyline(innen, hell, 2.0, true)

    draw_circle(Vector2.ZERO, RADIUS * 0.26 + 6.0 * _blitz, hell)

    # Deutlich unterhalb des Rings: auf Kernhoehe ueberlagert die Schrift die
    # Ringe und beide werden unleserlich.
    draw_string(Schrift.text(), Vector2(-RADIUS, RADIUS + 40.0),
        "ANZAPFEN", HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 15,
        Color(0.62, 0.78, 0.90))
