extends Node2D

## Der Meeresgrund des Rundumlaufs - alles aus Linien.
##
## **Vorher war hier nichts.** Ein schwarzes Feld mit einem Kreis darum: das
## reichte, um zu sehen, ob sich das Fahren gut anfuehlt, und fuer nichts
## sonst. Ohne Grund hat eine Fahrt keinen Bezug - man sieht das Boot sich
## bewegen, aber nicht, dass es **irgendwohin** faehrt.
##
## Alles hier ist ein Linienzug. Keine gefuellte Flaeche traegt eine Form;
## sie decken nur ab, was dahinter liegt. Das ist dieselbe Sprache wie im
## Schlund - und derselbe technische Grund: `draw_polygon` ist in Godot nicht
## kantengeglaettet, `draw_polyline` schon.
##
## **Drei Lagen, und die Tiefe steckt in Helligkeit und Groesse**, nicht in
## einer Perspektivrechnung - genau wie bei den Sedimentruecken im Schlund.
## Was hinten liegt, ist blasser, kleiner und feiner gestrichelt.
##
## Alles kommt aus einer Saat. Zweimal starten heisst zweimal derselbe Grund:
## eine Karte, die sich bei jedem Start neu wuerfelt, ist keine Karte.

const SAAT := 0x4e454b52

## Wie weit ueber das Feld hinaus bewachsen wird. Am Rand soll nichts
## aufhoeren - eine Kante aus dem Nichts ist genau der Fehler, den das Riff
## im Schlund hatte.
const UEBERSTAND := 150.0

const TIEFE := 3
const LAGEN_KRAFT: PackedFloat32Array = [0.34, 0.62, 1.0]

## Die Farben des Riffs. Dieselbe Familie wie im Schlund, damit die beiden
## Schleifen wie derselbe Graben aussehen.
const FARBEN: PackedColorArray = [
    Color(0.42, 0.86, 0.92),
    Color(0.86, 0.52, 0.78),
    Color(0.34, 0.70, 0.62),
    Color(0.94, 0.68, 0.32),
    Color(0.44, 0.52, 0.90),
]

var zeit := 0.0

var _rippel: Array[PackedVector2Array] = []
var _felsen: Array[Dictionary] = []
var _bewuchs: Array[Dictionary] = []
var _staub: PackedVector2Array = []
var _staub_takt: PackedFloat32Array = []


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT
    _baue_rippel(rng)
    _baue_felsen(rng)
    _baue_bewuchs(rng)
    _baue_staub(rng)


func _process(delta: float) -> void:
    zeit += delta
    queue_redraw()


## Sedimentrippel: lange, flache Wellenlinien quer ueber den Grund.
##
## Sie sind das, was den Boden ueberhaupt zu einem Boden macht. Ohne sie ist
## das Feld eine schwarze Scheibe, und ob man faehrt oder steht, sieht man
## nur am Boot. Mit ihnen hat der Grund eine Richtung, und die Fahrt einen
## Bezug.
func _baue_rippel(rng: RandomNumberGenerator) -> void:
    var weite := Rundum.FELD_RADIUS + UEBERSTAND
    var richtung := rng.randf_range(0.0, PI)
    for i in 96:
        var versatz := lerpf(-weite, weite, float(i) / 21.0) \
            + rng.randf_range(-9.0, 9.0)
        var quer := Vector2.RIGHT.rotated(richtung)
        var laengs := quer.orthogonal()
        var zug := PackedVector2Array()
        var takt := rng.randf_range(0.010, 0.020)
        var hub := rng.randf_range(7.0, 22.0)
        var phase := rng.randf_range(0.0, TAU)
        for j in 41:
            var t := lerpf(-weite, weite, float(j) / 40.0)
            var p := quer * (versatz + hub * sin(t * takt + phase)) + laengs * t
            if p.length() > weite:
                continue
            zug.append(p)
        if zug.size() > 3:
            _rippel.append(zug)


