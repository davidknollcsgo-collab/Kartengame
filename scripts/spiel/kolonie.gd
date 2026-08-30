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
var fels := Color(0.030, 0.050, 0.068)

const FELS := Color(0.030, 0.050, 0.068)
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
## **Weiter auseinander als zuerst.** Bei 168 stand die hinterste Wand bei
## x = 138 von 360 - sie reichte also bis fast auf ein Drittel der Bildbreite
## an die Mitte heran, und der Graben wirkte wie ein Schacht, in dem man
## klemmt. Perspektive lebt vom Versatz, nicht von der Verengung: die Ebenen
## duerfen sich staffeln, aber sie duerfen den Blick nicht zumauern.
const EBENE_EINZUG: PackedFloat32Array = [92.0, 44.0, 0.0]

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
## **Sie muss deutlich heller sein als der Fels, sonst tut die ganze
## Staffelung nichts.**
##
## Hier stand `Color(0.052, 0.118, 0.146)` gegen einen Fels von
## `(0.055, 0.085, 0.110)` - der Unterschied lag im Hundertstel. Drei Ebenen,
## die verschieden weit weg sein sollen, kamen damit in praktisch derselben
## Farbe heraus: die Waende sahen flach aus, und zwar nicht, weil zu wenig
## darauf gezeichnet war, sondern weil ihnen der Tonwert fehlte. Aerial
## perspective ist kein Effekt, den man dazustellt - sie ist der Abstand
## zwischen zwei Farben, und wenn der null ist, gibt es sie nicht.
const DUNST := Color(0.088, 0.168, 0.198)

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

## --- Leben, das nicht mitspielt ---
##
## Zwischen den Waenden stand bisher Wasser und sonst nichts. Das ist die
## groesste Flaeche im Bild, und sie war leer - kein Wunder, dass der Graben
## unbewohnt wirkte: das einzige Lebendige darin waren die Raeuber, die einen
## umbringen wollen, und das eigene Tier.
##
## Also Treiber: kleine Quallen und Schwaermchen weit hinten, die ihre eigenen
## Bahnen ziehen. Sie treffen nichts und werden von nichts getroffen -
## **sie sind ausdruecklich keine Spielfiguren**, und darum stehen sie hier
## und nicht in `schwarm.gd`. Wenn sie irgendwann anfangen, dem Kegel
## auszuweichen, sind sie es geworden, und dann gehoeren sie in den Rechenkern.
var _treiber: Array[Dictionary] = []

## --- Was auf dem Fels waechst ---
##
## Der Graben war grau in grau: dunkler Fels, tuerkises Wasser, ein tuerkiser
## Kegel. Ein Bild mit einem Farbton ist eine Tonung, keine Farbgebung - und
## ein Riff ohne Riff ist eine Felswand.
##
## Also Bewuchs in drei Bauarten, weil eine Form fuenfzigmal wiederholt ein
## Muster ergibt und drei Formen ein Oekosystem: **Faecher**, die quer zur
## Stroemung stehen; **Roehrenbuendel**, die nach oben zeigen; und
## **Anemonen**, deren Arme sich bewegen. Alle drei in warmen und violetten
## Toenen, denn das Blau bekommt seinen Wert erst durch das, was nicht blau
## ist.
var _korallen: Array[Dictionary] = []

## Zeichen im Fels: kleine leuchtende Marken, die langsam atmen. Sie erzaehlen
## nichts und tun nichts - sie geben der Wand nur etwas, das man ansieht.
var _zeichen: Array[Dictionary] = []

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
    _baue_treiber(rng)
    _baue_korallen(rng)
    _baue_zeichen(rng)


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
        #
        # Die 330 stand einmal auf 306. Zusammen mit dem geringeren Einzug
        # der hinteren Ebenen oeffnet das den Graben spuerbar - das Spiel
        # findet in der Mitte statt, und die Waende sind der Rahmen, nicht
        # der Inhalt.
        var tief := 330.0 - einzug \
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
        var wurzel := seite * (330.0 - EBENE_EINZUG[ebene] + 8.0)
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
                # Nur auf den fernen Ebenen. Die vorderste Wand ist die
                # dunkelste und die naechste - sie traegt die Silhouette, und
                # eine Silhouette wird durch Struktur nicht besser, sondern
                # unruhiger.
                if ebene >= EBENEN - 1:
                    continue
                for _t in 2:
                    if rng.randf() > 0.40 * dichte:
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


