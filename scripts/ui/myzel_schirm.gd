## Der Myzel-Bildschirm: Fortschrittsknoten gegen Biomasse.
##
## Bewusst als Liste und nicht als verzweigter Baum. Ein Baum sieht in einem
## Konzeptbild gut aus, kostet auf einem Handybildschirm aber die Hälfte der
## Fläche für Linien zwischen Kästen - und bei fünf Ästen gibt es ohnehin
## nichts zu verzweigen.
class_name MyzelSchirm
extends Control

const ZEILE := 104.0

signal geschlossen

var _feld := Rect2()
var _schliessen := Rect2()
var _zeilen: Array[Rect2] = []
var _zeit := 0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    Fortschritt.biomasse_geaendert.connect(func(_w): queue_redraw())
    Fortschritt.myzel_geaendert.connect(queue_redraw)
    set_process(true)


func _passe_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


func _process(delta: float) -> void:
    if visible:
        _zeit += delta


func _gui_input(ereignis: InputEvent) -> void:
    if not visible or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return

    if _schliessen.has_point(m.position):
        visible = false
        geschlossen.emit()
        accept_event()
        return

    for i in _zeilen.size():
        if _zeilen[i].has_point(m.position):
            if Fortschritt.kaufe_knoten(String(Myzel.TABELLE[i]["id"])):
                queue_redraw()
            accept_event()
            return
    accept_event()


func _draw() -> void:
    var display := Schrift.display()
    var text := Schrift.text()

    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.84))

    var b := minf(size.x - 40.0, 520.0)
    var h := minf(200.0 + float(Myzel.TABELLE.size()) * ZEILE, size.y - 60.0)
    _feld = Rect2((size.x - b) * 0.5, (size.y - h) * 0.5, b, h)

    draw_rect(_feld, Color(0.043, 0.059, 0.051, 0.99))
    draw_rect(_feld, Color(0.26, 0.56, 0.50), false, 2.0)

    draw_string(display, Vector2(_feld.position.x + 24.0, _feld.position.y + 52.0),
        "MYZEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.88, 0.96, 0.93))

    # Guthaben rechts oben - die Zahl, an der jede Entscheidung hängt.
    draw_string(text, Vector2(_feld.position.x, _feld.position.y + 34.0),
        "BIOMASSE", HORIZONTAL_ALIGNMENT_RIGHT, b - 74.0, 13,
        Color(0.42, 0.60, 0.56))
    draw_string(display, Vector2(_feld.position.x, _feld.position.y + 60.0),
        Hud._kurz(Fortschritt.biomasse), HORIZONTAL_ALIGNMENT_RIGHT, b - 74.0, 22,
        Color(0.50, 0.94, 0.84))

    _zeichne_kreuz()

    _zeilen.clear()
    var y := _feld.position.y + 88.0
    for e in Myzel.TABELLE:
        _zeichne_zeile(Rect2(_feld.position.x + 18.0, y, b - 36.0, ZEILE - 12.0),
            e, display, text)
        y += ZEILE


func _zeichne_zeile(r: Rect2, e: Dictionary, display: Font, text: Font) -> void:
    var id := String(e["id"])
    var stufe := Fortschritt.stufe_von(id)
    var max_stufe := Myzel.max_stufe(id)
    var preis := Myzel.kosten(id, stufe)
    var voll := Myzel.voll(id, stufe)
    var kaufbar := not voll and Fortschritt.biomasse >= preis

    var ton := Color(0.36, 0.86, 0.76) if kaufbar else (
        Color(0.30, 0.52, 0.48) if voll else Color(0.26, 0.31, 0.30))
    draw_rect(r, Color(0.055, 0.078, 0.070))
    draw_rect(r, ton, false, 2.0)
    _zeilen.append(r)

    draw_string(display, Vector2(r.position.x + 16.0, r.position.y + 30.0),
        e["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, 19,
        Color(0.90, 0.96, 0.94) if not voll else Color(0.58, 0.76, 0.72))
    draw_string(text, Vector2(r.position.x + 16.0, r.position.y + 54.0),
        e["text"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130.0, 15,
        Color(0.55, 0.68, 0.65))

    # Stufenpunkte statt einer Zahl: der Fortschritt ist auf einen Blick da.
    var punkt_y := r.end.y - 16.0
    for i in max_stufe:
        var p := Vector2(r.position.x + 20.0 + float(i) * 15.0, punkt_y)
        if i < stufe:
            draw_circle(p, 5.0, Color(0.42, 0.92, 0.80))
        else:
            draw_arc(p, 5.0, 0.0, TAU, 12, Color(0.28, 0.40, 0.38), 1.4, true)

    if voll:
        draw_string(display, Vector2(r.position.x, r.get_center().y + 8.0),
            "VOLL", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18.0, 17,
            Color(0.44, 0.72, 0.66))
    else:
        draw_string(display, Vector2(r.position.x, r.get_center().y + 8.0),
            Hud._kurz(preis), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18.0, 20,
            Color(0.52, 0.94, 0.78) if kaufbar else Color(0.42, 0.48, 0.47))


func _zeichne_kreuz() -> void:
    _schliessen = Rect2(_feld.end.x - 58.0, _feld.end.y - 58.0, 44.0, 44.0)
    var m := _schliessen.get_center()
    var a := 11.0
    var f := Color(0.68, 0.80, 0.77)
    draw_line(m + Vector2(-a, -a), m + Vector2(a, a), f, 2.5, true)
    draw_line(m + Vector2(a, -a), m + Vector2(-a, a), f, 2.5, true)
