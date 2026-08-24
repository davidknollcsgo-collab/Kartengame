## Bildschirm für die Ausbauten, bezahlt mit Quanten.
##
## Bewusst als eigener Bildschirm und nicht als Dialog: hier stehen dauerhaft
## drei Angebote nebeneinander, die sich vergleichen lassen müssen.
class_name AusbauSchirm
extends Control

const BREITE := 620.0
const ZEILE := 118.0

signal geschlossen

var _zeilen: Array[Rect2] = []
var _schliessen := Rect2()
var _feld := Rect2()


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    Spielstand.quanten_geaendert.connect(func(_w): queue_redraw())
    Spielstand.ausbau_geaendert.connect(queue_redraw)


func _passe_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


## Die drei Angebote als Anzeigedaten. An einer Stelle beschrieben, damit
## Zeichnen und Kaufabwicklung nicht auseinanderlaufen können.
func _angebote() -> Array[Dictionary]:
    var s := Spielstand
    return [
        {
            "name": "Schub",
            "text": "x%d Förderung für %s" % [int(Ausbau.SCHUB_FAKTOR),
                Zahl.zeit(Ausbau.SCHUB_DAUER)],
            "preis": Ausbau.SCHUB_KOSTEN,
            "moeglich": s.quanten >= Ausbau.SCHUB_KOSTEN,
            "stand": "läuft noch %s" % Zahl.zeit(s.boost_rest()) if s.boost_aktiv() else "",
        },
        {
            "name": "Langzeitspeicher",
            "text": "Abwesenheit zählt bis %s" % Zahl.zeit(s.offline_grenze()),
            "preis": Ausbau.speicher_preis(s.speicher_stufe),
            "moeglich": not Ausbau.speicher_voll(s.speicher_stufe) \
                and s.quanten >= Ausbau.speicher_preis(s.speicher_stufe),
            "stand": "Stufe %d von %d" % [s.speicher_stufe, Ausbau.SPEICHER_MAX],
        },
        {
            "name": "Orbital-Verstärker",
            "text": "Dauerhaft x%d auf alles" % int(Ausbau.VERSTAERKER_FAKTOR),
            "preis": Ausbau.VERSTAERKER_KOSTEN,
            "moeglich": not s.verstaerker and s.quanten >= Ausbau.VERSTAERKER_KOSTEN,
            "stand": "in Betrieb" if s.verstaerker else "",
        },
    ]


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
            match i:
                0: Spielstand.kaufe_schub()
                1: Spielstand.kaufe_speicher()
                2: Spielstand.kaufe_verstaerker()
            queue_redraw()
            accept_event()
            return
    accept_event()


func _process(_delta: float) -> void:
    # Die Restlaufzeit des Schubs läuft weiter, während der Schirm offen ist.
    if visible and Spielstand.boost_aktiv():
        queue_redraw()


func _draw() -> void:
    var schrift := ThemeDB.fallback_font
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.78))

    var angebote := _angebote()
    var hoehe := 200.0 + float(angebote.size()) * ZEILE
    _feld = Rect2((size.x - BREITE) * 0.5, (size.y - hoehe) * 0.5, BREITE, hoehe)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.08, 0.10, 0.14, 0.98))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), Color(0.42, 0.62, 0.86), 2.0, true)

    draw_string(schrift, Vector2(_feld.position.x + 34.0, _feld.position.y + 52.0),
        "AUSBAUTEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.94, 0.96, 1.0))
    draw_string(schrift, Vector2(_feld.position.x, _feld.position.y + 52.0),
        Waehrung.quanten(Spielstand.quanten), HORIZONTAL_ALIGNMENT_RIGHT,
        BREITE - 34.0, 24, Color(0.62, 0.86, 0.98))

    _zeilen.clear()
    var y := _feld.position.y + 88.0
    for eintrag in angebote:
        _zeichne_zeile(Rect2(_feld.position.x + 24.0, y, BREITE - 48.0, ZEILE - 12.0),
            eintrag, schrift)
        y += ZEILE

    _schliessen = Rect2(_feld.get_center().x - 110.0, _feld.end.y - 78.0, 220.0, 56.0)
    draw_colored_polygon(Formen.kante(_schliessen, 12.0), Color(0.30, 0.34, 0.42, 0.25))
    draw_polyline(Formen.kante_umriss(_schliessen, 12.0), Color(0.52, 0.58, 0.68), 2.0, true)
    draw_string(schrift, Vector2(_schliessen.position.x, _schliessen.get_center().y + 8.0),
        "Schließen", HORIZONTAL_ALIGNMENT_CENTER, _schliessen.size.x, 20,
        Color(0.88, 0.91, 0.96))


func _zeichne_zeile(r: Rect2, eintrag: Dictionary, schrift: Font) -> void:
    var moeglich: bool = eintrag["moeglich"]
    var preis: int = eintrag["preis"]
    var ton := Color(0.42, 0.78, 0.96) if moeglich else Color(0.32, 0.35, 0.42)

    draw_colored_polygon(Formen.kante(r, 12.0), Color(0.12, 0.14, 0.19, 0.9))
    draw_polyline(Formen.kante_umriss(r, 12.0), ton, 2.0, true)
    _zeilen.append(r)

    draw_string(schrift, Vector2(r.position.x + 20.0, r.position.y + 34.0),
        eintrag["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
        Color(0.94, 0.96, 1.0) if moeglich else Color(0.60, 0.64, 0.70))
    draw_string(schrift, Vector2(r.position.x + 20.0, r.position.y + 60.0),
        eintrag["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.60, 0.66, 0.74))

    var stand: String = eintrag["stand"]
    if not stand.is_empty():
        draw_string(schrift, Vector2(r.position.x + 20.0, r.position.y + 84.0),
            stand, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.48, 0.72, 0.60))

    # Preis rechts; bei erschöpften Angeboten steht dort ein Strich statt einer
    # Zahl, die man ohnehin nicht mehr bezahlen kann.
    var text := "—" if preis <= 0 else Waehrung.quanten(preis)
    draw_string(schrift, Vector2(r.position.x, r.get_center().y + 8.0), text,
        HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0, 22,
        Color(0.62, 0.90, 0.72) if moeglich else Color(0.45, 0.48, 0.55))
