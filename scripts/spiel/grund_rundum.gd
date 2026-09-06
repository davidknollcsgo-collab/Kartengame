extends Node2D

## Der Meeresgrund des Rundumlaufs - alles aus Linien.
##
## **Vorher war hier nichts.** Ein schwarzes Feld mit einem Kreis darum: das
## reichte, um zu sehen, ob sich das Fahren gut anfuehlt, und fuer nichts
## sonst. Ohne Grund hat eine Fahrt keinen Bezug - man sieht das Boot sich
## bewegen, aber nicht, dass es **irgendwohin** faehrt.
##
## Alles hier ist ein Linienzug. Keine gefuellte Flaeche traegt eine Form;
## sie decken nur ab, was dahinter liegt. Das ist dieselbe Sprache wie im
## Schlund - und derselbe technische Grund: `draw_polygon` ist in Godot nicht
## kantengeglaettet, `draw_polyline` schon.
##
## **Drei Lagen, und die Tiefe steckt in Helligkeit und Groesse**, nicht in
## einer Perspektivrechnung - genau wie bei den Sedimentruecken im Schlund.
## Was hinten liegt, ist blasser, kleiner und feiner gestrichelt.
##
## Alles kommt aus einer Saat, und die haengt an der **Welle**: eine Strecke
## Graben je Fahrt, aber dieselbe Welle immer derselbe Grund. Wer eine
## Fundstelle liegen laesst und noch einmal so tief taucht, findet sie
## wieder - eine Karte, die sich bei jedem Start neu wuerfelt, ist keine.
## Innerhalb einer Fahrt bleibt der Grund stehen; gebaut wird nur in
## `rundlauf.gd::starte()`.

const SAAT := 0x4e454b52

## Wie weit ueber das Feld hinaus bewachsen wird. Am Rand soll nichts
## aufhoeren - eine Kante aus dem Nichts ist genau der Fehler, den das Riff
## im Schlund hatte.
const UEBERSTAND := 150.0

## **Vier Lagen statt dreier.** Die hinterste ist neu: sehr grosse, sehr
## dunkle Massive, die kaum mehr sind als ein Umriss. Sie geben dem Bild
## einen Horizont - vorher war der Grund gleichmaessig dicht besetzt, und was
## ueberall gleich weit weg ist, ist nirgends weit weg.
const TIEFE := 4
const LAGEN_KRAFT: PackedFloat32Array = [0.14, 0.34, 0.62, 1.0]

## Die Farben des Riffs. Dieselbe Familie wie im Schlund, damit die beiden
## Schleifen wie derselbe Graben aussehen.
const FARBEN: PackedColorArray = [
    Color(0.42, 0.86, 0.92),
    Color(0.86, 0.52, 0.78),
    Color(0.34, 0.70, 0.62),
    Color(0.94, 0.68, 0.32),
    Color(0.44, 0.52, 0.90),
]

var zeit := 0.0

## Die Karte des Spielers. Wird von `rundlauf.gd` gesetzt; ist sie leer, ist
## alles sichtbar - so bleiben Werkzeugschuesse ohne Nebel brauchbar.
var karte: Karte = null

## Der Kegel des Bootes, damit der Grund darauf reagieren kann.
##
## **Der Bewuchs war Kulisse.** Er stand da, in immer derselben Deckung, egal
## ob das Licht darueberging oder nicht - und damit war das Licht ein
## Werkzeug gegen Tiere und sonst nichts. Ein Riff, das aufleuchtet, wenn man
## es anleuchtet, macht aus dem Kegel eine Taschenlampe: man schwenkt ihn
## auch dann, wenn gerade nichts angreift.
##
## Gerechnet wird mit **derselben** `Schlund.beleuchtung()` wie Schaden und
## Kegelbild (Zusage 2) - ein Riff, das anders hell wird als der Kegel ist,
## waere eine dritte Wahrheit ueber dasselbe Licht.
## Der Abtrieb, den die Stroemung dem Kegel gerade gibt, in Bogenmass.
## Wird von `rundlauf.gd` gesetzt - dieselbe Zahl, die den Kegel dreht, aus
## demselben Grund wie in der Schlundwache (Zusage 27).
var abtrieb := 0.0

var licht_spitze := Vector2.ZERO
var licht_richtung := Vector2.ZERO
var licht_halbwinkel := 0.0
var licht_reichweite := 0.0
var licht_rand_kern := Schlund.RAND_KERN
var licht_tiefe_kern := Schlund.TIEFE_KERN
var licht_schein := 1.0

var _rippel: Array[PackedVector2Array] = []
var _felsen: Array[Dictionary] = []
var _bewuchs: Array[Dictionary] = []
var _staub: PackedVector2Array = []
var _staub_takt: PackedFloat32Array = []
var _funde: Array[Dictionary] = []
var _schlote: Array[Dictionary] = []
var _kleinzeug: Array[Dictionary] = []


func _ready() -> void:
    baue(0)


## Baut den Grund neu - **eine Strecke Graben je Fahrt.**
##
## Vorher gab es genau einen Grund, gebaut beim Start und danach nie wieder.
## Wer zum vierten Mal tauchte, deckte zum vierten Mal dieselbe Karte auf,
## und der Nebel verlor genau das, wofuer er da ist. Eine Fahrt fuehrt aber
## tiefer als die davor, also ist sie an einem anderen Ort.
##
## **Die Saat bleibt trotzdem eine Saat.** Sie haengt an der Welle, nicht an
## der Uhr: dieselbe Welle gibt denselben Grund, mit denselben Felsen und
## denselben Fundstellen. Wer eine Fundstelle liegen laesst und noch einmal
## dorthin taucht, findet sie wieder - eine Karte, die sich bei jedem Start
## neu wuerfelt, waere keine.
func baue(welle: int) -> void:
    _rippel.clear()
    _felsen.clear()
    _bewuchs.clear()
    _funde.clear()
    _schlote.clear()
    _kleinzeug.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = SAAT + welle
    _baue_rippel(rng)
    _baue_felsen(rng)
    _baue_bewuchs(rng)
    _baue_staub(rng)
    _baue_schlote(rng)
    _baue_kleinzeug(rng)
    _baue_funde(rng)


func _process(delta: float) -> void:
    zeit += delta
    _fuehre_glut(delta)
    queue_redraw()


## Wie schnell das Nachleuchten wieder abklingt.
const GLUT_ABKLANG := 0.55


## **Was der Kegel gestreift hat, glimmt weiter.**
##
## Ein Riff, das genau so lange leuchtet wie das Licht darauf faellt, ist ein
## Scheinwerfer auf einer Wand. Biolumineszenz ist eine Antwort des Tieres:
## sie setzt mit dem Reiz ein und laesst danach nach. Damit zieht der Kegel
## eine Spur ueber den Grund, und man sieht, wo man eben war - was in einem
## Feld, das im Dunkeln liegt, mehr ist als Zierde.
##
## Nur der Bewuchs, nicht das Kleinzeug: vierhundertzwanzig Zustaende je Bild
## sind nichts, sechsundzwanzighundert waeren spuerbar.
func _fuehre_glut(delta: float) -> void:
    var ab := clampf(GLUT_ABKLANG * delta, 0.0, 1.0)
    for b in _bewuchs:
        var p: Vector2 = b[&"ort"]
        var g := float(b[&"glut"])
        if not _im_blick(p, 60.0):
            # Ausserhalb des Bildes klingt es trotzdem ab - sonst kommt man
            # zurueck und findet eine Spur von vor zwei Minuten.
            b[&"glut"] = maxf(0.0, g - ab)
            continue
        b[&"glut"] = maxf(_angeleuchtet(p), g - ab)


## Sedimentrippel: lange, flache Wellenlinien quer ueber den Grund.
##
## Sie sind das, was den Boden ueberhaupt zu einem Boden macht. Ohne sie ist
## das Feld eine schwarze Scheibe, und ob man faehrt oder steht, sieht man
## nur am Boot. Mit ihnen hat der Grund eine Richtung, und die Fahrt einen
## Bezug.
## Halbe Breite eines Rippelbandes. Schmal, weil die Flaeche zaehlt: ein
## Band ueber die ganze Feldbreite ist bei jedem Pixel mehr Fuellung, und
## davon gibt es sechsundneunzig.
const RIPPEL_BREIT := 5.0

var _rippel_ecken := PackedVector2Array()
var _rippel_farben := PackedColorArray()
var _rippel_netz := PackedInt32Array()


