extends Node2D

## Zeichnet alle Raeuber einer Welle - in **einem** `_draw()`.
##
## Nicht je Raeuber ein Knoten: eine spaete Welle hat 180 Tiere, und 180
## Node2D mit eigenem `_draw()` kosten auf einem Telefon mehr als der Rest des
## Spiels zusammen. Die Tiere sind schlichte Objekte in einem Feld, das
## `wache.gd` fuehrt; dieser Knoten liest es nur.
##
## Jede Art wird aus Grundformen gezeichnet. Es gibt keine Bilddatei im
## Projekt - siehe `ASSETS.md`.

const GLUEHRINGE := 3

## Ab wievielen Tieren im Bild die Feinheiten wegfallen.
##
## Ehrlich gesagt: die Bildrate eines Telefons laesst sich von hier aus nicht
## messen - xvfb rendert in Software, es gibt keine Grafikkarte. Statt eine
## Zahl zu erfinden, wird die Zeichenlast begrenzt, wo sie ohnehin nichts
## bringt: bei achtzig Tieren im Bild sieht niemand mehr den Hof um ein
## einzelnes, aber jeder sieht es ruckeln.
const DICHT_AB := 80
const SEHR_DICHT_AB := 140

## Links und rechts. Als Konstante, weil ein Feldliteral in einer for-Schleife
## seinen Typ verliert und jede Ableitung daraus mit.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]


## Wird von `wache.gd` gesetzt.
var tiere: Array[Raeuber] = []


func _ready() -> void:
    # Additiv. In der Tiefsee leuchtet jedes Tier selbst - es wird nicht
    # angestrahlt. Mit Mischblendung sahen dieselben Formen aus wie grauer
    # Nebel auf schwarzem Grund; erst durch Addition sind es Lichter.
    #
    # Folge fuer alles hier unten: es gibt **keine dunklen Stellen**. Eine
    # schwarze Pupille waere unsichtbar, deshalb wird ein Auge als heller Kern
    # mit dunklerem Ring gezeichnet, nicht umgekehrt.
    var stoff := CanvasItemMaterial.new()
    stoff.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = stoff


func _draw() -> void:
    var sichtbar := 0
    for t in tiere:
        if t.lebendig and t.alter >= 0.0:
            sichtbar += 1

    var stufe := 0
    if sichtbar >= SEHR_DICHT_AB:
        stufe = 2
    elif sichtbar >= DICHT_AB:
        stufe = 1

    for t in tiere:
        if not t.lebendig:
            continue
        _zeichne(t, stufe)


func _zeichne(t: Raeuber, stufe := 0) -> void:
    var p := t.ort
    var farbe: Color = Arten.farbe(t.art)
    var r: float = Arten.radius(t.art)

    # Wer im Licht steht, glueht auf. Das ist die einzige Rueckmeldung, die
    # der Spieler zum Zielen braucht - ohne sie sieht er nicht, wen er fasst.
    var hitze := t.hitze
    var puls := 1.0 + 0.18 * hitze

    # Der Hof faellt als Erstes weg - er kostet drei Kreise je Tier und traegt
    # am wenigsten, sobald das Bild voll ist.
    if stufe == 0:
        _gluehen(p, r * 2.4 * puls, farbe, 0.16 + 0.42 * hitze)
    elif stufe == 1:
        draw_circle(p, r * 1.6 * puls, Color(farbe.r, farbe.g, farbe.b,
            0.10 + 0.20 * hitze))

    # Bei sehr vielen Tieren nur noch Umriss und Farbe: die Form bleibt
    # lesbar, die Zierde geht.
    if stufe >= 2:
        _knapp(p, r, farbe, t, hitze)
        return

    match t.art:
        Arten.Art.ZAHNKIEFER:
            _zahnkiefer(p, r, farbe, t, hitze)
        Arten.Art.SCHLEIER:
            _schleier(p, r, farbe, t, hitze)
        Arten.Art.PANZERKREBS:
            _panzerkrebs(p, r, farbe, t, hitze)
        Arten.Art.GRABNATTER:
            _grabnatter(p, r, farbe, t, hitze)

    # Lebensanzeige nur bei Verletzten. Volle Balken ueber jedem Tier waeren
    # Rauschen; ein angeschlagener Gegner ist dagegen eine Entscheidung.
    if t.verletzt():
        var anteil := t.anteil()
        var breite := r * 1.8
        var oben := p + Vector2(-breite * 0.5, -r - 9.0)
        draw_rect(Rect2(oben, Vector2(breite, 2.4)), Color(0.0, 0.0, 0.0, 0.55))
        draw_rect(Rect2(oben, Vector2(breite * anteil, 2.4)),
            farbe.lerp(Color(1.0, 0.42, 0.34), 1.0 - anteil))


