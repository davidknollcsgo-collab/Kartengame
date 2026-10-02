extends Node2D

## **Der Boden als Landkarte, in Pixeln.**
##
## Sand als Grund, darauf zusammenhaengende Wiesen, Wege, selten ein Teich oder
## ein Bach, und darauf Baeume, Buesche, Steine, Ruinen, Zaeune. So stand es
## in der Vorlage des Nutzers (Oktober 2026).
##
## **Bis zur dritten Runde der Grafik war er Vektor** (`Tusche`): weiche
## Kleckse mit durchsichtigem Rand, im Pixelpuffer verwaschen, waehrend die
## Figuren darueber scharfe Sprites waren. Jetzt:
##
##   * **Flaechen sind Vielecke mit Muster.** Sand, Gras, Erde und Wasser sind
##     je ein kleines gekacheltes Bild (`_muster`, einmal gerechnet), die
##     Flaechen darauf Vielecke ohne Glaettung - im Drittelpuffer haben sie
##     von selbst harte Pixelkanten. Das Muster haengt am Ort im Feld, nicht
##     an der Flaeche: es laeuft ueber jede Kachelgrenze weiter.
##   * **Ein Netz je Muster** (`Netz`): alle Wiesen eines Bildes sind ein
##     Aufruf, alle Wege einer. Ein Vieleck je Aufruf waeren Hunderte.
##   * **Dinge sind Sprites** (`Landschaft`), im selben Atlas wie die Figuren,
##     mit halber Kante und kleinem flachem Schatten.
##
## **Was einen Hintergrund laut macht, ist die Zahl der getrennten Dinge
## darin.** Die Wiesen sind Flaeche und kein Ding; Dinge stehen hoechstens
## `DINGE` je Kachel, und die grossen (Baum, Ruine, Teich) selten.
##
## Gekachelt um die Mitte; der Inhalt einer Kachel haengt allein an ihren
## Gitterkoordinaten - dieselbe Kachel sieht immer gleich aus, egal von
## welcher Seite man sie betritt.

const P := Pixel.P
const KACHEL := 420.0
## Wieviele Dinge auf einer Kachel stehen. Sehr wenige: siehe oben.
const DINGE := 3
## Kantenlaenge der Muster in Bildpunkten.
const MUSTER := 64

var _mitte := Vector2.ZERO
var _sand: ImageTexture
var _gras: ImageTexture
var _erde: ImageTexture
var _wasser: ImageTexture
var _weiss: ImageTexture
## Name -> [Region, Ankerspalte] der Landschafts-Sprites.
var _sprites := {}


