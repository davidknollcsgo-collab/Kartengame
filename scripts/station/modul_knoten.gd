## Eine Baugruppe der Station, prozedural gezeichnet.
##
## Zeigt Name, Stueckzahl und Preis und leuchtet auf, sobald mindestens ein
## Exemplar steht. Die Statusleiste am unteren Rand fuellt sich bis zum
## naechsten Meilenstein - das macht den Sprung sichtbar, bevor er eintritt.
class_name ModulKnoten
extends Node2D

const GROESSE := Vector2(196, 132)
const SCHRAEGE := 14.0

var index := 0
var anzahl := 0
var bezahlbar := false

var _puls := 0.0


func _ready() -> void:
    set_process(true)


func _process(delta: float) -> void:
    # Nur aktive Baugruppen pulsieren - stillstehende sollen ruhig wirken.
    if anzahl > 0:
        _puls = fmod(_puls + delta, TAU)
        queue_redraw()


## Rechteck der Baugruppe in lokalen Koordinaten des Elternknotens.
func trefferflaeche() -> Rect2:
    return Rect2(position - GROESSE * 0.5, GROESSE)


func aktualisiere(neue_anzahl: int, ist_bezahlbar: bool) -> void:
    if neue_anzahl == anzahl and ist_bezahlbar == bezahlbar:
        return
    anzahl = neue_anzahl
    bezahlbar = ist_bezahlbar
    queue_redraw()


func _draw() -> void:
    var r := Rect2(-GROESSE * 0.5, GROESSE)
    var leit := Modul.farbe(index)
    var aktiv := anzahl > 0

    # Rumpf: dunkel, damit die Leitfarbe traegt.
    var rumpf := Color(0.11, 0.13, 0.17) if aktiv else Color(0.08, 0.09, 0.11)
    draw_colored_polygon(Formen.kante(r, SCHRAEGE), rumpf)

    # Kontur - bei bezahlbaren Baugruppen deutlich heller als Kaufhinweis.
    var kontur := leit if aktiv else Color(0.22, 0.25, 0.30)
    var breite := 2.0
    if bezahlbar:
        kontur = leit.lightened(0.35)
        breite = 3.0
    draw_polyline(Formen.kante_umriss(r, SCHRAEGE), kontur, breite, true)

    # Leitstreifen links, Helligkeit atmet mit dem Puls.
    var glut := leit
    if aktiv:
        glut = leit.lightened(0.12 + 0.10 * sin(_puls * 2.0))
    else:
        glut = leit.darkened(0.65)
    draw_rect(Rect2(r.position.x + 8.0, r.position.y + 16.0, 6.0, r.size.y - 32.0), glut)

    var schrift := ThemeDB.fallback_font
    var hell := Color(0.92, 0.94, 0.97) if aktiv else Color(0.45, 0.48, 0.53)

    draw_string(schrift, Vector2(r.position.x + 24.0, r.position.y + 34.0),
        Modul.name_von(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, hell)

    draw_string(schrift, Vector2(r.position.x + 24.0, r.position.y + 60.0),
        "x%d" % anzahl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
        leit if aktiv else Color(0.40, 0.43, 0.48))

    var preis := Oekonomie.kosten(index, anzahl)
    draw_string(schrift, Vector2(r.position.x + 24.0, r.position.y + 84.0),
        Zahl.kurz(preis) + " ¢", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
        Color(0.55, 0.95, 0.65) if bezahlbar else Color(0.48, 0.51, 0.56))

    _zeichne_meilenstein(r, leit)


## Fortschrittsleiste bis zum naechsten Stueckzahl-Meilenstein.
func _zeichne_meilenstein(r: Rect2, leit: Color) -> void:
    var naechster := 0
    for schwelle in Modul.MEILENSTEINE:
        if anzahl < schwelle:
            naechster = schwelle
            break
    if naechster == 0:
        return

    var vorheriger := 0
    for schwelle in Modul.MEILENSTEINE:
        if schwelle <= anzahl:
            vorheriger = schwelle
    var anteil := float(anzahl - vorheriger) / float(naechster - vorheriger)

    var bahn := Rect2(r.position.x + 22.0, r.end.y - 18.0, r.size.x - 44.0, 4.0)
    draw_rect(bahn, Color(0.20, 0.22, 0.27))
    if anteil > 0.0:
        draw_rect(Rect2(bahn.position, Vector2(bahn.size.x * anteil, bahn.size.y)),
            leit.lightened(0.15))
