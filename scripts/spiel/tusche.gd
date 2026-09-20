class_name Tusche
extends RefCounted

## **Der Pinsel - und er sammelt.**
##
## Alles in diesem Spiel ist aus einer einzigen Form gebaut: einem Strich,
## der aufsetzt, traegt und abhebt. Das ist kein Schmuck, sondern der ganze
## Stil - eine Tuschezeichnung hat keine Umrisse und keine Fuellungen, sie
## hat **Striche verschiedener Breite**, und die Form entsteht aus ihrer
## Anordnung.
##
## Drei Regeln, die fuer jede neue Zeichnung hier gelten:
##
##   * **Kein Strich hat zwei gleiche Enden.** Ein Band gleicher Breite ist
##     ein Klebestreifen; ein Pinsel setzt auf und hebt ab.
##   * **Kein Strich ist gleichmaessig dunkel.** Tusche laeuft satt an und
##     trocknet aus.
##   * **Eine Kante ist nie hart** - nicht wegen der Glaettung, sondern weil
##     ein Haarpinsel keine hat.
##
## **Warum das hier ein Sammler ist und keine Sammlung freier Funktionen.**
## Ein Fechter besteht aus neun Strichen, ein Hintergrund aus hundertvierzig.
## Jeder Strich einzeln gezeichnet ist ein Zeichenaufruf, und ein
## Handy-Grafikchip will unter tausend fuer das ganze Bild - hundertvierzig
## allein fuer Papierfasern waeren ein Zehntel des Budgets fuer etwas, das
## man kaum sieht. Gesammelt wird alles in **ein** Dreiecksnetz und mit
## **einem** `canvas_item_add_triangle_array` abgesetzt: eine Figur, ein
## Aufruf. Das ist keine vorgezogene Optimierung, sondern die Form, in der
## dieses Bild ueberhaupt bezahlbar ist.

## Wie viele Laengsreihen ein Strich hat.
##
## **Sieben, und die beiden aeusseren tragen den Umriss.** Vorher waren es
## fuenf mit Deckung `[0, 0.92, 1, 0.92, 0]` - aussen durchsichtig, die Form
## eines Haarpinsels. Das war richtig, solange alles dieselbe schwarze Tusche
## war; farbige Figuren brauchen eine Kante, sonst verlaufen achtzig davon
## ineinander.
##
## **Die Kante kostet keinen zweiten Durchgang.** Der naheliegende Weg waere,
## jede Figur zweimal zu zeichnen - fett und dunkel, dann schmal und farbig -
## und das verdoppelt die Eckpunkte. Hier faerbt der Sammler ohnehin je
## Eckpunkt: die aeusseren Reihen bekommen einfach den Umriss statt der
## Koerperfarbe. Sieben statt fuenf Reihen heisst Faktor **1,4** statt 2,0,
## und die Kante folgt dem Strich von allein - auch um Kurven und an den
## Enden, wo ein zweiter Durchgang immer danebenliegt.
## **Ein Umriss braucht zwei Dinge, und der erste Anlauf gab ihm nur eines.**
##
## Erster Versuch: Kantenreihen auf 0,88 und Koerper ab 0,62 - dazwischen lief
## die Farbe ueber ein Viertel der Breite von Umriss nach Koerper, und das war
## kein Umriss, sondern ein Verlauf. Zweiter Versuch, korrigiert in die
## falsche Richtung: 0,78 und 0,74. Jetzt war der Uebergang scharf, aber das
## **deckende** Kantenband nur vier Hundertstel breit - bei einem Glied von
## zwanzig Bildpunkten ein halbes Pixel. Auf dem Schuss war wieder nichts zu
## sehen.
##
## Beides zugleich: das Kantenband laeuft von 0,72 bis 0,96 (also ein Viertel
## der halben Breite, **deckend**), springt bei 0,72 auf die Koerperfarbe, und
## ganz aussen liegt eine durchsichtige Reihe als weiche Aussenkante - die
## bekommt dieser Renderer ohne MSAA nicht anders.
##
## Neun Reihen statt fuenf: Faktor 1,8 auf die Eckpunkte. Was `DICHT_AB`
## davon vertraegt, wird gemessen und nicht geraten.
const REIHEN: PackedFloat32Array = [
    -1.0, -0.96, -0.72, -0.68, 0.0, 0.68, 0.72, 0.96, 1.0,
]
const REIHEN_DECKUNG: PackedFloat32Array = [
    0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0,
]
## Welche Reihen den Umriss tragen statt der Koerperfarbe.
const REIHEN_KANTE: PackedInt32Array = [1, 1, 1, 0, 0, 0, 1, 1, 1]

