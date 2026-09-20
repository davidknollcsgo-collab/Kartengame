class_name Streiter
extends RefCounted

## **Die Figuren.**
##
## In Minute neun stehen hundert davon im Bild. **Jede Sorte muss auf einen
## Blick zu erkennen sein, und der Held zuerst.**
##
## Hier stand einmal die umgekehrte Regel: *eine Sorte muss an ihrer
## Silhouette erkennbar sein, nicht an ihrer Farbe* - alles schwarze Tusche,
## Zinnober fuer Gefahr, Gold fuer Sold. Sie war in sich schluessig und im
## Gedraenge unbrauchbar, und zwar aus einem Grund, der eine Zeile weiter
## unten steht: ab `DICHT_AB` Figuren schaltet **jede** davon auf die
## Sparfassung, und die wirft die Silhouette weg. Die Regel verlangte genau
## das, was das Bild in seinem dichtesten Moment nicht mehr liefern konnte.
## Uebrig blieben achtzig gleiche schwarze Umrisse, und einer davon war man
## selbst.
##
## **Jetzt traegt die Farbe, was die Silhouette nicht mehr traegt**
## (`Palette.SORTE`), und der Bau bleibt trotzdem verschieden: der Wolf
## laeuft auf vieren und ist lang, der Spiesser traegt eine Stange quer durch
## sein eigenes Bild, der Treiber eine Fahne ueber alle hinaus, der Ritter
## ist breit und hat einen Schild, der Warlord ueberragt alles. Zwei Merkmale
## sind besser als eines - aber nur eines davon ueberlebt die Sparfassung,
## und das ist die Farbe.
##
## Jede Figur bekommt dazu eine **Kante** und einen **Schatten**. Die Kante
## trennt sie von der Figur daneben, der Schatten vom Boden darunter; ohne
## den schwebt in einem Bild ohne Perspektive alles.

const TINTE := Palette.UMRISS
const HELL := Color(0.98, 0.96, 0.90)
const ZINNOBER := Palette.GEFAHR

## Ab wie vielen Figuren im Bild die Sparfassung gilt. Der Stil darf nicht
## aussetzen, aber sieben Straenge je Strolch mal hundertfuenfzig sind
## fuenfzigtausend Eckpunkte - und dann ruckelt das, was man sehen will.
const DICHT_AB := 70


static func _gelenk(a: Vector2, b: Vector2, bieg: float) -> Vector2:
    return (a + b) * 0.5 + (b - a).orthogonal().normalized() * bieg


## **Der Schatten am Boden.** Flach, weil das Feld von oben gesehen ist und
## die Figuren aufrecht stehen; ein runder Schatten laege senkrecht in der
## Luft. Er ist das Einzige, was eine Figur auf den Boden stellt - ohne ihn
## schwebt in einem Bild ohne Perspektive alles.
##
## Ein `band()` und kein `klecks()`: der Klecks braucht `ecken + 1` Punkte
## und `ecken` Dreiecke, das Band hier sieben Punkte. Bei hundertfuenfzig
## Figuren ist das der Unterschied zwischen einem Schatten und keinem.
static func _schatten(tu: Tusche, ort: Vector2, h: float) -> void:
    var breit := h * 0.17
    tu.band(PackedVector2Array([ort + Vector2(-breit, 0.0), ort,
        ort + Vector2(breit, 0.0)]),
        PackedFloat32Array([h * 0.010, h * 0.055, h * 0.010]),
        Palette.SCHATTEN, PackedFloat32Array())


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
            farbe, 6, Palette.UMRISS)


## Der Rumpf als Masse, mit Schraffur darin - das ist der Kettenhemd-Trick:
## erst eine Flaeche, dann Striche, die man zaehlen kann.
static func _rumpf(tu: Tusche, hueft: Vector2, brust: Vector2, breite: float,
        farbe: Color, mit_schraffur := true) -> void:
    tu.strang(PackedVector2Array([hueft, (hueft + brust) * 0.5, brust]),
        PackedFloat32Array([breite * 0.8, breite, breite * 0.5]), farbe, 7,
        Palette.UMRISS)
    if mit_schraffur:
        tu.schraffur(hueft, brust, breite * 0.8, 3,
            Color(HELL.r, HELL.g, HELL.b, 0.30), 1.4)


## --- Der Held ---