## Felsen.
##
## **Nicht als Ecken gewuerfelt, sondern als Radiusfunktion.** Der erste
## Anlauf setzte sieben bis elf zufaellige Ecken und verband sie gerade: im
## Bild waren das schwarze Siebenecke, und weil die Flaeche dunkler ist als
## das Wasser davor, las man sie als Loecher statt als Steine. Ein Fels hat
## keine geraden Kanten.
##
## Drei Sinus mit unrunden Vielfachen ueber den Winkel, abgetastet in 48
## Schritten - das gibt einen Umriss, der unregelmaessig **und** glatt ist,
## und er wiederholt sich nicht.
##
## Dazu eine Hoehenlinie innen. Sie ist das, was einen Umriss zu einem
## Koerper macht: eine Kuppe hat eine Schulter, und die sieht man von oben
## als zweite Kontur.
func _baue_felsen(rng: RandomNumberGenerator) -> void:
    for _i in 190:
        var lage := rng.randi() % TIEFE
        var ort := _wuerfel_ort(rng)
        var gross := rng.randf_range(26.0, 96.0) \
            * lerpf(0.55, 1.0, float(lage) / float(TIEFE - 1))
        # **Die Form kommt aus `Riff`, nicht von hier.** Sie ist dieselbe,
        # die das Boot abstoesst - ein Fels, der anders aussieht als er sich
        # anfuehlt, ist unlernbar.
        var fels := Riff.bauen(rng, ort, gross)
        fels[&"lage"] = lage
        # Nur die vorderste Lage haelt auf. Was hinten liegt, ist Kulisse -
        # sonst wuerde man an etwas anstossen, das erkennbar weiter weg ist.
        fels[&"fest"] = lage == TIEFE - 1
        var risse: Array[PackedVector2Array] = []
        for _k in rng.randi_range(1, 3):
            var w := rng.randf_range(0.0, TAU)
            var riss := PackedVector2Array()
            for j in 4:
                var t := float(j) / 3.0
                riss.append(ort + Vector2.RIGHT.rotated(
                    w + rng.randf_range(-0.20, 0.20)) * gross * t * 0.88)
            risse.append(riss)
        fels[&"risse"] = risse
        _felsen.append(fels)


## Die Kante eines Felsens, abgetastet. Dieselbe `Riff.radius()`, die auch
## die Kollision fragt.
func _felskante(fels: Dictionary, faktor := 1.0) -> PackedVector2Array:
    var punkte := PackedVector2Array()
    var stufen := 48
    for j in stufen:
        var w := TAU * float(j) / float(stufen)
        punkte.append(Vector2(fels[&"ort"])
            + Vector2.RIGHT.rotated(w) * Riff.radius(fels, w) * faktor)
    return punkte


## Schiebt einen Koerper aus jedem festen Fels heraus, den er beruehrt.
##
## Oeffentlich, weil `rundlauf.gd` es je Bild fragt. Zwei Durchgaenge, damit
## eine Ecke zwischen zwei Steinen nicht in den einen zurueckschiebt, was der
## andere gerade herausgeschoben hat.
func abgestossen(ort: Vector2, dick: float) -> Vector2:
    var p := ort
    for _durchgang in 2:
        for fels in _felsen:
            if not bool(fels.get(&"fest", false)):
                continue
            if Riff.beruehrt(fels, p, dick):
                p = Riff.abgestossen(fels, p, dick)
    return p


