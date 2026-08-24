## Bericht: Kennzahlen und Errungenschaften.
##
## Beides auf einem Bildschirm, weil beides dieselbe Frage beantwortet - wie
## weit bin ich?
##
## Das Löschen steht bewusst allein am unteren Rand, mit nichts daneben und
## nichts darunter. Es ist der einzige unwiderrufliche Griff im ganzen Spiel;
## direkt neben einem harmlosen "Schließen" wäre es eine Falle. Geschlossen
## wird deshalb über das Kreuz oben rechts.
class_name BerichtSchirm
extends Control

## Höhe einer Errungenschaftszeile.
const ZEILE := 74.0

signal geschlossen
signal zuruecksetzen_gewuenscht
signal lizenzen_gewuenscht

var _feld := Rect2()
var _schliessen := Rect2()
var _reset := Rect2()
var _lizenzen := Rect2()
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
    if not visible or not (ereignis is InputEventMouseButton):
        return
    var m := ereignis as InputEventMouseButton
    if m.button_index != MOUSE_BUTTON_LEFT or m.pressed:
        return
    if _schliessen.has_point(m.position):
        visible = false
        geschlossen.emit()
    elif _lizenzen.has_point(m.position):
        lizenzen_gewuenscht.emit()
    elif _reset.has_point(m.position):
        zuruecksetzen_gewuenscht.emit()
    accept_event()


func _draw() -> void:
    var titel := Schrift.titel()
    var text := Schrift.text()
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.80))

    _feld = Masse.fenster(size, size.y - Masse.RAND * 2.0)
    draw_colored_polygon(Formen.kante(_feld, 20.0), Color(0.08, 0.10, 0.14, 0.98))
    draw_polyline(Formen.kante_umriss(_feld, 20.0), Color(0.46, 0.58, 0.76), 2.0, true)

    var links := _feld.position.x + 26.0
    var innen := _feld.size.x - 52.0

    draw_string(titel, Vector2(links, _feld.position.y + 48.0), "BERICHT",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.94, 0.96, 1.0))
    _zeichne_kreuz()

    # Zugang zu den Lizenzen im Kopf, bewusst weit weg vom Löschknopf.
    _lizenzen = Rect2(_schliessen.position.x - 116.0, _feld.position.y + 20.0,
        104.0, Masse.TIPPFLAECHE - 8.0)
    draw_string(text, Vector2(_lizenzen.position.x, _lizenzen.get_center().y + 6.0),
        "Lizenzen", HORIZONTAL_ALIGNMENT_CENTER, _lizenzen.size.x, 16,
        Color(0.54, 0.66, 0.82))
    draw_line(Vector2(_lizenzen.position.x + 18.0, _lizenzen.get_center().y + 12.0),
        Vector2(_lizenzen.end.x - 18.0, _lizenzen.get_center().y + 12.0),
        Color(0.36, 0.46, 0.60), 1.0)

    var y := _feld.position.y + 82.0
    for paar in _kennzahlen():
        draw_string(text, Vector2(links, y), paar[0],
            HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.56, 0.62, 0.70))
        var wert := Color(0.90, 0.93, 0.98)
        # -1 heisst: reine Zahl ohne Waehrungszeichen.
        if int(paar[2]) < 0:
            draw_string(titel, Vector2(links, y), paar[1],
                HORIZONTAL_ALIGNMENT_RIGHT, innen, 16, wert)
        else:
            Waehrung.zeichne(self, titel, Vector2(_feld.end.x - 26.0, y),
                paar[1], paar[2] as Waehrung.Art, 16, wert, Waehrung.Lage.RECHTS)
        y += 30.0

    y += 10.0
    draw_line(Vector2(links, y), Vector2(_feld.end.x - 26.0, y),
        Color(0.20, 0.24, 0.30), 1.0)
    y += 26.0
    draw_string(titel, Vector2(links, y),
        "ERRUNGENSCHAFTEN  %d/%d" % [Spielstand.errungen.size(),
            Errungenschaft.TABELLE.size()],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.72, 0.80, 0.90))
    y += 14.0

    # Der Löschknopf bekommt seinen eigenen Streifen am Fuß, deutlich abgesetzt.
    var fuss := 108.0
    var frei := _feld.end.y - y - fuss

    # Auf ganze Zeilen abrunden: sonst steht am unteren Rand ein angeschnittener
    # Eintrag, der wie ein Darstellungsfehler aussieht.
    var zeilen := maxi(int(frei / ZEILE), 1)
    _liste.position = Vector2(links, y)
    _liste.size = Vector2(innen, float(zeilen) * ZEILE)

    _reset = Rect2(_feld.get_center().x - 110.0, _feld.end.y - 74.0, 220.0, 52.0)
    draw_colored_polygon(Formen.kante(_reset, 12.0), Color(0.82, 0.30, 0.28, 0.14))
    draw_polyline(Formen.kante_umriss(_reset, 12.0), Color(0.80, 0.36, 0.34), 2.0, true)
    draw_string(titel, Vector2(_reset.position.x, _reset.get_center().y + 7.0),
        "ALLES LÖSCHEN", HORIZONTAL_ALIGNMENT_CENTER, _reset.size.x, 16,
        Color(0.96, 0.74, 0.72))


## Kreuz oben rechts. Die Trefferfläche ist größer als das gezeichnete Zeichen -
## ein 20 Punkte großes Kreuz trifft niemand mit dem Daumen.
func _zeichne_kreuz() -> void:
    _schliessen = Rect2(_feld.end.x - Masse.TIPPFLAECHE - 14.0,
        _feld.position.y + 16.0, Masse.TIPPFLAECHE, Masse.TIPPFLAECHE)
    var m := _schliessen.get_center()
    var a := 11.0
    var farbe := Color(0.72, 0.78, 0.86)
    draw_line(m + Vector2(-a, -a), m + Vector2(a, a), farbe, 2.5, true)
    draw_line(m + Vector2(a, -a), m + Vector2(-a, a), farbe, 2.5, true)


func _kennzahlen() -> Array:
    var s := Spielstand
    return [
        ["Spielzeit", Zahl.zeit(s.spielzeit), -1],
        ["Gefördert insgesamt", Zahl.kurz(s.lebenszeit_plasma), Waehrung.Art.PLASMA],
        ["Förderung je Sekunde", Zahl.kurz(s.rate()), Waehrung.Art.PLASMA],
        ["Baugruppen", str(_bestand_summe()), -1],
        ["Zurücksetzungen", str(s.prestige_anzahl), -1],
        ["Protokolle", "%d  (x%.2f)" % [s.protokolle,
            Oekonomie.prestige_mult(s.protokolle)], -1],
    ]


func _bestand_summe() -> int:
    var n := 0
    for k in Spielstand.bestand:
        n += k
    return n
