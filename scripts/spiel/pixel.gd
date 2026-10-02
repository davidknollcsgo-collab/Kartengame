class_name Pixel
extends RefCounted

## **Pixel-Art als Text.**
##
## Die Figuren waren bis Oktober 2026 Vektorstriche (`Tusche`), die in ein
## Drittel der Aufloesung gerechnet wurden - im Bild Klumpen und
## Strichmaennchen, keine Soldaten. Hier stehen sie Pixel fuer Pixel, als
## Zeichenraster im Quelltext (`Figuren`): **keine Bilddatei**, das Bild
## entsteht beim Start.
##
## **Die Zeichen sind Rollen, keine Farben.** `b` heisst "Rock in der Farbe
## der Sorte", `s` "Gesicht", `M` "Stahl". Aufgeloest wird beim Bauen, aus
## `Palette`: dieselbe Zeichnung ergibt so jede Sorte und jedes Gewand, und
## die Farben bleiben an einer Stelle.
##
## **Ein Atlas fuer alles.** Jedes Bild wird einmal in ein gemeinsames
## `Image` gesetzt; gezeichnet wird mit `canvas_item_add_texture_rect_region`
## auf dieselbe Textur, und gleiche Textur heisst: der Renderer buendelt
## dreihundert Figuren zu wenigen Aufrufen. Auch die Rasterpunkte der
## Effekte (`punkt`, `linie`, `ring`) nehmen ein weisses Feld desselben
## Atlas - sie buendeln mit.

## Ein Bildpunkt des Pixelpuffers in Punkten des Feldes. Muss
## `zug_lauf.PIXEL / Gefecht.ZOOM` sein.
const P := 3.0 / 0.8
const GROESSE := 1024

static var _bild: Image
static var _textur: ImageTexture
static var _regionen := {}
static var _anker := {}
static var _x := 4
static var _y := 0
static var _zeilen_hoehe := 0
static var _schmutzig := false


# --- Rollen ----------------------------------------------------------------

## Die festen Rollen: alles, was nicht die Farbe der Sorte traegt.
static func grund() -> Dictionary:
    return {
        "o": Palette.UMRISS, "e": Palette.UMRISS,
        "s": Palette.HAUT, "S": Palette.HAUT_TIEF,
        "m": Palette.STAHL_HELL, "M": Palette.STAHL, "n": Palette.STAHL_TIEF,
        "w": Palette.HOLZ_HELL, "W": Palette.HOLZ,
        "l": Palette.LEDER, "L": Palette.LEDER_TIEF,
        "f": Palette.STIEFEL, "F": Palette.STIEFEL_TIEF,
        "x": Palette.WEISS,
        "z": Palette.GEFAHR,
        "$": Palette.SOLD, "%": Palette.SOLD.darkened(0.35),
        "~": Palette.SCHATTEN,
    }


## **Ein Kleid**: die Rollen in der Farbe einer Sorte oder eines Gewands.
## Licht von links oben (`Palette.LICHT`): `a` ist die Lichtseite, `c` und
## `d` die Schattenseite. Die Hose ist dunkler und grauer als der Rock - so
## liest man Rock und Beine als zwei Stuecke.
static func kleid(haupt: Color, glanz := Color(0, 0, 0, 0)) -> Dictionary:
    var k := grund()
    k["a"] = haupt.lightened(0.30)
    k["b"] = haupt
    k["c"] = haupt.darkened(0.28)
    k["d"] = haupt.darkened(0.50)
    var hose := haupt.lerp(Color(0.30, 0.27, 0.25), 0.55)
    k["h"] = hose
    k["H"] = hose.darkened(0.30)
    # Umhang des Helden: dunkler als das Gewand, damit er dahinter liegt.
    k["u"] = haupt.darkened(0.40)
    k["U"] = haupt.darkened(0.58)
    k["q"] = glanz if glanz.a > 0.0 else haupt.lightened(0.55)
    # Fell des Wolfs: Bauch und Schnauze heller.
    k["y"] = haupt.lightened(0.48)
    return k


