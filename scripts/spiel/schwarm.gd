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


## Ab wievielen Tieren im Bild die Feinheiten wegfallen.
##
## Ehrlich gesagt: die Bildrate eines Telefons laesst sich von hier aus nicht
## messen - xvfb rendert in Software, es gibt keine Grafikkarte. Statt eine
## Zahl zu erfinden, wird die Zeichenlast begrenzt, wo sie ohnehin nichts
## bringt: bei achtzig Tieren im Bild sieht niemand mehr den Hof um ein
## einzelnes, aber jeder sieht es ruckeln.
## Wie weit der Leib beim Schwimmen ausschlaegt, und woran das gemessen wird.
##
## Neun Grad beim beweglichsten Tier. Mehr sieht nach Zappeln aus - und ein
## Schwarm, der zappelt, ist Rauschen ueber dem halben Bild; dieselbe Grenze
## wie beim Zittern nach einem Treffer.
## Wie stark sich ein Leib beim Schlagen durchbiegt, in Anteilen seiner
## eigenen Laenge. Wird je Tier in `_zeichne()` gesetzt und von `_koerper()`
## gelesen - wie `deckung` und `lichtquelle` auch.
var _biegung := 0.0

const SCHLAG_WINKEL := 0.16
const SCHLAG_BEZUG := 60.0

## Wie weit sich der Schwanz dabei ueber die Laenge des Leibes hinausbiegt.
const SCHLAG_BIEGUNG := 0.20

const DICHT_AB := 80
const SEHR_DICHT_AB := 140

## Links und rechts. Als Konstante, weil ein Feldliteral in einer for-Schleife
## seinen Typ verliert und jede Ableitung daraus mit.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]


## Wird von `rundlauf.gd` gesetzt.
var tiere: Array[Raeuber] = []

## Wo das Licht herkommt - die Spitze des Kegels, also das Boot.
##
## **Weitergereicht, nicht angenommen.** Hier stand der feste Sitz des
## Waechters aus der geloeschten Schlundwache. Dort war das richtig: der
## Kegel setzte immer an derselben Stelle an. Hier faehrt er mit, und ein
## Randlicht, das auf einen festen Weltpunkt zeigt, sagt dem Spieler die
## halbe Zeit die falsche Richtung - die dem Boot zugewandte Kante war nur
## dann hell, wenn das Boot zufaellig gerade dort stand.
##
## Es ist derselbe Ort, den `rundlauf.gd` auch an `_grund.licht_spitze`
## gibt: eine Lichtquelle, eine Zahl.
var lichtquelle := Vector2.ZERO

## Wellenzeit, fuer alles, was zappeln soll, ohne mit dem Alter des einzelnen
## Tieres zu laufen.
var _zeit := 0.0


func _process(delta: float) -> void:
    _zeit += delta


func _ready() -> void:
    # **Mischblendung, nicht mehr additiv - und das ist die Entscheidung,
    # an der die ganze Tierdarstellung haengt.**
    #
    # Additiv war lange richtig: in der Tiefsee leuchtet jedes Tier selbst,
    # und mit Mischblendung sahen die Formen aus wie grauer Nebel auf
    # schwarzem Grund. Nur hat additiv eine Folge, die sich nicht umgehen
    # laesst - **es kann nichts decken**. Jede Flaeche addiert sich zu dem,
    # was dahinter liegt, und zwei uebereinander werden heller statt dass
    # eine die andere verdeckt. Ein gefuellter Leib wird damit zwangslaeufig
    # ein weisser Klecks, und der einzige Ausweg war, die Fuellung fast ganz
    # wegzulassen. Genau das hat die Tiere zu Drahtgittern gemacht: was blieb,
    # war ihr Umriss.
    #
    # Was den Wechsel jetzt traegt, ist die Nachbearbeitung. Die Szene hat
    # ein Gluehen mit einer HDR-Schwelle von 0,62: **was hell ist, blueht
    # weiterhin von selbst** - Photophoren, Augen, Kanten -, und was dunkel
    # ist, deckt endlich. Der Grund, aus dem additiv gewaehlt wurde, ist
    # damit anderweitig erfuellt.
    #
    # Folge fuer alles hier unten, und sie kehrt sich um: es gibt jetzt
    # **dunkle Stellen**. Ein Leib darf eine Schattenseite haben, ein Auge
    # eine Pupille, eine Platte eine Fuge.
    pass


## Die Funkenbluete dieser Welle, oder null. `rundlauf.gd` setzt sie.
var bluete: Bluete = null

## --- Leuchtroehren statt Papierschnitt ---
##
## Die Tiere sollen aussehen wie Leuchtlinien: kein Koerper aus Farbe,
## sondern ein Zug, der glimmt. Das ist nicht bloss Geschmack - die Szene
## laeuft mit einer Nachbearbeitung, und ein Gluehen greift an **hellen,
## schmalen** Stellen. Eine breite Flaeche mit halber Deckung wird davon nur
## milchig; eine helle duenne Linie wird davon zu einer Roehre.
##
## Das stand bis zur Loeschung der Schlundwache hinter einem Schalter, damit
## die andere Schleife unveraendert blieb. Es gibt nur noch eine.

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
    # **Die Daempfung war fuer eine andere Nachbearbeitung gemacht.**
    #
    # Zweiundzwanzig Prozent Farbe mal fuenfundvierzig Prozent Deckung sind
    # zusammen ein Zehntel - ein Leib war damit praktisch nur sein Umriss,
    # und siebzehn Umrisse nebeneinander sind ein Drahtgitter, kein Bestand
    # von Tieren. Die Zahl stammt aus der Zeit, als `glow_bloom` auf 0,55
    # bei einer Schwelle von 0,30 stand: da blueht jede Flaeche, und jede
    # Fuellung wurde milchig.
    #
    # Seit der Bloom auf 0,16 bei 0,62 steht, blueht nur noch, was wirklich
    # hell ist. Eine gedaempfte Fuellung darf deshalb wieder eine Flaeche
    # sein - sie bleibt weit unter der Schwelle und gibt dem Tier trotzdem
    # einen Koerper, vor dem seine hellen Kanten stehen.
    # **Auch eine Fuellung bekommt die Lichtseite.**
    #
    # `_koerper()` schattiert seinen Umriss zum Licht hin, `_fuellung()` legte
    # eine **flache** dunkle Flaeche - und weil jede Flosse, jeder Schwanz,
    # jede Schere und jeder Kiefer hier durchgeht, sass an einem schattierten
    # Leib lauter unschattiertes Beiwerk. Im Bild sah der Zahnkiefer aus wie
    # ein Fisch mit einem aufgeklebten Papierdrachen.
    #
    # Es ist dieselbe Rechnung wie im Leib, nur ohne dessen Verlaufsumfang -
    # ein Anbauteil ist klein, und ein voller Verlauf darauf waere Unruhe.
    farbe = _gedeckt(farbe)
    var mitte := _mitte(punkte)
    var hin := lichtquelle - mitte
    hin = hin.normalized() if hin.length_squared() > 1.0 else Vector2.UP
    var toene := PackedColorArray()
    for v in punkte:
        var zu := maxf(0.0, (v - mitte).normalized().dot(hin))
        var st := 0.62 + 0.60 * zu * zu
        toene.append(Color(farbe.r * 0.30 * st, farbe.g * 0.30 * st,
            farbe.b * 0.32 * st, minf(1.0, farbe.a * 1.9)))
    draw_polygon(punkte, toene)


## Ein Linienzug. Bei Leuchtroehren zweimal: ein weiter blasser Hof und ein
## schmaler heller Kern darauf. Das ist dieselbe Machart wie beim Boot und
## bei den Ranken.
## Wie breit der Hof um einen Zug hoechstens werden darf, in Pixeln.
##
## **Er war unbegrenzt, und das war der Grund, warum kleine Tiere Kleckse
## waren.** `_koerper()` uebergibt eine Dicke von 3,4; mal 3,4 sind das eLF
## Komma sechs Pixel Hof - auf einem Zahnkiefer mit siebzehn Pixeln Radius
## ist das breiter als sein halber Leib. Kiefer, Zaehne und Flossen lagen
## darunter und waren nicht mehr zu sehen; im Bild blieb ein weisser Fleck
## mit einer Flosse daran.
##
## Der Hof gehoert zur Leuchtroehre und bleibt - aber er ist eine
## **Eigenschaft der Linie**, nicht des Tieres, und eine Linie auf einem
## kleinen Tier ist kurz. Sechs Pixel sind auf dem Krebs immer noch ein Hof
## und auf dem Schleier kein Nebel.
const HOF_HOECHSTENS := 6.0


func _zug(punkte: PackedVector2Array, farbe: Color, dicke: float) -> void:
    if punkte.size() < 2:
        return
    farbe = _gedeckt(farbe)
    draw_polyline(punkte, Color(farbe.r, farbe.g, farbe.b,
        farbe.a * 0.22), minf(dicke * 3.4, HOF_HOECHSTENS), true)
    draw_polyline(punkte, Color(minf(1.0, farbe.r * 1.5),
        minf(1.0, farbe.g * 1.5), minf(1.0, farbe.b * 1.5),
        minf(1.0, farbe.a * 1.7)), maxf(1.0, dicke * 0.9), true)


## Dasselbe fuer eine einzelne Strecke.
func _strich(a: Vector2, b: Vector2, farbe: Color, dicke: float) -> void:
    farbe = _gedeckt(farbe)
    draw_line(a, b, Color(farbe.r, farbe.g, farbe.b, farbe.a * 0.22),
        minf(dicke * 3.4, HOF_HOECHSTENS), true)
    draw_line(a, b, Color(minf(1.0, farbe.r * 1.5),
        minf(1.0, farbe.g * 1.5), minf(1.0, farbe.b * 1.5),
        minf(1.0, farbe.a * 1.7)), maxf(1.0, dicke * 0.9), true)


## Die Leuchtpunkte laengs des Koerpers.
##
## Sie sitzen paarweise links und rechts der Bahn, und die Welle laeuft von
## der Nase zum Schwanz - so herum, weil ein Tier, dessen Lichter nach vorn
## laufen, aussieht, als schwimme es rueckwaerts.
func _leuchtpunkte(p: Vector2, r: float, farbe: Color, t: Raeuber,
        hitze: float) -> void:
    var zahl := clampi(int(r * 0.22), 3, 7)
    var k := t.richtung
    var quer := k.orthogonal()
    for i in zahl:
        var u := float(i) / float(zahl - 1)
        # Von der Nase (0.55 r) bis zum Schwanz (-0.75 r).
        var laengs := lerpf(0.55, -0.75, u)
        # Die Welle: eine Sekunde von vorn nach hinten.
        var welle := 0.5 + 0.5 * sin(_zeit * 4.4 - u * 3.4 + t.phase * 5.0)
        var a := (0.20 + 0.55 * welle) * (1.0 + hitze)
        var gr := r * (0.055 + 0.030 * welle)
        var hell := Color(minf(1.0, farbe.r * 1.5), minf(1.0, farbe.g * 1.5),
            minf(1.0, farbe.b * 1.5), 1.0)
        for seite: float in SEITEN:
            var wo := p + k * r * laengs + quer * seite * r * 0.34
            # **Drei Lagen, und die Farbe liegt aussen.**
            #
            # Vorher waren es zwei: ein Hof vom 2,8fachen Radius und ein
            # gleich grosser Kern, beide in derselben aufgehellten Farbe.
            # Auf einem grossen Tier - der Kalkrochen hat sechzig Einheiten
            # Radius - sind das vierzehn blasse Scheiben von je vierzehn
            # Pixeln, und im Bild sahen sie aus wie Plastikperlen, die
            # jemand auf den Leib geklebt hat.
            #
            # Ein Photophor ist ein **winziger heller Punkt in einem
            # farbigen See**. Der Kern schrumpft deshalb auf gut die Haelfte
            # und wird das Einzige, was fast weiss ist; die beiden Hoefe
            # tragen die Farbe der Art nach aussen und laufen aus. Das ist
            # dieselbe Machart wie bei jeder anderen Leuchtstelle hier -
            # aussen die Art, innen das Licht.
            draw_circle(wo, gr * 3.2, Color(farbe.r, farbe.g, farbe.b,
                minf(1.0, a) * 0.13))
            draw_circle(wo, gr * 1.45, Color(farbe.r, farbe.g, farbe.b,
                minf(1.0, a) * 0.34))
            draw_circle(wo, gr * 0.55,
                Color(hell.r, hell.g, hell.b, minf(1.0, a)))


## Die Schleppe eines Tieres: sein Weg, verblassend.
##
## **Sie misst sich selbst.** Die Punkte werden nach Strecke aufgeschrieben,
## nicht nach Zeit - ein schnelles Tier hat damit von allein eine lange
## Schleppe und ein traeges eine kurze, ohne dass irgendwo eine Tempogrenze
## steht. Der Schleier zieht einen Faden hinter sich her, der Panzerkrebs
## einen Stummel, und beides stimmt.
##
## Nur im Rundumlauf: im Schlund sinkt alles dieselbe Bahn nach unten, und
## zwoelf Schleppen nebeneinander waeren dort ein Vorhang.
func _schleppe(t: Raeuber) -> void:
    var weg := t.rueckweg
    if weg.size() < 3:
        return
    var farbe: Color = Arten.farbe(t.art)

    # **Ein Band, keine Kette aus Scheiben.**
    #
    # Sie war je Abschnitt ein Paar `draw_line` von bis zu neun Pixeln
    # Breite - und die Punkte des Rueckwegs liegen neun Einheiten
    # auseinander. Ein Strich, der so breit ist wie er lang, ist ein Punkt:
    # im Bild eine Kette gleich grosser Perlen hinter jedem Tier, und bei
    # der Laichwolke war diese Kette das Auffaelligste am ganzen Tier.
    #
    # **Und sie wusste nichts von der Groesse ihres Tieres.** Eine
    # Laichwolke hat zwoelf Einheiten Radius und zog denselben Faden wie ein
    # Leitwesen mit sechzig. Dieselbe Regel wie beim Hof (siehe
    # `_zeichne()`): was ein Tier hinter sich herzieht, waechst mit ihm.
    #
    # Jetzt ein Dreiecksnetz aus drei Punktreihen - aussen auf Deckung null,
    # in der Mitte voll -, in **einem** Aufruf statt zweiundzwanzig
    # geglaetteten Linien. Dieselbe Machart wie Rippel, Druckwelle und
    # Schein, und gemessen billiger als das, was es ersetzt.
    var mass := clampf(Wellen.radius_in(t.art, t.welle) / 26.0, 0.30, 1.0)
    var n := weg.size()
    var ecken := PackedVector2Array()
    var farben := PackedColorArray()
    for i in n:
        var f := float(i) / float(n - 1)
        var vor: Vector2 = weg[maxi(0, i - 1)]
        var nach: Vector2 = weg[mini(n - 1, i + 1)]
        var quer := (nach - vor)
        quer = quer.orthogonal().normalized() if quer.length() > 0.001 \
            else Vector2.UP
        var breit := (1.0 + 4.4 * f * f) * mass
        var mitte := _gedeckt(Color(farbe.r, farbe.g, farbe.b,
            0.26 * f * f * mass))
        var aus := Color(farbe.r, farbe.g, farbe.b, 0.0)
        ecken.append(weg[i] - quer * breit); farben.append(aus)
        ecken.append(weg[i]); farben.append(mitte)
        ecken.append(weg[i] + quer * breit); farben.append(aus)
    var netz := PackedInt32Array()
    for i in n - 1:
        var a := i * 3
        var b := a + 3
        netz.append_array([a, b, b + 1, a, b + 1, a + 1])
        netz.append_array([a + 1, b + 1, b + 2, a + 1, b + 2, a + 2])
    RenderingServer.canvas_item_add_triangle_array(
        get_canvas_item(), netz, ecken, farben)


