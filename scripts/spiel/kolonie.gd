extends Node2D

## Alles, was zur Kolonie gehoert und nicht laeuft: die Ranken mit ihren
## Nischen, die Wehrpolypen, der Kalkwulst und die Brut.
##
## Ein Knoten statt fuenf, weil alles davon still steht und sich nur bei
## Aenderungen neu zeichnet. Fuer Beweglichkeit gibt es `schwarm.gd`.
##
## --- Die Waende sind weg ---
##
## Hier standen einmal drei gestaffelte Felsebenen je Seite, mit Vorspruengen,
## Rissen, Mulden, Krusten, Schleiern, Roehrenbewuchs und Zeichen darin -
## sechshundert Zeilen, die zusammen ein Viertel der Bildbreite fuellten.
##
## Im Bild waren sie zwei graue Platten mit aufgeklebtem Kleinkram. Der Grund
## ist geometrisch und nicht kuenstlerisch: die Wand steht **senkrecht am
## Rand**, also genau dort, wo der Blick nicht hinsieht, und sie ist
## **fast schwarz**, also kann alles darauf entweder gar nicht gesehen werden
## oder es sticht heraus wie ein Aufkleber. Es gibt keine dritte Moeglichkeit.
## Jede Kleinigkeit, die ich darauf legte, machte es schlimmer statt besser.
##
## Ohne sie ist der Graben offenes Wasser: der Verlauf des Shaders traegt die
## Tiefe, die seitliche Verdunkelung fuehrt den Blick in die Mitte, und was
## davor treibt, hat Platz. Ein leerer Rand ist kein Mangel - er ist der
## Grund, warum die Mitte wirkt.

## Von `wache.gd` gefuehrt.
var polypen: Array[Vector2] = []
var brut: int = Graben.BRUT_LEBEN
var brut_voll: int = Graben.BRUT_LEBEN
var naehrstoffe: int = 0
var bauphase := false
var zeit := 0.0

## Grundton des Kalks. `wache.gd` faerbt ihn je Abschnitt um - was am Grund
## liegt, nimmt die Farbe des Wassers an, in dem es steht.
var fels := Color(0.030, 0.050, 0.068)

const BRUT_FARBE := Color(0.98, 0.80, 0.42)
const POLYP_FARBE := Color(0.52, 0.94, 0.80)

## Die Farbe, in der sich Fernes aufloest - dieselbe, die der Wassershader in
## mittlerer Hoehe zeigt. Im Wasser wird Entferntes **heller und blauer**,
## nicht dunkler; das ist der Unterschied zwischen einem Bild mit Tiefe und
## einem ohne.
const DUNST := Color(0.088, 0.168, 0.198)

## Links und rechts - als Konstante, weil ein Feldliteral in einer
## for-Schleife seinen Typ verliert und jede Ableitung daraus mit.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]

## Treiber: kleine Quallen und Schwaermchen weit hinten, die ihre eigenen
## Bahnen ziehen. Sie treffen nichts und werden von nichts getroffen -
## **sie sind ausdruecklich keine Spielfiguren**, und darum stehen sie hier
## und nicht in `schwarm.gd`. Wenn sie irgendwann anfangen, dem Kegel
## auszuweichen, sind sie es geworden, und dann gehoeren sie in den Rechenkern.
var _treiber: Array[Dictionary] = []

## Das Riff am Grund, rings um den Kalkwulst. Warme und violette Toene gegen
## das Blau - ein Bild mit einem Farbton ist eine Tonung, keine Farbgebung.
var _korallen: Array[Dictionary] = []

## Der Kegel, um Ranken und Riff von ihm anleuchten zu lassen. Gesetzt von
## `wache.gd`. Dieselbe `Schlund.beleuchtung()` wie ueberall - was hell
## gezeichnet wird, ist das Licht, das auch Schaden macht.
var kegel: Node2D = null


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x4e454b7f
    _baue_treiber(rng)
    _baue_korallen(rng)


func _process(delta: float) -> void:
    zeit += delta
    queue_redraw()


## **Nicht alles ist tuerkis.** Das Bild hatte genau einen Farbton, und ein
## Bild mit einem Farbton ist eine Tonung, keine Farbgebung. Tiefseequallen
## leuchten in ganz unterschiedlichen Faerbungen; ein paar warme und
## violette dazwischen geben dem Blau erst seinen Wert.
const TREIBER_FARBEN: PackedColorArray = [
    Color(0.34, 0.72, 0.86),
    Color(0.30, 0.56, 0.90),
    Color(0.86, 0.42, 0.66),
    Color(0.62, 0.44, 0.88),
    Color(0.40, 0.84, 0.74),
    Color(0.92, 0.58, 0.44),
]


func _baue_treiber(rng: RandomNumberGenerator) -> void:
    _treiber.clear()
    for i in 16:
        # Die Groesse traegt die Entfernung: kleine treiben weit hinten und
        # langsam, grosse naeher und schneller. Eine Groesse fuer alle waere
        # eine Reihe gleicher Stempel.
        var nah := rng.randf()
        _treiber.append({
            &"x": rng.randf_range(Graben.FELD.position.x + 70.0,
                Graben.FELD.end.x - 70.0),
            &"y": rng.randf_range(Graben.FELD.position.y, Graben.FELD.end.y),
            &"tempo": lerpf(5.0, 17.0, nah),
            &"quer": rng.randf_range(6.0, 20.0),
            &"takt": rng.randf_range(0.30, 0.62),
            &"phase": rng.randf_range(0.0, TAU),
            &"gross": lerpf(7.0, 26.0, nah * nah),
            &"nah": nah,
            &"schwarm": rng.randf() < 0.28,
            &"zahl": rng.randi_range(4, 8),
            &"farbe": TREIBER_FARBEN[rng.randi() % TREIBER_FARBEN.size()],
            &"faeden": rng.randi_range(5, 8),
        })


