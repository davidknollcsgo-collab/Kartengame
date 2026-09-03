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

## Wellenzeit, fuer alles, was zappeln soll, ohne mit dem Alter des einzelnen
## Tieres zu laufen.
var _zeit := 0.0


func _process(delta: float) -> void:
    _zeit += delta


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


## Die Funkenbluete dieser Welle, oder null. `wache.gd` setzt sie.
var bluete: Bluete = null

## --- Leuchtroehren statt Papierschnitt ---
##
## Im Rundumlauf sollen die Tiere aussehen wie Leuchtlinien: kein Koerper aus
## Farbe, sondern ein Zug, der glimmt. Das ist nicht bloss Geschmack - dort
## laeuft eine Nachbearbeitung mit Gluehen, und ein Gluehen greift an
## **hellen, schmalen** Stellen. Eine breite Flaeche mit halber Deckung wird
## davon nur milchig; eine helle duenne Linie wird davon zu einer Roehre.
##
## Der Schalter steht hier und nicht im Rundumlauf, weil die zwoelf
## Zeichenfunktionen hier stehen - und weil der Schlund unveraendert bleiben
## soll. Ohne ihn aendert sich dort nichts: `led` ist aus.
var led := false

## Wie deutlich das Tier gerade gezeichnet wird, 0 bis 1.
##
## **Ein Lauerer ist da, bevor man ihn sieht.** Er liegt still am Grund und
## glimmt nur; erst wenn er erwacht, steht er voll im Bild. Das ueber die
## drei Zeichenhelfer zu machen ist der einzige Weg, der nicht durch alle
## zwoelf Tierzeichnungen greift - dort steckt in jeder Zeile eine eigene
## Deckung, und zwoelf Stellen zu aendern heisst, elf davon zu vergessen.
var deckung := 1.0

## Wie deutlich ein Lauerer ist, solange er schlaeft. Nicht null: ein Tier,
## das man gar nicht sieht, ist kein Hinterhalt, sondern ein Betrug.
const LAUER_DECKUNG := 0.42


## Eine Fuellung. Bei Leuchtroehren faellt sie fast ganz weg - was bleibt, ist
## gerade genug, damit ein Tier vor einem Felsen nicht durchsichtig wirkt.
func _fuellung(punkte: PackedVector2Array, farbe: Color) -> void:
    if punkte.size() < 3:
        return
    farbe = _gedeckt(farbe)
    if led:
        draw_colored_polygon(punkte, Color(farbe.r * 0.22, farbe.g * 0.22,
            farbe.b * 0.22, farbe.a * 0.45))
        return
    draw_colored_polygon(punkte, farbe)


## Ein Linienzug. Bei Leuchtroehren zweimal: ein weiter blasser Hof und ein
## schmaler heller Kern darauf. Das ist dieselbe Machart wie beim Boot und
## bei den Ranken.
func _zug(punkte: PackedVector2Array, farbe: Color, dicke: float) -> void:
    if punkte.size() < 2:
        return
    farbe = _gedeckt(farbe)
    if led:
        draw_polyline(punkte, Color(farbe.r, farbe.g, farbe.b,
            farbe.a * 0.22), dicke * 3.4, true)
        draw_polyline(punkte, Color(minf(1.0, farbe.r * 1.5),
            minf(1.0, farbe.g * 1.5), minf(1.0, farbe.b * 1.5),
            minf(1.0, farbe.a * 1.7)), maxf(1.0, dicke * 0.9), true)
        return
    draw_polyline(punkte, farbe, dicke, true)


## Dasselbe fuer eine einzelne Strecke.
func _strich(a: Vector2, b: Vector2, farbe: Color, dicke: float) -> void:
    farbe = _gedeckt(farbe)
    if led:
        draw_line(a, b, Color(farbe.r, farbe.g, farbe.b, farbe.a * 0.22),
            dicke * 3.4, true)
        draw_line(a, b, Color(minf(1.0, farbe.r * 1.5),
            minf(1.0, farbe.g * 1.5), minf(1.0, farbe.b * 1.5),
            minf(1.0, farbe.a * 1.7)), maxf(1.0, dicke * 0.9), true)
        return
    draw_line(a, b, farbe, dicke, true)


