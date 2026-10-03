extends Node2D

## **Der Boden, der sich bewegt.**
##
## `feld.gd` zeichnet den Boden nur neu, wenn man eine halbe Kachel weiter
## ist - ein stilles Bild, und das ist der Grund, warum er bezahlbar ist. Was
## sich bewegen soll, steht deshalb hier, in einem eigenen Knoten desselben
## Unterbilds, der jedes Bild neu zeichnet: Grasbueschel und Schilf, die sich
## wiegen, wenn eine Windwelle schraeg uebers Feld laeuft, und Wasser, das
## glitzert.
##
## **Kein Zufall aus der Simulation** (siehe `_zier` in `zug_lauf.gd`): was
## hier glitzert, haengt an Zeit und Ort, nicht an einem Wuerfel.

const P := Pixel.P

@onready var _feld: Node2D = get_node("../Feld")
var _zeit := 0.0
var _bilder := {}


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(d: float) -> void:
    _zeit += d
    queue_redraw()


## Ein Bueschel in Ruhe oder im Ausschlag, gemerkt.
func _bild(name: String, ausschlag: bool) -> Array:
    var k := name + ("|w" if ausschlag else "|r")
    var v: Variant = _bilder.get(k)
    if v == null:
        var d := Landschaft.bild_von(name)
        var schluessel := "leben|" + k
        var r := Pixel.bild(schluessel, Landschaft.wiege(d[0], ausschlag, 0.5),
            Landschaft.kleid(d[2]), d[1], false, false, d[3])
        v = [r, Pixel.anker(schluessel, false, false, d[3])]
        _bilder[k] = v
    return v


func _draw() -> void:
    var kamera := get_viewport().get_camera_2d()
    if kamera == null:
        return
    var mitte := kamera.position
    # Das halbe Sichtfeld, bei 20:9 bis 1000 hoch, und ein Rand.
    var halb := Vector2(Gefecht.BILD_HALB_X, 1000.0) + Vector2.ONE * 40.0
    var ci := get_canvas_item()
    var stuecke: Array = _feld.lebendes(mitte, halb)
    for d in stuecke:
        _bild(d[1], false)
        _bild(d[1], true)
    Pixel.bereit()
    for d in stuecke:
        var ort: Vector2 = d[0]
        if absf(ort.x - mitte.x) > halb.x or absf(ort.y - mitte.y) > halb.y:
            continue
        # **Eine Windwelle laeuft schraeg uebers Feld**: wer auf ihrem Kamm
        # steht, neigt sich. Alle zugleich waere ein Ruck, keine Brise.
        var welle := sin(_zeit * 2.1 - ort.x * 0.006 - ort.y * 0.004)
        var b := _bild(d[1], welle > 0.55)
        Pixel.setze(ci, b[0], b[1], ort)
    # **Wasser glitzert**: je Wasserpunkt hin und wieder zwei helle Pixel,
    # an einer Stelle, die aus Zeit und Ort folgt.
    var hell := Palette.WASSER_HELL.lightened(0.35)
    for w in _feld.wasserpunkte(mitte, halb):
        var o: Vector2 = w[0]
        var r: float = w[1]
        if absf(o.x - mitte.x) > halb.x + r or absf(o.y - mitte.y) > halb.y + r:
            continue
        for k in 2:
            var takt := int(_zeit * 2.5 + o.x * 0.013 + float(k) * 1.7)
            var h := hash(Vector3i(int(o.x), int(o.y), takt * 2 + k))
            if h % 3 != 0:
                continue
            var dx := float((h >> 4) % 1000) / 500.0 - 1.0
            var dy := float((h >> 14) % 1000) / 500.0 - 1.0
            var p := o + Vector2(dx * r, dy * r * 0.6)
            Pixel.punkt(ci, p, hell)
            Pixel.punkt(ci, p + Vector2(P, 0.0), Palette.WASSER_HELL)