func _baue_rippel(rng: RandomNumberGenerator) -> void:
    var weite := Rundum.FELD_RADIUS + UEBERSTAND
    var richtung := rng.randf_range(0.0, PI)
    for i in 96:
        var versatz := lerpf(-weite, weite, float(i) / 21.0) \
            + rng.randf_range(-9.0, 9.0)
        var quer := Vector2.RIGHT.rotated(richtung)
        var laengs := quer.orthogonal()
        var zug := PackedVector2Array()
        var takt := rng.randf_range(0.010, 0.020)
        var hub := rng.randf_range(7.0, 22.0)
        var phase := rng.randf_range(0.0, TAU)
        for j in 41:
            var t := lerpf(-weite, weite, float(j) / 40.0)
            var p := quer * (versatz + hub * sin(t * takt + phase)) + laengs * t
            if p.length() > weite:
                continue
            zug.append(p)
        if zug.size() > 3:
            _rippel.append(zug)
    _baue_rippelnetz()


## Die Rippel als **Baender**, nicht als Striche.
##
## Sechsundneunzig Haarlinien mit dreizehn Prozent Deckung quer ueber das
## ganze Feld sahen aus, als haette jemand mit dem Lineal ins Wasser
## gekratzt - dieselbe Beobachtung wie seinerzeit bei den Schlieren, und
## dieselbe Ursache: eine Linie hat zwei Kanten und keinen Uebergang.
##
## Eine Sandrippel von oben ist kein Strich, sondern ein Ruecken: in der
## Mitte am hellsten, zu beiden Seiten auf null auslaufend. Das sind drei
## Punktreihen statt einer, und der Verlauf dazwischen macht die Arbeit.
##
## **Einmal gebaut, in einem Aufruf gezeichnet.** Die Form aendert sich nie;
## sie kam trotzdem in jedem Bild als sechsundneunzig geglaettete Linienzuege
## heraus. Ein Dreiecksnetz kostet dagegen nichts als das Fuellen - und
## gemessen ist es billiger als die Linien, weil eine geglaettete Polylinie
## in Godot selbst schon Geometrie erzeugt.
func _baue_rippelnetz() -> void:
    _rippel_ecken = PackedVector2Array()
    _rippel_farben = PackedColorArray()
    _rippel_netz = PackedInt32Array()
    var mitte := Color(0.22, 0.44, 0.50, 0.15)
    var aus := Color(0.22, 0.44, 0.50, 0.0)
    for zug: PackedVector2Array in _rippel:
        var n := zug.size()
        var erste := _rippel_ecken.size()
        for i in n:
            # Die Normale aus den Nachbarn, damit das Band der Kurve folgt
            # statt an jeder Biegung zu knicken.
            var vor: Vector2 = zug[maxi(0, i - 1)]
            var nach: Vector2 = zug[mini(n - 1, i + 1)]
            var quer := (nach - vor)
            quer = quer.orthogonal().normalized() if quer.length() > 0.001 \
                else Vector2.UP
            _rippel_ecken.append(zug[i] - quer * RIPPEL_BREIT)
            _rippel_farben.append(aus)
            _rippel_ecken.append(zug[i])
            _rippel_farben.append(mitte)
            _rippel_ecken.append(zug[i] + quer * RIPPEL_BREIT)
            _rippel_farben.append(aus)
        for i in n - 1:
            var a := erste + i * 3
            var b := a + 3
            _rippel_netz.append_array([a, b, b + 1, a, b + 1, a + 1])
            _rippel_netz.append_array([a + 1, b + 1, b + 2, a + 1, b + 2, a + 2])


## Felsen.
##
## **Nicht als Ecken gewuerfelt, sondern als Radiusfunktion.** Der erste
## Anlauf setzte sieben bis elf zufaellige Ecken und verband sie gerade: im
## Bild waren das schwarze Siebenecke, und weil die Flaeche dunkler ist als
## das Wasser davor, las man sie als Loecher statt als Steine. Ein Fels hat
## keine geraden Kanten.
##
## Drei Sinus mit unrunden Vielfachen ueber den Winkel, abgetastet in 48
## Schritten - das gibt einen Umriss, der unregelmaessig **und** glatt ist,
## und er wiederholt sich nicht.
##
## Dazu eine Hoehenlinie innen. Sie ist das, was einen Umriss zu einem
## Koerper macht: eine Kuppe hat eine Schulter, und die sieht man von oben
## als zweite Kontur.
func _baue_felsen(rng: RandomNumberGenerator) -> void:
    for _i in 190:
        # **Nicht gleich viele je Lage.** Die hinterste traegt Massive vom
        # Zweieinhalbfachen der Groesse; gleich viele davon wie vorne heisst
        # siebenmal so viel Flaeche, und in Software-Rasterung ist Flaeche
        # das, was kostet - gemessen 6,0 auf 4,5 Bilder je Sekunde. Ein
        # Horizont braucht ohnehin keine Dichte, sondern Ruhe.
        var wurf := rng.randf()
        var lage := 0 if wurf < 0.09 else (1 + (rng.randi() % (TIEFE - 1)))
        var ort := _wuerfel_ort(rng)
        # Die hinterste Lage ist nicht nur blasser, sondern **groesser**.
        # Ein kleiner blasser Fels sieht aus wie ein kleiner Fels im Nebel;
        # ein grosser blasser sieht aus wie ein Berg in der Ferne.
        var gross := rng.randf_range(26.0, 96.0) \
            * (2.6 if lage == 0 else lerpf(0.55, 1.0,
                float(lage - 1) / float(TIEFE - 2)))
        # **Die Form kommt aus `Riff`, nicht von hier.** Sie ist dieselbe,
        # die das Boot abstoesst - ein Fels, der anders aussieht als er sich
        # anfuehlt, ist unlernbar.
        var fels := Riff.bauen(rng, ort, gross)
        fels[&"lage"] = lage
        # Nur die vorderste Lage haelt auf. Was hinten liegt, ist Kulisse -
        # sonst wuerde man an etwas anstossen, das erkennbar weiter weg ist.
        fels[&"fest"] = lage == TIEFE - 1
        var risse: Array[PackedVector2Array] = []
        for _k in rng.randi_range(1, 3):
            var w := rng.randf_range(0.0, TAU)
            var riss := PackedVector2Array()
            for j in 4:
                var t := float(j) / 3.0
                riss.append(ort + Vector2.RIGHT.rotated(
                    w + rng.randf_range(-0.20, 0.20)) * gross * t * 0.88)
            risse.append(riss)
        fels[&"risse"] = risse
        # **Einmal abtasten, nicht je Bild.** Die Kante aendert sich nie -
        # sie kam trotzdem in jedem Bild aus 48 Winkeln mit je drei Sinus
        # frisch heraus, und zwar zweimal je Fels (Umriss und Schulter). Bei
        # vierzig sichtbaren Felsen sind das elftausend Sinus je Bild fuer
        # eine Form, die seit dem Start feststeht.
        fels[&"weit"] = Riff.hoechster_radius(fels)
        fels[&"umriss"] = _felskante(fels)
        fels[&"schulter"] = _felskante(fels, 0.58)
        # Der Saum liegt **ausserhalb** der Kante. Er traegt keine Form,
        # sondern nur den Uebergang ins Wasser - siehe `_zeichne_felsen()`.
        fels[&"saum"] = _felskante(fels, 1.12)
        _felsen.append(fels)


## Die Kante eines Felsens, abgetastet. Dieselbe `Riff.radius()`, die auch
## die Kollision fragt.
func _felskante(fels: Dictionary, faktor := 1.0) -> PackedVector2Array:
    var punkte := PackedVector2Array()
    var stufen := 48
    for j in stufen:
        var w := TAU * float(j) / float(stufen)
        punkte.append(Vector2(fels[&"ort"])
            + Vector2.RIGHT.rotated(w) * Riff.radius(fels, w) * faktor)
    return punkte


## Schiebt einen Koerper aus jedem festen Fels heraus, den er beruehrt.
##
## Oeffentlich, weil `rundlauf.gd` es je Bild fragt. Zwei Durchgaenge, damit
## eine Ecke zwischen zwei Steinen nicht in den einen zurueckschiebt, was der
## andere gerade herausgeschoben hat.
func abgestossen(ort: Vector2, dick: float) -> Vector2:
    var p := ort
    for _durchgang in 2:
        for fels in _felsen:
            if not bool(fels.get(&"fest", false)):
                continue
            if Riff.beruehrt(fels, p, dick):
                p = Riff.abgestossen(fels, p, dick)
    return p


## Bewuchs: Faecher, Roehren und Schoepfe. Drei Formen reichen - was den
## Grund reich macht, ist nicht die Zahl der Arten, sondern dass sie in
## Gruppen stehen und verschieden gross sind.
func _baue_bewuchs(rng: RandomNumberGenerator) -> void:
    for _i in 420:
        var lage := rng.randi() % TIEFE
        var ort := _wuerfel_ort(rng)
        var arme := PackedFloat32Array()
        for _a in rng.randi_range(5, 10):
            arme.append(rng.randf_range(0.55, 1.0))
        _bewuchs.append({
            &"lage": lage,
            &"ort": ort,
            &"art": rng.randi() % 3,
            &"gross": rng.randf_range(11.0, 34.0)
                * lerpf(0.55, 1.0, float(lage) / float(TIEFE - 1)),
            &"dreh": rng.randf_range(0.0, TAU),
            &"arme": arme,
            &"takt": rng.randf_range(0.25, 0.8),
            &"phase": rng.randf_range(0.0, TAU),
            &"farbe": FARBEN[rng.randi() % FARBEN.size()],
            # Wieviel Nachleuchten der Bewuchs gerade traegt. Siehe
            # `_fuehre_glut()`.
            &"glut": 0.0,
        })