var _punkte := PackedVector2Array()
var _farben := PackedColorArray()
var _index := PackedInt32Array()


func loesche() -> void:
    _punkte.clear()
    _farben.clear()
    _index.clear()


## Wie viele Eckpunkte gerade im Netz liegen. Fuer den Messstand, der das
## Eckpunkt-Budget prueft - geraten wird es nicht.
func ecken() -> int:
    return _punkte.size()


func leer() -> bool:
    return _index.is_empty()


## Alles Gesammelte in einem Aufruf absetzen.
func spuele(ci: RID) -> void:
    if _index.is_empty():
        return
    RenderingServer.canvas_item_add_triangle_array(ci, _index, _punkte, _farben)
    loesche()


## **Der Grundstrich.** `mitte` ist der Weg, `halb` die halbe Breite je
## Stuetzstelle, `deckung` die Saettigung je Stuetzstelle.
## `kante` ist die Farbe der beiden aeusseren Reihen. Wird sie weggelassen,
## laufen alle sieben Reihen in `farbe` - das ist der alte, weiche Pinsel,
## und den brauchen Boden, Schraffur und Balken weiterhin. Eine Figur bekommt
## eine Kante, ein Grashalm nicht.
func band(mitte: PackedVector2Array, halb: PackedFloat32Array,
        farbe: Color, deckung: PackedFloat32Array,
        kante := Color(0, 0, 0, 0)) -> void:
    var n := mitte.size()
    if n < 2:
        return
    var basis := _punkte.size()
    var breit := REIHEN.size()
    var mit_kante := kante.a > 0.0

    for i in n:
        # Die Normale aus der lokalen Laufrichtung. An den Enden zaehlt das
        # einzige vorhandene Stueck - sonst kippt der letzte Querschnitt.
        var vor: Vector2 = mitte[mini(i + 1, n - 1)]
        var zurueck: Vector2 = mitte[maxi(i - 1, 0)]
        var lauf := vor - zurueck
        if lauf.length_squared() < 0.000001:
            lauf = Vector2.RIGHT
        var quer := lauf.normalized().orthogonal()
        var h: float = halb[mini(i, halb.size() - 1)]
        # **Eine leere Deckungsliste heisst voll deckend, nicht unsichtbar.**
        # Vorher stand hier `deckung[mini(i, deckung.size() - 1)]`, und bei
        # leerer Liste ist das `deckung[-1]`: der Zugriff geht daneben, `d`
        # wird null, und die Figur wird mit Deckung null in das Netz
        # geschrieben - gerechnet, gezeichnet, im Bild nicht vorhanden. Der
        # Druckring lief so eine Runde lang durch alle Messungen (in 66 % der
        # Bilder gesetzt) und war auf keinem Schuss zu sehen.
        var d := 1.0
        if not deckung.is_empty():
            d = deckung[mini(i, deckung.size() - 1)]
        for r in breit:
            _punkte.append(mitte[i] + quer * (h * REIHEN[r]))
            var c := farbe
            if mit_kante and REIHEN_KANTE[r] != 0:
                c = kante
            _farben.append(Color(c.r, c.g, c.b,
                c.a * d * REIHEN_DECKUNG[r]))

    for i in n - 1:
        for r in breit - 1:
            var a := basis + i * breit + r
            var b := a + 1
            var c := a + breit
            var e := c + 1
            _index.append(a); _index.append(c); _index.append(b)
            _index.append(b); _index.append(c); _index.append(e)


