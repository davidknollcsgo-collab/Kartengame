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
const ERDE := Palette.ERDE

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

    # **Flecken zuerst**: Erde und Grasgrund als grosse, sehr blasse Flaechen.
    # Sie sind Flaeche und kein Ding - der Grundsatz oben (die Zahl der
    # getrennten Dinge macht einen Hintergrund laut) bleibt unberuehrt. Ohne
    # sie las sich der Grund als Papier und nicht als Feld.
    # Zwei sich kreuzende Wische je Fleck: einer allein war eine Linse mit
    # spitzen Enden und sichtbaren Facetten, zwei ergeben einen Fleck.
    for i in 2:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var farbe := Palette.ERDE if rng.randf() < 0.5 else Palette.GRASGRUND
        var deck := 0.16 + rng.randf() * 0.10
        var w := rng.randf() * PI
        for k in 2:
            var wk := w + float(k) * 1.2
            var l := (120.0 + rng.randf() * 140.0) * (1.0 - 0.3 * float(k))
            var d := Vector2(cos(wk), sin(wk) * 0.5) * l
            _tu.zug(p - d * 0.5, p + d * 0.5, 80.0 + rng.randf() * 50.0,
                Color(farbe.r, farbe.g, farbe.b, deck),
                0.5, 0.0, (rng.randf() - 0.5) * 40.0, 11)

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

    _pfade(gx, gy, ecke)

    # **Kiesel**: klein, blass, verstreut. Einzeln sieht man sie kaum; ohne
    # sie ist zwischen den Dingen nichts, und der Grund ist ein Tischtuch.
    for i in 7:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var c := STEIN.darkened(0.15 + rng.randf() * 0.2)
        _tu.klecks(p, 1.6 + rng.randf() * 2.2, Color(c.r, c.g, c.b, 0.55), i)

    for i in DINGE:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var los := rng.randf()
        if los < 0.50:
            _gras(p, rng)
        elif los < 0.80:
            _steine(p, rng)
        elif los < 0.93:
            _busch(p, rng)
        else:
            _stumpf(p, rng)


## **Ausgetretene Pfade ueber viele Kacheln.** Ein Pfad haengt an einer
## Gitterlinie und nicht an einer Kachel: seine Lage ist eine Funktion von
## `x` (bzw. `y`) allein, also setzt er sich ueber jede Kachelgrenze fort.
## Ob es ihn gibt, sagt die Saat der Linie - nicht jede hat einen.
const PFAD_ABSTAND := 3
const PFAD_STUECKE := 7

## **Stoss an Stoss, ohne Ueberlappung.** Der erste Anlauf liess jedes
## Stueck dreissig Punkte in die Nachbarkachel ragen; der Pfad ist
## halbdurchsichtig, und an jeder Kachelgrenze stand ein dunkler Querstreifen.
func _pfade(gx: int, gy: int, ecke: Vector2) -> void:
    # Waagerecht: Linie `ly`, laeuft durch Kacheln mit gy == ly * ABSTAND.
    if posmod(gy, PFAD_ABSTAND) == 0 and _pfad_da(gy, 1):
        var y0 := ecke.y + KACHEL * 0.5
        var bahn := PackedVector2Array()
        for i in PFAD_STUECKE + 1:
            var x := ecke.x + KACHEL * float(i) / float(PFAD_STUECKE)
            bahn.append(Vector2(x, y0 + _welle(x, gy)))
        _pfad(bahn)
    if posmod(gx, PFAD_ABSTAND) == 0 and _pfad_da(gx, 2):
        var x0 := ecke.x + KACHEL * 0.5
        var bahn := PackedVector2Array()
        for i in PFAD_STUECKE + 1:
            var y := ecke.y + KACHEL * float(i) / float(PFAD_STUECKE)
            bahn.append(Vector2(x0 + _welle(y, gx), y))
        _pfad(bahn)


func _pfad_da(linie: int, achse: int) -> bool:
    return (hash(Vector2i(linie, achse * 7919)) & 0xff) < 150


func _welle(t: float, linie: int) -> float:
    var p := float(linie) * 1.7
    return sin(t * 0.0041 + p) * 70.0 + sin(t * 0.0113 + p * 2.3) * 22.0


func _pfad(bahn: PackedVector2Array) -> void:
    var halb := PackedFloat32Array()
    for p in bahn:
        halb.append(26.0 + 8.0 * sin(p.x * 0.013 + p.y * 0.017))
    _tu.band(bahn, halb, Color(ERDE.r, ERDE.g, ERDE.b, 0.34), PackedFloat32Array())
    # Zwei Spuren darin, dunkler: dort wird gegangen.
    for s in [-1.0, 1.0]:
        var spur := PackedVector2Array()
        var schmal := PackedFloat32Array()
        for i in bahn.size():
            var vor := bahn[mini(i + 1, bahn.size() - 1)] - bahn[maxi(i - 1, 0)]
            spur.append(bahn[i] + vor.normalized().orthogonal() * 9.0 * s)
            schmal.append(3.5)
        var d := ERDE.darkened(0.12)
        _tu.band(spur, schmal, Color(d.r, d.g, d.b, 0.30), PackedFloat32Array())


