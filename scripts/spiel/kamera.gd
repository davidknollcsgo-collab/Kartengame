## Kamera mit Erschütterung.
##
## Die Erschütterung ist kurz und klein - drei bis sechs Punkte, unter einer
## Zehntelsekunde. Länger oder stärker wirkt sie nicht kräftiger, sondern nur
## unruhig, und auf einem Handy wird sie schnell unangenehm.
class_name Kamera
extends Camera2D

var _staerke := 0.0
var _ruhe := Vector2.ZERO


func _ready() -> void:
    _ruhe = position
    set_process(true)


## Löst eine Erschütterung aus. [param staerke] in Bildpunkten.
func ruettle(staerke: float) -> void:
    _staerke = maxf(_staerke, staerke)


func _process(delta: float) -> void:
    if _staerke <= 0.01:
        if offset != Vector2.ZERO:
            offset = Vector2.ZERO
        return
    offset = Vector2(randf_range(-_staerke, _staerke), randf_range(-_staerke, _staerke))
    # Schnell abklingen: die Erschütterung soll den Treffer betonen, nicht
    # danach noch nachwackeln.
    _staerke = maxf(_staerke - delta * 42.0, 0.0)