## **Der Held.** Seine Farbe traegt nichts sonst im ganzen Bild - das ist
## die halbe Antwort auf die Frage, die ein Spieler bei hundertfuenfzig
## Figuren alle zwei Sekunden stellt: *wo bin ich?* Die andere Haelfte ist
## die Freistellung darunter.
static func held(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, waffe_winkel: float, farbe := Palette.HELD,
        glanz := Palette.HELD_GLANZ) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.46)
    var brust := ort + Vector2(h * 0.02 * blick, -h * 0.76)
    var kopf := ort + Vector2(h * 0.04 * blick, -h * 0.92)
    var schulter := ort + Vector2(h * 0.01 * blick, -h * 0.74)

    _beine(tu, hueft, h, blick, phase, h * 0.155, farbe)
    _rumpf(tu, hueft, brust, h * 0.22, farbe)

    # Der Helm: ein Klecks mit Nasal. Das Nasal ist der ganze Unterschied
    # zwischen einem Topf und einem Helm.
    tu.klecks(kopf, h * 0.062, farbe, int(ort.x), Palette.UMRISS)
    tu.zug(kopf + Vector2(h * 0.05 * blick, -h * 0.01),
        kopf + Vector2(h * 0.055 * blick, h * 0.045), h * 0.022,
        glanz, 0.4, 0.2, 0.0, 3)

    # Der Arm und die Klinge. Der Winkel kommt von aussen: so zeigt die
    # Waffe wirklich dorthin, wo der Schlag gerechnet wurde.
    var hand := schulter + Vector2(cos(waffe_winkel), sin(waffe_winkel)) * h * 0.30
    tu.strang(PackedVector2Array([schulter, _gelenk(schulter, hand, h * 0.05), hand]),
        PackedFloat32Array([h * 0.10, h * 0.075, h * 0.045]), farbe, 6,
        Palette.UMRISS)
    # **Die Klinge traegt nicht die Farbe des Helden.** Stahl ist hell und
    # kalt; faerbte man sie wie sein Gewand, waere sie ein dritter Arm.
    var spitze := hand + Vector2(cos(waffe_winkel), sin(waffe_winkel)) * h * 0.52
    tu.zug(hand, spitze, h * 0.040, glanz, 0.2, 0.35, h * 0.012,
        6, Palette.UMRISS)
    # Parierstange: quer, kurz. Ohne sie ist es ein Stock.
    var quer := Vector2(cos(waffe_winkel), sin(waffe_winkel)).orthogonal()
    tu.zug(hand - quer * h * 0.055, hand + quer * h * 0.055, h * 0.022,
        Palette.SOLD, 0.5, 0.0, 0.0, 3)


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
        pergament: Color, ring := Palette.HELD) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.44)
    var brust := ort + Vector2(0.0, -h * 0.80)
    tu.strang(PackedVector2Array([ort + Vector2(0.0, -h * 0.02), hueft, brust]),
        PackedFloat32Array([h * 0.34, h * 0.40, h * 0.30]), pergament, 7)
    tu.klecks(ort + Vector2(0.0, -h * 0.90), h * 0.13, pergament, int(ort.y))
    # **Der Standring, und jetzt traegt er die Farbe des Helden.** Vorher
    # waren es zwei blasse Tuschebogen bei 45 % Deckung - im Gedraenge zwei
    # graue Striche unter einer von achtzig Figuren. Er ist die Marke, an der
    # man sich findet, also darf er auch wie eine aussehen.
    for s in [-1.0, 1.0]:
        tu.zug(ort + Vector2(h * 0.34 * s, -h * 0.03),
            ort + Vector2(h * 0.08 * s, h * 0.045), h * 0.055,
            ring, 0.5, 0.15, h * 0.03 * s, 5, Palette.UMRISS)


## --- Die Feinde ---

