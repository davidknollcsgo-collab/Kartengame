class_name Fechter
extends RefCounted

## **Die Fechter.**
##
## Jede Figur ist ein Skelett aus neun Punkten, und jeder Knochen ist ein
## Pinselstrich. Nichts hier ist ein Umriss, nichts ist gefuellt - genau
## darin besteht der Stil, und deshalb steht `Tusche` zwischen allem und der
## Leinwand.
##
## **Die Haltung traegt die Aussage, nicht die Zeichnung.** Ein Fechter im
## Ansatz muss aus zwanzig Bildpunkten Entfernung erkennbar machen, *welche*
## Linie kommt - vor jeder Fuehrungslinie, vor jeder Farbe. Wenn die Haltung
## das nicht sagt, ist die Figur falsch gebaut, und keine Zinnoberlinie
## rettet sie. Deshalb liegt zwischen den fuenf Ansaetzen jeweils der
## groesstmoegliche Abstand: Klinge ueber dem Kopf, an der rechten Schulter,
## an der linken, waagerecht hinter dem Ruecken, und die Spitze voran.
##
## Alle Punkte stehen in Anteilen der Figurhoehe, Ursprung zwischen den
## Fuessen, y nach oben negativ. Gespiegelt wird ueber `blick`; eine zweite
## Punkteliste fuer die Gegenrichtung waeren zwei Wahrheiten ueber dieselbe
## Figur.

const TINTE := Color(0.09, 0.08, 0.09)
const ZINNOBER := Color(0.78, 0.16, 0.10)
const GRAU := Color(0.44, 0.43, 0.44)

## Wie gross ein Fechter im Bild ist. Der Spieler steht naeher, also groesser
## - das ist die einzige Perspektive, die diese Buehne kennt, und sie
## genuegt.
const HOEHE_SPIELER := 300.0
const HOEHE_GEGNER := 262.0

## **Strichbreiten, in Anteilen der Hoehe - und sie sind der Unterschied
## zwischen einer Figur und einem Strichmaennchen.**
##
## Der erste Anlauf stand bei 0,115 fuer den Rumpf und 0,082 fuer ein Bein.
## Im Bild war das ein Draht mit einem Kopf darauf, und zwar unabhaengig
## davon, wie gut die Haltung stimmte: **eine sorgfaeltig gezeichnete
## Drahtfigur ist immer noch eine.** Was eine Tuschefigur traegt, ist Masse -
## das Gewand, die weite Hose, der Aermel -, und aus ihr treten Kopf, Haende
## und Klinge hervor.
##
## Die Regel dahinter, fuer jede neue Zeichnung hier: **erst die Masse, dann
## die Glieder.** Wer mit den Gliedern anfaengt, baut ein Skelett und haengt
## danach vergeblich Kleider daran.
const B_RUMPF := 0.195
const B_HOSE := 0.142
const B_ARM := 0.082
const B_KLINGE := 0.052


## Ein Satz Gelenke. Bewusst eine flache Liste und kein Baum: geblendet wird
## Punkt fuer Punkt, und ein Baum muesste dafuer erst wieder abgewickelt
## werden.
class Haltung extends RefCounted:
    var hueft := Vector2(0.0, -0.46)
    var brust := Vector2(0.0, -0.74)
    var kopf := Vector2(0.0, -0.90)
    var fuss_v := Vector2(0.22, 0.0)
    var fuss_h := Vector2(-0.26, 0.0)
    var schulter := Vector2(0.0, -0.72)
    var hand := Vector2(0.20, -0.62)
    var spitze := Vector2(0.62, -0.72)
    ## Nur fuer das Bild: wie weit die Figur nach vorn geneigt ist.
    var neigung := 0.0

    func blende(zu: Haltung, t: float) -> Haltung:
        var h := Haltung.new()
        h.hueft = hueft.lerp(zu.hueft, t)
        h.brust = brust.lerp(zu.brust, t)
        h.kopf = kopf.lerp(zu.kopf, t)
        h.fuss_v = fuss_v.lerp(zu.fuss_v, t)
        h.fuss_h = fuss_h.lerp(zu.fuss_h, t)
        h.schulter = schulter.lerp(zu.schulter, t)
        h.hand = hand.lerp(zu.hand, t)
        h.spitze = spitze.lerp(zu.spitze, t)
        h.neigung = lerpf(neigung, zu.neigung, t)
        return h


