## Aufsteigende Zahl als Rückmeldung auf eine Gutschrift.
##
## Ohne sie fühlt sich das Antippen des Kerns nach nichts an: die Zahl oben im
## Kopfbereich springt zwar, aber der Blick liegt beim Tippen auf dem Finger,
## nicht am oberen Rand. Die Rückmeldung muss dort erscheinen, wo getippt wurde.
class_name SchwebeZahl
extends Node2D

## Lebensdauer in Sekunden.
const DAUER := 1.1

## Strecke, die die Zahl in dieser Zeit zurücklegt.
const STRECKE := 62.0

var _text := ""
var _farbe := Color.WHITE
var _art := Waehrung.Art.PLASMA
var _alter := 0.0


## Setzt Text und Farbe und startet den Aufstieg.
func starte(text: String, farbe: Color, art: Waehrung.Art) -> void:
    _text = text
    _farbe = farbe
    _art = art
    _alter = 0.0


func _process(delta: float) -> void:
    _alter += delta
    if _alter >= DAUER:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var t := _alter / DAUER
    # Schnell weg vom Finger, dann auslaufen - eine gleichmäßige Bewegung wirkt
    # träge, weil der Blick die erste Hälfte gar nicht mitbekommt.
    var hoehe := STRECKE * (1.0 - pow(1.0 - t, 2.4))
    var farbe := _farbe
    farbe.a = 1.0 - pow(t, 2.0)

    var schrift := Schrift.titel()
    Waehrung.zeichne(self, schrift, Vector2(0.0, -hoehe), _text, _art, 20,
        farbe, Waehrung.Lage.MITTE)
