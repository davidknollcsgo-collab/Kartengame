extends Control

## **Das Bedienbild - in derselben Pixelsprache wie das Feld.**
##
## Bis Oktober 2026 war es aus Vektorstrichen (`Tusche`) gebaut, und neben
## dem Pixelfeld sahen die Menues aus wie aus einem anderen Spiel. Jetzt:
## Pergament als erzeugte Textur, Rahmen aus Pixelstreifen mit
## Eckbeschlaegen, Knoepfe mit Fase, die sich beim Antippen eindruecken,
## Symbole und Figuren als Pixel-Sprites (`Symbole`, `Figuren`), dreifach
## vergroessert (`M`).
##
## **Alles wird sofort gezeichnet, in Reihenfolge.** Der Pinsel sammelte und
## kam erst am Ende aufs Blatt; mit Sprites dazwischen lag dann jedes Bild
## unter seiner eigenen Tafel. Nur die Schrift wartet (siehe `_worte`).
##
## **Die Aufstiegskarten bekommen den ganzen Schirm.** Sie sind die einzige
## Entscheidung im Lauf; alles andere ist Aufstellung und Reflex.

const TINTE := Color(0.12, 0.10, 0.09)
const ZINNOBER := Color(0.66, 0.14, 0.11)
const GOLD := Color(0.72, 0.55, 0.18)
const SEPIA := Color(0.42, 0.34, 0.24)
const HELL := Color(0.98, 0.96, 0.90)

## Ein Bildpunkt des Bedienbilds in Schirmpunkten.
const M := 3.0

const RAHMEN_TIEF := Color(0.200, 0.122, 0.071)
const RAHMEN := Color(0.400, 0.259, 0.141)
const RAHMEN_HELL := Color(0.639, 0.471, 0.282)
const BLATT := Color(0.957, 0.918, 0.808)
const BLATT_TIEF := Color(0.886, 0.824, 0.678)

## **Die Schrift wartet.** `draw_string` und alles andere gehen sofort aufs
## Blatt; die Worte kommen zuletzt, damit keine Flaeche sie verdeckt.
var _worte: Array = []
var _felder: Array = []
var _lauf: Node2D
## Der Knopf unter dem Finger, solange er liegt - er wird gedrueckt
## gezeichnet. Ausgeloest wird erst beim Loslassen ueber demselben Knopf.
var _gedrueckt := ""
var _pergament: ImageTexture

## **Zwei Schriften, und jede hat ihre Aufgabe.** Bricolage, kraeftig, fuer
## das, was einen Schirm benennt - Titel, Namen, Knoepfe; Rajdhani fuer
## Zahlen, deren Ziffern gleich breit stehen.
const BRICOLAGE := preload("res://schriften/bricolage/BricolageGrotesque.ttf")
const RAJDHANI := preload("res://schriften/rajdhani/Rajdhani-Medium.ttf")
var _kopf: Font
var _zahl: Font


func _ready() -> void:
    _lauf = get_parent().get_parent() as Node2D
    # Bricolage ist eine variable Schrift; ohne Achse steht sie im duennsten
    # Schnitt, und der verschwindet auf Pergament.
    var fett := FontVariation.new()
    fett.base_font = BRICOLAGE
    fett.variation_opentype = {
        TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
    _kopf = fett
    _zahl = RAJDHANI
    # Scharfe Pixel und gekacheltes Pergament.
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    _pergament = _baue_pergament()
    mouse_filter = Control.MOUSE_FILTER_PASS
    set_process(true)


func _process(_d: float) -> void:
    queue_redraw()


func _rand() -> float:
    # `get_display_safe_area()` nur auf dem Telefon: auf dem Schreibtisch
    # liefert sie den ganzen Bildschirm und nicht das Fenster, und aus der
    # Differenz wird ein Rand von vierhundert Bildpunkten.
    if not OS.has_feature("mobile"):
        return 26.0
    var sicher := DisplayServer.get_display_safe_area()
    var fenster := DisplayServer.window_get_size()
    return clampf(float(sicher.position.y), 26.0, float(fenster.y) * 0.12)


# --- Pergament und Rahmen ---------------------------------------------------

## **Pergament als Bild aus dem Code**: Rauschen in zwei Groessen, kurze
## Fasern, ein paar Flecken. Gesaet, also bei jedem Start gleich, und ohne
## Bilddatei. 64 Bildpunkte, dreifach vergroessert und gekachelt.
static func _baue_pergament() -> ImageTexture:
    var n := 64
    var bild := Image.create(n, n, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1157
    var grob := PackedFloat32Array()
    for i in 64:
        grob.append(rng.randf())
    for y in n:
        for x in n:
            # Grobes Rauschen ueber ein 8er-Gitter, das sich kachelt.
            var gx := x / 8
            var gy := y / 8
            var g := grob[(gy % 8) * 8 + (gx % 8)]
            var fein := rng.randf()
            var t := (g - 0.5) * 0.05 + (fein - 0.5) * 0.035
            bild.set_pixel(x, y, BLATT.lightened(t) if t > 0.0 else BLATT.darkened(-t))
    # Fasern: kurze waagerechte Striche, etwas dunkler.
    for i in 26:
        var x := rng.randi_range(0, n - 1)
        var y := rng.randi_range(0, n - 1)
        var l := rng.randi_range(2, 6)
        for k in l:
            var px := (x + k) % n
            bild.set_pixel(px, y, bild.get_pixel(px, y).darkened(0.07))
    # Flecken: kleine dunklere Tupfen, unregelmaessig. Ringe waren es
    # zuerst, und beim Kacheln standen sie als Muster aus Kreisen im Blatt.
    for i in 10:
        var cx := rng.randi_range(0, n - 1)
        var cy := rng.randi_range(0, n - 1)
        for k in rng.randi_range(2, 5):
            var px := posmod(cx + rng.randi_range(-1, 1), n)
            var py := posmod(cy + rng.randi_range(-1, 1), n)
            bild.set_pixel(px, py, bild.get_pixel(px, py).darkened(0.05))
    return ImageTexture.create_from_image(bild)


func _flaeche(r: Rect2, farbe: Color) -> void:
    draw_rect(r, farbe)


## Ein Rechteck aus Pergament, im Pixelraster gekachelt.
func _blatt(r: Rect2) -> void:
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(M, M))
    draw_texture_rect(_pergament, Rect2(r.position / M, r.size / M), true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ein Rand von `dicke` Bildpunkten aus Streifen, aussen nach innen.
func _streifen(r: Rect2, farben: Array) -> void:
    for i in farben.size():
        var innen := r.grow(-M * float(i))
        draw_rect(innen.grow(-M * 0.5), farben[i], false, M)


## **Der Rahmen eines Schirms**: Schatten, Pergament, ein Rand aus vier
## Pixelstreifen (dunkel, Holz, Licht, dunkel) und Beschlaege an den Ecken.
func _rahmen(r: Rect2) -> void:
    r = Rect2((r.position / M).round() * M, (r.size / M).round() * M)
    _flaeche(Rect2(r.position + Vector2(M * 2.0, M * 3.0), r.size),
        Color(TINTE.r, TINTE.g, TINTE.b, 0.35))
    _blatt(r)
    _streifen(r, [RAHMEN_TIEF, RAHMEN, RAHMEN_HELL, RAHMEN_TIEF])
    # Eine feine Linie innen, zwei Bildpunkte vom Rand.
    draw_rect(r.grow(-M * 6.5), Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.35), false, M)
    for ecke in 4:
        _ecke(r, ecke)


const ECKE: PackedStringArray = [
    "nnnnnnn.",
    "nMMMMMn.",
    "nMmmMMnn",
    "nMmxMMn.",
    "nMMMMn..",
    "nMMMn...",
    "nnnn....",
    "..n.....",
]

## Ein Beschlag aus Stahl, zur jeweiligen Ecke gespiegelt.
func _ecke(r: Rect2, welche: int) -> void:
    var zeilen := ECKE
    var rechts := welche == 1 or welche == 3
    var unten := welche >= 2
    if unten:
        var umgekehrt := PackedStringArray()
        for i in range(zeilen.size() - 1, -1, -1):
            umgekehrt.append(zeilen[i])
        zeilen = umgekehrt
    var name := "ecke%d" % welche
    var b := Pixel.bild(name, zeilen, Pixel.grund(), 0, rechts, false, true)
    Pixel.bereit()
    var x := r.position.x - M if not rechts else r.end.x - float(b.size.x - 1) * M
    var y := r.position.y - M if not unten else r.end.y - float(b.size.y - 1) * M
    RenderingServer.canvas_item_add_texture_rect_region(get_canvas_item(),
        Rect2(Vector2(x, y), Vector2(b.size) * M), Pixel.textur().get_rid(), Rect2(b))


## Eine Linie zwischen zwei Zeilen: dunkel mit hellem Strich darunter, wie
## eingeritzt.
func _trenner(r: Rect2, y: float) -> void:
    y = roundf(y / M) * M
    var a := r.position.x + M * 8.0
    var e := r.end.x - M * 8.0
    draw_rect(Rect2(a, y, e - a, M), Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.55))
    draw_rect(Rect2(a, y + M, e - a, M), Color(1.0, 1.0, 1.0, 0.35))


