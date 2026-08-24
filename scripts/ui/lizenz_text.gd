## Schiebbarer Fließtext mit Umbruch.
##
## Eigenes Control mit [member Control.clip_contents], wie schon bei der
## Errungenschaftsliste: von Hand beschnittener Text lief dort über den Rahmen
## hinaus.
class_name LizenzText
extends Control

const GROESSE := 14
const ZEILENHOEHE := 19.0

var _text := ""
var _versatz := 0.0
var _zieht := false
var _hoehe := 0.0


func _ready() -> void:
    clip_contents = true


func setze(text: String) -> void:
    _text = text
    _versatz = 0.0
    _hoehe = 0.0
    queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventMouseButton:
        var m := ereignis as InputEventMouseButton
        if m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _schiebe(60.0)
        elif m.button_index == MOUSE_BUTTON_WHEEL_UP:
            _schiebe(-60.0)
        elif m.button_index == MOUSE_BUTTON_LEFT:
            _zieht = m.pressed
        accept_event()
    elif ereignis is InputEventMouseMotion and _zieht:
        _schiebe(-(ereignis as InputEventMouseMotion).relative.y)
        accept_event()


func _schiebe(um: float) -> void:
    _versatz = clampf(_versatz + um, 0.0, maxf(_hoehe - size.y, 0.0))
    queue_redraw()


func _draw() -> void:
    if _text.is_empty():
        return
    var schrift := Schrift.text()
    var breite := size.x - 14.0
    _hoehe = schrift.get_multiline_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT,
        breite, GROESSE).y

    draw_multiline_string(schrift, Vector2(0.0, ZEILENHOEHE - _versatz), _text,
        HORIZONTAL_ALIGNMENT_LEFT, breite, GROESSE, -1, Color(0.68, 0.74, 0.82))

    if _hoehe <= size.y:
        return
    var bahn := Rect2(size.x - 8.0, 0.0, 6.0, size.y)
    draw_rect(bahn, Color(0.16, 0.19, 0.24))
    var anteil := size.y / _hoehe
    draw_rect(Rect2(bahn.position.x, (_versatz / _hoehe) * size.y, bahn.size.x,
        maxf(size.y * anteil, 30.0)), Color(0.46, 0.60, 0.78))
