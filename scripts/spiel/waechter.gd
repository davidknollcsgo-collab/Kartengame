extends Node2D

## Der Waechter der Schlundwache.
##
## **Eigene Datei und eigener Knoten, weil er ueber dem Kegel liegen muss.**
## Vorher zeichnete ihn `kolonie.gd`, und die Kolonie steht in der Szene vor
## dem Kegel - sein additives Leuchten legte sich also ueber das Tier und
## wusch es weg. Im Bild war vom Waechter der Kranz seiner Wurzeln zu sehen
## und sonst nichts. Ein Tier, aus dem das Licht kommt, gehoert vor das Licht.
##
## Er ist die Figur, auf die der Spieler die ganze Zeit sieht.
##
## **Und er sah aus wie eine Lampe.** Der Umriss war eine Vase: unten breit,
## in der Mitte eingezogen, oben ein Hals mit einer leuchtenden Kugel darauf.
## Genau das ist die Silhouette einer Tischlampe, und daran aendert keine
## Farbe und keine Rippe etwas - eine Form liest man am Umriss, und der war
## Geraet, nicht Tier.
##
## Der Umriss macht jetzt das Gegenteil: **breit und flach statt schmal und
## hoch**, und aus dem Rand steigt ein Kranz aus acht Armen, die sich nach
## aussen rollen und in der Stroemung stehen. Das Organ sitzt nicht mehr
## obenauf, sondern **zwischen** den Armen, tiefer und kleiner - es wird
## getragen, statt aufgesetzt zu sein. Arme, die sich bewegen, sind das
## Einzige, was aus einer Form ein Tier macht; alles andere ist Verzierung.
##
## Kein Gesicht und keine Gliedmassen im Sinne von Beinen: er soll ein Teil
## der Kolonie sein, kein Maskottchen.

## Links und rechts - als Konstante, weil ein Feldliteral in einer
## for-Schleife seinen Typ verliert.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]

var zeit := 0.0

## --- Womit er antwortet ---
##
## Ein Tier, das auf nichts reagiert, ist eine Kulisse. Zwei Regungen genuegen,
## und beide haengen an etwas, das der Spieler ohnehin verfolgt: er zuckt,
## wenn die Brut getroffen wird, und sein Organ flammt auf, wenn er etwas
## erlegt. Mehr waere Zappeln.

## Sekunden Restzucken, und wie tief. Er zieht sich zusammen und faehrt
## langsamer wieder aus, als er eingefahren ist - genau darin liegt der
## Unterschied zwischen erschrecken und wackeln.
var _zucken := 0.0
const ZUCK_DAUER := 0.55

## Restglut eines Abschusses. Kurz und hell.
var _glut := 0.0
const GLUT_DAUER := 0.30


## Die Brut ist getroffen worden. `wucht` ist die Zahl der verlorenen Eier.
func zucke(wucht: int) -> void:
    _zucken = ZUCK_DAUER * clampf(0.6 + 0.2 * float(wucht), 0.6, 1.4)


## Ein Raeuber ist gefallen. Das Organ flammt auf.
func feuer() -> void:
    _glut = GLUT_DAUER

## Der Kegel, um am Tier ablesen zu koennen, wie hell es gerade brennt.
## Gesetzt von `wache.gd`.
var kegel: Node2D = null


## Groesser gezeichnet, aber **um seinen eigenen Ort herum**: der Knoten wird
## skaliert und zugleich so verschoben, dass `Graben.WAECHTER` auf sich selbst
## abbildet. Nur die Skalierung zu setzen haette ihn quer durch das Bild
## geschoben.
## Wie weit der Ring des Stosslichts gerade draussen ist, oder -1. `wache.gd`
## setzt es; gezeichnet wird es hier, weil der Stoss vom Waechter ausgeht und
## nicht vom Bedienbild.
var stoss_weit := -1.0


func _ready() -> void:
    var g := Graben.WAECHTER_GROESSE
    scale = Vector2.ONE * g
    position = Graben.WAECHTER * (1.0 - g)


func _process(delta: float) -> void:
    zeit += delta
    _zucken = maxf(0.0, _zucken - delta)
    _glut = maxf(0.0, _glut - delta)
    queue_redraw()


