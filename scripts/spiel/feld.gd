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
## **Je Kachel einmal gerechnet.** Der Inhalt einer Kachel haengt nur an
## ihren Gitterkoordinaten; neu gezeichnet wird, sobald man eine halbe Kachel
## weiter ist, und dabei stehen fast alle Kacheln schon. Ohne Merken kostete
## ein Neuzeichnen 43 ms - ein Ruck etwa jede Sekunde, die man laeuft.
var _kacheln := {}
const KACHELN_HOECHSTENS := 160
var _sand: ImageTexture
var _gras: ImageTexture
var _erde: ImageTexture
var _wasser: ImageTexture
var _weiss: ImageTexture
## Name -> [Region, Ankerspalte] der Landschafts-Sprites.
var _sprites := {}
var _wasserpunkte: Array = []


## **Ein Dreiecksnetz mit einem Muster.** Gesammelt wird ueber alle Kacheln,
## gespuelt in einem Aufruf. Die Dreiecke stehen einzeln, ohne Index: so
## haengt man das Netz einer gemerkten Kachel mit `append_array` an, ohne
## jeden Index um seinen Platz zu verschieben.
class Netz:
    var tex: Texture2D
    var punkte := PackedVector2Array()
    var uvs := PackedVector2Array()
    var farben := PackedColorArray()

    func _init(t: Texture2D) -> void:
        tex = t

    func _uv(p: Vector2) -> Vector2:
        return p / (Pixel.P * Vector2(tex.get_size()))

    func _ecke(p: Vector2, farbe: Color) -> void:
        punkte.append(p)
        uvs.append(_uv(p))
        farben.append(farbe)

    func flaeche(pts: PackedVector2Array, farbe: Color) -> void:
        for i in Geometry2D.triangulate_polygon(pts):
            _ecke(pts[i], farbe)

    ## Ein Band aus zwei Kanten gleicher Laenge.
    func band(links: PackedVector2Array, rechts: PackedVector2Array, farbe: Color) -> void:
        for i in links.size() - 1:
            for p in [links[i], rechts[i], links[i + 1], rechts[i], rechts[i + 1], links[i + 1]]:
                _ecke(p, farbe)

    func dazu(n: Netz) -> void:
        punkte.append_array(n.punkte)
        uvs.append_array(n.uvs)
        farben.append_array(n.farben)

    func spuele(ci: RID) -> void:
        if punkte.is_empty():
            return
        RenderingServer.canvas_item_add_triangle_array(ci, PackedInt32Array(), punkte,
            farben, uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


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

const SCHICHTEN := ["sand", "wiese_rand", "wiese", "weg_rand", "weg", "wasser_rand", "wasser"]

func _netze() -> Dictionary:
    return {
        "sand": Netz.new(_sand),
        "wiese_rand": Netz.new(_weiss), "wiese": Netz.new(_gras),
        "weg_rand": Netz.new(_weiss), "weg": Netz.new(_erde),
        "wasser_rand": Netz.new(_weiss), "wasser": Netz.new(_wasser),
    }


func _draw() -> void:
    # **Was die Kamera erreichen kann, bevor neu gezeichnet wird**: das halbe
    # Sichtfeld (`Gefecht.BILD_HALB_X/_Y`, bei 20:9 bis 1000 hoch) plus der
    # Weg bis zum naechsten Neuzeichnen und eine Figur Rand. Ein Quadrat von
    # 1400 um die Mitte war doppelt so viele Kacheln.
    var weit := Vector2(Gefecht.BILD_HALB_X, 1000.0) + Vector2.ONE * (KACHEL * 0.4 + 140.0)
    var von := ((_mitte - weit) / KACHEL).floor()
    var bis := ((_mitte + weit) / KACHEL).floor()
    var netze := _netze()
    var a := von * KACHEL
    var b := (bis + Vector2.ONE) * KACHEL
    (netze["sand"] as Netz).flaeche(PackedVector2Array([a, Vector2(b.x, a.y), b,
        Vector2(a.x, b.y)]), Color.WHITE)
    var dinge: Array = []
    for gx in range(int(von.x), int(bis.x) + 1):
        for gy in range(int(von.y), int(bis.y) + 1):
            var kachel: Array = _kachel_an(gx, gy)
            var eigene: Dictionary = kachel[0]
            for name in eigene:
                (netze[name] as Netz).dazu(eigene[name])
            dinge.append_array(kachel[1])
    var ci := get_canvas_item()
    # **In Schichten**: erst alle Wiesenraender, dann alle Wiesen, dann Wege
    # und Wasser. Je Kachel alles auf einmal liess den Rand der naechsten
    # Wiese ueber die vorige laufen.
    for name in SCHICHTEN:
        (netze[name] as Netz).spuele(ci)
    Pixel.bereit()
    dinge.sort_custom(func(x: Array, y: Array) -> bool: return x[0].y < y[0].y)
    # Erst alle Schatten, dann alle Dinge: kein Schatten liegt auf einem Ding.
    for d in dinge:
        var schatten: Array = d[3]
        if not schatten.is_empty():
            Pixel.setze(ci, schatten[0], schatten[1], (d[0] as Vector2) + schatten[2])
    for d in dinge:
        var s: Array = d[1]
        if not s.is_empty():
            Pixel.setze(ci, s[0], s[1], d[0], d[2])


## Eine Kachel: ihre Netze (nur die, die etwas tragen), ihre Dinge am Boden,
## ihre hohen Dinge, ihr Lebendes und ihre Wasserpunkte (fuer das Glitzern).
func _rechne_kachel(gx: int, gy: int) -> Array:
    var netze := _netze()
    var dinge: Array = []
    _hoch = []
    _lebend = []
    _wasserpunkte = []
    _kachel(gx, gy, netze, dinge)
    var eigene := {}
    for name in netze:
        if not (netze[name] as Netz).punkte.is_empty():
            eigene[name] = netze[name]
    return [eigene, dinge, _hoch, _lebend, _wasserpunkte]


func _kachel_an(gx: int, gy: int) -> Array:
    var k := Vector2i(gx, gy)
    if not _kacheln.has(k):
        if _kacheln.size() > KACHELN_HOECHSTENS:
            _kacheln.clear()
        _kacheln[k] = _rechne_kachel(gx, gy)
    return _kacheln[k]


## Eintraege einer Spalte (2 hoch, 3 lebend, 4 Wasser) aller Kacheln, die das
## Rechteck um `mitte` beruehren.
## Gemerkt je Spalte und Kachelbereich: die Liste aendert sich erst, wenn
## das Rechteck eine Kachelgrenze ueberschreitet, gefragt wird jedes Bild.
var _gesammelt := {}

func _sammle(spalte: int, mitte: Vector2, halb: Vector2) -> Array:
    var von := ((mitte - halb) / KACHEL).floor()
    var bis := ((mitte + halb) / KACHEL).floor()
    var schluessel := [spalte, von, bis]
    var alt: Variant = _gesammelt.get(spalte)
    if alt != null and alt[0] == schluessel:
        return alt[1]
    var aus: Array = []
    for gx in range(int(von.x), int(bis.x) + 1):
        for gy in range(int(von.y), int(bis.y) + 1):
            aus.append_array(_kachel_an(gx, gy)[spalte])
    _gesammelt[spalte] = [schluessel, aus]
    return aus


## **Die hohen Dinge im Bild**: `[Ort, Name]` - Baeume, Kiefern, Tuerme.
func hohe_dinge(mitte: Vector2, halb: Vector2) -> Array:
    return _sammle(2, mitte, halb)


## **Was sich wiegt**: `[Ort, Name]` - Grasbueschel, Schilf.
func lebendes(mitte: Vector2, halb: Vector2) -> Array:
    return _sammle(3, mitte, halb)


## **Wo Wasser glitzern kann**: Orte auf Teichen und Baechen.
func wasserpunkte(mitte: Vector2, halb: Vector2) -> Array:
    return _sammle(4, mitte, halb)


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
        for p in (bahn[0] as PackedVector2Array):
            _wasserpunkte.append([p, 14.0])
    var rng := _saat(gx, gy, 2)
    if rng.randf() < 0.05:
        var p := ecke + Vector2(0.3 + rng.randf() * 0.4, 0.3 + rng.randf() * 0.4) * KACHEL
        var r := 50.0 + rng.randf() * 30.0
        var welle := rng.randf()
        (netze["wasser_rand"] as Netz).flaeche(_blob(p, r + P * 1.6, welle),
            Palette.WIESE_TIEF.darkened(0.3))
        (netze["wasser"] as Netz).flaeche(_blob(p, r, welle), Color.WHITE)
        _wasserpunkte.append([p, r * 0.7])
        # Schilf am Ufer.
        for i in 3:
            var w := PI * (0.7 + float(i) * 0.25)
            var u := p + Vector2(cos(w), sin(w) * 0.82) * r
            _ding(dinge, u, "schilf", 0.0)


## Ein Sprite der Landschaft, einmal gebaut und gemerkt.
func _sprite(name: String) -> Array:
    if _sprites.has(name):
        return _sprites[name]
    var d := Landschaft.bild_von(name)
    var schluessel := "land|" + name
    var r := Pixel.bild(schluessel, d[0], Landschaft.kleid(d[2]), d[1], false, false, d[3])
    var s := [r, Pixel.anker(schluessel, false, false, d[3])]
    _sprites[name] = s
    return s


## Ein Ding vormerken: Ort, Sprite, Farbe, Schatten (Radius, 0 = keiner).
## **Der Schatten ist ein Sprite**, eine flache Ellipse nach rechts unten,
## vom Licht weg: Zeile fuer Zeile gezeichnet waren es bei dreihundert Dingen
## zweitausend Aufrufe je Neuzeichnen.
##
## **Hohe Dinge** (`Landschaft.ist_hoch`) legen nur ihren Schatten in den
## Boden und sich selbst in `_hoch`, **Lebendes** (`ist_lebend`) nur in
## `_lebend`: beides holt man mit `hohe_dinge()` und `lebendes()`.
var _hoch: Array = []
var _lebend: Array = []

func _ding(dinge: Array, p: Vector2, name: String, schatten: float,
        modul := Color.WHITE) -> void:
    var s: Array = []
    if schatten > 0.0:
        var breite := maxi(4, int(roundf(schatten * 2.0 / P)))
        var name_s := "land_schatten%d" % breite
        var r := Pixel.bild(name_s, _schatten_zeilen(breite), Pixel.grund(), breite / 2)
        s = [r, Pixel.anker(name_s), Vector2(schatten * 0.3, P * float(breite / 6))]
    if Landschaft.ist_lebend(name):
        _lebend.append([p, name])
        return
    if Landschaft.ist_hoch(name):
        _hoch.append([p, name])
        dinge.append([p, [], modul, s])
        return
    dinge.append([p, _sprite(name), modul, s])


## Eine flache Ellipse aus `~`, `breite` Bildpunkte, gut ein Drittel so hoch.
static func _schatten_zeilen(breite: int) -> PackedStringArray:
    var hoch := maxi(2, int(roundf(float(breite) * 0.36)))
    var aus := PackedStringArray()
    for y in hoch:
        var t := (float(y) + 0.5) / float(hoch) * 2.0 - 1.0
        var halb := float(breite) * 0.5 * sqrt(maxf(0.0, 1.0 - t * t))
        var n := ""
        for x in breite:
            n += "~" if absf(float(x) + 0.5 - float(breite) * 0.5) < halb else "."
        aus.append(n)
    return aus


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
