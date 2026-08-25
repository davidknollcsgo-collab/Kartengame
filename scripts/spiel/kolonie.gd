extends Node2D

## Alles, was zur Kolonie gehoert und nicht laeuft: Grabenwaende, Nischen,
## Wehrpolypen, der Waechter und die Brut.
##
## Ein Knoten statt fuenf, weil alles davon still steht und sich nur bei
## Aenderungen neu zeichnet. Fuer Beweglichkeit gibt es `schwarm.gd`.

## Von `wache.gd` gefuehrt.
var polypen: Array[Vector2] = []
var brut: int = Graben.BRUT_LEBEN
var brut_voll: int = Graben.BRUT_LEBEN
var naehrstoffe: int = 0
var bauphase := false
var zeit := 0.0

const FELS := Color(0.055, 0.085, 0.110)
const FELS_KANTE := Color(0.10, 0.17, 0.20)
const BRUT_FARBE := Color(0.98, 0.80, 0.42)
const POLYP_FARBE := Color(0.52, 0.94, 0.80)

## Links und rechts - als Konstante, weil ein Feldliteral in einer
## for-Schleife seinen Typ verliert und jede Ableitung daraus mit.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]

var _wand_links := PackedVector2Array()
var _wand_rechts := PackedVector2Array()


func _ready() -> void:
    _baue_waende()


func _process(delta: float) -> void:
    zeit += delta
    queue_redraw()


## Die Grabenwaende. Einmal aus einer festen Saat gezogen, damit sie ueber
## Sitzungen hinweg gleich aussehen - eine Hoehle, die sich bei jedem Start
## anders faltet, wirkt nicht wie ein Ort.
func _baue_waende() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x4e454b7f
    var oben := Graben.FELD.position.y - 200.0
    var unten := Graben.FELD.end.y + 200.0
    var schritte := 26

    for seite: float in SEITEN:
        var punkte := PackedVector2Array()
        var aussen := seite * (Graben.FELD.size.x * 0.5 + 220.0)
        punkte.append(Vector2(aussen, oben))
        for i in schritte + 1:
            var t := float(i) / float(schritte)
            var y := lerpf(oben, unten, t)
            # Zwei ueberlagerte Wellen: eine grosse fuer die Form des Grabens,
            # eine kleine fuer die Zerklueftung.
            var tief := 306.0 \
                + sin(t * 5.1 + seite * 1.7) * 34.0 \
                + sin(t * 13.7 + seite * 4.2) * 13.0 \
                + rng.randf_range(-9.0, 9.0)
            punkte.append(Vector2(seite * tief, y))
        punkte.append(Vector2(aussen, unten))
        if seite < 0.0:
            _wand_links = punkte
        else:
            _wand_rechts = punkte


func _draw() -> void:
    _zeichne_wand(_wand_links)
    _zeichne_wand(_wand_rechts)
    _zeichne_nischen()
    _zeichne_polypen()
    _zeichne_brut()
    _zeichne_waechter()


func _zeichne_wand(punkte: PackedVector2Array) -> void:
    if punkte.is_empty():
        return
    draw_colored_polygon(punkte, FELS)
    # Nur die Innenkante zeichnen - die Aussenkante liegt ausserhalb des Bildes.
    var kante := punkte.slice(1, punkte.size() - 1)
    draw_polyline(kante, FELS_KANTE, 2.6, true)
    # Leuchtflechten auf dem Fels. Setzt Farbe in die Dunkelheit, ohne dass
    # der Spieler sie fuer etwas Spielbares haelt.
    for i in range(1, kante.size(), 3):
        var p := kante[i]
        var puls := 0.5 + 0.5 * sin(zeit * 0.7 + float(i) * 1.9)
        draw_circle(p, 2.2 + puls * 1.4, Color(0.24, 0.64, 0.72, 0.20 + 0.16 * puls))


func _zeichne_nischen() -> void:
    for i in Graben.NISCHEN.size():
        var p := Graben.NISCHEN[i]
        if i < polypen.size():
            continue
        var frei := bauphase and naehrstoffe >= Graben.polyp_kosten(polypen.size())
        var puls := 0.5 + 0.5 * sin(zeit * 3.0 + float(i))
        var deckung := 0.16 + (0.30 * puls if frei else 0.0)
        draw_circle(p, Graben.POLYP_RADIUS * 1.5, Color(0.20, 0.42, 0.46, deckung * 0.5))
        draw_arc(p, Graben.POLYP_RADIUS, 0.0, TAU, 20,
            Color(0.42, 0.78, 0.82, deckung + 0.14), 1.8, true)
        if frei:
            # Ein Kreuz, das nur waehrend der Bauphase erscheint. Waehrend der
            # Welle darf hier nichts blinken - der Blick gehoert dem Schlund.
            draw_line(p - Vector2(5.0, 0.0), p + Vector2(5.0, 0.0),
                Color(0.72, 1.0, 0.92, 0.5 + 0.4 * puls), 1.8)
            draw_line(p - Vector2(0.0, 5.0), p + Vector2(0.0, 5.0),
                Color(0.72, 1.0, 0.92, 0.5 + 0.4 * puls), 1.8)


