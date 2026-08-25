## Lizenzen der verwendeten Fremdbestandteile.
##
## Kein Zierrat, sondern Pflicht: MIT (Godot) und SIL OFL (Orbitron, Rajdhani)
## verlangen beide, dass der Lizenztext mit der Anwendung ausgeliefert wird.
## Ohne diesen Bildschirm verletzt die App die Lizenzen - auch wenn niemand
## klagt.
##
## Godots eigene Fremdbestandteile werden zur Laufzeit über
## [method Engine.get_license_text] geholt statt hier abgeschrieben; so bleibt
## der Text auch nach einem Engine-Wechsel richtig.
class_name LizenzSchirm
extends Control

signal geschlossen

var _feld := Rect2()
var _schliessen := Rect2()
var _text: LizenzText


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _text = LizenzText.new()
    add_child(_text)
    _text.setze(_sammle())
    _passe_an()
    get_viewport().size_changed.connect(_passe_an)


func _passe_an() -> void:
    size = get_viewport_rect().size
    queue_redraw()


## Trägt alle Lizenztexte zusammen.
func _sammle() -> String:
    var teile: PackedStringArray = []
    teile.append("STERNWERFT verwendet die folgenden Bestandteile Dritter.\n")

    teile.append("\n── Godot Engine ──\n")
    teile.append(Engine.get_license_text())

    for paar in [
        ["Orbitron", "res://schriften/orbitron/OFL.txt"],
        ["Rajdhani", "res://schriften/rajdhani/OFL.txt"],
    ]:
        teile.append("\n\n── Schrift %s ──\n" % paar[0])
        teile.append(_lies(paar[1]))
    return "".join(teile)


func _lies(pfad: String) -> String:
    var f := FileAccess.open(pfad, FileAccess.READ)
    if f == null:
        # Darf im ausgelieferten Spiel nicht vorkommen; der Hinweis ist besser
        # als eine leere Seite, die wie ein Fehler aussieht.
        push_warning("Lizenztext fehlt: %s" % pfad)
        return "(Lizenztext nicht auffindbar: %s)" % pfad
    var t := f.get_as_text()
    f.close()
    return t


func _gui_input(ereignis: InputEvent) -> void:
    if not visible or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index == MOUSE_BUTTON_LEFT and not m.pressed \
            and _schliessen.has_point(m.position):
        visible = false
        geschlossen.emit()
    accept_event()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.86))
    _feld = Masse.fenster(size, size.y - Masse.RAND * 2.0)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.07, 0.09, 0.12, 0.99))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), Color(0.42, 0.52, 0.68), 2.0, true)

    draw_string(Schrift.titel(), Vector2(_feld.position.x + 26.0,
        _feld.position.y + 48.0), "LIZENZEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
        Color(0.92, 0.95, 1.0))

    _schliessen = Rect2(_feld.end.x - Masse.TIPPFLAECHE - 14.0,
        _feld.position.y + 14.0, Masse.TIPPFLAECHE, Masse.TIPPFLAECHE)
    var m := _schliessen.get_center()
    var a := 11.0
    var f := Color(0.72, 0.78, 0.86)
    draw_line(m + Vector2(-a, -a), m + Vector2(a, a), f, 2.5, true)
    draw_line(m + Vector2(a, -a), m + Vector2(-a, a), f, 2.5, true)

    var oben := _feld.position.y + 72.0
    _text.position = Vector2(_feld.position.x + 24.0, oben)
    _text.size = Vector2(_feld.size.x - 48.0, _feld.end.y - oben - 24.0)