## Schlote: Risse im Grund, aus denen es warm herausleuchtet und aufsteigt.
##
## **Der Grund war ueberall gleich kalt.** Riff, Bewuchs und Sediment liegen
## alle im selben Blaugruen; was fehlte, war eine zweite Quelle - etwas, das
## von unten leuchtet statt angeleuchtet zu werden, und das sich bewegt,
## ohne dass man es angefahren hat.
##
## Sie stehen **ausserhalb von allem**: kein Schaden, kein Naehrstoff, keine
## Punkte, in keiner `Wellen.auftritte()`. Dieselbe Begruendung wie bei der
## Funkenbluete und den Fischschwaermen - was nichts kostet und nichts
## zahlt, verschiebt auch nichts.
const SCHLOTE := 30

## Wie hoch eine Fahne steigt, und wieviele Blasen sie traegt.
const FAHNE_HOCH := 190.0
const FAHNE_BLASEN := 9

func _baue_schlote(rng: RandomNumberGenerator) -> void:
    for _i in SCHLOTE:
        # Warm oder kalt: heisse Quellen und kalte Sicker. Zwei Farben
        # reichen - drei waeren Konfetti.
        var heiss := rng.randf() < 0.55
        _schlote.append({
            &"ort": _wuerfel_ort(rng),
            &"gross": rng.randf_range(9.0, 22.0),
            &"takt": rng.randf_range(0.22, 0.55),
            &"phase": rng.randf_range(0.0, TAU),
            &"neigung": rng.randf_range(-0.5, 0.5),
            &"farbe": Color(1.0, 0.62, 0.30) if heiss
                else Color(0.44, 0.86, 0.94),
        })


## Ein Schlot: ein Mund im Grund und eine Fahne darueber.
##
## Die Blasen steigen **entlang der Zeit**, nicht entlang einer Bahn: jede
## bekommt ihren Platz aus `zeit` und ihrer eigenen Nummer, laeuft nach oben
## und faengt oben wieder unten an. Damit braucht keine von ihnen einen
## eigenen Zustand, und der Schlot kostet nichts, wenn er nicht im Bild ist.
func _zeichne_schlote() -> void:
    for sch in _schlote:
        var p: Vector2 = sch[&"ort"]
        if not _im_blick(p, FAHNE_HOCH) or not _bekannt(p):
            continue
        var farbe: Color = sch[&"farbe"]
        var gr: float = sch[&"gross"]
        var takt: float = sch[&"takt"]
        var puls := 0.5 + 0.5 * sin(zeit * takt * 3.0 + float(sch[&"phase"]))
        # Auch der Schlot antwortet auf das Licht - schwaecher als der
        # Bewuchs, weil er selbst leuchtet und nicht nur zurueckwirft.
        puls = minf(1.6, puls + 1.4 * _angeleuchtet(p))
        var schraeg := Vector2(float(sch[&"neigung"]), -1.0).normalized()

        # **Ein Spalt, kein Ring.** Als voller Kreis gezeichnet sah der
        # Schlot aus wie eine Fundstelle oder ein kleiner Bewuchs - im
        # Bild lauter gleiche Kringel. Ein Riss quer zur Fahne ist auf einen
        # Blick etwas anderes als alles andere im Feld.
        var quer := schraeg.orthogonal()
        var lippe := PackedVector2Array()
        for j in 9:
            var u := lerpf(-1.0, 1.0, float(j) / 8.0)
            # Die Lippe woelbt sich der Fahne entgegen: ein Mund, kein
            # Strich.
            lippe.append(p + quer * u * gr
                + schraeg * (1.0 - u * u) * gr * 0.34)
        draw_polyline(lippe,
            Color(farbe.r, farbe.g, farbe.b, 0.08 + 0.08 * puls), 9.0, true)
        draw_polyline(lippe,
            Color(farbe.r, farbe.g, farbe.b, 0.42 + 0.30 * puls), 1.6, true)
        # Der Glutfleck darin - das Einzige im Feld, das von unten leuchtet.
        draw_circle(p + schraeg * gr * 0.16, gr * (0.34 + 0.12 * puls),
            Color(farbe.r, farbe.g, farbe.b, 0.14 + 0.16 * puls))

        for j in FAHNE_BLASEN:
            var t := fmod(zeit * takt + float(j) / float(FAHNE_BLASEN), 1.0)
            # Oben duenner und blasser: die Fahne loest sich auf, statt
            # abgeschnitten zu enden.
            var a := (1.0 - t) * (0.34 + 0.24 * puls)
            var seit := sin(t * 5.0 + float(j)) * gr * 0.55 * t
            var b := p + schraeg * (t * FAHNE_HOCH) \
                + schraeg.orthogonal() * seit
            draw_circle(b, maxf(0.7, gr * 0.24 * (1.0 - t * 0.6)),
                Color(farbe.r, farbe.g, farbe.b, a))


## Kleinzeug: Kies, Schalen, Seesterne, Roehrchen.
##
## **Detail dort, wo man ist.** Zwoelfhundert Kleinigkeiten ueber das ganze
## Feld waeren aus der Ferne ein Grieseln und aus der Naehe immer noch zu
## duenn. Sie werden deshalb nur in einem engen Umkreis um die Bildmitte
## gezeichnet - dort stehen dann dreissig bis fuenfzig davon, und der Grund
## bekommt genau da Textur, wo man hinsieht.
##
## Das kostet nichts und belohnt Bewegung: wer faehrt, findet staendig neuen
## Kleinkram, wer steht, sieht immer denselben.
const KLEINZEUG := 2600
const KLEIN_SICHT := 560.0

func _baue_kleinzeug(rng: RandomNumberGenerator) -> void:
    for _i in KLEINZEUG:
        _kleinzeug.append({
            &"ort": _wuerfel_ort(rng),
            &"art": rng.randi() % 6,
            &"gross": rng.randf_range(2.6, 7.5),
            &"dreh": rng.randf_range(0.0, TAU),
            &"ton": rng.randf_range(0.5, 1.0),
        })


## Das Kleinzeug auf dem Grund.
##
## **Es waren Striche, und Striche lesen sich als Schrift.** Jedes Stueck war
## ein Pixel breit und ueberall gleich hell: ein Bogen, drei Rippen, fuenf
## Arme, ein Strich mit einem Punkt. Vergroessert sah der Grund aus wie ein
## Schriftsatz - lauter kleine C, Sternchen und Striche, und nichts davon lag
## auf dem Boden.
##
## Was einem Kiesel Koerper gibt, sind drei Dinge, und keines davon ist eine
## weitere Linie:
##
##   * **Eine Flaeche.** Ein Stein ist gefuellt und **dunkler** als das
##     Sediment, nicht heller. Er nimmt Licht weg, bevor er welches gibt.
##   * **Ein Saum auf der Lichtseite.** Es gibt eine Lichtquelle, und sie
##     steht nicht senkrecht ueber dem Grund - `licht_spitze` sagt, wo. Ein
##     heller Bogen auf der zugewandten Seite macht aus einem Fleck eine
##     Woelbung.
##   * **Ein Schatten auf der anderen.** Nur eine Andeutung; der Grund ist
##     ohnehin dunkel, und ein harter Schlagschatten je Kiesel waere bei
##     sechsundzwanzighundert Stueck ein Muster.
func _zeichne_kleinzeug() -> void:
    var grund_farbe := Color(0.40, 0.66, 0.70)
    for k in _kleinzeug:
        var p: Vector2 = k[&"ort"]
        if p.distance_squared_to(_blickmitte) > KLEIN_SICHT * KLEIN_SICHT:
            continue
        if not _bekannt(p):
            continue
        var gr: float = k[&"gross"]
        var w: float = k[&"dreh"]
        # Im Licht deutlich, sonst nur eine Ahnung - dieselbe Antwort auf den
        # Kegel wie beim Bewuchs.
        # Nach aussen ausblenden, sonst steht am Rand des Umkreises eine
        # sichtbare Kante aus Kleinkram.
        var weg := p.distance_to(_blickmitte) / KLEIN_SICHT
        var saum := clampf((1.0 - weg) * 2.2, 0.0, 1.0)
        var hell := _angeleuchtet(p)
        var a := (0.13 + 0.34 * hell) * float(k[&"ton"]) * saum
        var farbe := Color(grund_farbe.r, grund_farbe.g, grund_farbe.b, a)

        # Woher das Licht kommt. Ohne Kegel faellt es von oben ein - dann
        # gibt es keine Seite, und der Saum liegt gleichmaessig oben.
        var zum_licht := Vector2.UP
        if licht_reichweite > 0.0:
            var d := licht_spitze - p
            if d.length_squared() > 1.0:
                zum_licht = d.normalized()
        var lick := 0.35 + 0.65 * hell

        match int(k[&"art"]):
            0:
                _kiesel(p, gr, w, farbe, zum_licht, lick, saum)
            1:
                _schale(p, gr, w, farbe, zum_licht, lick)
            2:
                _seestern(p, gr, w, farbe, zum_licht, lick)
            3:
                _roehrchen(p, gr, w, farbe, zum_licht, lick)
            4:
                _scherbe(p, gr, w, farbe, zum_licht, lick, saum)
            _:
                _wurmspur(p, gr, w, farbe)