## **Ein Zug von A nach B**, mit Anschwellen und Auslaufen.
##
## `druck` sagt, wo der Pinsel am staerksten aufliegt (0 = Anfang, 1 = Ende).
## `trocken` reisst die Deckung zum Ende hin auf - der Schleppstrich, der
## einer Klinge ihre Richtung gibt.
func zug(a: Vector2, b: Vector2, breite: float, farbe: Color,
        druck := 0.35, trocken := 0.0, bogen := 0.0, stuecke := 8,
        kante := Color(0, 0, 0, 0)) -> void:
    if a.distance_squared_to(b) < 0.0001:
        return
    var mitte := PackedVector2Array()
    var halb := PackedFloat32Array()
    var deck := PackedFloat32Array()
    var quer := (b - a).orthogonal().normalized()
    for i in stuecke:
        var t := float(i) / float(stuecke - 1)
        # Ein gerader Strich ist eine Konstruktionszeichnung. Jeder Zug
        # traegt deshalb einen Bogen, und sei er winzig.
        mitte.append(a.lerp(b, t) + quer * (bogen * sin(t * PI)))
        var spanne: float = druck if t < druck else 1.0 - druck
        var f := clampf(1.0 - absf(t - druck) / maxf(0.08, spanne), 0.0, 1.0)
        halb.append(breite * 0.5 * (0.16 + 0.84 * pow(f, 0.6)))
        deck.append(clampf(1.0 - trocken * pow(t, 2.2), 0.0, 1.0))
    band(mitte, halb, farbe, deck, kante)


## **Ein Strang** - ein Glied, ein Rumpf, alles, was durch mehrere Punkte
## laeuft und dabei die Breite wechselt.
##
## Der erste Anlauf setzte ein Bein aus **zwei** Zuegen zusammen, Schenkel
## und Schienbein. Im Bild hatte es am Knie eine Kerbe: der eine Zug lief
## dort auf seine Spitze aus, der andere setzte mit voller Breite an, und
## zwischen beiden stand eine Einschnuerung, die kein Koerper hat. Zwei
## gebogene Arme nebeneinander ergaben aus demselben Grund einen **Reifen**
## statt zweier Arme.
##
## Ein Glied ist deshalb **ein** Strang: eine Kurve durch die Stuetzstellen,
## mit einer Breite je Stuetzstelle, die dazwischen mitlaeuft. Die Regel
## dahinter gilt fuer jede neue Zeichnung hier - **wo ein Uebergang
## hingehoert, wird keine Kante gezeichnet**, und eine Kerbe ist eine Kante.
func strang(stuetzen: PackedVector2Array, breiten: PackedFloat32Array,
        farbe: Color, stuecke := 12, kante := Color(0, 0, 0, 0)) -> void:
    var n := stuetzen.size()
    if n < 2:
        return
    var mitte := PackedVector2Array()
    var halb := PackedFloat32Array()
    var deck := PackedFloat32Array()
    for i in stuecke:
        var t := float(i) / float(stuecke - 1)
        var p: Vector2
        var w: float
        if n == 2:
            p = stuetzen[0].lerp(stuetzen[1], t)
            w = lerpf(breiten[0], breiten[1], t)
        else:
            # Quadratisch durch drei Stuetzstellen: das Gelenk zieht die
            # Kurve, ohne selbst ein Punkt auf ihr sein zu muessen - genau
            # so biegt sich ein Glied.
            var a := stuetzen[0].lerp(stuetzen[1], t)
            var b := stuetzen[1].lerp(stuetzen[2], t)
            p = a.lerp(b, t)
            var wa := lerpf(breiten[0], breiten[1], t)
            var wb := lerpf(breiten[1], breiten[2], t)
            w = lerpf(wa, wb, t)
        mitte.append(p)
        halb.append(maxf(0.35, w * 0.5))
        deck.append(1.0)
    band(mitte, halb, farbe, deck, kante)