# --- Der Atlas -------------------------------------------------------------

static func _sicher() -> void:
    if _bild != null:
        return
    _bild = Image.create(GROESSE, GROESSE, false, Image.FORMAT_RGBA8)
    # Ein weisses Feld fuer die Rasterpunkte, oben links.
    _bild.fill_rect(Rect2i(0, 0, 3, 3), Color.WHITE)
    _x = 4
    _y = 0
    _zeilen_hoehe = 3
    _textur = ImageTexture.create_from_image(_bild)


## Vor dem Zeichnen eines Bildes einmal aufrufen: was seit dem letzten Mal
## in den Atlas kam, geht jetzt zur Grafikkarte.
static func bereit() -> RID:
    _sicher()
    if _schmutzig:
        _textur.update(_bild)
        _schmutzig = false
    return _textur.get_rid()


static func textur() -> Texture2D:
    _sicher()
    if _schmutzig:
        _textur.update(_bild)
        _schmutzig = false
    return _textur


## **Ein Bild aus Zeilen und Kleid**, gemerkt unter `schluessel`.
## `spiegel` dreht es nach links; `blitz` macht es zur hellen Silhouette
## (ein Getroffener blitzt auf). `anker` ist die Spalte der Fussmitte.
static func bild(schluessel: String, zeilen: PackedStringArray, kleid_: Dictionary,
        anker: int, spiegel := false, blitz := false) -> Rect2i:
    var name := "%s|%d|%d" % [schluessel, int(spiegel), int(blitz)]
    if _regionen.has(name):
        return _regionen[name]
    _sicher()
    var h := zeilen.size()
    var w := 0
    for z in zeilen:
        w = maxi(w, z.length())
    if _x + w + 1 > GROESSE:
        _x = 4
        _y += _zeilen_hoehe + 1
        _zeilen_hoehe = 0
    if _y + h + 1 > GROESSE:
        push_error("Pixel: Atlas voll")
        return Rect2i(0, 0, 1, 1)
    var blitz_farbe := Palette.BLITZ
    for y in h:
        var z: String = zeilen[y]
        for x in z.length():
            var rolle := z[x]
            if rolle == "." or rolle == " ":
                continue
            var c: Color = kleid_.get(rolle, Color.MAGENTA)
            if blitz:
                c = c.lerp(blitz_farbe, 0.82)
            var px := (w - 1 - x) if spiegel else x
            _bild.set_pixel(_x + px, _y + y, c)
    var r := Rect2i(_x, _y, w, h)
    _regionen[name] = r
    _anker[name] = (w - 1 - anker) if spiegel else anker
    _x += w + 1
    _zeilen_hoehe = maxi(_zeilen_hoehe, h)
    _schmutzig = true
    return r


static func anker(schluessel: String, spiegel := false, blitz := false) -> int:
    return _anker.get("%s|%d|%d" % [schluessel, int(spiegel), int(blitz)], 0)


# --- Zeichnen --------------------------------------------------------------

## Ein Ort des Feldes, auf das Pixelraster gelegt.
static func raster(ort: Vector2) -> Vector2:
    return (ort / P).round()


## **Ein Bild an seinen Fuessen setzen**: `fuss` im Feld, die Fussmitte
## (`anker`) auf diesem Pixel, die unterste Zeile auf dem Boden.
static func setze(ci: RID, r: Rect2i, anker_x: int, fuss: Vector2,
        modul := Color.WHITE) -> void:
    var px := raster(fuss)
    var oben_links := Vector2(px.x - float(anker_x), px.y - float(r.size.y) + 1.0) * P
    RenderingServer.canvas_item_add_texture_rect_region(ci,
        Rect2(oben_links, Vector2(r.size) * P), _textur.get_rid(), Rect2(r), modul)


