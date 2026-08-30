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
    #
    # Die Staerken sind gedaempft, seit es Randlicht gibt. Vorher trug der Hof
    # die ganze Rueckmeldung; jetzt teilen sich beide die Aufgabe, und wenn
    # beide voll aufdrehen, wird aus dem Tier ein weisser Klecks. Genau das
    # war im ersten Bild zu sehen: eine beleuchtete Glutqualle war von einer
    # beleuchteten Schildkoralle nicht mehr zu unterscheiden.
    if stufe == 0:
        _gluehen(p, r * 2.2 * puls, farbe, 0.13 + 0.24 * hitze)
    elif stufe == 1:
        draw_circle(p, r * 1.6 * puls, Color(farbe.r, farbe.g, farbe.b,
            0.08 + 0.13 * hitze))

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
        Arten.Art.SCHILDKORALLE:
            _schildkoralle(p, r, farbe, t, hitze)
        Arten.Art.GLUTQUALLE:
            _glutqualle(p, r, farbe, t, hitze)
        Arten.Art.TREIBANKER:
            _treibanker(p, r, farbe, t, hitze)
        Arten.Art.SPRUNGAAL:
            _sprungaal(p, r, farbe, t, hitze)
        Arten.Art.SCHLUNDMUTTER:
            _schlundmutter(p, r, farbe, t, hitze)

    # Lebensanzeige nur bei Verletzten. Volle Balken ueber jedem Tier waeren
    # Rauschen; ein angeschlagener Gegner ist dagegen eine Entscheidung.
    _kielwasser(p, r, farbe, t)
    _randlicht(p, r, farbe, t)

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
    var fuellung := Color(farbe.r, farbe.g, farbe.b, 0.18 + 0.20 * hitze)
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


# --- Die vier spaeten Arten -----------------------------------------------
#
# Jede muss auf den ersten Blick sagen, was sie anders macht. Ein Gegner mit
# einer besonderen Regel, den man nicht von den anderen unterscheiden kann,
# ist kein Entwurf, sondern eine Falle.

