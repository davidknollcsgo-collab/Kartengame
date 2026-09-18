extends Node2D

## **Das Papier.**
##
## Der Hintergrund ist kein Bild, sondern ein Blatt: ein Bodenstrich, ein
## paar Lavierungen, eine Sonnenscheibe in Zinnober, und darueber die Faser
## des Papiers. Mehr nicht - und das ist Absicht.
##
## **Was einen Hintergrund laut macht, ist die Zahl der getrennten Dinge
## darin.** Hier steht die Antwort auf die Frage, die im Duell entscheidet -
## *welche Linie kommt?* -, und jedes zusaetzliche Ding im Bild ist ein
## Blick, der nicht auf der Fuehrungslinie liegt. Der Hintergrund darf
## deshalb Stimmung tragen und sonst nichts.
##
## Er wird **einmal** gezeichnet und nie neu: `_draw()` laeuft nur nach
## `queue_redraw()`, und dieser Knoten ruft es nur beim Wechsel des
## Kapitels. Gesammelt ist alles in einem einzigen Netz, kostet also einen
## Zeichenaufruf je Bild statt hundertvierzig.

const PAPIER := Color(0.937, 0.918, 0.871)
const TINTE := Color(0.09, 0.08, 0.09)
const GRAU := Color(0.44, 0.43, 0.44)
const ZINNOBER := Color(0.78, 0.16, 0.10)

## Wo der Boden liegt. Alle Fechter stehen darauf; eine zweite Zahl dafuer
## waeren zwei Meinungen darueber, wo unten ist.
const BODEN_Y := 806.0

## So viele Fasern. Sie sind der Unterschied zwischen Papier und einer
## leeren Flaeche - einzeln unsichtbar, zusammen ein Blatt.
const FASERN := 150

var _tu := Tusche.new()
var _kapitel := 0


func setze_kapitel(k: int) -> void:
    if k == _kapitel:
        return
    _kapitel = k
    queue_redraw()


func _ready() -> void:
    queue_redraw()


func _draw() -> void:
    var b := 720.0
    var h := 1280.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x504150 + _kapitel * 977

    # **Die Sonnenscheibe.** Der einzige grosse farbige Fleck im ganzen
    # Spiel, und er steht hinter allem: ein Siegel auf dem Blatt. Zinnober
    # gehoert sonst der Gefahr - hier steht er still und blass, damit die
    # Fuehrungslinie ihn jederzeit ueberstimmt.
    var sonne := Vector2(b * (0.30 + 0.40 * float(_kapitel % 3) * 0.5), 320.0)
    _tu.klecks(sonne, 118.0, Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.11),
        _kapitel)

    # **Ferne Duenste** - zwei Lavierungen, sehr breit und sehr blass. Der
    # erste Anlauf nahm drei schmale: im Bild waren das graue Kratzer, die
    # quer ueber dem Blatt hingen. Ein Wisch, den man als Strich lesen kann,
    # ist kein Dunst mehr, sondern ein Gegenstand - und einen Gegenstand
    # darf hier nur tragen, wer im Duell etwas bedeutet.
    for i in 2:
        var y := 500.0 + float(i) * 96.0
        _tu.wisch(Vector2(-120.0, y + 18.0), Vector2(b + 120.0, y - 12.0),
            140.0 + float(i) * 60.0,
            Color(GRAU.r, GRAU.g, GRAU.b, 0.055 - float(i) * 0.018))

    # **Der Bodenstrich.** Er ist kein Lineal: ein Zug, der in der Mitte
    # traegt und zu beiden Seiten auslaeuft. Ein Strich von Rand zu Rand mit
    # gleicher Deckung waere das Einzige im Bild, das das tut.
    _tu.zug(Vector2(-40.0, BODEN_Y + 8.0), Vector2(b + 40.0, BODEN_Y - 6.0),
        7.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.55), 0.5, 0.0, 9.0, 11)
    _tu.wisch(Vector2(-40.0, BODEN_Y + 40.0), Vector2(b + 40.0, BODEN_Y + 30.0),
        70.0, Color(GRAU.r, GRAU.g, GRAU.b, 0.10))

    # **Ein paar Graeser**, nur am Boden und nur wenige. Sie sagen, dass der
    # Boden ein Ort ist und keine Kante.
    for i in 9:
        var x := rng.randf() * b
        var l := 26.0 + rng.randf() * 46.0
        var neige := (rng.randf() - 0.5) * 34.0
        _tu.zug(Vector2(x, BODEN_Y + 14.0), Vector2(x + neige, BODEN_Y - l),
            3.4, Color(TINTE.r, TINTE.g, TINTE.b, 0.30), 0.0, 0.7, 4.0, 4)

    # **Die Faser.** Sehr blass, sehr kurz, ueber das ganze Blatt - man sieht
    # sie nie einzeln und merkt sofort, wenn sie fehlt.
    for i in FASERN:
        var p := Vector2(rng.randf() * b, rng.randf() * h)
        var l := 14.0 + rng.randf() * 40.0
        var w := rng.randf() * PI
        var d := Vector2(cos(w), sin(w) * 0.25) * l
        _tu.zug(p - d * 0.5, p + d * 0.5, 2.2,
            Color(GRAU.r, GRAU.g, GRAU.b, 0.045 + rng.randf() * 0.035),
            0.5, 0.0, 0.0, 3)

    _tu.spuele(get_canvas_item())