## Wie stark er gerade zusammengezogen ist: schnell hinein, langsam heraus.
func _einzug() -> float:
    if _zucken <= 0.0:
        return 0.0
    var t := _zucken / ZUCK_DAUER
    # Die erste Fuenftel der Zeit faehrt er ein, den Rest wieder aus.
    return t if t > 0.8 else pow(t / 0.8, 1.6)


## Der Waechter.
##
## **Er ist die Figur, auf die der Spieler die ganze Zeit sieht, und er war
## sechs Punkte gross.** Ein Sechseck, fuenf Stummel, drei Adern, ein Kreis
## obenauf - aus zwei Metern Abstand ein Fleck. Wenn irgendetwas im Bild
## Aufwand verdient, dann das Tier, dessen Licht man fuehrt.
##
## Gebaut ist er jetzt aus fuenf Lagen, von hinten nach vorn: Wurzeln, die ihn
## im Kalk halten; Kiemenfaecher, die atmen; der geriefte Leib; das
## Adernetz, das zum Organ laeuft; und das Leuchtorgan selbst mit seinem Kranz.
## Kein Gesicht und keine Gliedmassen - er soll ein Teil der Kolonie sein,
## kein Maskottchen.
func _draw() -> void:
    var p := Graben.WAECHTER
    var puls := 0.5 + 0.5 * sin(zeit * 1.1)
    var atem := 0.5 + 0.5 * sin(zeit * 0.7 + 1.2)

    # Wie hell das Organ gerade brennt. Wer den Kegel weit aufreisst, sieht es
    # dem Tier an - die Anzeige ist das Tier selbst.
    var brennt := 0.0
    if kegel != null:
        brennt = clampf(kegel.schein, 0.0, 1.0)

    # Zusammengezogen sinkt er in seinen Wulst und wird breiter - dasselbe,
    # was eine Seeanemone tut, wenn man sie anfasst. Nur nach unten zu
    # verschieben sieht aus, als raege jemand am Bild.
    var einzug := _einzug()
    var p_zuck := p + Vector2(0.0, 9.0 * einzug)
    var brennt_gesamt := clampf(brennt + _glut / GLUT_DAUER, 0.0, 1.6)

    _wurzeln(p)
    # Die hinteren Arme zuerst, dann der Leib, dann die vorderen: so steht
    # der Kranz **um** das Tier und nicht davor. Ohne diese Teilung liegt
    # entweder der ganze Kranz vor dem Leib (dann ist es ein Gitter) oder
    # ganz dahinter (dann sieht man ihn nicht).
    _arme(p_zuck, atem, brennt_gesamt, einzug, false)
    _kragen(p_zuck, atem * (1.0 - 0.7 * einzug))
    _leib(p_zuck, brennt_gesamt, einzug)
    _adern(p_zuck, brennt_gesamt)
    _organ(p_zuck, puls, brennt_gesamt)
    _arme(p_zuck, atem, brennt_gesamt, einzug, true)
    _stossring(p)


## Der Ring des Stosslichts: eine Front, die nach aussen laeuft.
##
## Drei Boegen dicht hintereinander statt eines dicken - eine Druckwelle hat
## eine Vorderkante und einen Schweif, und genau daran erkennt man, in welche
## Richtung sie laeuft. Ein einzelner Kreis waere ein Reifen.
func _stossring(p: Vector2) -> void:
    if stoss_weit < 0.0:
        return
    # In lokalen Koordinaten: der Knoten ist skaliert, der Radius kommt aber
    # aus der Welt. Ohne das Teilen laeuft der Ring um den Massstab zu schnell.
    var g := maxf(0.001, Graben.WAECHTER_GROESSE)
    var r := stoss_weit / g
    for i in 3:
        var weit := r - float(i) * 16.0 / g
        if weit <= 0.0:
            continue
        var a := (0.42 - float(i) * 0.12) * clampf(1.0 - r / 900.0, 0.0, 1.0)
        draw_arc(p, weit, 0.0, TAU, 64, Color(0.74, 0.98, 1.0, a),
            3.4 - float(i) * 0.9, true)


