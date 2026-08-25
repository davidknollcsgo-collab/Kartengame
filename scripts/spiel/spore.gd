## Die fliegende Spore.
##
## Bekommt den fertig berechneten Streckenzug von [Ballistik] und fährt ihn mit
## gleichbleibender Geschwindigkeit ab. Sie rechnet **nichts** selbst nach -
## sonst könnte ihr Weg vom vorhergesagten abweichen, und genau das darf nie
## passieren.
class_name Spore
extends Node2D

## Fluggeschwindigkeit in Weltpunkten je Sekunde.
const TEMPO := 1150.0

## Radius für Treffer an Befallsknoten.
const RADIUS := 7.0

signal abgeprallt(ort: Vector2, nummer: int)
signal angekommen(spur: PackedVector2Array)

var farbe := Color(0.45, 0.95, 0.86)

var _bahn: PackedVector2Array = []
var _abschnitt := 0
var _im_abschnitt := 0.0
var _flaeche: Kammer
var _laeuft := false

## Bereits zurückgelegter Teil der Bahn - zugleich die wachsende Wurzelspur.
var _spur: PackedVector2Array = []


func starte(bahn: PackedVector2Array, flaeche: Kammer) -> void:
    _bahn = bahn
    _flaeche = flaeche
    _abschnitt = 0
    _im_abschnitt = 0.0
    _spur = PackedVector2Array([bahn[0]])
    position = bahn[0]
    _laeuft = true
    set_process(true)


func _process(delta: float) -> void:
    if not _laeuft:
        return

    var rest := TEMPO * delta
    # In einem Bild können mehrere kurze Abschnitte überflogen werden; ohne
    # diese Schleife würde die Spore bei engen Abprallern langsamer.
    while rest > 0.0 and _abschnitt < _bahn.size() - 1:
        var a := _bahn[_abschnitt]
        var b := _bahn[_abschnitt + 1]
        var laenge := a.distance_to(b)

        if laenge <= 0.001:
            _abschnitt += 1
            continue

        var uebrig := laenge - _im_abschnitt
        if rest < uebrig:
            _im_abschnitt += rest
            rest = 0.0
        else:
            rest -= uebrig
            _im_abschnitt = 0.0
            _abschnitt += 1
            _spur.append(b)
            position = b
            _pruefe_knoten(b)
            if _abschnitt < _bahn.size() - 1:
                abgeprallt.emit(b, _abschnitt)
            continue

        var neu := a.lerp(b, _im_abschnitt / laenge)
        # Auf dem Weg zwischen zwei Stützpunkten ebenfalls prüfen, sonst fliegt
        # die Spore bei hohem Tempo durch Knoten hindurch.
        _pruefe_strecke(position, neu)
        position = neu

    if _abschnitt >= _bahn.size() - 1:
        _laeuft = false
        set_process(false)
        _spur.append(_bahn[_bahn.size() - 1])
        angekommen.emit(_spur)
        queue_free()
        return

    queue_redraw()


## Prüft die Strecke zwischen zwei Bildern in kleinen Schritten.
func _pruefe_strecke(von: Vector2, nach: Vector2) -> void:
    var strecke := von.distance_to(nach)
    if strecke <= RADIUS:
        _pruefe_knoten(nach)
        return
    var schritte := int(ceil(strecke / RADIUS))
    for i in range(1, schritte + 1):
        _pruefe_knoten(von.lerp(nach, float(i) / float(schritte)))


func _pruefe_knoten(p: Vector2) -> void:
    if _flaeche != null:
        _flaeche.pruefe_treffer(p, RADIUS)


## Die bereits geflogene Spur, damit sie mitwächst.
func gefloge_spur() -> PackedVector2Array:
    var s := PackedVector2Array(_spur)
    s.append(position)
    return s


func _draw() -> void:
    # Kopf der Spore: heller Kern mit Saum.
    draw_circle(Vector2.ZERO, RADIUS * 2.6, Color(farbe.r, farbe.g, farbe.b, 0.14))
    draw_circle(Vector2.ZERO, RADIUS * 1.5, Color(farbe.r, farbe.g, farbe.b, 0.30))
    draw_circle(Vector2.ZERO, RADIUS, farbe.lightened(0.35))
