extends Node2D

## Was zwischen dem Auge und dem Spiel schwebt.
##
## **Warum es das braucht.** Tiefe entsteht nicht daraus, dass hinten etwas
## steht, sondern daraus, dass etwas **davor** steht. Solange alles im Bild
## dieselbe Entfernung hat, bleibt es eine Zeichnung - egal wie viele Ebenen
## dahinter liegen. Also: grosse, sehr weiche Schwaden aus Schlick und ein paar
## nahe Flocken, unscharf und traege, direkt vor der Kamera.
##
## Alles hier ist bewusst schwach gedeckt. Ein Vordergrund, der das Spiel
## verdeckt, ist kein Vordergrund, sondern ein Vorhang - und die Raeuber
## muessen jederzeit lesbar bleiben.

## Schwaden: grosse, dunkle, sehr weiche Flaechen.
const SCHWADEN := 5
const SCHWADEN_DECKUNG := 0.16

## Nahe Flocken: gross, unscharf, schnell. Sie geben dem Bild eine vorderste
## Ebene, an der das Auge die Entfernung aller anderen misst.
const FLOCKEN := 26
const FLOCKEN_DECKUNG := 0.20

const SCHLICK := Color(0.020, 0.045, 0.062)
const FLOCKE := Color(0.42, 0.66, 0.74)

## Wie stark der Vordergrund insgesamt sichtbar ist. `wache.gd` senkt es, wenn
## das Bild voll ist - Lesbarkeit geht vor Stimmung.
var staerke := 1.0

var _zeit := 0.0
var _schwaden: Array[Dictionary] = []
var _flocken: Array[Dictionary] = []


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x4e454b33

    for i in SCHWADEN:
        var punkte := PackedVector2Array()
        var breit := rng.randf_range(220.0, 480.0)
        var hoch := rng.randf_range(90.0, 210.0)
        var ecken := 9
        for k in ecken:
            var w := TAU * float(k) / float(ecken)
            var zerre := 0.62 + 0.38 * rng.randf()
            punkte.append(Vector2(cos(w) * breit * zerre, sin(w) * hoch * zerre))
        _schwaden.append({
            &"punkte": punkte,
            &"x": rng.randf_range(Graben.FELD.position.x, Graben.FELD.end.x),
            &"y": rng.randf_range(Graben.FELD.position.y, Graben.FELD.end.y),
            &"tempo": rng.randf_range(7.0, 17.0),
            &"takt": rng.randf_range(0.10, 0.26),
            &"weite": rng.randf_range(18.0, 52.0),
        })

    for i in FLOCKEN:
        _flocken.append({
            &"x": rng.randf_range(Graben.FELD.position.x - 60.0, Graben.FELD.end.x + 60.0),
            &"y": rng.randf_range(Graben.FELD.position.y, Graben.FELD.end.y),
            &"r": rng.randf_range(2.6, 7.0),
            &"tempo": rng.randf_range(26.0, 62.0),
            &"takt": rng.randf_range(0.4, 1.2),
            &"weite": rng.randf_range(8.0, 26.0),
        })


func _process(delta: float) -> void:
    _zeit += delta
    queue_redraw()


func _draw() -> void:
    if staerke <= 0.01:
        return
    _zeichne_schwaden()
    _zeichne_flocken()


## Schlickschwaden. Sie steigen langsam, weil der Spieler in den Graben
## hinabsieht - was faellt, faellt von ihm weg, und was steigt, kommt auf ihn zu.
func _zeichne_schwaden() -> void:
    var hoehe := Graben.FELD.size.y + 500.0
    for s in _schwaden:
        var y: float = float(s[&"y"]) - fmod(_zeit * float(s[&"tempo"]), hoehe)
        if y < Graben.FELD.position.y - 250.0:
            y += hoehe
        var x: float = float(s[&"x"]) \
            + sin(_zeit * float(s[&"takt"])) * float(s[&"weite"])
        var mitte := Vector2(x, y)

        # Drei ineinandergelegte Stufen statt einer harten Kante: eine
        # Schlickwolke hat keinen Umriss.
        var punkte: PackedVector2Array = s[&"punkte"]
        for stufe in 3:
            var wuchs := 1.0 - 0.26 * float(stufe)
            var flaeche := PackedVector2Array()
            for p in punkte:
                flaeche.append(mitte + p * wuchs)
            draw_colored_polygon(flaeche, Color(SCHLICK.r, SCHLICK.g, SCHLICK.b,
                SCHWADEN_DECKUNG * staerke * (0.32 + 0.34 * float(stufe))))


## Nahe Flocken. Gross und weich - sie sind ausserhalb der Schaerfe, und genau
## das macht sie zur vordersten Ebene.
func _zeichne_flocken() -> void:
    var hoehe := Graben.FELD.size.y + 200.0
    for f in _flocken:
        var y: float = Graben.FELD.position.y \
            + fmod(float(f[&"y"]) - Graben.FELD.position.y
                + _zeit * float(f[&"tempo"]), hoehe)
        var x: float = float(f[&"x"]) \
            + sin(_zeit * float(f[&"takt"])) * float(f[&"weite"])
        var p := Vector2(x, y)
        var r: float = float(f[&"r"])
        for ring in 3:
            var t := float(ring + 1) / 3.0
            draw_circle(p, r * (0.5 + 1.5 * t), Color(FLOCKE.r, FLOCKE.g, FLOCKE.b,
                FLOCKEN_DECKUNG * staerke * (1.0 - t) * 0.5))
