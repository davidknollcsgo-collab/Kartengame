class_name Streiter
extends RefCounted

## **Die Figuren.**
##
## In Minute neun stehen hundert davon im Bild, alle in derselben schwarzen
## Tusche auf demselben hellen Pergament. Daraus folgt die einzige Regel, die
## hier wirklich zaehlt:
##
## **Eine Sorte muss an ihrer Silhouette erkennbar sein, nicht an ihrer
## Farbe.** Farbe traegt hier nichts - es gibt nur Schwarz, Zinnober fuer
## Gefahr und Gold fuer Sold. Wer eine Sorte nur an einem Farbton
## unterscheidet, hat sie bei hundert Figuren nicht unterschieden.
##
## Deshalb ist jede Sorte anders **gebaut** und nicht anders eingefaerbt:
## der Wolf laeuft auf vieren und ist lang, der Spiesser traegt eine Stange
## quer durch sein eigenes Bild, der Treiber eine Fahne ueber alle hinaus,
## der Ritter ist breit und hat einen Schild, der Warlord ueberragt alles.
##
## **Und der Held ist der einzige umrandete Koerper.** Ein heller Saum nur um
## ihn - so findet man sich im Gedraenge wieder, ohne dass irgendwo ein Pfeil
## stehen muss.

const TINTE := Color(0.12, 0.10, 0.09)
const HELL := Color(0.98, 0.96, 0.90)
const ZINNOBER := Color(0.66, 0.14, 0.11)

## Ab wie vielen Figuren im Bild die Sparfassung gilt. Der Stil darf nicht
## aussetzen, aber sieben Straenge je Strolch mal hundertfuenfzig sind
## fuenfzigtausend Eckpunkte - und dann ruckelt das, was man sehen will.
const DICHT_AB := 70


static func _gelenk(a: Vector2, b: Vector2, bieg: float) -> Vector2:
    return (a + b) * 0.5 + (b - a).orthogonal().normalized() * bieg


## Zwei Beine im Schritt. `phase` laeuft mit der Zeit; steht die Figur, steht
## auch der Schritt.
static func _beine(tu: Tusche, hueft: Vector2, h: float, blick: float,
        phase: float, breite: float, farbe: Color) -> void:
    for i in 2:
        var seite := sin(phase + PI * float(i)) * 0.16
        var fuss := hueft + Vector2(seite * h * blick, h * 0.44)
        var knie := _gelenk(hueft, fuss, h * 0.05 * blick)
        tu.strang(PackedVector2Array([hueft, knie, fuss]),
            PackedFloat32Array([breite, breite * 0.72, breite * 0.18]),
            farbe, 6)


## Der Rumpf als Masse, mit Schraffur darin - das ist der Kettenhemd-Trick:
## erst eine Flaeche, dann Striche, die man zaehlen kann.
static func _rumpf(tu: Tusche, hueft: Vector2, brust: Vector2, breite: float,
        farbe: Color, mit_schraffur := true) -> void:
    tu.strang(PackedVector2Array([hueft, (hueft + brust) * 0.5, brust]),
        PackedFloat32Array([breite * 0.8, breite, breite * 0.5]), farbe, 7)
    if mit_schraffur:
        tu.schraffur(hueft, brust, breite * 0.8, 3,
            Color(HELL.r, HELL.g, HELL.b, 0.30), 1.4)


## --- Der Held ---

