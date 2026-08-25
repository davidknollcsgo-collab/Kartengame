## Das Mutterschiff in der Mitte der Formation.
##
## Zugleich die Fläche zum manuellen Anzapfen: in der Anfangsphase ist das die
## einzige Einnahmequelle, deshalb liegt es mittig und ist das Auffälligste im
## Bild.
##
## Alles wird gezeichnet, nichts geladen. Ein Schiff aus Polygonen hat den
## Vorteil, dass die Triebwerke, Signallichter und der Andockring aus demselben
## Zustand leben wie das Spiel selbst - sie leuchten stärker, wenn mehr
## gefördert wird, ohne dass dafür Bilder in mehreren Fassungen nötig wären.
class_name Mutterschiff
extends Node2D

## Halbe Länge des Rumpfs. Das Schiff liegt längs im Hochformat.
const LAENGE := 330.0

## Halbe Breite am Mittelschiff.
const BREITE := 92.0

## Radius des Andockrings; dort enden die Frachtwege der Drohnen.
const RING := 52.0

var _zeit := 0.0
var _blitz := 0.0

## Zwischen 0 und 1: wie stark die Triebwerke arbeiten.
##
## Wird von [Station] aus dem Ausbaustand gesetzt. Eine leere Formation laesst
## die Duesen glimmen, eine volle laesst sie brennen - das ist die einzige
## Stelle, an der man dem Schiff den Fortschritt ansieht.
var last := 0.0


func _process(delta: float) -> void:
    _zeit += delta
    if _blitz > 0.0:
        _blitz = maxf(_blitz - delta * 3.0, 0.0)
    queue_redraw()


## Rückmeldung auf ein Antippen.
func aufblitzen() -> void:
    _blitz = 1.0


## Trefferfläche - großzügig um den Andockring herum, nicht das ganze Schiff.
##
## Der Rumpf reicht fast über den halben Bildschirm; wäre er ganz antippbar,
## träfe man ihn versehentlich bei jedem Schieben der Kamera.
func trefferflaeche() -> Rect2:
    var r := RING + 34.0
    return Rect2(position - Vector2(r, r), Vector2(r, r) * 2.0)


# --- Zeichnen ---------------------------------------------------------------

func _draw() -> void:
    _triebwerke()
    _rumpf()
    _aufbauten()
    _andockring()
    _signallichter()


## Umriss des Rumpfs.
##
## Bewusst stumpf statt spitz: der erste Entwurf lief vorn in eine Spitze aus
## und las sich dadurch als Rakete. Ein Mutterschiff traegt eine Flotte - es
## muss massig wirken, nicht schnell.
func _hull_punkte() -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(-BREITE * 0.30, -LAENGE),        # abgeflachter Bug
        Vector2(BREITE * 0.30, -LAENGE),
        Vector2(BREITE * 0.58, -LAENGE * 0.86),
        Vector2(BREITE * 0.80, -LAENGE * 0.52),
        Vector2(BREITE * 0.96, -LAENGE * 0.10),
        Vector2(BREITE, LAENGE * 0.34),
        Vector2(BREITE * 0.90, LAENGE * 0.74),
        Vector2(BREITE * 0.66, LAENGE * 0.94),   # Heck
        Vector2(-BREITE * 0.66, LAENGE * 0.94),
        Vector2(-BREITE * 0.90, LAENGE * 0.74),
        Vector2(-BREITE, LAENGE * 0.34),
        Vector2(-BREITE * 0.96, -LAENGE * 0.10),
        Vector2(-BREITE * 0.80, -LAENGE * 0.52),
        Vector2(-BREITE * 0.58, -LAENGE * 0.86),
    ])


func _rumpf() -> void:
    var punkte := _hull_punkte()
    draw_colored_polygon(punkte, Color(0.13, 0.15, 0.20))

    var umriss := PackedVector2Array(punkte)
    umriss.append(punkte[0])
    draw_polyline(umriss, Color(0.40, 0.52, 0.64), 2.5, true)

    # Plattenfugen quer über den Rumpf. Sie geben dem Schiff Länge, ohne dass
    # eine Textur nötig wäre.
    var fugen: PackedFloat32Array = [-0.62, -0.34, -0.06, 0.22, 0.50, 0.76]
    for anteil: float in fugen:
        var y := LAENGE * anteil
        var halb := _breite_bei(anteil)
        draw_line(Vector2(-halb * 0.86, y), Vector2(halb * 0.86, y),
            Color(0.24, 0.29, 0.36), 1.4, true)

    # Rückgrat als heller Streifen.
    draw_line(Vector2(0.0, -LAENGE * 0.78), Vector2(0.0, LAENGE * 0.88),
        Color(0.20, 0.26, 0.33), 3.0, true)