## Der Kopf eines Rahmens: Bild links, Titel, optional Untertitel, und das
## Schliesskreuz rechts, das zurueck zum Titel fuehrt.
func _kopfzeile(r: Rect2, titel: String, bild: Callable, unter := "",
        schliessen := false) -> void:
    bild.call(Vector2(r.position.x + 56.0, r.position.y + 60.0))
    var x := r.position.x + 98.0
    var platz := r.end.x - x - (74.0 if schliessen else 30.0)
    _zeile_eng(titel, Vector2(x, r.position.y + (62.0 if unter != "" else 74.0)), 40,
        TINTE, platz, _kopf)
    if unter != "":
        _zeile_eng(unter, Vector2(x, r.position.y + 92.0), 20,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), platz)
    if schliessen:
        var p := Vector2(r.end.x - 46.0, r.position.y + 48.0)
        _symbol("KREUZ", p, false, M, RAHMEN_TIEF)
        _felder.append({"id": "titel", "r": Rect2(p - Vector2.ONE * 30.0,
            Vector2.ONE * 60.0), "aktiv": true})
    _trenner(r, r.position.y + 118.0)


## **Ein Knopf ist eine Leiste mit Fase**: oben und links Licht, unten und
## rechts Schatten - gedrueckt umgekehrt, und der Inhalt sinkt einen
## Bildpunkt ein. Man sieht, dass er nachgibt, bevor etwas passiert.
func _leiste(id: String, r: Rect2, text: String, aktiv := true,
        bild := Callable()) -> void:
    _felder.append({"id": id, "r": r, "aktiv": aktiv})
    r = Rect2((r.position / M).round() * M, (r.size / M).round() * M)
    var unten := _gedrueckt == id and aktiv
    if not unten:
        _flaeche(Rect2(r.position + Vector2(0.0, M * 2.0), r.size),
            Color(TINTE.r, TINTE.g, TINTE.b, 0.35))
    var tief := Vector2(0.0, M) if unten else Vector2.ZERO
    var k := Rect2(r.position + tief, r.size)
    var grund := BLATT_TIEF if aktiv else BLATT
    if unten:
        grund = grund.darkened(0.08)
    _flaeche(k, grund)
    var licht := Color(1.0, 1.0, 1.0, 0.55)
    var schatten := Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.55)
    var oben_farbe := schatten if unten else licht
    var unten_farbe := licht if unten else schatten
    _flaeche(Rect2(k.position + Vector2(M, M), Vector2(k.size.x - M * 2.0, M)), oben_farbe)
    _flaeche(Rect2(k.position + Vector2(M, M), Vector2(M, k.size.y - M * 2.0)), oben_farbe)
    _flaeche(Rect2(k.position + Vector2(M, k.size.y - M * 2.0),
        Vector2(k.size.x - M * 2.0, M)), unten_farbe)
    _flaeche(Rect2(k.position + Vector2(k.size.x - M * 2.0, M),
        Vector2(M, k.size.y - M * 2.0)), unten_farbe)
    draw_rect(k.grow(-M * 0.5), RAHMEN_TIEF if aktiv else
        Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.5), false, M)
    var farbe := TINTE if aktiv else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.6)
    if bild.is_valid():
        bild.call(Vector2(k.position.x + 36.0, k.position.y + k.size.y * 0.5))
        _mitte_eng(text, Rect2(k.position + Vector2(44.0, 0.0),
            k.size - Vector2(44.0, 0.0)), 26, farbe, _kopf)
    else:
        _mitte_eng(text, k, 26, farbe, _kopf)


func _knopf(id: String, r: Rect2, text: String, aktiv := true,
        bild := Callable()) -> void:
    _leiste(id, r, text, aktiv, bild)


# --- Sprites -----------------------------------------------------------------

## Die Rollen in der Farbe des gewaehlten Helden und Gewands.
func _held_kleid() -> Dictionary:
    var h := Burg.stand.held
    var n := Burg.stand.skin(h)
    return Pixel.kleid(Skins.koerper(h, n), Skins.glanz(h, n))


func _held_schluessel() -> String:
    return "%d_%d" % [Burg.stand.held, Burg.stand.skin(Burg.stand.held)]


## **Ein Symbol** aus `Symbole`, mittig auf `mitte`. `umriss` brennt einen
## Bildpunkt Kante ein (fuer Gegenstaende); Zeichen wie Pfeil und Kreuz sind
## selbst schon Kante. `farbe` faerbt ein Zeichen ein (modulate).
func _symbol(name: String, mitte: Vector2, umriss := true, mass := M,
        farbe := Color.WHITE, kleid := {}, schluessel := "") -> void:
    var zeilen: PackedStringArray = (Symbole as Script).get_script_constant_map()[name]
    if kleid.is_empty():
        kleid = _held_kleid()
        schluessel = _held_schluessel()
    var b := Pixel.bild("sym_%s_%s" % [name, schluessel], zeilen, kleid, 0, false, false,
        umriss)
    Pixel.bereit()
    var oben_links := (mitte - Vector2(b.size) * mass * 0.5).round()
    RenderingServer.canvas_item_add_texture_rect_region(get_canvas_item(),
        Rect2(oben_links, Vector2(b.size) * mass), Pixel.textur().get_rid(), Rect2(b), farbe)