## Nur die Deckung, nicht die Farbe: ein Lauerer soll blasser sein, nicht
## grauer - sonst verliert er die Farbe, an der man seine Art erkennt.
func _gedeckt(farbe: Color) -> Color:
    if deckung >= 1.0:
        return farbe
    return Color(farbe.r, farbe.g, farbe.b, farbe.a * deckung)


func _draw() -> void:
    # Kein Rest vom letzten Bild: die Bluete geht durch dieselbe Datei, und
    # ein liegengebliebener Biegewert waere ein Tier, das sich erinnert.
    _biegung = 0.0
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
        if not t.lauert:
            _schleppe(t)
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


## Ein Wert zwischen 0 und 1, der zu diesem einen Tier gehoert und sich nie
## aendert. Er kommt aus `t.phase` - dem einzigen Feld, das der Wellenbau je
## Tier wuerfelt und das schon jetzt reine Zierde ist. Der Faktor macht aus
## einer Phase, die im Schlaengeln nur wenige Umlaeufe braucht, eine Zahl,
## die auch bei benachbarten Phasen weit auseinanderliegt.
func _eigenart(t: Raeuber, faktor := 3.7) -> float:
    return fmod(absf(t.phase) * faktor, 1.0)


## Wieviel die Faerbung eines einzelnen Tieres von seiner Art abweichen darf.
##
## **Klein, und mit Absicht klein.** Die Farbe sagt, welche Art da schwimmt,
## und das muss sie in einer halben Sekunde sagen koennen. Ein Achtel
## Helligkeit und ein Hauch Farbdrehung reichen, damit ein Schwarm nicht mehr
## aussieht wie derselbe Stempel zwoelfmal - mehr waere eine dreizehnte Art.
const EIGEN_HELL := 0.16
const EIGEN_DREH := 0.030


## Die Faerbung dieses einen Tieres.
func _eigenfarbe(t: Raeuber, farbe: Color) -> Color:
    var e := _eigenart(t) - 0.5
    var f := Color.from_hsv(
        fmod(farbe.h + e * EIGEN_DREH + 1.0, 1.0),
        clampf(farbe.s - e * 0.10, 0.0, 1.0),
        clampf(farbe.v + e * EIGEN_HELL, 0.10, 1.0))
    f.a = farbe.a
    return f


func _zeichne(t: Raeuber, stufe := 0) -> void:
    var p := t.ort
    # **Kein Tier sieht aus wie das andere.**
    #
    # Zwoelf Arten, und innerhalb einer Art war jedes Stueck derselbe
    # Stempel: gleiche Farbe, gleiche Zahl Zacken, gleicher Takt. Aus zehn
    # Schleiern nebeneinander wurde damit ein Muster statt eines Schwarms.
    #
    # **Gewuerfelt wird nur, was nichts kostet.** Der Radius bleibt exakt
    # `Wellen.radius_in()` - das ist der Kreis, den auch der Kegel trifft,
    # und ein Tier, das groesser gezeichnet ist als es getroffen wird, waere
    # dieselbe zweite Wahrheit wie ein Kegel, der anders aussieht als er
    # wirkt. Verschoben werden Faerbung und Zierat innerhalb des Umrisses.
    var farbe: Color = _eigenfarbe(t, Arten.farbe(t.art))
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

    # **Was schwimmt, schlaegt.**
    #
    # Der Weg jedes Tieres pendelt seit jeher seitlich um seine Bahn
    # (`Rundum.schritt()`, `seitlich = schlaengel * sin(takt * zeit +
    # phase)`) - der **Leib** aber stand still dabei. Damit war jedes Tier
    # ein Bild, das durch das Wasser geschoben wird: die Bahn erzaehlte eine
    # Bewegung, der Koerper keine.
    #
    # Das ist der Grund, warum die Sprites lange leblos wirkten, und zwar
    # unabhaengig davon, wie gut sie gezeichnet waren. Ein Fisch, der sich
    # nicht biegt, ist ein Aufkleber - und ein sehr sorgfaeltig gezeichneter
    # Aufkleber ist immer noch einer.
    #
    # **Derselbe Sinus, dieselbe Phase, dieselbe Quelle.** Das Tier weicht
    # seitlich aus, *weil* es den Leib schlaegt; zwei getrennte Rechnungen
    # dafuer waeren zwei Bewegungen, die auseinanderlaufen - genau die Art
    # Fehler, gegen die Zusage 1 geschrieben ist. `Arten.schlaengel()` und
    # `Arten.takt()` sind jetzt Zugriffe wie jeder andere, und Bahn und
    # Leib lesen beide daraus.
    #
    # **Gedreht wird um einen Punkt vor der Mitte**, nicht um die Mitte. Um
    # die Mitte gedreht wandern Nase und Schwanz gleich weit - das sieht aus
    # wie ein Zeiger. Ein Fisch haelt den Kopf fast auf Kurs und schlaegt
    # hinten aus, und der Unterschied zwischen beidem sind diese zwei
    # Zeilen.
    #
    # Der Ausschlag haengt an `schlaengel`: der Panzerkrebs (6) bewegt sich
    # kaum, das Schwarmherz (82) wirft sich herum. Ein fester Winkel fuer
    # alle haette den Gepanzerten dasselbe Schlaengeln gegeben wie dem Aal,
    # und dann sagt die Bewegung nichts mehr ueber die Art.
    var gier := SCHLAG_WINKEL \
        * clampf(Arten.schlaengel(t.art) / SCHLAG_BEZUG, 0.05, 1.0) \
        * sin(Arten.takt(t.art) * t.alter + t.phase)
    # **Und der Leib biegt sich mit.** Eine Drehung allein ist ein Wedeln;
    # was ein Tier schwimmen laesst, ist eine Welle, die von vorn nach
    # hinten durch den Koerper laeuft. `_koerper()` liest das - damit
    # bekommen es sechzehn Arten auf einmal, ohne dass eine einzelne
    # Zeichnung davon weiss.
    _biegung = SCHLAG_BIEGUNG * gier / SCHLAG_WINKEL
    var alte_richtung := t.richtung
    if absf(gier) > 0.0005:
        var achse := p + t.richtung * r * 0.55
        p = achse + (p - achse).rotated(gier)
        t.richtung = t.richtung.rotated(gier)

    # Der Hof faellt als Erstes weg - er kostet drei Kreise je Tier und traegt
    # am wenigsten, sobald das Bild voll ist.
    #
    # Die Staerken sind gedaempft, seit es Randlicht gibt. Vorher trug der Hof
    # die ganze Rueckmeldung; jetzt teilen sich beide die Aufgabe, und wenn
    # beide voll aufdrehen, wird aus dem Tier ein weisser Klecks. Genau das
    # war im ersten Bild zu sehen: eine beleuchtete Glutqualle war von einer
    # beleuchteten Schildkoralle nicht mehr zu unterscheiden.
    #
    # **Halbiert, seit die Szene eine Nachbearbeitung hat.** Die gestapelten
    # Kreise waren der Ersatz fuer ein Gluehen, das es nicht gab; jetzt gibt
    # es eins, und beides zusammen war zuviel - ein Zahnkiefer im Strahl war
    # ein weisser Klecks mit einer Flosse daran. Der Hof bleibt trotzdem: er
    # traegt die **Farbe** der Art nach aussen, und die Nachbearbeitung
    # kennt nur Helligkeit.
    #
    # **Und kleine Tiere bekommen weniger davon.** Der Hof waechst mit dem
    # Radius, die Nachbearbeitung nicht - bei einer Laichwolke von zwoelf
    # Einheiten lag der Koerper vollstaendig im eigenen Schein, und drei
    # davon im Strahl waren drei weisse Punkte. Was den Schwarm lesbar macht,
    # ist die Wiederholung derselben Form; eine Form, die man nicht sieht,
    # wiederholt sich nicht.
    # **Und der Hof waechst mit der Hitze nicht mehr mit.** Er stand auf
    # 0,07 + 0,13 mal Hitze bei zweikommazwei Radien - zusammen mit dem
    # weissen Umriss, dem Randlicht und der Nachbearbeitung ergab das den
    # weissen Klecks. Er zieht sich jetzt beim Brennen sogar leicht
    # **zusammen**: ein Brand ist ein Punkt, keine Wolke.
    # **Der Kreis-Hof ist weg.** Hier standen drei Kreise um den Mittelpunkt
    # mit dem 2,2fachen Koerperradius - ein Fleck neben der Form statt einer
    # leuchtenden Form. Was ihn ersetzt, zeichnet `_koerper()` als Schale
    # entlang des Umrisses. Nur die Sparfassung behaelt einen Kreis: bei
    # achtzig Tieren im Bild sieht niemand mehr die Form eines Hofs, wohl
    # aber, dass es ruckelt.
    var klein := clampf(r / 18.0, 0.45, 1.0)
    if stufe >= 2:
        draw_circle(p, r * 1.6, Color(farbe.r, farbe.g, farbe.b,
            (0.045 + 0.025 * hitze) * klein))

    # **Leuchtpunkte.** Eine Reihe kleiner Lichter laengs des Koerpers, die
    # als Welle von vorn nach hinten durchlaeuft.
    #
    # Das ist das Kennzeichen der Tiefsee schlechthin - fast alles, was dort
    # lebt, traegt Photophoren -, und es steht **vor** der Verzweigung, gilt
    # also fuer alle zwoelf Arten auf einmal. Zahl und Abstand kommen aus dem
    # Radius, die Phase aus `t.phase`: gleich grosse Tiere blinken deshalb
    # nicht im Gleichtakt.
    #
    # Nur in der obersten Stufe. Sie sind Zierde, und Zierde geht als Erstes,
    # wenn das Bild voll wird.
    # **Nicht jede Art traegt die Reihe.**
    #
    # `_leuchtpunkte()` setzt die Photophoren laengs der Achse auf ±0,34
    # Radien - das passt auf einen Leib mit einer Mitte. Der Kreiser ist ein
    # **offener Ring**, und dort landet die Reihe in seinem Loch: zwei helle
    # Punkte, die frei im Wasser schweben. Der Spiegler ist eine geschliffene
    # Flaeche; auf ihr sahen dieselben Punkte aus wie aufgeklebte Knoepfe,
    # und ein Spiegel leuchtet ohnehin nicht selbst - er wirft zurueck.
    #
    # Zwei Ausnahmen von Hand sind hier ehrlicher als ein Feld in der
    # Artentabelle: es sind genau die zwei Arten, deren Oberflaeche nicht
    # laengs der Achse liegt, und wer eine dritte baut, sieht es im Bild.
    if stufe == 0 and t.art != Arten.Art.KREISER \
            and t.art != Arten.Art.SPIEGLER:
        _leuchtpunkte(p, r, farbe, t, hitze)

    # Bei sehr vielen Tieren nur noch Umriss und Farbe: die Form bleibt
    # lesbar, die Zierde geht.
    if stufe >= 2:
        _knapp(p, r, farbe, t, hitze)
        t.richtung = alte_richtung
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
        Arten.Art.LAICHWOLKE:
            _laichwolke(p, r, farbe, t, hitze)
        Arten.Art.KREISER:
            _kreiser(p, r, farbe, t, hitze)
        Arten.Art.LICHTSCHEU:
            _lichtscheu(p, r, farbe, t, hitze)
        Arten.Art.RINGMAUL:
            _ringmaul(p, r, farbe, t, hitze)
        Arten.Art.BRUTSTOCK:
            _brutstock(p, r, farbe, t, hitze)
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

    # **Der Schlag ist eine Zeichenrichtung, keine Fahrtrichtung.** Er wird
    # fuer die Dauer einer Zeichnung in `t.richtung` gelegt, weil alle
    # siebzehn Artfunktionen von dort ihre Achse holen - und danach
    # zurueckgenommen. Am Weg des Tieres aendert das nichts, und am
    # Trefferkreis auch nicht: der ist ein **Kreis** um `t.ort`, und ein
    # Kreis hat keine Richtung. Genau deshalb ist der Schlag hier erlaubt
    # und eine Aenderung am Radius es nicht.
    t.richtung = alte_richtung


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


## Der **Schein um eine Form** - kein Kreis um einen Mittelpunkt.
##
## **Der Unterschied, um den es geht.** Bisher bekam jedes Tier seinen Hof
## von `_gluehen()`: drei Kreise um seinen Mittelpunkt, Radius 2,2 mal
## Koerperradius. Ein Kreis weiss nichts von der Form, die in ihm steht -
## bei einem langen Fisch leuchtete das Wasser links und rechts von ihm
## genauso hell wie an seiner Schnauze, und bei einem Ring leuchtete sein
## Loch. Das ist der Unterschied zwischen "Punktlichter an eine Form
## haengen" und "die Form leuchtet": im ersten Fall sieht man die Kreise, im
## zweiten die Form.
##
## **Wie es richtig geht.** Das Verfahren stammt aus den 2D-Lichtsystemen:
## fuer jedes Leuchtsegment wird ein Koerper aufgespannt, der die Strecke
## **plus ihren Leuchtradius** umschliesst, und die Helligkeit faellt vom
## Segment weg ab - nicht von einem Mittelpunkt. Gezeichnet wird nur diese
## Flaeche, nicht der halbe Schirm; deshalb ist es billig.
##
## Hier ist die "Strecke" der geschlossene Umriss des Tieres. Der Schein ist
## damit eine **Schale**, die den Umriss nach aussen fortsetzt: an der Kante
## voll, am aeusseren Rand auf null. Ein Aal leuchtet dadurch laenglich, ein
## Ring leuchtet als Ring, und keiner leuchtet in sein eigenes Loch.
##
## Die Aussennormale kommt aus den **beiden Nachbarkanten** und nicht aus der
## Richtung zum Schwerpunkt: bei einer Einbuchtung zeigt die Schwerpunkt-
## richtung nach innen, und die Schale stuelpt sich dort um.
func _schein(rund: PackedVector2Array, farbe: Color, weite: float,
        staerke: float) -> void:
    var n := rund.size()
    if n < 3 or staerke <= 0.004 or weite <= 0.5:
        return
    var innen := _gedeckt(Color(farbe.r, farbe.g, farbe.b, staerke))
    var aussen := Color(farbe.r, farbe.g, farbe.b, 0.0)
    var ecken := PackedVector2Array()
    var farben := PackedColorArray()
    for i in n:
        var vor: Vector2 = rund[(i - 1 + n) % n]
        var hier: Vector2 = rund[i]
        var nach: Vector2 = rund[(i + 1) % n]
        var norm := ((hier - vor).orthogonal().normalized()
            + (nach - hier).orthogonal().normalized())
        norm = norm.normalized() if norm.length_squared() > 0.001 \
            else (nach - vor).orthogonal().normalized()
        ecken.append(hier)
        farben.append(innen)
        ecken.append(hier + norm * weite)
        farben.append(aussen)
    var netz := PackedInt32Array()
    for i in n:
        var a := i * 2
        var b := ((i + 1) % n) * 2
        netz.append_array([a, b, b + 1, a, b + 1, a + 1])
    RenderingServer.canvas_item_add_triangle_array(
        get_canvas_item(), netz, ecken, farben)


## Leib: gedaempfte Fuellung, heller Umriss. Bei additivem Zeichnen macht der
## Umriss die Form, nicht die Flaeche - eine hell gefuellte Flaeche waere ein
## Klecks ohne Kontur.
## Ein Linienzug mit **Farbe je Punkt** - sonst wie `_zug`.
##
## Er wird gebraucht, wo eine Kante ueber ihre Laenge heller und dunkler
## wird: eine Lichtseite an einem Leib. `draw_polyline` kann das nicht, und
## den Zug in Stuecke zu zerlegen ginge auch nicht - jedes Stueck bekaeme
## an seinen Enden eine runde Kappe, und aus einem Umriss wuerde eine
## Perlenkette. Dieselbe Falle steckt im Rumpf des Bootes.
func _zug_farben(punkte: PackedVector2Array, farben: PackedColorArray,
        dicke: float) -> void:
    if punkte.size() < 2 or farben.size() != punkte.size():
        return
    var hof := PackedColorArray()
    for c in farben:
        hof.append(Color(c.r, c.g, c.b, _gedeckt(c).a * 0.30))
    var kern := PackedColorArray()
    for c in farben:
        kern.append(_gedeckt(c))
    draw_polyline_colors(punkte, hof,
        minf(dicke * 3.4, HOF_HOECHSTENS), true)
    draw_polyline_colors(punkte, kern, dicke, true)


