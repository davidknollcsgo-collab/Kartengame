extends Node2D

## **Der Boden als Landkarte.**
##
## Sand als Grund, darauf zusammenhaengende Wiesen, Wege, selten ein Teich oder
## ein Bach, und darauf Baeume, Buesche, Steine, Ruinen, Zaeune. So stand es
## in der Vorlage des Nutzers (Oktober 2026). Vorher war der Grund ein
## blasses Papier mit Flecken - ein Rest des Holzschnitts.
##
## **Was einen Hintergrund laut macht, ist die Zahl der getrennten Dinge
## darin.** Die Wiesen sind Flaeche und kein Ding; Dinge stehen hoechstens
## `DINGE` je Kachel, und die grossen (Baum, Ruine, Teich) selten.
##
## Gezeichnet im Pixelpuffer des Bodens (`gefecht.tscn`), mit demselben
## Pinsel wie die Figuren: Kante ein Bildpunkt. Gekachelt um die Mitte; der
## Inhalt einer Kachel haengt allein an ihren Gitterkoordinaten - dieselbe
## Kachel sieht immer gleich aus, egal von welcher Seite man sie betritt.

const PERGAMENT := Palette.BODEN
const TINTE := Palette.UMRISS
const SEPIA := Palette.GRUND_ZIER
const ERDE := Palette.ERDE

const KACHEL := 420.0
## Wieviele Dinge auf einer Kachel stehen. Sehr wenige: siehe oben.
const DINGE := 3

## Halbe Kante fuer Dinge am Boden: eine volle waere eine Figur.
const KANTE := Color(0.129, 0.114, 0.149, 0.55)

var _tu := Tusche.new()
var _mitte := Vector2.ZERO


func _ready() -> void:
    # Derselbe Pinsel wie im Figurenpuffer: Kante ein Bildpunkt.
    var punkt := 3.0 / 0.8
    _tu.kante_fest = punkt * 0.95
    _tu.mindest = punkt * 0.5


func setze_mitte(ort: Vector2) -> void:
    # Erst neu zeichnen, wenn man eine halbe Kachel weiter ist. Jedes Bild
    # neu waere derselbe Grund fuer denselben Preis.
    if ort.distance_squared_to(_mitte) < (KACHEL * 0.4) * (KACHEL * 0.4):
        return
    _mitte = ort
    queue_redraw()


func _draw() -> void:
    # Halbe Bildhoehe im Feld (bis 1000 bei 20:9 und Zoom 0,8) plus der Weg,
    # den man geht, bevor neu gezeichnet wird.
    var sicht := 1400.0
    var von := ((_mitte - Vector2.ONE * sicht) / KACHEL).floor()
    var bis := ((_mitte + Vector2.ONE * sicht) / KACHEL).ceil()
    # **In Schichten, ueber alle Kacheln.** Erst alle Wiesenraender, dann alle
    # Wiesen, dann Wege und Wasser, dann die Dinge. Je Kachel alles auf
    # einmal liess den Rand der naechsten Wiese ueber die vorige laufen.
    for schicht in 4:
        for gx in range(int(von.x), int(bis.x) + 1):
            for gy in range(int(von.y), int(bis.y) + 1):
                _kachel(gx, gy, schicht)
    _tu.spuele(get_canvas_item())