func _symbol_waffe(w: int) -> String:
    return ["SCHWERT", "SPEER", "FLEGEL", "ARMBRUST", "HAMMER", "AXT"][clampi(w, 0, 5)]


func _symbol_zug(z: int) -> String:
    return ["RUESTUNG", "STIEFEL", "WETZSTEIN", "LATERNE", "ZEHRUNG", ""][clampi(z, 0, 5)]


func _symbol_bau(b: int) -> String:
    return ["MAUER", "SCHMIEDE", "STALL", "MUENZEN"][clampi(b, 0, 3)]


func _symbol_stueck(s: int) -> String:
    return ["KESSELHAUBE", "VISIERHELM", "RUESTUNG", "PLATTENROCK", "SIEGELRING",
        "BLUTSTEIN", "REISEMANTEL", "BANNERTUCH"][clampi(s, 0, 7)]


## **Eine Figur im Menue**: dasselbe Sprite wie im Feld, mit eingebranntem
## Umriss, `mass`-fach. `fuss` ist die Fussmitte auf dem Schirm.
func _figur(name: String, zeilen: PackedStringArray, kleid: Dictionary, anker: int,
        fuss: Vector2, mass := M, spiegel := false, modul := Color.WHITE) -> void:
    var b := Pixel.bild(name, zeilen, kleid, anker, spiegel, false, true)
    Pixel.bereit()
    var a := Pixel.anker(name, spiegel, false, true)
    Pixel.setze_schirm(get_canvas_item(), b, a, fuss.round(), mass, modul)


## Ein Held im Menue, mit Arm und Waffe als Pixellinie wie im Feld.
func _held_bild(klasse: int, fuss: Vector2, mass: float, winkel: float,
        kleid: Dictionary, schluessel: String, schatten := true) -> void:
    if schatten:
        _figur("schatten14", Figuren.schatten(14), Pixel.grund(), 7,
            fuss + Vector2(0.0, mass * 2.0), mass)
    _figur("mheld%d_%s" % [klasse, schluessel], Figuren.held(klasse, -1), kleid,
        Figuren.BEIN_ANKER, fuss, mass)
    var schulter := fuss + Vector2(Figuren.HELD_SCHULTER) * mass
    var r := Vector2(cos(winkel), sin(winkel))
    var q := r.orthogonal()
    var hand := schulter + r * 5.0 * mass
    _linie(schulter, hand, kleid["c"], 2, mass)
    match klasse:
        1:
            var vorn := hand + r * 6.0 * mass
            _linie(hand - r * 2.0 * mass, vorn, Palette.HOLZ, 2, mass)
            _linie(vorn - q * 4.0 * mass, vorn + q * 4.0 * mass, Palette.STAHL, 1, mass)
        2:
            _linie(hand - r * 6.0 * mass, hand + r * 15.0 * mass, Palette.HOLZ_HELL, 1, mass)
            _linie(hand + r * 14.0 * mass, hand + r * 18.0 * mass, Palette.STAHL_HELL, 2, mass)
        3:
            var kopf := hand + r * 9.0 * mass
            _linie(hand, kopf, Palette.HOLZ, 2, mass)
            _linie(kopf - q * 3.0 * mass, kopf + q * 3.0 * mass, Palette.STAHL, 3, mass)
        _:
            _linie(hand, hand + r * 10.0 * mass, Palette.STAHL_HELL, 2, mass)
            _linie(hand - q * 2.0 * mass, hand + q * 2.0 * mass, Palette.STAHL_TIEF, 1, mass)
    _flaeche(Rect2((hand / mass).floor() * mass, Vector2.ONE * mass * 2.0), Palette.HAUT)


## Eine Linie aus Bildpunkten der Groesse `mass` (Bresenham).
func _linie(a: Vector2, b: Vector2, farbe: Color, dicke: int, mass := M) -> void:
    var p0 := Vector2i((a / mass).round())
    var p1 := Vector2i((b / mass).round())
    var dx := absi(p1.x - p0.x)
    var dy := -absi(p1.y - p0.y)
    var sx := 1 if p0.x < p1.x else -1
    var sy := 1 if p0.y < p1.y else -1
    var fehler := dx + dy
    var p := p0
    var versatz := Vector2.ONE * float(dicke / 2)
    for i in 256:
        draw_rect(Rect2((Vector2(p) - versatz) * mass, Vector2.ONE * mass * float(dicke)), farbe)
        if p == p1:
            break
        var e2 := 2 * fehler
        if e2 >= dy:
            fehler += dy
            p.x += sx
        if e2 <= dx:
            fehler += dx
            p.y += sy


## Ein Balken im Pixelraster: dunkler Rand, Grund, Fuellung, Glanzlinie.
func _balken(r: Rect2, anteil: float, farbe: Color) -> void:
    r = Rect2((r.position / M).round() * M, (r.size / M).round() * M)
    _flaeche(r, RAHMEN_TIEF)
    var innen := r.grow(-M)
    _flaeche(innen, Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.55))
    var b := roundf(innen.size.x * clampf(anteil, 0.0, 1.0) / M) * M
    if b > 0.0:
        _flaeche(Rect2(innen.position, Vector2(b, innen.size.y)), farbe)
        _flaeche(Rect2(innen.position, Vector2(b, M)), farbe.lightened(0.3))


## Das Wappen in der Farbe des gewaehlten Helden und Gewands.
func _wappen(ort: Vector2, mass := M) -> void:
    _symbol("WAPPEN", ort, true, mass)


# --- Schrift --------------------------------------------------------------

func _mitte(text: String, r: Rect2, groesse: int, farbe: Color,
        schrift: Font = null) -> void:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
    _worte.append({"f": f, "wo": Vector2(r.position.x + (r.size.x - w) * 0.5,
        r.position.y + r.size.y * 0.5 + groesse * 0.36), "text": text,
        "groesse": groesse, "farbe": farbe})


## Mittig wie `_mitte`, und kleiner, bis der Satz mit Rand hineingeht - aus
## demselben Grund wie `_zeile_eng`.
func _mitte_eng(text: String, r: Rect2, groesse: int, farbe: Color,
        schrift: Font = null) -> void:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    var g := groesse
    while g > KLEINSTE and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
            -1, g).x > r.size.x - 52.0:
        g -= 1
    _mitte(text, r, g, farbe, f)


func _zeile(text: String, wo: Vector2, groesse: int, farbe: Color,
        schrift: Font = null) -> void:
    _worte.append({"f": schrift if schrift != null else ThemeDB.fallback_font,
        "wo": wo, "text": text, "groesse": groesse, "farbe": farbe})


## Wie breit ein Text in einer Schrift steht.
func _breite(text: String, groesse: int, schrift: Font = null) -> float:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x