## Bewuchs: Faecher, Roehren und Schoepfe. Drei Formen reichen - was den
## Grund reich macht, ist nicht die Zahl der Arten, sondern dass sie in
## Gruppen stehen und verschieden gross sind.
func _baue_bewuchs(rng: RandomNumberGenerator) -> void:
    for _i in 420:
        var lage := rng.randi() % TIEFE
        var ort := _wuerfel_ort(rng)
        var arme := PackedFloat32Array()
        for _a in rng.randi_range(5, 10):
            arme.append(rng.randf_range(0.55, 1.0))
        _bewuchs.append({
            &"lage": lage,
            &"ort": ort,
            &"art": rng.randi() % 3,
            &"gross": rng.randf_range(11.0, 34.0)
                * lerpf(0.55, 1.0, float(lage) / float(TIEFE - 1)),
            &"dreh": rng.randf_range(0.0, TAU),
            &"arme": arme,
            &"takt": rng.randf_range(0.25, 0.8),
            &"phase": rng.randf_range(0.0, TAU),
            &"farbe": FARBEN[rng.randi() % FARBEN.size()],
        })


func _baue_staub(rng: RandomNumberGenerator) -> void:
    var weite := Rundum.FELD_RADIUS + UEBERSTAND
    _staub.resize(900)
    _staub_takt.resize(900)
    for i in 900:
        _staub[i] = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) \
            * sqrt(rng.randf()) * weite
        _staub_takt[i] = rng.randf_range(0.15, 0.6)


## Ein Ort im Feld, gleichmaessig verteilt. `sqrt` ist noetig, weil sonst
## alles in die Mitte faellt - der Flaecheninhalt waechst mit dem Quadrat des
## Radius.
func _wuerfel_ort(rng: RandomNumberGenerator) -> Vector2:
    var weite := Rundum.FELD_RADIUS + UEBERSTAND
    return Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) \
        * sqrt(rng.randf()) * weite


## Was weiter weg ist als die Sicht, wird nicht gezeichnet.
##
## Bei einem Feld von 1500 Einheiten und einem Bild von 900 liegt das meiste
## ausserhalb. Ohne diese Frage zeichnete jedes Bild zweihundert Felsen, von
## denen zwanzig zu sehen sind.
func _im_blick(ort: Vector2, rand: float) -> bool:
    return ort.distance_squared_to(_blickmitte) \
        < (Rundum.SICHT + rand) * (Rundum.SICHT + rand)


var _blickmitte := Vector2.ZERO


func _draw() -> void:
    # Die Kamera sagt, wo hingesehen wird. Sie steht als Geschwister in der
    # Szene; ihr Ort ist der Mittelpunkt des Bildes.
    var kamera := get_parent().get_node_or_null("Kamera") as Camera2D
    if kamera != null:
        _blickmitte = kamera.position
    _zeichne_rippel()
    for lage in TIEFE:
        _zeichne_felsen(lage)
        _zeichne_bewuchs(lage)
    _zeichne_staub()


func _zeichne_rippel() -> void:
    for zug in _rippel:
        draw_polyline(zug, Color(0.22, 0.44, 0.50, 0.09), 1.0, true)


func _zeichne_felsen(lage: int) -> void:
    var kraft: float = LAGEN_KRAFT[lage]
    for f in _felsen:
        if int(f[&"lage"]) != lage or not _im_blick(f[&"ort"], 140.0):
            continue
        var umriss := _felskante(f)
        # Die Flaeche deckt nur ab, was dahinter liegt - dunkler als das
        # Wasser davor, wie das Sediment im Schlund. Die Form traegt die
        # Kante.
        draw_colored_polygon(umriss, Color(0.016, 0.030, 0.038, 1.0))
        var zu := umriss + PackedVector2Array([umriss[0]])
        draw_polyline(zu, Color(0.32, 0.56, 0.60, 0.10 * kraft), 4.0, true)
        draw_polyline(zu, Color(0.32, 0.56, 0.60, 0.44 * kraft), 1.3, true)
        var sch := _felskante(f, 0.58)
        draw_polyline(sch + PackedVector2Array([sch[0]]),
            Color(0.32, 0.56, 0.60, 0.15 * kraft), 1.0, true)
        for riss in f[&"risse"]:
            draw_polyline(riss, Color(0.32, 0.56, 0.60, 0.12 * kraft),
                1.0, true)