static func _setze(hueft: Vector2, brust: Vector2, kopf: Vector2,
        fuss_v: Vector2, fuss_h: Vector2, schulter: Vector2,
        hand: Vector2, spitze: Vector2, neigung := 0.0) -> Haltung:
    var h := Haltung.new()
    h.hueft = hueft
    h.brust = brust
    h.kopf = kopf
    h.fuss_v = fuss_v
    h.fuss_h = fuss_h
    h.schulter = schulter
    h.hand = hand
    h.spitze = spitze
    h.neigung = neigung
    return h


## --- Die Haltungen ---

static func ruhe(atem: float) -> Haltung:
    var s := sin(atem) * 0.012
    return _setze(
        Vector2(0.0, -0.46 + s), Vector2(0.01, -0.74 + s * 1.4),
        Vector2(0.03, -0.90 + s * 1.5),
        Vector2(0.20, 0.0), Vector2(-0.24, 0.0),
        Vector2(0.01, -0.72 + s * 1.4),
        Vector2(0.17, -0.56), Vector2(0.30, -0.16), 0.0)


## Der Ansatz je Linie. **Hier liegt die Lesbarkeit des ganzen Spiels.**
static func ansatz(linie: int) -> Haltung:
    match linie:
        Schnitte.Linie.SENKRECHT:
            # Beide Haende ueber dem Kopf, Klinge senkrecht nach oben.
            return _setze(
                Vector2(0.0, -0.47), Vector2(-0.02, -0.75), Vector2(0.0, -0.91),
                Vector2(0.24, 0.0), Vector2(-0.26, 0.0),
                Vector2(-0.01, -0.73), Vector2(0.06, -1.02),
                Vector2(0.10, -1.52), -0.04)
        Schnitte.Linie.KESA:
            # Ueber der rechten Schulter, Spitze schraeg nach hinten oben.
            return _setze(
                Vector2(0.0, -0.46), Vector2(-0.04, -0.74), Vector2(-0.02, -0.90),
                Vector2(0.22, 0.0), Vector2(-0.28, 0.0),
                Vector2(-0.03, -0.72), Vector2(-0.18, -0.92),
                Vector2(-0.62, -1.28), -0.10)
        Schnitte.Linie.GYAKU:
            # Tief an der linken Huefte, Spitze nach unten hinten - der
            # aufsteigende Hieb kommt von dort.
            return _setze(
                Vector2(0.0, -0.46), Vector2(0.03, -0.73), Vector2(0.05, -0.89),
                Vector2(0.26, 0.0), Vector2(-0.24, 0.0),
                Vector2(0.03, -0.71), Vector2(-0.16, -0.38),
                Vector2(-0.58, -0.10), 0.06)
        Schnitte.Linie.WAAGERECHT:
            # Waagerecht hinter dem Ruecken aufgezogen, Spitze nach hinten.
            return _setze(
                Vector2(-0.02, -0.46), Vector2(-0.06, -0.73), Vector2(-0.04, -0.89),
                Vector2(0.28, 0.0), Vector2(-0.24, 0.0),
                Vector2(-0.05, -0.71), Vector2(-0.22, -0.68),
                Vector2(-0.74, -0.62), -0.06)
        _:
            # Stoss: Spitze voran, Koerper lang gestreckt.
            return _setze(
                Vector2(0.0, -0.44), Vector2(0.06, -0.72), Vector2(0.09, -0.88),
                Vector2(0.32, 0.0), Vector2(-0.30, 0.0),
                Vector2(0.06, -0.70), Vector2(0.24, -0.68),
                Vector2(0.86, -0.70), 0.10)


## Der Durchschlag: die Klinge steht auf der anderen Seite ihrer Linie.
static func schlag(linie: int) -> Haltung:
    var a := ansatz(linie)
    var h := _setze(
        Vector2(0.02, -0.44), Vector2(0.10, -0.71), Vector2(0.13, -0.87),
        Vector2(0.36, 0.0), Vector2(-0.30, 0.0),
        Vector2(0.09, -0.69), Vector2(0.30, -0.60),
        Vector2(0.30, -0.60), 0.16)
    if Schnitte.ist_stoss(linie):
        h.spitze = Vector2(1.10, -0.70)
        h.hand = Vector2(0.44, -0.68)
        return h
    # Die Klinge laeuft durch: vom Ansatzpunkt aus ueber die Linie hinaus.
    var r := Schnitte.richtung(linie)
    h.spitze = h.hand + Vector2(-r.x, -r.y) * 0.78 \
        if a.spitze.x < a.hand.x else h.hand + r * 0.78
    return h