## Ein Rasterpunkt, `n` Bildpunkte gross, am Pixel von `ort`.
static func punkt(ci: RID, ort: Vector2, farbe: Color, n := 1) -> void:
    var px := raster(ort)
    RenderingServer.canvas_item_add_texture_rect_region(ci,
        Rect2(px * P, Vector2.ONE * P * float(n)), _textur.get_rid(),
        Rect2(1, 1, 1, 1), farbe)


## Ein Rechteck im Pixelraster (Balken, Riegel): `von` oben links im Feld,
## `groesse` in Bildpunkten.
static func block(ci: RID, von: Vector2, groesse: Vector2i, farbe: Color) -> void:
    var px := raster(von)
    RenderingServer.canvas_item_add_texture_rect_region(ci,
        Rect2(px * P, Vector2(groesse) * P), _textur.get_rid(),
        Rect2(1, 1, 1, 1), farbe)


## **Eine Linie aus Bildpunkten** (Bresenham): scharf in jedem Winkel. Ein
## gedrehtes Pixelbild zerfaellt, eine gerasterte Linie nicht.
static func linie(ci: RID, a: Vector2, b: Vector2, farbe: Color, dicke := 1) -> void:
    var p0 := Vector2i(raster(a))
    var p1 := Vector2i(raster(b))
    var dx := absi(p1.x - p0.x)
    var dy := -absi(p1.y - p0.y)
    var sx := 1 if p0.x < p1.x else -1
    var sy := 1 if p0.y < p1.y else -1
    var fehler := dx + dy
    var p := p0
    var rid := _textur.get_rid()
    var versatz := Vector2.ONE * float(dicke / 2)
    for i in 512:
        RenderingServer.canvas_item_add_texture_rect_region(ci,
            Rect2((Vector2(p) - versatz) * P, Vector2.ONE * P * float(dicke)), rid,
            Rect2(1, 1, 1, 1), farbe)
        if p == p1:
            break
        var e2 := 2 * fehler
        if e2 >= dy:
            fehler += dy
            p.x += sx
        if e2 <= dx:
            fehler += dx
            p.y += sy


## Ein flacher Ring (am Boden liegend: halb so hoch wie breit), aus
## Bildpunkten. `bogen` begrenzt ihn auf einen Teil des Umfangs.
static func ring(ci: RID, mitte: Vector2, radius: float, farbe: Color,
        flach := 0.5, von := 0.0, bis := TAU) -> void:
    var r_px := radius / P
    var schritte := maxi(8, int(r_px * absf(bis - von) * 1.2))
    var zuletzt := Vector2i(1 << 30, 0)
    var mitte_px := raster(mitte)
    var rid := _textur.get_rid()
    for i in schritte + 1:
        var w := lerpf(von, bis, float(i) / float(schritte))
        var p := Vector2i((mitte_px + Vector2(cos(w) * r_px, sin(w) * r_px * flach)).round())
        if p == zuletzt:
            continue
        zuletzt = p
        RenderingServer.canvas_item_add_texture_rect_region(ci,
            Rect2(Vector2(p) * P, Vector2.ONE * P), rid, Rect2(1, 1, 1, 1), farbe)


## Eine gefuellte Scheibe (rund oder flach), zeilenweise.
static func scheibe(ci: RID, mitte: Vector2, radius: float, farbe: Color,
        flach := 1.0) -> void:
    var r_px := radius / P
    var mitte_px := raster(mitte)
    var rid := _textur.get_rid()
    var hoch := maxi(1, int(round(r_px * flach)))
    for dy in range(-hoch, hoch + 1):
        var t := float(dy) / maxf(0.5, r_px * flach)
        var halb := int(round(r_px * sqrt(maxf(0.0, 1.0 - t * t))))
        if halb <= 0 and dy != 0:
            continue
        RenderingServer.canvas_item_add_texture_rect_region(ci,
            Rect2((mitte_px + Vector2(-halb, dy)) * P,
                Vector2(halb * 2 + 1, 1) * P), rid, Rect2(1, 1, 1, 1), farbe)