## Nur die Deckung, nicht die Farbe: ein Lauerer soll blasser sein, nicht
## grauer - sonst verliert er die Farbe, an der man seine Art erkennt.
func _gedeckt(farbe: Color) -> Color:
    if deckung >= 1.0:
        return farbe
    return Color(farbe.r, farbe.g, farbe.b, farbe.a * deckung)


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

    # Die Bluete zuerst: sie treibt hinter den Raeubern, weil sie nicht zu
    # ihnen gehoert. Wer sie vor ihnen zeichnete, machte aus einer Gelegenheit
    # ein Hindernis.
    if bluete != null and bluete.lebendig and bluete.alter >= 0.0:
        _zeichne_bluete(bluete)

    for t in tiere:
        if not t.lebendig:
            continue
        deckung = LAUER_DECKUNG if t.lauert else 1.0
        _zeichne(t, stufe)
    deckung = 1.0


## Die Funkenbluete: ein Kern in einer offenen Huelle, aus der Faeden treiben.
##
## **Sie darf keinem Raeuber aehneln.** Alles andere im Bild ist gerichtet -
## Spitze voran, Bahn nach unten. Sie ist rund, symmetrisch und warm, und sie
## treibt quer. Wer eine Sekunde Zeit hat, soll ohne Nachdenken wissen: das
## will nicht zur Brut.
func _zeichne_bluete(b: Bluete) -> void:
    var p := b.ort
    var offen := 1.0 - b.anteil()
    var r := 34.0 + 10.0 * offen
    var warm := Color(1.0, 0.82, 0.42)
    var puls := 0.5 + 0.5 * sin(b.alter * 2.2 + b.phase)
    var hell: float = clampf(b.licht, 0.0, 1.0)

    # Faeden, die nach aussen treiben. Sie stehen quer zur Bahn, damit man
    # die Richtung sieht, in die sie zieht.
    for i in 10:
        var w := TAU * float(i) / 10.0 + b.alter * 0.35
        var weit := r * (1.5 + 0.5 * sin(b.alter * 1.7 + float(i)))
        var spitze := p + Vector2(cos(w), sin(w) * 0.8) * weit
        draw_line(p, spitze, Color(warm.r, warm.g, warm.b,
            0.18 + 0.20 * hell + 0.08 * puls), 1.8)
        draw_circle(spitze, 2.8 + 1.6 * b.hitze,
            Color(1.0, 0.94, 0.72, 0.52 + 0.4 * hell))

    # Die Huelle. Sie oeffnet sich, waehrend die Bluete brennt - das ist die
    # Lebensanzeige, und sie braucht keinen Balken.
    for i in 6:
        var w := TAU * float(i) / 6.0 + b.alter * 0.2
        var mitte := p + Vector2(cos(w), sin(w) * 0.82) * r * (0.5 + 0.5 * offen)
        draw_circle(mitte, r * 0.36,
            Color(warm.r, warm.g, warm.b, 0.26 + 0.26 * hell + 0.1 * b.hitze))

    draw_circle(p, r * 1.5, Color(warm.r, warm.g, warm.b, 0.05 + 0.07 * hell))
    draw_circle(p, r * 0.9, Color(warm.r, warm.g, warm.b, 0.12 + 0.14 * hell))
    draw_circle(p, r * (0.30 + 0.05 * puls),
        Color(1.0, 0.90, 0.62, 0.75 + 0.25 * b.hitze))
    draw_circle(p, r * 0.14, Color(1.0, 1.0, 0.92, 0.95))