func _zeichne_bewuchs(lage: int) -> void:
    var kraft: float = LAGEN_KRAFT[lage]
    for b in _bewuchs:
        if int(b[&"lage"]) != lage or not _im_blick(b[&"ort"], 60.0):
            continue
        var p: Vector2 = b[&"ort"]
        var gr: float = b[&"gross"]
        var farbe: Color = b[&"farbe"]
        var atem := 0.5 + 0.5 * sin(zeit * float(b[&"takt"])
            + float(b[&"phase"]))
        var arme: PackedFloat32Array = b[&"arme"]
        var dreh: float = b[&"dreh"]
        var a := (0.16 + 0.10 * atem) * kraft
        match int(b[&"art"]):
            0:
                _faecher(p, gr, farbe, a, dreh, arme, atem)
            1:
                _roehren(p, gr, farbe, a, dreh, arme, atem)
            _:
                _schopf(p, gr, farbe, a, dreh, arme, atem)


## Ein Faecher: Rippen aus einem Punkt, aussen durch einen Bogen verbunden.
func _faecher(p: Vector2, r: float, farbe: Color, a: float, dreh: float,
        arme: PackedFloat32Array, atem: float) -> void:
    var saum := PackedVector2Array()
    for i in arme.size():
        var t := float(i) / float(maxi(1, arme.size() - 1))
        var w := dreh + lerpf(-1.05, 1.05, t)
        var laenge := r * arme[i] * (0.92 + 0.08 * atem)
        var spitze := p + Vector2.RIGHT.rotated(w) * laenge
        draw_line(p, spitze, Color(farbe.r, farbe.g, farbe.b, a), 1.1, true)
        saum.append(spitze)
    if saum.size() > 2:
        draw_polyline(saum, Color(farbe.r, farbe.g, farbe.b, a * 0.7),
            1.0, true)


## Roehren: kurze Stiele mit einem Ring obendrauf.
func _roehren(p: Vector2, r: float, farbe: Color, a: float, dreh: float,
        arme: PackedFloat32Array, atem: float) -> void:
    for i in arme.size():
        var w := dreh + TAU * float(i) / float(arme.size())
        var fuss := p + Vector2.RIGHT.rotated(w) * r * 0.34
        var kopf := fuss + Vector2.RIGHT.rotated(w + 0.3) \
            * r * arme[i] * (0.7 + 0.06 * atem)
        draw_line(fuss, kopf, Color(farbe.r, farbe.g, farbe.b, a), 1.3, true)
        draw_arc(kopf, r * 0.13, 0.0, TAU, 8,
            Color(farbe.r, farbe.g, farbe.b, a * 1.4), 1.0, true)


## Ein Schopf: gebogene Halme aus einem Punkt, die sich in der Stroemung
## wiegen. Der einzige Bewuchs, der sich sichtbar bewegt - mehr Bewegung im
## Hintergrund zieht den Blick von den Raeubern ab.
func _schopf(p: Vector2, r: float, farbe: Color, a: float, dreh: float,
        arme: PackedFloat32Array, atem: float) -> void:
    for i in arme.size():
        var w := dreh + lerpf(-0.9, 0.9, float(i) / float(maxi(1,
            arme.size() - 1)))
        var wiege := sin(zeit * 0.7 + float(i) * 0.8 + p.x * 0.01) * 0.22
        var halm := PackedVector2Array()
        for j in 6:
            var t := float(j) / 5.0
            halm.append(p + Vector2.RIGHT.rotated(w + wiege * t * t)
                * r * arme[i] * t)
        draw_polyline(halm, Color(farbe.r, farbe.g, farbe.b, a), 1.1, true)


func _zeichne_staub() -> void:
    for i in _staub.size():
        if not _im_blick(_staub[i], 30.0):
            continue
        var p := _staub[i] + Vector2(
            sin(zeit * _staub_takt[i] + float(i)) * 6.0,
            cos(zeit * _staub_takt[i] * 0.7 + float(i)) * 6.0)
        draw_circle(p, 0.9, Color(0.62, 0.86, 0.92, 0.13))
