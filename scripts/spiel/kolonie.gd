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

## Grundton des Felsens. `wache.gd` faerbt ihn je Abschnitt um - der Fels
## nimmt die Farbe des Wassers an, in dem er steht.
var fels := Color(0.055, 0.085, 0.110)

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

## --- Was aus einer Flaeche einen Fels macht ---
##
## Die Wand war eine Flaeche mit vier Schichtlinien darauf, und genau so sah
## sie aus: nicht wie Stein, sondern wie eine dunkle Form. Fels liest man an
## drei Dingen, und keines davon ist die Farbe.
##
##   * **Risse.** Sie laufen quer zur Schichtung, verzweigen sich einmal und
##     hoeren mitten im Nichts auf. Eine Wand ohne Risse ist gegossen.
##   * **Mulden.** Ausbrueche und eingeschlossene Broecken - Flecken, die
##     anders liegen als die Flaeche um sie herum. Sie geben der Wand eine
##     Oberflaeche statt einer Kontur.
##   * **Krusten.** Was auf dem Stein sitzt: Kolonien aus winzigen Punkten,
##     die sich an die Kante draengen, wo das Wasser vorbeizieht. Sie sind
##     der einzige Teil der Wand, der lebt.
##
## Alles drei liegt in Wandkoordinaten und wandert mit dem Versatz seiner
## Ebene - sonst schwimmt die Struktur auf dem Fels statt in ihm.
var _risse: Array[Dictionary] = []
var _mulden: Array[Dictionary] = []
var _krusten: Array[Dictionary] = []

## Schleier: lange Faeden, die von Vorspruengen und Kanten haengen und in der
## Stroemung stehen. Sie sind das Einzige an der Wand, das sich bewegt - und
## Bewegung ist es, woran man Wasser erkennt.
var _schleier: Array[Dictionary] = []

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
    _baue_felsdetail(rng)
    _baue_schleier(rng)


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