func _zeichne(t: Raeuber, stufe := 0) -> void:
    var p := t.ort
    var farbe: Color = Arten.farbe(t.art)
    var r: float = Wellen.radius_in(t.art, t.welle)

    # Wer im Licht steht, glueht auf. Das ist die einzige Rueckmeldung, die
    # der Spieler zum Zielen braucht - ohne sie sieht er nicht, wen er fasst.
    var hitze := t.hitze
    var puls := 1.0 + 0.18 * hitze

    # **Was brennt, zappelt.**
    #
    # Ein getroffenes Tier glomm bisher nur heller - es hing weiter still im
    # Strahl, als waere nichts. Das nimmt dem Treffen jede Wucht: der Spieler
    # sieht eine Farbe wechseln, aber nichts geschehen. Zwei Zeilen aendern
    # das, und zwar fuer alle neun Arten auf einmal, weil sie **vor** der
    # Verzweigung stehen: das Tier zittert quer zu seiner Bahn und blaeht sich
    # dabei leicht auf.
    #
    # Das Zittern haengt an der Wellenzeit und nicht am Alter des Tieres -
    # sonst zittern alle im Gleichtakt, und ein Schwarm im Gleichtakt sieht
    # aus wie ein Maschinenteil.
    #
    # **Und leise.** Der erste Anlauf zitterte mit 41 Hertz und einem Neuntel
    # des Koerperradius - bei zwanzig brennenden Tieren gleichzeitig war das
    # kein Zappeln mehr, sondern Rauschen ueber dem halben Bild. Das Spiel
    # soll man in Ruhe spielen koennen; eine Rueckmeldung, die den Blick
    # zerhackt, arbeitet gegen genau das. Halb so schnell, ein Drittel so
    # weit - man sieht es, ohne dass es sticht.
    if hitze > 0.01:
        var quer := t.richtung.orthogonal()
        p += quer * sin(_zeit * 19.0 + t.phase * 6.0) * hitze * r * 0.04
        r *= 1.0 + 0.04 * hitze

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
        Arten.Art.SPIEGLER:
            _spiegler(p, r, farbe, t, hitze)
        Arten.Art.SCHLUNDMUTTER:
            _schlundmutter(p, r, farbe, t, hitze)
        Arten.Art.KALKROCHEN:
            _kalkrochen(p, r, farbe, t, hitze)
        Arten.Art.SCHWARMHERZ:
            _schwarmherz(p, r, farbe, t, hitze)

    # Lebensanzeige nur bei Verletzten. Volle Balken ueber jedem Tier waeren
    # Rauschen; ein angeschlagener Gegner ist dagegen eine Entscheidung.
    _kielwasser(p, r, farbe, t)
    _randlicht(p, r, farbe, t)

    # Die Lebensanzeige erst, wenn es etwas zu entscheiden gibt.
    #
    # Vorher stand ueber jedem angekratzten Tier ein Balken - bei zwanzig
    # Raeubern im Bild zwanzig kleine Rechtecke, und das ist genau die Art
    # Unruhe, die einem das Spiel aus der Hand nimmt. Wer noch fast voll ist,
    # sagt einem nichts; interessant wird es unter zwei Dritteln. Und ein
    # Strich mit runden Enden liest sich als Teil des Tieres, ein Rechteck
    # als Bedienoberflaeche.
    var anteil := t.anteil()
    if anteil < 0.66:
        var breite := r * 1.5
        var y := p.y - r - 9.0
        var links := p.x - breite * 0.5
        draw_line(Vector2(links, y), Vector2(links + breite, y),
            Color(0.0, 0.0, 0.0, 0.42), 3.0)
        draw_line(Vector2(links, y), Vector2(links + breite * anteil, y),
            farbe.lerp(Color(1.0, 0.46, 0.38), 1.0 - anteil), 2.6)


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
    _fuellung(leib, Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.35 * hitze))
    _zug(leib + PackedVector2Array([leib[0]]),
        farbe.lerp(Color(1.0, 0.98, 0.94), 0.4 + 0.4 * hitze), 1.4)


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
## Ein Leib.
##
## **Zwei Dinge, und sie gelten fuer alle neun Arten**, weil fast jede diese
## Funktion aufruft. Das ist der Grund, warum sie hier stehen und nicht
## neunmal einzeln.
##
## **Erstens: rund.** Die Umrisse sind als Vielecke mit sechs bis neun Ecken
## gebaut - gut zu rechnen, aber im Bild sind es Sechsecke mit Streifen, und
## bei voller Aufloesung sieht man jede Facette. Zwei Durchgaenge
## Eckenschneiden machen daraus eine Kurve. Es ist derselbe Umriss, nur ohne
## die Ecken, die niemand gemeint hat.
##
## **Zweitens: Fuelle.** Eine Flaeche in einer Farbe ist ein Aufkleber. Drei
## ineinanderliegende Fassungen mit steigender Deckung geben demselben Umriss
## eine Mitte - das ist der billigste Weg zu einem Koerper, der eine
## Vorderseite hat.
func _koerper(punkte: PackedVector2Array, farbe: Color, hitze: float) -> void:
    var rund := _rund(_rund(punkte))
    var mitte := _mitte(rund)

    for i in 3:
        var t := float(i) / 2.0
        var schrumpf := lerpf(1.0, 0.52, t)
        var lage := PackedVector2Array()
        for v in rund:
            lage.append(mitte + (v - mitte) * schrumpf)
        _fuellung(lage, Color(farbe.r, farbe.g, farbe.b,
            (0.10 + 0.09 * t) + (0.10 + 0.07 * t) * hitze))

    var geschlossen := rund + PackedVector2Array([rund[0]])
    _zug(geschlossen, Color(farbe.r, farbe.g, farbe.b,
        0.26 + 0.28 * hitze), 3.4)
    _zug(geschlossen, farbe.lerp(Color(1.0, 0.98, 0.94),
        0.45 + 0.45 * hitze), 1.3)