## Wurzeln: was ihn im Kalkwulst haelt. Sie liegen hinter allem anderen und
## bewegen sich kaum - was festgewachsen ist, schwingt nicht.
func _wurzeln(p: Vector2) -> void:
    # **Kurz und breit, nicht lang und schmal.**
    #
    # Der erste Entwurf liess sie gerade nach unten laufen. Mit dem groesseren
    # Massstab reichten sie damit ueber die Eierreihe hinweg - der Waechter
    # stand in seiner eigenen Brut. Ein Haftfuss greift ohnehin zur Seite:
    # nach unten haelt ihn nichts, zur Seite der ganze Wulst.
    for i in 7:
        var s := lerpf(-1.0, 1.0, float(i) / 6.0)
        var wurzel := p + Vector2(s * 26.0, 46.0)
        var linie := PackedVector2Array([wurzel])
        var punkt := wurzel
        for g in 2:
            var quer := s * (6.0 + float(g) * 4.0) + sin(zeit * 0.5 + float(i)) * 1.0
            punkt += Vector2(quer, 4.5 - float(g) * 1.4)
            linie.append(punkt)
        draw_polyline(linie, Color(0.11, 0.26, 0.30, 0.85 - 0.25 * absf(s)),
            3.4 - 1.3 * absf(s), true)


## --- Die Arme ---
##
## Acht je Seite, aus dem Rand des Mantels. Sie sind der Grund, warum der
## Waechter jetzt als Tier gelesen wird: eine Form mit ruhigem Umriss ist ein
## Gegenstand, eine Form mit Fortsaetzen, die sich langsam bewegen, ist
## lebendig. Nichts anderes an ihm musste sich dafuer aendern.
##
## Sie rollen sich nach aussen ein - jeder Arm ist eine Kurve, die flacher
## wird, je weiter sie laeuft. Gerade Arme sind Speichen; eingerollte sind
## Fangarme.
##
## `vorn` teilt den Kranz: die geraden Nummern liegen hinter dem Leib, die
## ungeraden davor. Damit steht der Kranz **um** das Tier herum, und der
## Leib hat vorn wie hinten eine Kante, an der etwas verschwindet.
const ARME_JE_SEITE := 5


func _arme(p: Vector2, atem: float, brennt: float, einzug: float,
        vorn: bool) -> void:
    for seite: float in SEITEN:
        for i in ARME_JE_SEITE:
            if (i % 2 == 1) != vorn:
                continue
            var t := float(i) / float(ARME_JE_SEITE - 1)
            # **Ansatz und Winkel muessen zusammenlaufen.**
            #
            # Der innerste Arm sitzt oben an der Oeffnung und steht steil
            # nach oben; der aeusserste sitzt unten an der Flanke und legt
            # sich flach nach aussen. Andersherum - steiler Winkel unten,
            # flacher oben - kreuzen sich alle Arme auf halber Hoehe, und im
            # Bild stand links und rechts je ein Lenkergriff. Ein Kranz
            # oeffnet sich, er buendelt nicht.
            var ansatz_t := lerpf(1.0, 0.42, t)
            var wurzel := p + Vector2(seite * _halbbreite(ansatz_t) * 0.86,
                _hoehe(ansatz_t))
            # Innen steil, aussen flach - so entsteht ein Faecher und keine
            # Garbe. Die Welle laesst ihn in der Stroemung stehen.
            var welle := sin(zeit * 0.8 + float(i) * 0.9 + seite * 1.3)
            var start := lerpf(0.26, 1.02, t) + 0.09 * welle
            # Wie stark er sich beim Auslaufen nach aussen rollt.
            var rolle := lerpf(0.55, 1.15, t)
            var laenge := lerpf(72.0, 42.0, t) * (1.0 - 0.30 * einzug)

            var glieder := 8
            var schritt := laenge / float(glieder)
            var punkt := wurzel
            var linie := PackedVector2Array([punkt])
            for g in range(1, glieder + 1):
                var u := float(g) / float(glieder)
                var w := start + rolle * pow(u, 1.4) + 0.10 * welle * u
                punkt += Vector2(seite * sin(w), -cos(w)) * schritt
                linie.append(punkt)

            # Von der Wurzel zur Spitze duenner und blasser. Ein Arm mit
            # gleichbleibender Staerke ist ein Draht.
            for g in glieder:
                var u := float(g) / float(glieder)
                draw_line(linie[g], linie[g + 1],
                    Color(0.30, 0.66, 0.74, (0.52 - 0.30 * u) + 0.12 * brennt),
                    lerpf(6.2, 1.2, u))

            # Die Spitze traegt ein Photophor. Das sitzt in der Tiefsee an so
            # einem Arm, und es ist zugleich das, was den Kranz im Dunkeln
            # ueberhaupt erkennbar macht.
            var spitze: Vector2 = linie[linie.size() - 1]
            var glimm := 0.40 + 0.28 * (0.5 + 0.5 * welle) + 0.30 * brennt
            draw_circle(spitze, 5.0, Color(0.34, 0.78, 0.86, 0.14 * glimm))
            draw_circle(spitze, 2.1, Color(0.72, 0.98, 1.0, glimm))


