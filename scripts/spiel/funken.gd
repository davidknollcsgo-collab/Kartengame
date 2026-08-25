extends Node2D

## Funken, Strahlen und Platzer.
##
## Eigene kleine Teilchenverwaltung statt `GPUParticles2D`: die Teilchen sollen
## in derselben Reihenfolge und mit denselben Farben entstehen wie die
## Ereignisse, die sie ausloesen, und ein Partikelsystem je Ereignis
## anzulegen kostet auf einem Telefon mehr als das Zeichnen selbst.

const HOECHSTZAHL := 420
const STRAHL_LEBEN := 0.085


class Teilchen extends RefCounted:
    var ort := Vector2.ZERO
    var stoss := Vector2.ZERO
    var farbe := Color.WHITE
    var leben := 0.0
    var voll := 1.0
    var groesse := 2.0


class Strahl extends RefCounted:
    var von := Vector2.ZERO
    var nach := Vector2.ZERO
    var farbe := Color.WHITE
    var leben := 0.0


var _teilchen: Array[Teilchen] = []
var _strahlen: Array[Strahl] = []


func _ready() -> void:
    var stoff := CanvasItemMaterial.new()
    stoff.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = stoff


func _process(delta: float) -> void:
    for i in range(_teilchen.size() - 1, -1, -1):
        var t := _teilchen[i]
        t.leben -= delta
        if t.leben <= 0.0:
            _teilchen.remove_at(i)
            continue
        # Auftrieb und Wasserwiderstand: die Funken treiben nach oben aus und
        # werden langsam. Im Wasser faellt nichts.
        t.stoss = t.stoss.lerp(Vector2(0.0, -26.0), delta * 1.6)
        t.ort += t.stoss * delta

    for i in range(_strahlen.size() - 1, -1, -1):
        _strahlen[i].leben -= delta
        if _strahlen[i].leben <= 0.0:
            _strahlen.remove_at(i)

    queue_redraw()


## Ein Treffer: der Raeuber zerfaellt in Funken.
func platzen(ort: Vector2, farbe: Color, radius: float) -> void:
    var zahl := clampi(int(radius * 0.9), 6, 22)
    for _i in zahl:
        if _teilchen.size() >= HOECHSTZAHL:
            return
        var t := Teilchen.new()
        t.ort = ort
        t.stoss = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 190.0)
        t.farbe = farbe.lerp(Color(1.0, 0.98, 0.92), randf() * 0.55)
        t.voll = randf_range(0.35, 0.95)
        t.leben = t.voll
        t.groesse = randf_range(1.4, 3.4)
        _teilchen.append(t)


## Ein kurzer Lichtfaden von der Quelle zum getroffenen Tier. Macht sichtbar,
## *wen* der Kegel gerade fasst - der Kegel allein zeigt nur, wo Licht ist.
func strahl(von: Vector2, nach: Vector2, farbe: Color) -> void:
    if _strahlen.size() >= HOECHSTZAHL:
        return
    var s := Strahl.new()
    s.von = von
    s.nach = nach
    s.farbe = farbe
    s.leben = STRAHL_LEBEN
    _strahlen.append(s)


func _draw() -> void:
    for s in _strahlen:
        var f := s.leben / STRAHL_LEBEN
        draw_line(s.von, s.nach,
            Color(s.farbe.r, s.farbe.g, s.farbe.b, 0.30 * f), 1.4, true)
        draw_circle(s.nach, 4.0 * f, Color(1.0, 0.98, 0.92, 0.5 * f))

    for t in _teilchen:
        var f := t.leben / t.voll
        draw_circle(t.ort, t.groesse * f,
            Color(t.farbe.r, t.farbe.g, t.farbe.b, f * 0.9))
