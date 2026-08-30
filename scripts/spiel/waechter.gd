extends Node2D

## Der Waechter der Schlundwache.
##
## **Eigene Datei und eigener Knoten, weil er ueber dem Kegel liegen muss.**
## Vorher zeichnete ihn `kolonie.gd`, und die Kolonie steht in der Szene vor
## dem Kegel - sein additives Leuchten legte sich also ueber das Tier und
## wusch es weg. Im Bild war vom Waechter der Kranz seiner Wurzeln zu sehen
## und sonst nichts. Ein Tier, aus dem das Licht kommt, gehoert vor das Licht.
##
## Er ist die Figur, auf die der Spieler die ganze Zeit sieht, und er war
## einmal sechs Punkte gross: ein Sechseck, fuenf Stummel, drei Adern, ein
## Kreis obenauf. Jetzt besteht er aus fuenf Lagen, von hinten nach vorn -
## Wurzeln, die ihn im Kalk halten; Kiemenfaecher, die atmen; der geriefte
## Leib; das Adernetz, das zum Organ laeuft; und das Leuchtorgan selbst.
## Kein Gesicht und keine Gliedmassen: er soll ein Teil der Kolonie sein, kein
## Maskottchen.

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
    _kiemen(p_zuck, atem * (1.0 - 0.7 * einzug))
    _leib(p_zuck, brennt_gesamt, einzug)
    _adern(p_zuck, brennt_gesamt)
    _organ(p_zuck, puls, brennt_gesamt)


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
        var wurzel := p + Vector2(s * 22.0, 40.0)
        var linie := PackedVector2Array([wurzel])
        var punkt := wurzel
        for g in 2:
            var quer := s * (6.0 + float(g) * 4.0) + sin(zeit * 0.5 + float(i)) * 1.0
            punkt += Vector2(quer, 4.5 - float(g) * 1.4)
            linie.append(punkt)
        draw_polyline(linie, Color(0.11, 0.26, 0.30, 0.85 - 0.25 * absf(s)),
            3.4 - 1.3 * absf(s), true)


## Kiemenfaecher an beiden Flanken. Sie sind das Einzige an ihm, das sich
## sichtbar bewegt, und sie tun es langsam - ein Tier, das schnell atmet,
## wirkt in Panik.
func _kiemen(p: Vector2, atem: float) -> void:
    for seite: float in SEITEN:
        for i in 5:
            var t := float(i) / 4.0
            var wurzel := p + Vector2(seite * lerpf(16.0, 27.0, t), lerpf(4.0, 34.0, t))
            var oeffnung := 0.55 + 0.45 * atem
            var laenge := lerpf(20.0, 11.0, t) * (0.82 + 0.18 * atem)
            var w := seite * lerpf(0.35, 1.05, t) * oeffnung
            var spitze := wurzel + Vector2(sin(w), -cos(w) * 0.35 + 0.55) * laenge
            draw_line(wurzel, spitze, Color(0.20, 0.46, 0.52, 0.55), 2.4)
            draw_circle(spitze, 1.5, Color(0.34, 0.70, 0.76, 0.40))


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
    # beiden Seiten nicht spiegelgleich sind. Nichts davon laesst sich mit
    # einer Handvoll Ecken sagen.
    var verschoben := PackedVector2Array()
    var stufen := 26
    for seite: float in SEITEN:
        for i in stufen + 1:
            # Linke Seite von unten nach oben, rechte von oben nach unten -
            # sonst laeuft das Vieleck ueber Kreuz.
            var t := float(i) / float(stufen)
            if seite > 0.0:
                t = 1.0 - t
            # Beim Zusammenziehen staucht er sich der Hoehe nach und quillt
            # dabei in die Breite - was Volumen behaelt, wird beim Stauchen
            # dicker. Ohne das schrumpft er einfach, und das sieht nach einem
            # Fehler in der Skalierung aus.
            verschoben.append(p + Vector2(
                seite * _halbbreite(t) * (1.0 + 0.16 * einzug),
                _hoehe(t) * (1.0 - 0.24 * einzug)))
    # **Dunkler als das Wasser dahinter, nicht gleich hell.**
    #
    # Genau hier stand der dritte Fehlversuch. Der Waechter sitzt an der
    # Spitze des Kegels, also im hellsten Fleck des ganzen Bildes - ein Leib
    # in Wasserfarbe verschwindet darin restlos, und uebrig bleiben die
    # Linien, die man daraufgezeichnet hat. Aus der Lupe sah das aus wie ein
    # Gestell aus Draehten. Ein Koerper vor einer Lampe ist eine Silhouette;
    # so muss er auch gemalt werden.
    draw_colored_polygon(verschoben, Color(0.026, 0.058, 0.074))

    # Das Innere: drei weiche Scheiben vom Organ abwaerts, immer breiter und
    # immer schwaecher. Sie bleiben ein gutes Stueck **innerhalb** der
    # Silhouette - eine, die ueber den Rand lief, machte aus dem Koerper
    # wieder eine Laterne.
    for i in 5:
        var t := lerpf(0.86, 0.10, float(i) / 4.0)
        var mitte := p + Vector2(0.0, _hoehe(t))
        draw_circle(mitte, _halbbreite(t) * 0.62,
            Color(0.34, 0.74, 0.86, (0.15 - 0.024 * float(i)) * (0.75 + 0.5 * brennt)))

    # Drei kurze Rippen oben, wo der Koerper sich verjuengt. Mehr waren es
    # sieben ueber die ganze Hoehe, und genau die machten das Geruest.
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
        draw_polyline(bogen, Color(0.30, 0.62, 0.70, 0.16), 1.1, true)

    # Der Saum um die ganze Kontur. Er ist das, was den Koerper vom Wasser
    # trennt, und darf deshalb nicht sparsam sein - der schwarze Balken, der
    # hier einmal als "Fuss" lag, sah dagegen aus wie ein Strich unter einem
    # Rechenbeispiel.
    # Der Saum laeuft **nicht** ueber den Fuss. Unten steckt der Waechter im
    # Kalk; eine helle Linie quer darunter waere ein Strich unter einem
    # Rechenbeispiel, und genau so sah sie auch aus.
    var saum := verschoben.slice(1, verschoben.size() - 1)
    draw_polyline(saum, Color(0.40, 0.78, 0.88, 0.62 + 0.28 * brennt), 2.4, true)


