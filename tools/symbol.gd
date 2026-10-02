extends SceneTree

## Erzeugt das App-Symbol und den Android-Symbolsatz - gezeichnet vom Spiel
## selbst, nicht gemalt.
##
##     xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/symbol.gd
##
## Dieselbe Entscheidung wie bei allem anderen Sichtbaren: die Symbole
## entstehen in diesem Quelltext und haben damit genau eine Herkunft. Die
## erzeugten Dateien stehen in `ASSETS.md` als selbst erzeugt.
##
## **Motiv: einer gegen viele.** Der Held in seinem Blau, mit erhobener
## Klinge, und um ihn herum die Horde in ihren Farben.
## Gezeichnet mit den Pixel-Sprites des Spiels (`Figuren`, `Pixel`), mit
## eingebranntem Umriss, gross und scharf vergroessert. Wer das Symbol
## kennt, erkennt den Bildschirm wieder, und wer den Bildschirm kennt, das
## Symbol.
##
## Kein Schriftzug: ein Symbol muss auf 48 Pixel Kantenlaenge noch erkennbar
## sein, und Buchstaben sind es dort nie. Eine blaue Figur in einem Ring aus
## warmen Farben ist es.
##
## **Hier zeichnete bis September 2026 noch NEKTONs Lichtkegel**, zwei Spiele
## nach NEKTON - und das Werkzeug lief gar nicht mehr, weil es eine Klasse
## aufrief, die mit ihrem Spiel geloescht worden war. Die Symbole im
## Repository waren damit Dateien, die niemand mehr erzeugen konnte.
##
## **Es braucht einen Bildschirm**, anders als der Rest der Werkzeuge: die
## Figuren entstehen im Renderer, nicht in einer Pixelschleife. Deshalb
## `xvfb-run` und `opengl3`, wie beim Schuss.
##
## --- Warum es fuenf Dateien sind ---
##
## Ein einzelnes Vollbild reicht seit Android 8 nicht mehr. Das System schiebt
## dort **zwei** Ebenen gegeneinander - Hintergrund und Vordergrund - und
## schneidet daraus die Form, die der Hersteller gerade vorsieht: Kreis,
## abgerundetes Quadrat, Tropfen. Wer nur ein fertiges Bild abgibt, bekommt es
## in ein weisses Kaestchen gesetzt und steht damit neben jeder anderen App
## wie ein Fremdkoerper.
##
##   * `symbol.png` - 512, das Projektsymbol und die Vorlage fuer den Web-Bau
##   * `symbol_192.png` - der alte, nicht anpassbare Starter
##   * `symbol_hintergrund.png` - 432, randlos: der Boden und die Horde
##   * `symbol_vordergrund.png` - 432, durchsichtig: der Held, freigestellt
##   * `symbol_einfarbig.png` - 432, weiss auf durchsichtig, fuer die
##     eingefaerbten Symbole ab Android 13
##
## **Die Schutzzone ist der ganze Grund fuer die Aufteilung.** Von den 432
## Pixeln sind nur die inneren 66 Prozent sicher sichtbar; alles ausserhalb
## darf beschnitten werden. Der Held liegt deshalb im Vordergrund und
## vollstaendig innerhalb dieser Zone. Die Horde steht im Hintergrund und
## reicht bis an die Ecken - was dort abgeschnitten wird, ist eben ein Feind
## weniger, und die inneren stehen so nah, dass jede Form sie zeigt.
##
## Bewegen manche Starter die zwei Ebenen gegeneinander, verschiebt sich der
## Held vor der Horde. Das ist genau die Lage im Spiel.

const ADAPTIV := 432
## Anteil der Kantenlaenge, der sicher sichtbar bleibt.
const SCHUTZZONE := 0.66
## Wie gross das Motiv im Vollbild steht. Nicht ganz eins: der Starter legt
## beim alten Symbol selbst eine Maske darueber, und die Klinge soll bleiben.
const VOLL := 0.88

enum Ebene { GRUND, HELD, EINFARBIG }

## Die Horde: Winkel um den Helden (0 = rechts, im Uhrzeigersinn, weil y nach
## unten zeigt), Abstand in Motivbreiten, Sorte. **Gemischt nach Bedeutung**:
## vorn das Fussvolk, dahinter Ritter und Treiber, damit jede der Farben,
## die man im Spiel lernt, einmal im Symbol steht.
const HORDE := [
    [0.15, 0.40, Feinde.Art.RITTER],
    [0.85, 0.42, Feinde.Art.STROLCH],
    [1.55, 0.44, Feinde.Art.SPIESSER],
    [2.20, 0.42, Feinde.Art.ARMBRUSTER],
    [2.85, 0.40, Feinde.Art.WOLF],
    [3.50, 0.38, Feinde.Art.TREIBER],
    [4.15, 0.36, Feinde.Art.STROLCH],
    [4.80, 0.38, Feinde.Art.SPIESSER],
    [5.50, 0.40, Feinde.Art.STROLCH],
    # Der zweite Ring: nur im Hintergrund zu sehen, wo nichts beschnitten
    # wird, oder im Vollbild angeschnitten am Rand.
    [0.50, 0.80, Feinde.Art.STROLCH],
    [1.20, 0.80, Feinde.Art.STROLCH],
    [1.90, 0.82, Feinde.Art.RITTER],
    [2.55, 0.80, Feinde.Art.STROLCH],
    [3.20, 0.82, Feinde.Art.SPIESSER],
    [3.85, 0.80, Feinde.Art.STROLCH],
    [4.50, 0.82, Feinde.Art.ARMBRUSTER],
    [5.15, 0.80, Feinde.Art.STROLCH],
    [5.85, 0.82, Feinde.Art.TREIBER]]