static func offen(t: float) -> Haltung:
    # Zurueckgeworfen, Klinge aus der Linie, Kopf im Nacken.
    return _setze(
        Vector2(-0.05, -0.43), Vector2(-0.13, -0.70), Vector2(-0.18, -0.85),
        Vector2(0.14, 0.0), Vector2(-0.34, 0.0),
        Vector2(-0.12, -0.68), Vector2(-0.30, -0.50),
        Vector2(-0.66, -0.22), -0.20 - 0.05 * sin(t * 9.0))


static func gefallen(t: float) -> Haltung:
    var f := clampf(t, 0.0, 1.0)
    var sink := f * f
    return _setze(
        Vector2(-0.10 - 0.22 * sink, -0.44 + 0.40 * sink),
        Vector2(-0.24 - 0.34 * sink, -0.70 + 0.62 * sink),
        Vector2(-0.34 - 0.44 * sink, -0.84 + 0.76 * sink),
        Vector2(0.10 - 0.10 * sink, 0.0), Vector2(-0.36, 0.0),
        Vector2(-0.22 - 0.30 * sink, -0.68 + 0.60 * sink),
        Vector2(-0.40 - 0.30 * sink, -0.40 + 0.36 * sink),
        Vector2(-0.86 - 0.20 * sink, -0.06 + 0.06 * sink), -0.5 * sink)


## Der Spieler: Parade auf einer Achse - die Klinge **liegt** in der Linie,
## damit das Bild dasselbe sagt wie die Pruefung.
static func parade(linie: int) -> Haltung:
    var r := Schnitte.richtung(linie)
    var hand := Vector2(0.16, -0.66)
    return _setze(
        Vector2(0.0, -0.46), Vector2(0.0, -0.74), Vector2(0.02, -0.90),
        Vector2(0.22, 0.0), Vector2(-0.26, 0.0),
        Vector2(0.0, -0.72), hand, hand + r * 0.66, -0.02)


static func schnitt_aus() -> Haltung:
    return _setze(
        Vector2(0.03, -0.45), Vector2(0.12, -0.72), Vector2(0.16, -0.88),
        Vector2(0.38, 0.0), Vector2(-0.28, 0.0),
        Vector2(0.11, -0.70), Vector2(0.36, -0.56),
        Vector2(0.92, -0.30), 0.18)


## --- Zeichnen ---

## Ein Knie oder Ellbogen: die Mitte, quer versetzt. Zwei-Knochen-Kinematik
## waere hier eine Rechnung fuer eine Wirkung, die niemand sieht.
static func _gelenk(a: Vector2, b: Vector2, bieg: float) -> Vector2:
    return (a + b) * 0.5 + (b - a).orthogonal().normalized() * bieg