## Die Farben des Riffs. Warm und violett gegen das Blau des Wassers - das
## ist der ganze Zweck, den sie haben.
const KORALL_FARBEN: PackedColorArray = [
    Color(0.92, 0.46, 0.30),
    Color(0.86, 0.34, 0.52),
    Color(0.62, 0.36, 0.82),
    Color(0.34, 0.70, 0.62),
    Color(0.94, 0.68, 0.32),
    Color(0.44, 0.52, 0.90),
]


func _baue_korallen(rng: RandomNumberGenerator) -> void:
    _korallen.clear()
    # **Am Grund, nicht am Rand.**
    #
    # Das Riff sass an der Wandkante und lief als farbiger Saum senkrecht
    # durchs Bild. Ohne Wand hat es keine Kante mehr - und das ist gut so:
    # ein Riff waechst dort, wo Halt und Naehrstoff sind, und beides gibt es
    # am Kalkwulst der Kolonie. Es liegt damit **unter** dem Geschehen statt
    # daneben, und der Blick geht ueber es hinweg nach oben in die Dunkelheit.
    var grund := Graben.BRUT_Y + 158.0
    for i in 24:
        # Zur Mitte hin flacher: dort steht der Waechter, und Bewuchs, der
        # ihm ins Bild waechst, verdeckt genau die Figur, auf die man sieht.
        var x := rng.randf_range(Graben.FELD.position.x - 30.0,
            Graben.FELD.end.x + 30.0)
        var aussen := clampf(absf(x) / 360.0, 0.0, 1.0)
        if absf(x) < 118.0 and rng.randf() < 0.72:
            continue
        var arme := PackedFloat32Array()
        for _a in rng.randi_range(6, 11):
            arme.append(rng.randf_range(0.5, 1.0))
        _korallen.append({
            &"ort": Vector2(x, grund + rng.randf_range(-38.0, 92.0)),
            # `innen` war die Wachstumsrichtung von der Wand weg. Am Grund
            # waechst alles nach oben; die Zahl bleibt als Neigung erhalten,
            # damit die drei Zeichenformen unveraendert weiterlaufen.
            &"innen": -signf(x) if x != 0.0 else 1.0,
            &"art": rng.randi() % 3,
            &"gross": lerpf(24.0, 88.0, aussen) * rng.randf_range(0.7, 1.25),
            &"neigung": rng.randf_range(-0.5, 0.5),
            &"arme": arme,
            &"takt": rng.randf_range(0.25, 0.7),
            &"phase": rng.randf_range(0.0, TAU),
            &"farbe": KORALL_FARBEN[rng.randi() % KORALL_FARBEN.size()],
        })


func _zeichne_korallen() -> void:
    for k in _korallen:
        var p: Vector2 = k[&"ort"]
        var innen: float = k[&"innen"]
        var r: float = k[&"gross"]
        var farbe: Color = k[&"farbe"]
        var atem: float = 0.5 + 0.5 * sin(zeit * float(k[&"takt"]) + float(k[&"phase"]))
        var arme: PackedFloat32Array = k[&"arme"]
        var neigung: float = k[&"neigung"]
        # Einmal je Klumpen, nicht je Arm: `beleuchtung()` ist die teuerste
        # Rechnung im Bild.
        var hell := _licht_auf(p)
        # **Deutlich schwaecher als frueher.** Am Rand sass das Riff im
        # Halbdunkel; am Grund liegt es unter der Brut, und dort ist der
        # hellste Punkt des Bildes. Mit der alten Deckung war es eine Reihe
        # bunter Wimpel direkt unter dem Einzigen, worauf man sehen muss.
        var kraft := 0.20 + 0.34 * hell

        match int(k[&"art"]):
            0:
                _koralle_faecher(p, r, farbe, kraft, innen, neigung, arme, atem)
            1:
                _koralle_roehren(p, r, farbe, kraft, innen, arme, atem)
            _:
                _koralle_anemone(p, r, farbe, kraft, innen, arme, atem)


## --- Warum die Korallen eine Flaeche brauchen ---
##
## Alle drei waren aus Strichen gebaut: Rippen, Roehren und Arme, jeweils
## `draw_line` mit einem Punkt an der Spitze. In der Lupe sah das aus wie
## Wunderkerzen - Funken auf Stielen, ohne Koerper. Eine Koralle ist aber vor
## allem **Masse**: ein Faecher hat ein Netz zwischen den Rippen, eine Roehre
## ist unten dick und oben duenn, eine Anemone hat einen Fuss.
##
## Die Flaechen sind bewusst schwach gedeckt. Sie sollen der Form Gewicht
## geben, nicht das Bild fuellen - die Korallen sitzen am Rand, und der Rand
## darf nicht lauter werden als die Mitte.