func _initialize() -> void:
    _male_alle()


func _male_alle() -> void:
    var voll_512 := await _male(512, 512.0 * VOLL, [Ebene.GRUND, Ebene.HELD])
    _schreibe(voll_512, "res://symbol.png")
    var voll_192 := await _male(192, 192.0 * VOLL, [Ebene.GRUND, Ebene.HELD])
    _schreibe(voll_192, "res://symbol_192.png")
    var mass := float(ADAPTIV) * SCHUTZZONE
    _schreibe(await _male(ADAPTIV, mass, [Ebene.GRUND]),
        "res://symbol_hintergrund.png")
    _schreibe(_gerade(await _male(ADAPTIV, mass, [Ebene.HELD])),
        "res://symbol_vordergrund.png")
    _schreibe(_weiss(await _male(ADAPTIV, mass, [Ebene.EINFARBIG])),
        "res://symbol_einfarbig.png")
    quit()


## Zeichnet die verlangten Ebenen in ein eigenes, durchsichtiges Blatt und
## gibt das Bild zurueck. `mass` ist die Kantenlaenge des Motivs in Pixeln.
func _male(groesse: int, mass: float, ebenen: Array) -> Image:
    var blatt := SubViewport.new()
    blatt.size = Vector2i(groesse, groesse)
    blatt.transparent_bg = true
    blatt.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    var knoten := Node2D.new()
    knoten.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    blatt.add_child(knoten)
    root.add_child(blatt)
    var mitte := Vector2(groesse, groesse) * 0.5
    knoten.draw.connect(func() -> void:
        if Ebene.GRUND in ebenen:
            _boden(knoten, groesse, mass, mitte)
        if Ebene.HELD in ebenen:
            _held(knoten, mass, mitte, true)
        if Ebene.EINFARBIG in ebenen:
            _held(knoten, mass, mitte, false))
    knoten.queue_redraw()
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var bild := blatt.get_texture().get_image()
    blatt.queue_free()
    bild.convert(Image.FORMAT_RGBA8)
    return bild


## Wo der Held steht: seine Fuesse, und wie hoch er ist. Eine Stelle fuer
## beide Ebenen - sonst stuende er im Vollbild woanders als im Starter.
##
## **Er ist gross, und die Horde ist klein.** Im Spiel sind beide fast gleich
## hoch; im ersten Anlauf auch hier, und auf 48 Pixeln stand ein Gewimmel
## gleich grosser Figuren, unter denen das Blau eine von vielen Farben war.
## Ein Symbol beantwortet *wer bin ich* auf einen Blick, nicht nach Suchen.
func _held_ort(mass: float, mitte: Vector2) -> Vector2:
    return mitte + Vector2(-0.10, 0.40) * mass


func _held_hoehe(mass: float) -> float:
    return mass * 0.70


## Wie gross ein Bildpunkt eines Sprites im Symbol ist: ganzzahlig, damit
## die Pixel scharf bleiben. Der Held ist 24 Bildpunkte hoch.
func _punkt(mass: float) -> float:
    return maxf(1.0, floorf(_held_hoehe(mass) * 0.9 / 24.0))


func _sprite(knoten: Node2D, name: String, zeilen: PackedStringArray, kleid: Dictionary,
        anker: int, fuss: Vector2, p: float, spiegel := false) -> void:
    var r := Pixel.bild(name, zeilen, kleid, anker, spiegel, false, true)
    var a := Pixel.anker(name, spiegel, false, true)
    var oben_links := Vector2(fuss.x - (float(a) + 0.5) * p, fuss.y - float(r.size.y) * p)
    knoten.draw_texture_rect_region(Pixel.textur(),
        Rect2(oben_links.round(), Vector2(r.size) * p), Rect2(r))


## Eine Linie aus Bildpunkten der Groesse `p` (Bresenham), mit Umriss.
func _linie(knoten: Node2D, a: Vector2, b: Vector2, farbe: Color, dicke: int,
        p: float) -> void:
    var punkte: Array[Vector2i] = []
    var p0 := Vector2i((a / p).round())
    var p1 := Vector2i((b / p).round())
    var dx := absi(p1.x - p0.x)
    var dy := -absi(p1.y - p0.y)
    var sx := 1 if p0.x < p1.x else -1
    var sy := 1 if p0.y < p1.y else -1
    var fehler := dx + dy
    var q := p0
    for i in 256:
        punkte.append(q)
        if q == p1:
            break
        var e2 := 2 * fehler
        if e2 >= dy:
            fehler += dy
            q.x += sx
        if e2 <= dx:
            fehler += dx
            q.y += sy
    var halb := float(dicke / 2)
    for k in 2:
        for pt in punkte:
            var r := Rect2((Vector2(pt) - Vector2.ONE * halb) * p, Vector2.ONE * p * float(dicke))
            if k == 0:
                knoten.draw_rect(r.grow(p), Palette.UMRISS)
            else:
                knoten.draw_rect(r, farbe)