## Eckenschneiden nach Chaikin: jede Kante gibt zwei Punkte auf einem Viertel
## und drei Vierteln ihrer Laenge her. Zweimal angewandt wird aus einem
## Siebeneck eine Kurve aus achtundzwanzig Punkten.
##
## Warum nicht gleich runde Umrisse zeichnen? Weil die Formen aus Richtung und
## Querachse des Tieres gebaut werden und dabei lesbar bleiben sollen - ein
## Siebeneck mit sprechenden Ecken ist im Quelltext zu verstehen, eine
## Bezierkurve mit vierzehn Stuetzpunkten nicht.
func _rund(punkte: PackedVector2Array) -> PackedVector2Array:
    var n := punkte.size()
    if n < 3:
        return punkte
    var aus := PackedVector2Array()
    for i in n:
        var a: Vector2 = punkte[i]
        var b: Vector2 = punkte[(i + 1) % n]
        aus.append(a + (b - a) * 0.25)
        aus.append(a + (b - a) * 0.75)
    return aus


func _mitte(punkte: PackedVector2Array) -> Vector2:
    var summe := Vector2.ZERO
    for v in punkte:
        summe += v
    return summe / float(maxi(1, punkte.size()))


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
    _fuellung(schwanz, Color(farbe.r, farbe.g, farbe.b, 0.28))
    _zug(schwanz + PackedVector2Array([schwanz[0]]),
        farbe.lightened(0.25), 1.2)

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
    _fuellung(schirm, Color(farbe.r, farbe.g, farbe.b,
        0.42 + 0.42 * hitze))
    _zug(schirm, farbe.lightened(0.45), 1.2)

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
        # Gedaempft, weil sich sieben Glieder additiv aufaddieren. Bei voller
        # Deckung je Glied wurde die Trench Adder im Licht zu einem weissen
        # Balken, in dem man ihre Form nicht mehr sah.
        draw_circle(glieder[i], dick,
            Color(farbe.r, farbe.g, farbe.b, 0.34 + 0.20 * hitze).darkened(0.3 * (1.0 - f)))

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
        _fuellung(platte, Color(farbe.r, farbe.g, farbe.b,
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
    _fuellung(schirm, Color(farbe.r, farbe.g, farbe.b,
        0.13 + 0.20 * hitze))
    _zug(schirm + PackedVector2Array([schirm[0]]),
        Color(farbe.r, farbe.g, farbe.b, 0.34 + 0.30 * hitze), 1.3)

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
    _zug(schleppe, Color(farbe.r, farbe.g, farbe.b, 0.34), 1.6)
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


## Der Kalkrochen. Ein flacher, breiter Schild mit einem Schleppschwanz -
## und die Panzerplatten sind das, was man von ihm sieht.
##
## **Er muss sich vom Mantel der Schlundmutter im Umriss unterscheiden**, nicht
## in der Farbe: zwei Leitwesen mit derselben Silhouette sind dasselbe Tier in
## zwei Anstrichen. Sie ist rund und gebuchtet, er ist eine Raute, die quer
## zur Bahn liegt und flach wirkt.
func _kalkrochen(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var schlag := sin(t.alter * 1.3 + t.phase)

    # Der Schwanz zuerst, damit der Schild darueber liegt.
    var schwanz := PackedVector2Array()
    for i in 7:
        var u := float(i) / 6.0
        schwanz.append(p - k * r * (0.5 + 2.0 * u)
            + quer * schlag * r * 0.34 * u * u)
    draw_polyline(schwanz, Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.24 * hitze),
        3.4)
    draw_circle(schwanz[schwanz.size() - 1], r * 0.09,
        Color(1.0, 0.96, 0.88, 0.40 + 0.40 * hitze))

    # Der Schild: breit quer zur Bahn, vorn stumpf, hinten spitz. Die
    # Wellenkante an den Flanken ist das, woran ein Rochen erkannt wird.
    var schild := PackedVector2Array()
    for i in 19:
        var u := lerpf(-1.0, 1.0, float(i) / 18.0)
        var laengs := (1.0 - u * u) * 0.86 - 0.14
        var flatter := 0.08 * sin(u * 5.4 + t.alter * 2.2)
        schild.append(p + k * r * laengs + quer * r * u * (1.36 + flatter))
    schild.append(p - k * r * 0.62)
    _koerper(schild, farbe, hitze)

    # **Die Platten sind seine Regel.** Dieselbe Bildsprache wie bei der
    # Schildkoralle: wer die kennt, liest hier ohne einen Satz Text, dass der
    # Rand des Kegels an ihm nichts ausrichtet.
    # **Als Fugen, nicht als helle Striche.** Weiss auf einem sandfarbenen
    # Leib bei zwanzig Prozent Deckung ist unsichtbar - im Bild war der
    # Kalkrochen eine glatte Raute, und seine einzige Regel stand nirgends.
    # Eine Platte erkennt man an ihrem Schatten und ihrer Oberkante, so wie
    # jede Fuge in jedem Material.
    # **Die Breite kommt aus derselben Kurve wie der Rumpf.** Vorher war sie
    # eine eigene Interpolation, und die stand an den Flanken ueber den
    # Umriss hinaus - im Bild ragten die Platten aus dem Tier heraus wie
    # Speichen. Zwei Beschreibungen derselben Form laufen auseinander, immer.
    for i in 5:
        var u := lerpf(0.26, 0.94, float(i) / 4.0)
        var y := (1.0 - u * u) * 0.86 - 0.14
        var halb := r * u * 1.30
        var a := p + k * r * y + quer * halb
        var b := p + k * r * y - quer * halb
        draw_line(a, b, Color(0.05, 0.04, 0.03, 0.55), 3.4)
        draw_line(a - k * 2.0, b - k * 2.0,
            Color(1.0, 0.98, 0.92, 0.30 + 0.40 * hitze), 1.8)

    for seite: float in SEITEN:
        _auge(p + k * r * 0.44 + quer * r * seite * 0.30, r * 0.11, hitze)


## Das Schwarmherz. Ein Kern, um den ein Ring aus Trabanten kreist - kein
## Panzer, dafuer eine Bahn, die weit ausschlaegt.
##
## Der Ring ist kein Schmuck: er dreht sich mit der Zeit und macht damit
## sichtbar, dass dieses Tier **nicht stillsteht**. Genau das ist seine
## Schwierigkeit, und ein Leitwesen soll man ansehen und wissen, woran man ist.
func _schwarmherz(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var dreh := t.alter * 1.4 + t.phase

    for i in 9:
        var w := TAU * float(i) / 9.0 + dreh
        var weit := r * (1.02 + 0.20 * sin(dreh * 1.7 + float(i)))
        var wo := p + Vector2(cos(w), sin(w) * 0.72) * weit
        draw_line(p, wo, Color(farbe.r, farbe.g, farbe.b, 0.13 + 0.10 * hitze), 1.4)
        draw_circle(wo, r * 0.13,
            Color(farbe.r, farbe.g, farbe.b, 0.34 + 0.34 * hitze))
        draw_circle(wo, r * 0.055, Color(0.92, 1.0, 0.96, 0.55 + 0.35 * hitze))

    var kern := PackedVector2Array()
    for i in 15:
        var w := TAU * float(i) / 15.0
        var zerre := 1.0 + 0.16 * sin(float(i) * 2.1 + t.alter * 2.6)
        kern.append(p + Vector2(cos(w), sin(w) * 0.82) * r * 0.62 * zerre)
    _koerper(kern, farbe, hitze)

    _auge(p, r * 0.17, hitze)


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
    var tempo: float = Wellen.tempo_in(t.art, t.welle)
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


## Der Spiegler.
##
## **Seine Zeichnung erklaert seine Regel.** Er brennt nur im Randlicht; im
## Kern des Kegels prallt der Strahl ab. Genau das ist zu sehen: je heller er
## steht, desto groesser das Glanzlicht auf seiner Schale - er blendet am
## staerksten in dem Augenblick, in dem er unverwundbar ist. Wer ihn einmal in
## den Kern genommen hat und nichts geschehen sah, hat die Regel gelernt, ohne
## sie zu lesen.
##
## Die Schale ist facettiert, weil eine glatte Kuppel wie eine Blase aussieht
## und eine Blase nichts zurueckwirft. Sechs Felder genuegen; bei zwoelf ist
## es wieder eine Kuppel.
func _spiegler(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()

    # Die Schale: breit quer zur Bahn, vorn gerundet, hinten offen.
    var schale := PackedVector2Array([
        p + k * r * 0.86,
        p + k * r * 0.34 + quer * r * 0.92,
        p - k * r * 0.42 + quer * r * 0.80,
        p - k * r * 0.72,
        p - k * r * 0.42 - quer * r * 0.80,
        p + k * r * 0.34 - quer * r * 0.92,
    ])
    _koerper(schale, farbe, hitze)

    # Facetten: Grate vom Rand zur Mitte. Sie tragen den Glanz.
    for i in 5:
        var u := lerpf(-0.86, 0.86, float(i) / 4.0)
        var aussen := p + k * r * 0.30 + quer * r * u * 0.95
        draw_line(p + k * r * 0.05, aussen,
            Color(farbe.r, farbe.g, farbe.b, 0.20 + 0.22 * hitze), 1.2)

    # **Das Glanzlicht haengt an `t.licht`, nicht an `hitze`.**
    #
    # `hitze` sagt "wurde getroffen", `licht` sagt "steht im Strahl". Fuer
    # jedes andere Tier ist das fast dasselbe; fuer den Spiegler ist es der
    # ganze Unterschied. Im Kern steht er hell und nimmt nichts - also glaenzt
    # er dort, und nur dort.
    var blenden := clampf((t.licht - Wellen.hoechst_licht_in(t.art, t.welle))
        / 0.45, 0.0, 1.0)
    if blenden > 0.01:
        var glanz := p + k * r * 0.20
        draw_circle(glanz, r * (0.30 + 0.85 * blenden),
            Color(0.86, 0.94, 1.0, 0.14 * blenden))
        draw_circle(glanz, r * (0.16 + 0.34 * blenden),
            Color(1.0, 1.0, 1.0, 0.42 * blenden))
        # Ein kurzer Strahl zurueck zum Waechter - das Licht kommt von dort,
        # also geht es auch dorthin zurueck.
        var heim := (Graben.WAECHTER - p).normalized()
        draw_line(glanz, glanz + heim * r * (0.8 + 1.6 * blenden),
            Color(0.92, 0.98, 1.0, 0.30 * blenden), 1.6)

    _auge(p + k * r * 0.46, r * 0.13, hitze)