## Treiber: Quallen und Schwaermchen im offenen Wasser.
##
## Sie liegen auf einer eigenen, sehr fernen Ebene - hell und blau wie alles
## Ferne, langsam, und ohne jede Beziehung zum Spiel. Ihre Bahn ist eine
## Schleife: waagerecht wandern, senkrecht atmen, und wenn sie unten aus dem
## Bild laufen, oben wieder herein.
## Die Farben der Treiber.
##
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
    var kante := _wand_links.slice(1, _wand_links.size() - 1) \
        + _wand_rechts.slice(1, _wand_rechts.size() - 1)
    for i in kante.size():
        if rng.randf() > 0.34:
            continue
        var p: Vector2 = kante[i]
        var innen := -signf(p.x)
        var arme := PackedFloat32Array()
        for _a in rng.randi_range(6, 11):
            arme.append(rng.randf_range(0.5, 1.0))
        _korallen.append({
            # **An der Kante, mit dem Fuss knapp im Fels.**
            #
            # Zuerst sass der Fuss bis zu 34 Einheiten *im* Gestein - und
            # weil alle Arme nach innen wachsen, standen die Korallen damit
            # groesstenteils hinter der Wand. Im Bild waren sie ein farbiger
            # Saum am aeussersten Rand. Bewuchs sitzt dort, wo Fels und
            # Wasser sich treffen, und ragt ins Wasser: das ist der Ort, an
            # dem es Stroemung gibt, und der Grund, warum er dort waechst.
            &"ort": p + Vector2(-innen * rng.randf_range(-6.0, 12.0),
                rng.randf_range(-16.0, 16.0)),
            &"innen": innen,
            &"art": rng.randi() % 3,
            &"gross": rng.randf_range(34.0, 98.0),
            &"neigung": rng.randf_range(-0.5, 0.5),
            &"arme": arme,
            &"takt": rng.randf_range(0.25, 0.7),
            &"phase": rng.randf_range(0.0, TAU),
            &"farbe": KORALL_FARBEN[rng.randi() % KORALL_FARBEN.size()],
        })


func _zeichne_korallen() -> void:
    var versatz := Vector2(0.0, -fmod(zeit * EBENE_TEMPO[EBENEN - 1], 220.0))
    for k in _korallen:
        var p: Vector2 = (k[&"ort"] as Vector2) + versatz
        var innen: float = k[&"innen"]
        var r: float = k[&"gross"]
        var farbe: Color = k[&"farbe"]
        var atem: float = 0.5 + 0.5 * sin(zeit * float(k[&"takt"]) + float(k[&"phase"]))
        var arme: PackedFloat32Array = k[&"arme"]
        var neigung: float = k[&"neigung"]
        # Einmal je Klumpen, nicht je Arm: `beleuchtung()` ist die teuerste
        # Rechnung im Bild.
        var hell := _licht_auf(p)
        var kraft := 0.42 + 0.58 * hell

        match int(k[&"art"]):
            0:
                _koralle_faecher(p, r, farbe, kraft, innen, neigung, arme, atem)
            1:
                _koralle_roehren(p, r, farbe, kraft, innen, arme, atem)
            _:
                _koralle_anemone(p, r, farbe, kraft, innen, arme, atem)


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
        var spitze := p + richtung * laenge
        spitzen.append(spitze)
        draw_line(p, spitze, Color(farbe.r, farbe.g, farbe.b, 0.34 * kraft),
            1.0 + r * 0.035)
    # Das Netz zwischen den Rippen - daran erkennt man einen Faecher.
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
        draw_line(fuss, spitze, Color(farbe.r, farbe.g, farbe.b, 0.30 * kraft),
            1.4 + r * 0.05)
        draw_circle(spitze, 1.2 + r * 0.055,
            Color(farbe.r, farbe.g, farbe.b, 0.42 * kraft))
        draw_circle(spitze, 0.6 + r * 0.022,
            Color(1.0, 0.96, 0.90, 0.30 * kraft))