## Ein Kiesel: eine gefuellte, leicht unrunde Scheibe mit hellem Scheitel.
func _kiesel(p: Vector2, gr: float, w: float, farbe: Color,
        zum_licht: Vector2, lick: float, saum: float) -> void:
    var rund := PackedVector2Array()
    for i in 7:
        var t := TAU * float(i) / 7.0 + w
        # Die Unrundheit kommt aus dem Winkel, nicht aus einem Wurf: ein
        # Stein, der bei jedem Bild anders aussieht, ist kein Stein.
        var rr := gr * (0.82 + 0.18 * sin(t * 3.0 + w * 5.0))
        rund.append(p + Vector2.RIGHT.rotated(t) * rr)
    # **Dunkel, aber nicht schwarz.** Der erste Anlauf fuellte mit 0,55
    # Deckung in fast Schwarz - im Bild waren das schwarze Punkte auf dem
    # Sediment, und der Grund wirkte leerer als mit den alten Strichen. Ein
    # Kiesel nimmt Licht weg, er ist kein Loch.
    draw_colored_polygon(rund, Color(0.030, 0.062, 0.074, 0.30 * saum))
    # Im Licht bekommt er zusaetzlich eine eigene Flaeche: ein angestrahlter
    # Stein ist eine Form, kein Schatten.
    if lick > 0.5:
        draw_colored_polygon(rund, Color(farbe.r, farbe.g, farbe.b,
            farbe.a * 0.55 * (lick - 0.5)))
    var scheitel := p + zum_licht * gr * 0.30
    draw_arc(scheitel, gr * 0.66, zum_licht.angle() - 1.6,
        zum_licht.angle() + 1.6, 8,
        Color(farbe.r, farbe.g, farbe.b, minf(1.0, farbe.a * 2.4 * lick)),
        1.3, true)


## Eine Schale: ein gefuellter Faecher mit Rippen, wie eine Muschel von oben.
func _schale(p: Vector2, gr: float, w: float, farbe: Color,
        zum_licht: Vector2, lick: float) -> void:
    var oeffnung := 1.0
    var schale := PackedVector2Array([p])
    for j in 5:
        var s := w + lerpf(-oeffnung, oeffnung, float(j) / 4.0)
        schale.append(p + Vector2.RIGHT.rotated(s) * gr * 1.5)
    draw_colored_polygon(schale, Color(farbe.r, farbe.g, farbe.b,
        farbe.a * 0.60))
    for j in 3:
        var s2 := w + lerpf(-0.6, 0.6, float(j) / 2.0)
        draw_line(p, p + Vector2.RIGHT.rotated(s2) * gr * 1.4,
            Color(farbe.r, farbe.g, farbe.b, farbe.a * 0.9 * lick), 1.0, true)
    # Der Wirbel, an dem die Schale sass - der Punkt, an dem eine Muschel
    # als Muschel zu lesen ist.
    draw_circle(p, gr * 0.22, Color(farbe.r, farbe.g, farbe.b,
        farbe.a * 1.4 * lick))
    var _egal := zum_licht


## Ein Schlangenstern: fuenf Arme, die sich kruemmen. Sie standen als gerade
## Speichen - und ein Seestern mit geraden Armen ist ein Stern aus dem
## Zeichensatz.
func _seestern(p: Vector2, gr: float, w: float, farbe: Color,
        zum_licht: Vector2, lick: float) -> void:
    for j in 5:
        var s := w + TAU * float(j) / 5.0
        var arm := PackedVector2Array()
        for n in 4:
            var t := float(n) / 3.0
            # Die Kruemmung haengt am Arm, nicht an der Zeit - er liegt still.
            var bieg := sin(t * 2.2) * 0.5 * sin(float(j) * 2.7 + w * 3.0)
            arm.append(p + Vector2.RIGHT.rotated(s + bieg) * gr * (0.25 + t))
        draw_polyline(arm, Color(farbe.r, farbe.g, farbe.b,
            minf(1.0, farbe.a * 1.3 * lick)), 1.2, true)
    draw_circle(p, gr * 0.30, Color(farbe.r, farbe.g, farbe.b, farbe.a * 0.7))
    var _egal := zum_licht


## Ein Roehrenwurm: der Stiel dunkel, die Krone hell - so herum, weil das
## Lebende leuchtet und die Roehre nur Kalk ist.
func _roehrchen(p: Vector2, gr: float, w: float, farbe: Color,
        zum_licht: Vector2, lick: float) -> void:
    var kopf := p + Vector2.RIGHT.rotated(w) * gr
    draw_line(p, kopf, Color(farbe.r * 0.7, farbe.g * 0.7, farbe.b * 0.7,
        farbe.a * 0.8), 1.6, true)
    for j in 3:
        var s := w + lerpf(-0.8, 0.8, float(j) / 2.0)
        draw_line(kopf, kopf + Vector2.RIGHT.rotated(s) * gr * 0.5,
            Color(farbe.r, farbe.g, farbe.b, farbe.a * 1.1 * lick), 1.0, true)
    draw_circle(kopf, 1.1, Color(farbe.r, farbe.g, farbe.b,
        minf(1.0, farbe.a * 1.9 * lick)))
    var _egal := zum_licht


## Eine Scherbe: ein flaches Dreieck, das auf der Lichtseite aufblitzt.
## Knochen, Schalenbruch, ein Stueck Schlot - was der Graben eben so
## liegenlaesst.
func _scherbe(p: Vector2, gr: float, w: float, farbe: Color,
        zum_licht: Vector2, lick: float, saum: float) -> void:
    var ecken := PackedVector2Array([
        p + Vector2.RIGHT.rotated(w) * gr * 1.3,
        p + Vector2.RIGHT.rotated(w + 2.3) * gr * 0.9,
        p + Vector2.RIGHT.rotated(w - 2.0) * gr * 1.0])
    draw_colored_polygon(ecken, Color(0.032, 0.066, 0.076, 0.34 * saum))
    # Nur die dem Licht zugewandte Kante blitzt - eine Scherbe, die rundum
    # glaenzt, ist ein Aufkleber.
    var lichtseite := p + zum_licht * gr * 0.8
    draw_line(ecken[0], lichtseite,
        Color(farbe.r, farbe.g, farbe.b, minf(1.0, farbe.a * 2.6 * lick)),
        1.2, true)


## Eine Wurmspur: eine flache Schlangenlinie im Sediment. Kein Koerper,
## sondern eine Vertiefung - deshalb dunkel und ohne Saum.
func _wurmspur(p: Vector2, gr: float, w: float, farbe: Color) -> void:
    var spur := PackedVector2Array()
    for n in 5:
        var t := float(n) / 4.0
        spur.append(p + Vector2.RIGHT.rotated(w) * gr * 3.0 * (t - 0.5)
            + Vector2.RIGHT.rotated(w + PI * 0.5) * sin(t * 6.0) * gr * 0.6)
    draw_polyline(spur, Color(0.030, 0.060, 0.070, farbe.a * 1.8), 1.8, true)


func _baue_staub(rng: RandomNumberGenerator) -> void:
    var weite := Rundum.FELD_RADIUS + UEBERSTAND
    _staub.resize(1600)
    _staub_takt.resize(1600)
    for i in 1600:
        _staub[i] = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) \
            * sqrt(rng.randf()) * weite
        _staub_takt[i] = rng.randf_range(0.15, 0.6)


## Ein Ort im Feld, gleichmaessig verteilt. `sqrt` ist noetig, weil sonst
## alles in die Mitte faellt - der Flaecheninhalt waechst mit dem Quadrat des
## Radius.
func _wuerfel_ort(rng: RandomNumberGenerator) -> Vector2:
    var weite := Rundum.FELD_RADIUS + UEBERSTAND
    return Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) \
        * sqrt(rng.randf()) * weite


## Wie hell der Kegel an dieser Stelle steht, 0 bis 1.
func _angeleuchtet(ort: Vector2) -> float:
    if licht_reichweite <= 0.0:
        return 0.0
    return Schlund.beleuchtung(licht_spitze, licht_richtung, licht_halbwinkel,
        licht_reichweite, ort, licht_rand_kern, licht_tiefe_kern) \
        * licht_schein