## **Ein Klecks** - ein Kopf, ein Knauf, ein Tropfen. Kein Kreis: ein Kreis
## ist gedruckt, ein Klecks ist gesetzt.
## `kante` legt einen Umriss um den Klecks: dieselbe Welle noch einmal, ein
## Stueck weiter aussen, als Ring aus Dreiecken. Als Ring und nicht als
## groesserer Klecks darunter - der waere doppelt so viele Dreiecke fuer eine
## Flaeche, die vollstaendig verdeckt wird.
func klecks(ort: Vector2, radius: float, farbe: Color, saat := 0,
        kante := Color(0, 0, 0, 0)) -> void:
    # **Die Zahl der Ecken waechst mit dem Radius.** Elf Ecken sind auf einem
    # Kopf von zwoelf Bildpunkten ein Klecks und auf einer Sonnenscheibe von
    # hundertzwanzig ein Vieleck - und ein sichtbares Vieleck ist gedruckt,
    # nicht gesetzt. Eine feste Zahl kann nur eine der beiden Groessen
    # richtig machen.
    var ecken := clampi(9 + int(radius * 0.45), 9, 44)
    if kante.a > 0.0:
        # Erst der Umriss, dann der Koerper darueber - ein Umriss ueber der
        # Figur waere ein Fleck, einer unter ihr waere keiner.
        _kranz(ort, radius, radius + maxf(1.6, radius * 0.17), kante, saat, ecken)
    var basis := _punkte.size()
    _punkte.append(ort)
    _farben.append(farbe)
    # **Die Unregelmaessigkeit laeuft ueber den Winkel, nicht je Ecke.**
    # Ein Wurf je Eckpunkt gibt bei vielen Ecken einen **Stern**: zwischen
    # zwei Nachbarn liegt der volle Sprung, und je mehr Ecken, desto mehr
    # Zacken. Ein Klecks ist aber an manchen Stellen breiter und an anderen
    # schmaler - das ist eine langsame Welle und kein Rauschen.
    var phase := float((saat * 2654435761) % 1000) * 0.006283
    for i in ecken:
        var w := TAU * float(i) / float(ecken)
        var r := radius * (1.0 + 0.085 * sin(w * 2.0 + phase)
            + 0.055 * sin(w * 3.0 - phase * 1.7))
        _punkte.append(ort + Vector2(cos(w), sin(w)) * r)
        _farben.append(farbe)
    for i in ecken:
        _index.append(basis)
        _index.append(basis + 1 + i)
        _index.append(basis + 1 + (i + 1) % ecken)


## Ein Ring zwischen zwei Radien, mit derselben Welle wie `klecks`.
func _kranz(ort: Vector2, innen: float, aussen: float, farbe: Color,
        saat: int, ecken: int) -> void:
    var basis := _punkte.size()
    var phase := float((saat * 2654435761) % 1000) * 0.006283
    for i in ecken:
        var w := TAU * float(i) / float(ecken)
        var welle := 1.0 + 0.085 * sin(w * 2.0 + phase) \
            + 0.055 * sin(w * 3.0 - phase * 1.7)
        var richtung := Vector2(cos(w), sin(w))
        _punkte.append(ort + richtung * (innen * welle))
        _farben.append(farbe)
        _punkte.append(ort + richtung * (aussen * welle))
        _farben.append(farbe)
    for i in ecken:
        var a := basis + i * 2
        var b := a + 1
        var c := basis + ((i + 1) % ecken) * 2
        var d2 := c + 1
        _index.append(a); _index.append(c); _index.append(b)
        _index.append(b); _index.append(c); _index.append(d2)


## **Schraffur** - der Unterschied zwischen Tuschemalerei und Holzschnitt.
##
## Ein Holzschnitt kennt keine Graustufen: er hat Schwarz, er hat Weiss, und
## dazwischen hat er **Striche, die man zaehlen kann**. Ein Schatten entsteht
## dort, wo sie dichter liegen.
##
## Gezeichnet wird zwischen zwei Punkten quer zur Achse, `zahl` Striche, mit
## abnehmender Laenge zu den Enden - so bekommt die Flaeche eine Form und
## wird nicht zum Gitter. Kostet nichts extra: alles landet im selben Netz.
func schraffur(a: Vector2, b: Vector2, breite: float, zahl: int,
        farbe: Color, staerke := 1.6) -> void:
    if zahl <= 0:
        return
    var achse := b - a
    if achse.length_squared() < 0.01:
        return
    var quer := achse.orthogonal().normalized()
    for i in zahl:
        var t := (float(i) + 0.5) / float(zahl)
        var mitte := a + achse * t
        # Zu den Enden hin kuerzer: eine Schraffur gleicher Laenge ist ein
        # Rechteck, und ein Rechteck ist keine Woelbung.
        var halb := breite * 0.5 * sin(t * PI)
        if halb < 0.4:
            continue
        zug(mitte - quer * halb, mitte + quer * halb, staerke, farbe,
            0.5, 0.0, 0.0, 3)


## **Ein Wisch** - die graue Lavierung, aus der Tiefe entsteht. Sehr breit,
## sehr blass: sie soll Raum andeuten und nicht als Form gelesen werden.
func wisch(a: Vector2, b: Vector2, breite: float, farbe: Color) -> void:
    zug(a, b, breite, farbe, 0.5, 0.0, breite * 0.05, 6)
