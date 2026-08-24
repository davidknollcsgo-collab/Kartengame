## Detailfenster einer Baugruppe.
##
## Zeigt, was die Baugruppe leistet, und stellt die beiden Käufe nebeneinander:
## weitere Stücke oder eine Ausbaustufe. Genau diese Gegenüberstellung ist der
## Zweck des Fensters - auf der Karte draußen sieht man nur den Stückpreis und
## hat keine Grundlage für die Entscheidung.
class_name ModulSchirm
extends Control

signal geschlossen

var index := 0

var _feld := Rect2()
var _schliessen := Rect2()
var _kaufen := Rect2()
var _ausbauen := Rect2()


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    Spielstand.plasma_geaendert.connect(func(_w):
        if visible:
            queue_redraw())


func _passe_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


func zeige(neuer_index: int) -> void:
    index = neuer_index
    visible = true
    queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if not visible or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return
    if _schliessen.has_point(m.position):
        visible = false
        geschlossen.emit()
    elif _kaufen.has_point(m.position):
        if Spielstand.kaufe(index, _menge()):
            Klang.spiele(Klang.Art.KAUF)
        queue_redraw()
    elif _ausbauen.has_point(m.position):
        if Spielstand.kaufe_modul_ausbau(index):
            Klang.spiele(Klang.Art.AUSBAU)
        queue_redraw()
    accept_event()


func _menge() -> int:
    if Spielstand.kaufmenge >= 1:
        return Spielstand.kaufmenge
    return maxi(Oekonomie.max_kaufbar(index, Spielstand.bestand[index],
        Spielstand.plasma), 1)


func _draw() -> void:
    var titel := Schrift.titel()
    var text := Schrift.text()
    var leit := Modul.farbe(index)
    var anzahl: int = Spielstand.bestand[index]
    var stufe: int = Spielstand.modul_stufe[index]

    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.80))
    # Höhe aus dem Inhalt: Kopf, vier Kennzahlen, Knopfreihe, Fuß. Ein fester
    # Wert ließ die untere Hälfte leer stehen.
    _feld = Masse.fenster(size, 84.0 + 4.0 * 30.0 + 16.0 + 96.0 + 30.0)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.08, 0.10, 0.14, 0.98))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), leit, 2.0, true)

    var links := _feld.position.x + 26.0
    var innen := _feld.size.x - 52.0

    draw_string(titel, Vector2(links, _feld.position.y + 48.0), Modul.name_von(index),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.94, 0.96, 1.0))
    _zeichne_kreuz()

    # Anteil an der Gesamtförderung: die Zahl, an der man ablesen kann, ob sich
    # weiteres Plasma hier überhaupt noch lohnt.
    var meine := Oekonomie.modul_rate(index, anzahl, Spielstand.global_mult(), stufe)
    var gesamt := Spielstand.rate()
    var anteil := (meine / gesamt * 100.0) if gesamt > 0.0 else 0.0

    var y := _feld.position.y + 84.0
    for paar in [
        ["In Betrieb", "%d Stück" % anzahl],
        ["Ausbaustufe", "%d von %d  (x%s)" % [stufe, ModulAusbau.MAX_STUFE,
            Zahl.kurz(ModulAusbau.faktor(stufe))]],
        ["Förderung", Zahl.kurz(meine) + " je Sekunde"],
        ["Anteil an allem", "%.1f %%" % anteil],
    ]:
        draw_string(text, Vector2(links, y), paar[0],
            HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.56, 0.62, 0.70))
        draw_string(titel, Vector2(links, y), paar[1],
            HORIZONTAL_ALIGNMENT_RIGHT, innen, 15, Color(0.90, 0.93, 0.98))
        y += 30.0

    y += 16.0
    var knopf_b := (innen - 16.0) * 0.5
    var knopf_h := 96.0

    # --- Stücke kaufen ---
    var menge := _menge()
    var stueckpreis := Oekonomie.kosten_summe(index, anzahl, menge)
    _kaufen = Rect2(links, y, knopf_b, knopf_h)
    _knopf(_kaufen, leit, stueckpreis <= Spielstand.plasma,
        "KAUFEN", "x%d" % menge, stueckpreis, Waehrung.Art.PLASMA)

    # --- Ausbauen ---
    _ausbauen = Rect2(links + knopf_b + 16.0, y, knopf_b, knopf_h)
    if ModulAusbau.voll(stufe):
        _knopf(_ausbauen, Color(0.40, 0.44, 0.50), false,
            "AUSBAU", "voll ausgebaut", -1.0, Waehrung.Art.PLASMA)
    else:
        var apreis := ModulAusbau.kosten(index, stufe)
        _knopf(_ausbauen, Color(0.55, 0.82, 0.98), apreis <= Spielstand.plasma,
            "AUSBAU", "Stufe %d  x2" % (stufe + 1), apreis, Waehrung.Art.PLASMA)


func _knopf(r: Rect2, ton: Color, moeglich: bool, kopf: String, zeile: String,
        preis: float, art: Waehrung.Art) -> void:
    var farbe := ton if moeglich else ton.darkened(0.45)
    draw_colored_polygon(Formen.kante(r, 12.0),
        Color(farbe.r, farbe.g, farbe.b, 0.18 if moeglich else 0.06))
    draw_polyline(Formen.kante_umriss(r, 12.0), farbe, 2.0, true)

    var hell := Color(0.95, 0.97, 1.0) if moeglich else Color(0.52, 0.56, 0.62)
    draw_string(Schrift.titel(), Vector2(r.position.x, r.position.y + 30.0), kopf,
        HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, hell)
    draw_string(Schrift.text(), Vector2(r.position.x, r.position.y + 54.0), zeile,
        HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(0.62, 0.68, 0.76))
    if preis >= 0.0:
        Waehrung.zeichne(self, Schrift.titel(),
            Vector2(r.get_center().x, r.position.y + 80.0), Zahl.kurz(preis), art, 16,
            Color(0.60, 0.92, 0.70) if moeglich else Color(0.48, 0.51, 0.57),
            Waehrung.Lage.MITTE)


func _zeichne_kreuz() -> void:
    _schliessen = Rect2(_feld.end.x - Masse.TIPPFLAECHE - 14.0,
        _feld.position.y + 16.0, Masse.TIPPFLAECHE, Masse.TIPPFLAECHE)
    var m := _schliessen.get_center()
    var a := 11.0
    var f := Color(0.72, 0.78, 0.86)
    draw_line(m + Vector2(-a, -a), m + Vector2(a, a), f, 2.5, true)
    draw_line(m + Vector2(a, -a), m + Vector2(-a, a), f, 2.5, true)
