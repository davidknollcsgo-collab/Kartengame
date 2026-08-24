## Silhouetten der acht Versorgungsstationen.
##
## Jede Station sieht nach ihrer Aufgabe aus: das Solarsegel spannt Flächen
## auf, der Schmelzofen hat Abgasschlote, das Frachtdock hält Container. Eine
## Karte mit Beschriftung sagt dasselbe, aber man muss sie lesen - eine
## Silhouette erkennt man im Vorbeiwischen.
##
## Alles wird gezeichnet, nichts geladen. Die Ausbaustufe wächst sichtbar mit:
## mehr Segel, mehr Container, mehr Schlote. So sieht man einer Station an, wie
## weit sie ist, ohne die Zahl zu lesen.
class_name Bauform
extends RefCounted

## Halbe Kantenlänge, auf die alle Formen ausgelegt sind.
const MASS := 62.0


## Zeichnet die Station [param index] im Ursprung von [param ci].
static func zeichne(ci: CanvasItem, index: int, farbe: Color, stufe: int,
        aktiv: bool, zeit: float) -> void:
    var rumpf := Color(0.14, 0.16, 0.21) if aktiv else Color(0.10, 0.11, 0.14)
    var kante := farbe if aktiv else farbe.darkened(0.62)
    var glut := farbe.lightened(0.25) if aktiv else farbe.darkened(0.45)
    var puls := 0.5 + 0.5 * sin(zeit * 1.8 + float(index))

    match index:
        0: _solarsegel(ci, rumpf, kante, glut, stufe, puls)
        1: _drohnenbucht(ci, rumpf, kante, glut, stufe, puls)
        2: _schmelzofen(ci, rumpf, kante, glut, stufe, puls)
        3: _hydroponik(ci, rumpf, kante, glut, stufe, puls)
        4: _werkstatt(ci, rumpf, kante, glut, stufe, zeit)
        5: _reaktor(ci, rumpf, kante, glut, stufe, zeit)
        6: _frachtdock(ci, rumpf, kante, glut, stufe, puls)
        7: _labor(ci, rumpf, kante, glut, stufe, zeit)


# --- Hilfen -----------------------------------------------------------------

static func _kasten(ci: CanvasItem, r: Rect2, fuellung: Color, kante: Color,
        staerke: float = 1.6) -> void:
    ci.draw_rect(r, fuellung)
    ci.draw_rect(r, kante, false, staerke)


static func _polygon(ci: CanvasItem, punkte: PackedVector2Array,
        fuellung: Color, kante: Color, staerke: float = 1.6) -> void:
    ci.draw_colored_polygon(punkte, fuellung)
    var u := PackedVector2Array(punkte)
    u.append(punkte[0])
    ci.draw_polyline(u, kante, staerke, true)


# --- Die acht Stationen -----------------------------------------------------

## Solarsegel: schmaler Mast, davon abstehend große Flächen.
## Jede Ausbaustufe hängt ein weiteres Segelpaar an.
static func _solarsegel(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, puls: float) -> void:
    var paare := 2 + mini(stufe / 3, 3)
    var hoehe := MASS * 1.5
    var schritt := hoehe / float(paare + 1)

    _kasten(ci, Rect2(-9.0, -hoehe * 0.5, 18.0, hoehe), rumpf, kante)

    for i in paare:
        var y := -hoehe * 0.5 + schritt * float(i + 1)
        for seite: float in [-1.0, 1.0]:
            var segel := Rect2(seite * 9.0 - (0.0 if seite > 0.0 else MASS * 0.86),
                y - schritt * 0.32, MASS * 0.86, schritt * 0.64)
            _kasten(ci, segel, Color(rumpf.r, rumpf.g, rumpf.b, 0.9), kante, 1.3)
            # Zellenraster auf der Fläche.
            for k in 3:
                var x := segel.position.x + segel.size.x * (0.25 + 0.25 * float(k))
                ci.draw_line(Vector2(x, segel.position.y + 2.0),
                    Vector2(x, segel.end.y - 2.0), Color(kante.r, kante.g, kante.b, 0.35), 1.0)
            ci.draw_line(Vector2(segel.position.x, segel.get_center().y),
                Vector2(segel.end.x, segel.get_center().y),
                Color(glut.r, glut.g, glut.b, 0.25 + 0.35 * puls), 1.2, true)

    ci.draw_circle(Vector2(0.0, -hoehe * 0.5 - 6.0), 4.0 + 1.5 * puls, glut)


