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

## --- Tiefe ---
##
## Der Graben war eine Ebene: ein Verlauf, zwei Wandflaechen, fertig. Tiefe
## entsteht nicht aus mehr Farbe, sondern daraus, dass Dinge **voreinander**
## liegen. Deshalb drei Wandebenen statt einer: je weiter hinten, desto
## dunkler, desto naeher an der Mitte und desto langsamer bewegt.
##
## Der Versatz ist der ganze Trick. Zwei Waende in derselben Ebene sind eine
## Zeichnung; drei in verschiedenen Ebenen sind ein Raum.
const EBENEN := 3

## Wie weit jede Ebene gegenueber der vordersten nach innen rueckt.
const EBENE_EINZUG: PackedFloat32Array = [168.0, 84.0, 0.0]

## Und wieviel Dunst zwischen ihr und dem Auge liegt.
##
## **Das war zuerst falsch herum.** Der erste Entwurf machte ferne Ebenen
## dunkler - so macht man es an Land, wo Entfernung Licht schluckt. Im Wasser
## ist es umgekehrt: die Strecke dazwischen streut selbst, also wird alles
## Ferne **heller und blauer**, bis es im Dunst verschwindet. Genau das ist
## der Grund, warum ein Taucher Tiefe sieht und ein Bild ohne diesen Effekt
## flach aussieht, egal wie viele Ebenen darin stecken.
const EBENE_DUNST: PackedFloat32Array = [0.86, 0.46, 0.0]

## Die Farbe, in der sich die Ferne aufloest - dieselbe, die der Wassershader
## in mittlerer Hoehe zeigt.
const DUNST := Color(0.052, 0.118, 0.146)

## Wie schnell eine Ebene treibt. Die hintere kriecht, die vordere zieht -
## dasselbe Mittel wie in jedem Seitscroller, nur senkrecht.
const EBENE_TEMPO: PackedFloat32Array = [1.6, 4.2, 0.0]

## Links und rechts - als Konstante, weil ein Feldliteral in einer
## for-Schleife seinen Typ verliert und jede Ableitung daraus mit.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]

var _wand_links := PackedVector2Array()
var _wand_rechts := PackedVector2Array()

## Die hinteren Wandebenen, je Ebene links und rechts.
var _fernwaende: Array[PackedVector2Array] = []

## Felsvorspruenge, die quer in den Graben ragen. Sie brechen die senkrechte
## Flucht - ohne sie sieht ein Graben aus wie ein Korridor.
var _vorspruenge: Array[Dictionary] = []

## Bewuchs auf dem Fels: Buescheln aus Roehren, keine einzelnen Punkte. Ein
## Punkt ist ein Fehler im Bild, ein Buschel ist ein Lebewesen.
var _bewuchs: Array[Dictionary] = []

## Der Kegel, um Fels und Bewuchs von ihm anleuchten zu lassen. Gesetzt von
## `wache.gd`. Dieselbe `Schlund.beleuchtung()` wie ueberall - was hell
## gezeichnet wird, ist das Licht, das auch Schaden macht.
var kegel: Node2D = null


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

    _fernwaende.clear()
    for ebene in EBENEN:
        for seite: float in SEITEN:
            _fernwaende.append(_wandprofil(seite, EBENE_EINZUG[ebene], ebene, rng))

    _wand_links = _fernwaende[(EBENEN - 1) * 2]
    _wand_rechts = _fernwaende[(EBENEN - 1) * 2 + 1]

    _baue_vorspruenge(rng)
    _baue_bewuchs(rng)