func _schildkoralle(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Gepanzert und schwer: uebereinanderliegende Platten mit dickem Saum. Die
    # Fugen glimmen - die einzige Stelle, an der ueberhaupt Licht hineinkommt,
    # und damit die Begruendung fuer den Panzer im Bild.
    var k := t.richtung
    var quer := k.orthogonal()

    var saum := PackedVector2Array()
    for i in 7:
        var w := TAU * float(i) / 7.0 + t.phase * 0.2
        saum.append(p + (k * cos(w) + quer * sin(w)) * r * (0.92 + 0.16 * float(i % 2)))
    _koerper(saum, farbe, hitze)

    for i in 3:
        var t_i := float(i) / 2.0
        var vorn := p + k * r * lerpf(0.62, -0.42, t_i)
        var halb := r * lerpf(0.42, 0.86, t_i)
        var platte := PackedVector2Array([
            vorn + quer * halb, vorn - quer * halb,
            vorn - k * r * 0.30 - quer * halb * 0.82,
            vorn - k * r * 0.30 + quer * halb * 0.82,
        ])
        draw_colored_polygon(platte, Color(farbe.r, farbe.g, farbe.b,
            0.16 + 0.22 * hitze))
        # Die Fuge, nicht die Platte, traegt das Licht.
        draw_line(vorn + quer * halb, vorn - quer * halb,
            Color(1.0, 0.98, 0.90, 0.30 + 0.55 * hitze), 1.5)

    _auge(p + k * r * 0.66 + quer * r * 0.26, r * 0.15, hitze)
    _auge(p + k * r * 0.66 - quer * r * 0.26, r * 0.15, hitze)


func _glutqualle(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Ein weiter, blasser Schirm um einen sehr hellen Kern. Genau das ist ihre
    # Regel als Bild: der Schirm ist Beiwerk, getroffen wird der Kern - und wer
    # sie am Rand des Kegels mitlaufen laesst, trifft ihn nicht.
    var k := t.richtung
    var quer := k.orthogonal()

    var schirm := PackedVector2Array()
    for i in 13:
        var w := lerpf(-PI * 0.62, PI * 0.62, float(i) / 12.0)
        var welle := 1.0 + 0.10 * sin(t.alter * 2.2 + float(i) * 0.9 + t.phase)
        schirm.append(p + (k * cos(w) * 1.02 + quer * sin(w) * 1.28) * r * welle)
    schirm.append(p - k * r * 0.52)
    draw_colored_polygon(schirm, Color(farbe.r, farbe.g, farbe.b,
        0.13 + 0.20 * hitze))
    draw_polyline(schirm + PackedVector2Array([schirm[0]]),
        Color(farbe.r, farbe.g, farbe.b, 0.34 + 0.30 * hitze), 1.3, true)

    for i in 5:
        var s := (float(i) - 2.0) * 0.34
        var wurzel := p - k * r * 0.30 + quer * r * s
        var wehen := sin(t.alter * 4.4 + float(i) * 1.3) * r * 0.26
        draw_line(wurzel, wurzel - k * r * 1.5 + quer * wehen,
            Color(farbe.r, farbe.g, farbe.b, 0.24), 1.2)

    var glut := 0.5 + 0.5 * sin(t.alter * 3.0 + t.phase)
    draw_circle(p, r * (0.40 + 0.06 * glut), Color(1.0, 0.86, 0.72,
        0.55 + 0.45 * hitze))
    draw_circle(p, r * 0.22, Color(1.0, 0.98, 0.94, 0.85))


func _treibanker(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Ein schwerer Leib an einer langen Schleppe. Die Schleppe haengt gegen die
    # Wanderrichtung - man sieht dem Tier an, wohin es zieht, bevor es zieht.
    var seite: float = 1.0 if cos(t.phase) >= 0.0 else -1.0
    var zug := Vector2(seite, 0.0)
    var k := t.richtung
    var quer := k.orthogonal()

    var schleppe := PackedVector2Array()
    for i in 6:
        var f := float(i) / 5.0
        schleppe.append(p - zug * r * (0.6 + 2.3 * f)
            - k * r * 0.5 * f
            + quer * sin(t.alter * 3.0 + f * 3.4) * r * 0.22 * f)
    draw_polyline(schleppe, Color(farbe.r, farbe.g, farbe.b, 0.34), 1.6)
    draw_circle(schleppe[schleppe.size() - 1], r * 0.16,
        Color(farbe.r, farbe.g, farbe.b, 0.42))

    var leib := PackedVector2Array([
        p + k * r * 0.92 + zug * r * 0.28,
        p + quer * r * 0.70,
        p - k * r * 0.86 + zug * r * 0.12,
        p - quer * r * 0.70,
    ])
    _koerper(leib, farbe, hitze)

    # Zwei kurze Fluegel quer zur Wanderrichtung - das Segel, das ihn treibt.
    for s: float in SEITEN:
        var wurzel := p + quer * r * 0.5 * s
        draw_line(wurzel, wurzel + zug * r * 1.15 + quer * r * 0.2 * s,
            Color(farbe.r, farbe.g, farbe.b, 0.46 + 0.3 * hitze), 2.0)

    _auge(p + k * r * 0.42 + zug * r * 0.22, r * 0.19, hitze)


func _sprungaal(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Der Leib staucht sich vor dem Schub und streckt sich waehrend des Schubs.
    # Dieselbe Zahl, die in `Schlund.bahn()` das Sinken treibt - der Koerper
    # luegt also nicht ueber die Bewegung, die gleich kommt.
    var takt: float = Arten.art(t.art)[&"takt"]
    var schub := cos(takt * t.alter + t.phase)
    var laenge := 1.0 + 0.55 * schub
    var dicke := 1.0 - 0.26 * schub

    var k := t.richtung
    var quer := k.orthogonal()

    var glieder := 5
    for i in range(glieder - 1, -1, -1):
        var f := float(i) / float(glieder - 1)
        var wo := p - k * r * 1.5 * laenge * f \
            + quer * sin(t.alter * 7.0 + f * 4.2 + t.phase) * r * 0.34 * f
        draw_circle(wo, r * dicke * (0.52 - 0.30 * f),
            Color(farbe.r, farbe.g, farbe.b, (0.34 + 0.40 * hitze) * (1.0 - 0.5 * f)))

    var kopf := PackedVector2Array([
        p + k * r * 1.05 * laenge,
        p + quer * r * 0.46 * dicke,
        p - k * r * 0.30,
        p - quer * r * 0.46 * dicke,
    ])
    _koerper(kopf, farbe, hitze)

    # Ein heller Blitz entlang des Leibes, wenn er gerade schiesst.
    if schub > 0.45:
        draw_line(p - k * r * 1.2, p + k * r * 1.1 * laenge,
            Color(1.0, 0.98, 0.92, 0.28 * (schub - 0.45) / 0.55), 2.4)

    _auge(p + k * r * 0.48 * laenge, r * 0.17, hitze)


func _schlundmutter(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Das Leitwesen. Es muss auf den ersten Blick anders **gross** sein als
    # alles andere - deshalb ein breiter Mantel, ein Kranz aus Augen und ein
    # Schleppnetz aus Faeden, das ueber den halben Bildschirm reicht.
    var k := t.richtung
    var quer := k.orthogonal()
    var atem := 1.0 + 0.05 * sin(t.alter * 1.1 + t.phase)

    # Die Faeden zuerst, damit der Leib darueber liegt.
    for i in 9:
        var s := (float(i) - 4.0) * 0.24
        var wurzel := p - k * r * 0.2 + quer * r * s * 1.15
        var wehen := sin(t.alter * 1.7 + float(i) * 0.8) * r * 0.5
        draw_line(wurzel, wurzel - k * r * 2.4 + quer * wehen,
            Color(farbe.r, farbe.g, farbe.b, 0.16 + 0.10 * hitze), 1.6)

    var mantel := PackedVector2Array()
    for i in 17:
        var w := lerpf(-PI * 0.72, PI * 0.72, float(i) / 16.0)
        var buchtung := 1.0 + 0.07 * sin(float(i) * 2.3 + t.alter * 1.4)
        mantel.append(p + (k * cos(w) * 0.96 + quer * sin(w) * 1.22)
            * r * atem * buchtung)
    mantel.append(p - k * r * 0.72)
    _koerper(mantel, farbe, hitze)

    # Panzerrippen ueber dem Mantel - dieselbe Sprache wie bei der
    # Schildkoralle, weil beide dieselbe Eigenschaft haben.
    for i in 4:
        var f := float(i) / 3.0
        var y := lerpf(0.62, -0.42, f)
        var halb := lerpf(r * 0.46, r * 1.02, f)
        draw_line(p + k * r * y + quer * halb, p + k * r * y - quer * halb,
            Color(1.0, 0.96, 0.92, 0.16 + 0.34 * hitze), 2.0)

    # Ein Kranz aus Augen. Kein einzelnes grosses - viele kleine wirken auf
    # einem Telefon groesser als eines, das man fuer einen Reflex haelt.
    for i in 7:
        var w := lerpf(-PI * 0.42, PI * 0.42, float(i) / 6.0)
        _auge(p + (k * cos(w) * 0.62 + quer * sin(w) * 0.86) * r, r * 0.10, hitze)


## Randlicht: die dem Waechter zugewandte Kante wird hell.
##
## Das ist der billigste Weg zu Koerperlichkeit, den es gibt - ein heller
## Bogen auf einer Seite, sonst nichts. Ein Tier, das von ueberall gleich
## beleuchtet ist, sieht aus wie ein Aufkleber; eines mit einer hellen und
## einer dunklen Seite sieht aus wie ein Koerper im Wasser.
##
## Die Staerke kommt aus `Raeuber.licht`, also aus derselben
## `Schlund.beleuchtung()`, die den Schaden bestimmt. Randlicht ohne Schaden
## waere ein Kegel, der weiter zu reichen scheint als er reicht.
func _randlicht(p: Vector2, r: float, farbe: Color, t: Raeuber) -> void:
    if t.licht <= 0.05:
        return
    var zum_licht := (Graben.WAECHTER - p)
    if zum_licht.length_squared() < 1.0:
        return
    var w := zum_licht.angle()
    var staerke: float = t.licht
    var bogen := lerpf(1.15, 0.72, staerke)

    # Zwei Bogen: ein breiter, weicher Saum und darin eine schmale, harte
    # Kante. Der Saum macht die Rundung, die Kante den Glanzpunkt.
    draw_arc(p, r * 1.04, w - bogen, w + bogen, 16,
        Color(farbe.r, farbe.g, farbe.b, 0.26 * staerke), 2.6)
    draw_arc(p, r * 0.96, w - bogen * 0.48, w + bogen * 0.48, 12,
        Color(1.0, 0.99, 0.94, 0.24 * staerke * staerke), 1.5)


## Kielwasser: eine kurze, sich verjuengende Spur hinter schnellen Tieren.
##
## Sie erzaehlt Geschwindigkeit, ohne dass sich etwas bewegen muss - auf einem
## Standbild sieht man, wer schiesst und wer treibt. Traege Arten bekommen
## keine; ein Schleppband hinter einer Schildkoralle waere eine Luege ueber
## ihr Tempo.
func _kielwasser(p: Vector2, r: float, farbe: Color, t: Raeuber) -> void:
    var tempo: float = Arten.tempo(t.art)
    if tempo < 80.0 or t.alter < 0.12:
        return
    var kraft := clampf((tempo - 80.0) / 90.0, 0.0, 1.0)
    var zurueck := -t.richtung

    # Drei Glieder, jedes duenner und blasser als das davor.
    for i in 3:
        var f := float(i + 1) / 3.0
        var wo := p + zurueck * r * (0.9 + 2.4 * f) * kraft
        draw_circle(wo, r * (0.62 - 0.17 * float(i)),
            Color(farbe.r, farbe.g, farbe.b, (0.16 - 0.045 * float(i)) * kraft))