## Eine Zeile, die **in ihre Tafel passt**.
##
## Der erste Anlauf setzte den Satz des Bogenschuetzen in fester Groesse auf
## die Karte: er lief ueber den Rand der Tafel hinaus und rechts aus dem
## Bild. Eine Beschriftung, die breiter ist als das, was sie beschriftet,
## ist keine Beschriftung.
##
## Gekuerzt wird nicht - ein abgeschnittener Satz sagt weniger als ein
## kleinerer. Die Groesse faellt, bis er hineingeht, und nicht unter
## `KLEINSTE`: darunter liest ihn auf einem Telefon niemand mehr.
const KLEINSTE := 15

func _zeile_eng(text: String, wo: Vector2, groesse: int, farbe: Color,
        breite: float, schrift: Font = null) -> void:
    var f := schrift if schrift != null else ThemeDB.fallback_font
    var g := groesse
    while g > KLEINSTE and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
            -1, g).x > breite:
        g -= 1
    _worte.append({"f": f, "wo": wo, "text": text, "groesse": g,
        "farbe": farbe})


## Wie viel Luft ueber einem Block steht, damit er **mittig** im Bild sitzt.
##
## Die Schirme waren von oben her gesetzt. Auf einem 20:9-Telefon
## (720 x 1600) stand alles im oberen Drittel und darunter ein leeres
## Viertel Pergament - das sieht nicht nach Absicht aus, sondern nach einem
## Entwurf fuer ein anderes Geraet. Wird es eng, ist die Luft null und der
## Block klebt wieder oben; ueber den Rand schiebt ihn nichts.
func _luft(hoehe: float) -> float:
    return maxf(0.0, (size.y - _rand() * 2.0 - hoehe) * 0.5)


# --- Das Bild --------------------------------------------------------------

func _draw() -> void:
    _felder.clear()
    _worte.clear()
    if _lauf == null:
        return
    match _lauf.lage:
        0:
            _titel()
        1:
            if _lauf.marke:
                _marke()
            else:
                _im_lauf()
        2:
            _ende()
        3:
            _burg()
        4:
            _zeug()
    # **Im Lauf bekommt die Schrift eine Kante.** Sie steht dort nicht auf
    # einer Tafel, sondern direkt ueber dem Gedraenge.
    var kante: bool = _lauf.lage == 1
    for w in _worte:
        if kante:
            draw_string_outline(w["f"], w["wo"], w["text"],
                HORIZONTAL_ALIGNMENT_LEFT, -1, w["groesse"],
                maxi(4, int(w["groesse"]) / 5),
                Color(HELL.r, HELL.g, HELL.b, 0.85))
        draw_string(w["f"], w["wo"], w["text"], HORIZONTAL_ALIGNMENT_LEFT,
            -1, w["groesse"], w["farbe"])


const TITEL_ZEILE := 114.0

func _titel() -> void:
    var b := size.x
    var s := Burg.stand
    var zeilen := Helden.NAMEN.size()
    var hoch := 124.0 + float(zeilen) * TITEL_ZEILE + 100.0
    var oben := _rand() + _luft(SZENE + hoch + 50.0)
    _szene(Vector2(b * 0.5, oben + SZENE - 18.0), b)
    var r := Rect2(24.0, oben + SZENE, b - 48.0, hoch)
    _rahmen(r)
    _kopfzeile(r, "TEN THOUSAND", func(p): _wappen(p),
        "One blade. Ten thousand of them.")

    var y := r.position.y + 122.0
    for h in zeilen:
        var frei := Helden.ist_frei(h, s.beste_zeit, s.meiste_erschlagen,
            s.warlord_gefallen)
        var zeile := Rect2(r.position.x, y, r.size.x - 14.0, TITEL_ZEILE)
        # **Jede Zeile zeigt ihren Helden** - in seiner Klasse und dem
        # gewaehlten Gewand. Ein gesperrter steht als Schatten da: man sieht,
        # was kommt, aber nicht, wie es aussieht.
        var n := s.skin(h)
        var kleid := Pixel.kleid(Skins.koerper(h, n), Skins.glanz(h, n))
        var schluessel := "%d_%d" % [h, n]
        var fuss := Vector2(r.position.x + 58.0, y + TITEL_ZEILE - 14.0)
        if frei:
            _held_bild(h, fuss, M, -0.7, kleid, schluessel)
        else:
            _figur("mheld%d_%s" % [h, schluessel], Figuren.held(h, -1), kleid,
                Figuren.BEIN_ANKER, fuss, M, false, Color(0.15, 0.12, 0.10, 0.55))
        var x := r.position.x + 112.0
        _zeile(Helden.name_von(h), Vector2(x, y + 38.0), 28,
            TINTE if frei else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.6), _kopf)
        var satz := Helden.lehre_von(h) if frei else Helden.bedingung_text(h)
        # **Zwei Saetze, zwei Zeilen**, und beide hoeren vor den Gewaendern
        # auf: eine Beschriftung unter einem Knopf ist keine Beschriftung.
        var platz := zeile.end.x - x - 16.0 - (150.0 if frei else 0.0)
        var farbe := Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95 if frei else 0.6)
        var teil := satz.find(". ")
        if teil > 0:
            _zeile_eng(satz.substr(0, teil + 1), Vector2(x, y + 64.0), 19, farbe, platz)
            _zeile_eng(satz.substr(teil + 2), Vector2(x, y + 86.0), 19, farbe, platz)
        else:
            _zeile_eng(satz, Vector2(x, y + 70.0), 19, farbe, platz)
        if frei:
            # **Die Zeile hoert vor den Punkten auf.** Der Treffer nimmt das
            # erste Feld, das passt; laege sie darueber, startete jeder Tipp
            # auf ein Gewand sofort einen Lauf.
            _felder.append({"id": "held%d" % h,
                "r": Rect2(zeile.position, Vector2(zeile.size.x - 156.0, zeile.size.y)),
                "aktiv": true})
            _gewaender(h, zeile)
        y += TITEL_ZEILE
        if h < zeilen - 1:
            _trenner(r, y)

    var halb := (r.size.x - 66.0) * 0.5
    var yk := y + 12.0
    _knopf("burg", Rect2(r.position.x + 24.0, yk, halb, 60.0), "KEEP", true,
        func(p): _symbol("MAUER", p, true, 2.0))
    _knopf("zeug", Rect2(r.position.x + 42.0 + halb, yk, halb, 60.0), "GEAR", true,
        func(p): _symbol("VISIERHELM", p, true, 2.0))
    if s.etwas_zu_holen():
        _flaeche(Rect2(r.position.x + 24.0 + halb - 18.0, yk - 6.0, 18.0, 18.0), RAHMEN_TIEF)
        _flaeche(Rect2(r.position.x + 24.0 + halb - 15.0, yk - 3.0, 12.0, 12.0), Palette.HELD)
    if s.laeufe > 0:
        var z := "best %d:%02d   /   %d felled   /   %d coin" % [
            int(s.beste_zeit) / 60, int(s.beste_zeit) % 60,
            s.meiste_erschlagen, s.sold]
        var zw := _breite(z, 26, _zahl)
        _zeile(z, Vector2((b - zw) * 0.5, r.end.y + 44.0), 26,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.85), _zahl)