## Eine Anemone: ein Fuss und Arme, die sich einzeln bewegen.
func _koralle_anemone(p: Vector2, r: float, farbe: Color, kraft: float,
        innen: float, arme: PackedFloat32Array, atem: float) -> void:
    draw_circle(p, r * 0.30 * (0.9 + 0.1 * atem),
        Color(farbe.r, farbe.g, farbe.b, 0.20 * kraft))
    for i in arme.size():
        var t := float(i) / float(maxi(1, arme.size() - 1))
        var w := lerpf(-1.25, 1.25, t)
        var linie := PackedVector2Array([p])
        var punkt := p
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


## Zeichen im Fels.
##
## Jedes ist ein kurzer Streckenzug auf einem Gitter von drei mal drei - so
## entstehen Marken, die aussehen, als haetten sie eine Bedeutung, ohne dass
## eine hineingelegt werden muss. Wichtig ist nur, dass sie **kantig** sind:
## eine runde Kritzelei liest sich als Fehler, eine eckige als Schrift.
func _baue_zeichen(rng: RandomNumberGenerator) -> void:
    _zeichen.clear()
    var kante := _wand_links.slice(1, _wand_links.size() - 1) \
        + _wand_rechts.slice(1, _wand_rechts.size() - 1)
    for i in kante.size():
        if rng.randf() > 0.26:
            continue
        var p: Vector2 = kante[i]
        var innen := -signf(p.x)
        var strich := PackedVector2Array()
        var punkt := Vector2(rng.randi_range(0, 2), rng.randi_range(0, 2))
        strich.append(punkt)
        for _g in rng.randi_range(2, 4):
            var richtung := Vector2(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
            if richtung == Vector2.ZERO:
                richtung = Vector2.DOWN
            punkt = (punkt + richtung).clamp(Vector2.ZERO, Vector2(2.0, 2.0))
            strich.append(punkt)
        _zeichen.append({
            &"ort": p + Vector2(-innen * rng.randf_range(40.0, 200.0),
                rng.randf_range(-30.0, 30.0)),
            &"strich": strich,
            &"gross": rng.randf_range(10.0, 20.0),
            &"takt": rng.randf_range(0.20, 0.55),
            &"phase": rng.randf_range(0.0, TAU),
        })


func _zeichne_zeichen() -> void:
    var versatz := Vector2(0.0, -fmod(zeit * EBENE_TEMPO[EBENEN - 1], 220.0))
    for z in _zeichen:
        var atem: float = 0.5 + 0.5 * sin(zeit * float(z[&"takt"]) + float(z[&"phase"]))
        var r: float = z[&"gross"]
        var ort: Vector2 = (z[&"ort"] as Vector2) + versatz
        var strich: PackedVector2Array = z[&"strich"]
        var linie := PackedVector2Array()
        for g in strich:
            linie.append(ort + (g - Vector2.ONE) * r)
        var a := 0.16 + 0.24 * atem
        draw_polyline(linie, Color(0.46, 0.86, 0.82, a * 0.45), 4.4, true)
        draw_polyline(linie, Color(0.68, 0.96, 0.90, a), 1.4, true)


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

    # Zwischen die hinteren Waende und den Bewuchs: die Treiber stehen im
    # offenen Wasser, also vor dem Fels und hinter allem, was am Fels sitzt.
    # **Hier standen einmal sechs Lagen Kleinkram uebereinander:** Krusten,
    # Schleier, Roehrenbewuchs, Zeichen, Korallen, Treiber. Jede fuer sich
    # war begruendet, zusammen ergaben sie ein Rauschen, in dem der Spieler
    # die Raeuber suchen musste. Ein Bild wird nicht reicher, indem man mehr
    # hineinlegt - es wird reicher, wenn das, was drin ist, groesser ist und
    # Platz hat. Uebrig sind drei: Treiber im Wasser, Zeichen im Fels,
    # Korallen an der Kante.
    _zeichne_treiber()
    _zeichne_zeichen()
    _zeichne_korallen()
    _zeichne_nischen()
    _zeichne_polypen()
    # Der Sockel gehoert hinter die Brut. Andersherum deckte er die Eierreihe
    # zu - und die Brut ist das Einzige im Bild, das der Spieler die ganze
    # Zeit sehen muss.
    _zeichne_sockel()
    _zeichne_brut()
    # Der Waechter steht nicht mehr hier. Er wird **ueber** dem Kegel
    # gezeichnet - siehe `waechter.gd`.


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

    # **Die Kante ist kein Strich.**
    #
    # Vorher lag hier eine einzelne helle Linie um jede Wand, und genau die
    # machte aus dem Graben eine Zeichnung: im Tiefenwasser gibt es keine
    # scharfe Grenze zwischen Fels und Wasser, weil die Strecke dazwischen
    # selbst streut. Was man sieht, ist ein Saum, der ueber ein paar Meter
    # ausblutet - und je weiter weg, desto breiter und schwaecher.
    #
    # Also drei Striche uebereinander: aussen breit und fast durchsichtig,
    # innen schmal und heller. Die Reihenfolge zaehlt - der breite zuerst,
    # sonst frisst er den schmalen.
    var breit := 9.0 + 7.0 * dunst
    for i in 3:
        var t := float(i) / 2.0
        draw_polyline(kante, Color(FELS_KANTE.r, FELS_KANTE.g, FELS_KANTE.b,
            lerpf(0.05, 0.42, t) * (1.0 - 0.55 * dunst)),
            lerpf(breit, 1.4, t), true)

    # **Und ein Dunstsaum, der in das offene Wasser hineinlaeuft.**
    #
    # Ohne ihn endet die ferne Wand an einer Linie, und weil sie heller ist
    # als das tiefe Wasser dahinter, steht dort eine senkrechte Kante quer
    # durch das Bild - im breiteren Graben faellt das sofort auf: ein
    # schwarzer Block mit sauber gezogenem Rand. Wasser tut das nicht. Die
    # Strecke zwischen Auge und Fels streut, also loest sich der Fels ueber
    # ein paar Meter auf, und je weiter weg, desto weiter.
    _zeichne_kantendunst(kante, ebene)

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


## Ein Streifen entlang der Wandkante, der nach innen auf null ausblutet.
## `draw_polygon` nimmt eine Farbe je Eckpunkt - damit ist es ein einziger
## Verlauf und keine Stapelung, die Streifen ergaebe.
func _zeichne_kantendunst(kante: PackedVector2Array, ebene: int) -> void:
    if kante.size() < 2:
        return
    var dunst := EBENE_DUNST[ebene]
    # Fern heisst breit: was weiter weg liegt, hat mehr streuendes Wasser
    # davor. Und fern heisst zugleich schwaecher, weil dort ohnehin schon
    # alles im Dunst steht.
    var weite := 34.0 + 96.0 * dunst
    var farbe := fels.lerp(DUNST, dunst)
    var voll := Color(farbe.r, farbe.g, farbe.b, 0.55 - 0.25 * dunst)
    var leer := Color(farbe.r, farbe.g, farbe.b, 0.0)

    var nach_innen := -signf(kante[0].x)
    for i in kante.size() - 1:
        var a: Vector2 = kante[i]
        var b: Vector2 = kante[i + 1]
        draw_polygon(
            PackedVector2Array([a, b,
                b + Vector2(nach_innen * weite, 0.0),
                a + Vector2(nach_innen * weite, 0.0)]),
            PackedColorArray([voll, voll, leer, leer]))


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

    # **Der Kontrast einer Platte ist ein Anteil ihres Grundes, kein Betrag.**
    #
    # Hier stand `grund.lightened(0.085)`. `lightened` mischt gegen Weiss,
    # also hebt es einen dunklen Ton um fast den vollen Betrag - auf einem
    # Fels mit dem Wert 0.15 sind das +0.078, die Haelfte obendrauf. Im Bild
    # waren das keine Platten mehr, sondern helle Sechsecke, die mitten im
    # Wasser schwebten: flach, hartkantig, wie ausgeschnittenes Papier. Und
    # ausgerechnet auf den **fernen** Ebenen fiel es am meisten auf, weil der
    # Dunst dort den Fels aufhellt und ihn damit dem Wasser angleicht - eine
    # Platte mit festem Aufschlag steht dann allein im Bild.
    #
    # Ein Faktor tut, was ein Betrag nicht kann: er waechst mit dem Grund und
    # verschwindet mit ihm. Und weil der Dunst mit der Entfernung auch die
    # Struktur frisst und nicht nur die Farbe, geht er hier ein zweites Mal
    # ein - das ist Luftperspektive, konsequent zu Ende gedacht.
    var wirkung := 1.0 - 0.72 * dunst

    for m in _mulden:
        if int(m[&"ebene"]) != ebene:
            continue
        var form := PackedVector2Array()
        for v: Vector2 in m[&"form"]:
            form.append(v + versatz)

        # **Kein flacher Ton, sondern ein Verlauf ueber die Platte.**
        #
        # Es gibt genau eine Lichtquelle im Bild - den Kegel unten in der
        # Mitte. Also ist die Seite, die zur Grabenmitte zeigt, die helle,
        # und die abgewandte laeuft auf den Fels zurueck. Damit hat die
        # Platte an ihrer Rueckseite **gar keine Kante mehr**: sie geht dort
        # in die Wand ueber, statt an einer Linie aufzuhoeren. Genau das war
        # der Grund, warum eine Platte wie ein Aufkleber aussah.
        var tiefer := bool(m[&"tiefer"])
        var hub := (0.11 if tiefer else 0.19) * wirkung
        var innen: float = m[&"innen"]
        var mitte := mitte_von(form)
        var weite := 1.0
        for v in form:
            weite = maxf(weite, absf(v.x - mitte.x))

        var farben := PackedColorArray()
        for v in form:
            # 0 an der abgewandten Kante, 1 an der zur Mitte zeigenden.
            var t := clampf(0.5 + 0.5 * (v.x - mitte.x) * innen / weite, 0.0, 1.0)
            var k := hub * t * t
            farben.append(Color(grund.r * (1.0 + k), grund.g * (1.0 + k),
                grund.b * (1.0 + k * 0.86)))
        draw_polygon(form, farben)

        # Eine Mulde von einem Buckel unterscheidet nicht die Helligkeit der
        # Flaeche, sondern wo ihr heller Saum liegt. Er bleibt - aber leise,
        # und nur dort, wo ueberhaupt noch Licht ankommt.
        if dunst > 0.5:
            continue
        var saum := Color(0.34, 0.62, 0.68,
            (0.13 if tiefer else 0.09) * (1.0 - dunst))
        for i in form.size():
            var a: Vector2 = form[i]
            var b: Vector2 = form[(i + 1) % form.size()]
            if signf((a + b).x * 0.5 - mitte.x) == innen:
                draw_line(a, b, saum, 1.4)


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
func _zeichne_brut() -> void:
    var breite := Graben.BRUT_BREITE
    var links := -breite * 0.5
    var abstand := breite / float(maxi(1, brut_voll - 1))

    # **Erst das Bett, dann die Eier, dann die Lippe darueber.**
    #
    # Die dritte Lage ist die, auf die es ankommt: ein schmaler Saum, der
    # ueber die untere Kante jedes Eis laeuft. Ohne ihn liegen die Eier
    # *auf* der Membran wie Muenzen auf einem Tisch; mit ihm stecken sie
    # darin. Es ist derselbe Trick, mit dem ein Maler einen Stein ins Wasser
    # setzt - nicht der Stein macht es, sondern die Linie davor.
    _zeichne_gelege(links, breite, false)

    for i in brut_voll:
        # Leicht versetzt statt auf einer Linie. Eine schnurgerade Reihe ist
        # eine Anzeige; eine leicht unruhige ist ein Gelege.
        var hub := sin(float(i) * 2.4) * 3.0
        var p := Vector2(links + abstand * float(i), Graben.BRUT_Y + hub)
        if i < brut:
            _zeichne_ei(p, i)
        else:
            _zeichne_schale(p)

    _zeichne_gelege(links, breite, true)


## Die Membran unter den Eiern. Sie ist der Grund, warum die Reihe wie ein
## Gelege aussieht und nicht wie eine Fortschrittsleiste.
func _zeichne_gelege(links: float, breite: float, vorn: bool) -> void:
    var y := Graben.BRUT_Y
    var oben := PackedVector2Array()
    var unten := PackedVector2Array()
    var stufen := 44
    # Die Lippe liegt hoeher als das Bett - so weit, dass sie das untere
    # Drittel eines Eis deckt und den Keim darin frei laesst.
    var hoehe := (y + 3.0) if vorn else (y + 9.0)
    for i in stufen + 1:
        var t := float(i) / float(stufen)
        var x := links + breite * t
        # An den Enden duenn, in der Mitte dick - und zwei Wellen darauf,
        # eine langsame und eine kurze, damit die Kante nicht gezeichnet
        # aussieht.
        var dicke := (8.0 + 4.0 * sin(t * 9.0 + zeit * 0.5)
            + 2.5 * sin(t * 23.0 - zeit * 0.8)) * sin(t * PI)
        oben.append(Vector2(x, hoehe - dicke * (0.42 if vorn else 1.0)))
        unten.append(Vector2(x, y + 22.0 + dicke * 0.6))

    var haut := oben.duplicate()
    for i in range(unten.size() - 1, -1, -1):
        haut.append(unten[i])
    draw_colored_polygon(haut, Color(0.13, 0.10, 0.06, 0.62 if vorn else 0.50))
    draw_polyline(oben, Color(0.46, 0.35, 0.20, 0.50 if vorn else 0.34), 1.5, true)


## Ein Ei: Hof, Schale, Keim. Der Keim bewegt sich - ein Ei ohne etwas darin
## ist ein Punkt, eines mit etwas darin ist ein Grund, es zu verteidigen.
func _zeichne_ei(p: Vector2, i: int) -> void:
    var puls := 0.5 + 0.5 * sin(zeit * 1.7 + float(i) * 0.6)
    var f := BRUT_FARBE
    # Nicht alle gleich gross. Zwoelf gleiche Kreise sind eine Skala.
    var r := 6.6 * (0.88 + 0.12 * sin(float(i) * 1.9 + 0.7))
    draw_circle(p, r * 2.3, Color(f.r, f.g, f.b, 0.06 + 0.05 * puls))
    draw_circle(p, r * 1.5, Color(f.r, f.g, f.b, 0.15 + 0.07 * puls))
    draw_circle(p, r, f)

    # Ein heller Fleck oben links: die Stelle, an der das Licht des Waechters
    # auf die Schale trifft. Ohne ihn ist ein Kreis eine Scheibe.
    draw_circle(p + Vector2(-r * 0.3, -r * 0.34), r * 0.30,
        Color(1.0, 0.94, 0.78, 0.55))

    var keim := p + Vector2(sin(zeit * 0.9 + float(i)) * 1.4,
        cos(zeit * 1.1 + float(i)) * 1.1)
    draw_circle(keim, 3.0, Color(1.0, 0.96, 0.86, 0.9))
    draw_circle(keim, 1.4, Color(1.0, 1.0, 0.96, 1.0))


## Eine zerbrochene Schale. Sie bleibt liegen - was verloren ist, verschwindet
## nicht, es liegt da.
func _zeichne_schale(p: Vector2) -> void:
    draw_arc(p, 6.0, 0.35, PI - 0.35, 10, Color(0.34, 0.30, 0.26, 0.7), 1.6)
    draw_line(p + Vector2(-5.0, 1.0), p + Vector2(-2.0, -4.0),
        Color(0.30, 0.26, 0.22, 0.6), 1.2)
    draw_line(p + Vector2(5.0, 1.0), p + Vector2(2.5, -3.5),
        Color(0.30, 0.26, 0.22, 0.6), 1.2)
    # Ein Rest, der noch verglimmt.
    draw_circle(p + Vector2(0.0, 2.0), 1.6, Color(0.52, 0.38, 0.20, 0.35))


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
    var schaft := PackedVector2Array()
    var stufen := 22
    for seite: float in SEITEN:
        for i in stufen + 1:
            var t := float(i) / float(stufen)
            if seite > 0.0:
                t = 1.0 - t
            schaft.append(p + Vector2(seite * _sockelbreite(t), _sockelhoehe(t)) * g)
    draw_colored_polygon(schaft, fels.lightened(0.05))

    # Der Kern liegt tief im Schaft, nicht hinter dem Tier: hoeher angesetzt
    # legte er einen Hof um den Waechter und sah aus wie ein zweites Organ.
    for i in 4:
        var t := float(i) / 3.0
        var mitte := p + Vector2(0.0, lerpf(268.0, 150.0, t)) * g
        draw_circle(mitte, lerpf(24.0, 9.0, t) * g,
            Color(0.34, 0.82, 0.84, 0.05 + 0.055 * t))

    var kante := schaft.slice(1, schaft.size() - 1)
    draw_polyline(kante, Color(0.24, 0.46, 0.52, 0.40), 1.8, true)

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
