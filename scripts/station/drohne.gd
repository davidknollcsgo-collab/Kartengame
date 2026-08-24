## Frachtdrohne, die zwischen einer Versorgungsstation und dem Mutterschiff pendelt.
##
## Rein dekorativ - sie transportiert nichts, was die Rechnung beeinflusst. Ihr
## Zweck ist Rückmeldung: eine Formation, in der sich nichts bewegt, wirkt
## kaputt, auch wenn die Zahlen laufen.
##
## Die Form ist bewusst als Fluggerät erkennbar aufgebaut - Rumpf, zwei
## Auslegerarme mit Triebwerksgondeln, ein Frachtgreifer darunter. Eine bloße
## Pfeilspitze liest sich als Zeiger, nicht als Fahrzeug.
class_name Drohne
extends Node2D

## Grundgröße; der Rumpf ist etwa doppelt so lang wie breit.
const GROESSE := 9.0

var von := Vector2.ZERO
var nach := Vector2.ZERO
var farbe := Color.WHITE

var _fortschritt := 0.0
var _rueckweg := false
var _zeit := 0.0
var _tempo := 150.0


## Setzt die Drohne auf eine neue Strecke.
func starte(a: Vector2, b: Vector2, f: Color, versatz: float = 0.0) -> void:
    von = a
    nach = b
    farbe = f
    _fortschritt = versatz
    _rueckweg = false
    # Leicht unterschiedliche Geschwindigkeiten, damit die Drohnen nicht im
    # Gleichschritt fliegen.
    _tempo = 132.0 + randf() * 46.0


func _process(delta: float) -> void:
    var strecke := von.distance_to(nach)
    if strecke < 1.0:
        return
    _zeit += delta
    _fortschritt += delta * _tempo / strecke
    if _fortschritt >= 1.0:
        _fortschritt = 0.0
        _rueckweg = not _rueckweg

    var a := nach if _rueckweg else von
    var b := von if _rueckweg else nach
    # Leichter Bogen statt schnurgerader Linie: Fluggeräte fliegen keine
    # Lineale, und der Versatz trennt Hin- und Rückweg sichtbar.
    var gerade := a.lerp(b, _fortschritt)
    var quer := (b - a).orthogonal().normalized()
    var bogen := sin(_fortschritt * PI) * 16.0 * (1.0 if _rueckweg else -1.0)
    position = gerade + quer * bogen

    rotation = (b - a).angle() + bogen * 0.0009
    queue_redraw()


func _draw() -> void:
    var beladen := not _rueckweg
    var s := GROESSE
    var rumpf := Color(0.20, 0.23, 0.29)
    var kante := farbe if beladen else farbe.darkened(0.35)

    # Auslegerarme mit Gondeln - vier Stück, wie bei einem Quadrocopter.
    for vorne: float in [1.0, -1.0]:
        for seite: float in [1.0, -1.0]:
            var arm := Vector2(s * 0.52 * vorne, s * 0.62 * seite)
            draw_line(Vector2(s * 0.12 * vorne, 0.0), arm,
                Color(0.30, 0.34, 0.41), 1.6, true)
            draw_circle(arm, s * 0.26, rumpf)
            draw_arc(arm, s * 0.26, 0.0, TAU, 10, kante, 1.2, true)

    # Rumpf: längliche Kapsel, vorn schmaler.
    draw_colored_polygon(PackedVector2Array([
        Vector2(s * 0.95, 0.0),
        Vector2(s * 0.30, s * 0.42),
        Vector2(-s * 0.60, s * 0.38),
        Vector2(-s * 0.78, 0.0),
        Vector2(-s * 0.60, -s * 0.38),
        Vector2(s * 0.30, -s * 0.42),
    ]), rumpf)
    draw_polyline(PackedVector2Array([
        Vector2(s * 0.95, 0.0),
        Vector2(s * 0.30, s * 0.42),
        Vector2(-s * 0.60, s * 0.38),
        Vector2(-s * 0.78, 0.0),
        Vector2(-s * 0.60, -s * 0.38),
        Vector2(s * 0.30, -s * 0.42),
        Vector2(s * 0.95, 0.0),
    ]), kante, 1.3, true)

    # Sensorauge vorn.
    draw_circle(Vector2(s * 0.52, 0.0), s * 0.15, kante.lightened(0.3))

    if beladen:
        # Frachtbehälter unter dem Rumpf, in der Leitfarbe der Station.
        var k := Rect2(-s * 0.34, -s * 0.24, s * 0.62, s * 0.48)
        draw_rect(k, Color(farbe.r, farbe.g, farbe.b, 0.55))
        draw_rect(k, farbe.lightened(0.25), false, 1.1)
    else:
        # Leerer Greifer: zwei offene Klauen.
        for seite: float in [1.0, -1.0]:
            draw_line(Vector2(-s * 0.10, s * 0.20 * seite),
                Vector2(-s * 0.40, s * 0.46 * seite),
                Color(0.42, 0.46, 0.54), 1.3, true)

    # Blinklicht am Heck, damit die Drohne auch als Fluggerät gelesen wird.
    var blink := pow(maxf(1.0 - fmod(_zeit * 1.5, 1.0) * 5.0, 0.0), 1.5)
    if blink > 0.02:
        draw_circle(Vector2(-s * 0.72, 0.0), s * 0.16,
            Color(1.0, 0.42, 0.36, 0.5 + 0.5 * blink))