## Ein Faecher: Rippen von einem Fuss aus, mit einem Netz dazwischen. Er steht
## quer zur Stroemung, weil er von ihr lebt.
func _koralle_faecher(p: Vector2, r: float, farbe: Color, kraft: float,
        innen: float, neigung: float, arme: PackedFloat32Array,
        atem: float) -> void:
    var n := arme.size()
    var spitzen := PackedVector2Array()
    for i in n:
        var t := float(i) / float(maxi(1, n - 1))
        var w := lerpf(-1.05, 1.05, t) + neigung + 0.05 * sin(zeit * 0.4 + float(i))
        var laenge := r * (0.55 + 0.45 * sin(t * PI)) * arme[i]
        var richtung := Vector2(innen * sin(w), -cos(w))
        spitzen.append(p + richtung * laenge)

    # Das Netz als Flaeche, mit Verlauf vom Fuss zur Kante: dicht am Stiel,
    # ausgefranst am Rand. Erst danach die Rippen darauf.
    if spitzen.size() > 2:
        var netz := PackedVector2Array([p])
        var farben := PackedColorArray([Color(farbe.r, farbe.g, farbe.b, 0.20 * kraft)])
        for sp in spitzen:
            netz.append(sp)
            farben.append(Color(farbe.r, farbe.g, farbe.b, 0.05 * kraft))
        draw_polygon(netz, farben)

    for i in n:
        draw_line(p, spitzen[i], Color(farbe.r, farbe.g, farbe.b, 0.34 * kraft),
            1.0 + r * 0.035)
    if spitzen.size() > 1:
        for anteil in [0.55, 0.85]:
            var bogen := PackedVector2Array()
            for sp in spitzen:
                bogen.append(p + (sp - p) * anteil)
            draw_polyline(bogen, Color(farbe.r, farbe.g, farbe.b,
                0.20 * kraft), 1.0, true)
        draw_polyline(spitzen, Color(farbe.r, farbe.g, farbe.b,
            0.26 * kraft), 1.0, true)


## Roehren: ein Buendel, das nach oben zeigt, mit hellen Muendungen.
func _koralle_roehren(p: Vector2, r: float, farbe: Color, kraft: float,
        innen: float, arme: PackedFloat32Array, atem: float) -> void:
    for i in arme.size():
        var t := float(i) / float(maxi(1, arme.size() - 1))
        var fuss := p + Vector2(innen * lerpf(-0.5, 0.5, t) * r * 0.9, 0.0)
        var hoch := r * arme[i] * (0.85 + 0.15 * atem)
        var spitze := fuss + Vector2(innen * 0.18 * r * (t - 0.5), -hoch)
        # Unten dick, oben schmal - eine Roehre mit gleichbleibender Breite
        # ist ein Strich.
        var quer := (spitze - fuss).orthogonal().normalized()
        var dick := 1.6 + r * 0.075
        draw_colored_polygon(PackedVector2Array([
            fuss + quer * dick, spitze + quer * dick * 0.44,
            spitze - quer * dick * 0.44, fuss - quer * dick,
        ]), Color(farbe.r, farbe.g, farbe.b, 0.24 * kraft))
        draw_line(fuss, spitze, Color(farbe.r, farbe.g, farbe.b, 0.26 * kraft),
            1.0 + r * 0.03)
        draw_circle(spitze, 1.2 + r * 0.055,
            Color(farbe.r, farbe.g, farbe.b, 0.42 * kraft))
        draw_circle(spitze, 0.6 + r * 0.022,
            Color(1.0, 0.96, 0.90, 0.30 * kraft))


## Eine Anemone: ein Fuss und Arme, die sich einzeln bewegen.
func _koralle_anemone(p: Vector2, r: float, farbe: Color, kraft: float,
        innen: float, arme: PackedFloat32Array, atem: float) -> void:
    # Der Fuss ist eine Kuppel, kein Punkt. Vorher stand hier ein Kreis mit
    # dem Radius eines Drittels - aus dem ragten die Arme heraus wie Draehte
    # aus einer Perle.
    var breit := r * 0.46
    var hoch := r * 0.30 * (0.9 + 0.1 * atem)
    var kuppe := PackedVector2Array()
    for k in 13:
        var w := lerpf(PI, TAU, float(k) / 12.0)
        kuppe.append(p + Vector2(cos(w) * breit, sin(w) * hoch + hoch * 0.35))
    draw_colored_polygon(kuppe, Color(farbe.r, farbe.g, farbe.b, 0.26 * kraft))
    draw_polyline(kuppe, Color(farbe.r, farbe.g, farbe.b, 0.34 * kraft), 1.2, true)

    for i in arme.size():
        var t := float(i) / float(maxi(1, arme.size() - 1))
        var w := lerpf(-1.25, 1.25, t)
        var fuss := p + Vector2(cos(lerpf(PI, TAU, t)) * breit * 0.7, -hoch * 0.4)
        var linie := PackedVector2Array([fuss])
        var punkt := fuss
        var richtung := Vector2(innen * sin(w), -cos(w))
        for g in 3:
            richtung = richtung.rotated(
                sin(zeit * 0.9 + float(i) * 1.7 + float(g)) * 0.22)
            punkt += richtung * r * 0.30 * arme[i]
            linie.append(punkt)
        draw_polyline(linie, Color(farbe.r, farbe.g, farbe.b, 0.28 * kraft),
            1.0 + r * 0.03, true)
        draw_circle(linie[linie.size() - 1], 1.0 + r * 0.03,
            Color(farbe.r, farbe.g, farbe.b, 0.34 * kraft))