## Wie hoch die Szene ueber dem Titel steht.
const SZENE := 190.0

## **Einer gegen die Horde - als Bild, bevor man es liest.** Der Held in der
## Mitte, die Sorten von beiden Seiten auf ihn zu, mit denselben Sprites wie
## im Feld. Die Reihenfolge ist fest: der Titel ist kein Gefecht.
const SZENE_REIHE := [
    [-300.0, Feinde.Art.SPIESSER], [-240.0, Feinde.Art.STROLCH],
    [-185.0, Feinde.Art.WOLF], [-120.0, Feinde.Art.RITTER],
    [300.0, Feinde.Art.ARMBRUSTER], [240.0, Feinde.Art.TREIBER],
    [180.0, Feinde.Art.STROLCH], [118.0, Feinde.Art.WOLF],
]

func _szene(boden: Vector2, b: float) -> void:
    var mass := M
    for e in SZENE_REIHE:
        var x: float = e[0] * minf(1.0, b / 720.0)
        var art: int = e[1]
        var f := boden + Vector2(x, absf(x) * 0.02)
        _figur("schatten12", Figuren.schatten(12), Pixel.grund(), 6,
            f + Vector2(0.0, mass * 2.0), mass)
        _figur("mf%d" % art, Figuren.feind(art, 0), Pixel.kleid(Palette.sorte(art)),
            Figuren.anker(art), f, mass, x > 0.0)
    _held_bild(Burg.stand.held, boden + Vector2(0.0, 8.0), 4.0, -1.0, _held_kleid(),
        _held_schluessel())


## Die drei Gewaender am rechten Rand einer Heldenzeile: Farbfelder im
## Pixelraster, das getragene mit dunklem Reif.
func _gewaender(h: int, karte: Rect2) -> void:
    var s := Burg.stand
    var gewaehlt := s.skin(h)
    for n in Skins.JE_HELD:
        var mitte := Vector2(karte.end.x - 30.0 - float(Skins.JE_HELD - 1 - n) * 46.0,
            karte.position.y + karte.size.y * 0.5)
        var frei := Skins.ist_frei(h, n, s.beste_zeit, s.meiste_erschlagen,
            s.warlord_gefallen)
        var feld := Rect2(((mitte - Vector2.ONE * 15.0) / M).round() * M, Vector2.ONE * 30.0)
        if n == gewaehlt:
            _flaeche(feld.grow(M * 2.0), RAHMEN_TIEF)
            _flaeche(feld.grow(M), HELL)
        _flaeche(feld, RAHMEN_TIEF)
        var farbe := Skins.koerper(h, n) if frei else BLATT_TIEF
        _flaeche(feld.grow(-M), farbe)
        if frei:
            _flaeche(Rect2(feld.position + Vector2(M, M), Vector2(feld.size.x - M * 2.0, M)),
                farbe.lightened(0.35))
            _felder.append({"id": "skin%d_%d" % [h, n],
                "r": Rect2(mitte - Vector2.ONE * 23.0, Vector2.ONE * 46.0),
                "aktiv": true})


func _im_lauf() -> void:
    var st: Gefecht.Stand = _lauf.stand()
    if st == null:
        return
    var b := size.x
    var oben := _rand()

    # **Ein Treffer faerbt den Bildrand.** Kurz und blass in Zinnober, an allen
    # vier Kanten: Schaden am Spieler.
    var wunde: float = _lauf.wunde()
    if wunde > 0.0:
        var h := size.y
        for k in 4:
            var c := Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.32 * wunde * (1.0 - float(k) * 0.25))
            var d := float(k) * 12.0
            _flaeche(Rect2(0.0, d, b, 12.0), c)
            _flaeche(Rect2(0.0, h - d - 12.0, b, 12.0), c)
            _flaeche(Rect2(d, 0.0, 12.0, h), c)
            _flaeche(Rect2(b - d - 12.0, 0.0, 12.0, h), c)

    # **Das Leben ist die lauteste Anzeige**, denn es ist der einzige Grund,
    # warum ein Lauf endet. Links davor das Wappen: die Fahne, unter der man
    # kaempft.
    _balken(Rect2(66.0, oben + 12.0, b - 92.0, 24.0),
        st.leben / maxf(1.0, st.leben_voll), ZINNOBER)
    _wappen(Vector2(36.0, oben + 30.0))
    # Erfahrung darunter, schmaler: sie endet nichts, sie verspricht nur.
    var noetig := float(Gunst.stufenkosten(st.stufe))
    _balken(Rect2(66.0, oben + 42.0, b - 92.0, 12.0),
        float(st.erfahrung) / maxf(1.0, noetig), Palette.ERFAHRUNG)

    var m := int(st.zeit) / 60
    var sek := int(st.zeit) % 60
    _zeile("%d:%02d" % [m, sek], Vector2(26.0, oben + 100.0), 42, TINTE, _zahl)
    var lv := "LV %d" % st.stufe
    _zeile(lv, Vector2(b - 26.0 - _breite(lv, 32, _kopf), oben + 98.0), 32,
        TINTE, _kopf)
    _symbol("SCHAEDEL", Vector2(40.0, oben + 126.0), true, 2.0)
    _zeile("%d" % st.erschlagen, Vector2(62.0, oben + 136.0), 28,
        Color(TINTE.r, TINTE.g, TINTE.b, 0.9), _zahl)
    var sold := "%d" % st.sold
    var sw := _breite(sold, 28, _zahl)
    _symbol("MUENZE", Vector2(b - 26.0 - sw - 18.0, oben + 126.0), true, 2.0)
    _zeile(sold, Vector2(b - 26.0 - sw, oben + 136.0), 28,
        Color(GOLD.r, GOLD.g, GOLD.b, 0.95), _zahl)

    if st.wartet_auf_wahl:
        _aufstieg(st)
        return

    # **Der erste Lauf erklaert sich, einmal** (Zusicherung 27).
    var hin: float = _lauf.hinweis()
    if hin > 0.0:
        var y := size.y * 0.70
        _mitte_eng("Drag anywhere to move.", Rect2(0.0, y, b, 40.0), 30,
            Color(TINTE.r, TINTE.g, TINTE.b, hin))
        _mitte_eng("Your weapons strike on their own.",
            Rect2(0.0, y + 42.0, b, 34.0), 24,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, hin))

    # Der Stick wird gezeichnet, wo der Daumen ihn aufgesetzt hat: ein Ring
    # aus Bildpunkten und ein Knauf.
    if _lauf.zieht():
        var von: Vector2 = _lauf.stick_von()
        var jetzt: Vector2 = _lauf.stick_jetzt()
        var ring := Color(TINTE.r, TINTE.g, TINTE.b, 0.30)
        for k in 24:
            var w := TAU * float(k) / 24.0
            _flaeche(Rect2(((von + Vector2(cos(w), sin(w)) * 72.0) / M).round() * M,
                Vector2.ONE * M * 2.0), ring)
        var d := jetzt - von
        var kopf := von + d.limit_length(72.0)
        _flaeche(Rect2(((kopf - Vector2.ONE * 15.0) / M).round() * M, Vector2.ONE * 30.0),
            Color(TINTE.r, TINTE.g, TINTE.b, 0.40))


