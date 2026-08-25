## Kurzlebiger Partikelausbruch, prozedural gezeichnet.
##
## Kein Partikelsystem und keine Sprite-Blätter: bei dieser Menge und Lebenszeit
## ist ein Array aus Punkten schneller als ein GPUParticles2D mit Textur - und
## es entsteht keine Datei, deren Herkunft belegt werden müsste.
class_name Funken
extends Node2D

## Ein einzelner Funke: Ort, Geschwindigkeit, Alter, Lebensdauer.
var _teilchen: Array[Dictionary] = []
var _farbe := Color.WHITE


## Streut [param anzahl] Funken um [param richtung].
##
## [param streuung] ist der halbe Öffnungswinkel in Bogenmaß; PI streut rundum.
func starte(anzahl: int, richtung: Vector2, streuung: float, farbe: Color,
        tempo: float = 260.0) -> void:
    _farbe = farbe
    var grund := richtung.angle() if richtung.length_squared() > 0.001 else 0.0
    for i in anzahl:
        var a := grund + randf_range(-streuung, streuung)
        var v := randf_range(0.45, 1.0) * tempo
        _teilchen.append({
            "ort": Vector2.ZERO,
            "v": Vector2(cos(a), sin(a)) * v,
            "alter": 0.0,
            "leben": randf_range(0.22, 0.46),
        })
    set_process(true)


func _process(delta: float) -> void:
    var lebt := false
    for t in _teilchen:
        t["alter"] = float(t["alter"]) + delta
        if float(t["alter"]) >= float(t["leben"]):
            continue
        lebt = true
        var v: Vector2 = t["v"]
        t["ort"] = Vector2(t["ort"]) + v * delta
        # Abbremsen, damit die Funken auslaufen statt davonzuschießen.
        t["v"] = v * (1.0 - 3.4 * delta)
    if not lebt:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    for t in _teilchen:
        var anteil := float(t["alter"]) / float(t["leben"])
        if anteil >= 1.0:
            continue
        var f := _farbe
        f.a = pow(1.0 - anteil, 1.6)
        var ort: Vector2 = t["ort"]
        var v: Vector2 = t["v"]
        # Als kurzer Strich in Flugrichtung statt als Punkt: das liest sich als
        # Geschwindigkeit, ein Punkt nur als Fleck.
        draw_line(ort, ort - v * 0.016, f, 2.2 * (1.0 - anteil * 0.6), true)
