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

## Ein kurzer Sturz nach unten, wenn ein neuer Grabenabschnitt aufgeht.
##
## Der Spieler steht still, also kann man den Abstieg nur an dem zeigen, was
## an ihm vorbeizieht: der Schwebstoff schiesst nach oben weg. Zusammen mit
## dem Farbwechsel des Wassers ist das der ganze Moment - kein Schnitt, keine
## Tafel, nur zwei Sekunden, in denen es abwaerts geht.
var _sturz := 0.0

var _zeit := 0.0
var _schwaden: Array[Dictionary] = []
var _flocken: Array[Dictionary] = []

## Das Riff in den unteren Ecken. Siehe `_zeichne_riff()`.
var _riff: Array[Dictionary] = []

const RIFF_FARBEN: PackedColorArray = [
    Color(0.92, 0.46, 0.30),
    Color(0.86, 0.34, 0.52),
    Color(0.58, 0.40, 0.86),
    Color(0.36, 0.76, 0.68),
]


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x4e454b33

    # Das Riff: wenige, grosse Stoecke je Ecke. Viele kleine waeren wieder
    # Rauschen, und Rauschen ist genau das, was der Vordergrund nicht sein
    # darf - er liegt vor allem anderen.
    for seite: float in [-1.0, 1.0]:
        for i in 4:
            var arme := PackedFloat32Array()
            for _a in rng.randi_range(5, 8):
                arme.append(rng.randf_range(0.55, 1.0))
            _riff.append({
                &"seite": seite,
                &"rand": rng.randf_range(300.0, 372.0),
                &"gross": rng.randf_range(110.0, 230.0),
                &"arme": arme,
                &"farbe": RIFF_FARBEN[rng.randi() % RIFF_FARBEN.size()],
            })

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
    _sturz = maxf(0.0, _sturz - delta * 0.5)
    queue_redraw()


## Loest den Sturz aus. `wache.gd` ruft das, wenn ein Abschnitt aufgeht.
func abstieg() -> void:
    _sturz = 1.0


func _draw() -> void:
    if staerke <= 0.01:
        return
    _zeichne_schwaden()
    _zeichne_riff()
    _zeichne_flocken()


## Das Riff im Vordergrund.
##
## **Es rahmt, es spielt nicht mit.** Ein Bild braucht eine unterste Ebene,
## sonst schwebt alles darin gleich weit weg - und die untersten Ecken sind
## der einzige Platz, an dem etwas stehen darf, ohne dem Spieler die Sicht auf
## den Schlund zu nehmen. Deshalb: nur in den Ecken, nur nach innen wachsend,
## und **fast schwarz**. Was im Vordergrund steht, ist naeher an der Kamera
## als jede Lichtquelle; es ist eine Silhouette. Nur die Spitzen bekommen
## Farbe, und die ist gedaempft.
##
## Verankert wird es am unteren Bildrand und nicht an einem Weltpunkt: die
## Kamera richtet sich nach der Bildhoehe (siehe `wache.gd::UNTERKANTE`), und
## ein Riff, das an einer festen Welthoehe klebt, waere auf einem langen
## Telefon in der Bildmitte.
func _zeichne_riff() -> void:
    var sicht := get_viewport_rect().size
    var unten := get_global_transform_with_canvas().affine_inverse() \
        * Vector2(sicht.x * 0.5, sicht.y)
    for f in _riff:
        var seite: float = f[&"seite"]
        var fuss := Vector2(seite * float(f[&"rand"]), unten.y + 30.0)
        var r: float = f[&"gross"]
        var farbe: Color = f[&"farbe"]
        var arme: PackedFloat32Array = f[&"arme"]
        var n := arme.size()

        # Der Stamm - dunkel und breit, damit die Ecke Gewicht bekommt.
        var stamm := PackedVector2Array()
        for i in 9:
            var t := float(i) / 8.0
            var w := lerpf(-1.15, 1.15, t)
            stamm.append(fuss + Vector2(sin(w) * r * 0.55 * -seite,
                -cos(w) * r * 0.30 - r * 0.10))
        # **Die Umlaufrichtung muss stimmen.** Der Bogen laeuft von `-seite`
        # nach `+seite`; standen die beiden Bodenpunkte danach in derselben
        # Reihenfolge, schloss sich das Vieleck ueber Kreuz. Godot meldete das
        # jede einzelne Bildwiederholung mit "triangulation failed".
        stamm.append(fuss + Vector2(-seite * r * 0.7, 60.0))
        stamm.append(fuss + Vector2(seite * r * 0.7, 60.0))
        draw_colored_polygon(stamm, Color(0.014, 0.030, 0.042, 0.95))

        for i in n:
            var t := float(i) / float(maxi(1, n - 1))
            # Nach innen und nach oben, weg von der Ecke.
            var w := lerpf(0.15, 1.35, t) * -seite
            var laenge := r * arme[i]
            var linie := PackedVector2Array([fuss])
            var punkt := fuss
            var richtung := Vector2(sin(w), -cos(w))
            for g in 4:
                richtung = richtung.rotated(
                    sin(_zeit * 0.35 + float(i) * 1.3 + float(g)) * 0.06
                    + (0.16 * -seite))
                punkt += richtung * laenge * 0.25
                linie.append(punkt)
            draw_polyline(linie, Color(0.016, 0.036, 0.050, 0.95),
                5.5 - 0.5 * float(i % 3), true)
            # Nur die Spitze traegt Farbe, und leise.
            var spitze: Vector2 = linie[linie.size() - 1]
            draw_circle(spitze, 3.4, Color(farbe.r, farbe.g, farbe.b, 0.16))
            draw_circle(spitze, 1.5, Color(farbe.r, farbe.g, farbe.b, 0.30))


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
        _wolke(mitte, s[&"punkte"], SCHLICK, SCHWADEN_DECKUNG * staerke)