func _zeichne_treiber() -> void:
    var hoch := Graben.FELD.size.y + 200.0
    for d in _treiber:
        var atem: float = 0.5 + 0.5 * sin(zeit * float(d[&"takt"]) + float(d[&"phase"]))
        var y: float = fposmod(float(d[&"y"]) + zeit * float(d[&"tempo"])
            - Graben.FELD.position.y, hoch) + Graben.FELD.position.y - 100.0
        var x: float = float(d[&"x"]) \
            + sin(zeit * float(d[&"takt"]) * 0.7 + float(d[&"phase"])) * float(d[&"quer"])
        var p := Vector2(x, y)
        var r: float = float(d[&"gross"])
        var nah: float = d[&"nah"]
        var farbe: Color = d[&"farbe"]

        # Nah heisst kraeftig, fern heisst blass und blau - dieselbe Regel wie
        # bei den Waenden. Ohne sie schwimmen alle in derselben Ebene.
        var kraft := 0.22 + 0.55 * nah
        farbe = farbe.lerp(DUNST, 0.55 * (1.0 - nah))

        if bool(d[&"schwarm"]):
            for k in int(d[&"zahl"]):
                var w := TAU * float(k) / float(d[&"zahl"]) + zeit * 0.5
                var q := p + Vector2(cos(w), sin(w) * 0.6) * r
                draw_circle(q, 2.4 * (0.6 + 0.6 * nah),
                    Color(farbe.r, farbe.g, farbe.b, 0.30 * kraft))
                draw_circle(q, 1.1, Color(farbe.r, farbe.g, farbe.b, 0.55 * kraft))
            continue

        _zeichne_qualle(p, r, farbe, kraft, atem, float(d[&"phase"]),
            int(d[&"faeden"]))


## Eine Qualle.
##
## **Was sie ausmacht, sind die Faeden, nicht der Schirm.** Der erste Entwurf
## hatte vier gerade Striche unter einem Halbkreis - im Bild ein Pilz. Ein
## Faden haengt nicht, er **schleppt**: jedes Glied folgt dem vorigen mit
## Verzoegerung, und weil der Schirm sich rhythmisch zusammenzieht, laeuft
## eine Welle daran entlang. Das ist die ganze Bewegung, und sie kostet eine
## Sinusfunktion je Glied.
##
## Dazu ein Schirm aus drei ineinanderliegenden Kuppeln statt einer Flaeche -
## eine Qualle ist durchsichtig, und Durchsichtigkeit sieht man nur dort, wo
## sich etwas ueberlagert.
func _zeichne_qualle(p: Vector2, r: float, farbe: Color, kraft: float,
        atem: float, phase: float, faeden: int) -> void:
    var breit := r * (1.10 - 0.20 * atem)
    var hoch := r * (0.66 + 0.26 * atem)

    # Der Hof. Eine Qualle leuchtet nicht nur, sie steht in ihrem eigenen
    # Licht - das ist der Unterschied zwischen einer Zeichnung und einem
    # Lebewesen im Wasser.
    draw_circle(p, r * 1.7, Color(farbe.r, farbe.g, farbe.b, 0.05 * kraft))

    # Die Faeden zuerst, damit der Schirm ueber ihren Ansaetzen liegt.
    for k in faeden:
        var s := lerpf(-0.86, 0.86, float(k) / float(maxi(1, faeden - 1)))
        var wurzel := p + Vector2(s * breit * 0.82, hoch * 0.3)
        var linie := PackedVector2Array([wurzel])
        var punkt := wurzel
        var glieder := 7
        for g in glieder:
            var t := float(g + 1) / float(glieder)
            # Die Welle laeuft nach unten weg: der Versatz je Glied haengt an
            # `t`, also hinkt jedes Glied dem darueber hinterher.
            var schwung := sin(zeit * 1.4 - t * 3.4 + phase + s * 2.0) \
                * r * 0.16 * t
            punkt += Vector2(schwung + s * r * 0.06, r * 0.34)
            linie.append(punkt)
        draw_polyline(linie, Color(farbe.r, farbe.g, farbe.b,
            (0.30 - 0.16 * absf(s)) * kraft), 1.0 + r * 0.045, true)

    # Der Schirm: drei Kuppeln, aussen weit und blass, innen eng und kraeftig.
    for i in 3:
        var t := float(i) / 2.0
        var kuppe := PackedVector2Array()
        var bb := breit * lerpf(1.0, 0.52, t)
        var hh := hoch * lerpf(1.0, 0.62, t)
        for k in 15:
            var w := lerpf(PI, TAU, float(k) / 14.0)
            kuppe.append(p + Vector2(cos(w) * bb, sin(w) * hh))
        draw_colored_polygon(kuppe, Color(farbe.r, farbe.g, farbe.b,
            (0.07 + 0.05 * t) * kraft))

    # Und ein Saum an der Glocke - dort ist das Gewebe am dichtesten.
    var rand := PackedVector2Array()
    for k in 17:
        var w := lerpf(PI, TAU, float(k) / 16.0)
        rand.append(p + Vector2(cos(w) * breit, sin(w) * hoch))
    draw_polyline(rand, Color(farbe.r, farbe.g, farbe.b, 0.34 * kraft),
        1.2 + r * 0.03, true)


func _draw() -> void:
    # Von hinten nach vorn. Das ist die ganze Ordnung, die Tiefe ausmacht.
    #
    # **Hier standen einmal neun Lagen uebereinander:** drei Wandebenen mit
    # Mulden, Rissen und Vorspruengen, darauf Krusten, Schleier, Bewuchs und
    # Zeichen. Jede fuer sich war begruendet, zusammen ergaben sie ein
    # Rauschen, in dem der Spieler die Raeuber suchen musste. Ein Bild wird
    # nicht reicher, indem man mehr hineinlegt - es wird reicher, wenn das,
    # was drin ist, groesser ist und Platz hat.
    _zeichne_treiber()
    _zeichne_korallen()
    _zeichne_ranken()
    _zeichne_nischen()
    _zeichne_polypen()
    # Der Sockel gehoert hinter die Brut. Andersherum deckte er die Eierreihe
    # zu - und die Brut ist das Einzige im Bild, das der Spieler die ganze
    # Zeit sehen muss.
    _zeichne_sockel()
    _zeichne_brut()
    # Der Waechter steht nicht mehr hier. Er wird **ueber** dem Kegel
    # gezeichnet - siehe `waechter.gd`.