## Sparfassung: ein Leib, ein Umriss, kein Beiwerk. Wird erst gezeichnet, wenn
## so viele Tiere im Bild sind, dass Einzelheiten ohnehin verschwimmen.
func _knapp(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var leib := PackedVector2Array([
        p + k * r * 1.1,
        p + quer * r * 0.62,
        p - k * r * 1.0,
        p - quer * r * 0.62,
    ])
    draw_colored_polygon(leib, Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.35 * hitze))
    draw_polyline(leib + PackedVector2Array([leib[0]]),
        farbe.lerp(Color(1.0, 0.98, 0.94), 0.4 + 0.4 * hitze), 1.4, true)


## Weicher Schein aus gestapelten Kreisen. Billiger als ein Shader je Tier und
## auf gl_compatibility zuverlaessig.
func _gluehen(p: Vector2, radius: float, farbe: Color, staerke: float) -> void:
    for i in GLUEHRINGE:
        var t := float(i + 1) / float(GLUEHRINGE)
        draw_circle(p, radius * t, Color(farbe.r, farbe.g, farbe.b,
            staerke * (1.0 - t) * 0.7))


## Leib: gedaempfte Fuellung, heller Umriss. Bei additivem Zeichnen macht der
## Umriss die Form, nicht die Flaeche - eine hell gefuellte Flaeche waere ein
## Klecks ohne Kontur.
func _koerper(punkte: PackedVector2Array, farbe: Color, hitze: float) -> void:
    var fuellung := Color(farbe.r, farbe.g, farbe.b, 0.20 + 0.30 * hitze)
    draw_colored_polygon(punkte, fuellung)
    var geschlossen := punkte + PackedVector2Array([punkte[0]])
    draw_polyline(geschlossen, Color(farbe.r, farbe.g, farbe.b,
        0.30 + 0.30 * hitze), 3.2, true)
    draw_polyline(geschlossen, farbe.lerp(Color(1.0, 0.98, 0.94),
        0.45 + 0.45 * hitze), 1.3, true)


## Das Auge ist ein Leuchtpunkt mit Hof. Kein dunkler Kern - siehe `_ready()`.
func _auge(p: Vector2, r: float, hitze: float) -> void:
    draw_circle(p, r * 1.8, Color(0.30, 0.52, 0.60, 0.30))
    draw_circle(p, r, Color(1.0, 0.94, 0.78, 0.75 + 0.25 * hitze))