static func feind(tu: Tusche, ort: Vector2, h: float, blick: float, art: int,
        phase: float, zuckt: float, knapp: bool) -> void:
    var farbe := Palette.sorte(art)
    if zuckt > 0.0:
        # **Ein Getroffener blitzt auf, er verblasst nicht.** Vorher senkte
        # `zuckt` die Deckung - und ein Treffer, den man nur am Verblassen
        # erkennt, sieht aus wie ein Zeichenfehler und nicht wie ein Schlag.
        farbe = farbe.lerp(Palette.BLITZ, clampf(zuckt * 4.5, 0.0, 0.85))
    _schatten(tu, ort, h)
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
##
## **Und seit die Farbe traegt, ist er billig geworden.** Frueher warf diese
## Fassung genau das weg, woran man eine Sorte erkannte - bei achtzig Figuren
## standen achtzig gleiche schwarze Umrisse im Bild. Die Farbe ueberlebt die
## Sparfassung: ein vierstrichiger roter Ritter ist auch bei
## hundertfuenfzig Figuren ein Ritter. Der dichteste Fall ist damit der, der
## am meisten gewonnen hat.
static func _knapp(tu: Tusche, ort: Vector2, h: float, blick: float, art: int,
        farbe: Color) -> void:
    if art == Feinde.Art.WOLF:
        # Der Wolf bleibt lang und tief - aber mit Kopf und Laeufen, sonst
        # ist er eine Pfuetze.
        # **Tief, und der Kopf haengt vorn herunter.** Der erste Anlauf hatte
        # Ruecken und Kopf auf einer Hoehe: im Bild ein Tisch mit vier
        # Beinen. Was einen Vierbeiner ausmacht, ist die Neigung - Kruppe
        # hoch, Schulter tiefer, Kopf darunter.
        # **Kurz und tief, nicht lang und duenn.** Der erste Anlauf war ein
        # Band gleicher Dicke mit zwei nadelduennen Beinen darunter: im Bild
        # ein Balken auf zwei Spiessen. Bei zweiundzwanzig Bildpunkten Laenge
        # traegt nur, was **massig** ist - also ein kurzer, tiefer Rumpf,
        # dicke Laeufe und ein Kopf, der am Koerper sitzt statt an einem
        # Stiel. Genau hier wird ueber die Sorte entschieden, denn dies ist
        # die Fassung, die im Gedraenge gezeichnet wird.
        var hinten := ort + Vector2(-h * 0.30 * blick, -h * 0.52)
        var vorn := ort + Vector2(h * 0.22 * blick, -h * 0.40)
        # **Mit eingezogener Weiche.** Drei Stuetzstellen gaben eine glatte
        # Wurst; was einen Rumpf von einem Balken trennt, ist die Taille
        # zwischen Brustkorb und Kruppe. Vier Stellen, und die zweite ist
        # deutlich schmaler als ihre Nachbarn.
        tu.strang(PackedVector2Array([hinten,
            hinten.lerp(vorn, 0.38) + Vector2(0.0, h * 0.01),
            hinten.lerp(vorn, 0.72), vorn]),
            PackedFloat32Array([h * 0.20, h * 0.125, h * 0.26, h * 0.19]),
            farbe, 8, Palette.UMRISS)
        # Kopf tief und dicht am Bug - kein Stiel dazwischen.
        var kopf := vorn + Vector2(h * 0.17 * blick, h * 0.10)
        tu.klecks(kopf, h * 0.105, farbe, int(ort.x), Palette.UMRISS)
        tu.zug(kopf, kopf + Vector2(h * 0.15 * blick, h * 0.05), h * 0.065,
            farbe, 0.3, 0.5, 0.0, 3, Palette.UMRISS)
        # Zwei dicke Laeufe, vorn und hinten - nicht vier duenne.
        for s in [-0.24, 0.14]:
            tu.zug(ort + Vector2(h * s * blick, -h * 0.38),
                ort + Vector2(h * (s + 0.06) * blick, 0.0),
                h * 0.115, farbe, 0.25, 0.25, 0.0, 4, Palette.UMRISS)
        # Die Rute: der eine Strich, der ihn von jedem Zweibeiner trennt.
        tu.zug(hinten, hinten + Vector2(-h * 0.20 * blick, -h * 0.12),
            h * 0.060, farbe, 0.15, 0.6, h * 0.025, 4, Palette.UMRISS)
        return

    var hueft := ort + Vector2(0.0, -h * 0.44)
    var brust := ort + Vector2(0.0, -h * 0.78)
    # Zwei Beine als V: das ist der ganze Unterschied zwischen einer Figur
    # und einem Zapfen.
    for s in [-0.13, 0.13]:
        tu.zug(hueft, ort + Vector2(h * s * blick, 0.0), h * 0.085, farbe,
            0.15, 0.3, 0.0, 3, Palette.UMRISS)
    tu.strang(PackedVector2Array([hueft, (hueft + brust) * 0.5, brust]),
        PackedFloat32Array([h * 0.17, h * 0.21, h * 0.13]), farbe, 5,
        Palette.UMRISS)
    tu.klecks(ort + Vector2(0.0, -h * 0.88), h * 0.058, farbe, int(ort.x),
        Palette.UMRISS)
    if art == Feinde.Art.SPIESSER or art == Feinde.Art.TREIBER:
        var lang := 1.35 if art == Feinde.Art.SPIESSER else 1.75
        tu.zug(ort + Vector2(h * 0.18 * blick, -h * 0.05),
            ort + Vector2(-h * 0.12 * blick, -h * lang), h * 0.028, farbe,
            0.3, 0.3, 0.0, 4)
    elif art == Feinde.Art.RITTER or art == Feinde.Art.WARLORD:
        # Der Schild: die einzige geschlossene Flaeche neben einem Koerper.
        tu.klecks(brust + Vector2(h * 0.16 * blick, h * 0.06), h * 0.10,
            farbe, int(ort.y), Palette.UMRISS)


