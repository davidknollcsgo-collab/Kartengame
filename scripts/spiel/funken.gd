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


## Ein Bruchstueck eines Leibes. Anders als ein Funke hat es eine Form und
## dreht sich - genau daran erkennt das Auge, dass hier etwas zerfaellt und
## nicht bloss etwas funkt.
class Splitter extends RefCounted:
    var ort := Vector2.ZERO
    var stoss := Vector2.ZERO
    var winkel := 0.0
    var drehung := 0.0
    var form := PackedVector2Array()
    var farbe := Color.WHITE
    var leben := 0.0
    var voll := 1.0


## Die Druckwelle eines Todes: ein duenner Ring, der aufgeht und verblasst.
## Sie sagt in einem Bild, was passiert ist, auch wenn der Blick woanders war.
class Ring extends RefCounted:
    var ort := Vector2.ZERO
    var farbe := Color.WHITE
    var leben := 0.0
    var voll := 1.0
    var weite := 40.0


var _teilchen: Array[Teilchen] = []
var _strahlen: Array[Strahl] = []
var _splitter: Array[Splitter] = []
var _ringe: Array[Ring] = []


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

    for i in range(_splitter.size() - 1, -1, -1):
        var sp := _splitter[i]
        sp.leben -= delta
        if sp.leben <= 0.0:
            _splitter.remove_at(i)
            continue
        # Wasserwiderstand: Bruchstuecke werden schnell langsam und treiben
        # dann nur noch. Ein Splitter, der geradeaus weiterfliegt, sieht nach
        # Luft aus, nicht nach Wasser.
        sp.stoss = sp.stoss.lerp(Vector2(0.0, -18.0), delta * 2.4)
        sp.ort += sp.stoss * delta
        sp.drehung *= 1.0 - delta * 1.2
        sp.winkel += sp.drehung * delta

    for i in range(_ringe.size() - 1, -1, -1):
        _ringe[i].leben -= delta
        if _ringe[i].leben <= 0.0:
            _ringe.remove_at(i)

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


## Ein Tod: der Leib zerfaellt in Bruchstuecke, Glut und eine Druckwelle.
##
## Das war vorher ein Funkenausbruch, und Funken sagen "getroffen", nicht
## "gestorben". Drei Dinge zugleich sagen es: Splitter mit Form und Drehung,
## eine kurze helle Blende am Ort, und ein Ring, der aufgeht.
func zerfall(ort: Vector2, farbe: Color, radius: float, richtung: Vector2) -> void:
    platzen(ort, farbe, radius * 0.7)

    var stuecke := clampi(int(radius * 0.34), 3, 9)
    for _i in stuecke:
        if _splitter.size() >= HOECHSTZAHL:
            break
        var sp := Splitter.new()
        sp.ort = ort
        # Der Schwung des Tieres bleibt erhalten, dazu ein Stoss nach aussen.
        sp.stoss = richtung * randf_range(10.0, 40.0) \
            + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 130.0)
        sp.winkel = randf() * TAU
        sp.drehung = randf_range(-7.0, 7.0)
        sp.farbe = farbe.lerp(Color(1.0, 0.98, 0.92), randf() * 0.35)
        sp.voll = randf_range(0.5, 1.15)
        sp.leben = sp.voll

        # Eine unregelmaessige Scherbe. Drei bis vier Ecken reichen - mehr
        # sieht man bei dieser Groesse ohnehin nicht.
        var ecken := randi_range(3, 4)
        var gross := radius * randf_range(0.16, 0.42)
        var form := PackedVector2Array()
        for k in ecken:
            var w := TAU * float(k) / float(ecken) + randf_range(-0.3, 0.3)
            form.append(Vector2(cos(w), sin(w)) * gross * randf_range(0.6, 1.0))
        sp.form = form
        _splitter.append(sp)

    if _ringe.size() < HOECHSTZAHL:
        var ring := Ring.new()
        ring.ort = ort
        ring.farbe = farbe
        ring.voll = 0.42
        ring.leben = ring.voll
        ring.weite = radius * 3.4
        _ringe.append(ring)


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

    for sp in _splitter:
        var f := sp.leben / sp.voll
        var punkte := PackedVector2Array()
        for v in sp.form:
            punkte.append(sp.ort + v.rotated(sp.winkel) * (0.35 + 0.65 * f))
        draw_colored_polygon(punkte, Color(sp.farbe.r, sp.farbe.g, sp.farbe.b,
            0.30 * f))
        draw_polyline(punkte + PackedVector2Array([punkte[0]]),
            Color(sp.farbe.r, sp.farbe.g, sp.farbe.b, 0.70 * f), 1.3, true)

    for ring in _ringe:
        var f := ring.leben / ring.voll
        var r := ring.weite * (1.0 - f * f)
        draw_arc(ring.ort, r, 0.0, TAU, 26,
            Color(1.0, 0.98, 0.92, 0.42 * f * f), 2.2 * f + 0.6, true)
        draw_arc(ring.ort, r * 0.72, 0.0, TAU, 22,
            Color(ring.farbe.r, ring.farbe.g, ring.farbe.b, 0.26 * f), 1.4, true)