## Ein Wandprofil. `einzug` schiebt es zur Mitte, `ebene` waehlt die
## Zerklueftung - hintere Ebenen sind glatter, weil Entfernung Kanten frisst.
func _wandprofil(seite: float, einzug: float, ebene: int,
        rng: RandomNumberGenerator) -> PackedVector2Array:
    var oben := Graben.FELD.position.y - 400.0
    var unten := Graben.FELD.end.y + 400.0
    var schritte := 30
    var schaerfe := 0.35 + 0.65 * float(ebene) / float(maxi(1, EBENEN - 1))

    var punkte := PackedVector2Array()
    var aussen := seite * (Graben.FELD.size.x * 0.5 + 260.0)
    punkte.append(Vector2(aussen, oben))
    for i in schritte + 1:
        var t := float(i) / float(schritte)
        var y := lerpf(oben, unten, t)
        # Drei ueberlagerte Wellen: Grabenform, Zerklueftung, Feinkante.
        var tief := 306.0 - einzug \
            + sin(t * 5.1 + seite * 1.7 + float(ebene) * 2.1) * 34.0 * schaerfe \
            + sin(t * 13.7 + seite * 4.2 + float(ebene) * 1.3) * 13.0 * schaerfe \
            + sin(t * 31.0 + seite * 2.9) * 5.0 * schaerfe \
            + rng.randf_range(-9.0, 9.0) * schaerfe
        punkte.append(Vector2(seite * tief, y))
    punkte.append(Vector2(aussen, unten))
    return punkte


## Felsvorspruenge: flache Keile, die aus der Wand in den Graben ragen. Sie
## liegen zwischen den Ebenen, damit man an ihnen die Tiefe abliest.
func _baue_vorspruenge(rng: RandomNumberGenerator) -> void:
    _vorspruenge.clear()
    for i in 9:
        var seite: float = SEITEN[i % 2]
        var y := lerpf(Graben.FELD.position.y - 260.0, Graben.FELD.end.y + 120.0,
            float(i) / 8.0) + rng.randf_range(-40.0, 40.0)
        var ebene := i % EBENEN
        var laenge := rng.randf_range(58.0, 132.0) * (0.55 + 0.45 * float(ebene) / 2.0)
        var hoehe := rng.randf_range(26.0, 62.0)
        var wurzel := seite * (306.0 - EBENE_EINZUG[ebene] + 8.0)
        _vorspruenge.append({
            &"ebene": ebene,
            &"punkte": PackedVector2Array([
                Vector2(wurzel, y - hoehe),
                Vector2(wurzel - seite * laenge, y - hoehe * 0.24),
                Vector2(wurzel - seite * laenge * 0.72, y + hoehe * 0.42),
                Vector2(wurzel, y + hoehe),
            ]),
        })


## Bewuchs: Buescheln aus Roehren auf der vordersten Wand. Sie leuchten von
## sich aus schwach und **zusaetzlich**, wenn der Kegel sie streift.
func _baue_bewuchs(rng: RandomNumberGenerator) -> void:
    _bewuchs.clear()
    var kante := _wand_links.slice(1, _wand_links.size() - 1) \
        + _wand_rechts.slice(1, _wand_rechts.size() - 1)
    for i in range(0, kante.size(), 2):
        if rng.randf() > 0.62:
            continue
        var p: Vector2 = kante[i]
        var nach_innen := -signf(p.x)
        var roehren := rng.randi_range(3, 6)
        var laengen := PackedFloat32Array()
        var winkel := PackedFloat32Array()
        for r in roehren:
            laengen.append(rng.randf_range(7.0, 20.0))
            winkel.append(rng.randf_range(-0.7, 0.7))
        _bewuchs.append({
            &"ort": p + Vector2(nach_innen * 4.0, 0.0),
            &"innen": nach_innen,
            &"laengen": laengen,
            &"winkel": winkel,
            &"takt": rng.randf_range(0.4, 1.1),
            &"phase": rng.randf_range(0.0, TAU),
        })


func _draw() -> void:
    # Von hinten nach vorn. Das ist die ganze Ordnung, die Tiefe ausmacht.
    for ebene in EBENEN:
        var versatz := Vector2(0.0, -fmod(zeit * EBENE_TEMPO[ebene], 220.0))
        _zeichne_wand(_fernwaende[ebene * 2], ebene, versatz)
        _zeichne_wand(_fernwaende[ebene * 2 + 1], ebene, versatz)
        _zeichne_vorspruenge(ebene, versatz)

    _zeichne_bewuchs()
    _zeichne_nischen()
    _zeichne_polypen()
    _zeichne_brut()
    _zeichne_waechter()