## Ob ein Ort schon aufgedeckt ist. Ohne Karte ist alles offen.
func _bekannt(ort: Vector2) -> bool:
    return karte == null or karte.ist_bekannt(ort)


## Was weiter weg ist als die Sicht, wird nicht gezeichnet.
##
## Bei einem Feld von 1500 Einheiten und einem Bild von 900 liegt das meiste
## ausserhalb. Ohne diese Frage zeichnete jedes Bild zweihundert Felsen, von
## denen zwanzig zu sehen sind.
func _im_blick(ort: Vector2, rand: float) -> bool:
    return ort.distance_squared_to(_blickmitte) \
        < (Rundum.SICHT + rand) * (Rundum.SICHT + rand)


var _blickmitte := Vector2.ZERO


func _draw() -> void:
    # Die Kamera sagt, wo hingesehen wird. Sie steht als Geschwister in der
    # Szene; ihr Ort ist der Mittelpunkt des Bildes.
    var kamera := get_parent().get_node_or_null("Kamera") as Camera2D
    if kamera != null:
        _blickmitte = kamera.position
    _zeichne_rippel()
    for lage in TIEFE:
        _zeichne_felsen(lage)
        _zeichne_bewuchs(lage)
    _zeichne_kleinzeug()
    _zeichne_schlote()
    _zeichne_schatten()
    _zeichne_staub()
    _zeichne_funde()
    # **Zuletzt.** Der Nebel deckt ab, was darunter liegt, statt dass jedes
    # Stueck Grund selbst nachsieht, ob es sich zeigen darf. Ein Fels liegt
    # ueber vier Felder verteilt; wer ihn feldweise ausblendet, sieht ihn
    # springen. Ueber das Boot und die Raeuber legt er sich nicht - die
    # zeichnen Geschwister, die nach diesem Knoten an der Reihe sind.
    _zeichne_nebel()


func _zeichne_rippel() -> void:
    if _rippel_netz.is_empty():
        return
    RenderingServer.canvas_item_add_triangle_array(
        get_canvas_item(), _rippel_netz, _rippel_ecken, _rippel_farben)


func _zeichne_felsen(lage: int) -> void:
    var kraft: float = LAGEN_KRAFT[lage]
    for f in _felsen:
        # Der Rand haengt an der Groesse des Felsens: ein Massiv von
        # zweihundertfuenfzig Einheiten Radius, das mit hundertvierzig
        # gekeult wird, springt am Bildrand ins Bild.
        if int(f[&"lage"]) != lage \
                or not _im_blick(f[&"ort"], float(f[&"weit"]) + 40.0):
            continue
        _kuppel(f, kraft)


## Ein Fels als **Kuppel**, nicht als Loch mit einem Kringel darum.
##
## **Der Grund, warum das umgebaut wurde.** Ein Fels war eine fast schwarze
## Flaeche, eine helle Umrisslinie, eine zweite Linie weiter innen (die
## Schulter) und ein paar Risse. Vier Linien je Stein, vierzig Steine im
## Bild - und die Welt sah aus wie eine Zeichnung mit dem Lineal. Was fehlte,
## waren nicht Einzelheiten, sondern **Uebergaenge**: zwischen Stein und
## Wasser, zwischen Kuppe und Flanke lag jedes Mal eine Kante.
##
## Jetzt ist es ein Netz aus drei Ringen, in **einem** Aufruf:
##
## * die **Schulter** (0,58) — die Kuppe, die dem Licht zugewandt ist,
## * die **Kante** (1,0) — die Flanke, die ins Dunkle abfaellt,
## * der **Saum** (1,12) — ausserhalb der Kante, auf Deckung null.
##
## Der Saum ist der Trick: er macht aus der Silhouette einen Verlauf. Ein
## dunkler Koerper in truebem Wasser hat keine Schnittkante, sondern einen
## Hof, in dem er verschwindet - und ohne ihn sitzt der Stein wie
## ausgeschnitten auf dem Wasser, ganz gleich wie schoen seine Flaeche ist.
##
## Die Schulterlinie ist damit **weg**, und das ist kein Verlust: sie war die
## Kante zwischen Kuppe und Flanke, und jetzt ist da ein Verlauf. Wer eine
## Kante zeichnet, wo ein Uebergang hingehoert, verdoppelt den Umriss.
func _kuppel(f: Dictionary, kraft: float) -> void:
    var umriss: PackedVector2Array = f[&"umriss"]
    var schulter: PackedVector2Array = f[&"schulter"]
    var saum: PackedVector2Array = f[&"saum"]
    var n := umriss.size()
    if n < 3 or schulter.size() != n or saum.size() != n:
        return

    var mitte: Vector2 = f[&"ort"]
    var zum_licht := Vector2.UP
    if licht_reichweite > 0.0:
        var d := licht_spitze - mitte
        if d.length_squared() > 1.0:
            zum_licht = d.normalized()
    var hell := _angeleuchtet(mitte)

    # Der Grundton des Steins. Er deckt ab, was hinter ihm liegt - dunkler
    # als das Wasser davor, wie das Sediment im Schlund.
    var dunkel := Color(0.016, 0.030, 0.038, 1.0)
    # Wieviel Licht die Kuppe hoechstens annimmt. Quadriert angewandt, weil
    # ein linearer Verlauf ueber eine ganze Flaeche wie ein Farbverlauf
    # aussieht und nicht wie Licht: Licht faellt steil ab, sobald eine
    # Flaeche sich wegdreht.
    var gewinn := (0.9 + 3.4 * hell) * kraft

    var ecken := PackedVector2Array()
    var farben := PackedColorArray()

    # Die Nabe: die Kuppe in ihrer vollen Helligkeit.
    ecken.append(mitte)
    farben.append(_steinfarbe(dunkel, gewinn, 1.0))

    for i in n:
        var zu_ihm: float = maxf(0.0,
            (umriss[i] - mitte).normalized().dot(zum_licht))
        ecken.append(schulter[i])
        farben.append(_steinfarbe(dunkel, gewinn, 0.35 + 0.65 * zu_ihm))
    for i in n:
        var zu_ihm: float = maxf(0.0,
            (umriss[i] - mitte).normalized().dot(zum_licht))
        ecken.append(umriss[i])
        farben.append(_steinfarbe(dunkel, gewinn * 0.30, 0.20 * zu_ihm))
    for i in n:
        ecken.append(saum[i])
        farben.append(Color(dunkel.r, dunkel.g, dunkel.b, 0.0))

    var netz := PackedInt32Array()
    for i in n:
        var j := (i + 1) % n
        # Nabe -> Schulter
        netz.append_array([0, 1 + i, 1 + j])
        # Schulter -> Kante
        netz.append_array([1 + i, 1 + n + i, 1 + n + j])
        netz.append_array([1 + i, 1 + n + j, 1 + j])
        # Kante -> Saum
        netz.append_array([1 + n + i, 1 + 2 * n + i, 1 + 2 * n + j])
        netz.append_array([1 + n + i, 1 + 2 * n + j, 1 + n + j])
    RenderingServer.canvas_item_add_triangle_array(
        get_canvas_item(), netz, ecken, farben)

    # **Die Kante bleibt, aber nur wo Licht darauf faellt.**
    #
    # Sie stand rundum auf vierundvierzig Prozent, und damit war sie das
    # Erste, was man von einem Stein sah - im Bild vierzig helle Kringel auf
    # schwarzem Wasser. Ein Fels im Dunkeln hat keinen leuchtenden Rand; was
    # ihn im Dunkeln zeigt, ist der Saum. Der Rand ist die Antwort auf das
    # Licht und sonst nichts.
    #
    # Gerechnet je Eckpunkt und nicht als Bogen: der Umriss ist unrund, und
    # ein Bogen ueber eine unrunde Form legt den Glanz daneben.
    # **Was aufhaelt, bleibt sichtbar.** Nur die vorderste Lage stoesst das
    # Boot ab; ein Hindernis, das man erst sieht, wenn man es anleuchtet,
    # ist keine Entscheidung, sondern ein Hinterhalt aus Stein. Die Kulisse
    # dahinter darf dagegen im Dunkeln verschwinden - dorthin faehrt
    # niemand.
    var grundrand := 0.19 if bool(f.get(&"fest", false)) else 0.05
    var rand := grundrand + 0.52 * hell
    var glanz := PackedVector2Array()
    for i in n:
        if (umriss[i] - mitte).normalized().dot(zum_licht) > 0.10:
            glanz.append(umriss[i])
        else:
            if glanz.size() > 1:
                _kantenzug(glanz, rand * kraft)
            glanz = PackedVector2Array()
    if glanz.size() > 1:
        _kantenzug(glanz, rand * kraft)

    # Risse nur, wo das Licht sie findet. Ein Riss, den man auch im Dunkeln
    # sieht, ist aufgemalt.
    if hell > 0.05:
        for riss in f[&"risse"]:
            draw_polyline(riss, Color(0.32, 0.56, 0.60,
                0.30 * hell * kraft), 1.0, true)