## Näherung der halben Rumpfbreite an einer Längsposition.
func _breite_bei(anteil: float) -> float:
    var t := clampf((anteil + 1.0) * 0.5, 0.0, 1.0)
    return BREITE * sin(t * PI) * 1.02 + BREITE * 0.08


## Kommandobrücke vorn, Frachtsektionen mittschiffs.
func _aufbauten() -> void:
    var stahl := Color(0.19, 0.23, 0.29)
    var kante := Color(0.34, 0.44, 0.56)

    # Hangargondeln an beiden Flanken. Sie sind der Grund, warum das Schiff
    # als Traeger gelesen wird und nicht als Frachter: dort starten die
    # Drohnen, und die offenen Tore zeigen das.
    for seite: float in [-1.0, 1.0]:
        var x := seite * BREITE * 0.92
        var gondel := PackedVector2Array([
            Vector2(x, -LAENGE * 0.30), Vector2(x + seite * 24.0, -LAENGE * 0.22),
            Vector2(x + seite * 24.0, LAENGE * 0.16), Vector2(x, LAENGE * 0.24),
        ])
        draw_colored_polygon(gondel, Color(0.15, 0.18, 0.23))
        var gu := PackedVector2Array(gondel)
        gu.append(gondel[0])
        draw_polyline(gu, kante, 1.6, true)
        for i in 3:
            var y := -LAENGE * 0.20 + LAENGE * 0.16 * float(i)
            draw_rect(Rect2(x + seite * 6.0 - (0.0 if seite > 0.0 else 13.0),
                y, 13.0, 16.0), Color(0.08, 0.10, 0.14))

    # Brücke: schmaler Aufbau kurz hinter dem Bug.
    var bruecke := PackedVector2Array([
        Vector2(-20.0, -LAENGE * 0.74),
        Vector2(20.0, -LAENGE * 0.74),
        Vector2(28.0, -LAENGE * 0.52),
        Vector2(-28.0, -LAENGE * 0.52),
    ])
    draw_colored_polygon(bruecke, stahl)
    var bu := PackedVector2Array(bruecke)
    bu.append(bruecke[0])
    draw_polyline(bu, kante, 1.8, true)
    draw_circle(Vector2(0.0, -LAENGE * 0.63), 7.0, Color(0.45, 0.78, 0.95, 0.85))

    # Frachtsektionen: zwei Kästen längs, je Seite einer.
    for seite: float in [-1.0, 1.0]:
        var k := Rect2(seite * 30.0 - 22.0, LAENGE * 0.06, 44.0, LAENGE * 0.40)
        draw_rect(k, stahl)
        draw_rect(k, kante, false, 1.6)
        for i in 3:
            var y := k.position.y + k.size.y * (0.25 + 0.25 * float(i))
            draw_line(Vector2(k.position.x + 5.0, y), Vector2(k.end.x - 5.0, y),
                Color(0.28, 0.34, 0.42), 1.2, true)