static func held(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, waffe_winkel: float, farbe := TINTE) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.46)
    var brust := ort + Vector2(h * 0.02 * blick, -h * 0.76)
    var kopf := ort + Vector2(h * 0.04 * blick, -h * 0.92)
    var schulter := ort + Vector2(h * 0.01 * blick, -h * 0.74)

    _beine(tu, hueft, h, blick, phase, h * 0.155, farbe)
    _rumpf(tu, hueft, brust, h * 0.22, farbe)

    # Der Helm: ein Klecks mit Nasal. Das Nasal ist der ganze Unterschied
    # zwischen einem Topf und einem Helm.
    tu.klecks(kopf, h * 0.062, farbe, int(ort.x))
    tu.zug(kopf + Vector2(h * 0.05 * blick, -h * 0.01),
        kopf + Vector2(h * 0.055 * blick, h * 0.045), h * 0.022, farbe,
        0.4, 0.2, 0.0, 3)

    # Der Arm und die Klinge. Der Winkel kommt von aussen: so zeigt die
    # Waffe wirklich dorthin, wo der Schlag gerechnet wurde.
    var hand := schulter + Vector2(cos(waffe_winkel), sin(waffe_winkel)) * h * 0.30
    tu.strang(PackedVector2Array([schulter, _gelenk(schulter, hand, h * 0.05), hand]),
        PackedFloat32Array([h * 0.10, h * 0.075, h * 0.045]), farbe, 6)
    var spitze := hand + Vector2(cos(waffe_winkel), sin(waffe_winkel)) * h * 0.52
    tu.zug(hand, spitze, h * 0.040, farbe, 0.2, 0.35, h * 0.012, 6)
    # Parierstange: quer, kurz. Ohne sie ist es ein Stock.
    var quer := Vector2(cos(waffe_winkel), sin(waffe_winkel)).orthogonal()
    tu.zug(hand - quer * h * 0.055, hand + quer * h * 0.055, h * 0.022,
        farbe, 0.5, 0.0, 0.0, 3)


## **Der Held wird freigestellt.**
##
## In Minute fuenf stehen hundert schwarze Figuren im Bild, und eine davon
## ist man selbst. Der erste Anlauf legte einen hellen Saum *unter* ihn -
## das machte ihn blass statt auffindbar, weil die eigene Zeichnung darauf
## nur noch grau wirkte.
##
## Ein Holzschnitt loest das anders: er **schneidet die Figur frei**. Hier
## also eine Flaeche in Pergamentton, etwas groesser als der Held, unter ihn
## gelegt - im leeren Feld sieht man sie gar nicht, im Gedraenge steht er in
## einer Luecke. Dazu ein Ring am Boden, der sagt, wo er steht.
##
## Es ist die einzige Stelle im Spiel, an der Pergament ueber Tusche liegt.
static func frei_gestellt(tu: Tusche, ort: Vector2, h: float,
        pergament: Color) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.44)
    var brust := ort + Vector2(0.0, -h * 0.80)
    tu.strang(PackedVector2Array([ort + Vector2(0.0, -h * 0.02), hueft, brust]),
        PackedFloat32Array([h * 0.34, h * 0.40, h * 0.30]), pergament, 7)
    tu.klecks(ort + Vector2(0.0, -h * 0.90), h * 0.13, pergament, int(ort.y))
    # Der Standring: zwei Bogenstuecke, keine geschlossene Scheibe. Ein
    # voller Kreis waere eine Marke aus einem anderen Spiel.
    for s in [-1.0, 1.0]:
        tu.zug(ort + Vector2(h * 0.30 * s, -h * 0.02),
            ort + Vector2(h * 0.10 * s, h * 0.03), h * 0.030,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.45), 0.5, 0.2, h * 0.02 * s, 4)


## --- Die Feinde ---

static func feind(tu: Tusche, ort: Vector2, h: float, blick: float, art: int,
        phase: float, zuckt: float, knapp: bool) -> void:
    var farbe := TINTE
    if zuckt > 0.0:
        # Ein Getroffener setzt kurz aus, als haette der Stichel abgesetzt.
        farbe = Color(TINTE.r, TINTE.g, TINTE.b, 1.0 - clampf(zuckt * 4.0, 0.0, 0.62))
    if knapp:
        _knapp(tu, ort, h, blick, art, farbe)
        return
    match art:
        Feinde.Art.WOLF:
            _wolf(tu, ort, h, blick, phase, farbe)
        Feinde.Art.SPIESSER:
            _mit_stange(tu, ort, h, blick, phase, farbe, 1.35, false)
        Feinde.Art.ARMBRUSTER:
            _armbruster(tu, ort, h, blick, phase, farbe)
        Feinde.Art.TREIBER:
            _mit_stange(tu, ort, h, blick, phase, farbe, 1.75, true)
        Feinde.Art.RITTER:
            _ritter(tu, ort, h, blick, phase, farbe, false)
        Feinde.Art.WARLORD:
            _ritter(tu, ort, h, blick, phase, farbe, true)
        _:
            _strolch(tu, ort, h, blick, phase, farbe)