## Ein **Gliedmass**: verjuengt, mit Gelenk und Lichtkante.
##
## **Warum es das gibt.** Beine, Fangarme und Scheren waren `draw_line` mit
## fester Breite - ein Zickzack aus Haarlinien, gleich dick von der Wurzel
## bis zur Spitze und auf beiden Seiten gleich hell. Beim Panzerkrebs sah
## das aus wie eine Kinderzeichnung von einer Spinne, und der Fehler ist
## nicht der Umriss des Tieres, sondern die **Strichqualitaet**.
##
## Drei Dinge machen aus einem Strich ein Glied, und alle drei kosten fast
## nichts:
##
## * **Verjuengung.** Ein Bein ist an der Wurzel dick und an der Spitze
##   duenn. Das heisst: eine Flaeche, kein Strich.
## * **Eine Lichtkante.** Eine Seite ist hell, die andere nicht - erst
##   dadurch ist es ein Koerper und nicht ein Band.
## * **Ein Gelenk.** Wo zwei Glieder aneinanderstossen, sitzt ein Knoten;
##   ohne ihn knickt eine Linie, statt dass ein Bein sich beugt.
func _glied(von: Vector2, nach: Vector2, dick_von: float, dick_nach: float,
        farbe: Color, deckung: float) -> void:
    var achse := nach - von
    if achse.length_squared() < 0.01:
        return
    var quer := achse.orthogonal().normalized()
    var haut := PackedVector2Array([
        von + quer * dick_von, nach + quer * dick_nach,
        nach - quer * dick_nach, von - quer * dick_von])
    _fuellung(haut, Color(farbe.r, farbe.g, farbe.b, deckung * 1.5))
    # **Die Lichtkante ist schmal und liegt auf einer Seite.** Der erste
    # Anlauf gab ihr die anderthalbfache Deckung als Breite und dreissig
    # Prozent Weiss - im Bild wurde daraus ein weisses Band, und die
    # Verjuengung, um die es ging, verschwand darunter. Eine Kante, die
    # breiter ist als das Glied dick, beschreibt nichts mehr.
    # **Auch die Lichtkante haelt sich an `deckung`.** Sie tat es nicht, und
    # damit leuchtete ein Fangarm, der blass sein sollte, heller als der
    # Leib, an dem er haengt - im Bild vier grelle Striche an einer dunklen
    # Qualle. Eine Zierde, die heller strahlt als der Koerper, kehrt die
    # Rangfolge um.
    var kante := _gedeckt(farbe.lerp(Color(1.0, 0.98, 0.94), 0.16))
    draw_line(von + quer * dick_von, nach + quer * dick_nach,
        Color(kante.r, kante.g, kante.b, kante.a * minf(1.0, deckung * 1.3)),
        1.0, true)
    draw_line(von - quer * dick_von, nach - quer * dick_nach,
        Color(farbe.r, farbe.g, farbe.b, deckung * 0.40), 0.8, true)
    draw_circle(von, dick_von * 0.9,
        Color(farbe.r, farbe.g, farbe.b, deckung * 0.55))


## Ein **Fangarm**: mehrgliedrig, verjuengt, nachschwingend.
##
## Fangarme und Faeden waren ueberall `draw_line` von der Wurzel zu einem
## Punkt - eine gerade Linie mit fester Breite. Sie schwang zwar, aber als
## **Ganzes**: das Ende ging mit, die Mitte nicht. So bewegt sich kein Arm
## im Wasser; eine Welle laeuft von der Wurzel zur Spitze und wird dabei
## groesser, weil das duenne Ende der Traegheit weniger entgegensetzt.
##
## Drei Glieder reichen dafuer. Jedes ist verjuengt (`_glied`), und die
## Auslenkung waechst mit dem Quadrat der Laenge - das ist die Form, die
## eine schwingende Rute wirklich annimmt.
func _fangarm(wurzel: Vector2, richtung: Vector2, laenge: float,
        dick: float, wehen: float, farbe: Color, deckung: float) -> void:
    # **Vier Glieder statt drei, und die Spitze rollt sich ein.** Mit drei
    # geraden Stuecken und quadratisch wachsender Auslenkung blieb ein Arm
    # im Bild fast gerade - er stand steif nach hinten wie ein Draht. Ein
    # Fangarm im Wasser wird zur Spitze hin nicht nur weiter ausgelenkt, er
    # **kruemmt** sich staerker.
    var quer := richtung.orthogonal()
    var wo := wurzel
    for i in 4:
        var u0 := float(i) / 4.0
        var u1 := float(i + 1) / 4.0
        var ziel := wurzel + richtung * laenge * u1 \
            + quer * wehen * u1 * u1 * (0.6 + 0.9 * u1)
        _glied(wo, ziel, dick * (1.0 - 0.76 * u0), dick * (1.0 - 0.76 * u1),
            farbe, deckung * (1.0 - 0.34 * u0))
        wo = ziel


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
## Wieviel Eckenschneiden ein Leib bekommt.
##
## **Zwei Durchgaenge machen aus jedem Vieleck einen Kreis** - und damit aus
## der Schildkoralle, die eigens als eckiger Schild gebaut wurde, wieder ein
## Oval. Die Arbeit, ihr eine Kante zu geben, war umsonst, weil sie hier
## anschliessend weggeglaettet wurde.
##
## `weich` sagt jetzt, wieviel: zwei fuer alles Weiche (Quallen, Fische,
## Wolken), einen fuer die Gepanzerten, null fuer den, dessen ganze Aussage
## eine gerade Kante ist.
## Den Leib durchbiegen, so wie ein Fisch sich beim Schlagen biegt.
##
## **Warum das hier steht und nicht in siebzehn Zeichnungen.** Jede Art baut
## ihren Umriss aus `t.richtung` und deren Senkrechten; wer die Biegung dort
## einbaut, baut sie siebzehnmal ein und vergisst sie beim achtzehnten Tier.
## `_koerper()` bekommt den fertigen Umriss - eine Stelle, alle Arten, und
## eine neue Art hat die Bewegung, ohne dass jemand daran denkt.
##
## **Die Welle laeuft nach hinten aus, sie beginnt nicht dort.** Der Ausschlag
## ist an der Nase null und waechst zum Schwanz - quadratisch, damit das
## vordere Drittel praktisch stillsteht. Ein Leib, der sich ueber die ganze
## Laenge gleich weit biegt, ist eine Banane und kein Fisch.
##
## Der Trefferkreis bleibt unberuehrt: der Schwanz wandert auf einem Bogen um
## hoechstens ein Fuenftel der Koerperlaenge, der Kreis um `t.ort` bleibt
## derselbe. Dasselbe Zugestaendnis wie beim Zittern nach einem Treffer, und
## aus demselben Grund erlaubt - der Radius selbst wird nicht angefasst.
func _gebogen(rund: PackedVector2Array,
        achse: Vector2) -> PackedVector2Array:
    if absf(_biegung) < 0.002 or rund.size() < 4:
        return rund
    var mitte := _mitte(rund)
    var a := achse if achse != Vector2.ZERO else _laengsachse(rund, mitte)
    if a == Vector2.ZERO:
        return rund
    var quer := a.orthogonal()
    var laenge := 0.0
    for v in rund:
        laenge = maxf(laenge, absf((v - mitte).dot(a)))
    if laenge < 1.0:
        return rund
    var neu := PackedVector2Array()
    for v in rund:
        var u := clampf((v - mitte).dot(a) / laenge, -1.0, 1.0)
        var f: float = pow(clampf(0.5 - 0.5 * u, 0.0, 1.0), 1.7)
        neu.append(v + quer * (_biegung * laenge * f))
    return neu


func _koerper(punkte: PackedVector2Array, farbe: Color, hitze: float,
        achse := Vector2.ZERO, weich := 2) -> void:
    var rund := punkte
    for _i in weich:
        rund = _rund(rund)
    rund = _gebogen(rund, achse)

    # **Der Schein zuerst**, damit der Leib darauf liegt. Er folgt dem
    # Umriss und nicht einem Kreis - siehe `_schein()`.
    _schein(rund, farbe, 8.0 + 16.0 * hitze, 0.10 + 0.12 * hitze)
    var mitte := _mitte(rund)

    # **Was brennt, wird dunkel in der Mitte und hell am Rand.**
    #
    # Vorher wurde alles zugleich heller: Fuellung, Umriss, Hof, Randlicht -
    # und darueber liegt noch die Nachbearbeitung. Ein getroffenes Tier war
    # damit eine **weisse Scheibe**, und zwar genau in dem Augenblick, in dem
    # man hinsieht: beim Zielen. Man verliert die Art aus dem Blick, sobald
    # man sie trifft, und das ist die schlechteste denkbare Stelle dafuer.
    #
    # Ein durchleuchteter Koerper sieht anders aus. Das Licht kommt von
    # aussen, der Leib steht davor - er wird zur Silhouette, und was
    # aufleuchtet, ist seine **Kante**. Die Fuellung geht deshalb mit der
    # Hitze zurueck statt hoch; die Form bleibt lesbar, weil sie sich vom
    # eigenen Schein abhebt.
    #
    # **Und sie ist ein Verlauf, keine drei gestapelten Fassungen.**
    #
    # Hier lagen drei zum Schwerpunkt geschrumpfte Kopien uebereinander. Zwei
    # Dinge stimmten daran nicht. Erstens sah man sie nicht: `_fuellung()`
    # daempft die Farbe auf 22 Prozent und die Deckung auf 45, und drei mal
    # zehn Prozent davon sind zusammen ein Achtel Deckung - der Leib war
    # praktisch nur sein Umriss, und auf einem kleinen Tier heisst das
    # **Donut**. Zweitens schrumpft eine Kopie eines unrunden Umrisses in
    # sich selbst hinein, sobald er eine Kerbe hat; Godot meldete dazu
    # tausend Mal je Lauf `triangulation failed`.
    #
    # Ein Verlauf ueber die Eckpunkte kann beides nicht: er zeichnet genau
    # eine Flaeche, und er braucht dafuer keinen zweiten Umriss. Hell liegt
    # er dort, wo das Tier hinschaut - ein Koerper, der sich bewegt, ist
    # vorn dichter als hinten.
    #
    # **Der Verlauf laeuft zum Licht, nicht nach vorn.** Solange additiv
    # gezeichnet wurde, war die Fuellung ein Hauch und ihre Richtung
    # gleichgueltig; jetzt ist sie die Flaeche des Tieres, und eine Flaeche
    # unter Licht ist dort hell, wo sie sich dem Licht zuwendet. Das ist
    # dieselbe Rechnung wie beim Fels und beim Rumpf des Bootes - eine
    # Beleuchtung, drei Stellen.
    var kern := 1.0 - 0.30 * hitze
    var zum_licht := lichtquelle - mitte
    zum_licht = zum_licht.normalized() if zum_licht.length_squared() > 1.0 \
        else Vector2.UP
    var toene := PackedColorArray()
    for v in rund:
        var zu := maxf(0.0, (v - mitte).normalized().dot(zum_licht))
        # Quadriert: Licht faellt steil ab, sobald eine Flaeche sich
        # wegdreht. Linear sieht es aus wie ein Farbverlauf.
        var st := 0.30 + 0.70 * zu * zu
        # **Die Schattenseite kippt ins Blaue, nicht ins Graue.** Was im
        # Wasser im Schatten liegt, wird nicht nur dunkler - es verliert
        # zuerst das lange Ende des Spektrums. Ein bloss abgedunkeltes Rot
        # sieht aus wie schmutziges Rot; ein ins Blau gezogenes sieht aus
        # wie Rot unter Wasser.
        var tief := Color(farbe.r, farbe.g, farbe.b).lerp(
            Color(0.14, 0.34, 0.48), 0.55 * (1.0 - zu))
        # **Kein Leib wird schwarz.** Der erste Anlauf multiplizierte die
        # Farbe mit `st`, und `st` faellt auf 0,30 - zusammen mit der
        # Daempfung war die Schattenseite einer dunklen Art nicht mehr von
        # Wasser zu unterscheiden. Im Bild war die Glutqualle innen ein Loch
        # mit einem Rand darum. Ein Sockel von einem Viertel haelt die
        # Flaeche lesbar, auch wo kein Licht hinfaellt: Tiefseewasser ist
        # nicht schwarz, sondern sehr dunkles Blau, und ein Koerper davor
        # ist es auch.
        var hell := 0.25 + 0.75 * st
        toene.append(Color(tief.r * hell, tief.g * hell, tief.b * hell,
            (0.86 + 0.12 * zu) * kern))
    draw_polygon(rund, toene)

    # **Der Umriss hat eine Lichtseite.**
    #
    # Er lief rundum mit derselben Deckung, und damit war jedes Tier ein
    # gleichmaessig heller Neonring - eine Roehre, kein Koerper. Volumen
    # entsteht erst, wenn eine Seite heller ist als die andere, und welche
    # Seite das ist, sagt `lichtquelle`: der Ort des Bootes, derselbe, den
    # auch der Meeresgrund fuer seine Felsen bekommt.
    #
    # Gerechnet je Eckpunkt aus der **Aussennormalen** und nicht als Bogen.
    # Genau das war der Fehler des alten `_randlicht()`: es zog einen
    # Kreisbogen bei 1,04 Radien um den Mittelpunkt, und auf einem langen
    # Fisch schwebte der neben dem Tier statt auf seiner Kante.
    var seite := PackedFloat32Array()
    for v in rund:
        var aussen := (v - mitte).normalized()
        seite.append(0.34 + 0.66 * maxf(0.0, aussen.dot(zum_licht)))

    # **Eine Kontur, kein Doppelhof.**
    #
    # Hier lagen zwei Zuege uebereinander, und `_zug_farben()` legt unter
    # jeden einen Hof von bis zu sechs Pixeln - zusammen also zwei weiche
    # Baender auf derselben Kante. Auf einem gefuellten Leib ist das kein
    # Umriss mehr, sondern ein Nebel darum.
    #
    # Seit der Leib eine Flaeche ist, braucht die Kante auch keinen Hof, um
    # gesehen zu werden: sie steht zwischen hell und dunkel. Was bleibt, ist
    # **ein** weiches Band nach aussen und ein schmaler harter Kern darauf.
    var geschlossen := rund + PackedVector2Array([rund[0]])
    var hof := PackedColorArray()
    for i in geschlossen.size():
        var f: float = seite[i % seite.size()]
        hof.append(_gedeckt(Color(farbe.r, farbe.g, farbe.b,
            (0.20 + 0.26 * hitze) * f)))
    draw_polyline_colors(geschlossen, hof, 4.2, true)
    # **Der Umriss traegt die Farbe der Art, nicht Weiss.**
    #
    # Er stand im Ruhezustand schon auf 45 % Weiss, und darueber liegt die
    # Nachbearbeitung: aus einer fast weissen Linie von 1,3 Pixeln wird ein
    # weisser Ring, und die Art dahinter ist verschwunden. Zwoelf Arten mit
    # zwoelf Farben sahen aus wie zwoelfmal dasselbe Leuchten.
    #
    # Vierzehn Prozent reichen fuer den hellen Kern der Leuchtroehre. Weiss
    # wird sie erst beim Brennen - dann ist es kein Verlust, sondern die
    # Ansage.
    var kante := farbe.lerp(Color(1.0, 0.98, 0.94), 0.22 + 0.58 * hitze)
    var kern_farben := PackedColorArray()
    for i in geschlossen.size():
        var f: float = seite[i % seite.size()]
        kern_farben.append(_gedeckt(Color(kante.r, kante.g, kante.b,
            0.30 + 0.70 * f)))
    draw_polyline_colors(geschlossen, kern_farben, 1.5 + 0.7 * hitze, true)

    _inneres(rund, mitte, achse, farbe, hitze)