## --- Die Ranken ---
##
## Zwei Arme, die aus dem Kalkwulst aufsteigen und die Nischen tragen. Sie
## sind der Ersatz fuer die Waende, aber sie ersetzen nicht deren Aufgabe:
## eine Wand rahmt das Bild ein, eine Ranke **erklaert die Nischen**.
##
## Ohne sie haetten acht leuchtende Ringe im offenen Wasser gehangen - acht
## Tippflaechen ohne etwas, woran sie sitzen. Mit ihnen sieht man in einem
## Blick, dass die Kolonie zwei Arme in den Schlund streckt und dass in deren
## Knospen etwas waechst.
##
## Gezeichnet als **ein** Streifenzug mit Farbe je Eckpunkt, nicht als Stapel
## aus Linien: uebereinandergelegte deckende Lagen haben so viele harte
## Kanten wie Lagen, und drei davon habe ich in diesem Projekt schon
## herausgeholt.
const RANKE_TEILE := 26


func _zeichne_ranken() -> void:
    for seite: float in SEITEN:
        var links := PackedVector2Array()
        var rechts := PackedVector2Array()
        var farben := PackedColorArray()
        for i in RANKE_TEILE + 1:
            var t := float(i) / float(RANKE_TEILE)
            var p := Graben.ranke(seite, t)
            # Die Normale aus der Bahn selbst, damit die Dicke immer quer zur
            # Ranke steht und nicht quer zum Bild.
            var vor := Graben.ranke(seite, minf(1.0, t + 0.02))
            var zurueck := Graben.ranke(seite, maxf(0.0, t - 0.02))
            var quer := (vor - zurueck).orthogonal().normalized()
            var d := Graben.ranke_dicke(t) * 0.5
            links.append(p - quer * d)
            rechts.append(p + quer * d)
            # Das Licht des Kegels streift sie wie alles andere - und weil
            # `_licht_auf()` dieselbe `Schlund.beleuchtung()` fragt, die auch
            # den Schaden bestimmt, kann sie nicht heller aussehen als sie ist.
            var hell := _licht_auf(p)
            var atem := 0.5 + 0.5 * sin(zeit * 0.7 - t * 3.4 + seite)
            var farbe := fels.lerp(DUNST, 0.16 + 0.30 * hell) \
                .lerp(POLYP_FARBE, 0.05 + 0.05 * atem + 0.22 * hell)
            # Die Spitze blendet aus, statt abzubrechen. Eine Ranke, die oben
            # mit einer geraden Kante endet, ist ein abgesaegter Stab - und
            # genau das war im Bild zu sehen, ein Stueck unterhalb der
            # obersten Knospe.
            farbe.a = clampf((1.0 - t) * 6.0, 0.0, 1.0)
            farben.append(farbe)

        var flaeche := PackedVector2Array()
        var farbfeld := PackedColorArray()
        for i in links.size():
            flaeche.append(links[i])
            farbfeld.append(farben[i])
        for i in range(rechts.size() - 1, -1, -1):
            flaeche.append(rechts[i])
            farbfeld.append(farben[i])
        draw_polygon(flaeche, farbfeld)

        # Ein weicher Hof laengs der Bahn: ohne ihn ist die Ranke ein Draht.
        # Additiv waere er ein zweites Licht - also gemischt und sehr schwach.
        var bahn := PackedVector2Array()
        for i in RANKE_TEILE + 1:
            bahn.append(Graben.ranke(seite, float(i) / float(RANKE_TEILE)))
        # Der Hof endet mit der obersten Knospe - darueber laeuft die Ranke
        # aus, und ein Hof um nichts ist ein Strich im Wasser.
        var hof := PackedVector2Array()
        for i in RANKE_TEILE + 1:
            var t := float(i) / float(RANKE_TEILE)
            if t > Graben.nische_lage(Graben.NISCHEN_JE_RANKE - 1) + 0.04:
                break
            hof.append(Graben.ranke(seite, t))
        draw_polyline(hof, Color(POLYP_FARBE.r, POLYP_FARBE.g,
            POLYP_FARBE.b, 0.05), 22.0, true)
        draw_polyline(hof, Color(POLYP_FARBE.r, POLYP_FARBE.g,
            POLYP_FARBE.b, 0.05), 11.0, true)

        # Ein Saum auf der dem Schlund zugewandten Seite: das ist die Kante,
        # die der Kegel trifft, und ohne sie ist die Ranke eine Silhouette.
        var saum := PackedVector2Array()
        for i in links.size():
            if float(i) / float(RANKE_TEILE) > 0.9:
                break
            saum.append(links[i] if seite > 0.0 else rechts[i])
        draw_polyline(saum, Color(POLYP_FARBE.r, POLYP_FARBE.g,
            POLYP_FARBE.b, 0.16), 1.4, true)

        # Ranken haben Seitentriebe. Ohne sie ist es ein Schlauch.
        for i in 7:
            var t := lerpf(0.10, 0.94, float(i) / 6.0)
            var p := Graben.ranke(seite, t)
            var w := seite * (2.3 + 0.9 * sin(float(i) * 2.1))
            var laenge := lerpf(30.0, 12.0, t) * (0.7 + 0.3 * sin(zeit * 0.8 + float(i)))
            var spitze := p + Vector2(cos(w), sin(w)) * laenge
            draw_line(p, spitze, Color(POLYP_FARBE.r, POLYP_FARBE.g,
                POLYP_FARBE.b, 0.13), 2.0)
            draw_circle(spitze, 2.0, Color(0.70, 0.98, 0.90, 0.16))