## **Die Sparfassung.** Drei Zuege je Figur - der Stil darf bei hundertfuenfzig
## Feinden nicht aussetzen, aber er darf sich vereinfachen. Was bleibt, ist
## genau das, woran man die Sorte erkennt: Umriss und Groesse.
## **Die Sparfassung - und sie muss trotzdem ein Mensch sein.**
##
## Der erste Anlauf war *ein* Strang von den Fuessen zur Brust plus ein
## Kopfklecks. Im Bild waren das fuenfzig schwarze **Pillen**: kein Schritt,
## keine Schultern, keine Richtung. Eine Sparfassung darf weglassen, was
## Zierde ist, aber nicht das, woran man eine Figur ueberhaupt erkennt -
## und das sind zwei Beine, eine Schulterlinie und ein Kopf.
##
## Vier Zuege statt siebzehn: das ist der Handel, und er ist bezahlbar.
static func _knapp(tu: Tusche, ort: Vector2, h: float, blick: float, art: int,
        farbe: Color) -> void:
    if art == Feinde.Art.WOLF:
        # Der Wolf bleibt lang und tief - aber mit Kopf und Laeufen, sonst
        # ist er eine Pfuetze.
        # **Tief, und der Kopf haengt vorn herunter.** Der erste Anlauf hatte
        # Ruecken und Kopf auf einer Hoehe: im Bild ein Tisch mit vier
        # Beinen. Was einen Vierbeiner ausmacht, ist die Neigung - Kruppe
        # hoch, Schulter tiefer, Kopf darunter.
        var hinten := ort + Vector2(-h * 0.30 * blick, -h * 0.36)
        var vorn := ort + Vector2(h * 0.22 * blick, -h * 0.30)
        tu.strang(PackedVector2Array([hinten, (hinten + vorn) * 0.5
            + Vector2(0.0, -h * 0.03), vorn]),
            PackedFloat32Array([h * 0.12, h * 0.18, h * 0.13]), farbe, 5)
        var kopf := vorn + Vector2(h * 0.13 * blick, h * 0.08)
        tu.zug(vorn, kopf, h * 0.08, farbe, 0.3, 0.2, 0.0, 3)
        tu.klecks(kopf, h * 0.050, farbe, int(ort.x))
        tu.zug(kopf, kopf + Vector2(h * 0.11 * blick, h * 0.03), h * 0.032,
            farbe, 0.2, 0.6, 0.0, 3)
        for s in [-0.22, 0.16]:
            tu.zug(ort + Vector2(h * s * blick, -h * 0.32),
                ort + Vector2(h * (s + 0.04) * blick, 0.0), h * 0.048, farbe,
                0.2, 0.35, 0.0, 3)
        return

    var hueft := ort + Vector2(0.0, -h * 0.44)
    var brust := ort + Vector2(0.0, -h * 0.78)
    # Zwei Beine als V: das ist der ganze Unterschied zwischen einer Figur
    # und einem Zapfen.
    for s in [-0.13, 0.13]:
        tu.zug(hueft, ort + Vector2(h * s * blick, 0.0), h * 0.085, farbe,
            0.15, 0.3, 0.0, 3)
    tu.strang(PackedVector2Array([hueft, (hueft + brust) * 0.5, brust]),
        PackedFloat32Array([h * 0.17, h * 0.21, h * 0.13]), farbe, 5)
    tu.klecks(ort + Vector2(0.0, -h * 0.88), h * 0.058, farbe, int(ort.x))
    if art == Feinde.Art.SPIESSER or art == Feinde.Art.TREIBER:
        var lang := 1.35 if art == Feinde.Art.SPIESSER else 1.75
        tu.zug(ort + Vector2(h * 0.18 * blick, -h * 0.05),
            ort + Vector2(-h * 0.12 * blick, -h * lang), h * 0.028, farbe,
            0.3, 0.3, 0.0, 4)
    elif art == Feinde.Art.RITTER or art == Feinde.Art.WARLORD:
        # Der Schild: die einzige geschlossene Flaeche neben einem Koerper.
        tu.klecks(brust + Vector2(h * 0.16 * blick, h * 0.06), h * 0.10,
            farbe, int(ort.y))