## **Der Name ueber dem Gefecht** - nur fuer das Feature-Bild des Ladens.
## Oben und nicht in der Mitte: dort steht der Held.
func _marke() -> void:
    var b := size.x
    var h := size.y
    var t := "TEN THOUSAND"
    var gross := int(minf(b * 0.085, h * 0.16))
    var w := _breite(t, gross, _kopf)
    var u := "One blade. Ten thousand of them."
    var klein := int(gross * 0.42)
    var uw := _breite(u, klein)
    var mitte := h * 0.2
    _rahmen(Rect2((b - w) * 0.5 - gross * 0.7, mitte - gross * 1.15,
        w + gross * 1.4, gross * 2.2))
    _zeile(t, Vector2((b - w) * 0.5, mitte + gross * 0.12), gross, TINTE, _kopf)
    _zeile(u, Vector2((b - uw) * 0.5, mitte + gross * 0.86), klein,
        Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))


## **Der Aufstieg ist ein Banner**: es haengt an einer Stange, traegt die
## drei Angebote untereinander und laeuft unten in eine Spitze aus, ueber der
## eine Burg in den Farben des Helden steht.
const WAHL_ZEILE := 124.0

func _aufstieg(st: Gefecht.Stand) -> void:
    var b := size.x
    var h := size.y
    _flaeche(Rect2(0.0, 0.0, b, h), Color(HELL.r, HELL.g, HELL.b, 0.50))
    var zahl := st.angebote.size()
    var koerper := 96.0 + float(zahl) * WAHL_ZEILE + 196.0
    var spitze := 84.0
    var oben := _rand() + 156.0 + maxf(0.0, (h - _rand() * 2.0 - 156.0
        - koerper - spitze) * 0.35)
    var r := Rect2(((Vector2(40.0, oben)) / M).round() * M,
        (Vector2(b - 80.0, koerper) / M).round() * M)
    var mitte := r.position.x + r.size.x * 0.5
    var unten := Vector2(mitte, r.end.y + spitze)
    # Schatten, Tuch mit Spitze, Rand den Umriss entlang.
    var umriss := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
        r.end, unten, Vector2(r.position.x, r.end.y)])
    var schatten := PackedVector2Array()
    for p in umriss:
        schatten.append(p + Vector2(M * 2.0, M * 3.0))
    draw_colored_polygon(schatten, Color(TINTE.r, TINTE.g, TINTE.b, 0.35))
    draw_colored_polygon(umriss, BLATT)
    _blatt(r)
    for i in umriss.size():
        var a := umriss[i]
        var e := umriss[(i + 1) % umriss.size()]
        _linie(a, e, RAHMEN_TIEF, 2, M)
    for i in umriss.size():
        var a := umriss[i]
        var e := umriss[(i + 1) % umriss.size()]
        var innen := (Vector2(mitte, r.position.y + r.size.y * 0.5) - (a + e) * 0.5).normalized() * M * 3.0
        _linie(a + innen, e + innen, Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.45), 1, M)
    # Die Stange, an der es haengt, mit Knaeufen.
    _flaeche(Rect2(r.position.x - 24.0, r.position.y - M * 3.0, r.size.x + 48.0, M * 3.0),
        Palette.HOLZ)
    _flaeche(Rect2(r.position.x - 24.0, r.position.y - M * 3.0, r.size.x + 48.0, M),
        Palette.HOLZ_HELL)
    for x in [r.position.x - 30.0, r.end.x + 18.0]:
        _flaeche(Rect2(x, r.position.y - M * 5.0, M * 4.0, M * 6.0), RAHMEN_TIEF)
        _flaeche(Rect2(x + M, r.position.y - M * 4.0, M * 2.0, M * 4.0), Palette.HOLZ_HELL)

    var t := "CHOOSE"
    _zeile(t, Vector2(mitte - _breite(t, 42, _kopf) * 0.5, r.position.y + 68.0), 42,
        TINTE, _kopf)
    var y := r.position.y + 96.0
    _trenner(r, y)
    for i in zahl:
        var a = st.angebote[i]
        var zeile := Rect2(r.position.x, y, r.size.x, WAHL_ZEILE)
        var bild := Vector2(r.position.x + 58.0, y + WAHL_ZEILE * 0.5)
        _symbol_feld(bild)
        if a.ist_waffe:
            _symbol(_symbol_waffe(a.was), bild)
        elif a.was == Gunst.Zug.GEFAEHRTE:
            _figur("mgef_%s" % _held_schluessel(), Figuren.gefaehrte(0), _held_kleid(),
                Figuren.GEFAEHRTE_ANKER, bild + Vector2(0.0, 22.0), M)
        else:
            _symbol(_symbol_zug(a.was), bild)
        var x := r.position.x + 112.0
        _zeile(a.name(), Vector2(x, y + 44.0), 28, TINTE, _kopf)
        # **Stufen als Kaestchen.** Eine Zahl sagt, wo man steht; Kaestchen
        # sagen auch, wie weit es noch geht. Das neue in der Farbe des Helden.
        var hoechst := Waffen.HOECHSTSTUFE if a.ist_waffe else Gunst.ZUG_HOECHSTSTUFE
        for k in hoechst:
            var p := Vector2(r.end.x - 42.0 - float(hoechst - 1 - k) * 24.0, y + 22.0)
            var feld := Rect2((p / M).round() * M, Vector2.ONE * M * 6.0)
            _flaeche(feld, RAHMEN_TIEF)
            if k + 1 < a.stufe:
                _flaeche(feld.grow(-M), RAHMEN_HELL)
            elif k + 1 == a.stufe:
                _flaeche(feld.grow(-M), Palette.HELD)
            else:
                _flaeche(feld.grow(-M), BLATT_TIEF)
        if a.neu:
            _zeile("NEW", Vector2(r.end.x - 42.0 - float(hoechst - 1) * 24.0,
                y + 70.0), 18, Palette.HELD.darkened(0.35), _kopf)
        _zeile_eng(a.lehre(), Vector2(x, y + 94.0), 20,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.98), r.end.x - x - 20.0)
        _felder.append({"id": "wahl%d" % i, "r": zeile, "aktiv": true})
        if _gedrueckt == "wahl%d" % i:
            _flaeche(zeile.grow(-M * 4.0), Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.12))
        y += WAHL_ZEILE
        _trenner(r, y)
    _symbol("BURG", Vector2(mitte, y + 112.0), true, 5.0, Color.WHITE, _held_kleid(),
        _held_schluessel())