## Ein Stueck Lichtkante: ein weiter blasser Hof und ein schmaler Kern
## darauf. Dieselbe Machart wie bei den Leuchtroehren - eine Linie mit einem
## Hof hat einen Uebergang, eine ohne hat eine Kante.
func _kantenzug(punkte: PackedVector2Array, staerke: float) -> void:
    draw_polyline(punkte, Color(0.42, 0.68, 0.74,
        staerke * 0.22), 5.0, true)
    draw_polyline(punkte, Color(0.72, 0.90, 0.94, staerke), 1.4, true)


## Der Ton eines Steins bei gegebener Zuwendung zum Licht.
func _steinfarbe(dunkel: Color, gewinn: float, zu: float) -> Color:
    var st := 1.0 + gewinn * zu * zu
    return Color(dunkel.r * st, dunkel.g * st, dunkel.b * st, 1.0)


func _zeichne_bewuchs(lage: int) -> void:
    var kraft: float = LAGEN_KRAFT[lage]
    for b in _bewuchs:
        if int(b[&"lage"]) != lage or not _im_blick(b[&"ort"], 60.0):
            continue
        # Unter dem Nebel waere er ohnehin nicht zu sehen - das spart in der
        # ersten Minute den groessten Teil der Zeichenaufrufe.
        if not _bekannt(b[&"ort"]):
            continue
        var p: Vector2 = b[&"ort"]
        var gr: float = b[&"gross"]
        var farbe: Color = b[&"farbe"]
        var atem := 0.5 + 0.5 * sin(zeit * float(b[&"takt"])
            + float(b[&"phase"]))
        var arme: PackedFloat32Array = b[&"arme"]
        var dreh: float = b[&"dreh"]
        # Im Licht bluehen sie auf: bis zum Vierfachen der Ruhedeckung.
        # Der Anteil ist bewusst gross - eine Aenderung, die man suchen
        # muss, ist keine.
        # Das Nachleuchten steht hier statt der reinen Beleuchtung: es ist
        # ihr Hoechstwert der letzten Sekunden und faellt danach ab.
        var a := (0.16 + 0.10 * atem) * kraft \
            * (1.0 + 3.0 * float(b[&"glut"]))
        match int(b[&"art"]):
            0:
                _faecher(p, gr, farbe, a, dreh, arme, atem)
            1:
                _roehren(p, gr, farbe, a, dreh, arme, atem)
            _:
                _schopf(p, gr, farbe, a, dreh, arme, atem)


## Ein Faecher: Rippen aus einem Punkt, aussen durch einen Bogen verbunden.
func _faecher(p: Vector2, r: float, farbe: Color, a: float, dreh: float,
        arme: PackedFloat32Array, atem: float) -> void:
    var saum := PackedVector2Array()
    var spitzen: Array[Vector2] = []
    var winkel := PackedFloat32Array()
    for i in arme.size():
        var t := float(i) / float(maxi(1, arme.size() - 1))
        var w := dreh + lerpf(-1.05, 1.05, t)
        var laenge := r * arme[i] * (0.92 + 0.08 * atem)
        var spitze := p + Vector2.RIGHT.rotated(w) * laenge
        spitzen.append(spitze)
        winkel.append(w)
        saum.append(spitze)

    # **Erst die Haut, dann die Rippen.** Ein Faecher aus lauter Speichen ist
    # ein Sternchen; was ihn zur Gorgonie macht, ist das Gewebe dazwischen.
    # Es liegt unter den Rippen, damit die Rippen es teilen und nicht
    # umgekehrt.
    #
    # **Und die Haut hat einen Verlauf.** Sie war eine Flaeche in einer
    # Farbe: am Fuss so deckend wie an der Kante, und damit ein Papierfaecher
    # mit Speichen darauf. Gewebe zwischen zwei Rippen ist dort dicht, wo es
    # ansetzt, und laeuft zur Kante hin aus - ein Faecher, der an seinem
    # Rand endet, statt dort abgeschnitten zu sein.
    if spitzen.size() > 2:
        var haut := PackedVector2Array([p])
        var toene := PackedColorArray([
            Color(farbe.r, farbe.g, farbe.b, a * 0.52)])
        for sp in spitzen:
            haut.append(sp)
            toene.append(Color(farbe.r, farbe.g, farbe.b, a * 0.10))
        draw_polygon(haut, toene)

    for i in spitzen.size():
        # **Auch die Rippe laeuft aus.** Mit einer Farbe gezogen hat sie an
        # der Spitze eine Kappe, und zehn Kappen auf einem Bogen sind ein
        # Zahnrad. Zwei Farben auf demselben Zug kosten nichts weiter.
        draw_polyline_colors(PackedVector2Array([p, spitzen[i]]),
            PackedColorArray([
                Color(farbe.r, farbe.g, farbe.b, a),
                Color(farbe.r, farbe.g, farbe.b, a * 0.34)]), 1.1, true)
        # **Und jede zweite Rippe gabelt sich.** Eine Koralle waechst
        # verzweigt; gerade Speichen sind ein Rad. An jeder Rippe gemessen
        # kostete es acht Prozent Bildrate (6,5 auf 6,0) - bei bis zu zehn
        # Rippen sind das zwanzig zusaetzliche Striche je Faecher. An jeder
        # zweiten ist im Bild kein Unterschied zu sehen, und die Haelfte ist
        # wieder da.
        if i % 2 == 0:
            var ast := p.lerp(spitzen[i], 0.68)
            for seite: float in [-0.55, 0.55]:
                draw_line(ast, ast + Vector2.RIGHT.rotated(winkel[i] + seite)
                    * r * 0.22, Color(farbe.r, farbe.g, farbe.b, a * 0.8),
                    1.0, true)

    if saum.size() > 2:
        draw_polyline(saum, Color(farbe.r, farbe.g, farbe.b, a * 0.7),
            1.0, true)


## Roehren: kurze Stiele mit einem Ring obendrauf.
func _roehren(p: Vector2, r: float, farbe: Color, a: float, dreh: float,
        arme: PackedFloat32Array, atem: float) -> void:
    for i in arme.size():
        var w := dreh + TAU * float(i) / float(arme.size())
        var fuss := p + Vector2.RIGHT.rotated(w) * r * 0.34
        var kopf := fuss + Vector2.RIGHT.rotated(w + 0.3) \
            * r * arme[i] * (0.7 + 0.06 * atem)
        # Der Stiel ist Kalk und traegt nichts; die Krone ist das Tier.
        draw_line(fuss, kopf, Color(farbe.r * 0.8, farbe.g * 0.8,
            farbe.b * 0.8, a * 0.9), 1.8, true)
        draw_circle(kopf, r * 0.13, Color(farbe.r, farbe.g, farbe.b, a * 0.5))
        draw_arc(kopf, r * 0.13, 0.0, TAU, 8,
            Color(farbe.r, farbe.g, farbe.b, a * 1.4), 1.0, true)
        # Die Fangarme, quer zur Roehre - daran erkennt man einen
        # Roehrenwurm und nicht einen Nagel mit Kopf.
        for seite: float in [-1.1, 1.1]:
            draw_line(kopf, kopf + Vector2.RIGHT.rotated(w + 0.3 + seite)
                * r * 0.20, Color(farbe.r, farbe.g, farbe.b, a * 1.1),
                1.0, true)


## Ein Schopf: gebogene Halme aus einem Punkt, die sich in der Stroemung
## wiegen. Der einzige Bewuchs, der sich sichtbar bewegt - mehr Bewegung im
## Hintergrund zieht den Blick von den Raeubern ab.
func _schopf(p: Vector2, r: float, farbe: Color, a: float, dreh: float,
        arme: PackedFloat32Array, atem: float) -> void:
    for i in arme.size():
        var w := dreh + lerpf(-0.9, 0.9, float(i) / float(maxi(1,
            arme.size() - 1)))
        var wiege := sin(zeit * 0.7 + float(i) * 0.8 + p.x * 0.01) * 0.22
        var halm := PackedVector2Array()
        for j in 6:
            var t := float(j) / 5.0
            halm.append(p + Vector2.RIGHT.rotated(w + wiege * t * t)
                * r * arme[i] * t)
        # **Unten dick, oben duenn.** Alles hier war einen Pixel breit, und
        # ein Halm von gleicher Staerke ueber die ganze Laenge ist ein
        # Strich. `draw_polyline` kann nicht verjuengen - zwei Zuege
        # koennen es: die unteren zwei Drittel breiter, der Rest schmal.
        draw_polyline(halm.slice(0, 4),
            Color(farbe.r, farbe.g, farbe.b, a), 2.0, true)
        draw_polyline(halm.slice(3, 6),
            Color(farbe.r, farbe.g, farbe.b, a * 0.85), 1.0, true)
        # Eine leuchtende Spitze. Viele Hydroiden der Tiefsee tragen sie,
        # und im Bild ist sie das, was aus einem Grashalm etwas Lebendiges
        # macht.
        draw_circle(halm[5], 1.2, Color(farbe.r, farbe.g, farbe.b, a * 1.8))