## Wie hell der Kegel diesen Punkt trifft. 0.0, solange kein Kegel gesetzt
## ist - `kolonie.gd` laeuft auch ohne, etwa im Koloniebildschirm.
func _licht_auf(punkt: Vector2) -> float:
    if kegel == null:
        return 0.0
    return Schlund.beleuchtung(Graben.WAECHTER, kegel.richtung, kegel.halbwinkel,
        kegel.reichweite, punkt, kegel.rand_kern, kegel.tiefe_kern) * kegel.schein


func _zeichne_nischen() -> void:
    for i in Graben.NISCHEN.size():
        var p := Graben.NISCHEN[i]
        if i < polypen.size():
            continue
        var frei := bauphase and naehrstoffe >= Graben.polyp_kosten(polypen.size())
        # Nach aussen zeigend: die Knospe sitzt auf der Ranke und oeffnet sich
        # vom Schlund weg, so wie alles hier von der Kolonie weg waechst.
        var nach_aussen := signf(p.x)

        # **Waehrend der Welle ist eine Nische eine geschlossene Knospe.**
        #
        # Hier stand fuer beide Lagen derselbe Ring: acht leuchtende Kreise,
        # die am Bild klebten wie Aufkleber. Antippen kann man sie nur
        # zwischen den Wellen - solange sie nichts tun, duerfen sie auch
        # nichts fordern.
        if not bauphase:
            draw_circle(p, Graben.POLYP_RADIUS * 0.52,
                fels.lerp(POLYP_FARBE, 0.20))
            draw_arc(p, Graben.POLYP_RADIUS * 0.52, 0.0, TAU, 14,
                Color(0.42, 0.78, 0.82, 0.16), 1.2, true)
            continue

        # Zwischen den Wellen oeffnet sie sich: ein Kelch, ein Ring und - wenn
        # der Naehrstoff reicht - ein Kreuz, das langsam pulst.
        var puls := 0.5 + 0.5 * sin(zeit * 3.0 + float(i))
        var deckung := 0.20 + (0.30 * puls if frei else 0.0)
        draw_circle(p, Graben.POLYP_RADIUS * 1.6, Color(0.20, 0.42, 0.46, deckung * 0.5))
        for k in 5:
            var w := PI * (-0.5 + float(k) / 4.0) * 1.1 + (0.0 if nach_aussen > 0.0 else PI)
            var spitze := p + Vector2(cos(w), sin(w)) * Graben.POLYP_RADIUS * 1.15
            draw_line(p, spitze, Color(0.42, 0.78, 0.82, deckung * 0.9), 1.6)
        draw_arc(p, Graben.POLYP_RADIUS, 0.0, TAU, 20,
            Color(0.42, 0.78, 0.82, deckung + 0.14), 1.8, true)
        if frei:
            draw_line(p - Vector2(5.0, 0.0), p + Vector2(5.0, 0.0),
                Color(0.72, 1.0, 0.92, 0.5 + 0.4 * puls), 1.8)
            draw_line(p - Vector2(0.0, 5.0), p + Vector2(0.0, 5.0),
                Color(0.72, 1.0, 0.92, 0.5 + 0.4 * puls), 1.8)


func _zeichne_polypen() -> void:
    for i in polypen.size():
        var p := polypen[i]
        var puls := 0.5 + 0.5 * sin(zeit * 2.1 + float(i) * 0.8)

        # **Die Reichweite steht nur zwischen den Wellen.**
        #
        # Sie ist die Auskunft, die man beim Setzen braucht - und genau dann
        # ist der Bildschirm leer. Waehrend der Welle sind es acht sich
        # kreuzende Kreise ueber dem halben Bild, und dann sucht man die
        # Raeuber in einem Netz aus Linien. Was man nicht mehr entscheiden
        # kann, muss man auch nicht mehr sehen.
        if bauphase:
            draw_arc(p, Graben.POLYP_REICHWEITE, 0.0, TAU, 42,
                Color(POLYP_FARBE.r, POLYP_FARBE.g, POLYP_FARBE.b, 0.10), 1.0, true)

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


## Die Brut: das Einzige im Bild, das der Spieler die ganze Zeit sehen muss.
##
## Sie war eine Reihe Punkte auf einem Balken. Was daran fehlte, ist das, was
## Eier ueberhaupt zu Eiern macht: sie liegen in etwas. Jetzt liegt darunter
## ein Gelege - eine Membran, die sich zwischen den Eiern durchzieht und an
## den Raendern ausduennt -, und die Eier stehen unterschiedlich hoch darin,
## als waeren sie hineingesunken statt aufgereiht worden.
##
## Jedes Ei ist ein Lebenspunkt. Dadurch braucht es keine Zahl, um zu sehen,
## wie es steht - und einen Verlust sieht man an der Luecke, nicht an einem
## Zaehler.
## Die Brut: das Einzige im Bild, das der Spieler die ganze Zeit sehen muss.
##
## Wo ein Ei liegt, steht in `Graben.ei_ort()` und nicht hier - `wache.gd`
## braucht denselben Ort fuer die Bruchstuecke.
func _zeichne_brut() -> void:
    var breite := Graben.BRUT_BREITE
    var links := -breite * 0.5
    var radius := Graben.ei_radius(brut_voll)
    var reihen := Graben.brut_reihen(brut_voll)
    var je_reihe := Graben.brut_je_reihe(brut_voll)

    _zeichne_gelege(links, breite, false)

    # Von hinten nach vorn, damit die vordere Reihe die hintere ueberdeckt.
    for r in range(reihen - 1, -1, -1):
        # Hinten kleiner und blasser - dieselbe Luftperspektive wie am Fels,
        # nur ueber zehn Pixel statt ueber den halben Graben.
        var ferne := float(r) / float(maxi(1, Graben.BRUT_REIHEN_HOECHSTENS - 1))
        for k in mini(je_reihe, brut_voll - r * je_reihe):
            var i := r * je_reihe + k
            var punkt := Graben.ei_ort(i, brut_voll)
            if i < brut:
                _zeichne_ei(punkt, i, radius * (1.0 - 0.14 * ferne), ferne)
            else:
                _zeichne_schale(punkt, radius * (1.0 - 0.14 * ferne))

    _zeichne_gelege(links, breite, true)