## Der Grund unter einem Symbol: ein dunkler gerahmtes Feld.
func _symbol_feld(mitte: Vector2) -> void:
    var r := Rect2(((mitte - Vector2.ONE * 33.0) / M).round() * M, Vector2.ONE * 66.0)
    _flaeche(r, RAHMEN_TIEF)
    _flaeche(r.grow(-M), BLATT_TIEF)
    _flaeche(Rect2(r.position + Vector2(M, M), Vector2(r.size.x - M * 2.0, M)),
        Color(1.0, 1.0, 1.0, 0.45))


## **Der Bericht hat ein Bild.** Gewonnen: der Held steht ueber dem
## gefallenen Warlord. Gefallen: die Horde steht, und vor ihr liegt die
## Waffe. Darunter das Blatt mit den Zahlen, darunter zwei Wege.
const BERICHT_BILD := 230.0
const BERICHT_TAFEL := 400.0

func _ende() -> void:
    var st: Gefecht.Stand = _lauf.stand()
    var b := size.x
    var gewonnen: bool = st != null and st.warlord_gefallen
    var oben := _rand() + _luft(BERICHT_BILD + BERICHT_TAFEL + 200.0)
    _bericht_bild(Vector2(b * 0.5, oben + BERICHT_BILD - 24.0), gewonnen,
        st.held if st != null else 0)
    var r := Rect2(b * 0.10, oben + BERICHT_BILD, b * 0.80, BERICHT_TAFEL)
    _rahmen(r)
    var kopf := "THE FIELD IS YOURS" if gewonnen else "YOU FALL"
    _mitte_eng(kopf, Rect2(r.position.x, r.position.y + 30.0, r.size.x, 60.0), 40,
        TINTE if gewonnen else ZINNOBER, _kopf)
    _trenner(r, r.position.y + 100.0)
    if st != null:
        var zeilen := [
            ["lasted", "%d:%02d" % [int(st.zeit) / 60, int(st.zeit) % 60]],
            ["slain", "%d" % st.erschlagen],
            ["coin", "%d" % st.sold],
            ["level", "%d" % st.stufe],
        ]
        var y := r.position.y + 150.0
        var achse := r.position.x + r.size.x * 0.5
        for z in zeilen:
            # Name links, Zahl rechts an einer Mittelachse.
            var nw := _breite(z[0], 26)
            _zeile(z[0], Vector2(achse - 14.0 - nw, y), 26,
                Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95))
            _zeile(z[1], Vector2(achse + 14.0, y + 2.0), 34,
                GOLD if z[0] == "coin" else Color(TINTE.r, TINTE.g, TINTE.b, 0.92),
                _zahl)
            y += 44.0
        var fu: int = _lauf.fund()
        if fu >= 0:
            _trenner(r, y - 18.0)
            var ft := "found  %s  %d" % [Ausruestung.name_von(fu), _lauf.fund_stufe()]
            var fw := _breite(ft, 26)
            var fx := r.position.x + (r.size.x - fw) * 0.5 + 22.0
            _symbol(_symbol_stueck(fu), Vector2(fx - 30.0, y + 14.0), true, 2.0)
            _zeile(ft, Vector2(fx, y + 24.0), 26, TINTE)
    # **Kein Angebot nach einer Niederlage.** Zwei Wege, nie mehr.
    var yk := r.end.y + 30.0
    _knopf("nochmal", Rect2(b * 0.14, yk, b * 0.72, 78.0), "AGAIN", true,
        func(p): _symbol("NOCHMAL", p, false, M, RAHMEN_TIEF))
    _knopf("titel", Rect2(b * 0.14, yk + 96.0, b * 0.72, 66.0), "BACK", true,
        func(p): _symbol("ZURUECK", p, false, M, RAHMEN_TIEF))


func _bericht_bild(boden: Vector2, gewonnen: bool, held: int) -> void:
    var kleid := _held_kleid()
    var schluessel := _held_schluessel()
    if gewonnen:
        var kw := Pixel.kleid(Palette.sorte(Feinde.Art.WARLORD))
        _figur("mliegt_w", Figuren.liegend(Figuren.feind(Feinde.Art.WARLORD, -1)), kw,
            16, boden + Vector2(70.0, 6.0), 4.0, true)
        _held_bild(held, boden + Vector2(-80.0, 6.0), 5.0, -1.35, kleid, schluessel)
    else:
        var reihe := [[-150.0, Feinde.Art.STROLCH], [-80.0, Feinde.Art.RITTER],
            [80.0, Feinde.Art.SPIESSER], [150.0, Feinde.Art.STROLCH]]
        for e in reihe:
            var art: int = e[1]
            var x: float = e[0]
            var f := boden + Vector2(x, 0.0)
            _figur("schatten12", Figuren.schatten(12), Pixel.grund(), 6,
                f + Vector2(0.0, 8.0), 4.0)
            _figur("mf%d" % art, Figuren.feind(art, -1), Pixel.kleid(Palette.sorte(art)),
                Figuren.anker(art), f, 4.0, x > 0.0)
        _symbol(_symbol_waffe(Helden.startwaffe(held)), boden + Vector2(0.0, -14.0), true, 4.0)


const BURG_ZEILE := 138.0

func _burg() -> void:
    var b := size.x
    var s := Burg.stand
    var hoch := 122.0 + float(Halle.NAMEN.size()) * BURG_ZEILE + 172.0
    var oben := _rand() + _luft(hoch)
    var r := Rect2(24.0, oben, b - 48.0, hoch)
    _rahmen(r)
    _kopfzeile(r, "THE KEEP", func(p): _symbol("MAUER", p, true, M), "", true)
    var e := "%d" % s.sold
    var ew := _breite(e, 34, _zahl)
    _zeile(e, Vector2(r.end.x - 90.0 - ew, r.position.y + 72.0), 34, GOLD, _zahl)
    _symbol("MUENZE", Vector2(r.end.x - 90.0 - ew - 22.0, r.position.y + 60.0), true, 2.0)

    var y := r.position.y + 122.0
    for bau in Halle.NAMEN.size():
        var stufe := s.stufe(bau)
        var voll := stufe >= Halle.HOECHSTSTUFE
        var bild := Vector2(r.position.x + 62.0, y + BURG_ZEILE * 0.5)
        _symbol_feld(bild)
        _symbol(_symbol_bau(bau), bild)
        var x := r.position.x + 118.0
        _zeile(Halle.name_von(bau), Vector2(x, y + 42.0), 30, TINTE, _kopf)
        var nw := _breite(Halle.name_von(bau), 30, _kopf)
        _zeile("%d" % stufe, Vector2(x + nw + 12.0, y + 42.0), 30,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), _zahl)
        _zeile_eng(Halle.beschreibung_von(bau), Vector2(x, y + 74.0), 20,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), r.end.x - x - 24.0)
        _balken(Rect2(x, y + 94.0, r.end.x - x - 204.0, 12.0),
            float(stufe) / float(Halle.HOECHSTSTUFE), RAHMEN_HELL)
        _knopf("bau%d" % bau, Rect2(r.end.x - 176.0, y + 80.0, 150.0, 48.0),
            "MAX" if voll else "%d" % s.kosten(bau), s.kann_bauen(bau))
        y += BURG_ZEILE
        _trenner(r, y)
    # **Ton und Beben lassen sich abschalten.** Die Datenschutzerklaerung
    # verspricht den Schalter, und er steht in der Burg, weil sie der einzige
    # Schirm ist, der ohnehin Einstellungen am Spieler vornimmt.
    var halb := (r.size.x - 66.0) * 0.5
    var laut := s.laut > 0.001
    _knopf("ton", Rect2(r.position.x + 24.0, y + 18.0, halb, 58.0),
        "SOUND ON" if laut else "SOUND OFF", true,
        func(p): _symbol("LAUT" if laut else "STUMM", p, false, M, RAHMEN_TIEF))
    _knopf("beben", Rect2(r.position.x + 42.0 + halb, y + 18.0, halb, 58.0),
        "RUMBLE ON" if s.beben else "RUMBLE OFF", true,
        func(p): _symbol("RUETTEL", p, false, M,
            RAHMEN_TIEF if s.beben else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.5)))
    _knopf("titel", Rect2(r.position.x + r.size.x * 0.25, y + 92.0, r.size.x * 0.5, 58.0),
        "BACK", true, func(p): _symbol("ZURUECK", p, false, M, RAHMEN_TIEF))