func _zeichne_polypen() -> void:
    for i in polypen.size():
        var p := polypen[i]
        var puls := 0.5 + 0.5 * sin(zeit * 2.1 + float(i) * 0.8)

        # Reichweite nur andeuten - ein voller Kreis je Polyp waere ein Netz
        # aus Linien ueber dem halben Bild.
        draw_arc(p, Graben.POLYP_REICHWEITE, 0.0, TAU, 42,
            Color(POLYP_FARBE.r, POLYP_FARBE.g, POLYP_FARBE.b, 0.055), 1.0, true)

        # Stiel zur Wand, damit der Polyp gewachsen wirkt und nicht schwebt.
        var wand := Vector2(signf(p.x) * (absf(p.x) + 26.0), p.y + 8.0)
        draw_line(p, wand, POLYP_FARBE.darkened(0.55), 4.0)

        # Kelch aus Tentakeln.
        for k in 7:
            var w := TAU * float(k) / 7.0 + sin(zeit * 1.3 + float(i)) * 0.2
            var spitze := p + Vector2(cos(w), sin(w)) * Graben.POLYP_RADIUS * 1.5
            draw_line(p, spitze, Color(POLYP_FARBE.r, POLYP_FARBE.g,
                POLYP_FARBE.b, 0.55), 2.0)
            draw_circle(spitze, 1.8, Color(0.85, 1.0, 0.95, 0.7))

        draw_circle(p, Graben.POLYP_RADIUS * (0.62 + 0.08 * puls),
            Color(POLYP_FARBE.r, POLYP_FARBE.g, POLYP_FARBE.b, 0.85))
        draw_circle(p, Graben.POLYP_RADIUS * 1.9,
            Color(POLYP_FARBE.r, POLYP_FARBE.g, POLYP_FARBE.b, 0.10 + 0.05 * puls))


func _zeichne_brut() -> void:
    # Die Brut ist eine Reihe Eier. Jedes steht fuer einen Lebenspunkt -
    # dadurch braucht es keine Zahl, um zu sehen, wie es steht.
    var breite := Graben.BRUT_BREITE
    var links := -breite * 0.5
    var abstand := breite / float(maxi(1, brut_voll - 1))

    draw_line(Vector2(links - 30.0, Graben.BRUT_Y + 26.0),
        Vector2(-links + 30.0, Graben.BRUT_Y + 26.0),
        Color(0.14, 0.26, 0.28, 0.8), 5.0)

    for i in brut_voll:
        var p := Vector2(links + abstand * float(i), Graben.BRUT_Y)
        if i < brut:
            var puls := 0.5 + 0.5 * sin(zeit * 1.7 + float(i) * 0.6)
            draw_circle(p, 12.0, Color(BRUT_FARBE.r, BRUT_FARBE.g, BRUT_FARBE.b,
                0.10 + 0.07 * puls))
            draw_circle(p, 6.4, BRUT_FARBE)
            draw_circle(p, 3.0, Color(1.0, 0.96, 0.86, 0.9))
        else:
            # Zerbrochen: nur noch die leere Schale.
            draw_arc(p, 6.0, 0.35, PI - 0.35, 10, Color(0.34, 0.30, 0.26, 0.7), 1.6)


func _zeichne_waechter() -> void:
    var p := Graben.WAECHTER
    var puls := 0.5 + 0.5 * sin(zeit * 1.1)

    # Ein festgewachsener Koerper mit dem Leuchtorgan obenauf. Kein Gesicht,
    # keine Gliedmassen - das Tier soll wie Teil der Kolonie wirken.
    var leib := PackedVector2Array([
        Vector2(-34.0, 44.0), Vector2(-20.0, -8.0), Vector2(-9.0, -22.0),
        Vector2(9.0, -22.0), Vector2(20.0, -8.0), Vector2(34.0, 44.0),
    ])
    var verschoben := PackedVector2Array()
    for v in leib:
        verschoben.append(p + v)
    draw_colored_polygon(verschoben, Color(0.10, 0.22, 0.26))
    draw_polyline(verschoben, Color(0.26, 0.52, 0.58, 0.9), 2.0, true)

    for i in 5:
        var s := lerpf(-24.0, 24.0, float(i) / 4.0)
        var wurzel := p + Vector2(s, 40.0)
        draw_line(wurzel, wurzel + Vector2(sin(zeit * 0.9 + float(i)) * 5.0, 22.0),
            Color(0.18, 0.40, 0.44, 0.7), 3.0)

    draw_circle(p + Vector2(0.0, -18.0), 9.0 + puls * 1.5,
        Color(0.70, 0.98, 1.0, 0.85))