## **Ein Bueschel, nicht drei Haare.** Halme in zwei Toenen - die hinteren
## dunkler, die vorderen heller -, dichter und gefaechert, und selten eine
## Bluete. Vorher waren es drei graue Striche nebeneinander.
func _gras(p: Vector2, rng: RandomNumberGenerator) -> void:
    var halme := 5 + rng.randi_range(0, 3)
    for i in halme:
        var t := float(i) / float(halme - 1) - 0.5
        var l := 14.0 + rng.randf() * 22.0
        var neige := t * 26.0 + (rng.randf() - 0.5) * 8.0
        var vorn := i % 2 == 1
        var c := Palette.HALM.lightened(0.25) if vorn else Palette.HALM
        _tu.zug(p + Vector2(t * 12.0, 0.0), p + Vector2(t * 12.0 + neige, -l),
            2.8, Color(c.r, c.g, c.b, 0.55), 0.0, 0.6, 2.0, 3)
    if rng.randf() < 0.3:
        _tu.klecks(p + Vector2((rng.randf() - 0.5) * 14.0, -18.0 - rng.randf() * 10.0),
            2.6, Color(Palette.BLUETE.r, Palette.BLUETE.g, Palette.BLUETE.b, 0.9),
            int(p.x))


## Grundtoene fuer die Dinge am Boden. Keine Sortenfarbe, kein Gold, kein
## Zinnober - und alles mit **halber Kante**: eine volle waere eine Figur.
const STEIN := Color(0.62, 0.60, 0.55)
const LAUB := Color(0.40, 0.46, 0.31)
const RINDE := Color(0.46, 0.37, 0.27)
const KANTE := Color(0.129, 0.114, 0.149, 0.42)


## **Steine liegen in Gruppen.** Einer allein war ein Fleck mit Schraffur -
## aus dem Holzschnitt uebrig, und im farbigen Bild ein Loch im Boden. Jetzt
## zwei bis vier, der groesste hinten, mit Licht und halber Kante.
func _steine(p: Vector2, rng: RandomNumberGenerator) -> void:
    var zahl := 2 + rng.randi_range(0, 2)
    for i in zahl:
        var r := (12.0 - float(i) * 3.0) * (0.7 + rng.randf() * 0.6)
        var o := p + Vector2((rng.randf() - 0.5) * 34.0, float(i) * 5.0)
        var c := STEIN.darkened(rng.randf() * 0.12)
        _tu.klecks(o + Vector2(2.0, r * 0.35), r * 1.05,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.12), i)
        _tu.klecks(o, r, c, int(o.x) + i, KANTE)
        _tu.klecks(o + Vector2(-r * 0.3, -r * 0.35), r * 0.35,
            Color(1.0, 1.0, 1.0, 0.22), i)


## Ein niedriger Busch: Bauschen aus Laub, die hinteren dunkler.
func _busch(p: Vector2, rng: RandomNumberGenerator) -> void:
    _tu.klecks(p + Vector2(0.0, 8.0), 24.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.10), 1)
    for i in 5:
        var w := PI + float(i) / 4.0 * PI
        var o := p + Vector2(cos(w) * 16.0, sin(w) * 9.0 + 2.0)
        var c := LAUB.darkened(0.18) if i % 2 == 0 else LAUB
        _tu.klecks(o, 10.0 + rng.randf() * 4.0, c, i, KANTE)
    _tu.klecks(p + Vector2(0.0, -6.0), 13.0, LAUB.lightened(0.12), 7, KANTE)


## Ein Baumstumpf: Rinde, oben die helle Schnittflaeche mit einem Ring.
func _stumpf(p: Vector2, rng: RandomNumberGenerator) -> void:
    var r := 13.0 + rng.randf() * 5.0
    _tu.klecks(p + Vector2(3.0, 10.0), r * 1.2, Color(TINTE.r, TINTE.g, TINTE.b, 0.12), 1)
    _tu.strang(PackedVector2Array([p + Vector2(0.0, 10.0), p]),
        PackedFloat32Array([r * 2.2, r * 2.0]), RINDE, 2, KANTE)
    var schnitt := RINDE.lightened(0.45)
    _tu.klecks(p, r, schnitt, 2, KANTE)
    _tu.kranz(p, r * 0.45, r * 0.55, RINDE.lightened(0.15), 3)
