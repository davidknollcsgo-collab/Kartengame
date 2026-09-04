extends Node2D

## Die Schwaerme, die nicht angreifen.
##
## **Vorher war jedes bewegte Ding auf dem Bild ein Feind.** Eine Karte, auf
## der alles Lebende auf einen zuhaelt, ist keine Welt, sondern ein Schiessstand
## mit Hintergrund. Diese Schwaerme wollen nichts vom Boot - sie ziehen ueber
## den Grund, und wenn man ihnen zu nahe kommt, stieben sie auseinander.
##
## Sie stehen **ausserhalb der Wirtschaft**: in keiner `Wellen.auftritte()`,
## kein Naehrstoff, keine Punkte, kein Schaden in beide Richtungen. Genau wie
## die Funkenbluete (Zusage 18) - was nichts kostet und nichts zahlt,
## verschiebt auch nichts.
##
## Gezeichnet **ueber dem Nebel**, nicht darunter: sie leuchten, und ein
## Glimmen weit draussen im Dunkeln ist der beste Grund, dorthin zu fahren.
## Deshalb haengen sie als eigener Knoten hinter dem Grund in der Szene und
## nicht in ihm.

const SAAT := 0x57494c44

## Wieviele Schwaerme, und wie gross. Lieber wenige grosse als viele kleine:
## ein Schwarm aus vier Fischen ist kein Schwarm, sondern vier Fische.
const SCHWAERME := 14
const JE_SCHWARM := 18

## Wie weit ein Fisch um die Mitte seines Schwarms streut - laengs mehr als
## quer. Ein runder Fleck aus Fischen ist ein Fleck; ein Zug, der laenger ist
## als er breit, ist ein Schwarm.
const STREUUNG := 118.0
const STREUUNG_QUER := 0.44

## Farben. Kuehl und blass - die Raeuber tragen die kraeftigen Farben, und
## wer die beiden verwechselt, faehrt in ein Maul statt an einem Fisch vorbei.
const FARBEN: PackedColorArray = [
    Color(0.52, 0.86, 0.92),
    Color(0.46, 0.72, 0.90),
    Color(0.58, 0.90, 0.80),
]

## Wird von `rundlauf.gd` gesetzt: wo das Boot steht.
var boot := Vector2.ZERO

var zeit := 0.0

var _schwaerme: Array[Dictionary] = []


func _ready() -> void:
    baue(0)


## Die Schwaerme neu setzen - **zur selben Saat wie der Grund.**
##
## Ohne das stuenden nach dem Umbau des Grundes dieselben vierzehn Schwaerme
## an denselben Stellen in einem anderen Riff: die Steine wandern, die Fische
## bleiben. Eine Strecke Graben ist beides zusammen oder keins von beidem.
func baue(welle: int) -> void:
    _schwaerme.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + welle
    for i in SCHWAERME:
        var mitte := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) \
            * sqrt(rng.randf()) * (Rundum.FELD_RADIUS - 160.0)
        var glieder: Array[Dictionary] = []
        for j in JE_SCHWARM:
            glieder.append({
                # Ein fester Platz im Schwarm, nicht jedes Bild neu gewuerfelt:
                # so behaelt der Schwarm seine Form, waehrend er zieht.
                &"platz": Vector2(rng.randf_range(-1.0, 1.0),
                    rng.randf_range(-1.0, 1.0) * STREUUNG_QUER) * STREUUNG,
                &"takt": rng.randf_range(1.6, 3.2),
                &"phase": rng.randf_range(0.0, TAU),
                &"gross": rng.randf_range(5.5, 9.0),
                &"ort": mitte,
                &"richtung": Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)),
            })
        _schwaerme.append({
            &"mitte": mitte,
            &"glieder": glieder,
            # Die ruhige Bahn: ein Kreis um einen eigenen Mittelpunkt. Eine
            # Gerade waere nach zwanzig Sekunden am Rand, ein Zufallsgang
            # zittert - ein Kreis zieht.
            &"achse": mitte + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
                * rng.randf_range(180.0, 420.0),
            &"kreis": rng.randf_range(0.06, 0.15) * (1.0 if rng.randf() < 0.5
                else -1.0),
            &"lage": rng.randf_range(0.0, TAU),
            &"farbe": FARBEN[rng.randi() % FARBEN.size()],
            # Wohin der Zug gerade zieht. Daraus bekommt **jeder** Fisch
            # seine Blickrichtung.
            &"blick": Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)),
        })