## Zwei Triebwerksgondeln am Heck mit Abgasfahne.
func _triebwerke() -> void:
    var schub := clampf(last, 0.0, 1.0)
    var flackern := 0.82 + 0.18 * sin(_zeit * 9.0)
    var glut := Color(0.42, 0.82, 1.0)

    for seite: float in [-1.0, 1.0]:
        var x := seite * BREITE * 0.46
        var y := LAENGE * 0.94

        # Gondel.
        var gondel := PackedVector2Array([
            Vector2(x - 20.0, y - 76.0), Vector2(x + 20.0, y - 76.0),
            Vector2(x + 24.0, y), Vector2(x - 24.0, y),
        ])
        draw_colored_polygon(gondel, Color(0.16, 0.19, 0.24))
        var gu := PackedVector2Array(gondel)
        gu.append(gondel[0])
        draw_polyline(gu, Color(0.36, 0.46, 0.58), 1.8, true)

        # Abgasfahne: mehrere Lagen, nach hinten schmaler und blasser.
        var laenge := 34.0 + 108.0 * schub
        for i in range(4, 0, -1):
            var t := float(i) / 4.0
            var f := glut
            f.a = 0.10 + 0.16 * (1.0 - t) * flackern * (0.35 + 0.65 * schub)
            draw_colored_polygon(PackedVector2Array([
                Vector2(x - 17.0 * t, y),
                Vector2(x + 17.0 * t, y),
                Vector2(x + 5.0 * t, y + laenge * t),
                Vector2(x - 5.0 * t, y + laenge * t),
            ]), f)

        # Heller Kern der Düse.
        var kern := glut.lightened(0.25)
        kern.a = 0.55 + 0.45 * flackern
        draw_circle(Vector2(x, y - 3.0), 8.0 + 4.0 * schub, kern)


## Andockring mittschiffs - dort laufen die Frachtwege zusammen.
func _andockring() -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 1.6)
    var ton := Color(0.34, 0.80, 0.95)

    # Ruhige Scheibe als Untergrund, damit der Ring vor dem Rumpf steht.
    draw_circle(Vector2.ZERO, RING + 10.0, Color(0.09, 0.12, 0.16, 0.92))

    # Zwei gegenläufige Ringe aus Segmenten: Bewegung ohne Animationsdaten.
    for lage in 2:
        var r := RING - float(lage) * 13.0
        var drehung := _zeit * (0.5 if lage == 0 else -0.8)
        var segmente := 8 if lage == 0 else 6
        for i in segmente:
            var a0 := drehung + TAU * float(i) / float(segmente)
            var a1 := a0 + TAU / float(segmente) * 0.62
            var f := ton
            f.a = 0.45 + 0.35 * puls if lage == 0 else 0.30 + 0.30 * puls
            draw_arc(Vector2.ZERO, r, a0, a1, 12, f, 3.0 if lage == 0 else 2.0, true)

    # Andockleuchte in der Mitte; blitzt beim Antippen auf.
    var mitte := ton.lightened(0.18 + 0.5 * _blitz)
    draw_circle(Vector2.ZERO, 15.0 + 7.0 * _blitz, mitte)
    draw_circle(Vector2.ZERO, 22.0 + 9.0 * _blitz, Color(mitte.r, mitte.g, mitte.b, 0.22))

    # Bewusst ohne Beschriftung: der Ring liegt mittschiffs, und jede Schrift
    # daneben landet auf dem Rumpf. Wofuer er da ist, sagt in der Anfangsphase
    # der Einstiegshinweis.


## Positionslichter: rot backbord, grün steuerbord, weiß am Bug.
##
## Sie blinken versetzt, damit das Schiff auch im Stillstand lebendig wirkt.
func _signallichter() -> void:
    var punkte := [
        [Vector2(-BREITE * 0.98, -LAENGE * 0.02), Color(0.95, 0.32, 0.30), 0.0],
        [Vector2(BREITE * 0.98, -LAENGE * 0.02), Color(0.36, 0.92, 0.48), 0.5],
        [Vector2(0.0, -LAENGE * 0.965), Color(0.92, 0.95, 1.0), 0.25],
        [Vector2(-BREITE * 0.70, LAENGE * 0.80), Color(0.95, 0.32, 0.30), 0.75],
        [Vector2(BREITE * 0.70, LAENGE * 0.80), Color(0.36, 0.92, 0.48), 0.15],
    ]
    for p in punkte:
        var takt: float = fmod(_zeit * 0.7 + float(p[2]), 1.0)
        # Kurzes Aufblitzen statt gleichmässigem Pulsieren - so lesen sie sich
        # als Signallicht und nicht als Zierde.
        var staerke := pow(maxf(1.0 - takt * 4.0, 0.0), 1.6)
        if staerke <= 0.01:
            continue
        var f: Color = p[1]
        draw_circle(p[0], 3.4, Color(f.r, f.g, f.b, 0.55 + 0.45 * staerke))
        draw_circle(p[0], 8.0, Color(f.r, f.g, f.b, 0.20 * staerke))