## Risse, Mulden und Krusten - je Ebene und Seite aus der fertigen Wandkante
## abgeleitet, damit sie wirklich **auf** dem Fels liegen und nicht daneben.
func _baue_felsdetail(rng: RandomNumberGenerator) -> void:
    _risse.clear()
    _mulden.clear()
    _krusten.clear()

    for ebene in EBENEN:
        # Hintere Ebenen bekommen weniger davon. Nicht aus Sparsamkeit: der
        # Dunst frisst Kanten von vorn nach hinten, und was er ohnehin
        # verschluckt, muss man nicht zeichnen.
        var dichte := 1.0 - 0.62 * EBENE_DUNST[ebene]
        for s in 2:
            var wand: PackedVector2Array = _fernwaende[ebene * 2 + s]
            var kante := wand.slice(1, wand.size() - 1)
            var nach_innen := -SEITEN[s]

            for i in range(2, kante.size() - 2):
                var p: Vector2 = kante[i]

                # Ein Riss: vier Glieder in den Fels hinein, mit einem
                # Abzweig. Er endet mitten in der Flaeche - ein Riss, der die
                # Wand durchquert, waere ein Spalt.
                if rng.randf() < 0.30 * dichte:
                    var linie := PackedVector2Array([p])
                    var richtung := Vector2(-nach_innen, rng.randf_range(-0.5, 0.5)).normalized()
                    var punkt := p
                    for _g in 4:
                        richtung = richtung.rotated(rng.randf_range(-0.5, 0.5)).normalized()
                        punkt += richtung * rng.randf_range(9.0, 26.0)
                        linie.append(punkt)
                    var abzweig := PackedVector2Array()
                    if linie.size() > 2:
                        var ab: Vector2 = linie[2]
                        abzweig.append(ab)
                        abzweig.append(ab + richtung.rotated(rng.randf_range(0.6, 1.3))
                            * rng.randf_range(10.0, 24.0))
                    _risse.append({
                        &"ebene": ebene, &"linie": linie, &"abzweig": abzweig,
                        &"staerke": rng.randf_range(0.5, 1.0),
                    })

                # Platten: grosse, kantige Broecken, die die ganze Wandbreite
                # bedecken - nicht nur einen Saum an der Kante.
                #
                # Zuerst waren es kleine Mulden dicht an der Kante. Das war zu
                # wenig: die Wand nimmt fast die Haelfte des Bildes ein, und
                # in dieser Flaeche lagen ein paar Tupfen. Fels liest man an
                # **grossen** Formen, die einander ueberlappen; das Kleinzeug
                # kommt erst danach und nur dort, wo man es sieht.
                for _t in 3:
                    if rng.randf() > 0.52 * dichte:
                        continue
                    var weg := rng.randf_range(6.0, 210.0)
                    var mitte := p + Vector2(-nach_innen * weg,
                        rng.randf_range(-28.0, 28.0))
                    # Weiter aussen groesser: dort steht kein Detail daneben,
                    # das den Massstab setzt, und kleine Formen wuerden dort
                    # zu Rauschen.
                    var r := rng.randf_range(16.0, 34.0) * (0.7 + weg / 210.0)
                    var form := PackedVector2Array()
                    var ecken := rng.randi_range(5, 7)
                    var dreh := rng.randf_range(0.0, TAU)
                    for e in ecken:
                        var w := dreh + TAU * float(e) / float(ecken)
                        var rr := r * rng.randf_range(0.66, 1.30)
                        form.append(mitte + Vector2(cos(w) * rr, sin(w) * rr * 0.80))
                    _mulden.append({
                        &"ebene": ebene, &"form": form,
                        &"innen": nach_innen,
                        &"tiefer": rng.randf() < 0.5,
                    })

            # Krusten nur auf der vordersten Wand: dort, wo sie noch als
            # Kolonie zu erkennen sind statt als Rauschen.
            if EBENE_DUNST[ebene] > 0.01:
                continue
            for i in range(1, kante.size() - 1):
                if rng.randf() > 0.34:
                    continue
                var q: Vector2 = kante[i]
                var punkte := PackedVector2Array()
                var groessen := PackedFloat32Array()
                for _k in rng.randi_range(5, 11):
                    punkte.append(q + Vector2(
                        -nach_innen * rng.randf_range(1.0, 26.0),
                        rng.randf_range(-15.0, 15.0)))
                    groessen.append(rng.randf_range(1.1, 3.2))
                _krusten.append({
                    &"punkte": punkte, &"groessen": groessen,
                    &"takt": rng.randf_range(0.5, 1.4),
                    &"phase": rng.randf_range(0.0, TAU),
                })


## Schleier: Faeden, die von der vordersten Kante haengen und in der Stroemung
## stehen. Sie sind lang, duenn und langsam - alles andere sieht aus wie Regen.
func _baue_schleier(rng: RandomNumberGenerator) -> void:
    _schleier.clear()
    var kante := _wand_links.slice(1, _wand_links.size() - 1) \
        + _wand_rechts.slice(1, _wand_rechts.size() - 1)
    for i in range(0, kante.size(), 1):
        if rng.randf() > 0.5:
            continue
        var p: Vector2 = kante[i]
        var nach_innen := -signf(p.x)
        # Kurz und viele, nicht lang und wenige. Bei fuenf Gliedern zu je
        # dreissig Pixeln reichten sie quer durch das halbe Bild und sahen aus
        # wie Kratzer auf der Linse - ein Faden, der laenger ist als der
        # Bewuchs, an dem er haengt, liest sich nicht mehr als Bewuchs.
        var glieder := PackedFloat32Array()
        for _g in rng.randi_range(3, 4):
            glieder.append(rng.randf_range(9.0, 17.0))
        _schleier.append({
            &"ort": p + Vector2(nach_innen * 3.0, 0.0),
            &"innen": nach_innen,
            &"glieder": glieder,
            &"takt": rng.randf_range(0.3, 0.7),
            &"phase": rng.randf_range(0.0, TAU),
            &"weite": rng.randf_range(0.18, 0.55),
        })