func _zahnkiefer(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Tiefseefisch: hoher, kurzer Leib, riesiger Kiefer, gegabelte Schwanzflosse.
    # Der erste Entwurf war eine glatte Kapsel mit einer Spitze hinten - im
    # Bild sah das aus wie eine Rakete. Was einen Fisch zum Fisch macht, sind
    # die Flossen und das Maul, nicht der Umriss des Rumpfes.
    var k := t.richtung
    var quer := k.orthogonal()
    var flossen := sin(t.alter * 7.0 + t.phase) * 0.22

    # Schwanzflosse, zwei Lappen mit Einbuchtung.
    var schwanz := PackedVector2Array([
        p - k * r * 0.85,
        p - k * r * 1.75 + quer * r * (0.72 + flossen),
        p - k * r * 1.25,
        p - k * r * 1.75 - quer * r * (0.72 - flossen),
    ])
    draw_colored_polygon(schwanz, Color(farbe.r, farbe.g, farbe.b, 0.28))
    draw_polyline(schwanz + PackedVector2Array([schwanz[0]]),
        farbe.lightened(0.25), 1.2, true)

    # Rumpf: vorn hoch, hinten schmal.
    var leib := PackedVector2Array([
        p + k * r * 1.05,
        p + k * r * 0.45 + quer * r * 0.66,
        p - k * r * 0.30 + quer * r * 0.58,
        p - k * r * 0.90 + quer * r * 0.20,
        p - k * r * 0.90 - quer * r * 0.20,
        p - k * r * 0.30 - quer * r * 0.58,
        p + k * r * 0.45 - quer * r * 0.66,
    ])
    _koerper(leib, farbe, hitze)

    # Rueckenflosse als Kamm.
    for i in 4:
        var s := lerpf(0.35, -0.75, float(i) / 3.0)
        var wurzel := p + k * r * s + quer * r * 0.55
        draw_line(wurzel, wurzel + quer * r * 0.34 - k * r * 0.12,
            Color(farbe.r, farbe.g, farbe.b, 0.45), 1.2)

    # Der Kiefer - offen stehend, mit Zaehnen nach innen. Das
    # Erkennungsmerkmal der Art.
    var oben := p + k * r * 1.05 + quer * r * 0.30
    var unten := p + k * r * 1.15 - quer * r * 0.34
    draw_line(p + k * r * 0.35 + quer * r * 0.50, oben, farbe.lightened(0.45), 1.8)
    draw_line(p + k * r * 0.35 - quer * r * 0.50, unten, farbe.lightened(0.45), 1.8)
    for i in 4:
        var f := float(i) / 3.0
        var o := (p + k * r * 0.40 + quer * r * 0.48).lerp(oben, f)
        var u := (p + k * r * 0.40 - quer * r * 0.48).lerp(unten, f)
        draw_line(o, o.lerp(u, 0.30), Color(0.94, 0.99, 1.0, 0.65), 1.2)
        draw_line(u, u.lerp(o, 0.30), Color(0.94, 0.99, 1.0, 0.65), 1.2)

    _auge(p + k * r * 0.30 + quer * r * 0.30, r * 0.20, hitze)
    _auge(p + k * r * 0.30 - quer * r * 0.30, r * 0.20, hitze)

    # Leuchtangel, von der Stirn nach vorn gebogen.
    var wurzel_angel := p - k * r * 0.10 + quer * r * 0.50
    var angel := p + k * r * 1.30 + quer * r * (0.62 + flossen * 0.5)
    draw_line(wurzel_angel, wurzel_angel.lerp(angel, 0.55),
        Color(farbe.r, farbe.g, farbe.b, 0.55), 1.2)
    draw_line(wurzel_angel.lerp(angel, 0.55), angel,
        Color(farbe.r, farbe.g, farbe.b, 0.40), 1.0)
    draw_circle(angel, r * 0.30, Color(0.60, 0.92, 0.90, 0.25))
    draw_circle(angel, r * 0.15, Color(0.92, 1.0, 0.98, 0.9))


func _schleier(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Glockenschirm mit nachziehenden Faeden. Fast durchsichtig - der Schwarm
    # soll als Wolke lesbar sein, nicht als Reihe einzelner Tiere.
    var k := t.richtung
    var quer := k.orthogonal()
    var schirm := PackedVector2Array()
    for i in 9:
        var w := lerpf(-PI * 0.5, PI * 0.5, float(i) / 8.0)
        schirm.append(p + (k * cos(w) * 1.05 + quer * sin(w) * 1.25) * r)
    schirm.append(p - k * r * 0.35)
    draw_colored_polygon(schirm, Color(farbe.r, farbe.g, farbe.b,
        0.42 + 0.42 * hitze))
    draw_polyline(schirm, farbe.lightened(0.45), 1.2, true)

    for i in 4:
        var s := (float(i) - 1.5) * 0.42
        var wurzel := p - k * r * 0.2 + quer * r * s
        var wehen := sin(t.alter * 6.0 + float(i)) * r * 0.3
        draw_line(wurzel, wurzel - k * r * 1.7 + quer * wehen,
            Color(farbe.r, farbe.g, farbe.b, 0.35), 1.1)


func _panzerkrebs(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Breiter, flacher Panzer, sechs Laufbeine, zwei schwere Scheren voran.
    # Der erste Entwurf war ein Sechseck mit zwei Strichen - im Bild eine
    # Papiertuete. Ein Krebs wird durch seine Anhaenge erkannt, nicht durch
    # den Umriss des Panzers.
    var k := t.richtung
    var quer := k.orthogonal()
    var rudern := sin(t.alter * 3.4 + t.phase)

    # Laufbeine zuerst, damit der Panzer darueber liegt.
    for seite: float in SEITEN:
        for i in 3:
            var laengs := lerpf(0.35, -0.60, float(i) / 2.0)
            var wurzel := p + k * r * laengs + quer * r * 0.72 * seite
            var knie := wurzel + quer * r * (0.72 + 0.12 * rudern) * seite \
                - k * r * 0.30
            var fuss := knie + quer * r * 0.46 * seite + k * r * (0.34 + 0.14 * rudern)
            draw_line(wurzel, knie, Color(farbe.r, farbe.g, farbe.b, 0.55), 2.4)
            draw_line(knie, fuss, Color(farbe.r, farbe.g, farbe.b, 0.42), 1.8)

    # Panzer: vorn breit und gerundet, hinten verjuengt.
    var panzer := PackedVector2Array([
        p + k * r * 0.62 + quer * r * 0.42,
        p + k * r * 0.34 + quer * r * 0.94,
        p - k * r * 0.22 + quer * r * 1.02,
        p - k * r * 0.78 + quer * r * 0.62,
        p - k * r * 0.94,
        p - k * r * 0.78 - quer * r * 0.62,
        p - k * r * 0.22 - quer * r * 1.02,
        p + k * r * 0.34 - quer * r * 0.94,
        p + k * r * 0.62 - quer * r * 0.42,
    ])
    _koerper(panzer, farbe, hitze)

    # Plattenfugen quer ueber den Ruecken.
    for i in 3:
        var s := lerpf(0.30, -0.60, float(i) / 2.0)
        var halb := lerpf(0.86, 0.52, float(i) / 2.0)
        draw_line(p + k * r * s + quer * r * halb, p + k * r * s - quer * r * halb,
            Color(farbe.r, farbe.g, farbe.b, 0.30), 1.2)

    # Scheren: Oberarm, Unterarm, zwei Klauenhaelften.
    for seite: float in SEITEN:
        var schulter := p + k * r * 0.45 + quer * r * 0.70 * seite
        var gelenk := schulter + k * r * 0.72 + quer * r * 0.52 * seite
        var klaue := gelenk + k * r * 0.62 + quer * r * 0.10 * seite
        draw_line(schulter, gelenk, Color(farbe.r, farbe.g, farbe.b, 0.60), 4.2)
        draw_line(gelenk, klaue, Color(farbe.r, farbe.g, farbe.b, 0.55), 3.4)
        var spreizung := (0.26 + 0.18 * rudern) * seite
        draw_line(klaue, klaue + (k * 0.9 + quer * (0.5 + spreizung) * seite) * r * 0.58,
            farbe.lightened(0.35), 2.4)
        draw_line(klaue, klaue + (k * 0.9 - quer * (0.2 - spreizung) * seite) * r * 0.58,
            farbe.lightened(0.35), 2.4)

    # Stielaugen, wie bei echten Tiefseekrebsen nach vorn gerichtet.
    for seite: float in SEITEN:
        var stiel := p + k * r * 0.55 + quer * r * 0.26 * seite
        var kopf := stiel + k * r * 0.34
        draw_line(stiel, kopf, Color(farbe.r, farbe.g, farbe.b, 0.5), 1.6)
        _auge(kopf, r * 0.17, hitze)


func _grabnatter(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Der Leib folgt der eigenen Bahn: die Glieder sitzen dort, wo das Tier
    # vor Sekundenbruchteilen war. Weil `Schlund.bahn()` eine reine Funktion
    # der Zeit ist, laesst sich das exakt zurueckrechnen - der Koerper luegt
    # also nie ueber den Weg, den er genommen hat.
    var glieder := t.rueckweg
    if glieder.is_empty():
        glieder = [p]

    for i in range(glieder.size() - 1, -1, -1):
        var f := 1.0 - float(i) / float(maxi(1, glieder.size()))
        var dick := r * (0.35 + 0.65 * f)
        draw_circle(glieder[i], dick,
            Color(farbe.r, farbe.g, farbe.b, 0.55 + 0.45 * hitze).darkened(0.3 * (1.0 - f)))

    var k := t.richtung
    var quer := k.orthogonal()
    var kopf := PackedVector2Array([
        p + k * r * 1.25,
        p + quer * r * 0.72,
        p - k * r * 0.55,
        p - quer * r * 0.72,
    ])
    _koerper(kopf, farbe, hitze)
    _auge(p + k * r * 0.35 + quer * r * 0.30, r * 0.19, hitze)
    _auge(p + k * r * 0.35 - quer * r * 0.30, r * 0.19, hitze)