## Drohnenbucht: Hangar mit offenem Tor und Landeplattformen.
static func _drohnenbucht(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, puls: float) -> void:
    var b := MASS * 1.5
    var h := MASS * 1.05
    _kasten(ci, Rect2(-b * 0.5, -h * 0.5, b, h), rumpf, kante)

    # Torhälften, leicht geöffnet.
    for seite: float in [-1.0, 1.0]:
        _polygon(ci, PackedVector2Array([
            Vector2(seite * b * 0.5, -h * 0.28),
            Vector2(seite * b * 0.16, -h * 0.42),
            Vector2(seite * b * 0.16, h * 0.42),
            Vector2(seite * b * 0.5, h * 0.28),
        ]), Color(0.09, 0.10, 0.13), kante, 1.3)

    # Landeplattformen, eine je zwei Ausbaustufen.
    var plaetze := 2 + mini(stufe / 2, 3)
    for i in plaetze:
        var t := (float(i) + 0.5) / float(plaetze)
        var p := Vector2(-b * 0.5 + b * t, 0.0)
        ci.draw_arc(p, 7.0, 0.0, TAU, 12, Color(kante.r, kante.g, kante.b, 0.55), 1.2, true)
        ci.draw_circle(p, 2.4, Color(glut.r, glut.g, glut.b, 0.4 + 0.5 * puls))


## Schmelzofen: gedrungener Körper mit Schloten und glühendem Schmelzraum.
static func _schmelzofen(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, puls: float) -> void:
    var b := MASS * 1.25
    var h := MASS * 1.0
    _polygon(ci, PackedVector2Array([
        Vector2(-b * 0.5, -h * 0.36), Vector2(-b * 0.34, -h * 0.5),
        Vector2(b * 0.34, -h * 0.5), Vector2(b * 0.5, -h * 0.36),
        Vector2(b * 0.5, h * 0.36), Vector2(b * 0.34, h * 0.5),
        Vector2(-b * 0.34, h * 0.5), Vector2(-b * 0.5, h * 0.36),
    ]), rumpf, kante)

    # Schmelzraum: glüht im Takt.
    var kern := Rect2(-b * 0.22, -h * 0.24, b * 0.44, h * 0.48)
    ci.draw_rect(kern, Color(glut.r, glut.g, glut.b, 0.18 + 0.30 * puls))
    ci.draw_rect(kern, glut, false, 1.4)
    for i in 3:
        var y := kern.position.y + kern.size.y * (0.25 + 0.25 * float(i))
        ci.draw_line(Vector2(kern.position.x + 3.0, y), Vector2(kern.end.x - 3.0, y),
            Color(glut.r, glut.g, glut.b, 0.35 + 0.4 * puls), 1.6, true)

    # Abgasschlote oben, einer je zwei Stufen.
    var schlote := 2 + mini(stufe / 2, 3)
    for i in schlote:
        var t := (float(i) + 0.5) / float(schlote)
        var x := -b * 0.42 + b * 0.84 * t
        _kasten(ci, Rect2(x - 4.0, -h * 0.5 - 12.0, 8.0, 13.0), rumpf, kante, 1.2)
        ci.draw_circle(Vector2(x, -h * 0.5 - 13.0), 2.6,
            Color(glut.r, glut.g, glut.b, 0.30 + 0.45 * puls))