const ZEUG_ZEILE := 120.0

func _zeug() -> void:
    var b := size.x
    var s := Burg.stand
    var plaetze := Ausruestung.PLATZ_NAMEN.size()
    var hoch := 122.0 + float(plaetze) * ZEUG_ZEILE + 104.0
    var oben := _rand() + _luft(hoch)
    var r := Rect2(24.0, oben, b - 48.0, hoch)
    _rahmen(r)
    _kopfzeile(r, "WHAT YOU CARRY", func(p): _symbol("VISIERHELM", p, true, M), "", true)

    var y := r.position.y + 122.0
    var zelle := (r.size.x - 156.0) * 0.5
    for platz in plaetze:
        _zeile(Ausruestung.platz_name(platz), Vector2(r.position.x + 28.0, y + 66.0), 22,
            Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.95), _kopf)
        var x := r.position.x + 110.0
        var getragen := int(s.angelegt.get(platz, -1))
        for stueck in Ausruestung.Stueck.size():
            if Ausruestung.platz_von(stueck) != platz:
                continue
            var stufe := int(s.besitz.get(stueck, 0))
            var hat := stufe > 0
            var z := Rect2(((Vector2(x, y + 12.0)) / M).round() * M,
                (Vector2(zelle, ZEUG_ZEILE - 24.0) / M).round() * M)
            var traegt := stueck == getragen
            _flaeche(z, RAHMEN_TIEF if (hat and traegt) else Color(RAHMEN.r, RAHMEN.g, RAHMEN.b, 0.55 if hat else 0.25))
            _flaeche(z.grow(-M * (2.0 if traegt else 1.0)), BLATT_TIEF if hat else BLATT)
            # Das Stueck als Bild. Ein nicht gefundenes steht als blasser
            # Schatten da: man weiss, dass es etwas gibt, aber nicht, was es kann.
            var bild := Vector2(z.position.x + 40.0, z.position.y + z.size.y * 0.5)
            _symbol(_symbol_stueck(stueck), bild, true, M,
                Color.WHITE if hat else Color(0.55, 0.50, 0.45, 0.35))
            var tx := z.position.x + 78.0
            _zeile_eng(Ausruestung.name_von(stueck), Vector2(tx, z.position.y + 36.0), 20,
                TINTE if hat else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.45),
                z.end.x - tx - 10.0, _kopf)
            _zeile_eng(Ausruestung.lehre_von(stueck, stufe) if hat else "not found",
                Vector2(tx, z.position.y + 64.0), 18,
                Color(TINTE.r, TINTE.g, TINTE.b, 0.8) if hat
                    else Color(SEPIA.r, SEPIA.g, SEPIA.b, 0.4),
                z.end.x - tx - 10.0)
            if hat:
                _felder.append({"id": "lege%d" % stueck, "r": z, "aktiv": true})
            x += zelle + 12.0
        y += ZEUG_ZEILE
        if platz < plaetze - 1:
            _trenner(r, y)
    _knopf("titel", Rect2(r.position.x + r.size.x * 0.25, y + 20.0, r.size.x * 0.5, 58.0),
        "BACK", true, func(p): _symbol("ZURUECK", p, false, M, RAHMEN_TIEF))


# --- Der Finger ------------------------------------------------------------

func _feld_bei(ort: Vector2) -> Dictionary:
    for feld in _felder:
        if feld["r"].has_point(ort):
            return feld
    return {}


func _gui_input(e: InputEvent) -> void:
    var gedrueckt := false
    var los := false
    var ort := Vector2.ZERO
    if e is InputEventScreenTouch:
        gedrueckt = e.pressed
        los = not e.pressed
        ort = e.position
    elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        gedrueckt = e.pressed
        los = not e.pressed
        ort = e.position
    if not gedrueckt and not los:
        return
    # **Im Lauf gehoert der Finger dem Helden** - ausser wenn gewaehlt wird.
    var st: Gefecht.Stand = _lauf.stand()
    if _lauf.lage == 1 and (st == null or not st.wartet_auf_wahl):
        _gedrueckt = ""
        return
    var feld := _feld_bei(ort)
    if gedrueckt:
        _gedrueckt = String(feld["id"]) if not feld.is_empty() and feld["aktiv"] else ""
        if not feld.is_empty():
            accept_event()
        return
    # Losgelassen: ausgeloest wird nur, was auch gedrueckt wurde. Wer den
    # Finger vom Knopf zieht, hat es sich anders ueberlegt.
    var war := _gedrueckt
    _gedrueckt = ""
    if feld.is_empty():
        return
    if feld["aktiv"] and (war == "" or war == String(feld["id"])):
        _gewaehlt(String(feld["id"]))
    accept_event()


func _gewaehlt(id: String) -> void:
    Klang.spiele(Klang.Ton.TIPP)
    if id.begins_with("skin"):
        var teile := id.substr(4).split("_")
        Burg.stand.waehle_skin(int(teile[0]), int(teile[1]))
        Burg.sichere()
    elif id.begins_with("held"):
        _lauf.beginne(int(id.substr(4)))
    elif id.begins_with("wahl"):
        _lauf.waehle(int(id.substr(4)))
    elif id.begins_with("bau"):
        Burg.baue(int(id.substr(3)))
    elif id.begins_with("lege"):
        Burg.stand.lege_an(int(id.substr(4)))
        Burg.sichere()
    elif id == "nochmal":
        _lauf.beginne(Burg.stand.held)
    elif id == "ton":
        Burg.stand.laut = 0.0 if Burg.stand.laut > 0.001 else 0.7
        Klang.laut = Burg.stand.laut
        Burg.sichere()
        Klang.spiele(Klang.Ton.TIPP)
    elif id == "beben":
        Burg.stand.beben = not Burg.stand.beben
        Tastsinn.an = Burg.stand.beben
        Burg.sichere()
    elif id == "burg":
        _lauf.lage = 3
    elif id == "zeug":
        _lauf.lage = 4
    elif id == "titel":
        _lauf.lage = 0
