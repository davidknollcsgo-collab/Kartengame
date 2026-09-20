extends Node2D

## **Das Pergament, auf dem gekaempft wird.**
##
## Ein Holzschnitt hat keinen Hintergrund im ueblichen Sinn - er hat das
## Blatt, und darauf steht, was gestochen wurde. Hier also: Faser, ein paar
## Flecken, Grasbueschel und Steine. Mehr nicht, und das ist Absicht.
##
## **Was einen Hintergrund laut macht, ist die Zahl der getrennten Dinge
## darin.** In Minute neun stehen hundert Figuren im Bild; jedes zusaetzliche
## Ding darunter ist ein Blick, der nicht auf einem Feind liegt.
##
## Gekachelt um den Helden: `KACHEL` gross, und gezeichnet werden nur die
## Kacheln, die man sieht. Der Inhalt einer Kachel haengt allein an ihren
## Gitterkoordinaten - dieselbe Kachel sieht damit immer gleich aus, egal von
## welcher Seite man sie betritt.

const PERGAMENT := Palette.BODEN
const TINTE := Palette.UMRISS
const SEPIA := Palette.GRUND_ZIER

const KACHEL := 420.0
## Wieviele Dinge auf einer Kachel stehen. Sehr wenige: siehe oben.
const DINGE := 3

var _tu := Tusche.new()
var _mitte := Vector2.ZERO


func setze_mitte(ort: Vector2) -> void:
    # Erst neu zeichnen, wenn man eine halbe Kachel weiter ist. Jedes Bild
    # neu waere derselbe Grund fuer denselben Preis.
    if ort.distance_squared_to(_mitte) < (KACHEL * 0.4) * (KACHEL * 0.4):
        return
    _mitte = ort
    queue_redraw()


func _draw() -> void:
    var sicht := 1100.0
    var von := ((_mitte - Vector2.ONE * sicht) / KACHEL).floor()
    var bis := ((_mitte + Vector2.ONE * sicht) / KACHEL).ceil()
    for gx in range(int(von.x), int(bis.x) + 1):
        for gy in range(int(von.y), int(bis.y) + 1):
            _kachel(gx, gy)
    _tu.spuele(get_canvas_item())


func _kachel(gx: int, gy: int) -> void:
    var rng := RandomNumberGenerator.new()
    # Die Saat haengt allein am Gitterplatz: dieselbe Kachel sieht immer
    # gleich aus, egal von welcher Seite man sie betritt.
    rng.seed = hash(Vector2i(gx, gy)) & 0x7fffffff
    var ecke := Vector2(float(gx), float(gy)) * KACHEL

    # Faser: sehr blass, sehr kurz. Man sieht sie nie einzeln und merkt
    # sofort, wenn sie fehlt.
    for i in 9:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var w := rng.randf() * PI
        var l := 18.0 + rng.randf() * 46.0
        var d := Vector2(cos(w), sin(w) * 0.3) * l
        _tu.zug(p - d * 0.5, p + d * 0.5, 2.4,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.05 + rng.randf() * 0.04),
            0.5, 0.0, 0.0, 3)

    for i in DINGE:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        if rng.randf() < 0.55:
            _gras(p, rng)
        else:
            _stein(p, rng)


func _gras(p: Vector2, rng: RandomNumberGenerator) -> void:
    var halme := 3 + rng.randi_range(0, 2)
    for i in halme:
        var l := 14.0 + rng.randf() * 22.0
        var neige := (rng.randf() - 0.5) * 20.0
        _tu.zug(p + Vector2(float(i) * 5.0 - 6.0, 0.0),
            p + Vector2(float(i) * 5.0 - 6.0 + neige, -l), 2.6,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.26), 0.0, 0.7, 2.0, 3)


func _stein(p: Vector2, rng: RandomNumberGenerator) -> void:
    var r := 7.0 + rng.randf() * 13.0
    _tu.klecks(p, r, Color(TINTE.r, TINTE.g, TINTE.b, 0.16), int(p.x))
    # **Ein Stein im Holzschnitt ist eine Kontur mit Schraffur**, keine
    # Flaeche: eine gefuellte Scheibe liest sich als Loch im Blatt.
    _tu.schraffur(p + Vector2(-r * 0.6, r * 0.2), p + Vector2(r * 0.6, -r * 0.2),
        r * 1.1, 3, Color(TINTE.r, TINTE.g, TINTE.b, 0.22), 1.5)