## Wie weit ein Schatten hinter seinem Fels liegt, als Vielfaches der
## Kegelreichweite, und wie dunkel er hoechstens wird.
const SCHATTEN_LAENGE := 0.85
const SCHATTEN_TIEFE := 0.62


## Was im Licht steht, wirft einen Schatten.
##
## **Der Grund war bisher gleichmaessig hell, wo der Kegel hinfiel** - ein
## Fels wurde angeleuchtet wie eine Flaeche, und dahinter blieb es genauso
## hell wie daneben. Damit war das Licht flach: es sagte, wie weit man
## sieht, aber nicht, was zwischen einem und der Ferne steht. Ein Schatten
## sagt beides auf einmal, und er bewegt sich mit dem Finger.
##
## **Nur die vorderste Lage wirft.** `fest` ist derselbe Fels, an dem das
## Boot anstoesst; was dahinter liegt, ist Kulisse in einer anderen Ebene
## und haette dort nichts zu verdecken.
##
## **Und nur der Grund liegt im Schatten, nie ein Tier.** Der Kegel ist ein
## Licht ueber dem Grund, die Raeuber schwimmen in der Wassersaeule darueber
## - ein Fels am Boden verdunkelt sie also nicht. Das ist nicht nur
## Physik, sondern Zusage 2: was hell gezeichnet wird, macht Schaden. Ein
## Tier im Fels-Schatten saehe dunkel aus und braennte weiter, und das waere
## eine zweite Wahrheit ueber dasselbe Licht.
func _zeichne_schatten() -> void:
    if licht_reichweite <= 0.0:
        return
    for f in _felsen:
        if not bool(f[&"fest"]):
            continue
        var ort: Vector2 = f[&"ort"]
        var breit := float(f[&"weit"]) * 0.82
        if not _im_blick(ort, breit + 40.0):
            continue
        if not _bekannt(ort):
            continue
        var hell := _angeleuchtet(ort)
        if hell <= 0.02:
            continue
        var weg := ort - licht_spitze
        var fern := weg.length()
        # Steht die Spitze im Fels, gibt es keine Richtung zum Werfen.
        if fern <= breit * 1.05:
            continue
        var richtung := weg / fern
        # Der Halbwinkel, unter dem der Fels von der Spitze aus erscheint -
        # daraus die beiden Beruehrpunkte der Sichtlinien.
        var spreiz := asin(clampf(breit / fern, 0.0, 0.999))
        var laenge := licht_reichweite * SCHATTEN_LAENGE
        var links := richtung.rotated(-spreiz)
        var rechts := richtung.rotated(spreiz)
        var nah := sqrt(maxf(fern * fern - breit * breit, 1.0))
        var a := licht_spitze + links * nah
        var b := licht_spitze + rechts * nah
        # Der Schatten wird nach hinten breiter, weil die Lichtquelle ein
        # Punkt ist: dieselben zwei Linien, nur weitergezogen.
        var c := licht_spitze + rechts * (nah + laenge)
        var d := licht_spitze + links * (nah + laenge)
        var tiefe := SCHATTEN_TIEFE * hell
        # Zwei Lagen: der Kern gleich hinter dem Fels ist dunkler als das
        # ausgefranste Ende. Ein Schatten mit **einer** Deckung endet an
        # einer Kante, und eine Kante im Wasser gibt es nicht.
        var mitte_c := licht_spitze + rechts * (nah + laenge * 0.34)
        var mitte_d := licht_spitze + links * (nah + laenge * 0.34)
        draw_colored_polygon(PackedVector2Array([a, b, mitte_c, mitte_d]),
            Color(NEBEL_FARBE.r, NEBEL_FARBE.g, NEBEL_FARBE.b, tiefe))
        draw_colored_polygon(
            PackedVector2Array([mitte_d, mitte_c, c, d]),
            Color(NEBEL_FARBE.r, NEBEL_FARBE.g, NEBEL_FARBE.b, tiefe * 0.42))
        # Der Saum: wo das Licht am Fels vorbeistreift, steht die hellste
        # Kante des Bildes. Ohne ihn wirkt der Fels ausgeschnitten.
        #
        # Er laeuft auf dem **echten Umriss** und nicht auf einer Sehne
        # quer durch den Fels. Der erste Anlauf zog eine gerade Linie durch
        # die Mitte, und im Bild sah das aus wie ein Kratzer auf dem Stein -
        # eine Kante gehoert an den Rand, sonst ist sie keine.
        var umriss: PackedVector2Array = f[&"umriss"]
        var saum := Color(0.62, 0.88, 0.92, 0.34 * hell)
        var zug := PackedVector2Array()
        for j in umriss.size() + 1:
            var e := umriss[j % umriss.size()]
            # Zur Spitze hin zeigende Kante: das ist die beschienene Seite.
            if (e - ort).normalized().dot(richtung) < -0.12:
                zug.append(e)
            elif zug.size() >= 2:
                draw_polyline(zug, saum, 2.0, true)
                zug = PackedVector2Array()
            else:
                zug = PackedVector2Array()
        if zug.size() >= 2:
            draw_polyline(zug, saum, 2.0, true)


## Wie weit der Schwebstoff je Bogenmass Abtrieb zur Seite wandert.
const STAUB_HUB := 340.0


func _zeichne_staub() -> void:
    for i in _staub.size():
        if not _im_blick(_staub[i], 30.0) or not _bekannt(_staub[i]):
            continue
        # **Der Schwebstoff treibt mit.** Von oben gesehen zeigt sich eine
        # Stroemung nicht an Schlieren am Horizont, sondern daran, dass
        # alles Lose in eine Richtung wandert - und das ist hier der
        # Meeresschnee. Der Ausschlag kommt aus demselben Abtrieb, der den
        # Kegel dreht.
        var p := _staub[i] + Vector2(
            sin(zeit * _staub_takt[i] + float(i)) * 6.0
                + abtrieb * STAUB_HUB,
            cos(zeit * _staub_takt[i] * 0.7 + float(i)) * 6.0)
        # **Schwebstoff im Strahl.** Ausserhalb kaum zu sehen, im Kegel ein
        # Flirren - das ist es, was einen Lichtkegel im Wasser ueberhaupt
        # sichtbar macht, und der Kegel selbst zeichnet nur seine Form.
        var hell := _angeleuchtet(p)
        var farbe := Color(0.62, 0.86, 0.92, 0.10 + 0.45 * hell)
        # Jede dritte Flocke ist ein kurzer Strich statt eines Punktes -
        # Meeresschnee ist Flocke und Faden, und aus zwei Formen wird ein
        # Gewimmel statt eines Rasters.
        if i % 3 == 0:
            var zug := Vector2.RIGHT.rotated(float(i) * 2.3
                + zeit * _staub_takt[i] * 0.3) * (2.4 + 2.6 * hell)
            draw_line(p - zug, p + zug, farbe, 1.0, true)
        else:
            draw_circle(p, 0.9 + 0.8 * hell, farbe)


# --- Der Nebel ---------------------------------------------------------------

## Wie dicht der Nebel ueber einem unbekannten Feld liegt.
##
## **Nicht ganz undurchsichtig.** Bei voller Deckung ist die Grenze zwischen
## bekannt und unbekannt eine harte Linie, und dahinter ist nichts - man
## faehrt gegen eine Wand aus Schwarz. Bei 0.93 schimmern grosse Felsen als
## Ahnung durch: man sieht, dass dort etwas steht, aber nicht was, und genau
## das ist der Grund hinzufahren.
const NEBEL_DECKUNG := 0.93

const NEBEL_FARBE := Color(0.004, 0.014, 0.020)


