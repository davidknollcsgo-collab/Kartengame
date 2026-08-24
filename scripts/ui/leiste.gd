## Bedienleiste am unteren Rand: Kaufmenge und Prestige.
##
## Die Kaufmenge ist kein Zierrat. Ab einigen hundert Baugruppen ist ein
## Idle-Spiel, das nur einzeln kaufen kann, schlicht nicht mehr bedienbar.
class_name Leiste
extends Control

const HOEHE := 112.0

## Waehlbare Mengen. -1 steht fuer "so viele wie bezahlbar".
const MENGEN: PackedInt32Array = [1, 10, 100, -1]

signal menge_gewaehlt(menge: int)
signal prestige_gewuenscht
signal ausbau_gewuenscht

var menge := 1

var _felder: Array[Rect2] = []
var _prestige := Rect2()
var _ausbau := Rect2()


func _ready() -> void:
    # Groesse und Lage ausdruecklich setzen: unter einem CanvasLayer greifen
    # Anker allein nicht (siehe Hud).
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    Spielstand.plasma_geaendert.connect(func(_w): queue_redraw())
    Spielstand.protokolle_geaendert.connect(func(_w): queue_redraw())
    Spielstand.quanten_geaendert.connect(func(_w): queue_redraw())


func _passe_an() -> void:
    var sicht := get_viewport_rect().size
    size = Vector2(sicht.x, HOEHE)
    position = Vector2(0.0, sicht.y - HOEHE)
    queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return

    for i in _felder.size():
        if _felder[i].has_point(m.position):
            menge = MENGEN[i]
            menge_gewaehlt.emit(menge)
            queue_redraw()
            accept_event()
            return

    if _ausbau.has_point(m.position):
        ausbau_gewuenscht.emit()
        accept_event()
        return

    if _prestige.has_point(m.position) and Oekonomie.prestige_moeglich(Spielstand.lebenszeit_plasma):
        prestige_gewuenscht.emit()
        accept_event()


static func menge_text(m: int) -> String:
    return "MAX" if m < 0 else "x%d" % m


func _draw() -> void:
    var schrift := ThemeDB.fallback_font

    draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09, 0.94))
    draw_line(Vector2.ZERO, Vector2(size.x, 0.0), Color(0.16, 0.20, 0.26), 2.0)

    # Mengenwahl links.
    _felder.clear()
    var b := 62.0
    var h := 52.0
    var x := 18.0
    for i in MENGEN.size():
        var r := Rect2(x, 16.0, b, h)
        _felder.append(r)
        var gewaehlt := MENGEN[i] == menge
        var ton := Color(0.30, 0.72, 0.90) if gewaehlt else Color(0.34, 0.38, 0.45)
        draw_colored_polygon(Formen.kante(r, 10.0),
            Color(ton.r, ton.g, ton.b, 0.22 if gewaehlt else 0.10))
        draw_polyline(Formen.kante_umriss(r, 10.0), ton, 2.0, true)
        draw_string(schrift, Vector2(r.position.x, r.get_center().y + 7.0),
            menge_text(MENGEN[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19,
            Color(0.95, 0.97, 1.0) if gewaehlt else Color(0.62, 0.66, 0.72))
        x += b + 8.0

    draw_string(schrift, Vector2(20.0, 90.0), "Kaufmenge",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.42, 0.46, 0.53))

    # Ausbau-Knopf zwischen Mengenwahl und Prestige.
    _ausbau = Rect2(x + 8.0, 16.0, 132.0, 52.0)
    var offen := Spielstand.quanten > 0
    var ton := Color(0.42, 0.78, 0.96) if offen else Color(0.36, 0.40, 0.48)
    draw_colored_polygon(Formen.kante(_ausbau, 10.0),
        Color(ton.r, ton.g, ton.b, 0.18 if offen else 0.08))
    draw_polyline(Formen.kante_umriss(_ausbau, 10.0), ton, 2.0, true)
    draw_string(schrift, Vector2(_ausbau.position.x, _ausbau.get_center().y + 7.0),
        "AUSBAU", HORIZONTAL_ALIGNMENT_CENTER, _ausbau.size.x, 18,
        Color(0.93, 0.96, 1.0) if offen else Color(0.60, 0.64, 0.70))
    draw_string(schrift, Vector2(_ausbau.position.x, 90.0),
        Waehrung.quanten(Spielstand.quanten), HORIZONTAL_ALIGNMENT_CENTER,
        _ausbau.size.x, 14, Color(0.52, 0.72, 0.86))

    # Prestige rechts.
    var gewinn := Oekonomie.prestige_ertrag(Spielstand.lebenszeit_plasma)
    var moeglich := gewinn > 0
    _prestige = Rect2(size.x - 214.0, 16.0, 196.0, 68.0)
    var farbe := Color(0.68, 0.52, 0.95) if moeglich else Color(0.30, 0.32, 0.38)
    draw_colored_polygon(Formen.kante(_prestige, 12.0),
        Color(farbe.r, farbe.g, farbe.b, 0.20 if moeglich else 0.08))
    draw_polyline(Formen.kante_umriss(_prestige, 12.0), farbe, 2.0, true)
    draw_string(schrift, Vector2(_prestige.position.x, _prestige.position.y + 28.0),
        "PRESTIGE", HORIZONTAL_ALIGNMENT_CENTER, _prestige.size.x, 20,
        Color(0.95, 0.93, 1.0) if moeglich else Color(0.45, 0.47, 0.53))
    draw_string(schrift, Vector2(_prestige.position.x, _prestige.position.y + 54.0),
        ("+%d Protokolle" % gewinn) if moeglich else "noch nicht",
        HORIZONTAL_ALIGNMENT_CENTER, _prestige.size.x, 15,
        Color(0.72, 0.62, 0.96) if moeglich else Color(0.38, 0.40, 0.46))