## Hydroponik: Kuppel mit Segmentfenstern und Bewuchs darunter.
static func _hydroponik(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, puls: float) -> void:
    var r := MASS * 0.72
    ci.draw_circle(Vector2.ZERO, r, rumpf)
    ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, kante, 2.0, true)

    # Segmentstreben der Kuppel.
    for i in 6:
        var a := TAU * float(i) / 6.0
        ci.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * r,
            Color(kante.r, kante.g, kante.b, 0.45), 1.2, true)
    ci.draw_arc(Vector2.ZERO, r * 0.58, 0.0, TAU, 30,
        Color(kante.r, kante.g, kante.b, 0.5), 1.2, true)

    # Beete: wachsen mit der Ausbaustufe.
    var beete := 3 + mini(stufe, 5)
    for i in beete:
        var a := TAU * float(i) / float(beete) + 0.4
        var p := Vector2(cos(a), sin(a)) * r * 0.42
        ci.draw_circle(p, 5.0, Color(glut.r, glut.g, glut.b, 0.25 + 0.35 * puls))
        ci.draw_arc(p, 5.0, 0.0, TAU, 12, glut, 1.1, true)

    # Sockel unten, damit die Kuppel steht statt zu schweben.
    _kasten(ci, Rect2(-r * 0.55, r * 0.72, r * 1.1, 12.0), rumpf, kante, 1.3)


## Werkstatt: offener Rahmen mit Greifarmen um ein Werkstück.
static func _werkstatt(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, zeit: float) -> void:
    var b := MASS * 1.35
    var h := MASS * 1.0

    # Rahmen: vier Ecken, offene Mitte.
    for ex: float in [-1.0, 1.0]:
        for ey: float in [-1.0, 1.0]:
            _kasten(ci, Rect2(ex * b * 0.5 - (11.0 if ex > 0.0 else 0.0),
                ey * h * 0.5 - (11.0 if ey > 0.0 else 0.0), 11.0, 11.0),
                rumpf, kante, 1.3)
    for ey: float in [-1.0, 1.0]:
        ci.draw_line(Vector2(-b * 0.5, ey * h * 0.5), Vector2(b * 0.5, ey * h * 0.5),
            kante, 1.6, true)
    for ex: float in [-1.0, 1.0]:
        ci.draw_line(Vector2(ex * b * 0.5, -h * 0.5), Vector2(ex * b * 0.5, h * 0.5),
            kante, 1.6, true)

    # Werkstück in der Mitte.
    _kasten(ci, Rect2(-13.0, -13.0, 26.0, 26.0),
        Color(glut.r, glut.g, glut.b, 0.16), glut, 1.5)

    # Greifarme, einer je zwei Stufen. Sie schwenken langsam.
    var arme := 2 + mini(stufe / 2, 3)
    for i in arme:
        var grund := TAU * float(i) / float(arme)
        var a := grund + sin(zeit * 0.9 + float(i)) * 0.30
        var von := Vector2(cos(grund), sin(grund)) * (b * 0.42)
        var gelenk := von.lerp(Vector2.ZERO, 0.42)
        var spitze := Vector2(cos(a), sin(a)) * 18.0
        ci.draw_line(von, gelenk, kante, 2.2, true)
        ci.draw_line(gelenk, spitze, kante, 1.8, true)
        ci.draw_circle(gelenk, 2.8, kante)


## Fusionsreaktor: Torus mit Feldspulen und hellem Kern.
static func _reaktor(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, zeit: float) -> void:
    var r := MASS * 0.78
    ci.draw_circle(Vector2.ZERO, r, rumpf)
    ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 44, kante, 2.2, true)
    ci.draw_arc(Vector2.ZERO, r * 0.52, 0.0, TAU, 30, kante, 1.6, true)

    # Feldspulen rund um den Torus; mehr Spulen je Ausbaustufe.
    var spulen := 6 + mini(stufe, 6)
    for i in spulen:
        var a := TAU * float(i) / float(spulen)
        var innen := Vector2(cos(a), sin(a)) * r * 0.52
        var aussen := Vector2(cos(a), sin(a)) * r
        ci.draw_line(innen, aussen, Color(kante.r, kante.g, kante.b, 0.7), 3.0, true)

    # Umlaufendes Plasma im Ring.
    for i in 3:
        var a := zeit * 1.7 + TAU * float(i) / 3.0
        var p := Vector2(cos(a), sin(a)) * r * 0.76
        ci.draw_circle(p, 4.0, Color(glut.r, glut.g, glut.b, 0.75))
        ci.draw_circle(p, 9.0, Color(glut.r, glut.g, glut.b, 0.18))

    var kern := 0.75 + 0.25 * sin(zeit * 3.0)
    ci.draw_circle(Vector2.ZERO, r * 0.30 * kern, glut)
    ci.draw_circle(Vector2.ZERO, r * 0.46, Color(glut.r, glut.g, glut.b, 0.20))