func _saat(gx: int, gy: int, schicht: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(Vector3i(gx, gy, schicht)) & 0x7fffffff
    return rng


## Ein Zufallswert je Gitterplatz, zwischen 0 und 1.
func _wert(gx: int, gy: int) -> float:
    return float(hash(Vector2i(gx * 31, gy * 17 + 5)) & 0xffff) / 65535.0


## **Wie viel Wiese hier steht**: der Mittelwert der Nachbarschaft. Ein Wert
## je Kachel allein gab ein Schachbrett aus Wiese und Sand; gemittelt ueber
## drei mal drei bilden sich zusammenhaengende Flaechen.
func _wiese(gx: int, gy: int) -> float:
    var summe := 0.0
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            summe += _wert(gx + dx, gy + dy)
    return clampf((summe / 9.0 - 0.47) * 3.0, 0.0, 1.0)


## Wieviel Wiese an einem Ort steht (grob, ueber seine Kachel).
func _wiese_an(p: Vector2) -> float:
    var g := (p / KACHEL).floor()
    return _wiese(int(g.x), int(g.y))


func _kachel(gx: int, gy: int, schicht: int) -> void:
    var ecke := Vector2(float(gx), float(gy)) * KACHEL
    var anteil := _wiese(gx, gy)
    match schicht:
        0, 1:
            _wiesen(gx, gy, ecke, anteil, schicht == 0)
        2:
            _pfade(gx, gy, ecke)
            _wasser(gx, gy, ecke)
        3:
            _dinge(gx, gy, ecke, anteil)


## Die Wiese einer Kachel: grosse Kleckse, erst ihr dunkler Rand
## (`rand` = Schicht 0), dann die Flaeche darueber.
func _wiesen(gx: int, gy: int, ecke: Vector2, anteil: float, rand: bool) -> void:
    var zahl := int(round(anteil * 5.0))
    if zahl == 0:
        return
    var rng := _saat(gx, gy, 0)
    for i in zahl:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var r := 110.0 + rng.randf() * 90.0
        if rand:
            _tu.klecks(p, r + 7.0, Palette.WIESE_TIEF, i)
        else:
            _tu.klecks(p, r, Palette.WIESE, i)
            # Ein hellerer Schimmer auf der Lichtseite.
            _tu.klecks(p + Vector2(-r * 0.25, -r * 0.3), r * 0.45,
                Palette.WIESE.lightened(0.06), i + 3)


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
    if posmod(gy, PFAD_ABSTAND) == 0 and _linie_da(gy, 1, 150):
        _pfad(_bahn_waagerecht(gy, ecke))
    if posmod(gx, PFAD_ABSTAND) == 0 and _linie_da(gx, 2, 150):
        _pfad(_bahn_senkrecht(gx, ecke))


func _bahn_waagerecht(linie: int, ecke: Vector2) -> PackedVector2Array:
    var y0 := ecke.y + KACHEL * 0.5
    var bahn := PackedVector2Array()
    for i in PFAD_STUECKE + 1:
        var x := ecke.x + KACHEL * float(i) / float(PFAD_STUECKE)
        bahn.append(Vector2(x, y0 + _welle(x, linie)))
    return bahn


func _bahn_senkrecht(linie: int, ecke: Vector2) -> PackedVector2Array:
    var x0 := ecke.x + KACHEL * 0.5
    var bahn := PackedVector2Array()
    for i in PFAD_STUECKE + 1:
        var y := ecke.y + KACHEL * float(i) / float(PFAD_STUECKE)
        bahn.append(Vector2(x0 + _welle(y, linie), y))
    return bahn


func _linie_da(linie: int, achse: int, von_256: int) -> bool:
    return (hash(Vector2i(linie, achse * 7919)) & 0xff) < von_256


func _welle(t: float, linie: int) -> float:
    var p := float(linie) * 1.7
    return sin(t * 0.0041 + p) * 70.0 + sin(t * 0.0113 + p * 2.3) * 22.0


func _pfad(bahn: PackedVector2Array) -> void:
    var halb := PackedFloat32Array()
    for p in bahn:
        halb.append(24.0 + 6.0 * sin(p.x * 0.013 + p.y * 0.017))
    _tu.band(bahn, halb, ERDE, PackedFloat32Array())
    # Zwei Spuren darin, dunkler: dort wird gegangen und gefahren.
    for s in [-1.0, 1.0]:
        var spur := PackedVector2Array()
        var schmal := PackedFloat32Array()
        for i in bahn.size():
            var vor := bahn[mini(i + 1, bahn.size() - 1)] - bahn[maxi(i - 1, 0)]
            spur.append(bahn[i] + vor.normalized().orthogonal() * 10.0 * s)
            schmal.append(2.6)
        _tu.band(spur, schmal, ERDE.darkened(0.12), PackedFloat32Array())


## **Wasser, selten.** Ein Bach an einer Gitterlinie quer zu den Wegen (eine
## von acht Linien), und gelegentlich ein Teich. Dekoration ohne Kollision:
## man watet hindurch, wie man durch die Wiese geht.
func _wasser(gx: int, gy: int, ecke: Vector2) -> void:
    if posmod(gx + 1, PFAD_ABSTAND * 2) == 0 and _linie_da(gx, 5, 40):
        var bahn := _bahn_senkrecht(gx * 3 + 1, ecke)
        var rand := PackedFloat32Array()
        var halb := PackedFloat32Array()
        var glanz := PackedFloat32Array()
        for p in bahn:
            var b := 20.0 + 6.0 * sin(p.y * 0.011 + float(gx))
            rand.append(b + 5.0)
            halb.append(b)
            glanz.append(b * 0.25)
        _tu.band(bahn, rand, Palette.WIESE_TIEF.darkened(0.15), PackedFloat32Array())
        _tu.band(bahn, halb, Palette.WASSER, PackedFloat32Array())
        _tu.band(bahn, glanz, Palette.WASSER_HELL, PackedFloat32Array())
    var rng := _saat(gx, gy, 2)
    if rng.randf() < 0.05:
        var p := ecke + Vector2(0.3 + rng.randf() * 0.4, 0.3 + rng.randf() * 0.4) * KACHEL
        var r := 50.0 + rng.randf() * 30.0
        _tu.klecks(p, r + 6.0, Palette.WIESE_TIEF.darkened(0.15), 1)
        _tu.klecks(p, r, Palette.WASSER, 2)
        _tu.klecks(p + Vector2(-r * 0.3, -r * 0.25), r * 0.35, Palette.WASSER_HELL, 3)
        # Schilf am Ufer.
        for i in 3:
            var w := PI * (0.7 + float(i) * 0.25)
            var u := p + Vector2(cos(w), sin(w) * 0.8) * r
            _gras(u, rng)


func _dinge(gx: int, gy: int, ecke: Vector2, anteil: float) -> void:
    var rng := _saat(gx, gy, 3)
    # **Die Wiese hat Struktur.** Als glatte Flaeche war sie ein gruener
    # Fleck auf einer Karte; kurze dunkle Haken lesen sich als Gras.
    for i in int(anteil * 22.0):
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        if _wiese_an(p) < 0.5:
            continue
        var c := Palette.HALM if i % 3 else Palette.WIESE.lightened(0.14)
        _tu.zug(p, p + Vector2(-5.0, -15.0), 5.0, c, 0.0, 0.0, 0.0, 2)
        _tu.zug(p + Vector2(7.0, 0.0), p + Vector2(12.0, -13.0), 5.0, c, 0.0, 0.0, 0.0, 2)
    # Kiesel: klein, verstreut. Einzeln sieht man sie kaum; ohne sie ist
    # zwischen den Dingen nichts, und der Grund ist ein Tischtuch.
    for i in 6:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        _tu.klecks(p, 2.4 + rng.randf() * 2.0, SEPIA.darkened(rng.randf() * 0.15), i)
    for i in DINGE:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var los := rng.randf()
        # Auf der Wiese stehen Baeume und Gras, im Sand Steine und Ruinen.
        if los < 0.18 + anteil * 0.30:
            _baum(p, rng)
        elif los < 0.50 + anteil * 0.15:
            _gras(p, rng)
        elif los < 0.70:
            _busch(p, rng)
        elif los < 0.85:
            _steine(p, rng)
        elif los < 0.90:
            _zaun(p, rng)
        elif los < 0.96:
            _ruine(p, rng)
        else:
            _stumpf(p, rng)


## **Ein Baum: Schatten, Stamm, Krone.** Die Krone aus mehreren Klecksen,
## die hinteren dunkler, oben ein Licht; der Schatten faellt nach rechts
## unten, vom Licht weg (`Palette.LICHT`).
func _baum(p: Vector2, rng: RandomNumberGenerator) -> void:
    var r := 44.0 + rng.randf() * 22.0
    _tu.klecks(p + Vector2(r * 0.55, r * 0.15), r * 1.05,
        Color(TINTE.r, TINTE.g, TINTE.b, 0.20), 1)
    _tu.strang(PackedVector2Array([p + Vector2(0.0, 4.0), p + Vector2(0.0, -r * 0.7)]),
        PackedFloat32Array([r * 0.36, r * 0.28]), Palette.HOLZ, 2, KANTE)
    var mitte := p + Vector2(0.0, -r * 1.05)
    for i in 4:
        var w := PI * (0.15 + float(i) * 0.47)
        var o := mitte + Vector2(cos(w) * r * 0.45, sin(w) * r * 0.30 + r * 0.10)
        _tu.klecks(o, r * 0.62, Palette.LAUB_TIEF, i, KANTE)
    _tu.klecks(mitte + Vector2(-r * 0.05, -r * 0.12), r * 0.70, Palette.LAUB, 7, KANTE)
    _tu.klecks(mitte + Vector2(-r * 0.25, -r * 0.32), r * 0.30,
        Palette.LAUB.lightened(0.18), 8)


## **Ein Bueschel, nicht drei Haare.** Halme in zwei Toenen, gefaechert, und
## selten eine Bluete.
func _gras(p: Vector2, rng: RandomNumberGenerator) -> void:
    var halme := 5 + rng.randi_range(0, 3)
    for i in halme:
        var t := float(i) / float(halme - 1) - 0.5
        var l := 14.0 + rng.randf() * 18.0
        var neige := t * 26.0 + (rng.randf() - 0.5) * 8.0
        var c := Palette.HALM.lightened(0.20) if i % 2 == 1 else Palette.HALM
        _tu.zug(p + Vector2(t * 12.0, 0.0), p + Vector2(t * 12.0 + neige, -l),
            3.4, c, 0.0, 0.0, 2.0, 3)
    if rng.randf() < 0.3:
        _tu.klecks(p + Vector2((rng.randf() - 0.5) * 14.0, -16.0 - rng.randf() * 8.0),
            3.6, Palette.BLUETE, int(p.x))


## Steine liegen in Gruppen, der groesste hinten, mit Licht und halber Kante.
func _steine(p: Vector2, rng: RandomNumberGenerator) -> void:
    var zahl := 2 + rng.randi_range(0, 2)
    for i in zahl:
        var r := (13.0 - float(i) * 3.0) * (0.7 + rng.randf() * 0.6)
        var o := p + Vector2((rng.randf() - 0.5) * 34.0, float(i) * 5.0)
        _tu.klecks(o + Vector2(r * 0.4, r * 0.35), r * 1.0,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.16), i)
        _tu.klecks(o, r, Palette.STEIN.darkened(rng.randf() * 0.12), int(o.x) + i, KANTE)
        _tu.klecks(o + Vector2(-r * 0.3, -r * 0.35), r * 0.38,
            Palette.STEIN.lightened(0.25), i)


