## Treibender Fund, der angetippt werden kann.
##
## Bewegt sich langsam quer durchs Bild und verschwindet nach einer Weile von
## selbst. Die letzten Sekunden blinkt er schneller - ohne diesen Hinweis
## verschwindet er für den Spieler scheinbar grundlos.
class_name Fund
extends Node2D

## Kantenlänge der Trefferfläche. Großzügig, weil sich das Ziel bewegt.
const GROESSE := 78.0

signal angetippt(art: int)
signal verfallen

var art := 0

var _alter := 0.0
var _von := Vector2.ZERO
var _nach := Vector2.ZERO
var _puls := 0.0


func starte(neue_art: int, von: Vector2, nach: Vector2) -> void:
    art = neue_art
    _von = von
    _nach = nach
    position = von
    _alter = 0.0


func trefferflaeche() -> Rect2:
    return Rect2(position - Vector2(GROESSE, GROESSE) * 0.5,
        Vector2(GROESSE, GROESSE))


func _process(delta: float) -> void:
    _alter += delta
    if _alter >= Ereignis.SICHTBAR:
        verfallen.emit()
        queue_free()
        return
    # Die Strecke wird ueber die Lebensdauer verteilt statt mit fester
    # Geschwindigkeit abgefahren. Mit festem Tempo haengt es von der Strecke ab,
    # wie viel davon ueberhaupt im Bild liegt - beim ersten Versuch war der Fund
    # fast nie sichtbar und damit nicht antippbar.
    position = _von.lerp(_nach, _alter / Ereignis.SICHTBAR)
    _puls += delta
    queue_redraw()


## Meldet einen Treffer. Gibt zurück, ob der Punkt den Fund traf.
func tippe(punkt: Vector2) -> bool:
    if not trefferflaeche().has_point(punkt):
        return false
    angetippt.emit(art)
    queue_free()
    return true


func _draw() -> void:
    var rest := Ereignis.SICHTBAR - _alter
    # In den letzten fünf Sekunden schneller blinken.
    var takt := 2.0 if rest > 5.0 else 7.0
    var schlag := 0.5 + 0.5 * sin(_puls * takt)

    var farbe := _farbe()
    var r := GROESSE * 0.34

    # Schein nach aussen, damit er sich vom Nebel abhebt.
    for i in range(3, 0, -1):
        var f := farbe
        f.a = 0.06 + 0.05 * schlag
        draw_circle(Vector2.ZERO, r + float(i) * 7.0, f)

    draw_circle(Vector2.ZERO, r, Color(0.06, 0.08, 0.12, 0.92))
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, farbe, 2.5 + schlag, true)
    Waehrung.zeichne_zeichen(self, _zeichen(), Vector2.ZERO, r * 0.52,
        farbe.lightened(0.25 * schlag))


func _farbe() -> Color:
    match art:
        Ereignis.Art.QUANTEN:
            return Color(0.58, 0.86, 0.98)
        Ereignis.Art.SCHUB:
            return Color(1.0, 0.78, 0.36)
    return Color(0.52, 0.92, 0.68)


func _zeichen() -> Waehrung.Art:
    match art:
        Ereignis.Art.QUANTEN:
            return Waehrung.Art.QUANTEN
        Ereignis.Art.SCHUB:
            return Waehrung.Art.PROTOKOLL
    return Waehrung.Art.PLASMA