static func _strolch(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color) -> void:
    # Geduckt, Kapuze, kurzes Messer: der kleinste und haeufigste Umriss.
    var hueft := ort + Vector2(0.0, -h * 0.42)
    var brust := ort + Vector2(-h * 0.05 * blick, -h * 0.70)
    _beine(tu, hueft, h, blick, phase, h * 0.125, farbe)
    _rumpf(tu, hueft, brust, h * 0.18, farbe, false)
    # Die Kapuze laeuft nach hinten aus - ein Klecks allein waere ein Kopf.
    tu.klecks(brust + Vector2(h * 0.03 * blick, -h * 0.13), h * 0.056, farbe,
        int(ort.x))
    tu.zug(brust + Vector2(h * 0.03 * blick, -h * 0.15),
        brust + Vector2(-h * 0.12 * blick, -h * 0.08), h * 0.05, farbe,
        0.2, 0.6, 0.0, 4)
    var hand := brust + Vector2(h * 0.16 * blick, h * 0.02)
    tu.zug(brust, hand, h * 0.07, farbe, 0.2, 0.3, 0.0, 4)
    tu.zug(hand, hand + Vector2(h * 0.16 * blick, -h * 0.06), h * 0.026, farbe,
        0.2, 0.5, 0.0, 3)


static func _wolf(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color) -> void:
    # **Auf vieren und lang** - der einzige Umriss im Spiel, der nicht steht.
    var ruecken_h := ort + Vector2(-h * 0.36 * blick, -h * 0.40)
    var ruecken_v := ort + Vector2(h * 0.26 * blick, -h * 0.46)
    tu.strang(PackedVector2Array([ruecken_h, (ruecken_h + ruecken_v) * 0.5
        + Vector2(0.0, -h * 0.04), ruecken_v]),
        PackedFloat32Array([h * 0.16, h * 0.22, h * 0.17]), farbe, 7)
    # Kopf mit Schnauze, tief getragen.
    var kopf := ruecken_v + Vector2(h * 0.14 * blick, h * 0.04)
    tu.klecks(kopf, h * 0.055, farbe, int(ort.x))
    tu.zug(kopf, kopf + Vector2(h * 0.14 * blick, h * 0.04), h * 0.034, farbe,
        0.2, 0.5, 0.0, 3)
    # Vier Laeufe, paarweise gegenlaeufig.
    for i in 4:
        var wo: Vector2 = ruecken_h.lerp(ruecken_v, 0.14 + 0.24 * float(i))
        var schwung := sin(phase * 1.6 + PI * 0.5 * float(i)) * 0.11
        tu.zug(wo, ort + Vector2((wo.x - ort.x) / maxf(1.0, h) * h + schwung * h * blick, 0.0),
            h * 0.055, farbe, 0.2, 0.3, 0.0, 4)
    # Rute: sie macht den Umriss unverwechselbar.
    tu.zug(ruecken_h, ruecken_h + Vector2(-h * 0.24 * blick, -h * 0.14),
        h * 0.045, farbe, 0.1, 0.7, h * 0.02, 5)


static func _mit_stange(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color, laenge: float, fahne: bool) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.46)
    var brust := ort + Vector2(0.0, -h * 0.78)
    _beine(tu, hueft, h, blick, phase, h * 0.14, farbe)
    _rumpf(tu, hueft, brust, h * 0.20, farbe, not fahne)
    tu.klecks(ort + Vector2(h * 0.02 * blick, -h * 0.92), h * 0.058, farbe,
        int(ort.x))
    # **Die Stange quert das eigene Bild** - daran erkennt man beide Sorten
    # auf zwanzig Bildpunkten, und zwar noch im Gedraenge.
    var fuss := ort + Vector2(h * 0.24 * blick, -h * 0.06)
    var spitze := ort + Vector2(-h * 0.16 * blick, -h * laenge)
    tu.zug(fuss, spitze, h * 0.030, farbe, 0.4, 0.15, 0.0, 5)
    if fahne:
        # Ein Tuch am oberen Ende: es ragt ueber alles hinaus, und genau das
        # ist die Ansage - nimm mich zuerst.
        var quer := (spitze - fuss).normalized().orthogonal() * blick
        tu.strang(PackedVector2Array([spitze, spitze + quer * h * 0.20
            + Vector2(0.0, h * 0.07), spitze + Vector2(0.0, h * 0.24)]),
            PackedFloat32Array([h * 0.02, h * 0.16, h * 0.03]), farbe, 6)
    else:
        tu.zug(spitze, spitze + (spitze - fuss).normalized() * h * 0.10,
            h * 0.05, farbe, 0.0, 0.8, 0.0, 3)
    tu.zug(brust, fuss.lerp(spitze, 0.35), h * 0.062, farbe, 0.2, 0.3, 0.0, 4)


