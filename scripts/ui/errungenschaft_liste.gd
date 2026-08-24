## Schiebbare Liste der Errungenschaften.
##
## Eigenes Control statt in [BerichtSchirm] mitgezeichnet: nur so greift
## [member Control.clip_contents]. Der erste Versuch beschnitt über
## RenderingServer von Hand und lief sichtbar über die Knöpfe darunter.
class_name ErrungenschaftListe
extends Control

const ZEILE := 74.0

var _versatz := 0.0
var _zieht := false


func _ready() -> void:
    clip_contents = true
    Spielstand.errungen_freigeschaltet.connect(func(_a, _b): queue_redraw())


func _gui_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventMouseButton:
        var m := ereignis as InputEventMouseButton
        if m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _schiebe(46.0)
        elif m.button_index == MOUSE_BUTTON_WHEEL_UP:
            _schiebe(-46.0)
        elif m.button_index == MOUSE_BUTTON_LEFT:
            _zieht = m.pressed
        accept_event()
    elif ereignis is InputEventMouseMotion and _zieht:
        _schiebe(-(ereignis as InputEventMouseMotion).relative.y)
        accept_event()


func _schiebe(um: float) -> void:
    var gesamt := float(Errungenschaft.TABELLE.size()) * ZEILE
    _versatz = clampf(_versatz + um, 0.0, maxf(gesamt - size.y, 0.0))
    queue_redraw()


func _draw() -> void:
    var schrift := ThemeDB.fallback_font
    var y := -_versatz
    for eintrag in Errungenschaft.TABELLE:
        # Zeilen weit ausserhalb gar nicht erst zeichnen.
        if y + ZEILE >= 0.0 and y <= size.y:
            _zeichne(Rect2(0.0, y, size.x, ZEILE - 10.0), eintrag, schrift)
        y += ZEILE

    # Andeutung, dass es weitergeht.
    var gesamt := float(Errungenschaft.TABELLE.size()) * ZEILE
    if gesamt > size.y:
        var anteil := size.y / gesamt
        var lauf := (_versatz / gesamt) * size.y
        draw_rect(Rect2(size.x - 4.0, lauf, 3.0, size.y * anteil),
            Color(0.45, 0.55, 0.68, 0.55))


func _zeichne(r: Rect2, eintrag: Dictionary, schrift: Font) -> void:
    var offen: bool = Spielstand.errungen.has(String(eintrag["id"]))
    var ton := Color(0.42, 0.82, 0.58) if offen else Color(0.30, 0.33, 0.40)
    draw_colored_polygon(Formen.kante(r, 12.0), Color(ton.r, ton.g, ton.b, 0.14 if offen else 0.05))
    draw_polyline(Formen.kante_umriss(r, 12.0), ton, 2.0, true)

    draw_string(schrift, Vector2(r.position.x + 18.0, r.position.y + 26.0),
        eintrag["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
        Color(0.92, 0.96, 0.94) if offen else Color(0.55, 0.59, 0.66))
    draw_string(schrift, Vector2(r.position.x + 18.0, r.position.y + 50.0),
        eintrag["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
        Color(0.60, 0.68, 0.66) if offen else Color(0.42, 0.45, 0.52))
    draw_string(schrift, Vector2(r.position.x, r.get_center().y + 7.0),
        Waehrung.quanten(int(eintrag["quanten"])), HORIZONTAL_ALIGNMENT_RIGHT,
        r.size.x - 24.0, 18,
        Color(0.52, 0.86, 0.66) if offen else Color(0.42, 0.46, 0.54))