## Ein niedriger Busch: Bauschen aus Laub, die hinteren dunkler.
func _busch(p: Vector2, rng: RandomNumberGenerator) -> void:
    _tu.klecks(p + Vector2(10.0, 8.0), 24.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.16), 1)
    for i in 4:
        var w := PI + float(i) / 3.0 * PI
        var o := p + Vector2(cos(w) * 15.0, sin(w) * 8.0 + 2.0)
        _tu.klecks(o, 11.0 + rng.randf() * 4.0, Palette.LAUB_TIEF, i, KANTE)
    _tu.klecks(p + Vector2(0.0, -6.0), 13.0, Palette.LAUB, 7, KANTE)
    if rng.randf() < 0.3:
        _tu.klecks(p + Vector2(4.0, -10.0), 3.0, Palette.BLUETE, 8)


## Ein Baumstumpf: Rinde, oben die helle Schnittflaeche mit einem Ring.
func _stumpf(p: Vector2, rng: RandomNumberGenerator) -> void:
    var r := 13.0 + rng.randf() * 5.0
    _tu.klecks(p + Vector2(8.0, 10.0), r * 1.2, Color(TINTE.r, TINTE.g, TINTE.b, 0.16), 1)
    _tu.strang(PackedVector2Array([p + Vector2(0.0, 10.0), p]),
        PackedFloat32Array([r * 2.2, r * 2.0]), Palette.HOLZ, 2, KANTE)
    _tu.klecks(p, r, Palette.HOLZ.lightened(0.45), 2, KANTE)
    _tu.kranz(p, r * 0.45, r * 0.60, Palette.HOLZ.lightened(0.15), 3)