## Frachtdock: Trägerbalken mit angedockten Containern.
static func _frachtdock(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, puls: float) -> void:
    var b := MASS * 1.6
    _kasten(ci, Rect2(-b * 0.5, -7.0, b, 14.0), rumpf, kante)

    # Container ober- und unterhalb des Balkens.
    var reihen := 2 + mini(stufe / 3, 2)
    var proReihe := 4
    for reihe in reihen:
        var oben := reihe % 2 == 0
        var abstand := 9.0 + float(reihe / 2) * 20.0
        for i in proReihe:
            var t := (float(i) + 0.5) / float(proReihe)
            var x := -b * 0.5 + b * t
            var y := (-abstand - 17.0) if oben else abstand
            var c := Rect2(x - 15.0, y, 30.0, 17.0)
            _kasten(ci, c, Color(rumpf.r, rumpf.g, rumpf.b, 0.95), kante, 1.2)
            ci.draw_line(Vector2(c.position.x + 4.0, c.get_center().y),
                Vector2(c.end.x - 4.0, c.get_center().y),
                Color(kante.r, kante.g, kante.b, 0.4), 1.0)
            # Halteklammer zum Balken.
            ci.draw_line(Vector2(x, y + (17.0 if oben else 0.0)),
                Vector2(x, -7.0 if oben else 7.0), kante, 1.2, true)

    ci.draw_circle(Vector2(-b * 0.5 + 6.0, 0.0), 3.2,
        Color(glut.r, glut.g, glut.b, 0.4 + 0.5 * puls))
    ci.draw_circle(Vector2(b * 0.5 - 6.0, 0.0), 3.2,
        Color(glut.r, glut.g, glut.b, 0.4 + 0.5 * puls))


## Forschungslabor: Laborkörper mit Parabolschüssel und Messausleger.
static func _labor(ci: CanvasItem, rumpf: Color, kante: Color, glut: Color,
        stufe: int, zeit: float) -> void:
    var b := MASS * 1.15
    var h := MASS * 0.72
    _kasten(ci, Rect2(-b * 0.5, -h * 0.5, b, h), rumpf, kante)
    for i in 2:
        var y := -h * 0.5 + h * (0.33 + 0.34 * float(i))
        ci.draw_line(Vector2(-b * 0.5 + 4.0, y), Vector2(b * 0.5 - 4.0, y),
            Color(kante.r, kante.g, kante.b, 0.35), 1.0)

    # Schüssel oben, schwenkt langsam.
    var schwenk := sin(zeit * 0.5) * 0.28
    var mitte := Vector2(0.0, -h * 0.5 - 20.0)
    ci.draw_line(Vector2(0.0, -h * 0.5), mitte, kante, 2.0, true)
    var schuessel := PackedVector2Array()
    for i in 13:
        var a := PI + schwenk - 0.9 + 1.8 * float(i) / 12.0
        schuessel.append(mitte + Vector2(cos(a), sin(a)) * 21.0)
    schuessel.append(mitte)
    _polygon(ci, schuessel, Color(rumpf.r, rumpf.g, rumpf.b, 0.9), kante, 1.4)
    ci.draw_circle(mitte + Vector2(sin(schwenk), -cos(schwenk)) * 9.0, 3.0, glut)

    # Messausleger, einer je zwei Stufen.
    var ausleger := 1 + mini(stufe / 2, 3)
    for i in ausleger:
        var seite := 1.0 if i % 2 == 0 else -1.0
        var y := h * 0.18 + float(i / 2) * 13.0
        ci.draw_line(Vector2(seite * b * 0.5, y),
            Vector2(seite * (b * 0.5 + 18.0), y + 6.0), kante, 1.5, true)
        ci.draw_circle(Vector2(seite * (b * 0.5 + 18.0), y + 6.0), 2.6,
            Color(glut.r, glut.g, glut.b, 0.75))
