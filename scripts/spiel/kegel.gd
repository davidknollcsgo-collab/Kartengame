extends Node2D

## Der Lichtkegel.
##
## **Zusicherung:** was hier hell gezeichnet wird, ist genau das, was Schaden
## macht. Beide Seiten fragen `Schlund.beleuchtung()`. Ein Kegel, der weiter
## reicht als er wirkt - oder umgekehrt - macht die Kernschleife unlernbar.
##
## Gezeichnet als Faecher aus Dreiecken mit Farbe je Eckpunkt: jeder Punkt
## bekommt genau die Helligkeit, die die Rechnung ihm gibt. Ein Shader waere
## huebscher, aber dann gaebe es zwei Beschreibungen desselben Kegels, und die
## zweite waere die falsche.

const RIPPEN := 26          ## Aufloesung quer
const RINGE := 9            ## Aufloesung in der Tiefe

## Kaltes Blaugruen mit weissem Kern. Ein grauer Kegel sah im ersten Bild aus
## wie Nebel; Licht braucht Saettigung, nicht nur Helligkeit.
const FARBE := Color(0.24, 0.86, 1.0)
const KERN := Color(0.82, 1.0, 0.96)
const STAERKE := 0.52


var richtung := Vector2.UP
var halbwinkel := Graben.HALBWINKEL
var reichweite := Graben.REICHWEITE
var flackern := 0.0


func _ready() -> void:
    # Additiv: Licht addiert sich zum Wasser, es deckt es nicht ab.
    var stoff := CanvasItemMaterial.new()
    stoff.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = stoff


func _process(delta: float) -> void:
    # Ein leises Atmen, damit der Kegel lebt. Rein optisch - die Rechnung
    # bekommt es nie zu sehen.
    flackern = fmod(flackern + delta * 2.3, TAU)
    queue_redraw()


func _draw() -> void:
    var spitze := Graben.WAECHTER
    var puls := 1.0 + 0.035 * sin(flackern)

    for ring in RINGE:
        var innen := reichweite * float(ring) / float(RINGE)
        var aussen := reichweite * float(ring + 1) / float(RINGE)

        for rippe in RIPPEN:
            var w0 := lerpf(-halbwinkel, halbwinkel, float(rippe) / float(RIPPEN))
            var w1 := lerpf(-halbwinkel, halbwinkel, float(rippe + 1) / float(RIPPEN))

            var punkte := PackedVector2Array([
                spitze + richtung.rotated(w0) * innen,
                spitze + richtung.rotated(w1) * innen,
                spitze + richtung.rotated(w1) * aussen,
                spitze + richtung.rotated(w0) * aussen,
            ])
            var farben := PackedColorArray()
            for p in punkte:
                farben.append(_farbe_an(spitze, p, puls))
            draw_polygon(punkte, farben)

    # Der Austritt am Waechter selbst - ein harter, heller Kern.
    draw_circle(spitze, 13.0, Color(KERN.r, KERN.g, KERN.b, 0.55 * puls))
    draw_circle(spitze, 26.0, Color(FARBE.r, FARBE.g, FARBE.b, 0.16 * puls))


func _farbe_an(spitze: Vector2, punkt: Vector2, puls: float) -> Color:
    var hell := Schlund.beleuchtung(spitze, richtung, halbwinkel, reichweite, punkt)
    if hell <= 0.0:
        return Color(FARBE.r, FARBE.g, FARBE.b, 0.0)
    var mische := FARBE.lerp(KERN, hell * hell)
    return Color(mische.r, mische.g, mische.b, hell * STAERKE * puls)
