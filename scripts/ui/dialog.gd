## Modales Fenster mit Titel, Text und bis zu zwei Knoepfen.
##
## Wird fuer Prestige und die Offline-Gutschrift verwendet. Bewusst selbst
## gezeichnet statt ueber Godots Standardfenster: die bringen ein eigenes
## Aussehen mit, das neben der Station wie ein Fremdkoerper wirkt.
class_name Dialog
extends Control

const KNOPF_HOEHE := 64.0

signal bestaetigt
signal abgebrochen

var titel := ""
var zeilen: PackedStringArray = []
var ja_text := "Bestätigen"
var nein_text := "Abbrechen"
var ja_moeglich := true
var _nur_ja := false

var _feld := Rect2()
var _ja := Rect2()
var _nein := Rect2()


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(func():
        size = get_viewport_rect().size
        queue_redraw())


## Fuellt und zeigt den Dialog. Ohne [param nein] gibt es nur einen Knopf.
func zeige(neuer_titel: String, neue_zeilen: PackedStringArray,
        ja: String, nein: String = "", moeglich: bool = true) -> void:
    titel = neuer_titel
    zeilen = neue_zeilen
    ja_text = ja
    nein_text = nein
    _nur_ja = nein.is_empty()
    ja_moeglich = moeglich
    visible = true
    queue_redraw()


func _gui_input(ereignis: InputEvent) -> void:
    if not visible or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return

    if _ja.has_point(m.position) and ja_moeglich:
        visible = false
        bestaetigt.emit()
    elif not _nur_ja and _nein.has_point(m.position):
        visible = false
        abgebrochen.emit()
    # Klicks daneben schlucken - ein modaler Dialog darf nicht durchlassen.
    accept_event()


func _draw() -> void:
    var schrift := Schrift.text()

    # Abdunkeln, damit klar ist, dass dahinter nichts bedienbar ist.
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.72))

    var hoehe := 200.0 + float(zeilen.size()) * 38.0
    _feld = Masse.fenster(size, hoehe)
    var BREITE := _feld.size.x
    # Knopfbreite aus dem Fenster ableiten: bei zwei Knöpfen je knapp die
    # Hälfte, sonst ragen sie auf schmalen Geräten über den Rahmen hinaus.
    var KNOPF := Vector2((BREITE - 96.0) * 0.5 if not _nur_ja else 220.0, KNOPF_HOEHE)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.09, 0.11, 0.15, 0.98))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), Color(0.30, 0.62, 0.78), 2.0, true)

    draw_string(schrift, Vector2(_feld.position.x, _feld.position.y + 56.0), titel,
        HORIZONTAL_ALIGNMENT_CENTER, BREITE, 30, Color(0.94, 0.96, 1.0))

    var y := _feld.position.y + 108.0
    for zeile in zeilen:
        draw_string(schrift, Vector2(_feld.position.x + 40.0, y), zeile,
            HORIZONTAL_ALIGNMENT_CENTER, BREITE - 80.0, 19, Color(0.72, 0.78, 0.86))
        y += 38.0

    var unten := _feld.end.y - KNOPF.y - 26.0
    if _nur_ja:
        _ja = Rect2(_feld.get_center().x - KNOPF.x * 0.5, unten, KNOPF.x, KNOPF.y)
        _nein = Rect2()
    else:
        _ja = Rect2(_feld.end.x - KNOPF.x - 32.0, unten, KNOPF.x, KNOPF.y)
        _nein = Rect2(_feld.position.x + 32.0, unten, KNOPF.x, KNOPF.y)
        _knopf(_nein, nein_text, Color(0.42, 0.46, 0.54), true)
    _knopf(_ja, ja_text, Color(0.26, 0.72, 0.90), ja_moeglich)


func _knopf(r: Rect2, text: String, ton: Color, moeglich: bool) -> void:
    var farbe := ton if moeglich else ton.darkened(0.55)
    draw_colored_polygon(Formen.kante(r, 12.0), Color(farbe.r, farbe.g, farbe.b, 0.20))
    draw_polyline(Formen.kante_umriss(r, 12.0), farbe, 2.0, true)
    draw_string(Schrift.text(),
        Vector2(r.position.x, r.get_center().y + 8.0), text,
        HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 21,
        Color(0.95, 0.97, 1.0) if moeglich else Color(0.45, 0.48, 0.54))