## **Ein Dreiecksnetz mit einem Muster.** Gesammelt wird ueber alle Kacheln,
## gespuelt in einem Aufruf.
class Netz:
    var tex: Texture2D
    var punkte := PackedVector2Array()
    var uvs := PackedVector2Array()
    var farben := PackedColorArray()
    var idx := PackedInt32Array()

    func _init(t: Texture2D) -> void:
        tex = t

    func _uv(p: Vector2) -> Vector2:
        return p / (Pixel.P * Vector2(tex.get_size()))

    func flaeche(pts: PackedVector2Array, farbe: Color) -> void:
        var tri := Geometry2D.triangulate_polygon(pts)
        if tri.is_empty():
            return
        var basis := punkte.size()
        for p in pts:
            punkte.append(p)
            uvs.append(_uv(p))
            farben.append(farbe)
        for i in tri:
            idx.append(basis + i)

    ## Ein Band aus zwei Kanten gleicher Laenge.
    func band(links: PackedVector2Array, rechts: PackedVector2Array, farbe: Color) -> void:
        var basis := punkte.size()
        for i in links.size():
            for p in [links[i], rechts[i]]:
                punkte.append(p)
                uvs.append(_uv(p))
                farben.append(farbe)
        for i in links.size() - 1:
            var a := basis + i * 2
            idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])

    func spuele(ci: RID) -> void:
        if idx.is_empty():
            return
        RenderingServer.canvas_item_add_triangle_array(ci, idx, punkte, farben, uvs,
            PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    _sand = _muster(0)
    _gras = _muster(1)
    _erde = _muster(2)
    _wasser = _muster(3)
    var w := Image.create(1, 1, false, Image.FORMAT_RGBA8)
    w.fill(Color.WHITE)
    _weiss = ImageTexture.create_from_image(w)


func setze_mitte(ort: Vector2) -> void:
    # Erst neu zeichnen, wenn man eine halbe Kachel weiter ist. Jedes Bild
    # neu waere derselbe Grund fuer denselben Preis.
    if ort.distance_squared_to(_mitte) < (KACHEL * 0.4) * (KACHEL * 0.4):
        return
    _mitte = ort
    queue_redraw()


# --- Die Muster ------------------------------------------------------------

## **Ein gekacheltes Muster**, `MUSTER` Bildpunkte im Quadrat. Nahtlos, weil
## jedes Ding darin modulo der Kante gesetzt wird. Feste Saat: derselbe Sand
## in jedem Lauf.
func _muster(art: int) -> ImageTexture:
    var rng := RandomNumberGenerator.new()
    rng.seed = 5501 + art * 97
    var bild := Image.create(MUSTER, MUSTER, false, Image.FORMAT_RGBA8)
    var grund: Color = [Palette.BODEN, Palette.WIESE, Palette.ERDE, Palette.WASSER][art]
    bild.fill(grund)
    var setze := func(x: int, y: int, c: Color) -> void:
        bild.set_pixel(posmod(x, MUSTER), posmod(y, MUSTER), c)
    # Grobe, sanfte Flecken: der Grund ist nie eine Farbe.
    for i in 6:
        var m := Vector2i(rng.randi_range(0, MUSTER - 1), rng.randi_range(0, MUSTER - 1))
        var r := rng.randi_range(5, 11)
        var c := grund.darkened(0.035) if i % 2 == 0 else grund.lightened(0.03)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy * 2 <= r * r:
                    setze.call(m.x + dx, m.y + dy, c)
    # Koernung je Bildpunkt.
    for y in MUSTER:
        for x in MUSTER:
            var n := rng.randf()
            if n < 0.06:
                setze.call(x, y, grund.darkened(0.07))
            elif n < 0.09:
                setze.call(x, y, grund.lightened(0.07))
    match art:
        0, 2:
            # Kiesel: ein heller Punkt, rechts unten sein Schatten.
            for i in (10 if art == 0 else 16):
                var x := rng.randi_range(0, MUSTER - 1)
                var y := rng.randi_range(0, MUSTER - 1)
                setze.call(x, y, Palette.GRUND_ZIER.lightened(0.18))
                setze.call(x + 1, y, Palette.GRUND_ZIER)
                setze.call(x + 1, y + 1, grund.darkened(0.16))
        1:
            # **Gras sind kleine Haken**, dunkel unten, darueber ein Licht.
            for i in 70:
                var x := rng.randi_range(0, MUSTER - 1)
                var y := rng.randi_range(0, MUSTER - 1)
                var c := Palette.WIESE_TIEF if i % 4 else Palette.HALM
                setze.call(x, y, c)
                setze.call(x - 1, y - 1, c)
                setze.call(x + 1, y - 1, c)
            for i in 40:
                setze.call(rng.randi_range(0, MUSTER - 1), rng.randi_range(0, MUSTER - 1),
                    Palette.WIESE.lightened(0.13))
        3:
            # Wellen: kurze helle Striche quer.
            for i in 16:
                var x := rng.randi_range(0, MUSTER - 1)
                var y := rng.randi_range(0, MUSTER - 1)
                var l := rng.randi_range(2, 5)
                for k in l:
                    setze.call(x + k, y, Palette.WASSER_HELL)
                setze.call(x + 1, y + 1, Palette.WASSER.darkened(0.12))
    return ImageTexture.create_from_image(bild)


# --- Zeichnen --------------------------------------------------------------

func _draw() -> void:
    # Halbe Bildhoehe im Feld (bis 1000 bei 20:9 und Zoom 0,8) plus der Weg,
    # den man geht, bevor neu gezeichnet wird.
    var sicht := 1400.0
    var von := ((_mitte - Vector2.ONE * sicht) / KACHEL).floor()
    var bis := ((_mitte + Vector2.ONE * sicht) / KACHEL).ceil()
    var netze := {
        "sand": Netz.new(_sand),
        "wiese_rand": Netz.new(_weiss), "wiese": Netz.new(_gras),
        "weg_rand": Netz.new(_weiss), "weg": Netz.new(_erde),
        "wasser_rand": Netz.new(_weiss), "wasser": Netz.new(_wasser),
    }
    var a := von * KACHEL
    var b := (bis + Vector2.ONE) * KACHEL
    (netze["sand"] as Netz).flaeche(PackedVector2Array([a, Vector2(b.x, a.y), b,
        Vector2(a.x, b.y)]), Color.WHITE)
    var dinge: Array = []
    for gx in range(int(von.x), int(bis.x) + 1):
        for gy in range(int(von.y), int(bis.y) + 1):
            _kachel(gx, gy, netze, dinge)
    var ci := get_canvas_item()
    # **In Schichten**: erst alle Wiesenraender, dann alle Wiesen, dann Wege
    # und Wasser. Je Kachel alles auf einmal liess den Rand der naechsten
    # Wiese ueber die vorige laufen.
    for name in ["sand", "wiese_rand", "wiese", "weg_rand", "weg", "wasser_rand", "wasser"]:
        (netze[name] as Netz).spuele(ci)
    Pixel.bereit()
    dinge.sort_custom(func(x: Array, y: Array) -> bool: return x[0].y < y[0].y)
    # Erst alle Schatten, dann alle Dinge: kein Schatten liegt auf einem Ding.
    for d in dinge:
        var schatten: float = d[3]
        if schatten > 0.0:
            Pixel.scheibe(ci, (d[0] as Vector2) + Vector2(schatten * 0.3, -P * 0.5),
                schatten, Palette.SCHATTEN, 0.36)
    for d in dinge:
        var s: Array = d[1]
        Pixel.setze(ci, s[0], s[1], d[0], d[2])


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


func _kachel(gx: int, gy: int, netze: Dictionary, dinge: Array) -> void:
    var ecke := Vector2(float(gx), float(gy)) * KACHEL
    var anteil := _wiese(gx, gy)
    _wiesen(gx, gy, ecke, anteil, netze)
    _pfade(gx, gy, ecke, netze)
    _wasser_an(gx, gy, ecke, netze, dinge)
    _dinge(gx, gy, ecke, anteil, dinge)


## Ein Kreis mit welligem Rand als Vieleck.
func _blob(p: Vector2, r: float, rng_wert: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    var n := 30
    for i in n:
        var w := TAU * float(i) / float(n)
        var wellig := 1.0 + 0.10 * sin(w * 3.0 + rng_wert * 6.0) \
            + 0.06 * sin(w * 5.0 + rng_wert * 11.0)
        pts.append(p + Vector2(cos(w), sin(w) * 0.82) * r * wellig)
    return pts


## Die Wiese einer Kachel: grosse wellige Flaechen, darunter ein Bildpunkt
## dunklerer Rand. Ueberlappende Flaechen verschmelzen, weil alle Raender
## vor allen Flaechen gezeichnet werden.
func _wiesen(gx: int, gy: int, ecke: Vector2, anteil: float, netze: Dictionary) -> void:
    var zahl := int(round(anteil * 5.0))
    if zahl == 0:
        return
    var rng := _saat(gx, gy, 0)
    for i in zahl:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var r := 110.0 + rng.randf() * 90.0
        var welle := rng.randf()
        (netze["wiese_rand"] as Netz).flaeche(_blob(p, r + P * 1.3, welle),
            Palette.WIESE_TIEF.darkened(0.12))
        (netze["wiese"] as Netz).flaeche(_blob(p, r, welle), Color.WHITE)


## **Ausgetretene Pfade ueber viele Kacheln.** Ein Pfad haengt an einer
## Gitterlinie und nicht an einer Kachel: seine Lage ist eine Funktion von
## `x` (bzw. `y`) allein, also setzt er sich ueber jede Kachelgrenze fort.
## Ob es ihn gibt, sagt die Saat der Linie - nicht jede hat einen.
const PFAD_ABSTAND := 3
const PFAD_STUECKE := 7


func _pfade(gx: int, gy: int, ecke: Vector2, netze: Dictionary) -> void:
    if posmod(gy, PFAD_ABSTAND) == 0 and _linie_da(gy, 1, 150):
        _pfad(_bahn(gy, ecke, true), netze)
    if posmod(gx, PFAD_ABSTAND) == 0 and _linie_da(gx, 2, 150):
        _pfad(_bahn(gx, ecke, false), netze)


## Die Punkte einer Bahn und ihre Querrichtung, **beide aus der Formel**.
## Aus den Nachbarpunkten gerechnet, waere die Querrichtung am Kachelrand
## einseitig, und zwei Kacheln truegen an derselben Stelle zwei Kanten.
func _bahn(linie: int, ecke: Vector2, waagerecht: bool) -> Array:
    var punkte := PackedVector2Array()
    var quer := PackedVector2Array()
    for i in PFAD_STUECKE + 1:
        var t := (ecke.x if waagerecht else ecke.y) + KACHEL * float(i) / float(PFAD_STUECKE)
        var p := _bahnpunkt(t, linie, ecke, waagerecht)
        var vor := _bahnpunkt(t + 1.0, linie, ecke, waagerecht) \
            - _bahnpunkt(t - 1.0, linie, ecke, waagerecht)
        punkte.append(p)
        quer.append(vor.normalized().orthogonal())
    return [punkte, quer]


func _bahnpunkt(t: float, linie: int, ecke: Vector2, waagerecht: bool) -> Vector2:
    if waagerecht:
        return Vector2(t, ecke.y + KACHEL * 0.5 + _welle(t, linie))
    return Vector2(ecke.x + KACHEL * 0.5 + _welle(t, linie), t)


func _linie_da(linie: int, achse: int, von_256: int) -> bool:
    return (hash(Vector2i(linie, achse * 7919)) & 0xff) < von_256


func _welle(t: float, linie: int) -> float:
    var p := float(linie) * 1.7
    return sin(t * 0.0041 + p) * 70.0 + sin(t * 0.0113 + p * 2.3) * 22.0


func _kanten(bahn: Array, breite: Callable) -> Array:
    var punkte: PackedVector2Array = bahn[0]
    var quer: PackedVector2Array = bahn[1]
    var links := PackedVector2Array()
    var rechts := PackedVector2Array()
    for i in punkte.size():
        var h: float = breite.call(punkte[i])
        links.append(punkte[i] + quer[i] * h)
        rechts.append(punkte[i] - quer[i] * h)
    return [links, rechts]


func _pfad(bahn: Array, netze: Dictionary) -> void:
    var halb := func(p: Vector2) -> float:
        return 24.0 + 6.0 * sin(p.x * 0.013 + p.y * 0.017)
    var rand := _kanten(bahn, func(p: Vector2) -> float: return halb.call(p) + P * 1.2)
    var flaeche := _kanten(bahn, halb)
    (netze["weg_rand"] as Netz).band(rand[0], rand[1], Palette.ERDE.darkened(0.16))
    (netze["weg"] as Netz).band(flaeche[0], flaeche[1], Color.WHITE)
    # Zwei Spuren darin, dunkler: dort wird gegangen und gefahren.
    var punkte: PackedVector2Array = bahn[0]
    var quer: PackedVector2Array = bahn[1]
    for s in [-1.0, 1.0]:
        var mitte := PackedVector2Array()
        for i in punkte.size():
            mitte.append(punkte[i] + quer[i] * 10.0 * s)
        var spur := _kanten([mitte, quer], func(_p: Vector2) -> float: return P * 0.55)
        (netze["weg"] as Netz).band(spur[0], spur[1], Color(0.86, 0.84, 0.82))


## **Wasser, selten.** Ein Bach an einer Gitterlinie quer zu den Wegen (eine
## von acht Linien), und gelegentlich ein Teich. Dekoration ohne Kollision:
## man watet hindurch, wie man durch die Wiese geht.
func _wasser_an(gx: int, gy: int, ecke: Vector2, netze: Dictionary, dinge: Array) -> void:
    if posmod(gx + 1, PFAD_ABSTAND * 2) == 0 and _linie_da(gx, 5, 40):
        var bahn := _bahn(gx * 3 + 1, ecke, false)
        var breit := func(p: Vector2) -> float:
            return 20.0 + 6.0 * sin(p.y * 0.011 + float(gx))
        var rand := _kanten(bahn, func(p: Vector2) -> float: return breit.call(p) + P * 1.6)
        var flaeche := _kanten(bahn, breit)
        (netze["wasser_rand"] as Netz).band(rand[0], rand[1], Palette.WIESE_TIEF.darkened(0.3))
        (netze["wasser"] as Netz).band(flaeche[0], flaeche[1], Color.WHITE)
    var rng := _saat(gx, gy, 2)
    if rng.randf() < 0.05:
        var p := ecke + Vector2(0.3 + rng.randf() * 0.4, 0.3 + rng.randf() * 0.4) * KACHEL
        var r := 50.0 + rng.randf() * 30.0
        var welle := rng.randf()
        (netze["wasser_rand"] as Netz).flaeche(_blob(p, r + P * 1.6, welle),
            Palette.WIESE_TIEF.darkened(0.3))
        (netze["wasser"] as Netz).flaeche(_blob(p, r, welle), Color.WHITE)
        # Schilf am Ufer.
        for i in 3:
            var w := PI * (0.7 + float(i) * 0.25)
            var u := p + Vector2(cos(w), sin(w) * 0.82) * r
            _ding(dinge, u, "schilf", 0.0)


## Ein Sprite der Landschaft, einmal gebaut und gemerkt.
func _sprite(name: String) -> Array:
    if _sprites.has(name):
        return _sprites[name]
    var zeilen: PackedStringArray
    var anker := 0
    var kante := Landschaft.kante_laub()
    var umriss := true
    var teile := name.split(":")
    var nr := int(teile[1]) if teile.size() > 1 else 0
    match teile[0]:
        "baum":
            zeilen = Landschaft.baum(nr)
            anker = Landschaft.baum_anker(nr)
        "kiefer":
            zeilen = Landschaft.kiefer(nr)
            anker = Landschaft.kiefer_anker(nr)
        "busch":
            zeilen = Landschaft.busch(nr)
            anker = Landschaft.busch_anker(nr)
        "stein":
            zeilen = Landschaft.stein(nr)
            anker = Landschaft.stein_anker(nr)
            kante = Landschaft.kante_stein()
        "mauer":
            zeilen = Landschaft.mauer()
            anker = 13
            kante = Landschaft.kante_stein()
        "turm":
            zeilen = Landschaft.turm()
            anker = 9
            kante = Landschaft.kante_stein()
        "stumpf":
            zeilen = Landschaft.STUMPF
            anker = 3
            kante = Landschaft.kante_holz()
        "zaun":
            zeilen = Landschaft.ZAUN
            anker = 9
            kante = Landschaft.kante_holz()
        "gras":
            zeilen = PackedStringArray(Landschaft.GRAS[nr])
            anker = 2
            umriss = false
        "schilf":
            zeilen = Landschaft.SCHILF
            anker = 2
            umriss = false
        "kiesel":
            zeilen = PackedStringArray(Landschaft.KIESEL[nr])
            anker = 1
            umriss = false
    var schluessel := "land|" + name
    var r := Pixel.bild(schluessel, zeilen, Landschaft.kleid(kante), anker, false, false, umriss)
    var s := [r, Pixel.anker(schluessel, false, false, umriss)]
    _sprites[name] = s
    return s


## Ein Ding vormerken: Ort, Sprite, Farbe, Schattenradius (0 = keiner).
func _ding(dinge: Array, p: Vector2, name: String, schatten: float,
        modul := Color.WHITE) -> void:
    dinge.append([p, _sprite(name), modul, schatten])


func _dinge(gx: int, gy: int, ecke: Vector2, anteil: float, dinge: Array) -> void:
    var rng := _saat(gx, gy, 3)
    # **Die Wiese hat Bueschel und Blueten**, der Sand Kiesel. Ohne sie ist
    # zwischen den Dingen nichts, und der Grund ist ein Tischtuch.
    for i in int(anteil * 12.0):
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        if _wiese_an(p) < 0.5:
            continue
        _ding(dinge, p, "gras:%d" % rng.randi_range(0, 3), 0.0)
    for i in 5:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        _ding(dinge, p, "kiesel:%d" % rng.randi_range(0, 2), 0.0)
    for i in DINGE:
        var p := ecke + Vector2(rng.randf(), rng.randf()) * KACHEL
        var los := rng.randf()
        # Auf der Wiese stehen Baeume und Gras, im Sand Steine und Ruinen.
        if los < 0.18 + anteil * 0.30:
            if rng.randf() < 0.28:
                var nr := rng.randi_range(0, Landschaft.KIEFERN - 1)
                _ding(dinge, p, "kiefer:%d" % nr, float(Landschaft.kiefer_breite(nr)) * P * 0.45)
            else:
                var nr := rng.randi_range(0, Landschaft.BAEUME - 1)
                _ding(dinge, p, "baum:%d" % nr, float(Landschaft.baum_breite(nr)) * P * 0.5)
        elif los < 0.50 + anteil * 0.15:
            for k in 2 + rng.randi_range(0, 1):
                _ding(dinge, p + Vector2(rng.randf_range(-24.0, 24.0),
                    rng.randf_range(-10.0, 10.0)), "gras:%d" % rng.randi_range(0, 3), 0.0)
        elif los < 0.70:
            var nr := rng.randi_range(0, Landschaft.BUESCHE - 1)
            _ding(dinge, p, "busch:%d" % nr, (13.0 + nr * 2.0) * P * 0.5)
        elif los < 0.85:
            var nr := rng.randi_range(0, Landschaft.STEINE - 1)
            _ding(dinge, p, "stein:%d" % nr, (10.0 + nr * 3.0) * P * 0.45)
        elif los < 0.90:
            _ding(dinge, p, "zaun", 0.0)
        elif los < 0.96:
            _ding(dinge, p, "mauer" if rng.randf() < 0.5 else "turm", 13.0 * P)
            # Ein Busch daneben, damit sie nicht wie hingestellt aussieht.
            _ding(dinge, p + Vector2(-70.0, 8.0), "busch:0", 6.0 * P)
        else:
            _ding(dinge, p, "stumpf", 4.0 * P)