func _draw() -> void:
    # Von hinten nach vorn. Das ist die ganze Ordnung, die Tiefe ausmacht.
    for ebene in EBENEN:
        var versatz := Vector2(0.0, -fmod(zeit * EBENE_TEMPO[ebene], 220.0))
        _zeichne_wand(_fernwaende[ebene * 2], ebene, versatz)
        _zeichne_wand(_fernwaende[ebene * 2 + 1], ebene, versatz)
        # Erst die Mulden, dann die Risse: eine Mulde ist eine Flaeche im
        # Fels, ein Riss laeuft darueber hinweg. Andersherum verschwaende der
        # Riss in der Mulde, durch die er geht.
        _zeichne_mulden(ebene, versatz)
        _zeichne_risse(ebene, versatz)
        _zeichne_vorspruenge(ebene, versatz)

    _zeichne_krusten()
    _zeichne_schleier()
    _zeichne_bewuchs()
    _zeichne_nischen()
    _zeichne_polypen()
    # Der Sockel gehoert hinter die Brut. Andersherum deckte er die Eierreihe
    # zu - und die Brut ist das Einzige im Bild, das der Spieler die ganze
    # Zeit sehen muss.
    _zeichne_sockel()
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

    draw_colored_polygon(verschoben, fels.lerp(DUNST, dunst))

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
        draw_colored_polygon(punkte, fels.lightened(0.09).lerp(DUNST, dunst * 0.86))
        draw_polyline(punkte + PackedVector2Array([punkte[0]]),
            FELS_KANTE.lerp(DUNST, dunst), 1.6, true)


## Mulden: Ausbrueche und eingeschlossene Broecken. Eine Wand hat nicht nur
## eine Kante, sondern eine Oberflaeche - und die sieht man nur, wenn etwas
## darauf anders liegt als der Rest.
func _zeichne_mulden(ebene: int, versatz: Vector2) -> void:
    var dunst := EBENE_DUNST[ebene]
    var grund := fels.lerp(DUNST, dunst)
    for m in _mulden:
        if int(m[&"ebene"]) != ebene:
            continue
        var form := PackedVector2Array()
        for v: Vector2 in m[&"form"]:
            form.append(v + versatz)
        # **Heller, nicht dunkler - beide Sorten.**
        #
        # Der erste Entwurf machte tiefe Mulden dunkel. Auf einem Fels, der
        # ohnehin bei 0.055 liegt, ist dunkler aber kein Ton mehr, sondern
        # Schwarz: im Bild standen Loecher in der Wand, als waere die
        # Zeichnung kaputt. Nach unten ist hier kein Platz. Was eine Mulde
        # von einem Buckel unterscheidet, ist deshalb nicht die Helligkeit
        # der Flaeche, sondern **wo ihr heller Saum liegt** - oben bei einem
        # Buckel, unten bei einer Mulde. Genau daran liest ein Auge Relief
        # ab, und es funktioniert auch bei fast keinem Kontrast.
        var tiefer := bool(m[&"tiefer"])
        draw_colored_polygon(form, grund.lightened(0.045 if tiefer else 0.085))

        # **Der Saum liegt zur Grabenmitte hin.**
        #
        # Im Bild gibt es genau eine Lichtquelle, und die steht unten in der
        # Mitte: der Kegel des Waechters. Also faengt jede Flaeche, die zur
        # Mitte zeigt, Licht, und jede, die von ihr wegzeigt, keines. Das
        # kostet nichts und ist der einzige Grund, warum ein flaches Vieleck
        # wie ein Brocken aussieht statt wie ein Fleck.
        var innen: float = m[&"innen"]
        var mitte := mitte_von(form)
        var saum := Color(0.34, 0.62, 0.68, (0.24 if tiefer else 0.16) * (1.0 - dunst))
        var licht := PackedVector2Array()
        for i in form.size():
            var a: Vector2 = form[i]
            var b: Vector2 = form[(i + 1) % form.size()]
            if signf((a + b).x * 0.5 - mitte.x * 2.0 + mitte.x) == innen:
                draw_line(a, b, saum, 1.4)
                licht.append(a)


## Der Mittelpunkt eines Vielecks - fuer die Frage, welche Haelfte seines
## Randes oben liegt und welche unten.
func mitte_von(form: PackedVector2Array) -> Vector2:
    var summe := Vector2.ZERO
    for v in form:
        summe += v
    return summe / float(maxi(1, form.size()))