## Ein Zaunstueck: Pfosten und zwei Latten, schraeg im Feld.
func _zaun(p: Vector2, rng: RandomNumberGenerator) -> void:
    var r := Vector2(1.0, (rng.randf() - 0.5) * 0.5).normalized()
    var pfosten := 3 + rng.randi_range(0, 2)
    var weit := 34.0
    for k in 2:
        var y := -10.0 - float(k) * 12.0
        _tu.strang(PackedVector2Array([p + Vector2(0.0, y),
            p + r * weit * float(pfosten - 1) + Vector2(0.0, y)]),
            PackedFloat32Array([5.0, 5.0]), Palette.HOLZ.lightened(0.12), 2, KANTE)
    for i in pfosten:
        var f := p + r * weit * float(i)
        _tu.strang(PackedVector2Array([f, f + Vector2(0.0, -30.0)]),
            PackedFloat32Array([7.5, 6.5]), Palette.HOLZ, 2, KANTE)


## **Eine Ruine**: ein Mauerstueck mit Zinnen, eingebrochen, oder ein
## Turmstumpf. Selten - sie ist das groesste Ding am Boden.
func _ruine(p: Vector2, rng: RandomNumberGenerator) -> void:
    var stein := Palette.STEIN
    _tu.klecks(p + Vector2(30.0, 10.0), 50.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.16), 1)
    if rng.randf() < 0.5:
        # Mauer: eine Reihe Bloecke, nach rechts abfallend.
        for i in 5:
            var hoch := 46.0 - float(i) * 7.0 - rng.randf() * 6.0
            var x := -60.0 + float(i) * 28.0
            _tu.strang(PackedVector2Array([p + Vector2(x, 0.0), p + Vector2(x, -hoch)]),
                PackedFloat32Array([28.0, 28.0]), stein.darkened(rng.randf() * 0.1), 2, KANTE)
            if i % 2 == 0 and hoch > 30.0:
                _tu.strang(PackedVector2Array([p + Vector2(x, -hoch),
                    p + Vector2(x, -hoch - 12.0)]),
                    PackedFloat32Array([16.0, 16.0]), stein, 2, KANTE)
        for i in 3:
            _tu.klecks(p + Vector2(70.0 + float(i) * 12.0, 4.0 - float(i) * 3.0),
                6.0 - float(i), stein, i, KANTE)
    else:
        # Turmstumpf: rund, oben offen.
        _tu.strang(PackedVector2Array([p, p + Vector2(0.0, -44.0)]),
            PackedFloat32Array([70.0, 64.0]), stein, 2, KANTE)
        _tu.klecks(p + Vector2(0.0, -44.0), 32.0, stein.lightened(0.12), 2, KANTE)
        _tu.klecks(p + Vector2(0.0, -44.0), 20.0, stein.darkened(0.45), 3)
    # Ein Busch daneben, damit sie nicht wie hingestellt aussieht.
    _busch(p + Vector2(-70.0, 8.0), rng)