func _boden(knoten: Node2D, groesse: int, mass: float, mitte: Vector2) -> void:
    knoten.draw_rect(Rect2(0.0, 0.0, groesse, groesse), Palette.BODEN)
    var p := _punkt(mass)
    # Ein paar Kiesel, wie auf dem Feld - fest gesetzt, nicht gewuerfelt:
    # ein Symbol, das bei jedem Lauf anders aussieht, ist keins.
    for i in 9:
        var w := float(i) * 2.39996
        var r := mass * (0.18 + 0.07 * float(i % 4))
        var q := ((mitte + Vector2(cos(w), sin(w)) * r) / p).round() * p
        knoten.draw_rect(Rect2(q, Vector2.ONE * p), Palette.GRUND_ZIER)
    # Der Held steht im Symbol immer vorn, weil er auf der eigenen Ebene
    # liegt - dieselbe Regel wie bei der Marke: wer sich sucht, muss sich
    # finden. **Er ist gross, und die Horde ist klein.**
    var klein := maxf(1.0, floorf(p * 0.38))
    var koerper := _held_ort(mass, mitte) + Vector2(0.0, -_held_hoehe(mass) * 0.45)
    var liste := []
    for f in HORDE:
        var winkel: float = f[0]
        var ort: Vector2 = koerper + Vector2(cos(winkel), sin(winkel)) * f[1] * mass \
            + Vector2(0.0, mass * 0.10)
        liste.append([ort, f[2]])
    liste.sort_custom(func(a, b): return a[0].y < b[0].y)
    for f in liste:
        var ort: Vector2 = f[0]
        var art: int = f[1]
        _sprite(knoten, "sym_f%d" % art, Figuren.feind(art, 0),
            Pixel.kleid(Palette.sorte(art)), Figuren.anker(art), ort, klein, ort.x > koerper.x)


## Der Held mit erhobener Klinge. `farbig` zeichnet ihn wie im Spiel; ohne
## ist es die Form fuer die einfarbige Fassung - dort traegt nur die Deckung.
func _held(knoten: Node2D, mass: float, mitte: Vector2, farbig: bool) -> void:
    var ort := _held_ort(mass, mitte)
    var p := _punkt(mass)
    var kleid := Pixel.kleid(Palette.HELD, Palette.HELD_GLANZ)
    _sprite(knoten, "sym_held", Figuren.held(0, -1), kleid, Figuren.BEIN_ANKER, ort, p)
    # Die Klinge schraeg nach vorn oben. Steiler stuende ihre Spitze
    # ausserhalb der Schutzzone und fiele beim Beschneiden weg.
    var r := Vector2(cos(-0.75), sin(-0.75))
    var schulter := ort + Vector2(Figuren.HELD_SCHULTER) * p
    var hand := schulter + r * 5.0 * p
    _linie(knoten, schulter, hand, kleid["c"], 2, p)
    _linie(knoten, hand, hand + r * 11.0 * p, Palette.STAHL_HELL, 2, p)
    _linie(knoten, hand - r.orthogonal() * 2.0 * p, hand + r.orthogonal() * 2.0 * p,
        Palette.STAHL_TIEF, 1, p)
    var _f := farbig


## Der Renderer mischt auf ein durchsichtiges Blatt vormultipliziert: an
## einer Kante mit halber Deckung steht dann halbe Farbe **und** halbe
## Deckung, und ein Bildbetrachter rechnet die Deckung ein zweites Mal ein.
## Heraus kommt ein dunkler Saum um jede Figur. Hier wird er zurueckgerechnet.
func _gerade(bild: Image) -> Image:
    for y in bild.get_height():
        for x in bild.get_width():
            var c := bild.get_pixel(x, y)
            if c.a > 0.004 and c.a < 0.996:
                bild.set_pixel(x, y, Color(minf(c.r / c.a, 1.0),
                    minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))
    return bild


## Die einfarbige Fassung: dort faerbt das System selbst, abgegeben wird
## nur eine Form in Weiss. Was zaehlt, ist die Deckung.
func _weiss(bild: Image) -> Image:
    for y in bild.get_height():
        for x in bild.get_width():
            bild.set_pixel(x, y, Color(1.0, 1.0, 1.0, bild.get_pixel(x, y).a))
    return bild


func _schreibe(bild: Image, ziel: String) -> void:
    var fehler := bild.save_png(ProjectSettings.globalize_path(ziel))
    if fehler != OK:
        push_error("Symbol nicht schreibbar: %s" % error_string(fehler))
        return
    print("Symbol geschrieben: ", ziel, " (", bild.get_width(), "x",
        bild.get_height(), ")")