## Risse: quer zur Schichtung, mit einem Abzweig, und sie hoeren mitten im
## Fels auf. Einer, der die Wand durchquert, waere ein Spalt.
func _zeichne_risse(ebene: int, versatz: Vector2) -> void:
    var dunst := EBENE_DUNST[ebene]
    if dunst > 0.9:
        return
    for r in _risse:
        if int(r[&"ebene"]) != ebene:
            continue
        # Auch hier hell statt dunkel, und aus demselben Grund. Physikalisch
        # stimmt es sogar besser: was man von einem Riss sieht, ist nicht der
        # Spalt - der ist zu schmal -, sondern die aufgebrochene Kante daneben,
        # und die faengt Licht.
        var deckung: float = 0.24 * float(r[&"staerke"]) * (1.0 - dunst)
        var farbe := Color(0.34, 0.60, 0.66, deckung)
        var linie := PackedVector2Array()
        for v: Vector2 in r[&"linie"]:
            linie.append(v + versatz)
        draw_polyline(linie, farbe, 1.5, true)
        var ab: PackedVector2Array = r[&"abzweig"]
        if ab.size() > 1:
            draw_line(ab[0] + versatz, ab[1] + versatz, farbe, 1.1)


## Krusten: Kolonien winziger Punkte, die sich an die Kante draengen. Sie
## atmen von sich aus und flammen auf, wenn der Kegel darueberzieht - das
## Einzige an der Wand, das lebt.
func _zeichne_krusten() -> void:
    var versatz := Vector2(0.0, -fmod(zeit * EBENE_TEMPO[EBENEN - 1], 220.0))
    for k in _krusten:
        var atem := 0.5 + 0.5 * sin(zeit * float(k[&"takt"]) + float(k[&"phase"]))
        var punkte: PackedVector2Array = k[&"punkte"]
        var groessen: PackedFloat32Array = k[&"groessen"]
        # Das Licht einmal je Kruste, nicht je Punkt: `beleuchtung()` ist die
        # teuerste Rechnung im Bild, und eine Kolonie steht ohnehin im selben
        # Lichtfleck.
        var hell := _licht_auf(punkte[0] + versatz)
        for i in punkte.size():
            var p: Vector2 = punkte[i] + versatz
            draw_circle(p, groessen[i] * (0.9 + 0.1 * atem),
                Color(0.30, 0.62, 0.66, 0.30 + 0.16 * atem + 0.50 * hell))


## Schleier: lange Faeden von der Kante, die in der Stroemung stehen. Jedes
## Glied haengt weiter zurueck als das vorige - so biegt sich der Faden,
## statt zu schwingen wie eine Saite.
func _zeichne_schleier() -> void:
    var versatz := Vector2(0.0, -fmod(zeit * EBENE_TEMPO[EBENEN - 1], 220.0))
    for f in _schleier:
        var ort: Vector2 = (f[&"ort"] as Vector2) + versatz
        var innen: float = f[&"innen"]
        var weite: float = f[&"weite"]
        var takt: float = f[&"takt"]
        var phase: float = f[&"phase"]
        var glieder: PackedFloat32Array = f[&"glieder"]

        var linie := PackedVector2Array([ort])
        var punkt := ort
        var winkel := 0.0
        for g in glieder.size():
            winkel += weite * sin(zeit * takt + phase + float(g) * 0.55) \
                / float(g + 1)
            var richtung := Vector2(innen * sin(winkel), cos(winkel) * 0.92 + 0.08)
            punkt += richtung * glieder[g]
            linie.append(punkt)

        var hell := _licht_auf(linie[linie.size() / 2])
        draw_polyline(linie, Color(0.20, 0.44, 0.48,
            0.26 + 0.34 * hell), 1.6, true)
        draw_circle(linie[linie.size() - 1], 1.8 + 2.4 * hell,
            Color(0.44, 0.86, 0.90, 0.24 + 0.50 * hell))


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
            draw_circle(p, 14.0, Color(BRUT_FARBE.r, BRUT_FARBE.g, BRUT_FARBE.b,
                0.07 + 0.06 * puls))
            draw_circle(p, 9.0, Color(BRUT_FARBE.r, BRUT_FARBE.g, BRUT_FARBE.b,
                0.16 + 0.08 * puls))
            draw_circle(p, 6.4, BRUT_FARBE)
            # Ein Keim darin, der sich leicht bewegt. Ein Ei ohne etwas darin
            # ist ein Punkt; eines mit etwas darin ist ein Grund, es zu
            # verteidigen.
            var keim := p + Vector2(sin(zeit * 0.9 + float(i)) * 1.4,
                cos(zeit * 1.1 + float(i)) * 1.1)
            draw_circle(keim, 3.0, Color(1.0, 0.96, 0.86, 0.9))
            draw_circle(keim, 1.4, Color(1.0, 1.0, 0.96, 1.0))
        else:
            # Zerbrochen: die leere Schale und ein Rest, der noch verglimmt.
            draw_arc(p, 6.0, 0.35, PI - 0.35, 10, Color(0.34, 0.30, 0.26, 0.7), 1.6)
            draw_line(p + Vector2(-5.0, 1.0), p + Vector2(-2.0, -4.0),
                Color(0.30, 0.26, 0.22, 0.6), 1.2)
            draw_line(p + Vector2(5.0, 1.0), p + Vector2(2.5, -3.5),
                Color(0.30, 0.26, 0.22, 0.6), 1.2)