## Eine Wolke ohne Rand.
##
## **Drei gestapelte Vielecke sind keine Wolke, sondern drei Vielecke.** Genau
## das stand hier: eine Schlickflaeche in drei Groessen uebereinander, jede
## mit fester Deckung. Der Kommentar daneben behauptete, damit habe sie keinen
## Umriss - sie hatte drei. Im Bild waren es breite Sechsecke, die quer durch
## den offenen Graben zogen, mit sauber gezogener Kante und sichtbarem
## Deckungssprung an jeder Stufe. Sie waren das Groesste im Bild und das
## Einzige, was aussah wie ein Fehler.
##
## Ein Verlauf kann, was eine Stapelung nicht kann: in der Mitte voll und am
## Rand **genau null** sein. `draw_polygon` nimmt eine Farbe je Eckpunkt, also
## wird die Wolke als Faecher aus Dreiecken gezeichnet - Mitte gedeckt, Rand
## durchsichtig. Ein Dreieck je Ecke, neun Ecken, fuenf Wolken: fuenfundvierzig
## Dreiecke fuer eine Flaeche, die vorher aus fuenfzehn Vielecken mit harten
## Kanten bestand.
func _wolke(mitte: Vector2, punkte: PackedVector2Array, farbe: Color,
        deckung: float) -> void:
    if deckung <= 0.002 or punkte.size() < 3:
        return
    var voll := Color(farbe.r, farbe.g, farbe.b, deckung)
    var leer := Color(farbe.r, farbe.g, farbe.b, 0.0)
    var n := punkte.size()
    for i in n:
        var a: Vector2 = mitte + punkte[i]
        var b: Vector2 = mitte + punkte[(i + 1) % n]
        draw_polygon(PackedVector2Array([mitte, a, b]),
            PackedColorArray([voll, leer, leer]))


## Nahe Flocken. Gross und weich - sie sind ausserhalb der Schaerfe, und genau
## das macht sie zur vordersten Ebene.
func _zeichne_flocken() -> void:
    var hoehe := Graben.FELD.size.y + 200.0
    for f in _flocken:
        var y: float = Graben.FELD.position.y \
            + fmod(float(f[&"y"]) - Graben.FELD.position.y
                + _zeit * float(f[&"tempo"]) * (1.0 + 7.0 * _sturz), hoehe)
        var x: float = float(f[&"x"]) \
            + sin(_zeit * float(f[&"takt"])) * float(f[&"weite"])
        var p := Vector2(x, y)
        var r: float = float(f[&"r"])
        for ring in 3:
            var t := float(ring + 1) / 3.0
            draw_circle(p, r * (0.5 + 1.5 * t), Color(FLOCKE.r, FLOCKE.g, FLOCKE.b,
                FLOCKEN_DECKUNG * staerke * (1.0 - t) * 0.5))

        # Waehrend des Sturzes zieht jede Flocke einen Strich hinter sich her -
        # dieselbe Flocke, nur so schnell, dass ein Bild sie nicht mehr als
        # Punkt zeigt.
        if _sturz > 0.02:
            draw_line(p, p + Vector2(0.0, float(f[&"tempo"]) * _sturz * 0.9),
                Color(FLOCKE.r, FLOCKE.g, FLOCKE.b,
                    FLOCKEN_DECKUNG * staerke * _sturz * 0.6), r * 0.7)