## Wie hell der Kegel diesen Punkt trifft. 0.0, solange kein Kegel gesetzt
## ist - `kolonie.gd` laeuft auch ohne, etwa im Koloniebildschirm.
func _licht_auf(punkt: Vector2) -> float:
    if kegel == null:
        return 0.0
    return Schlund.beleuchtung(Graben.WAECHTER, kegel.richtung, kegel.halbwinkel,
        kegel.reichweite, punkt, kegel.rand_kern, kegel.tiefe_kern) * kegel.schein


func _zeichne_wand(punkte: PackedVector2Array, ebene: int, versatz: Vector2) -> void:
    if punkte.is_empty():
        return
    var dunst := EBENE_DUNST[ebene]
    var verschoben := PackedVector2Array()
    for v in punkte:
        verschoben.append(v + versatz)

    draw_colored_polygon(verschoben, FELS.lerp(DUNST, dunst))

    var kante := verschoben.slice(1, verschoben.size() - 1)
    draw_polyline(kante, FELS_KANTE.lerp(DUNST, dunst), 2.6 * (1.0 - 0.5 * dunst), true)

    # Schichtlinien im Fels, parallel zur Kante nach aussen versetzt. Sie
    # geben der Wand eine Struktur statt einer Flaeche - und je naeher, desto
    # schaerfer, weil der Dunst als Erstes die Kanten frisst.
    for schicht in 4:
        var tiefe_hin := float(schicht + 1) * 19.0
        var linie := PackedVector2Array()
        for k in kante:
            linie.append(k + Vector2(signf(k.x) * tiefe_hin, 0.0))
        draw_polyline(linie, Color(FELS_KANTE.r, FELS_KANTE.g, FELS_KANTE.b,
            0.26 * (1.0 - dunst) / float(schicht + 1)), 1.2, true)

    # Und das Streiflicht des Kegels auf der Kante. Nur die vorderste Ebene -
    # weiter hinten kommt kein Licht mehr an, und genau das erzaehlt die
    # Entfernung.
    if dunst > 0.01:
        return
    for i in kante.size():
        var hell := _licht_auf(kante[i])
        if hell <= 0.02:
            continue
        draw_circle(kante[i], 3.0 + 9.0 * hell,
            Color(0.36, 0.86, 0.98, 0.16 * hell))


func _zeichne_vorspruenge(ebene: int, versatz: Vector2) -> void:
    var dunst := EBENE_DUNST[ebene]
    for v in _vorspruenge:
        if int(v[&"ebene"]) != ebene:
            continue
        var punkte := PackedVector2Array()
        for p: Vector2 in v[&"punkte"]:
            punkte.append(p + versatz)
        # Der Vorsprung steht etwas vor seiner Wand, faengt also etwas mehr
        # Licht - sonst verschwindet er in der Flaeche, aus der er ragt.
        draw_colored_polygon(punkte, FELS.lightened(0.09).lerp(DUNST, dunst * 0.86))
        draw_polyline(punkte + PackedVector2Array([punkte[0]]),
            FELS_KANTE.lerp(DUNST, dunst), 1.6, true)


## Roehrenbewuchs auf der vordersten Wand. Er glimmt von sich aus und flammt
## auf, wenn der Kegel darueberstreicht - der Spieler sieht damit an der Wand,
## wo sein Licht steht, auch wenn dort gerade kein Raeuber ist.
func _zeichne_bewuchs() -> void:
    for b in _bewuchs:
        var ort: Vector2 = b[&"ort"]
        var innen: float = b[&"innen"]
        var atem := 0.5 + 0.5 * sin(zeit * float(b[&"takt"]) + float(b[&"phase"]))
        var hell := _licht_auf(ort)
        var laengen: PackedFloat32Array = b[&"laengen"]
        var winkel: PackedFloat32Array = b[&"winkel"]

        for r in laengen.size():
            var richtung := Vector2(innen, 0.0).rotated(winkel[r])
            var spitze := ort + richtung * laengen[r] * (0.88 + 0.12 * atem)
            draw_line(ort, spitze, Color(0.16, 0.40, 0.46,
                0.34 + 0.30 * hell), 2.0)
            draw_circle(spitze, 1.6 + 1.2 * atem + 2.2 * hell,
                Color(0.42, 0.88, 0.92, 0.30 + 0.24 * atem + 0.46 * hell))


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
