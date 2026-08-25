## Bedienleiste am unteren Rand.
##
## Zwei Reihen: oben die Kaufmenge, unten die Bildschirme. Einreihig wurde es
## bei vier Plättchen plus drei Knöpfen auf 720 Punkten Breite zu eng - die
## Trefferflächen lagen unter dem, was ein Daumen zuverlässig trifft.
class_name Leiste
extends Control

const HOEHE := 150.0

## Waehlbare Mengen. -1 steht fuer "so viele wie bezahlbar".
const MENGEN: PackedInt32Array = [1, 10, 100, -1]

signal menge_gewaehlt(menge: int)
signal prestige_gewuenscht
signal ausbau_gewuenscht
signal bericht_gewuenscht

var menge := 1

var _felder: Array[Rect2] = []
var _prestige := Rect2()
var _ausbau := Rect2()
var _bericht := Rect2()


func _ready() -> void:
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    for signal_name in ["plasma_geaendert", "protokolle_geaendert", "quanten_geaendert"]:
        Spielstand.connect(signal_name, func(_w): queue_redraw())


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
    elif _bericht.has_point(m.position):
        bericht_gewuenscht.emit()
    elif _prestige.has_point(m.position) \
            and Oekonomie.prestige_moeglich(Spielstand.lebenszeit_plasma):
        prestige_gewuenscht.emit()
    else:
        return
    accept_event()


static func menge_text(m: int) -> String:
    return "MAX" if m < 0 else "x%d" % m


func _draw() -> void:
    var schrift := Schrift.text()

    draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09, 0.94))
    draw_line(Vector2.ZERO, Vector2(size.x, 0.0), Color(0.16, 0.20, 0.26), 2.0)

    # --- Reihe 1: Kaufmenge ---
    _felder.clear()
    # Plaettchenbreite aus der Bildschirmbreite: auf 360 Punkten passen vier
    # Plaettchen zu 70 plus Beschriftung nicht mehr nebeneinander.
    var rand := 18.0
    var platz := size.x - rand * 2.0
    var chip := clampf((platz - 3.0 * 8.0) * 0.52 / 4.0, Masse.TIPPFLAECHE, 74.0)
    var x := rand
    for i in MENGEN.size():
        var r := Rect2(x, 14.0, chip, 48.0)
        _felder.append(r)
        var gewaehlt := MENGEN[i] == menge
        var ton := Color(0.30, 0.72, 0.90) if gewaehlt else Color(0.34, 0.38, 0.45)
        _rahmen(r, ton, 0.22 if gewaehlt else 0.08, 10.0)
        draw_string(schrift, Vector2(r.position.x, r.get_center().y + 7.0),
            menge_text(MENGEN[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19,
            Color(0.95, 0.97, 1.0) if gewaehlt else Color(0.62, 0.66, 0.72))
        x += chip + 8.0
    draw_string(schrift, Vector2(x + 6.0, 44.0), "Kaufmenge",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.42, 0.46, 0.53))

    # --- Reihe 2: Bildschirme ---
    # Reihe 2 proportional aufteilen, damit auf schmalen Geraeten nichts
    # ueberlappt und auf breiten nichts verloren steht.
    var prestige_b := clampf(platz * 0.30, 150.0, 200.0)
    var rest := platz - prestige_b - 24.0
    var knopf_b := maxf(rest * 0.5 - 6.0, 108.0)
    _ausbau = Rect2(rand, 76.0, knopf_b, 58.0)
    var quanten_da := Spielstand.quanten > 0
    var ausbau_ton := Color(0.42, 0.78, 0.96) if quanten_da else Color(0.36, 0.40, 0.48)
    _rahmen(_ausbau, ausbau_ton, 0.18 if quanten_da else 0.07, 12.0)
    draw_string(schrift, Vector2(_ausbau.position.x, _ausbau.position.y + 26.0),
        "AUSBAU", HORIZONTAL_ALIGNMENT_CENTER, _ausbau.size.x, 18,
        Color(0.93, 0.96, 1.0) if quanten_da else Color(0.62, 0.66, 0.72))
    Waehrung.zeichne(self, schrift,
        Vector2(_ausbau.get_center().x, _ausbau.position.y + 47.0),
        str(Spielstand.quanten), Waehrung.Art.QUANTEN, 15,
        Color(0.52, 0.76, 0.90), Waehrung.Lage.MITTE)

    _bericht = Rect2(rand + knopf_b + 12.0, 76.0, knopf_b, 58.0)
    _rahmen(_bericht, Color(0.46, 0.52, 0.62), 0.10, 12.0)
    draw_string(schrift, Vector2(_bericht.position.x, _bericht.position.y + 26.0),
        "BERICHT", HORIZONTAL_ALIGNMENT_CENTER, _bericht.size.x, 18,
        Color(0.88, 0.91, 0.96))
    draw_string(schrift, Vector2(_bericht.position.x, _bericht.position.y + 47.0),
        "%d/%d" % [Spielstand.errungen.size(), Errungenschaft.TABELLE.size()],
        HORIZONTAL_ALIGNMENT_CENTER, _bericht.size.x, 15, Color(0.56, 0.62, 0.70))

    # --- Prestige rechts ---
    var gewinn := Oekonomie.prestige_ertrag(Spielstand.lebenszeit_plasma)
    var moeglich := Oekonomie.prestige_moeglich(Spielstand.lebenszeit_plasma)
    _prestige = Rect2(size.x - rand - prestige_b, 76.0, prestige_b, 58.0)
    var farbe := Color(0.68, 0.52, 0.95) if moeglich else Color(0.30, 0.32, 0.38)
    _rahmen(_prestige, farbe, 0.20 if moeglich else 0.07, 12.0)
    draw_string(schrift, Vector2(_prestige.position.x, _prestige.position.y + 26.0),
        "PRESTIGE", HORIZONTAL_ALIGNMENT_CENTER, _prestige.size.x, 18,
        Color(0.95, 0.93, 1.0) if moeglich else Color(0.45, 0.47, 0.53))
    # Unterhalb der Mindestausbeute steht der Fortschritt statt einer Zahl, die
    # noch zu nichts berechtigt.
    var unterfarbe := Color(0.76, 0.66, 0.98) if moeglich else Color(0.40, 0.42, 0.48)
    var untery := _prestige.position.y + 47.0
    if moeglich:
        Waehrung.zeichne(self, schrift, Vector2(_prestige.get_center().x, untery),
            "+%d" % gewinn, Waehrung.Art.PROTOKOLL, 15, unterfarbe,
            Waehrung.Lage.MITTE)
    else:
        # Unterhalb der Mindestausbeute zaehlt der Fortschritt, nicht ein Betrag,
        # der noch zu nichts berechtigt.
        draw_string(schrift, Vector2(_prestige.position.x, untery),
            "%d von %d" % [gewinn, Oekonomie.MIN_PROTOKOLLE],
            HORIZONTAL_ALIGNMENT_CENTER, _prestige.size.x, 15, unterfarbe)


func _rahmen(r: Rect2, ton: Color, fuellung: float, schraege: float) -> void:
    draw_colored_polygon(Formen.kante(r, schraege), Color(ton.r, ton.g, ton.b, fuellung))
    draw_polyline(Formen.kante_umriss(r, schraege), ton, 2.0, true)