## Der Kragen: kurze Fransen, wo die Arme aus dem Mantel treten. Sie sind das
## Bindeglied - ohne sie sitzen die Arme auf der Kante wie angeklebt.
func _kragen(p: Vector2, atem: float) -> void:
    for seite: float in SEITEN:
        for i in 6:
            var t := float(i) / 5.0
            var ansatz := lerpf(0.16, 0.58, t)
            var wurzel := p + Vector2(seite * _halbbreite(ansatz) * 0.98,
                _hoehe(ansatz))
            var laenge := lerpf(13.0, 7.0, t) * (0.82 + 0.18 * atem)
            var w := seite * lerpf(0.9, 0.3, t)
            var spitze := wurzel + Vector2(sin(w), cos(w) * 0.5) * laenge
            draw_line(wurzel, spitze, Color(0.20, 0.46, 0.52, 0.48), 2.2)


## Der Leib.
##
## **Zwei Anlaeufe, und beide gingen an derselben Sache vorbei.** Zuerst war er
## hell - dann las er sich als Glaskoerper, weil er heller stand als das
## Wasser dahinter. Also dunkel, mit Rippen darauf - dann las er sich als
## Drahtgeruest, weil bei so wenig Kontrast nur die Linien uebrigblieben und
## die Flaeche dazwischen verschwand.
##
## Was fehlte, war das Dazwischen: ein Koerper hat einen **Rand** und ein
## **Inneres**, und beides muss sichtbar sein. Der Rand ist jetzt ein
## schmaler heller Saum an der zur Mitte gewandten Kante - dieselbe
## Lichtrichtung wie am Fels. Das Innere ist ein weicher Schein, der vom Organ
## nach unten in den Leib faellt und ihn von innen fuellt. Rippen gibt es
## nur noch drei, kurz und oben, wo der Koerper sich verjuengt.
func _leib(p: Vector2, brennt: float, einzug: float) -> void:
    # **Die Kontur kommt aus einer Kurve, nicht aus neun Ecken.**
    #
    # Mit neun gesetzten Punkten wurde daraus ein Trapez - in der Lupe ein
    # Lampenschirm. Ein Koerper hat keine geraden Flanken: er ist unten breit,
    # zieht sich in der Mitte leicht ein und laeuft oben in den Hals aus, der
    # das Organ traegt. Dazu eine flache Welle auf dem Profil, damit die
    # beiden Seiten nicht spiegelgleich sind.
    #
    # **Und er ist gefuellt, nicht nur umrandet.** Hier stand eine einzige
    # fast schwarze Flaeche mit der Begruendung, ein Koerper vor einer Lampe
    # sei eine Silhouette. Das stimmt - nur steht der Waechter an der *Spitze*
    # des Kegels, und dort ist der Kegel schmal und das Wasser dunkel. Der
    # Leib lag damit bei 0.026/0.058/0.074 vor einem Wasser von etwa
    # 0.030/0.090/0.110: ein Unterschied im Hundertstel. Sichtbar blieb
    # allein der helle Saum, und der Waechter war zum dritten Mal ein
    # Drahtgestell - zwei blaue Boegen mit einer Lampe darueber.
    #
    # Ein Koerper, in dem das Licht entsteht, leuchtet **von innen**: oben am
    # Organ hell, zum Fuss hin aus. Drei ineinanderliegende Fassungen mit je
    # eigener Farbe je Eckpunkt geben genau das, und sie kosten drei
    # Zeichenaufrufe.
    var aussen := PackedVector2Array()
    var hoehen := PackedFloat32Array()
    _umriss(p, 1.0, 0.0, einzug, aussen, hoehen)

    # **Eine Flaeche mit Verlauf, keine drei gestapelten.**
    #
    # Der erste Anlauf legte drei geschrumpfte Fassungen ineinander, jede
    # etwas heller. Das gab dem Leib zwar Volumen, aber jede Fassung brachte
    # ihre eigene Kante mit: in der Lupe standen drei Trapeze im Koerper.
    # Dasselbe Ergebnis ohne Naht gibt es fuer einen Zeichenaufruf, wenn die
    # Farbe am Eckpunkt haengt statt an der Fassung - `ih[k]` ist 0 am Fuss
    # und 1 am Hals, und genau von oben kommt das Licht.
    #
    # **Und der Fuss darf nicht schwarz sein.** Mit `pow(h, 1.5)` und einem
    # Grundwert von 0.018 lag die untere Haelfte des Leibes praktisch bei
    # null: im Bild eine schwarze Glocke mit zwei blauen Boegen daran. Ein
    # Koerper, in dem Licht entsteht, ist unten gedaempft, nicht aus. Der
    # Grundwert liegt jetzt ueber dem des Wassers, und der Verlauf steigt
    # frueher an.
    var farben := PackedColorArray()
    for k in aussen.size():
        # **Deutlich dunkler als vorher.** Der Verlauf lief bis
        # 0.26/0.62/0.72 - bei einem flachen, breiten Mantel liegt der obere
        # Wert nicht mehr auf einem schmalen Hals, sondern auf der halben
        # Flaeche. Im Bild war das eine leuchtende Glaskugel, und damit war
        # die Lampe nur runder geworden.
        #
        # Der Mantel ist jetzt Koerper: knapp ueber dem Wasser, mit einem
        # Schein, der erst dicht an der Oeffnung ansteigt. Das Helle im Bild
        # ist das Organ - genau eines, und nicht das Tier.
        var hell := pow(hoehen[k], 1.6)
        farben.append(Color(
            lerpf(0.042, 0.14, hell),
            lerpf(0.112, 0.36, hell) + 0.08 * brennt * hell,
            lerpf(0.146, 0.43, hell) + 0.08 * brennt * hell))
    draw_polygon(aussen, farben)

    # Drei kurze Rippen oben, wo der Koerper sich verjuengt. Ihre Breite kommt
    # aus derselben Kurve wie die Kontur - sonst stehen sie darueber hinaus.
    for i in 3:
        var t := lerpf(0.62, 0.84, float(i) / 2.0)
        var halb := _halbbreite(t) * 0.72
        var y := _hoehe(t)
        var bogen := PackedVector2Array()
        for k in 5:
            var u := lerpf(-1.0, 1.0, float(k) / 4.0)
            bogen.append(p + Vector2(u * halb, y - (1.0 - u * u) * 2.6))
        draw_polyline(bogen, Color(0.44, 0.80, 0.88, 0.22), 1.1, true)

    # **Der Saum liegt nur oben.**
    #
    # Er lief einmal um den ganzen Umriss - und ein heller Strich rings um
    # eine gewoelbte Form ist eine Kugel, ganz gleich, wie dunkel sie
    # innen ist. Genau daran las sich der Mantel als Glasball. Licht faellt
    # aus dem Organ nach oben und aussen; unten steckt der Waechter im Kalk,
    # und dort hat er keine Kante.
    var saum := PackedVector2Array()
    for k in aussen.size():
        if hoehen[k] > 0.42:
            saum.append(aussen[k])
    if saum.size() > 1:
        draw_polyline(saum, Color(0.40, 0.78, 0.88, 0.40 + 0.22 * brennt), 2.0, true)