static func _strolch(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color) -> void:
    # Geduckt, Kapuze, kurzes Messer: der kleinste und haeufigste Umriss.
    var hueft := ort + Vector2(0.0, -h * 0.42)
    var brust := ort + Vector2(-h * 0.05 * blick, -h * 0.70)
    _beine(tu, hueft, h, blick, phase, h * 0.125, farbe)
    _rumpf(tu, hueft, brust, h * 0.18, farbe, false)
    # Die Kapuze laeuft nach hinten aus - ein Klecks allein waere ein Kopf.
    tu.klecks(brust + Vector2(h * 0.03 * blick, -h * 0.13), h * 0.056, farbe,
        int(ort.x), Palette.UMRISS)
    tu.zug(brust + Vector2(h * 0.03 * blick, -h * 0.15),
        brust + Vector2(-h * 0.12 * blick, -h * 0.08), h * 0.05, farbe,
        0.2, 0.6, 0.0, 4)
    var hand := brust + Vector2(h * 0.16 * blick, h * 0.02)
    tu.zug(brust, hand, h * 0.07, farbe, 0.2, 0.3, 0.0, 4)
    tu.zug(hand, hand + Vector2(h * 0.16 * blick, -h * 0.06), h * 0.026, farbe,
        0.2, 0.5, 0.0, 3)


