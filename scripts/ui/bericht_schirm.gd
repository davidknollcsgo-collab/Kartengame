## Bericht: Kennzahlen und Errungenschaften.
##
## Beides auf einem Bildschirm, weil beides dieselbe Frage beantwortet - wie
## weit bin ich? Die Liste ist länger als der Schirm und lässt sich schieben.
class_name BerichtSchirm
extends Control

const BREITE := 640.0
const ZEILE := 74.0

signal geschlossen
signal zuruecksetzen_gewuenscht

var _feld := Rect2()
var _schliessen := Rect2()
var _reset := Rect2()
var _liste: ErrungenschaftListe


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _liste = ErrungenschaftListe.new()
    add_child(_liste)
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    Spielstand.errungen_freigeschaltet.connect(func(_a, _b): queue_redraw())


func _passe_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if not visible:
        return

    if ereignis is InputEventMouseButton:
        var m := ereignis as InputEventMouseButton
        if m.button_index == MOUSE_BUTTON_LEFT and not m.pressed:
            if _schliessen.has_point(m.position):
                visible = false
                geschlossen.emit()
            elif _reset.has_point(m.position):
                zuruecksetzen_gewuenscht.emit()
        accept_event()


func _draw() -> void:
    var schrift := ThemeDB.fallback_font
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.80))

    var hoehe := minf(size.y - 120.0, 980.0)
    _feld = Rect2((size.x - BREITE) * 0.5, (size.y - hoehe) * 0.5, BREITE, hoehe)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.08, 0.10, 0.14, 0.98))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), Color(0.46, 0.58, 0.76), 2.0, true)

    draw_string(schrift, Vector2(_feld.position.x + 32.0, _feld.position.y + 50.0),
        "BERICHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.94, 0.96, 1.0))

    var y := _feld.position.y + 84.0
    for paar in _kennzahlen():
        draw_string(schrift, Vector2(_feld.position.x + 32.0, y), paar[0],
            HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.56, 0.62, 0.70))
        draw_string(schrift, Vector2(_feld.position.x, y), paar[1],
            HORIZONTAL_ALIGNMENT_RIGHT, BREITE - 32.0, 16, Color(0.90, 0.93, 0.98))
        y += 28.0

    y += 12.0
    draw_line(Vector2(_feld.position.x + 32.0, y), Vector2(_feld.end.x - 32.0, y),
        Color(0.20, 0.24, 0.30), 1.0)
    y += 24.0
    draw_string(schrift, Vector2(_feld.position.x + 32.0, y),
        "ERRUNGENSCHAFTEN  %d/%d" % [Spielstand.errungen.size(),
            Errungenschaft.TABELLE.size()],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.72, 0.80, 0.90))
    y += 16.0

    # Die Liste ist ein eigenes Control mit clip_contents; hier wird ihr nur
    # der verbleibende Platz zugewiesen.
    var listen_hoehe := _feld.end.y - y - 96.0
    _liste.position = Vector2(_feld.position.x + 24.0, y)
    _liste.size = Vector2(BREITE - 48.0, maxf(listen_hoehe, 0.0))

    _schliessen = Rect2(_feld.get_center().x + 10.0, _feld.end.y - 76.0, 190.0, 54.0)
    _rahmen(_schliessen, Color(0.52, 0.58, 0.68), 0.12)
    draw_string(schrift, Vector2(_schliessen.position.x, _schliessen.get_center().y + 8.0),
        "Schließen", HORIZONTAL_ALIGNMENT_CENTER, _schliessen.size.x, 20,
        Color(0.88, 0.91, 0.96))

    _reset = Rect2(_feld.get_center().x - 200.0, _feld.end.y - 76.0, 190.0, 54.0)
    _rahmen(_reset, Color(0.82, 0.38, 0.36), 0.12)
    draw_string(schrift, Vector2(_reset.position.x, _reset.get_center().y + 8.0),
        "Alles löschen", HORIZONTAL_ALIGNMENT_CENTER, _reset.size.x, 19,
        Color(0.95, 0.72, 0.70))


func _kennzahlen() -> Array:
    var s := Spielstand
    return [
        ["Spielzeit", Zahl.zeit(s.spielzeit)],
        ["Gefördert insgesamt", Waehrung.plasma(s.lebenszeit_plasma)],
        ["Förderung je Sekunde", Waehrung.plasma(s.rate())],
        ["Baugruppen", str(_bestand_summe())],
        ["Zurücksetzungen", str(s.prestige_anzahl)],
        ["Protokolle", "%s  (x%.2f)" % [Waehrung.protokolle(s.protokolle),
            Oekonomie.prestige_mult(s.protokolle)]],
    ]


func _bestand_summe() -> int:
    var n := 0
    for k in Spielstand.bestand:
        n += k
    return n



func _rahmen(r: Rect2, ton: Color, fuellung: float) -> void:
    draw_colored_polygon(Formen.kante(r, 12.0), Color(ton.r, ton.g, ton.b, fuellung))
    draw_polyline(Formen.kante_umriss(r, 12.0), ton, 2.0, true)