## Der Umriss des Leibes, als Vieleck und mit der Hoehenlage je Eckpunkt.
##
## Zwei Ausgaben, weil die Farbe eines Eckpunktes davon abhaengt, wie weit
## oben er sitzt - und diese Zahl steht nur hier zur Verfuegung. Sie
## nachtraeglich aus der y-Lage zurueckzurechnen ginge auch, waere aber eine
## zweite Beschreibung derselben Kurve.
##
## `schmaler` zieht die Flanken zur Achse, `hoch` schiebt den Fuss nach oben -
## zusammen ergibt das eine kleinere Fassung, die innerhalb der aeusseren
## bleibt, ohne dass man sie um einen Schwerpunkt skalieren muss.
func _umriss(p: Vector2, schmaler: float, hoch: float, einzug: float,
        aus: PackedVector2Array, hoehen: PackedFloat32Array) -> void:
    var stufen := 26
    for seite: float in SEITEN:
        for i in stufen + 1:
            # Linke Seite von unten nach oben, rechte von oben nach unten -
            # sonst laeuft das Vieleck ueber Kreuz.
            var t := float(i) / float(stufen)
            if seite > 0.0:
                t = 1.0 - t
            var u := lerpf(hoch, 1.0, t)
            # Beim Zusammenziehen staucht er sich der Hoehe nach und quillt
            # dabei in die Breite - was Volumen behaelt, wird beim Stauchen
            # dicker. Ohne das schrumpft er einfach, und das sieht nach einem
            # Fehler in der Skalierung aus.
            aus.append(p + Vector2(
                seite * _halbbreite(u) * schmaler * (1.0 + 0.16 * einzug),
                _hoehe(u) * (1.0 - 0.24 * einzug)))
            hoehen.append(u)