## **Der Wolf.** Der einzige Umriss im Spiel, der nicht steht.
##
## Er war zweimal ein Tisch. Beim ersten Mal, weil Ruecken und Kopf auf einer
## Hoehe lagen; beim zweiten Mal, nachdem die Neigung stimmte, **weil vier
## gerade senkrechte Striche unter einer waagerechten Masse ein Tisch sind** -
## daran aendert die Neigung nichts, und die Farbe machte es schlimmer, weil
## eine graue Flaeche sich als Platte liest, wo ein schwarzer Strich noch als
## Strich durchging.
##
## Was einen Vierbeiner ausmacht, sind drei Dinge zugleich:
##
##   * **die Neigung** - Kruppe hoch, Schulter tiefer, Kopf darunter,
##   * **die Masse** - tiefe Brust, eingezogene Weiche; ein Band gleicher
##     Dicke ist ein Brett,
##   * **geknickte Laeufe** - ein Bein mit einem Gelenk ist ein Bein, ein
##     gerader Strich ist ein Tischbein.
static func _wolf(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color) -> void:
    # **Lang und deutlich geneigt.** Der zweite Anlauf hatte die Neigung
    # zwar richtig herum, aber mit sieben Bildpunkten Gefaelle auf fuenfzig
    # Punkte Laenge - das sieht niemand, und uebrig blieb wieder eine
    # waagerechte Platte. Ein Vierbeiner ist **doppelt so lang wie hoch**,
    # und sein Ruecken faellt sichtbar nach vorn ab.
    # **Massig, nicht lang.** Der dritte Anlauf war ein Band von sechzig
    # Bildpunkten Laenge und zehn Dicke mit vier Nadeln darunter - im Bild
    # ein Kleiderstaender. Ein Wolf ist knapp anderthalbmal so lang wie tief;
    # was ihn traegt, ist die **Masse** und nicht die Laenge.
    var kruppe := ort + Vector2(-h * 0.28 * blick, -h * 0.56)
    var weiche := ort + Vector2(-h * 0.04 * blick, -h * 0.46)
    var brust := ort + Vector2(h * 0.20 * blick, -h * 0.44)
    tu.strang(PackedVector2Array([kruppe, weiche, brust]),
        PackedFloat32Array([h * 0.30, h * 0.22, h * 0.38]), farbe, 8,
        Palette.UMRISS)

    # Hals nach vorn und **unten**, Kopf deutlich unterhalb der Schulter.
    var kopf := brust + Vector2(h * 0.22 * blick, h * 0.11)
    tu.strang(PackedVector2Array([brust, brust.lerp(kopf, 0.55), kopf]),
        PackedFloat32Array([h * 0.24, h * 0.18, h * 0.14]), farbe, 6,
        Palette.UMRISS)
    tu.klecks(kopf, h * 0.115, farbe, int(ort.x), Palette.UMRISS)
    # Schnauze und ein Ohr - zwei Striche, die den Kopf nach vorn richten.
    tu.zug(kopf, kopf + Vector2(h * 0.17 * blick, h * 0.045), h * 0.085,
        farbe, 0.3, 0.5, 0.0, 3, Palette.UMRISS)
    tu.zug(kopf + Vector2(-h * 0.02 * blick, -h * 0.04),
        kopf + Vector2(-h * 0.05 * blick, -h * 0.10), h * 0.028, farbe,
        0.4, 0.3, 0.0, 3, Palette.UMRISS)

    # **Vier Laeufe mit Gelenk**, vorn und hinten verschieden geknickt: der
    # Vorderlauf faellt fast gerade, der Hinterlauf hat ein Sprunggelenk und
    # zeigt nach hinten. Genau das unterscheidet einen Hund von einem Hocker.
    for i in 4:
        var hinten := i < 2
        var oben: Vector2 = kruppe.lerp(brust, 0.08 if hinten else 0.90)
        var schwung := sin(phase * 1.7 + PI * (0.0 if i % 2 == 0 else 1.0)) * 0.13
        var fuss := ort + Vector2((oben.x - ort.x) + (schwung + (0.16 if hinten
            else 0.02)) * h * blick, 0.0)
        # Der Hinterlauf knickt weit nach hinten aus (Sprunggelenk), der
        # Vorderlauf faellt fast gerade. Ein Bein mit Gelenk ist ein Bein.
        var knick: Vector2 = oben.lerp(fuss, 0.42) + Vector2(
            (-0.15 if hinten else 0.06) * h * blick, 0.0)
        tu.strang(PackedVector2Array([oben, knick, fuss]),
            PackedFloat32Array([h * 0.145, h * 0.105, h * 0.060]), farbe, 6,
            Palette.UMRISS)

    # Rute: sie macht den Umriss unverwechselbar.
    tu.zug(kruppe, kruppe + Vector2(-h * 0.24 * blick, -h * 0.12),
        h * 0.095, farbe, 0.1, 0.7, h * 0.03, 5, Palette.UMRISS)


static func _mit_stange(tu: Tusche, ort: Vector2, h: float, blick: float,
        phase: float, farbe: Color, laenge: float, fahne: bool) -> void:
    var hueft := ort + Vector2(0.0, -h * 0.46)
    var brust := ort + Vector2(0.0, -h * 0.78)
    _beine(tu, hueft, h, blick, phase, h * 0.14, farbe)
    _rumpf(tu, hueft, brust, h * 0.20, farbe, not fahne)
    tu.klecks(ort + Vector2(h * 0.02 * blick, -h * 0.92), h * 0.058, farbe,
        int(ort.x), Palette.UMRISS)
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
        int(ort.x), Palette.UMRISS)
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
    tu.klecks(kopf, h * 0.068, farbe, int(ort.x), Palette.UMRISS)
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
    tu.klecks(schild, h * (0.13 if warlord else 0.105), farbe, int(ort.y),
        Palette.UMRISS)
    tu.schraffur(schild + Vector2(0.0, -h * 0.10), schild + Vector2(0.0, h * 0.10),
        h * 0.17, 3, Color(HELL.r, HELL.g, HELL.b, 0.34), 1.5)
    # Die Klinge ueber der Schulter, schraeg nach hinten - Ansatz zum Schlag.
    var hand := brust + Vector2(-h * 0.13 * blick, -h * 0.04)
    tu.zug(brust, hand, h * 0.085, farbe, 0.2, 0.3, 0.0, 4)
    tu.zug(hand, hand + Vector2(-h * 0.30 * blick, -h * (0.46 if warlord else 0.34)),
        h * 0.040, farbe, 0.2, 0.35, h * 0.014, 5)