## Wieviele Faecher das Breitenprofil eines Umrisses hat.
const PROFIL_FAECHER := 8

## Wieviele Querrippen ein Leib bekommt.
const RIPPEN := 3

## Ab welchem halben Laengsmass ueberhaupt etwas Inneres gezeichnet wird.
##
## **Neun war zu wenig.** Ein Zahnkiefer hat siebzehn Einheiten Radius; drei
## Rippen und eine Mittellinie darin liegen zwei Pixel auseinander, und im
## Bild war das keine Anatomie, sondern Kreuzschraffur - ausgerechnet auf den
## kleinen Arten, von denen die meisten gleichzeitig im Bild stehen.
##
## Achtzehn laesst das Innere dort, wo es etwas zeigt: auf den grossen
## Leibern ab Schildkoralle aufwaerts. Was kleiner ist, traegt seine Form im
## Umriss - und das ist keine Sparmassnahme, sondern dieselbe Regel wie
## ueberall: was man nicht aufloesen kann, ist kein Detail, sondern Rauschen.
const INNEN_AB := 18.0


## Das Innere eines Leibes: eine Mittellinie und ein paar Querrippen.
##
## **Warum ueberhaupt.** Der Leib war ein heller Ring um ein schwarzes Loch.
## Das ist die Folge zweier richtiger Entscheidungen, die zusammen zuviel
## waren: die Fuellung ist bewusst fast weg (eine helle Flaeche wird von der
## Nachbearbeitung milchig statt zur Roehre), und beim Brennen geht sie noch
## weiter zurueck, damit die Kante die Form traegt. Uebrig blieb ein Umriss -
## eine Drahtfigur, kein Tier.
##
## **Warum es keine Fuellung ist.** Die Loesung ist nicht, das Loch mit Farbe
## zuzustreichen; damit waere die ganze Leuchtroehren-Sprache hin. Ein
## Tiefseetier ist innen auch nicht flaechig - man sieht Darm, Kiemenbogen,
## Segmente. Also besteht das Innere aus **denselben duennen Linien** wie
## alles andere hier, und die Nachbearbeitung macht auch aus ihnen Roehren.
##
## **Warum es beim Brennen heller wird.** Das dreht die alte Rueckmeldung um,
## ohne sie zu verlieren: aussen bleibt die Kante die Ansage, innen kommt
## etwas dazu. Ein getroffenes Tier zeigt sein Inneres, statt es zu verlieren.
##
## Die Rippen werden nicht geschnitten, sondern aus einem **Breitenprofil**
## des Umrisses gelesen: ein Durchgang ueber die Ecken, acht Faecher laengs
## der Achse, je Fach die groesste Auslenkung zur Seite. Ein Schnitt von vier
## Rippen gegen achtundzwanzig Kanten waere hundertzwoelf Streckentests je
## Tier; das hier ist einer.
func _inneres(rund: PackedVector2Array, mitte: Vector2, achse: Vector2,
        farbe: Color, hitze: float) -> void:
    if rund.size() < 6:
        return
    if achse == Vector2.ZERO:
        achse = _laengsachse(rund, mitte)
    var quer := achse.orthogonal()

    var laenge := 0.0
    for v in rund:
        laenge = maxf(laenge, absf((v - mitte).dot(achse)))
    if laenge < INNEN_AB:
        return

    var profil := PackedFloat32Array()
    profil.resize(PROFIL_FAECHER)
    for v in rund:
        var d := v - mitte
        var u := clampf((d.dot(achse) / laenge) * 0.5 + 0.5, 0.0, 0.999)
        var i := int(u * PROFIL_FAECHER)
        profil[i] = maxf(profil[i], absf(d.dot(quer)))
    # Ein leeres Fach nimmt seinen Nachbarn. Bei einer spitzen Nase trifft
    # keine Ecke das aeusserste Fach, und eine Rippe der Breite null ist ein
    # Loch in der Reihe.
    for i in PROFIL_FAECHER:
        if profil[i] <= 0.0:
            profil[i] = profil[maxi(0, i - 1)]
    for i in range(PROFIL_FAECHER - 2, -1, -1):
        if profil[i] <= 0.0:
            profil[i] = profil[i + 1]

    # **Eine Fuge ist ein Schatten, keine Linie.**
    #
    # Solange additiv gezeichnet wurde, konnte das Innere nur hell sein - es
    # gab kein Dunkel. Auf den gefuellten Leibern sehen dieselben hellen
    # Striche aus wie **Kratzer**: vier Linien quer ueber einen Rochen, die
    # nichts beschreiben.
    #
    # Wie eine Fuge in einem Material wirklich aussieht: eine dunkle Rille,
    # und daneben - auf der dem Licht zugewandten Seite - eine schmale helle
    # Lippe, wo die Kante das Licht fasst. Zwei Zuege statt einem, und aus
    # dem Kratzer wird eine Naht.
    var haut := farbe.lerp(Color(1.0, 0.98, 0.94), 0.10 + 0.30 * hitze)
    var deck := 0.30 + 0.42 * hitze
    var rille := Color(0.04, 0.09, 0.14, 0.44 + 0.14 * hitze)
    var lippe := Vector2.ZERO
    var licht_hin := lichtquelle - mitte
    if licht_hin.length_squared() > 1.0:
        lippe = licht_hin.normalized() * 1.5

    # **Die Mittellinie nur bei laenglichen Leibern.** Auf einem runden Leib
    # kreuzt sie jede Rippe in deren Mitte, und aus Rippen mit einer Nabe
    # wird ein Rad. Ein Darm laeuft ohnehin nur dort, wo es eine Laengsachse
    # gibt, die diesen Namen verdient.
    var breiteste := 0.0
    for w: float in profil:
        breiteste = maxf(breiteste, w)
    if laenge > breiteste * 1.25:
        var mittelweg := PackedVector2Array()
        for i in 7:
            var u := lerpf(-0.74, 0.74, float(i) / 6.0)
            mittelweg.append(mitte + achse * (u * laenge))
        _rille(mittelweg, rille,
            Color(haut.r, haut.g, haut.b, deck * 0.55), lippe)

    # Die Rippen sind leicht zur Nase gewoelbt. Ein gerader Strich quer durch
    # den Leib liest sich als Balken, ein gebogener als Schnitt durch einen
    # Koerper.
    #
    # **Und sie werden nach aussen kuerzer und blasser.** Der erste Anlauf gab
    # allen dieselbe Laenge und dieselbe Deckung, bis an den Umriss heran -
    # damit war jede Rippe eine Sprosse, und der Leib ein Drahtkorb. Eine
    # Rippe, die den Umriss beruehrt, schliesst eine Masche; eine, die vorher
    # aufhoert, liegt **in** einem Koerper. Die mittlere ist die staerkste:
    # was innen am hellsten ist, liest sich als Organ und nicht als Gitter.
    for i in RIPPEN:
        var u := lerpf(-0.46, 0.44, float(i) / float(RIPPEN - 1))
        var aussen := absf(u) / 0.46
        var fach := clampi(int((u * 0.5 + 0.5) * PROFIL_FAECHER),
            0, PROFIL_FAECHER - 1)
        var breit: float = profil[fach] * (0.78 - 0.30 * aussen)
        if breit < 2.0:
            continue
        var ort := mitte + achse * (u * laenge)
        var rippe := PackedVector2Array()
        for j in 5:
            var s := lerpf(-1.0, 1.0, float(j) / 4.0)
            rippe.append(ort + quer * (s * breit)
                + achse * ((1.0 - s * s) * breit * 0.26))
        _rille(rippe, rille, Color(haut.r, haut.g, haut.b,
            deck * (1.0 - 0.42 * aussen)), lippe)


## Eine **Fuge**: dunkle Rille, helle Lippe auf der Lichtseite.
func _rille(weg: PackedVector2Array, dunkel: Color, hell: Color,
        lippe: Vector2) -> void:
    if weg.size() < 2:
        return
    draw_polyline(weg, _gedeckt(dunkel), 2.2, true)
    if lippe == Vector2.ZERO:
        return
    var oben := PackedVector2Array()
    for v in weg:
        oben.append(v + lippe)
    draw_polyline(oben, _gedeckt(hell), 1.0, true)


## Die Laengsachse eines Umrisses: die Richtung zur weitesten Ecke.
##
## Fuer die Leiber hier reicht das - sie sind aus Richtung und Querachse des
## Tieres gebaut, also laenglich, und die weiteste Ecke ist die Nase oder das
## Schwanzende. Welches von beiden, ist gleichgueltig: das Innere ist
## spiegelbar.
func _laengsachse(rund: PackedVector2Array, mitte: Vector2) -> Vector2:
    var weit := 0.0
    var achse := Vector2.RIGHT
    for v in rund:
        var d := v - mitte
        var l := d.length_squared()
        if l > weit:
            weit = l
            achse = d
    return achse.normalized() if achse.length() > 0.001 else Vector2.RIGHT


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
##
## **Der Hof traegt die Farbe der Art.** Er stand fest auf einem Graublau,
## und auf einem rosa oder gelben Leib war das ein grauer Fleck - im Bild
## eine Perle, kein Auge. Der Kern bleibt warmweiss: was leuchtet, leuchtet
## ueberall gleich, und was es umgibt, gehoert dem Tier.
func _auge(p: Vector2, r: float, hitze: float,
        farbe := Color(0.30, 0.52, 0.60)) -> void:
    draw_circle(p, r * 2.4, Color(farbe.r, farbe.g, farbe.b, 0.16))
    draw_circle(p, r * 1.5, Color(farbe.r, farbe.g, farbe.b, 0.30))
    draw_circle(p, r, Color(1.0, 0.94, 0.78, 0.75 + 0.25 * hitze))


## Der Zahnkiefer: **Kopf, Maul, Angel** - in dieser Reihenfolge.
##
## Der Entwurf davor hatte alles, was ein Fisch hat: Schwanzflosse mit
## Einbuchtung, Ruempfumriss, Rueckenkamm aus fuenf Zacken, Kiefer mit vier
## Zaehnen, zwei Augen, Angel. Auf siebzehn Einheiten Radius ist das
## zusammen ein Klecks mit einem Dorn - im Bild sah man eine helle Ellipse,
## einen Stachel und einen Punkt daneben, sonst nichts.
##
## **Was auf dieser Groesse traegt, sind drei Formen, nicht neun.** Die
## Regel dahinter ist nicht speziell: eine lesbare Figur hat eine grosse
## Form, ein bis zwei mittlere und einen hellen Punkt. Alles darueber ist
## Rauschen, sobald die Form kleiner ist als das Auge auffloesen kann.
##
## Hier heisst das:
##
## **Gross:** der Kopf. Er nimmt zwei Drittel des Tieres ein und laeuft nach
## hinten in einen duennen Schwanz aus - das ist die Silhouette eines
## Tiefsee-Anglers, und sie ist auch als schwarzer Umriss noch eindeutig.
## Vorher war der Rumpf gleichmaessig hoch und der Schwanz ein gegabelter
## Dorn von 1,75 Radien; die Gabel las sich als Stachel und nicht als Flosse.
##
## **Mittel:** das Maul. Es ist ein *Keil, der in die Silhouette hineinbeisst*
## und nicht eine Linie darauf - eine offene Kerbe im Umriss sieht man auf
## zwanzig Pixeln, zwei duenne Striche mit vier Zaehnchen nicht. Drei Zaehne
## reichen, und sie sind dreieckige Flaechen, keine Striche.
##
## **Hell:** die Angel. Ein einziger heller Punkt vor dem Kopf, an einem
## duennen Bogen. Er ist der Ort, an dem das Auge landet, und er sagt
## zugleich, wohin das Tier schaut.
func _zahnkiefer(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var schlag := sin(t.alter * 5.0 + t.phase)
    # Das Maul oeffnet und schliesst sich. Ein Angler mit stehendem Maul ist
    # ein Ornament; einer, der zubeisst, ist eine Drohung.
    var beiss := 0.5 + 0.5 * sin(t.alter * 2.3 + t.phase * 3.0)

    # **Lang und schmal, nicht rund.**
    #
    # Drei Anlaeufe sind hier gescheitert, und der Fehler war jedes Mal
    # derselbe - ich habe an der Zierde gearbeitet statt am Umriss. Der
    # letzte Leib war 1,62 Radien lang und 1,68 breit: **rund**. Der Umriss
    # eines runden Dings ist ein Ring, und ein Ring ist kein Tier, egal wie
    # viele Zaehne und Angeln man daran haengt.
    #
    # Die Schleierqualle nebenan las sich vom ersten Versuch an, und der
    # Grund ist nur ihr Seitenverhaeltnis: sie ist eine Sichel, also breiter
    # als hoch, mit einer Aushoehlung. Ein Umriss, dessen Laenge und Breite
    # sich um mehr als das Doppelte unterscheiden, hat eine Richtung - und
    # eine Richtung ist das, was man auf zwanzig Pixeln noch erkennt.
    #
    # Also: dreieinhalb Radien lang, einen breit. Kopf vorn mit dem Maul,
    # Rumpf schmal, Schwanzstiel duenn, Flosse hinten. Das ist ein
    # Drachenfisch und keine Kugel mit Anhaengen.
    var wedel := sin(t.alter * 5.0 + t.phase)

    var stiel := p - k * r * 1.10
    var fahnenende := p - k * r * 1.90 + quer * r * 0.34 * wedel
    # **Ein Lappen, keine Gabel.** Der Anlauf davor hatte zwischen den beiden
    # Flossenspitzen eine Einbuchtung - anatomisch richtig, im Bild aber ein
    # spitzer Winkel, und ein spitzer Winkel mit hellem Rand auf einem Tier
    # von fuenfunddreissig Pixeln liest sich als **Papierdrachen**. Eine
    # gerundete Fahne sagt "Flosse" auf dieser Groesse besser als eine
    # korrekte Gabel.
    var flosse := PackedVector2Array()
    for i in 7:
        var u := lerpf(-1.0, 1.0, float(i) / 6.0)
        flosse.append(fahnenende + quer * r * 0.46 * u
            + k * r * 0.22 * (1.0 - u * u))
    flosse.append(stiel)
    _fuellung(flosse, Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.20 * hitze))
    _zug(flosse + PackedVector2Array([flosse[0]]),
        Color(farbe.r, farbe.g, farbe.b, 0.20 + 0.24 * hitze), 1.0)

    var leib := PackedVector2Array([
        p + k * r * 1.42,
        p + k * r * 1.00 + quer * r * 0.44,
        p + k * r * 0.30 + quer * r * 0.54,
        p - k * r * 0.40 + quer * r * 0.34,
        p - k * r * 1.06 + quer * r * 0.13,
        p - k * r * 1.16,
        p - k * r * 1.06 - quer * r * 0.13,
        p - k * r * 0.40 - quer * r * 0.34,
        p + k * r * 0.30 - quer * r * 0.54,
        p + k * r * 1.00 - quer * r * 0.44,
    ])
    _koerper(leib, farbe, hitze, t.richtung)

    # **Der Rueckensaum ist weg.** Er stand als offener Linienzug ueber dem
    # Rumpf und sollte "Flosse" sagen; auf fuenfunddreissig Pixeln sagte er
    # "Strich neben dem Tier". Wer auf dieser Groesse zaehlt, wieviele Teile
    # ein Sprite hat, kommt schnell auf zu viele: Leib, Flosse, Saum, Maul,
    # Zaehne, Auge, Angel waren sieben. Vier davon sind sichtbar.

    # **Das Maul liegt auf dem Leib und schneidet ihn nicht.** Additiv
    # gezeichnet gibt es kein Dunkel; eine Kerbe im Umriss hat den Leib beim
    # Fuellen mit sich selbst schneiden lassen. Zwei kraeftige helle Zuege
    # vom Gelenk zur Schnauze sagen dasselbe - das Auge liest die Flaeche
    # dazwischen als offenes Maul.
    var gelenk := p + k * r * 0.62
    var weit := 0.30 + 0.26 * beiss
    var hell := farbe.lerp(Color(1.0, 0.98, 0.94), 0.34 + 0.46 * hitze)
    for seite: float in SEITEN:
        var ecke := p + k * r * 1.40 + quer * r * weit * seite
        _zug(PackedVector2Array([gelenk, ecke]), hell, 1.7)
        for i in 3:
            var u := lerpf(0.30, 0.88, float(i) / 2.0)
            var wo := gelenk.lerp(ecke, u)
            var tief: float = r * (0.20 - 0.05 * float(i)) * seite
            draw_colored_polygon(PackedVector2Array([
                wo - k * r * 0.09, wo + k * r * 0.09, wo - quer * tief]),
                Color(0.96, 1.0, 1.0, 0.60 + 0.30 * hitze))

    # Ein Auge, nicht zwei. Von oben sieht man ohnehin nur eines, und zwei
    # helle Punkte nebeneinander auf einem zwanzig Pixel grossen Kopf sind
    # ein Gesicht aus einem Comic.
    _auge(p + k * r * 0.48 + quer * r * 0.26, r * 0.17, hitze, farbe)

    # **Die Angel.** Von der Stirn nach vorn ueber das Maul gebogen, mit dem
    # hellsten Punkt des ganzen Tieres am Ende.
    var wurzel := p + k * r * 0.30 + quer * r * 0.40
    var mitte := p + k * r * 1.30 + quer * r * (0.80 + 0.10 * schlag)
    var spitze := p + k * r * 1.86 + quer * r * (0.20 + 0.16 * schlag)
    var bogen := PackedVector2Array()
    for i in 7:
        var u := float(i) / 6.0
        bogen.append(wurzel.lerp(mitte, u).lerp(mitte.lerp(spitze, u), u))
    _zug(bogen, Color(farbe.r, farbe.g, farbe.b, 0.34 + 0.22 * hitze), 1.0)
    draw_circle(spitze, r * 0.34, Color(farbe.r, farbe.g, farbe.b, 0.16))
    draw_circle(spitze, r * 0.17,
        Color(0.94, 1.0, 0.98, 0.75 + 0.25 * hitze))