## Die Membran unter den Eiern. Sie ist der Grund, warum das Gelege wie ein
## Gelege aussieht und nicht wie eine Fortschrittsleiste.
##
## **Ein Napf, kein Brett.** Vorher lief ihre Unterkante als gerade Linie
## ueber die volle Breite und endete an beiden Enden abrupt - im Bild ein
## braunes Brett, auf dem Eier liegen. Was eine Membran ausmacht, ist, dass
## sie nirgends eine Kante hat: sie ist in der Mitte dick und laeuft zu
## beiden Seiten auf null aus, oben wie unten. Und ihre Farbe gehoert dem
## Fels, in dem sie sitzt, nicht einem Brett.
##
## `vorn` ist die Lippe, die ueber das untere Drittel der vordersten Eier
## laeuft. Ohne sie liegen die Eier *auf* der Membran wie Muenzen auf einem
## Tisch; mit ihr stecken sie darin. Es ist derselbe Trick, mit dem ein Maler
## einen Stein ins Wasser setzt - nicht der Stein macht es, sondern die Linie
## davor.
func _zeichne_gelege(links: float, breite: float, vorn: bool) -> void:
    var y := Graben.BRUT_Y
    var oben := PackedVector2Array()
    var unten := PackedVector2Array()
    var stufen := 52
    var hoehe := (y + 3.0) if vorn else (y + 7.0)
    for i in stufen + 1:
        var t := float(i) / float(stufen)
        var x := links + breite * t
        # Der Bauch: in der Mitte voll, an den Enden null. Die Wurzel macht
        # ihn breiter als eine reine Sinuskurve - sonst ist die Membran nur
        # in der Mitte zu sehen und laeuft schon auf einem Drittel aus.
        var bauch := pow(sin(t * PI), 0.55)
        # Zwei Wellen darauf, eine langsame und eine kurze, damit die Kante
        # nicht gezeichnet aussieht.
        var kraus := 3.4 * sin(t * 9.0 + zeit * 0.5) + 2.0 * sin(t * 23.0 - zeit * 0.8)
        var dick := (9.0 + kraus) * bauch
        oben.append(Vector2(x, hoehe - dick * (0.42 if vorn else 1.0)))
        unten.append(Vector2(x, hoehe + (16.0 + kraus * 0.6) * bauch))

    var haut := oben.duplicate()
    for i in range(unten.size() - 1, -1, -1):
        haut.append(unten[i])
    # Kalk mit einem warmen Stich, abgeleitet vom Fels des Abschnitts - so
    # wechselt sie die Farbe mit dem Graben, statt immer braun zu bleiben.
    var kalk := fels.lightened(0.10).lerp(Color(0.42, 0.30, 0.16), 0.45)
    draw_colored_polygon(haut, Color(kalk.r, kalk.g, kalk.b,
        0.66 if vorn else 0.54))
    draw_polyline(oben, Color(0.50, 0.38, 0.22, 0.40 if vorn else 0.26), 1.5, true)


func _zeichne_ei(p: Vector2, i: int, r: float, ferne: float) -> void:
    var puls := 0.5 + 0.5 * sin(zeit * 1.7 + float(i) * 0.6)
    # Hinten blasser: die Reihe dahinter liegt im Wasser, nicht im Licht.
    var f := BRUT_FARBE.lerp(DUNST, 0.30 * ferne)
    # Nicht alle gleich gross. Zwoelf gleiche Kreise sind eine Skala.
    r *= 0.88 + 0.12 * sin(float(i) * 1.9 + 0.7)
    draw_circle(p, r * 2.3, Color(f.r, f.g, f.b, (0.06 + 0.05 * puls) * (1.0 - 0.4 * ferne)))
    draw_circle(p, r * 1.5, Color(f.r, f.g, f.b, (0.15 + 0.07 * puls) * (1.0 - 0.4 * ferne)))
    draw_circle(p, r, f)

    # Ein heller Fleck oben links: die Stelle, an der das Licht des Waechters
    # auf die Schale trifft. Ohne ihn ist ein Kreis eine Scheibe.
    draw_circle(p + Vector2(-r * 0.3, -r * 0.34), r * 0.30,
        Color(1.0, 0.94, 0.78, 0.55 * (1.0 - 0.5 * ferne)))

    if r < 4.0:
        return
    var keim := p + Vector2(sin(zeit * 0.9 + float(i)) * 1.4,
        cos(zeit * 1.1 + float(i)) * 1.1)
    draw_circle(keim, r * 0.42, Color(1.0, 0.96, 0.86, 0.9 * (1.0 - 0.5 * ferne)))
    draw_circle(keim, r * 0.20, Color(1.0, 1.0, 0.96, 1.0 - 0.5 * ferne))