## Das Profil des Leibes. `t` laeuft von 0 am Fuss bis 1 am Hals.
##
## Zwei Funktionen statt einer Punkteliste, weil ausser der Kontur noch drei
## andere Dinge daran haengen - Rippen, Kiemen und der Ansatz des Organs. Eine
## Liste haette jede davon zum Nachmessen gezwungen.
func _halbbreite(t: float) -> float:
    # Unten breit, in der Mitte leicht eingezogen, oben ein schmaler Hals.
    # Die Welle darauf ist flach und ungerade getaktet, damit keine der
    # beiden Flanken der anderen gleicht.
    # **Breit und flach, nicht schmal und hoch.**
    #
    # Hier stand `lerpf(34.0, 15.0, ...)` mit einer Einschnuerung in der
    # Mitte: unten breit, Taille, Hals. Das ist die Kontur einer Vase, und
    # eine Vase mit einer Leuchte obendrauf ist eine Lampe. Der breiteste
    # Punkt liegt jetzt im unteren Drittel und die Flanke faellt von dort
    # gleichmaessig ab - so waelbt sich ein Mantel, und so waelbt sich keine
    # Vase.
    var grund := lerpf(44.0, 30.0, t) + 11.0 * sin(t * PI)
    return maxf(6.0, grund + 1.8 * sin(t * 7.3 + 0.9))


## **Der Fuss reicht unter die Eier.**
##
## Er endete bei 50, und die Deckplatte des Sockels liegt genau dort - die
## waagerechte Unterkante des Leibes stand damit als schwarzer Strich
## unmittelbar ueber dem Gelege. Ein Tier, das in etwas steckt, hat dort
## keine Kante: es verschwindet darin. Also ein Stueck tiefer, hinter die
## vordere Eierreihe.
func _hoehe(t: float) -> float:
    # Flacher als vorher (90 Einheiten hoch, jetzt 68). Was an Hoehe fehlt,
    # tragen die Arme - und die tragen sie als Bewegung statt als Masse.
    return lerpf(48.0, 4.0, t)


