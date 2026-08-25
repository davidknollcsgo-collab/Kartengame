## Kopf- und Fußzeile während einer Kammer, dazu der Abschlussbildschirm.
##
## Bewusst schmal: das Spielfeld soll die Aufmerksamkeit tragen. Angezeigt wird
## nur, was für die nächste Entscheidung nötig ist - Kammernummer, übrige
## Sporen, übrige Knoten.
class_name Hud
extends Control

signal weiter_gewuenscht
signal wiederholen_gewuenscht

const KOPF_H := 92.0
const FUSS_H := 104.0

var kammer := 1
var sporen := 0
var knoten := 0

var _ende_sichtbar := false
var _gewonnen := false
var _ertrag := 0.0
var _knopf := Rect2()
var _zeit := 0.0


func _ready() -> void:
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)
    set_process(true)


func _passe_an() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    queue_redraw()


func _process(delta: float) -> void:
    _zeit += delta
    if _ende_sichtbar:
        queue_redraw()


func setze(neue_kammer: int, neue_sporen: int, neue_knoten: int) -> void:
    kammer = neue_kammer
    sporen = neue_sporen
    knoten = neue_knoten
    queue_redraw()


func zeige_ende(gewonnen: bool, ertrag: float = 0.0) -> void:
    _ende_sichtbar = true
    _gewonnen = gewonnen
    _ertrag = ertrag
    _zeit = 0.0
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()


func verbirg_ende() -> void:
    _ende_sichtbar = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if not _ende_sichtbar or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return
    if _knopf.has_point(m.position):
        if _gewonnen:
            weiter_gewuenscht.emit()
        else:
            wiederholen_gewuenscht.emit()
    accept_event()


func _draw() -> void:
    _zeichne_kopf()
    _zeichne_fuss()
    if _ende_sichtbar:
        _zeichne_ende()


func _zeichne_kopf() -> void:
    var display := Schrift.display()
    var text := Schrift.text()

    draw_rect(Rect2(0.0, 0.0, size.x, KOPF_H), Color(0.031, 0.043, 0.039, 0.90))
    draw_line(Vector2(0.0, KOPF_H), Vector2(size.x, KOPF_H),
        Color(0.13, 0.24, 0.22), 2.0)

    draw_string(text, Vector2(22.0, 34.0), "KAMMER",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.42, 0.60, 0.56))
    draw_string(display, Vector2(22.0, 68.0), str(kammer),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.88, 0.96, 0.93))

    # Übrige Knoten rechts - die Zahl, die zählt.
    draw_string(text, Vector2(size.x - 172.0, 34.0), "BEFALL",
        HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 14, Color(0.55, 0.42, 0.68))
    draw_string(display, Vector2(size.x - 172.0, 68.0), str(knoten),
        HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 30, Color(0.78, 0.58, 1.0))


## Übrige Sporen als Punktreihe.
##
## Punkte statt einer Zahl: man erfasst auf einen Blick, wie knapp es wird,
## ohne zu lesen. Ab zwölf Stück wird es unübersichtlich - dann doch als Zahl.
func _zeichne_fuss() -> void:
    var y := size.y - FUSS_H * 0.5
    draw_rect(Rect2(0.0, size.y - FUSS_H, size.x, FUSS_H),
        Color(0.031, 0.043, 0.039, 0.90))
    draw_line(Vector2(0.0, size.y - FUSS_H), Vector2(size.x, size.y - FUSS_H),
        Color(0.13, 0.24, 0.22), 2.0)

    var grund := Color(0.45, 0.95, 0.86)
    if sporen > 12:
        draw_string(Schrift.display(), Vector2(0.0, y + 11.0),
            "%d Sporen" % sporen, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, grund)
        return

    var abstand := 30.0
    var breite := float(maxi(sporen, 1) - 1) * abstand
    var x := size.x * 0.5 - breite * 0.5
    for i in sporen:
        var p := Vector2(x + float(i) * abstand, y)
        draw_circle(p, 11.0, Color(grund.r, grund.g, grund.b, 0.14))
        draw_circle(p, 6.5, grund)
    if sporen == 0:
        draw_string(Schrift.text(), Vector2(0.0, y + 7.0), "keine Sporen mehr",
            HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(0.60, 0.45, 0.42))


func _zeichne_ende() -> void:
    var display := Schrift.display()
    var text := Schrift.text()
    # Kurz einblenden statt hart aufpoppen.
    var ein := clampf(_zeit / 0.28, 0.0, 1.0)

    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72 * ein))

    var b := minf(size.x - 56.0, 460.0)
    var h := 260.0
    var feld := Rect2((size.x - b) * 0.5, (size.y - h) * 0.5, b, h)
    var ton := Color(0.36, 0.86, 0.76) if _gewonnen else Color(0.86, 0.52, 0.42)

    draw_rect(feld, Color(0.055, 0.075, 0.068, 0.98 * ein))
    draw_rect(feld, Color(ton.r, ton.g, ton.b, ein), false, 2.0)

    draw_string(display, Vector2(feld.position.x, feld.position.y + 62.0),
        "GERÄUMT" if _gewonnen else "SPOREN LEER",
        HORIZONTAL_ALIGNMENT_CENTER, b, 32, Color(ton.r, ton.g, ton.b, ein))

    var unterzeile := "+%s Biomasse" % _kurz(_ertrag) if _gewonnen \
        else "%d Knoten stehen noch" % knoten
    draw_string(text, Vector2(feld.position.x, feld.position.y + 104.0),
        unterzeile, HORIZONTAL_ALIGNMENT_CENTER, b, 19,
        Color(0.62, 0.72, 0.70, ein))

    _knopf = Rect2(feld.get_center().x - 110.0, feld.end.y - 84.0, 220.0, 56.0)
    draw_rect(_knopf, Color(ton.r, ton.g, ton.b, 0.16 * ein))
    draw_rect(_knopf, Color(ton.r, ton.g, ton.b, ein), false, 2.0)
    draw_string(display, Vector2(_knopf.position.x, _knopf.get_center().y + 9.0),
        "WEITER" if _gewonnen else "NOCHMAL",
        HORIZONTAL_ALIGNMENT_CENTER, _knopf.size.x, 21,
        Color(0.92, 0.97, 0.95, ein))


## Kurzform großer Zahlen.
static func _kurz(wert: float) -> String:
    if wert < 1000.0:
        return str(int(wert))
    if wert < 1000000.0:
        return "%.1f K" % (wert / 1000.0)
    return "%.1f M" % (wert / 1000000.0)