static func _armbruster(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color) -> void:
    # Geduckt, und die Waffe liegt **waagerecht** - die einzige Querlinie auf
    # Brusthoehe im ganzen Spiel.
    var hueft := ort + Vector2(0.0, -h * 0.40)
    var brust := ort + Vector2(-h * 0.04 * blick, -h * 0.68)
    _beine(tu, hueft, h, blick, phase * 0.5, h * 0.13, farbe)
    _rumpf(tu, hueft, brust, h * 0.19, farbe)
    tu.klecks(brust + Vector2(h * 0.04 * blick, -h * 0.12), h * 0.052, farbe,
        int(ort.x))
    var hand := brust + Vector2(h * 0.20 * blick, -h * 0.02)
    tu.zug(brust, hand, h * 0.07, farbe, 0.2, 0.3, 0.0, 4)
    tu.zug(hand + Vector2(-h * 0.14 * blick, 0.0), hand + Vector2(h * 0.20 * blick, 0.0),
        h * 0.032, farbe, 0.45, 0.1, 0.0, 4)
    tu.zug(hand + Vector2(h * 0.14 * blick, -h * 0.10),
        hand + Vector2(h * 0.14 * blick, h * 0.10), h * 0.026, farbe,
        0.5, 0.0, h * 0.02, 4)


static func _ritter(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color, warlord: bool) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.44)
    var brust := ort + Vector2(0.0, -h * 0.76)
    _beine(tu, hueft, h, blick, phase, h * 0.185, farbe)
    # **Breit.** Der Ritter unterscheidet sich vom Strolch nicht durch Groesse
    # allein, sondern durch Masse - ein hochskalierter Strolch waere ein
    # Strolch, der naeher steht.
    _rumpf(tu, hueft, brust, h * 0.30, farbe)
    var kopf := ort + Vector2(0.0, -h * 0.90)
    tu.klecks(kopf, h * 0.068, farbe, int(ort.x))
    if warlord:
        # Hoerner: der einzige Umriss mit zwei Spitzen ueber dem Kopf.
        for s in [-1.0, 1.0]:
            tu.zug(kopf + Vector2(h * 0.05 * s, -h * 0.02),
                kopf + Vector2(h * 0.14 * s, -h * 0.13), h * 0.028, farbe,
                0.3, 0.5, h * 0.015 * s, 4)
    # Schild an der vorderen Seite: eine geschlossene Flaeche, die der
    # Schraffur widerspricht - deshalb liest man ihn als Ding und nicht als
    # Koerperteil.
    var schild := brust + Vector2(h * 0.17 * blick, h * 0.06)
    tu.klecks(schild, h * (0.13 if warlord else 0.105), farbe, int(ort.y))
    tu.schraffur(schild + Vector2(0.0, -h * 0.10), schild + Vector2(0.0, h * 0.10),
        h * 0.17, 3, Color(HELL.r, HELL.g, HELL.b, 0.34), 1.5)
    # Die Klinge ueber der Schulter, schraeg nach hinten - Ansatz zum Schlag.
    var hand := brust + Vector2(-h * 0.13 * blick, -h * 0.04)
    tu.zug(brust, hand, h * 0.085, farbe, 0.2, 0.3, 0.0, 4)
    tu.zug(hand, hand + Vector2(-h * 0.30 * blick, -h * (0.46 if warlord else 0.34)),
        h * 0.040, farbe, 0.2, 0.35, h * 0.014, 5)