## Eine zerbrochene Schale. Sie bleibt liegen - was verloren ist, verschwindet
## nicht, es liegt da.
func _zeichne_schale(p: Vector2, r: float) -> void:
    draw_arc(p, r * 0.9, 0.35, PI - 0.35, 10, Color(0.34, 0.30, 0.26, 0.7), 1.6)
    draw_line(p + Vector2(-r * 0.76, r * 0.15), p + Vector2(-r * 0.30, -r * 0.60),
        Color(0.30, 0.26, 0.22, 0.6), 1.2)
    draw_line(p + Vector2(r * 0.76, r * 0.15), p + Vector2(r * 0.38, -r * 0.53),
        Color(0.30, 0.26, 0.22, 0.6), 1.2)
    # Ein Rest, der noch verglimmt.
    draw_circle(p + Vector2(0.0, r * 0.3), r * 0.24, Color(0.52, 0.38, 0.20, 0.35))


## Der Kalkwulst, in dem der Waechter steckt. Ohne ihn schwebt er ueber der
## Brut; mit ihm ist er festgewachsen wie alles andere hier auch.
##
## Nach unten laeuft er aus dem Bild - ein Sockel mit sichtbarer Unterkante
## sieht aus wie eine Kiste, auf der jemand sitzt.
func _zeichne_sockel() -> void:
    var p := Graben.WAECHTER
    # Derselbe Massstab wie das Tier darin - sonst waechst der Waechter aus
    # seinem Wulst heraus.
    var g := Graben.WAECHTER_GROESSE

    # **Eine geschnitzte Saeule, kein Kasten.**
    #
    # Der Sockel war ein dunkles Trapez, das nach unten aus dem Bild lief -
    # richtig gedacht (einer mit sichtbarer Unterkante sieht aus wie eine
    # Kiste, auf der jemand sitzt), aber leer ausgefuehrt. Was eine Saeule
    # zur Saeule macht, ist ihr Profil: eine ueberstehende Deckplatte, ein
    # eingezogener Schaft, ein Fuss, der sich wieder oeffnet. Und darin
    # leuchtet der Kern der Kolonie durch - die Begruendung dafuer, warum der
    # Waechter hier steht und nicht anderswo.
    #
    # **Und er ist nicht schwarz.** `fels.lightened(0.05)` auf einem Fels vom
    # Wert 0.03 ergibt 0.08 - im Bild ein dunkles Loch unter dem Gelege, das
    # groesste zusammenhaengende Nichts im ganzen Bild. Die Saeule steht
    # direkt unter der einzigen Lichtquelle: oben faengt sie Licht, nach
    # unten laeuft sie in die Tiefe aus. Eine Farbe je Eckpunkt sagt das in
    # einem Zeichenaufruf.
    var schaft := PackedVector2Array()
    var farben := PackedColorArray()
    var stufen := 22
    for seite: float in SEITEN:
        for i in stufen + 1:
            var t := float(i) / float(stufen)
            if seite > 0.0:
                t = 1.0 - t
            schaft.append(p + Vector2(seite * _sockelbreite(t), _sockelhoehe(t)) * g)
            # Oben hell, unten aus - und die Flanken etwas heller als die
            # Mitte, weil sie sich dem Licht zuwenden.
            # **Leise.** Der erste Anlauf mischte bis zu 68 Prozent gegen
            # ein helles Blaugruen - damit stand die Saeule heller da als
            # das Wasser davor und las sich als Glasrohr. Ein Stein unter
            # einer Lampe ist oben etwa so hell wie das Wasser und darunter
            # dunkler; was ihm Form gibt, ist der Saum an den Flanken, nicht
            # die Flaeche.
            var hell := pow(1.0 - t, 1.6)
            farben.append(fels.lerp(DUNST, 0.06 + 0.28 * hell))
    draw_polygon(schaft, farben)

    # Der Kern liegt tief im Schaft, nicht hinter dem Tier: hoeher angesetzt
    # legte er einen Hof um den Waechter und sah aus wie ein zweites Organ.
    for i in 4:
        var t := float(i) / 3.0
        var mitte := p + Vector2(0.0, lerpf(268.0, 150.0, t)) * g
        draw_circle(mitte, lerpf(24.0, 9.0, t) * g,
            Color(0.34, 0.82, 0.84, 0.05 + 0.055 * t))

    # Der Saum an den Flanken. Er traegt die Form der Saeule - deshalb zwei
    # Striche uebereinander, ein breiter blasser und ein schmaler heller.
    var kante := schaft.slice(1, schaft.size() - 1)
    draw_polyline(kante, Color(0.24, 0.50, 0.58, 0.16), 5.0, true)
    draw_polyline(kante, Color(0.38, 0.72, 0.80, 0.46), 1.6, true)

    for i in 5:
        var t := lerpf(0.30, 0.86, float(i) / 4.0)
        var halb := _sockelbreite(t) * 0.88
        var y := _sockelhoehe(t)
        draw_line(p + Vector2(-halb, y) * g, p + Vector2(halb, y) * g,
            Color(0.20, 0.40, 0.46, 0.26), 1.6)


## Das Profil des Sockels. `t` laeuft von 0 an der Deckplatte bis 1 am Fuss,
## der unten aus dem Bild laeuft.
## **Schmal.** Der erste Anlauf stand bei 80 Einheiten Halbbreite - das sind
## 232 im Bild, und damit war die Saeule breiter als der Waechter hoch ist:
## ein Keil, der ihn verschluckte, statt eines Sockels, auf dem er steht. Was
## eine Saeule traegt, ist ihre Schlankheit; ein breiter Klotz ist ein Fundament.
func _sockelbreite(t: float) -> float:
    if t < 0.14:
        # Die Deckplatte steht ueber - daran erkennt man eine Saeule.
        return lerpf(58.0, 44.0, t / 0.14)
    var u := (t - 0.14) / 0.86
    return 44.0 - 14.0 * sin(u * PI * 0.85) + 30.0 * pow(u, 3.0)


func _sockelhoehe(t: float) -> float:
    return lerpf(50.0, 330.0, t)