func _process(delta: float) -> void:
    zeit += delta
    for s in _schwaerme:
        s[&"lage"] = float(s[&"lage"]) + float(s[&"kreis"]) * delta
        var achse: Vector2 = s[&"achse"]
        var ziel := achse + Vector2.RIGHT.rotated(float(s[&"lage"])) \
            * achse.distance_to(Vector2(s[&"mitte"]))
        var vorher: Vector2 = s[&"mitte"]
        var mitte: Vector2 = Rundum.schwarmschritt(vorher, ziel, boot, delta)
        s[&"mitte"] = mitte
        var weg := mitte - vorher
        if weg.length_squared() > 0.0004:
            s[&"blick"] = Vector2(s[&"blick"]).lerp(weg.normalized(),
                clampf(3.0 * delta, 0.0, 1.0)).normalized()
    _fuehre_glieder(delta)
    queue_redraw()


## Jeder Fisch zieht seinem Platz im Schwarm nach - traege, damit er beim
## Wenden hinterherhaengt, und im Schreck weiter aussen, damit der Schwarm
## auseinanderstiebt statt als Klumpen wegzurutschen.
##
## **Der Platz liegt laengs zur Zugrichtung, und alle blicken dorthin, wohin
## der Zug zieht.** Beides stand hier zuerst anders: die Plaetze lagen fest
## im Weltraster und jeder Fisch schaute dorthin, wo sein eigener Platz lag.
## Im Bild war das kein Schwarm, sondern ein Seeigel - achtzehn Fische, die
## strahlenfoermig nach aussen zeigen. Ein Schwarm ist genau das, was er von
## weitem ist: viele, die in dieselbe Richtung sehen.
func _fuehre_glieder(delta: float) -> void:
    for i in _schwaerme.size():
        var s := _schwaerme[i]
        var mitte: Vector2 = s[&"mitte"]
        var blick: Vector2 = s[&"blick"]
        var quer := blick.orthogonal()
        var schreck: float = Rundum.schreck(mitte, boot)
        for g in _glieder(i):
            var platz: Vector2 = g[&"platz"]
            # Im Schreck laufen die Plaetze auseinander - und quer mehr als
            # laengs, weil ein Schwarm zur Seite ausbricht und nicht in die
            # Laenge zieht.
            var soll := mitte + blick * platz.x * (1.0 + schreck * 0.8) \
                + quer * platz.y * (1.0 + schreck * 3.4)
            g[&"ort"] = Vector2(g[&"ort"]).lerp(soll,
                clampf((2.2 + schreck * 4.0) * delta, 0.0, 1.0))
            # Die Blickrichtung kommt vom Zug, nicht vom eigenen Weg. Ein
            # kleiner Versatz je Fisch, sonst stehen sie wie gedruckt.
            var eigen := blick.rotated(sin(zeit * float(g[&"takt"]) * 0.5
                + float(g[&"phase"])) * 0.18)
            g[&"richtung"] = Vector2(g[&"richtung"]).lerp(eigen,
                clampf(4.0 * delta, 0.0, 1.0)).normalized()


func _glieder(i: int) -> Array:
    return _schwaerme[i][&"glieder"]


func _draw() -> void:
    var kamera := get_parent().get_node_or_null("Kamera") as Camera2D
    var blick := kamera.position if kamera != null else Vector2.ZERO
    for i in _schwaerme.size():
        var s := _schwaerme[i]
        if Vector2(s[&"mitte"]).distance_squared_to(blick) \
                > pow(Rundum.SICHT + 200.0, 2):
            continue
        var farbe: Color = s[&"farbe"]
        var schreck: float = Rundum.schreck(s[&"mitte"], boot)
        for g in _glieder(i):
            _fisch(g, farbe, schreck)


## Ein Fisch: zwei Striche und ein Punkt.
##
## Mehr braucht es nicht - er ist sechs Pixel gross, und jede weitere Linie
## waere ein Fleck. Der Schwanz schlaegt, und er schlaegt schneller, wenn der
## Schwarm erschrocken ist: das ist die ganze Erzaehlung.
func _fisch(g: Dictionary, farbe: Color, schreck: float) -> void:
    var p: Vector2 = g[&"ort"]
    var r: Vector2 = g[&"richtung"]
    var q := r.orthogonal()
    var gr: float = g[&"gross"]
    var schlag := sin(zeit * float(g[&"takt"]) * (1.0 + schreck * 2.4)
        + float(g[&"phase"])) * (0.4 + 0.4 * schreck)
    var a := 0.34 + 0.30 * schreck
    var nase := p + r * gr
    var heck := p - r * gr * 0.9
    draw_line(nase, heck, Color(farbe.r, farbe.g, farbe.b, a), 1.4, true)
    # Die Schwanzflosse: ein Strich quer am Heck, der mitschlaegt.
    var flosse := heck - r * gr * 0.5
    draw_line(heck, flosse + q * gr * schlag,
        Color(farbe.r, farbe.g, farbe.b, a * 0.8), 1.2, true)
    draw_circle(nase - r * gr * 0.25, 1.2,
        Color(farbe.r, farbe.g, farbe.b, a * 1.5))