## Der Schleier: eine **Glocke mit gebogenem Saum**, die pumpt.
##
## Sie war ein halber Kreis aus neun Punkten mit einem Strich hinten quer
## darueber - im Bild ein Halbmond, und weil sie mit sechshundert Auftritten
## die zweithaeufigste Art ist, war dieser Halbmond ein grosser Teil des
## ganzen Spiels.
##
## Drei Dinge machen daraus eine Qualle, und alle drei sind Silhouette und
## nicht Zierat:
##
## **Der Saum ist gewellt.** Der Rand einer Glocke ist nie glatt; er hat
## Lappen. Vier davon reichen - man sieht sie noch bei zwanzig Pixeln, weil
## sie den *Umriss* aendern und nicht die Fuellung.
##
## **Sie pumpt.** Eine Glocke schiebt sich durchs Wasser, indem sie sich
## zusammenzieht und wieder oeffnet - schmaler und laenger, dann breiter und
## kuerzer. Das ist eine Bewegung der Form selbst, und sie kostet zwei
## Faktoren.
##
## **Der Schirm ist hohl.** Die Fuellung stand auf 0,42 und stieg beim
## Brennen auf 0,84 - eine helle Flaeche, die von der Nachbearbeitung
## milchig wird. Eine Qualle sieht man *durch*; was sie zeigt, ist ihr Rand
## und die vier Radialkanaele darin.
func _schleier(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    # Pumpen: eng und lang, dann breit und kurz. Gegenlaeufig, damit die
    # Flaeche ungefaehr gleich bleibt - eine Glocke, die nur groesser wird,
    # atmet nicht, sie waechst.
    var stoss := sin(t.alter * 3.4 + t.phase)
    var breit := 1.24 + 0.16 * stoss
    var lang := 1.02 - 0.14 * stoss

    var schirm := PackedVector2Array()
    for i in 15:
        var w := lerpf(-PI * 0.52, PI * 0.52, float(i) / 14.0)
        # Vier Lappen auf dem Saum. Der Faktor greift nur aussen an, damit
        # die Kuppe glatt bleibt - eine Glocke ist oben rund und unten
        # gefranst.
        var lappen := 1.0 + 0.10 * cos(w * 4.0) * absf(sin(w))
        schirm.append(p + (k * cos(w) * lang + quer * sin(w) * breit)
            * r * lappen)
    # Der Glockenrand hinten leicht eingezogen, statt gerade abgeschnitten.
    #
    # **Die Reihenfolge ist nicht beliebig.** Der Bogen laeuft von der einen
    # Seite zur anderen; die drei Punkte muessen von *dort* zurueck. Falsch
    # herum angehaengt kreuzt der Umriss sich selbst, und Godot meldet
    # dreihundertneunundneunzig Mal je Lauf `triangulation failed` - stumm
    # im Bild, laut im Log.
    schirm.append(p - k * r * 0.30 + quer * r * 0.30)
    schirm.append(p - k * r * 0.46)
    schirm.append(p - k * r * 0.30 - quer * r * 0.30)

    # **Sie geht jetzt durch `_koerper()` wie jede andere Art.**
    #
    # Hier stand ein Hauch Fuellung (0,16) unter einem Umriss, der auf 18 %
    # Weiss anfing und beim Brennen auf 73 stieg. Auf einem Tier von zwanzig
    # Pixeln ist das kein Koerper, sondern eine **weisse Sichel** - und weil
    # der Schleier mit sechshundert Auftritten die zweithaeufigste Art ist,
    # war diese Sichel ein grosser Teil des Spiels. Die anderen sechzehn
    # Arten waren laengst gefuellte Leiber; genau diese eine und die
    # Glutqualle waren es nicht, und man sah es sofort, sobald sie
    # nebeneinander standen.
    #
    # `weich = 1` statt der ueblichen zwei: zweimal Ecken schneiden macht
    # aus den vier Lappen wieder einen glatten Bogen, und die Lappen sind
    # das Einzige, was den Saum vom Halbkreis unterscheidet.
    _koerper(schirm, farbe, hitze, k, 1)

    # Der Magen als einziger heller Punkt, in der Kuppe - eine Qualle hat
    # genau ein undurchsichtiges Organ, und das ist es.
    draw_circle(p + k * r * 0.18, r * 0.20,
        Color(farbe.r, farbe.g, farbe.b, 0.30))
    draw_circle(p + k * r * 0.18, r * 0.12,
        Color(1.0, 0.96, 0.90, 0.40 + 0.40 * hitze))

    # Drei bis fuenf Faeden, und jeder Schleier haengt sie ein Stueck weiter
    # oder kuerzer nach hinten. Ein Schwarm aus Wolken, in dem jede Wolke
    # dieselben vier Faeden in derselben Laenge zieht, ist ein Kamm.
    var faeden := 3 + int(_eigenart(t, 4.9) * 3.0)
    var laenge := lerpf(1.45, 2.05, _eigenart(t, 7.1))
    for i in faeden:
        var s := (float(i) - float(faeden - 1) * 0.5) * 0.42
        var wurzel := p - k * r * 0.2 + quer * r * s
        # Deutlicher ausschwingend und je Faden versetzt: vier Faeden mit
        # derselben Auslenkung sind ein Kamm.
        var wehen := sin(t.alter * 4.4 + float(i) * 1.7 + t.phase) * r * 0.85
        _fangarm(wurzel, -k, r * laenge, r * 0.075, wehen, farbe, 0.30)


func _panzerkrebs(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Breiter, flacher Panzer, sechs Laufbeine, zwei schwere Scheren voran.
    # Der erste Entwurf war ein Sechseck mit zwei Strichen - im Bild eine
    # Papiertuete. Ein Krebs wird durch seine Anhaenge erkannt, nicht durch
    # den Umriss des Panzers.
    var k := t.richtung
    var quer := k.orthogonal()
    var rudern := sin(t.alter * 3.4 + t.phase)

    # **Die Beine faechern, und sie gehen nicht im Gleichschritt.**
    #
    # Sie standen zu dritt je Seite in gleichem Abstand, alle mit demselben
    # Winkel nach hinten und alle im selben Takt - im Bild ein Kamm, der
    # sich als Ganzes hebt und senkt. Ein Tier bewegt sich so nicht.
    #
    # Drei Dinge dagegen, und alle drei kosten eine Zeile: das vorderste
    # Beinpaar zeigt nach **vorn**, das hinterste nach hinten (Faecher); die
    # Beine werden nach hinten **kuerzer**; und jedes hat seine eigene
    # Phase, so dass eine Welle durch sie laeuft, statt dass sie zusammen
    # zucken.
    for seite: float in SEITEN:
        for i in 3:
            var f := float(i) / 2.0
            var takt := sin(t.alter * 3.4 + t.phase + float(i) * 1.9)
            var laengs := lerpf(0.42, -0.66, f)
            var wurzel := p + k * r * laengs + quer * r * 0.62 * seite
            # Winkel: vorn nach vorn, hinten nach hinten.
            var aus := lerpf(0.46, -0.62, f)
            var lang := lerpf(1.00, 0.74, f)
            var knie := wurzel + (quer * seite * 0.86 + k * aus).normalized() \
                * r * lang * (0.72 + 0.08 * takt)
            var fuss := knie + (quer * seite * 0.52
                + k * (aus - 0.55)).normalized() * r * lang \
                * (0.66 + 0.12 * takt)
            # Hintere Beine dunkler: von oben liegen sie im eigenen Schatten.
            var tiefe := 0.62 - 0.13 * float(i)
            _glied(wurzel, knie, r * 0.20, r * 0.11, farbe, tiefe)
            _glied(knie, fuss, r * 0.11, r * 0.028, farbe, tiefe * 0.8)

    # **Die Scheren.** Sie sind das, was einen Krebs von einer Assel
    # unterscheidet, und sie waren zwei Haarlinien mit einem Haken.
    # Jetzt: ein kraeftiger Oberarm, ein Unterarm und eine **zweiteilige
    # Klaue**, die sich oeffnet und schliesst.
    for seite: float in SEITEN:
        var klapp := 0.5 + 0.5 * sin(t.alter * 2.1 + t.phase + seite)
        var schulter := p + k * r * 0.52 + quer * r * 0.44 * seite
        var ellbogen := schulter + (k * 0.72 + quer * seite * 0.62).normalized() \
            * r * 0.60
        var hand := ellbogen + (k * 0.94 - quer * seite * 0.24).normalized() \
            * r * 0.46
        _glied(schulter, ellbogen, r * 0.22, r * 0.17, farbe, 0.72)
        _glied(ellbogen, hand, r * 0.17, r * 0.13, farbe, 0.68)
        for finger: float in SEITEN:
            var oeffnung := (0.16 + 0.30 * klapp) * finger
            var spitze := hand + (k * (0.92 - absf(oeffnung) * 0.5)
                + quer * (oeffnung - 0.10 * seite)).normalized() * r * 0.40
            _glied(hand, spitze, r * 0.10, r * 0.022, farbe, 0.66)

    # **Ein Krebs ist gegliedert, und das ist seine Silhouette.**
    #
    # Der Panzer war 1,56 lang und 2,04 breit - fast rund, und im Bild ein
    # Klecks mit Beinen. Eine Assel erkennt man an ihren **Querplatten**:
    # der Umriss selbst ist gestuft, nicht glatt, und genau diese Stufen
    # sieht man auch dann noch, wenn das Tier zwanzig Pixel gross ist.
    var panzer := PackedVector2Array()
    for i in 5:
        var u := lerpf(0.78, -0.86, float(i) / 4.0)
        # Jede Platte etwas breiter als die davor, dann wieder schmaler -
        # der Umriss bekommt dadurch Kerben statt einer Rundung.
        var halb: float = r * (0.72 + 0.42 * sin(float(i) * 0.9 + 0.5))
        panzer.append(p + k * r * u + quer * halb)
    for i in range(4, -1, -1):
        var u := lerpf(0.78, -0.86, float(i) / 4.0)
        var halb: float = r * (0.72 + 0.42 * sin(float(i) * 0.9 + 0.5))
        panzer.append(p + k * r * u - quer * halb)
    _koerper(panzer, farbe, hitze, t.richtung, 1)
    # Die Fugen zwischen den Platten, quer.
    for i in 4:
        var u := lerpf(0.52, -0.62, float(i) / 3.0)
        var halb: float = r * (0.70 + 0.38 * sin(float(i) * 0.9 + 0.9))
        _zug(PackedVector2Array([
            p + k * r * u + quer * halb * 0.92,
            p + k * r * (u - 0.06),
            p + k * r * u - quer * halb * 0.92]),
            Color(farbe.r, farbe.g, farbe.b, 0.22 + 0.30 * hitze), 1.1)

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
        _auge(kopf, r * 0.17, hitze, farbe)


func _grabnatter(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    # Der Leib folgt der eigenen Bahn: die Glieder sitzen dort, wo das Tier
    # vor Sekundenbruchteilen war. Weil `Schlund.bahn()` eine reine Funktion
    # der Zeit ist, laesst sich das exakt zurueckrechnen - der Koerper luegt
    # also nie ueber den Weg, den er genommen hat.
    var glieder := t.rueckweg
    if glieder.is_empty():
        glieder = [p]

    # **Ein Leib, keine Perlenkette.**
    #
    # Er war je Glied ein `draw_circle` - und die Glieder liegen neun
    # Einheiten auseinander, waehrend der vorderste bei einem Radius von
    # dreissig fast dreissig Einheiten dick ist. Kreise, die dreimal so
    # breit sind wie ihr Abstand, ergeben genau das, wonach es im Bild
    # aussah: eine Kette gleich grosser Scheiben mit sichtbaren Kerben
    # dazwischen. Eine Schlange hat keine Kerben.
    #
    # Stattdessen ein Band aus drei Punktreihen ueber denselben Weg, in
    # einem Aufruf: aussen auf Deckung null, in der Mitte voll, und die
    # halbe Breite laeuft vom Kopf zum Schwanz aus. Damit wird aus der Kette
    # ein Koerper, und die Deckung addiert sich nicht mehr an jeder
    # Ueberlappung auf.
    #
    # Die Ruecken**zeichnung** bleibt: eine hellere Mittellinie, die den
    # Ruecken vom Bauch trennt - das ist das, was die einzelnen Glieder
    # vorher unfreiwillig erzaehlt haben.
    var gn := glieder.size()
    if gn >= 3:
        # **Fuenf Punktreihen, nicht drei.** Mit dreien faellt die Deckung
        # von der Mittellinie aus sofort ab, und dann sieht ein Band von
        # zwei Radien Breite aus wie ein Faden von einem: der Verlauf
        # frisst die halbe Breite. Ein Koerper braucht einen vollen Kern
        # und einen Saum darum - genau wie der Fels (Schulter, Kante,
        # Saum).
        var ecken := PackedVector2Array()
        var farben := PackedColorArray()
        var seiten := PackedFloat32Array([-1.0, -0.66, 0.0, 0.66, 1.0])
        for i in gn:
            var f := 1.0 - float(i) / float(gn)
            var vor: Vector2 = glieder[maxi(0, i - 1)]
            var nach: Vector2 = glieder[mini(gn - 1, i + 1)]
            var q := (nach - vor)
            q = q.orthogonal().normalized() if q.length() > 0.001 \
                else Vector2.UP
            var dick := r * (0.42 + 0.86 * f)
            var haut := Color(farbe.r, farbe.g, farbe.b,
                0.66 + 0.24 * hitze).darkened(0.30 * (1.0 - f))
            for sp in seiten:
                var rand := absf(sp) >= 0.99
                ecken.append(glieder[i] + q * dick * sp)
                farben.append(_gedeckt(Color(haut.r, haut.g, haut.b,
                    0.0 if rand else haut.a)))
        var netz := PackedInt32Array()
        for i in gn - 1:
            var a := i * 5
            var b := a + 5
            for j in 4:
                netz.append_array([a + j, b + j, b + j + 1,
                    a + j, b + j + 1, a + j + 1])
        RenderingServer.canvas_item_add_triangle_array(
            get_canvas_item(), netz, ecken, farben)
        # Die Ruecken-Mittellinie, heller und schmaler.
        var ruecken := PackedColorArray()
        var linie := PackedVector2Array()
        for i in gn:
            var f2 := 1.0 - float(i) / float(gn)
            linie.append(glieder[i])
            ruecken.append(_gedeckt(farbe.lerp(Color(1.0, 0.98, 0.94),
                0.20 + 0.45 * hitze) * Color(1, 1, 1,
                    (0.10 + 0.24 * hitze) * f2)))
        draw_polyline_colors(linie, ruecken, maxf(1.0, r * 0.09), true)

    var k := t.richtung
    var quer := k.orthogonal()
    var kopf := PackedVector2Array([
        p + k * r * 1.25,
        p + quer * r * 0.72,
        p - k * r * 0.55,
        p - quer * r * 0.72,
    ])
    _koerper(kopf, farbe, hitze, t.richtung)
    _auge(p + k * r * 0.35 + quer * r * 0.30, r * 0.19, hitze, farbe)
    _auge(p + k * r * 0.35 - quer * r * 0.30, r * 0.19, hitze, farbe)


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

    # **Ein Schild ist eckig.**
    #
    # Hier stand ein Siebeneck mit abwechselnd 0,92 und 1,08 Radien - also
    # ein Kreis mit einer Delle. Seitenverhaeltnis 1,0, und damit im Bild
    # das, was jeder runde Umriss auf zwanzig Pixeln ist: ein Ring.
    #
    # Was diese Art ausmacht, ist ihr Panzer, und Panzer sind **Platten**:
    # gerade Kanten, harte Ecken, breiter als lang. Das unterscheidet sie
    # auf einen Blick von allem Weichen ringsum - und es ist dieselbe
    # Auskunft, die ihre Regel gibt.
    var saum := PackedVector2Array([
        p + k * r * 0.74,
        p + k * r * 0.40 + quer * r * 1.06,
        p - k * r * 0.30 + quer * r * 1.18,
        p - k * r * 0.86 + quer * r * 0.60,
        p - k * r * 0.86 - quer * r * 0.60,
        p - k * r * 0.30 - quer * r * 1.18,
        p + k * r * 0.40 - quer * r * 1.06,
    ])
    _koerper(saum, farbe, hitze, t.richtung, 0)

    # **Panzer sind Platten, und Platten sieht man an ihren Fugen.**
    #
    # Hier lagen drei duenne `_zug` und drei Fuellungen mit 0,16 Deckung
    # uebereinander - im Bild ein Sechseck mit zwei Streifen darauf, also
    # ein Edelstein. Die Regel dieser Art ist ihr Panzer ("ein fester
    # Betrag wird jede Sekunde abgezogen"), und was einen Panzer im Bild
    # ausmacht, ist nicht die Platte, sondern die **Kante, an der die
    # naechste darueberliegt**.
    #
    # `_rille()` zeichnet genau das: eine dunkle Fuge und eine schmale helle
    # Lippe auf der Lichtseite - dieselbe Sprache, in der `_inneres()` alle
    # anderen Leiber gliedert. Drei davon quer ueber den Schild, jede
    # gewoelbt wie die Platte, die sie begrenzt.
    var zum_licht := lichtquelle - p
    zum_licht = zum_licht.normalized() if zum_licht.length_squared() > 1.0 \
        else Vector2.UP
    var fuge := Color(0.03, 0.07, 0.11, 0.52 + 0.16 * hitze)
    var lippe := farbe.lerp(Color(1.0, 0.98, 0.94), 0.22 + 0.40 * hitze)
    for i in 3:
        var u := lerpf(0.30, -0.54, float(i) / 2.0)
        var halb := r * (1.14 - 0.34 * absf(u))
        var bogen := PackedVector2Array()
        for j2 in 7:
            var v := lerpf(-1.0, 1.0, float(j2) / 6.0)
            # Die Fuge woelbt sich nach vorn: eine Platte liegt auf der
            # naechsten, sie ist kein Schnitt quer durch.
            bogen.append(p + quer * halb * v
                + k * r * (u + 0.16 * (1.0 - v * v)))
        _rille(bogen, fuge, lippe, zum_licht * (r * 0.10))

    # **Der Saum: ein Panzer hat Dicke.** Eine zweite Kontur, ein Stueck
    # nach innen versetzt, sagt "diese Schale ist dick" - eine einzelne
    # Linie sagt nur "hier hoert etwas auf".
    var innen := PackedVector2Array()
    for v in saum:
        innen.append(p + (v - p) * 0.80)
    _zug(innen + PackedVector2Array([innen[0]]),
        Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.34 * hitze), 1.3)

    _auge(p + k * r * 0.66 + quer * r * 0.26, r * 0.15, hitze, farbe)
    _auge(p + k * r * 0.66 - quer * r * 0.26, r * 0.15, hitze, farbe)


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
    # **Auch sie ist ein Leib und kein Umriss.** Dieselbe Umstellung wie
    # beim Schleier: eine Fuellung von 0,13 unter einer Kontur ist eine
    # Roehre. Der Schirm ist bei ihr trotzdem blass gemeint - das ist ihre
    # Regel als Bild -, und das macht `_koerper()` von selbst: die Fuellung
    # geht mit der Hitze **zurueck**, der Kern darin bleibt der helle Teil.
    _koerper(schirm, farbe, hitze, k, 2)

    for i in 5:
        var s := (float(i) - 2.0) * 0.34
        var wurzel := p - k * r * 0.30 + quer * r * s
        var wehen := sin(t.alter * 4.4 + float(i) * 1.3) * r * 0.26
        _fangarm(wurzel, -k, r * 1.5, r * 0.085, wehen, farbe, 0.26)

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
    # **Ein Seil wird zur Last hin duenner, nicht dicker.** Die Schleppe war
    # ein Zug von gleicher Breite mit einem Punkt am Ende - ein Stock mit
    # einer Perle. Sie laeuft jetzt aus und traegt am Ende einen Anker aus
    # drei Armen: das ist die Form, die dieser Art ihren Namen gibt, und man
    # sieht sie auch dann, wenn sie nur acht Pixel gross ist.
    for i in range(schleppe.size() - 1):
        var f := float(i) / float(schleppe.size() - 1)
        _glied(schleppe[i], schleppe[i + 1], r * (0.075 - 0.045 * f),
            r * (0.075 - 0.045 * (f + 0.2)), farbe, 0.46 - 0.14 * f)
    var ende: Vector2 = schleppe[schleppe.size() - 1]
    var davor: Vector2 = schleppe[schleppe.size() - 2]
    var laengs := (ende - davor).normalized()
    var seit := laengs.orthogonal()
    for arm: float in SEITEN:
        _glied(ende, ende + (laengs * 0.5 + seit * arm).normalized() * r * 0.34,
            r * 0.055, r * 0.02, farbe, 0.50)
    _glied(ende, ende + laengs * r * 0.22, r * 0.05, r * 0.02, farbe, 0.50)

    var leib := PackedVector2Array([
        p + k * r * 0.92 + zug * r * 0.28,
        p + quer * r * 0.70,
        p - k * r * 0.86 + zug * r * 0.12,
        p - quer * r * 0.70,
    ])
    _koerper(leib, farbe, hitze, t.richtung)

    # **Das Segel ist seine Regel, also muss es die Silhouette sein.**
    #
    # Hier standen zwei `draw_line` von zwei Pixeln Breite - bei einem Tier
    # von dreissig Einheiten zwei Striche, die man nicht sieht, und der
    # Umriss war ein Rhombus mit Seitenverhaeltnis 1,27, also rund. Von
    # dem, was diese Art ausmacht - "sie rutscht seitlich weg, waehrend sie
    # naeher kommt" -, stand nichts im Bild.
    #
    # Jetzt eine **Flosse** zur Driftseite: eine Flaeche mit Kontur, die am
    # Leib ansetzt und im Strom flattert. Sie macht das Tier auf einen Blick
    # unsymmetrisch, und die Richtung, in die sie steht, ist die, in die es
    # wegrutscht - man sieht die Regel, bevor sie einen kostet.
    #
    # **Und die Kontur ist der Teil, der traegt.** Der erste Anlauf war eine
    # Fuellung mit drei dicken Rippen darauf und ohne Aussenkante: im Bild
    # drei parallele Balken, die aussahen wie Schnurrhaare, und dazwischen
    # nichts. Eine Flosse erkennt man an ihrem Rand, nicht an ihren Rippen.
    var wurzel_a := p + quer * r * 0.80 - zug * r * 0.06
    var wurzel_b := p - quer * r * 0.72 - zug * r * 0.06
    var aussen := PackedVector2Array()
    for i in 9:
        var u := float(i) / 8.0
        var basis := wurzel_a.lerp(wurzel_b, u)
        # Am breitesten kurz vor der Mitte, zu beiden Enden auslaufend -
        # eine Membran ist an ihrer Wurzel angewachsen und aussen frei.
        var weite := r * (1.70 - 1.45 * absf(u - 0.44))
        var flattern := sin(t.alter * 2.6 + u * 4.2 + t.phase) * r * 0.13
        aussen.append(basis + zug * maxf(0.0, weite + flattern))

    var flosse := PackedVector2Array([wurzel_a])
    var toene := PackedColorArray([
        _gedeckt(Color(farbe.r, farbe.g, farbe.b, 0.40 + 0.24 * hitze))])
    for v in aussen:
        flosse.append(v)
        toene.append(_gedeckt(Color(farbe.r, farbe.g, farbe.b,
            0.13 + 0.10 * hitze)))
    flosse.append(wurzel_b)
    toene.append(_gedeckt(Color(farbe.r, farbe.g, farbe.b,
        0.40 + 0.24 * hitze)))
    draw_polygon(flosse, toene)

    # Die Aussenkante, an den Enden auslaufend: der Rand macht die Form.
    var kante := PackedColorArray()
    for i in aussen.size():
        var u := float(i) / float(aussen.size() - 1)
        kante.append(_gedeckt(farbe.lerp(Color(1.0, 0.98, 0.94),
            0.18 + 0.40 * hitze) * Color(1, 1, 1,
                (0.30 + 0.30 * hitze) * sin(PI * u))))
    draw_polyline_colors(aussen, kante, 1.3, true)

    # Zwei duenne Speichen - genug, damit die Flaeche gespannt wirkt.
    for i in 2:
        var idx := 2 + i * 4
        var u := float(idx) / 8.0
        draw_line(wurzel_a.lerp(wurzel_b, u),
            wurzel_a.lerp(wurzel_b, u).lerp(aussen[idx], 0.88),
            _gedeckt(Color(farbe.r, farbe.g, farbe.b, 0.26 + 0.18 * hitze)),
            1.1, true)

    _auge(p + k * r * 0.42 + zug * r * 0.22, r * 0.19, hitze, farbe)


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

    # **Ein Aal ist lang.**
    #
    # Der Kopf war eine Raute von 1,35 Radien Laenge und 0,92 Breite, und
    # dahinter fuenf einzelne Kreise - im Bild ein Klecks mit einem Faden.
    # Seitenverhaeltnis eins Komma fuenf ist keine Richtung.
    #
    # Der Leib laeuft jetzt in **einem** Umriss vom Maul bis zum Schwanz und
    # ist beim Zustossen ueber drei Radien lang. Das ist die ganze Aussage
    # dieser Art - sie schnellt vor -, und sie steht damit im Umriss statt in
    # einer Bewegung, die man verpassen kann.
    var kopf := PackedVector2Array([
        p + k * r * 1.30 * laenge,
        p + k * r * 0.72 * laenge + quer * r * 0.40 * dicke,
        p + k * r * 0.10 + quer * r * 0.46 * dicke,
        p - k * r * 0.90 + quer * r * 0.26 * dicke,
        p - k * r * 1.70 + quer * r * 0.10 * dicke,
        p - k * r * 1.86,
        p - k * r * 1.70 - quer * r * 0.10 * dicke,
        p - k * r * 0.90 - quer * r * 0.26 * dicke,
        p + k * r * 0.10 - quer * r * 0.46 * dicke,
        p + k * r * 0.72 * laenge - quer * r * 0.40 * dicke,
    ])
    _koerper(kopf, farbe, hitze, t.richtung)

    # Ein heller Blitz entlang des Leibes, wenn er gerade schiesst.
    if schub > 0.45:
        draw_line(p - k * r * 1.2, p + k * r * 1.1 * laenge,
            Color(1.0, 0.98, 0.92, 0.28 * (schub - 0.45) / 0.55), 2.4)

    _auge(p + k * r * 0.48 * laenge, r * 0.17, hitze, farbe)


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
        # Weiter ausschwingend und je Faden versetzt - neun Faeden im
        # Gleichtakt sind ein Kamm, nicht ein Schleier.
        var wehen := sin(t.alter * 1.7 + float(i) * 1.35) * r * 0.95
        _fangarm(wurzel, -k, r * 2.4, r * 0.075, wehen, farbe,
            0.18 + 0.10 * hitze)

    var mantel := PackedVector2Array()
    for i in 17:
        var w := lerpf(-PI * 0.72, PI * 0.72, float(i) / 16.0)
        var buchtung := 1.0 + 0.07 * sin(float(i) * 2.3 + t.alter * 1.4)
        mantel.append(p + (k * cos(w) * 0.96 + quer * sin(w) * 1.22)
            * r * atem * buchtung)
    mantel.append(p - k * r * 0.72)
    _koerper(mantel, farbe, hitze, t.richtung)

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
        _auge(p + (k * cos(w) * 0.62 + quer * sin(w) * 0.86) * r, r * 0.10, hitze, farbe)


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
    # **Der Schwanz eines Rochens laeuft aus.** Er war eine Polylinie von
    # dreikommavier Pixeln ueber ihre ganze Laenge - eine Peitsche hat aber
    # an der Wurzel den Durchmesser des Tieres und an der Spitze keinen.
    for i in range(schwanz.size() - 1):
        var f := float(i) / float(schwanz.size() - 1)
        # **Duenn.** Der erste Anlauf nahm 0,115 Radien als Wurzelbreite -
        # bei einem Leitwesen mit sechzig Einheiten Radius sind das sieben
        # Pixel, und im Bild wurde daraus ein Keil statt einer Peitsche. Der
        # Schwanz eines Rochens ist duenner als sein Auge.
        _glied(schwanz[i], schwanz[i + 1], r * (0.055 - 0.044 * f),
            r * (0.055 - 0.044 * (f + 0.17)), farbe,
            (0.56 + 0.24 * hitze) * (1.0 - 0.30 * f))
    # Der Giftstachel: ein schmales Dreieck laengs der Spitze.
    var spitz: Vector2 = schwanz[schwanz.size() - 1]
    var vor: Vector2 = schwanz[schwanz.size() - 2]
    var richt := (spitz - vor).normalized()
    draw_colored_polygon(PackedVector2Array([
        spitz - richt * r * 0.34 + richt.orthogonal() * r * 0.045,
        spitz - richt * r * 0.34 - richt.orthogonal() * r * 0.045,
        spitz + richt * r * 0.20]),
        _gedeckt(Color(1.0, 0.96, 0.88, 0.52 + 0.36 * hitze)))

    # Der Schild: breit quer zur Bahn, vorn stumpf, hinten spitz. Die
    # Wellenkante an den Flanken ist das, woran ein Rochen erkannt wird.
    var schild := PackedVector2Array()
    for i in 19:
        var u := lerpf(-1.0, 1.0, float(i) / 18.0)
        var laengs := (1.0 - u * u) * 0.86 - 0.14
        var flatter := 0.08 * sin(u * 5.4 + t.alter * 2.2)
        schild.append(p + k * r * laengs + quer * r * u * (1.36 + flatter))
    schild.append(p - k * r * 0.62)
    _koerper(schild, farbe, hitze, t.richtung)

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
        _auge(p + k * r * 0.44 + quer * r * seite * 0.30, r * 0.11, hitze, farbe)


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
    _koerper(kern, farbe, hitze, t.richtung)

    _auge(p, r * 0.17, hitze, farbe)


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
    var zum_licht := (lichtquelle - p)
    if zum_licht.length_squared() < 1.0:
        return
    var w := zum_licht.angle()
    var staerke: float = t.licht
    var bogen := lerpf(1.15, 0.72, staerke)

    # Zwei Bogen: ein breiter, weicher Saum und darin eine schmale, harte
    # Kante. Der Saum macht die Rundung, die Kante den Glanzpunkt.
    # **Nur noch der Kern, kein Bogen mehr.**
    #
    # Hier lagen zwei Kreisboegen bei 1,04 und 0,96 Radien um den
    # Mittelpunkt. Auf einem runden Tier sass das ungefaehr auf der Kante,
    # auf einem langen Fisch schwebte es daneben - ein heller Strich im
    # Wasser, der zu nichts gehoert. Die Lichtseite macht jetzt `_koerper()`
    # auf dem echten Umriss; was hier bleibt, ist ein Schein im Wasser
    # davor, und der darf rund sein, weil er keine Kante behauptet.
    draw_circle(p + (lichtquelle - p).normalized() * r * 0.55,
        r * 0.75, Color(farbe.r, farbe.g, farbe.b, 0.10 * staerke))
    var _b := bogen


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
## Laichwolke: ein winziger Koerper mit zwei Wimpernkraenzen.
##
## **Bewusst arm an Linien.** Sechs bis neun kommen auf einen Schlag, und
## wenn jedes davon ein Kunstwerk waere, saehe der Schwarm aus wie
## Konfetti. Was ihn lesbar macht, ist die Wiederholung derselben einfachen
## Form - der Schwarm ist die Figur, nicht das Tier.
## Die Laichwolke: eine **Traube**, kein Leib.
##
## **Sie war eine Raute mit sechs Strichen** - vier Ecken durch `_koerper()`
## und zwei Wimpernkraenze - und sie stellt bei einem Radius von zwoelf
## Einheiten fast die Haelfte aller Tiere im Bild. Auf zwanzig Pixeln ist
## eine glatte Raute nichts: kein Umriss, den man wiedererkennt, keine
## Stelle, an der das Auge haengenbleibt.
##
## **Was auf zwanzig Pixeln traegt, ist nicht Feinheit, sondern Klumpigkeit.**
## Eine Traube aus vier bis sechs verschieden grossen Blasen hat einen
## Umriss mit Beulen, und Beulen liest man auch dann noch, wenn jede
## einzelne Blase nur fuenf Pixel gross ist. Eine Ellipse gleicher Groesse
## liest man als Fleck.
##
## Aufbau in drei Stufen, wie bei jeder lesbaren Figur: die **Haut** um die
## ganze Traube (grosse Form), die **Blasen** (mittlere Form), die
## **Keime** darin (kleine Form, und der einzige helle Punkt).
func _laichwolke(p: Vector2, r: float, farbe: Color, t: Raeuber,
        hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var atem := 0.5 + 0.5 * sin(t.alter * 2.6 + t.phase)
    var zahl := 4 + int(_eigenart(t, 3.7) * 3.0)

    # Die Blasen sitzen auf einer leicht gebogenen Achse, vorn die groesste.
    # Gleich grosse Blasen auf einer Geraden waeren eine Perlenkette.
    var orte := PackedVector2Array()
    var groessen := PackedFloat32Array()
    for i in zahl:
        var u := float(i) / float(zahl - 1)
        var seit := sin(u * 3.1 + t.phase * 4.0) * 0.34
        orte.append(p + k * r * lerpf(0.62, -0.72, u)
            + quer * r * seit)
        groessen.append(r * lerpf(0.46, 0.24, u)
            * (0.92 + 0.16 * sin(t.alter * 3.4 + float(i) * 1.7)))

    # **Die Haut zuerst**: ein weiter, sehr blasser Schleier um die ganze
    # Traube. Er ist das, was aus fuenf Blasen *ein* Tier macht - ohne ihn
    # sieht ein Schwarm aus wie verstreute Punkte.
    for i in zahl:
        draw_circle(orte[i], groessen[i] * 2.1,
            Color(farbe.r, farbe.g, farbe.b, 0.05 + 0.05 * hitze))

    for i in zahl:
        var g: float = groessen[i]
        var wo: Vector2 = orte[i]
        # Blase: nur ein Rand. Eine gefuellte Scheibe wird von der
        # Nachbearbeitung milchig, ein Ring wird zur Roehre.
        draw_arc(wo, g, 0.0, TAU, 12,
            Color(farbe.r, farbe.g, farbe.b, 0.34 + 0.30 * hitze), 2.2, true)
        draw_arc(wo, g, 0.0, TAU, 12, farbe.lerp(Color(1.0, 0.98, 0.94),
            0.20 + 0.55 * hitze), 1.0, true)
        # Der Keim darin, versetzt zur Mitte - eine Blase mit einem Punkt
        # genau in der Mitte ist ein Ziel, keine Zelle.
        var keim := wo + quer * g * 0.26 - k * g * 0.18
        draw_circle(keim, g * 0.30,
            Color(1.0, 0.96, 0.88, 0.45 + 0.40 * atem))

    # Ein paar Wimpern am vordersten Rand, in einer Welle. Sie sagen, wohin
    # die Traube treibt; ohne sie steht sie im Wasser.
    for j in 4:
        var w := lerpf(-0.9, 0.9, float(j) / 3.0)
        var wurzel := orte[0] + (k * cos(w) + quer * sin(w)) * groessen[0]
        var welle := sin(t.alter * 7.0 + float(j) * 1.4 + t.phase) * 0.34
        draw_line(wurzel, wurzel + (k * cos(w + welle)
            + quer * sin(w + welle)) * r * 0.42,
            Color(farbe.r, farbe.g, farbe.b, 0.26 + 0.20 * hitze), 1.0)


## Kreiser: ein flacher Rumpf mit einem Ruderkranz, der zur Seite steht.
##
## Er kommt nie an, also zeigt seine Form quer zur Bahn und nicht nach vorn -
## man soll ihm ansehen, dass er vorbeizieht statt zuzustossen.
func _kreiser(p: Vector2, r: float, farbe: Color, t: Raeuber,
        hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    # **Er ist ein Ring, und das ist keine Zierde, sondern seine Regel.**
    #
    # Der Kreiser haelt Abstand und zieht den Ring langsam enger; er stoesst
    # nie zu. Gezeichnet war er trotzdem als flacher Leib mit einem
    # Ruderkranz - im Bild ein blasses Oval, das aussah wie alles andere,
    # und nichts daran sagte, was es tut.
    #
    # Ein **offener Ring** sagt es auf einen Blick: eine Form, die um etwas
    # herumfuehrt statt darauf zu. Die Luecke zeigt dabei nach vorn - in die
    # Richtung, in die er zieht -, so dass man ihm die Drehrichtung ansieht.
    var innen := r * 0.42
    var aussen := r * 0.92
    var luecke := 0.55
    var ring := PackedVector2Array()
    var stufen := 22
    for i in stufen + 1:
        var w := lerpf(luecke, TAU - luecke, float(i) / float(stufen))
        ring.append(p + (k * cos(w) + quer * sin(w)) * aussen)
    for i in range(stufen, -1, -1):
        var w := lerpf(luecke, TAU - luecke, float(i) / float(stufen))
        ring.append(p + (k * cos(w) + quer * sin(w)) * innen)
    _koerper(ring, farbe, hitze, t.richtung)

    # Ein zweiter, duennerer Ring innen - er dreht sich schneller als der
    # aeussere und macht sichtbar, dass das Tier nicht steht, sondern laeuft.
    var dreh := t.alter * 1.6 + t.phase
    for i in 3:
        var w := dreh + TAU * float(i) / 3.0
        var von := p + (k * cos(w) + quer * sin(w)) * innen
        var nach := p + (k * cos(w + 0.9) + quer * sin(w + 0.9)) * innen
        _zug(PackedVector2Array([von, nach]),
            Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.30 * hitze), 1.2)
    # Der Ruderkranz: sechs kurze Blaetter laengs der Aussenkante, die in
    # einer Welle durchlaufen - so sieht Seitwaertsfahrt aus.
    # Der Ruderkranz sitzt jetzt **aussen auf dem Ring**, nicht an den
    # Flanken eines Rumpfes - eine Welle laeuft ihn entlang, und daran
    # erkennt man die Richtung, in die er zieht.
    for i in 9:
        var u := float(i) / 8.0
        var w := lerpf(luecke + 0.2, TAU - luecke - 0.2, u)
        var welle := sin(t.alter * 5.0 - u * 3.6 + t.phase)
        var strahl := k * cos(w) + quer * sin(w)
        var wurzel := p + strahl * aussen
        _glied(wurzel, wurzel + strahl * r * (0.26 + 0.10 * welle)
            + strahl.orthogonal() * r * 0.14 * welle,
            r * 0.055, r * 0.02, farbe, 0.58)

    # Das Auge sitzt an der Luecke - dort, wo er hinsieht.
    # Auf dem Ring, nicht im Loch: der Kreiser hat keine Mitte.
    _auge(p + k * (innen + aussen) * 0.5, r * 0.13, hitze, farbe)


## Lichtscheue: ein Koerper, der sich zusammenzieht, wenn er brennt.
##
## `t.licht` ist dieselbe Zahl, aus der auch ihr Schaden faellt und aus der
## `Rundum.schritt()` ihr Zurueckweichen nimmt. Sie sieht damit genau so aus,
## wie sie sich verhaelt: je heller, desto enger und desto weiter weg.
func _lichtscheu(p: Vector2, r: float, farbe: Color, t: Raeuber,
        hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var eng := clampf(t.licht, 0.0, 1.0)

    # **Sie war eine Scheibe mit vier Stangen dahinter.**
    #
    # Der Leib mass 1,22 Radien laengs und 1,72 quer - Verhaeltnis 1,4, also
    # rund, und ein runder Umriss ist ein Ring (siehe CLAUDE.md, "Das
    # Seitenverhaeltnis ist der Sprite"). Die Faeden waren `_strich` mit
    # fester Breite; bei vollem Licht faellt `wehen` auf null, und dann
    # standen vier gerade, gleich lange, parallele Stangen hinter ihr. Im
    # Schuss war das ein Kamm auf einem Halbmond.
    #
    # Jetzt eine **Kapuze mit Schleppe**: vorn breit und ueberhaengend, nach
    # hinten auf eine Spitze auslaufend, 2,5 lang zu 1,0 breit. Und die
    # Kapuze ist ihre Regel als Bild - ein Tier, das vor dem eigenen Licht
    # zurueckweicht, sieht aus, als duckte es sich unter etwas weg.
    var lang := 1.05 + 0.20 * (1.0 - eng)
    var oben := PackedVector2Array()
    var unten := PackedVector2Array()
    for i in 11:
        var u := float(i) / 10.0
        var x := lerpf(lang, -1.45, u)
        # Vorn die Kapuze, hinten die Spitze. Der Exponent zieht die groesste
        # Breite nach vorn - hinten laeuft sie lang aus, statt symmetrisch
        # zu sein wie ein Blatt.
        var b := pow(sin(PI * pow(u, 0.58)), 1.15) * 0.52
        # Beim Zurueckweichen zieht sie sich zusammen: schmaler und kuerzer.
        b *= 1.0 - 0.26 * eng
        oben.append(p + k * x * r + quer * b * r)
        unten.append(p + k * x * r - quer * b * r)
    unten.reverse()
    var leib := oben + unten
    _koerper(leib, farbe, hitze, k, 1)

    # Der Kapuzensaum: eine Rille quer ueber den Vorderleib, dort wo die
    # Kapuze aufhoert. Sie sagt, dass vorn etwas *ueber* dem Koerper liegt.
    var saum := PackedVector2Array()
    for i in 7:
        var w := lerpf(-1.05, 1.05, float(i) / 6.0)
        saum.append(p + k * r * (0.34 + 0.16 * cos(w)) + quer * sin(w) * r * 0.44)
    var zum_licht := lichtquelle - p
    zum_licht = zum_licht.normalized() if zum_licht.length_squared() > 1.0 \
        else Vector2.UP
    _rille(saum, Color(0.04, 0.09, 0.14, 0.44 + 0.14 * hitze),
        farbe.lerp(Color(1.0, 0.98, 0.94), 0.10 + 0.30 * hitze),
        zum_licht * 1.4)

    # **Faeden, die faechern.** Jeder bekommt seine eigene Wurzelrichtung
    # und seine eigene Laenge - vier Faeden in dieselbe Richtung sind ein
    # Kamm, und daran ist keine Bewegung zu sehen. Beim Zurueckweichen legen
    # sie sich an: kuerzer und enger gefaechert.
    var faeden := 4 + int(_eigenart(t, 6.1) * 3.0)
    for i in faeden:
        var s_seite := (float(i) - float(faeden - 1) * 0.5) \
            / maxf(1.0, float(faeden - 1) * 0.5)
        var wurzel := p - k * r * 1.15 + quer * s_seite * r * 0.20
        var faecher := s_seite * (0.62 - 0.34 * eng)
        var laenge := r * (1.5 - 0.7 * eng) \
            * (0.72 + 0.55 * _eigenart(t, 3.3 + float(i)))
        var wehen := sin(t.alter * 5.0 + float(i) * 1.9 + t.phase) \
            * r * 0.30 * (1.0 - 0.7 * eng)
        _fangarm(wurzel, (-k).rotated(faecher), laenge, r * 0.055,
            wehen, farbe, 0.34)

    _auge(p + k * r * 0.62, r * 0.14, hitze, farbe)


## Ringmaul: ein offener Ring mit Zaehnen nach innen.
##
## Es kreist, also ist es quer gebaut wie der Kreiser - nur gross, mit einem
## Maul, das nach innen zeigt. Ein Leitwesen muss man am Umriss erkennen.
func _ringmaul(p: Vector2, r: float, farbe: Color, t: Raeuber,
        hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var atem := 0.5 + 0.5 * sin(t.alter * 1.2 + t.phase)

    # **Kein Kreis-Hof mehr.** Er stand hier zusaetzlich zu dem, den
    # `_koerper()` als Schale entlang des Umrisses zeichnet - ein
    # runder Fleck ueber einer Form, die nicht rund ist, und bei einem
    # Leitwesen von sechzig Einheiten Radius der auffaelligste im Bild.
    # Der Leib als offener Bogen quer zur Bahn.
    var bogen := PackedVector2Array()
    for i in 15:
        var w := lerpf(-PI * 0.82, PI * 0.82, float(i) / 14.0)
        var weit := r * (0.78 + 0.10 * sin(w * 3.0 + t.alter))
        bogen.append(p + k * sin(w) * weit + quer * cos(w) * weit)
    _fuellung(bogen, Color(farbe.r, farbe.g, farbe.b, 0.30))
    _zug(bogen, farbe.lightened(0.28), 2.2)
    # Zaehne nach innen - das Maul liegt auf der Innenseite des Rings.
    # **Zaehne sind Dreiecke, keine Balken.**
    #
    # Hier standen elf gerade weisse Striche von gleicher Breite vom Ring
    # nach innen - im Bild ein Zahnrad, kein Maul. Ein Zahn ist an der Wurzel
    # breit und laeuft spitz zu; das ist der ganze Unterschied zwischen einem
    # Gebiss und einer Speiche.
    #
    # Und sie sind **verschieden lang**. Gleich lange Zaehne in gleichem
    # Abstand sind ein Kamm; ein Rachen hat Luecken und Ueberlaenge.
    for i in 11:
        var w := lerpf(-PI * 0.76, PI * 0.76, float(i) / 10.0)
        var strahl := Vector2(k.x * sin(w) + quer.x * cos(w),
            k.y * sin(w) + quer.y * cos(w))
        var lang := 0.40 - 0.06 * atem + 0.10 * sin(float(i) * 2.3)
        var aussen := p + strahl * r * 0.76
        var spitze := p + strahl * r * lang
        var breit := strahl.orthogonal() * r * 0.075
        draw_colored_polygon(PackedVector2Array([
            aussen + breit, aussen - breit, spitze]),
            _gedeckt(Color(1.0, 0.96, 0.90, 0.62 + 0.28 * hitze)))
        # Eine Kante am Zahn, damit er nicht flach auf dem Ring liegt.
        draw_line(aussen + breit, spitze,
            _gedeckt(Color(1.0, 1.0, 0.98, 0.34 + 0.30 * hitze)), 1.0, true)
    draw_circle(p, r * (0.20 + 0.05 * atem),
        Color(farbe.r, farbe.g, farbe.b, 0.55))
    _auge(p + k * r * 0.1, r * 0.16, hitze, farbe)


## Brutstock: ein Stamm mit Knospen, aus denen die Jungen fallen.
##
## Die Knospen leeren sich sichtbar: `t.brut_uhr` laeuft gegen
## `Arten.brut_takt()`, und genau diese Zahl treibt den Ring an, der sich um
## den Kopf schliesst. Wer ihn ansieht, weiss, wieviel Zeit er noch hat.
func _brutstock(p: Vector2, r: float, farbe: Color, t: Raeuber,
        hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()
    var takt := maxf(0.001, Arten.brut_takt(t.art))
    var reif := clampf(t.brut_uhr / takt, 0.0, 1.0)

    # **Kein Kreis-Hof mehr.** Er stand hier zusaetzlich zu dem, den
    # `_koerper()` als Schale entlang des Umrisses zeichnet - ein
    # runder Fleck ueber einer Form, die nicht rund ist, und bei einem
    # Leitwesen von sechzig Einheiten Radius der auffaelligste im Bild.
    # Der Stamm, leicht gebogen.
    var stamm := PackedVector2Array()
    for i in 9:
        var u := float(i) / 8.0
        stamm.append(p + k * r * lerpf(0.9, -0.95, u)
            + quer * r * 0.16 * sin(u * 2.4 + t.alter * 0.7))
    # **Der Stamm verjuengt sich.** Er war ein Zug von vier Pixeln gleicher
    # Breite ueber die ganze Laenge - ein Stab. Ein Stock waechst von unten
    # dick nach oben duenn, und genau daran erkennt man, wo bei ihm oben ist.
    # **Auch er hatte keinen Schein.** Wie der Spiegler zeichnet er seinen
    # Leib selbst und ruft `_koerper()` nicht - damit fiel `_schein()` fuer
    # ihn aus, und ein Leitwesen ohne Schein steht ohne Anschluss im Wasser.
    # Der Umriss dafuer ist der Stamm, nach beiden Seiten auf seine eigene
    # Dicke aufgezogen.
    var huelle := PackedVector2Array()
    var gegen := PackedVector2Array()
    for i in stamm.size():
        var u := float(i) / float(stamm.size() - 1)
        var vor: Vector2 = stamm[maxi(0, i - 1)]
        var nach: Vector2 = stamm[mini(stamm.size() - 1, i + 1)]
        var q := (nach - vor)
        q = q.orthogonal().normalized() if q.length() > 0.001 else quer
        var d := r * (0.28 - 0.17 * u)
        huelle.append(stamm[i] + q * d)
        gegen.append(stamm[i] - q * d)
    gegen.reverse()
    _schein(huelle + gegen, farbe, 10.0 + 16.0 * hitze,
        0.10 + 0.12 * hitze)

    for i in range(stamm.size() - 1):
        var u := float(i) / float(stamm.size() - 1)
        # **Der Stamm war duenner als seine Knospen.** Neun Einheiten unten
        # gegen Beeren von vierzehn - und daraus wird eine Strukturformel:
        # Kugeln, verbunden durch Staebe. Ein Stock traegt seine Knospen,
        # also ist er dicker als sie.
        _glied(stamm[i], stamm[i + 1], r * (0.27 - 0.17 * u),
            r * (0.27 - 0.17 * (u + 0.13)), farbe, 0.70 - 0.16 * u)

    var zum_licht := lichtquelle - p
    zum_licht = zum_licht.normalized() if zum_licht.length_squared() > 1.0 \
        else Vector2.UP

    # Knospen an Seitenaesten. Die reifste sitzt vorn und wird groesser.
    #
    # **Sie sassen auf einem Raster.** Fuenf Aeste, streng abwechselnd links
    # und rechts, alle genau quer und alle gleich lang - im Bild ein
    # Strukturformel-Modell aus Kugeln und Staeben. Ein Stock, an dem alles
    # im selben Winkel steht, ist gewachsen wie ein Zaun. Winkel und Laenge
    # kommen deshalb aus `_eigenart()`, und der Ast ist geknickt statt
    # gerade: zwei Glieder mit einem Knoten dazwischen.
    for i in 5:
        var u := float(i) / 4.0
        var seite := 1.0 if i % 2 == 0 else -1.0
        var wurzel := p + k * r * lerpf(0.6, -0.7, u)
        # Nach hinten geneigt und je Ast anders - ein Seitenzweig zeigt vom
        # Wachstum weg, nicht rechtwinklig ins Wasser.
        var neigung := lerpf(0.34, 0.86, _eigenart(t, 2.1 + float(i)))
        var richt := (quer * seite - k * neigung).normalized()
        var weit := r * lerpf(0.48, 0.78, _eigenart(t, 5.7 + float(i)))
        var knie := wurzel + richt * weit * 0.55
        var spitze := knie + richt.rotated(seite * 0.42) * weit * 0.5
        _glied(wurzel, knie, r * 0.075, r * 0.055, farbe, 0.60)
        _glied(knie, spitze, r * 0.055, r * 0.032, farbe, 0.60)

        # **Eine Knospe ist keine Scheibe.** Sie war eine gefuellte
        # `draw_circle` mit harter Kante - dieselbe Kante, die ueberall
        # sonst in diesem Spiel durch einen Uebergang ersetzt ist. Drei
        # Lagen machen daraus einen Koerper: ein weicher Hof, die Beere
        # selbst, und ein heller Fleck dort, wo das Boot steht.
        var gross := r * (0.10 + 0.08 * reif * (1.0 - u))
        var beere := Color(minf(1.0, farbe.r * 1.3), minf(1.0, farbe.g * 1.3),
            minf(1.0, farbe.b * 1.3))
        draw_circle(spitze, gross * 1.6, _gedeckt(Color(beere.r, beere.g,
            beere.b, 0.07 + 0.07 * reif)))
        draw_circle(spitze, gross, _gedeckt(Color(beere.r * 0.62,
            beere.g * 0.62, beere.b * 0.62, 0.62 + 0.30 * reif)))
        draw_circle(spitze + zum_licht * gross * 0.34, gross * 0.55,
            _gedeckt(Color(beere.r, beere.g, beere.b, 0.55 + 0.35 * reif)))
    # Der Ring am Kopf schliesst sich, bis das naechste Junge faellt.
    draw_arc(p + k * r * 0.62, r * 0.34, -PI * 0.5,
        -PI * 0.5 + TAU * reif, 20,
        Color(1.0, 0.92, 0.98, 0.55 + 0.35 * hitze), 2.0, true)
    _auge(p + k * r * 0.62, r * 0.16, hitze, farbe)


func _spiegler(p: Vector2, r: float, farbe: Color, t: Raeuber, hitze: float) -> void:
    var k := t.richtung
    var quer := k.orthogonal()

    # Die Schale: breit quer zur Bahn, vorn gerundet, hinten offen.
    # **Ein Spiegel hat Facetten, keine Rundung.**
    #
    # Die Schale war 1,58 lang und 1,84 breit - Seitenverhaeltnis 1,16, also
    # rund. Was diese Art kann, ist Licht zurueckwerfen, und das tut keine
    # Kugel, sondern eine **Flaeche**: lange gerade Kanten, spitze Ecken,
    # deutlich laenger als breit. So sieht man ihr an, warum der Kernstrahl
    # an ihr abprallt.
    # **Ein Spiegel besteht aus Facetten, und Facetten springen.**
    #
    # Bisher ging der Spiegler durch `_koerper()` wie alles andere: ein
    # weicher Verlauf zum Licht hin. Im Bild war das eine blasse weisse
    # Mandel - hoeflich, aber austauschbar, und von seiner Regel stand nichts
    # darin.
    #
    # Seine Regel ist, dass er den **Kern des Strahls zurueckwirft**
    # (`Schlund.SPIEGEL_REST`). Genau das sieht man einem geschliffenen Ding
    # an, und zwar an einer Eigenschaft, die kein anderes Tier hier hat: die
    # Helligkeit **springt** von Flaeche zu Flaeche, statt weich
    # ueberzugehen. Ein Verlauf sagt "weiche Haut", eine Stufe sagt "harte
    # Flaeche" - das ist der ganze Unterschied zwischen einer Qualle und
    # einem Kristall, und er kostet eine Schleife.
    #
    # Der Leib ist deshalb kein Umriss mit Fuellung, sondern ein Kranz von
    # Facetten um eine Firstlinie. Jede bekommt ihre Helligkeit aus ihrer
    # eigenen Normalen.
    var ecken := PackedVector2Array([
        p + k * r * 1.34,
        p + k * r * 0.52 + quer * r * 0.62,
        p - k * r * 0.34 + quer * r * 0.70,
        p - k * r * 1.10 + quer * r * 0.26,
        p - k * r * 1.10 - quer * r * 0.26,
        p - k * r * 0.34 - quer * r * 0.70,
        p + k * r * 0.52 - quer * r * 0.62,
    ])
    var first_v := p + k * r * 0.95
    var first_h := p - k * r * 0.80
    var zum_licht := lichtquelle - p
    zum_licht = zum_licht.normalized() if zum_licht.length_squared() > 1.0 \
        else Vector2.UP

    # **Er war die einzige Art ohne Schein.** Weil er `_koerper()` nicht
    # ruft - er zeichnet seine Facetten selbst -, fiel fuer ihn auch
    # `_schein()` aus, und ohne den steht ein dunkles Vieleck ohne Anschluss
    # im Wasser. Im Schuss war er ein grauer Umriss mit einem Auge darin,
    # waehrend nebenan alles leuchtete. Der Schein gehoert zum Tier und
    # nicht zur Fuellmethode.
    _schein(ecken, farbe, 8.0 + 16.0 * hitze, 0.10 + 0.12 * hitze)

    # **Die Facetten allein decken den Leib nicht.** Jedes Dreieck laeuft
    # von einer Aussenkante zum *naeheren* der beiden Gratpunkte - der
    # Streifen zwischen den beiden Graten gehoert damit zu keinem von
    # ihnen. Im Bild war das ein schwarzer Keil laengs mitten durch das
    # Tier, und weil der Umriss aussenherum hell steht, las man ihn als
    # Loch in einem Ring. Ein Grundton unter allem schliesst ihn: die
    # Facetten liegen darauf und bleiben, was sie sind, und wo keine liegt,
    # steht die abgewandte Seite des Schliffs.
    var grundton := Color(farbe.r, farbe.g, farbe.b).lerp(
        Color(0.12, 0.30, 0.44), 0.34)
    draw_colored_polygon(ecken, _gedeckt(Color(grundton.r * 0.45,
        grundton.g * 0.45, grundton.b * 0.45, 0.94)))

    var n := ecken.size()
    for i in n:
        var a1: Vector2 = ecken[i]
        var b1: Vector2 = ecken[(i + 1) % n]
        var mitte_f := (a1 + b1) * 0.5
        # Welcher Punkt des Grats zu dieser Facette gehoert: der naehere.
        var grat: Vector2 = first_v if (mitte_f - first_v).length() \
            < (mitte_f - first_h).length() else first_h
        var norm := (mitte_f - grat).normalized()
        var zu := maxf(0.0, norm.dot(zum_licht))
        # **Der Sprung muss gross sein, sonst ist es kein Schliff.** Mit
        # 0,24 bis 1,24 lagen alle sieben Facetten dicht beieinander und das
        # Tier war wieder eine glatte Flaeche - nur mit Kanten darauf. Eine
        # abgewandte Facette ist fast dunkel, eine zugewandte fast weiss.
        #
        # **Aber auch hier wird nichts schwarz.** Mit 0,12 als Sockel und
        # der Blaustichigkeit darueber fiel eine abgewandte Facette auf
        # praktisch null, und weil bei sieben Facetten meist vier abgewandt
        # sind, war der halbe Leib ein Loch - dieselbe Falle wie bei den
        # Felsen und in `_koerper()`. Ein Viertel als Sockel laesst den
        # Sprung immer noch das Sechsfache betragen; das ist Schliff, und
        # nicht einmal knapp.
        var st := 0.45 + 1.45 * zu * zu
        var ton := Color(farbe.r, farbe.g, farbe.b).lerp(
            Color(0.12, 0.30, 0.44), 0.34 * (1.0 - zu))
        draw_colored_polygon(PackedVector2Array([grat, a1, b1]),
            _gedeckt(Color(minf(1.0, ton.r * st), minf(1.0, ton.g * st),
                minf(1.0, ton.b * st), 0.94)))
        # **Der Glanz** sitzt nur auf der Facette, die dem Licht am naechsten
        # steht, und ist eine scharfe Flaeche: ein Spiegel hat kein weiches
        # Glanzlicht, er hat einen Fleck oder keinen.
        if zu > 0.80:
            draw_colored_polygon(PackedVector2Array([
                grat.lerp(mitte_f, 0.34),
                a1.lerp(mitte_f, 0.46), b1.lerp(mitte_f, 0.46)]),
                _gedeckt(Color(1.0, 1.0, 0.98, 0.28 + 0.42 * hitze)))
        # Die Facettenkante macht den Sprung sichtbar.
        draw_line(grat, a1, _gedeckt(Color(farbe.r, farbe.g, farbe.b,
            0.22 + 0.34 * zu)), 1.0, true)

    var zu_r := ecken + PackedVector2Array([ecken[0]])
    var rand := PackedColorArray()
    for v in zu_r:
        var f := maxf(0.0, (v - p).normalized().dot(zum_licht))
        var kante := farbe.lerp(Color(1.0, 0.99, 0.96), 0.30 + 0.50 * hitze)
        rand.append(_gedeckt(Color(kante.r, kante.g, kante.b,
            0.30 + 0.70 * f)))
    draw_polyline_colors(zu_r, rand, 1.6, true)
    # Zwei Facettenkanten laengs - sie fangen das Licht und sagen, dass die
    # Oberflaeche aus Flaechen besteht und nicht aus Haut.
    # **Die frueheren Facettenzuege sind weg.** Es waren zwei Laengskanten
    # und fuenf Grate, alle als duenne Linien *auf* einer glatten Flaeche
    # gezeichnet - eine Facette, die man aufmalt, ist keine. Jetzt sind es
    # Flaechen mit eigener Helligkeit, und die Kante entsteht dort, wo zwei
    # verschieden helle aneinanderstossen.

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
        # Ein kurzer Strahl zurueck zur Lampe - das Licht kommt von dort,
        # also geht es auch dorthin zurueck.
        var heim := (lichtquelle - p).normalized()
        draw_line(glanz, glanz + heim * r * (0.8 + 1.6 * blenden),
            Color(0.92, 0.98, 1.0, 0.30 * blenden), 1.6)

    _auge(p + k * r * 0.46, r * 0.13, hitze, farbe)