## Eine ganze Figur. `blick` ist +1 nach rechts, -1 nach links.
static func figur(tu: Tusche, ort: Vector2, hoehe: float, blick: float,
        h: Haltung, farbe: Color, klingenfarbe: Color) -> void:
    var neige := h.neigung * blick

    # Vom Einheitsraum ins Bild: spiegeln, neigen, skalieren.
    var abb := func(p: Vector2) -> Vector2:
        var x := p.x * blick
        var y := p.y
        # Neigung dreht um die Fuesse, nicht um die Mitte - sonst wandert
        # der Kopf zurueck, waehrend der Koerper nach vorn geht.
        var gedreht := Vector2(x + y * neige * -1.0, y)
        return ort + gedreht * hoehe

    var hueft: Vector2 = abb.call(h.hueft)
    var brust: Vector2 = abb.call(h.brust)
    var kopf: Vector2 = abb.call(h.kopf)
    var fuss_v: Vector2 = abb.call(h.fuss_v)
    var fuss_h: Vector2 = abb.call(h.fuss_h)
    var schulter: Vector2 = abb.call(h.schulter)
    var hand: Vector2 = abb.call(h.hand)
    var spitze: Vector2 = abb.call(h.spitze)

    var b_hose := hoehe * B_HOSE
    var b_arm := hoehe * B_ARM
    var b_rumpf := hoehe * B_RUMPF

    # **Hinten zuerst, vorn zuletzt.** So verdeckt der Koerper, was hinter
    # ihm liegt, ohne dass irgendwo ein Umriss noetig waere - Tiefe aus der
    # Reihenfolge und nicht aus einer Kontur.
    #
    # Und jedes Glied ist **ein** Strang und nicht zwei Zuege: die
    # Begruendung steht bei `Tusche.strang()`, sie heisst Kerbe.

    # Das hintere Bein. Eine Hakama ist an der Huefte weit und am Knoechel
    # eng - eine Roehre waere eine Hose aus dem Katalog.
    tu.strang(PackedVector2Array([hueft,
        _gelenk(hueft, fuss_h, hoehe * 0.05 * blick), fuss_h]),
        PackedFloat32Array([b_hose * 0.92, b_hose * 0.70, b_hose * 0.16]),
        farbe, 10)
    # Der hintere Aermel biegt nach **hinten**, der vordere nach vorn. Beide
    # in dieselbe Richtung gebogen liegen aufeinander, und dann sieht man
    # einen Reifen statt zweier Arme.
    tu.strang(PackedVector2Array([schulter,
        _gelenk(schulter, hand, hoehe * -0.05 * blick), hand]),
        PackedFloat32Array([b_arm * 0.88, b_arm * 0.62, b_arm * 0.34]),
        farbe, 9)

    # **Der Rumpf ist das Gewand**: ein Strang von der Huefte ueber die
    # Brust in den Hals, am Guertel eingezogen und an der Brust am
    # breitesten. Dass der Hals daraus hervorgeht statt darauf zu sitzen,
    # ist der Unterschied zwischen einer Figur und einem Kopf auf einem Rohr.
    tu.strang(PackedVector2Array([hueft, brust, kopf]),
        PackedFloat32Array([b_rumpf * 0.68, b_rumpf, b_rumpf * 0.20]),
        farbe, 12)
    tu.klecks(kopf, hoehe * 0.059, farbe, int(ort.x))
    # Der Schopf: ein kurzer Strich nach hinten oben. Er kostet nichts und
    # gibt dem Kopf eine Richtung - ohne ihn ist er ein Punkt.
    tu.zug(kopf, kopf + Vector2(-0.062 * blick, -0.050) * hoehe,
        hoehe * 0.032, farbe, 0.0, 0.6, 0.0, 4)
    # **Der Guertel bricht die Masse.** Ohne ihn ist der Rumpf eine Spindel;
    # mit ihm hat er ein Oben und ein Unten, und das kostet einen Strich.
    var quer := (brust - hueft).orthogonal().normalized()
    tu.zug(hueft - quer * b_rumpf * 0.36, hueft + quer * b_rumpf * 0.36,
        hoehe * 0.030, farbe, 0.5, 0.0, hoehe * 0.006, 4)

    # Das vordere Bein und der vordere Aermel liegen oben.
    tu.strang(PackedVector2Array([hueft,
        _gelenk(hueft, fuss_v, hoehe * -0.06 * blick), fuss_v]),
        PackedFloat32Array([b_hose, b_hose * 0.74, b_hose * 0.17]),
        farbe, 10)
    tu.strang(PackedVector2Array([schulter,
        _gelenk(schulter, hand, hoehe * 0.06 * blick), hand]),
        PackedFloat32Array([b_arm, b_arm * 0.70, b_arm * 0.38]),
        farbe, 9)

    # **Die Klinge ist der trockenste Strich im Bild.** Sie laeuft zur
    # Spitze auf nichts aus - eine Klinge, die am Ende so breit ist wie am
    # Griff, ist ein Brett. Der Griff sitzt dahinter: ein kurzes Stueck
    # ueber die Hand hinaus, damit die Hand *am* Schwert liegt und nicht an
    # seinem Ende.
    var achse := (spitze - hand).normalized()
    tu.zug(hand, spitze, hoehe * B_KLINGE, klingenfarbe,
        0.22, 0.30, hoehe * 0.022 * blick, 9)
    # **Der Griff liegt ueber der Klinge, nicht darunter.** Darunter
    # gezeichnet verschwindet er in ihr, und die Hand sitzt dann am Ende
    # eines Stabes statt an einem Schwert.
    tu.zug(hand - achse * hoehe * 0.105, hand + achse * hoehe * 0.02,
        hoehe * 0.050, farbe, 0.45, 0.0, 0.0, 4)


## **Der Schatten unter den Fuessen.** Ohne ihn schwebt die Figur ueber dem
## Papier - dieselbe Frage wie ueberall: was aufliegt, braucht Kontakt.
static func schatten(tu: Tusche, ort: Vector2, hoehe: float, staerke := 1.0) -> void:
    var b := hoehe * 0.30
    tu.wisch(ort + Vector2(-b, 0.0), ort + Vector2(b, 0.0),
        hoehe * 0.055, Color(GRAU.r, GRAU.g, GRAU.b, 0.22 * staerke))