## Der Nebel als ein Dreiecksnetz mit Farbe an den Ecken.
##
## **Der erste Anlauf zeichnete je unbekanntes Feld ein Rechteck.** Das war
## billig und sah aus wie ein Tabellenblatt: die Kante zwischen bekannt und
## unbekannt lief in rechten Winkeln durchs Bild, und man las das Raster
## statt die Karte. Eine zweite Helligkeitsstufe fuer Randfelder half nicht -
## sie machte aus einer Treppe zwei.
##
## Hier bekommt stattdessen jede **Ecke** des Rasters ihre Deckung aus den
## vier Feldern, die sie beruehrt, und die Flaeche dazwischen wird
## interpoliert. Damit laeuft die Deckung ueber eine ganze Feldbreite aus,
## und die Rasterkante verschwindet, obwohl das Raster dasselbe geblieben
## ist.
##
## Alles in **einem** Aufruf. `canvas_item_add_triangle_array` nimmt ein
## ganzes Netz; vierhundert einzelne `draw_rect` waeren vierhundert
## Zeichenaufrufe je Bild, und der Grund hat schon genug davon.
func _zeichne_nebel() -> void:
    if karte == null:
        return
    var weit := Rundum.SICHT + Karte.ZELLE * 2.0
    var von := karte.raster(_blickmitte - Vector2.ONE * weit)
    var bis := karte.raster(_blickmitte + Vector2.ONE * weit)
    var nx := bis.x - von.x + 1
    var ny := bis.y - von.y + 1
    if nx < 1 or ny < 1:
        return

    # Die Deckung an jeder Ecke: der Anteil der vier angrenzenden Felder,
    # die noch unbekannt sind.
    var ecken := PackedVector2Array()
    var farben := PackedColorArray()
    var deckungen := PackedFloat32Array()
    ecken.resize((nx + 1) * (ny + 1))
    farben.resize(ecken.size())
    deckungen.resize(ecken.size())
    for j in ny + 1:
        for i in nx + 1:
            var zelle := Vector2i(von.x + i, von.y + j)
            var unbekannt := 0
            for dy in 2:
                for dx in 2:
                    if not karte.zelle_bekannt(zelle - Vector2i(dx, dy)):
                        unbekannt += 1
            var d := NEBEL_DECKUNG * float(unbekannt) * 0.25
            var k := j * (nx + 1) + i
            ecken[k] = karte.mitte_von(zelle) - Vector2.ONE * (Karte.ZELLE * 0.5)
            deckungen[k] = d
            farben[k] = Color(NEBEL_FARBE.r, NEBEL_FARBE.g, NEBEL_FARBE.b, d)

    var netz := PackedInt32Array()
    for j in ny:
        for i in nx:
            var a := j * (nx + 1) + i
            var b := a + 1
            var c := a + nx + 1
            var d := c + 1
            # Ein Feld, an dessen vier Ecken nichts liegt, wird auch nicht
            # gezeichnet - das ist der ganze bekannte Teil der Karte.
            if deckungen[a] <= 0.0 and deckungen[b] <= 0.0 \
                    and deckungen[c] <= 0.0 and deckungen[d] <= 0.0:
                continue
            netz.append_array([a, b, d, a, d, c])
    if netz.is_empty():
        return
    RenderingServer.canvas_item_add_triangle_array(
        get_canvas_item(), netz, ecken, farben)


# --- Fundstellen -------------------------------------------------------------

## Wieviele Fundstellen im Feld liegen.
##
## Sie sind der Grund, ueberhaupt in eine Richtung zu fahren, in der gerade
## kein Raeuber steht. Ohne sie belohnt das Aufdecken nur sich selbst.
## **Wenige.** Bei vierunddreissig standen auf einem Bild sieben davon, und
## ein Fund, von dem der naechste schon zu sehen ist, ist kein Fund, sondern
## eine Reihe.
const FUNDE := 20

## Wie nah man heran muss. Grosszuegig - ein Fund, den man knapp verfehlt,
## fuehlt sich nach einem Fehler des Spiels an und nicht nach einem eigenen.
const FUND_REICHWEITE := 52.0

## Was ein Fund einbringt.
##
## **Punkte, kein Naehrstoff** - aus demselben Grund wie bei der Kette
## (Zusage 16): Einkommen und Kosten der Kolonie sind aneinander gekoppelt,
## und eine zweite Quelle daneben verschoebe die ganze Wirtschaft. Ein Fund
## ist eine Bestmarke, keine Waehrung.
const FUND_PUNKTE := 250


func _baue_funde(rng: RandomNumberGenerator) -> void:
    var versuche := 0
    while _funde.size() < FUNDE and versuche < FUNDE * 60:
        versuche += 1
        # Nicht bis an den Rand und nicht in die Mitte: die Mitte sieht man
        # in den ersten Sekunden ohnehin, und am Rand steht man mit dem
        # Ruecken zur Wand.
        var ort := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) \
            * sqrt(rng.randf_range(0.06, 1.0)) * (Rundum.FELD_RADIUS - 120.0)
        var frei := true
        for f in _funde:
            if Vector2(f[&"ort"]).distance_to(ort) < 430.0:
                frei = false
                break
        # Nicht in einem Felsen - sonst liegt er hinter einer Wand, durch die
        # man nicht kommt.
        for fels in _felsen:
            if bool(fels.get(&"fest", false)) \
                    and Riff.beruehrt(fels, ort, 70.0):
                frei = false
                break
        if not frei:
            continue
        _funde.append({
            &"ort": ort,
            &"dreh": rng.randf_range(0.0, TAU),
            &"geholt": false,
        })


## Die Fundstellen, die auf der Uebersichtskarte stehen duerfen: nur die,
## deren Feld schon aufgedeckt ist. Eine Karte, die zeigt, wo man noch nicht
## war, waere der Nebel umsonst.
func gesehene_funde(karte_: Karte) -> Array:
    var sicht: Array[Dictionary] = []
    for f in _funde:
        if karte_ != null and not karte_.ist_bekannt(f[&"ort"]):
            continue
        sicht.append(f)
    return sicht


func funde_gesamt() -> int:
    return _funde.size()


func funde_geholt() -> int:
    var n := 0
    for f in _funde:
        if bool(f[&"geholt"]):
            n += 1
    return n


## Der naechste Fund in Reichweite - oder ein leerer Ort, wenn keiner da ist.
##
## Nimmt ihn gleich mit: wer ihn nur meldet, muss ihn getrennt streichen, und
## dann gibt es zwei Stellen, die wissen, was schon geholt ist.
func hole_fund(ort: Vector2) -> Dictionary:
    for f in _funde:
        if bool(f[&"geholt"]):
            continue
        if Vector2(f[&"ort"]).distance_to(ort) > FUND_REICHWEITE:
            continue
        f[&"geholt"] = true
        # Der Wert steht am Fund und nicht beim Aufrufer: sonst muesste
        # `rundlauf.gd` eine Konstante aus dieser Datei kennen, und die
        # Frage, was ein Fund wert ist, haette zwei Antworten.
        var mit := f.duplicate()
        mit[&"punkte"] = FUND_PUNKTE
        return mit
    return {}


## Ein Fund: ein Sechseck aus Licht ueber einem Keim.
##
## Der geholte bleibt als leere Kontur stehen. Das ist die Landkarte, die man
## sich erfaehrt - eine Stelle, an der man schon war, sieht anders aus als
## eine, an der man noch nicht war.
func _zeichne_funde() -> void:
    for f in _funde:
        var p: Vector2 = f[&"ort"]
        if not _im_blick(p, 60.0) or not _bekannt(p):
            continue
        var geholt := bool(f[&"geholt"])
        var dreh: float = f[&"dreh"]
        var puls := 0.5 + 0.5 * sin(zeit * 2.4 + dreh)
        var farbe := Color(0.42, 0.56, 0.60) if geholt \
            else Color(1.0, 0.84, 0.52)
        var a := 0.22 if geholt else (0.55 + 0.35 * puls)
        var r := 26.0 if geholt else 24.0 + 4.0 * puls
        var sechseck := PackedVector2Array()
        for i in 7:
            sechseck.append(p + Vector2.RIGHT.rotated(
                dreh + TAU * float(i) / 6.0) * r)
        draw_polyline(sechseck, Color(farbe.r, farbe.g, farbe.b, a), 1.6, true)
        if geholt:
            continue
        # Drei Speichen nach innen und ein Kern - er ist das, was man
        # anfaehrt, und muss im Dunkeln aus der Ferne zu sehen sein.
        for i in 3:
            var w := dreh + TAU * float(i) / 3.0
            draw_line(p + Vector2.RIGHT.rotated(w) * r * 0.42,
                p + Vector2.RIGHT.rotated(w) * r * 0.86,
                Color(farbe.r, farbe.g, farbe.b, a * 0.7), 1.2, true)
        draw_circle(p, 4.0 + 1.6 * puls,
            Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.30 * puls))
        # **Ein Lichtsee, kein Ring.**
        #
        # Hier stand ein duenner Kreisbogen vom 1,9fachen Radius. Zwei Dinge
        # stimmten daran nicht: eine mathematisch runde Linie in einer Welt
        # aus unrunden Formen faellt als Bedienoberflaeche auf, und sie sagt
        # das Falsche - ein Fund ist ein Keim, der glimmt, und ein Glimmen
        # hat einen Rand, an dem es aufhoert, aber keine Kante.
        #
        # Gestapelte Kreise mit nach aussen fallender Deckung, dieselbe
        # Machart wie der Hof um ein Tier. Weiter als der Ring war, damit
        # der Schein aus dem Dunkeln lockt statt den Fund zu umranden.
        for i in 4:
            var t := float(i + 1) / 4.0
            draw_circle(p, r * (0.9 + 1.6 * t), Color(farbe.r, farbe.g,
                farbe.b, (0.055 + 0.030 * puls) * (1.0 - t) * 0.8))
