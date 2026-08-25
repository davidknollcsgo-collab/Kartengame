## Kamera ueber der Station: ziehen zum Verschieben, Rad oder Aufziehen zum Zoomen.
class_name Kamera
extends Camera2D

const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.60
const RAND := 140.0

var grenzen := Rect2()

var _zieht := false
var _finger: Dictionary = {}
var _letzter_abstand := 0.0


## Zusaetzlicher Rand, damit die Station nicht am Bildrand klebt.
const RAND_X := 70.0

## Oben die Kopfzeile (104), unten die zweireihige Bedienleiste (150). Der
## Wert deckt beide samt Abstand ab, damit die aeusseren Baugruppen nicht
## dauerhaft unter der Leiste liegen.
const RAND_Y := 300.0


## Waehlt den Anfangszoom so, dass die ganze Station ins Bild passt.
##
## Fest verdrahtete Zoomwerte gehen auf dem einen Geraet auf und auf dem
## naechsten daneben; die Bildschirmformate reichen von 16:9 bis 21:9.
func passe_ein(sichtfeld: Vector2) -> void:
    if grenzen.size.x <= 0.0 or grenzen.size.y <= 0.0:
        return
    var z := minf(
        sichtfeld.x / (grenzen.size.x + RAND_X * 2.0),
        sichtfeld.y / (grenzen.size.y + RAND_Y))
    zoom = Vector2.ONE * clampf(z, ZOOM_MIN, ZOOM_MAX)
    position = grenzen.get_center()


func _unhandled_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventMouseButton:
        var m := ereignis as InputEventMouseButton
        if m.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoome(1.1)
        elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoome(1.0 / 1.1)
        elif m.button_index == MOUSE_BUTTON_LEFT:
            _zieht = m.pressed
    elif ereignis is InputEventMouseMotion and _zieht:
        _verschiebe(-(ereignis as InputEventMouseMotion).relative / zoom)
    elif ereignis is InputEventScreenDrag:
        var d := ereignis as InputEventScreenDrag
        _finger[d.index] = d.position
        if _finger.size() >= 2:
            _zwei_finger()
        else:
            _verschiebe(-d.relative / zoom)
    elif ereignis is InputEventScreenTouch:
        var t := ereignis as InputEventScreenTouch
        if t.pressed:
            _finger[t.index] = t.position
        else:
            _finger.erase(t.index)
            _letzter_abstand = 0.0


## Zwei Finger: der Abstand zwischen ihnen steuert den Zoom.
func _zwei_finger() -> void:
    var punkte: Array = _finger.values()
    var abstand: float = (punkte[0] as Vector2).distance_to(punkte[1] as Vector2)
    if _letzter_abstand > 0.0 and abstand > 0.0:
        _zoome(abstand / _letzter_abstand)
    _letzter_abstand = abstand


func _zoome(faktor: float) -> void:
    var z := clampf(zoom.x * faktor, ZOOM_MIN, ZOOM_MAX)
    zoom = Vector2(z, z)
    _begrenze()


func _verschiebe(um: Vector2) -> void:
    position += um
    _begrenze()


## Haelt die Kamera ueber der Station, damit man sich nicht ins Leere schiebt.
func _begrenze() -> void:
    if grenzen.size == Vector2.ZERO:
        return
    position.x = clampf(position.x, grenzen.position.x - RAND, grenzen.end.x + RAND)
    position.y = clampf(position.y, grenzen.position.y - RAND, grenzen.end.y + RAND)