## Der Kalkwulst, in dem der Waechter steckt. Ohne ihn schwebt er ueber der
## Brut; mit ihm ist er festgewachsen wie alles andere hier auch.
##
## Nach unten laeuft er aus dem Bild - ein Sockel mit sichtbarer Unterkante
## sieht aus wie eine Kiste, auf der jemand sitzt.
func _zeichne_sockel() -> void:
    var p := Graben.WAECHTER
    var kuppe := PackedVector2Array()
    for i in 15:
        var w := lerpf(PI, TAU, float(i) / 14.0)
        var welle := 1.0 + 0.09 * sin(float(i) * 2.3)
        kuppe.append(p + Vector2(cos(w) * 74.0 * welle, sin(w) * 24.0 * welle + 52.0))
    var sockel := kuppe.duplicate()
    sockel.append(p + Vector2(82.0, 300.0))
    sockel.append(p + Vector2(-82.0, 300.0))
    draw_colored_polygon(sockel, fels.lightened(0.04))
    draw_polyline(kuppe, Color(0.18, 0.36, 0.42, 0.34), 1.4, true)


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

    # Adern im Leib, die zum Leuchtorgan laufen. Sie pulsen leicht versetzt -
    # das ist der billigste Weg, einem stillen Koerper Leben zu geben.
    for i in 3:
        var s_i := lerpf(-13.0, 13.0, float(i) / 2.0)
        var ader := PackedVector2Array([
            p + Vector2(s_i * 1.6, 40.0),
            p + Vector2(s_i * 1.15, 12.0),
            p + Vector2(s_i * 0.5, -12.0),
        ])
        var glut := 0.5 + 0.5 * sin(zeit * 1.6 + float(i) * 1.1)
        draw_polyline(ader, Color(0.42, 0.86, 0.94, 0.18 + 0.20 * glut), 2.0, true)

    # Das Leuchtorgan selbst: Kern, Hof und ein Kranz feiner Fuehler.
    var kopf := p + Vector2(0.0, -18.0)
    for i in 9:
        var w := lerpf(-PI * 0.85, -PI * 0.15, float(i) / 8.0)
        var laenge := 13.0 + 5.0 * sin(zeit * 1.4 + float(i) * 0.9)
        draw_line(kopf, kopf + Vector2(cos(w), sin(w)) * laenge,
            Color(0.46, 0.88, 0.96, 0.30), 1.3)
    draw_circle(kopf, 20.0 + puls * 3.0, Color(0.40, 0.86, 0.98, 0.10))
    draw_circle(kopf, 9.0 + puls * 1.5, Color(0.70, 0.98, 1.0, 0.85))
    draw_circle(kopf, 4.2, Color(1.0, 1.0, 0.98, 0.95))