## Das Profil des Leibes. `t` laeuft von 0 am Fuss bis 1 am Hals.
##
## Zwei Funktionen statt einer Punkteliste, weil ausser der Kontur noch drei
## andere Dinge daran haengen - Rippen, Kiemen und der Ansatz des Organs. Eine
## Liste haette jede davon zum Nachmessen gezwungen.
func _halbbreite(t: float) -> float:
    # Unten breit, in der Mitte leicht eingezogen, oben ein schmaler Hals.
    # Die Welle darauf ist flach und ungerade getaktet, damit keine der
    # beiden Flanken der anderen gleicht.
    var grund := lerpf(34.0, 15.0, pow(t, 1.15)) \
        - 4.0 * sin(t * PI) * (1.0 - t)
    return maxf(6.0, grund + 1.8 * sin(t * 7.3 + 0.9))


func _hoehe(t: float) -> float:
    return lerpf(50.0, -26.0, t)


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
            p + Vector2(s * 1.5, 34.0),
            p + Vector2(s * 1.2, 16.0),
            p + Vector2(s * 0.75, -2.0),
            p + Vector2(s * 0.3, -15.0),
        ])
        var glut := 0.5 + 0.5 * sin(zeit * 1.6 - float(i) * 0.8)
        draw_polyline(ader, Color(0.42, 0.86, 0.94,
            0.07 + 0.07 * glut + 0.10 * brennt), 1.2, true)


## Das Leuchtorgan: Kranz, Hof, Kern. Alles daran wird groesser, wenn der
## Kegel brennt - es ist die Quelle, und das soll man sehen.
func _organ(p: Vector2, puls: float, brennt: float) -> void:
    var kopf := p + Vector2(0.0, -22.0)
    for i in 13:
        var w := lerpf(-PI * 0.92, -PI * 0.08, float(i) / 12.0)
        var laenge := (11.0 + 6.0 * sin(zeit * 1.4 + float(i) * 0.9)) \
            * (1.0 + 0.35 * brennt)
        var spitze := kopf + Vector2(cos(w), sin(w)) * laenge
        draw_line(kopf, spitze, Color(0.46, 0.88, 0.96, 0.22 + 0.20 * brennt), 1.2)
        draw_circle(spitze, 1.3 + 1.1 * brennt, Color(0.66, 0.96, 1.0, 0.30 + 0.35 * brennt))

    draw_circle(kopf, 26.0 + puls * 4.0 + 10.0 * brennt, Color(0.40, 0.86, 0.98, 0.07))
    draw_circle(kopf, 16.0 + puls * 2.5 + 5.0 * brennt, Color(0.44, 0.88, 0.98, 0.13))
    draw_circle(kopf, 9.5 + puls * 1.5, Color(0.70, 0.98, 1.0, 0.85))
    draw_circle(kopf, 4.6, Color(1.0, 1.0, 0.98, 0.95))