## Das Adernetz: von den Wurzeln zum Organ, mit Verzweigungen. Es pulst
## versetzt und wird heller, wenn das Organ brennt - der Koerper laedt dann
## sichtbar nach.
func _adern(p: Vector2, brennt: float) -> void:
    # **Duenn, blass und wenige.** In der Lupe waren fuenf helle Adern von
    # voller Koerperhoehe das Einzige, was man vom Waechter sah - kein
    # Adernetz, sondern ein Vogelkaefig. Adern liegen im Fleisch; man ahnt
    # sie, man liest sie nicht.
    for i in 3:
        var s := lerpf(-11.0, 11.0, float(i) / 2.0)
        var ader := PackedVector2Array([
            p + Vector2(s * 1.7, 42.0),
            p + Vector2(s * 1.4, 24.0),
            p + Vector2(s * 0.9, 8.0),
            p + Vector2(s * 0.4, -4.0),
        ])
        var glut := 0.5 + 0.5 * sin(zeit * 1.6 - float(i) * 0.8)
        draw_polyline(ader, Color(0.42, 0.86, 0.94,
            0.07 + 0.07 * glut + 0.10 * brennt), 1.2, true)


## Das Leuchtorgan.
##
## **Es sass obenauf, und das war der zweite Grund fuer die Lampe.** Ein
## Leuchtkoerper am oberen Ende eines Halses ist eine Gluehbirne, ganz gleich,
## woraus er besteht. Jetzt sitzt es tief im Mantel, dort, wo die Arme
## zusammenlaufen: nicht aufgesetzt, sondern **umschlossen**. Der Kranz aus
## Kapseln liegt flach darum herum wie die Perlen in einem Schlund, und was
## nach oben steht, sind die Arme.
##
## Alles daran wird groesser, wenn der Kegel brennt - es ist die Quelle des
## Lichts, und das soll man sehen, auch wenn der Blick oben am Bildrand haengt.
func _organ(p: Vector2, puls: float, brennt: float) -> void:
    var kopf := p + Vector2(0.0, 8.0)

    # **Ein Kranz aus Blasen, keine dreizehn Striche.** Was ein Leuchtorgan
    # der Tiefsee ausmacht, sind Kapseln: runde, halbdurchsichtige Koerper,
    # die einander ueberlappen und jeweils einen harten Kern haben. Sie
    # tragen zugleich die Rueckmeldung - wenn der Waechter feuert, treten sie
    # auseinander und werden groesser.
    #
    # Der Kranz liegt jetzt **flach** (0.44 statt 0.86 in der Hoehe): er
    # umschliesst den Kern in der Aufsicht, statt als Bogen darueber zu
    # stehen. Ein Bogen ueber einem Punkt ist ein Schirm.
    for i in 13:
        var w := TAU * float(i) / 13.0
        var weit := (17.0 + 3.5 * sin(zeit * 0.9 + float(i) * 1.7)) \
            * (1.0 + 0.28 * brennt)
        var mitte := kopf + Vector2(cos(w) * weit, sin(w) * weit * 0.44)
        # Ungleiche Groessen, sonst ist es eine Perlenkette.
        var r := 2.6 + 2.4 * absf(sin(float(i) * 2.3 + 0.6)) + 1.0 * brennt
        draw_circle(mitte, r * 2.0, Color(0.34, 0.80, 0.94, 0.08 + 0.09 * brennt))
        draw_circle(mitte, r, Color(0.50, 0.90, 0.98, 0.18 + 0.16 * brennt))
        draw_circle(mitte, r * 0.42, Color(0.86, 1.0, 1.0, 0.50 + 0.35 * brennt))

    # Der Kern. Kleiner als vorher - er soll die hellste Stelle des Bildes
    # sein, aber nicht die groesste.
    draw_circle(kopf, 19.0 + puls * 3.0 + 8.0 * brennt, Color(0.40, 0.86, 0.98, 0.06))
    draw_circle(kopf, 14.0 + puls * 2.5 + 5.0 * brennt, Color(0.44, 0.88, 0.98, 0.12))
    draw_circle(kopf, 7.5 + puls * 1.4, Color(0.70, 0.98, 1.0, 0.85))
    draw_circle(kopf, 3.6, Color(1.0, 1.0, 0.98, 0.95))
