extends CanvasLayer

## Anzeige ueber dem Spiel.
##
## **Die wichtigste Zeile dieser Datei steht in `_ready()`.** Ein `Control`
## hat von Haus aus `MOUSE_FILTER_STOP` und verschluckt damit jede Beruehrung,
## bevor sie beim Spiel ankommt. Bei HYPHA hat genau das die gesamte Eingabe
## totgelegt, und kein Screenshot und kein Testschuss aus dem Code hat es
## gezeigt - nur ein echter Mausklick im Browser.

const RAND := 22.0

@onready var _flaeche: Control = $Flaeche

## Ob die laufende Welle eine Tagesstroemung ist. `wache.gd` setzt es beim
## Wellenstart - das HUD entscheidet nichts, es zeigt nur an.
var stroemung := false

var _welle := 1
var _brut := Graben.BRUT_LEBEN
var _naehrstoffe := 0
var _offen := 0
var _preis := Graben.polyp_kosten(0)
var _gebaut := 0
var _bauphase := true
var _ende := false
var _gewonnen := false
var _sitzung := false

## Welche Art die Tafel gerade ankuendigt, oder -1 fuer den Abschnitt.
var _verdient := 0

## Wieviele Raeuber diese Sitzung gekostet hat. Die zweite Zahl des
## Ergebnisses - Naehrstoff sagt, was man mitnimmt, und das hier, was man
## getan hat.
var _erlegt := 0
var _zeit := 0.0
var _meldung := ""
var _meldung_leben := 0.0

## Tippziel des Koloniknopfs, in Bildschirmkoordinaten. `wache.gd` fragt es
## ab, statt selbst zu rechnen - so gibt es genau eine Stelle, an der steht,
## wo der Knopf liegt.
var _kolonieknopf := Rect2()

## Der Knopf, der die Welle startet.
##
## **Vorher startete jeder Tipp neben einer Nische die Welle.** Das war
## bequem gedacht und in der Hand eine Falle: die Nischen sind Kreise von
## knapp vierzig Pixeln, und wer daneben tippt, steht sofort in der Welle -
## ohne Warnung, ohne Weg zurueck, mit dem Naehrstoff noch in der Tasche. Ein
## Fehlgriff darf keinen Zustandswechsel ausloesen, den man nicht
## rueckgaengig machen kann.
var _wellenknopf := Rect2()

## Ankuendigung einer neuen Abschnittsregel. Steht laenger als eine Meldung,
## weil sie erklaert, warum sich das Spiel gerade anders anfuehlt.
var _abschnitt := -1
var _abschnitt_leben := 0.0

## Die Mutationen der laufenden Welle. `wache.gd` setzt sie; der Kopf zeigt
## sie als Band unter der Wellennummer. Eine Mutation, die man erst merkt,
## wenn die Brut faellt, ist keine Abwechslung, sondern eine Falle.
var mutationen := PackedInt32Array()
var _neue_mutation := -1

## --- Der Blitz ---
##
## Ein kurzer Schleier ueber dem ganzen Bild. Er ist die einzige Rueckmeldung,
## die man auch dann noch mitbekommt, wenn der Daumen die halbe untere
## Bildhaelfte verdeckt - und genau dort steht die Brut.
##
## Sparsam einsetzen: was bei jedem Treffer blitzt, blitzt nach zehn Sekunden
## gar nicht mehr, weil das Auge es wegrechnet. Nur die Brut ist es wert.
var _blitz := 0.0
var _blitz_voll := 0.001
var _blitz_farbe := Color(1.0, 0.42, 0.34)


func blitze(farbe: Color, dauer: float) -> void:
    _blitz_farbe = farbe
    _blitz_voll = maxf(0.05, dauer)
    _blitz = _blitz_voll

## --- Der gefuehrte Einstieg ---
##
## Was gesagt wird, steht in `Lehrpfad`; hier steht nur, wie es aussieht.
## `_lehre` ist der Schritt, `_lehr_ort` der Weltpunkt, auf den der Ring
## zeigt (gesetzt von `wache.gd`, weil nur die Wache weiss, welche Knospe
## frei ist), und `_lehr_leben` zaehlt, wie lange dieser Schritt schon steht.
##
## **Die Tafel schrumpft.** Sie steht ihre ersten Sekunden voll da - Titel
## und Satz -, danach bleibt nur der Titel und der Ring. Ein Erklaertext, der
## stehenbleibt, bis man tut, was er sagt, wird nach einer halben Minute zum
## Moebel: man liest ihn nicht mehr und er nimmt trotzdem Platz weg. Der Ring
## dagegen darf bleiben, denn er zeigt und redet nicht.
var _lehre := -1
var _lehr_ort := Vector2.ZERO
var _lehr_leben := 0.0
const LEHRE_VOLL := 14.0

## Ob das Spiel angehalten ist. Siehe `wache.gd::pausiere()`.
var _pause := false

var _schrift: Font
var _ausbeuten: Array[Dictionary] = []


func _ready() -> void:
    # Nichts hier oben darf Beruehrungen abfangen - siehe oben.
    _flaeche.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flaeche.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flaeche.offset_left = 0.0
    _flaeche.offset_top = 0.0
    _flaeche.offset_right = 0.0
    _flaeche.offset_bottom = 0.0
    _flaeche.draw.connect(_zeichne)
    _schrift = ThemeDB.fallback_font


func _process(delta: float) -> void:
    _zeit += delta
    if _meldung_leben > 0.0:
        _meldung_leben -= delta
    if _abschnitt_leben > 0.0:
        _abschnitt_leben -= delta
    if _blitz > 0.0:
        _blitz -= delta
    if _lehre >= 0:
        _lehr_leben += delta
    for i in range(_ausbeuten.size() - 1, -1, -1):
        _ausbeuten[i][&"leben"] -= delta
        if _ausbeuten[i][&"leben"] <= 0.0:
            _ausbeuten.remove_at(i)
    _flaeche.queue_redraw()


## Kurze Rueckmeldung oben, etwa wenn eine Kammer fertig wird.
func melde(was: String) -> void:
    _meldung = was
    _meldung_leben = 3.0


## Kuendigt die Regel eines neuen Abschnitts an. Wer in Welle 31 ploetzlich im
## Dunkeln steht und nicht weiss warum, haelt es fuer einen Fehler.
func zeige_abschnitt(abschnitt: int) -> void:
    _abschnitt = abschnitt
    _neue_mutation = -1
    _abschnitt_leben = 5.0


## Kuendigt eine Mutation an, die zum ersten Mal auftritt. Dieselbe Tafel.
func zeige_mutation(m: int) -> void:
    _neue_mutation = m
    _abschnitt = -1
    _abschnitt_leben = 5.0


## Zeigt den Lehrschritt mit dieser Nummer, oder -1 fuer keinen. `ort` ist
## der Weltpunkt, auf den der Ring zeigt - er gilt nur fuer die Ziele, die
## einen brauchen, und wird sonst nicht angesehen.
func zeige_einstieg(schritt: int, ort := Vector2.ZERO) -> void:
    if schritt != _lehre:
        _lehr_leben = 0.0
    _lehre = schritt if Lehrpfad.gilt(schritt) else -1
    _lehr_ort = ort


func zeige_pause(an: bool) -> void:
    _pause = an
    _flaeche.queue_redraw()


## **Dieselben zwei Knoepfe wie in der Bauphase, auch auf dem Schlussbild.**
##
## Nach einem Fall ist die nuetzliche Handlung nicht "noch einmal", sondern
## "ausgeben, was du verdient hast, und dann noch einmal". Genau die stand
## nicht zur Verfuegung: das Schlussbild kannte einen einzigen Ausgang, und
## der fuehrte sofort in die naechste Welle. Wer besser werden wollte, musste
## erst wieder verlieren, um in die Kolonie zu kommen.
func kolonieknopf_bei(bildschirm: Vector2) -> bool:
    return (_bauphase or _ende) and _kolonieknopf.has_point(bildschirm)


func wellenknopf_bei(bildschirm: Vector2) -> bool:
    return (_bauphase or _ende) and _wellenknopf.has_point(bildschirm)


func setze_zahlen(brut: int, naehrstoffe: int, offen: int) -> void:
    _brut = brut
    _naehrstoffe = naehrstoffe
    _offen = offen


func zeige_welle(nummer: int, brut: int, naehrstoffe: int, offen: int) -> void:
    _welle = nummer
    _bauphase = false
    _ende = false
    setze_zahlen(brut, naehrstoffe, offen)


func zeige_bauphase(nummer: int, brut: int, naehrstoffe: int, preis: int,
        gebaut: int) -> void:
    _welle = nummer
    _bauphase = true
    _ende = false
    _preis = preis
    _gebaut = gebaut
    setze_zahlen(brut, naehrstoffe, 0)


func zeige_ende(gewonnen: bool, nummer: int, verdient: int, erlegt := 0) -> void:
    _ende = true
    _gewonnen = gewonnen
    _sitzung = false
    _welle = nummer
    _verdient = verdient
    _erlegt = erlegt


## Das Ende einer Sitzung - kein Verlust, sondern ein Punkt zum Aufhoeren.
## Bewusst anders gefaerbt und anders formuliert als der Fall der Brut: wer
## gerade fuenf Wellen gehalten hat, darf das nicht wie eine Niederlage lesen.
func zeige_sitzungsende(naechste: int, verdient: int, erlegt := 0) -> void:
    _ende = true
    _gewonnen = false
    _sitzung = true
    _welle = naechste
    _verdient = verdient
    _erlegt = erlegt


## Eine aufsteigende Zahl am Ort des Treffers. Die einzige Stelle, an der das
## HUD Spielkoordinaten kennt - deshalb wird hier umgerechnet.
## Wie nah zwei Ausbeuten sein muessen, um zu einer zusammenzufallen.
##
## Grosszuegig, und das ist Absicht: gezeichnet wird spaeter in den Rand
## hinein und unter die Kopfzeile geschoben, also liegen zwei Zahlen im Bild
## naeher beieinander als im Wasser. Bei 52 Pixeln stapelten sich am oberen
## Rand immer noch drei Posten uebereinander.
const AUSBEUTE_NAH := 140.0

func zeige_ausbeute(welt: Vector2, wert: int) -> void:
    # **Zusammenzaehlen statt stapeln.**
    #
    # In Welle 187 sterben Dutzende Raeuber im selben Augenblick am selben
    # Fleck. Vorher stand dort ein eigenes "+1.23B" je Tier, alle an
    # derselben Stelle uebereinander - im Bild ein unlesbarer Klumpen, aus dem
    # sich nicht einmal die Groessenordnung ablesen liess. Wer nah genug an
    # einer laufenden Zahl stirbt, wird jetzt dazugezaehlt: aus vierzig
    # Fetzen wird eine Zahl, und die sagt mehr als jeder einzelne Posten.
    for a in _ausbeuten:
        if (a[&"ort"] as Vector2).distance_to(welt) < AUSBEUTE_NAH:
            a[&"wert"] = int(a[&"wert"]) + wert
            a[&"leben"] = maxf(float(a[&"leben"]), 0.7)
            return
    if _ausbeuten.size() > 8:
        return
    _ausbeuten.append({&"ort": welt, &"wert": wert, &"leben": 0.9})


func _zeichne() -> void:
    var breite := _flaeche.size.x
    var hoehe := _flaeche.size.y

    # Der Blitz zuerst, damit die Kopfzeile darueber lesbar bleibt.
    if _blitz > 0.0:
        _blitzschleier(breite, hoehe)

    _kopfzeile(breite)
    _schwebende_zahlen()

    if _bauphase and not _ende:
        _kolonieknopf_zeichnen(breite, hoehe,
            "COLONY", "START WAVE %d" % _welle)
        _bauhinweis(breite, hoehe)
    elif not _ende:
        _kolonieknopf = Rect2()
        _wellenknopf = Rect2()
    if _ende:
        _endschirm(breite, hoehe)

    if _meldung_leben > 0.0:
        var f := clampf(_meldung_leben / 0.8, 0.0, 1.0)
        _text(Vector2(breite * 0.5, 118.0), _meldung, 17,
            Color(0.62, 0.98, 0.86, f), true)

    if _abschnitt_leben > 0.0:
        _abschnittstafel(breite, hoehe)
    elif _lehre >= 0 and not _ende and not Lehrpfad.in_der_kolonie(_lehre):
        _lehrtafel(breite, hoehe)

    # Ganz zuletzt, ueber allem: eine Pause, die man nicht sieht, ist ein
    # Absturz.
    if _pause:
        _pausenschleier(breite, hoehe)


## Die Pause.
##
## **Sie deckt ab, aber sie loescht nicht.** Ein schwarzer Vorhang waere die
## naheliegende Loesung und die falsche: wer zurueckkommt, will sehen, wo er
## stehengeblieben ist - wie viele Raeuber im Bild sind, wie es um die Brut
## steht. Der Schleier nimmt deshalb Kontrast weg statt Bild, und die Zeile
## darueber sagt in einem Wort, was zu tun ist.
func _pausenschleier(breite: float, hoehe: float) -> void:
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe),
        Color(0.020, 0.043, 0.058, 0.72))

    var mitte := Vector2(breite * 0.5, hoehe * 0.44)
    var atem := 0.5 + 0.5 * sin(_zeit * 1.6)

    # Zwei Balken - das Zeichen fuer Pause, das jeder kennt, und es ist in
    # zwei Rechtecken gezeichnet statt in einer Schrift, die es nicht gibt.
    for s_seite: float in [-1.0, 1.0]:
        _flaeche.draw_rect(Rect2(mitte.x + s_seite * 15.0 - 5.0, mitte.y - 26.0,
            10.0, 52.0), Color(0.62, 0.94, 1.0, 0.42 + 0.16 * atem))

    _text(Vector2(mitte.x, mitte.y + 66.0), "PAUSED", 22,
        Color(0.86, 0.98, 1.0, 0.92), true)
    _text(Vector2(mitte.x, mitte.y + 96.0), "Tap anywhere to go on", 14,
        Color(0.58, 0.80, 0.88, 0.70 + 0.20 * atem), true)


## Kein flaechiger Farbschleier, sondern ein Rand, der nach innen ausblutet.
## Ein gleichmaessiger Schleier ueber dem ganzen Bild nimmt einem die Sicht
## genau in dem Augenblick, in dem man sie am dringendsten braucht - der Rand
## sagt dasselbe und laesst die Mitte frei.
func _blitzschleier(breite: float, hoehe: float) -> void:
    var f := pow(clampf(_blitz / _blitz_voll, 0.0, 1.0), 0.7)
    var c := _blitz_farbe
    var tiefe := 130.0
    var voll := Color(c.r, c.g, c.b, 0.21 * f)
    var leer := Color(c.r, c.g, c.b, 0.0)

    # **Ein Verlauf je Kante, nicht sieben gestapelte Rechtecke.**
    #
    # Gestapelt ergab das im Bild sichtbare Streifen und an den Ecken, wo sich
    # zwei Stapel ueberlagerten, einen doppelt so hellen Klotz. `draw_polygon`
    # nimmt eine Farbe **je Eckpunkt** - damit ist der Verlauf eine einzige
    # Flaeche, und an den Ecken addieren sich zwei Dreiecke, die dort beide
    # schon fast durchsichtig sind.
    var kanten: Array[PackedVector2Array] = [
        PackedVector2Array([Vector2(0.0, 0.0), Vector2(breite, 0.0),
            Vector2(breite, tiefe), Vector2(0.0, tiefe)]),
        PackedVector2Array([Vector2(0.0, hoehe), Vector2(breite, hoehe),
            Vector2(breite, hoehe - tiefe), Vector2(0.0, hoehe - tiefe)]),
        PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, hoehe),
            Vector2(tiefe, hoehe), Vector2(tiefe, 0.0)]),
        PackedVector2Array([Vector2(breite, 0.0), Vector2(breite, hoehe),
            Vector2(breite - tiefe, hoehe), Vector2(breite - tiefe, 0.0)]),
    ]
    var farben := PackedColorArray([voll, voll, leer, leer])
    for k in kanten:
        _flaeche.draw_polygon(k, farben)


## --- Die Lehrtafel ---
##
## Ein Kasten mit Titel und Satz, und ein Ring auf dem Ding, um das es geht.
##
## **Sie steht oben, nicht unten.** Unten liegt der Daumen, unten liegt die
## Brut, unten liegt der Koloniekopf - alles, was der Einstieg zeigen will,
## steht im unteren Drittel, und eine Tafel davor waere ein Vorhang vor
## genau der Sache, die sie erklaert.
func _lehrtafel(breite: float, hoehe: float) -> void:
    var voll := clampf(1.0 - (_lehr_leben - LEHRE_VOLL) / 2.0, 0.0, 1.0)
    var titel := Lehrpfad.titel(_lehre)
    var satz := Lehrpfad.satz(_lehre)
    var puls := 0.5 + 0.5 * sin(_zeit * 2.0)

    _lehrring(breite, hoehe, puls)

    # Umbruch von Hand: `draw_string` bricht nicht, und ein `RichTextLabel`
    # waere ein zweiter Zeichenweg neben allem anderen hier.
    var zeilen := _umbrich(satz, breite - RAND * 2.0 - 28.0, 14)
    var hoch := 40.0 + (float(zeilen.size()) * 19.0 + 12.0) * voll
    var kasten := Rect2(RAND, 154.0, breite - RAND * 2.0, hoch)

    _flaeche.draw_rect(kasten, Color(0.035, 0.105, 0.135, 0.86))
    _flaeche.draw_rect(kasten, Color(0.42, 0.86, 0.92, 0.24 + 0.16 * puls),
        false, 1.4)
    # Ein Streifen links in der Farbe des Einstiegs - dieselbe Marke wie an
    # den Kammerzeilen, damit man die Tafel als Fuehrung erkennt und nicht
    # als Meldung.
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(0.52, 0.94, 0.86, 0.85))

    _text(Vector2(kasten.position.x + 16.0, kasten.position.y + 26.0),
        titel, 16, Color(0.62, 0.98, 0.86))
    # Schrittzaehler rechts: er sagt, dass das hier ein Anfang ist und ein
    # Ende hat. Ohne ihn weiss niemand, ob noch zwanzig davon kommen.
    _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 25.0),
        "%d/%d" % [_lehre + 1, Lehrpfad.anzahl()], 12,
        Color(0.52, 0.72, 0.78, 0.8), false, true)

    if voll <= 0.01:
        return
    for i in zeilen.size():
        _text(Vector2(kasten.position.x + 16.0,
            kasten.position.y + 50.0 + float(i) * 19.0),
            zeilen[i], 14, Color(0.80, 0.92, 0.96, voll))


## Der Ring auf dem Ding, um das es geht.
func _lehrring(breite: float, hoehe: float, puls: float) -> void:
    var ziel := Lehrpfad.ziel(_lehre)
    if ziel == Lehrpfad.Ziel.KEINS:
        return

    var wo := Vector2.ZERO
    var r := 34.0
    match ziel:
        Lehrpfad.Ziel.KEGEL:
            # Kein fester Punkt, sondern eine **Bewegung**: der Ring wandert
            # im unteren Drittel hin und her und zieht eine kurze Spur hinter
            # sich her. Ein stehender Kreis wuerde sagen "tippe hier", und
            # genau das ist es nicht - es ist "halte und zieh".
            # **Auf halber Hoehe, nicht unten.** Unten stehen der
            # Bauhinweis und der Koloniekopf; ein wandernder Ring darauf
            # sieht aus, als solle man die beiden Knoepfe streicheln.
            var t := sin(_zeit * 0.9)
            wo = Vector2(breite * (0.5 + 0.26 * t), hoehe * 0.46)
            for i in 6:
                var alt_t := sin((_zeit - float(i) * 0.09) * 0.9)
                var p := Vector2(breite * (0.5 + 0.26 * alt_t), hoehe * 0.46)
                _flaeche.draw_circle(p, 5.0 - float(i) * 0.6,
                    Color(0.72, 1.0, 0.92, 0.18 - float(i) * 0.026))
        # **Ein Knopf bekommt einen Rahmen, keinen Kreis.** Die beiden
        # Knoepfe sind gut vierhundert Pixel breit und achtundfuenfzig hoch;
        # ein Kreis darauf zeigt auf ihre Mitte und laesst offen, wie weit
        # das Ding reicht, auf das er zeigt. Ein Ring ist die richtige Form
        # fuer einen Punkt und die falsche fuer eine Flaeche.
        Lehrpfad.Ziel.KOLONIEKNOPF:
            _lehrrahmen(_kolonieknopf, puls)
            return
        Lehrpfad.Ziel.WELLENKNOPF:
            _lehrrahmen(_wellenknopf, puls)
            return
        _:
            wo = _auf_bildschirm(_lehr_ort)

    # Zwei Ringe, versetzt atmend: einer, der steht, und einer, der nach
    # aussen laeuft und ausblendet. Der laufende ist es, was den Blick holt -
    # ein pulsierender Kreis allein wird uebersehen.
    var welle := fmod(_zeit * 0.9, 1.0)
    _flaeche.draw_arc(wo, r * (1.0 + welle * 0.9), 0.0, TAU, 32,
        Color(0.72, 1.0, 0.92, 0.34 * (1.0 - welle)), 2.0, true)
    _flaeche.draw_arc(wo, r, 0.0, TAU, 32,
        Color(0.72, 1.0, 0.92, 0.34 + 0.26 * puls), 2.2, true)


## Derselbe Hinweis fuer eine Flaeche: ein Rahmen, der nach aussen laeuft und
## ausblendet, und einer, der steht.
func _lehrrahmen(kasten: Rect2, puls: float) -> void:
    if kasten.size.x <= 0.0:
        return
    var welle := fmod(_zeit * 0.9, 1.0)
    var weit := welle * 14.0
    _flaeche.draw_rect(kasten.grow(weit),
        Color(0.72, 1.0, 0.92, 0.30 * (1.0 - welle)), false, 2.0)
    _flaeche.draw_rect(kasten.grow(3.0),
        Color(0.72, 1.0, 0.92, 0.32 + 0.26 * puls), false, 2.2)


## Bricht einen Satz auf die gegebene Breite um. `draw_string` kann das
## nicht, und ein zweiter Zeichenweg nur fuer drei Zeilen Text waere die
## teurere Antwort.
func _umbrich(satz: String, breite: float, groesse: int) -> PackedStringArray:
    var zeilen := PackedStringArray()
    var laufend := ""
    for wort in satz.split(" "):
        var versuch := wort if laufend.is_empty() else laufend + " " + wort
        if _schrift.get_string_size(versuch, HORIZONTAL_ALIGNMENT_LEFT, -1,
                groesse).x > breite and not laufend.is_empty():
            zeilen.append(laufend)
            laufend = wort
        else:
            laufend = versuch
    if not laufend.is_empty():
        zeilen.append(laufend)
    return zeilen


## Zwei Zeilen in der Bildmitte: was sich an diesem Graben geaendert hat.
##
## **Nur noch Abschnitte und Mutationen, keine Arten mehr.** Hier stand
## einmal "NEW: VEILFORM" mit der Regel darunter, bevor das erste davon
## eintrat - und das nahm der Welle ihren Anfang. Was aus dem Dunkel kommt,
## soll man sehen und nicht vorher lesen. Beide verbliebenen Faelle sind
## keine Gegner, sondern die Bedingungen, unter denen man spielt.
func _abschnittstafel(breite: float, hoehe: float) -> void:
    var f := clampf(_abschnitt_leben / 1.2, 0.0, 1.0)
    var mitte := Vector2(breite * 0.5, hoehe * 0.34)
    var kasten := Rect2(RAND, mitte.y - 54.0, breite - RAND * 2.0, 96.0)

    var titel := ""
    var zeile := ""
    var rahmen := Color(0.42, 0.86, 0.92, 0.34 * f)
    var farbe := Color(0.72, 0.96, 1.0, f)
    if _neue_mutation >= 0:
        titel = "MUTATION: %s" % Mutationen.name_von(_neue_mutation).to_upper()
        zeile = Mutationen.hinweis(_neue_mutation)
        rahmen = Color(0.94, 0.62, 0.86, 0.45 * f)
        farbe = Color(0.96, 0.72, 0.90, f)
    elif _abschnitt >= 0:
        titel = Regeln.name_von(_abschnitt).to_upper()
        zeile = Regeln.hinweis(_abschnitt)
    else:
        return

    _flaeche.draw_rect(kasten, Color(0.02, 0.06, 0.09, 0.72 * f))
    _flaeche.draw_rect(kasten, rahmen, false, 1.4)
    _text(mitte - Vector2(0.0, 18.0), titel, 22, farbe, true)
    _text(mitte + Vector2(0.0, 16.0), zeile, 15,
        Color(0.66, 0.82, 0.88, f), true)


func _kopfzeile(breite: float) -> void:
    var balken := Rect2(0.0, 0.0, breite, 84.0)
    _flaeche.draw_rect(balken, Color(0.02, 0.05, 0.07, 0.55))
    _flaeche.draw_line(Vector2(0.0, 84.0), Vector2(breite, 84.0),
        Color(0.24, 0.56, 0.62, 0.35), 1.5)

    _text(Vector2(RAND, 36.0), "WAVE %d" % _welle, 20, Color(0.72, 0.94, 0.98))
    if stroemung and not _bauphase and not _ende:
        _text(Vector2(RAND, 64.0), "CURRENT x%d" % int(Tagesstroemung.FAKTOR),
            14, Color(0.52, 0.94, 0.80))
    else:
        _text(Vector2(RAND, 64.0), Regeln.name_von(Graben.abschnitt(_welle))
            + Graben.tiefe_zeichen(_welle), 14, Color(0.44, 0.66, 0.72))

    # Das Mutationsband. Es steht dort, wo sonst nichts steht, und ist die
    # einzige Stelle, an der man vor dem Ziehen sieht, was diese Welle anders
    # macht als die davor.
    if not mutationen.is_empty() and not _ende:
        var teile := PackedStringArray()
        for m in mutationen:
            teile.append(Mutationen.name_von(m).to_upper())
        _text(Vector2(RAND, 108.0), " / ".join(teile), 13,
            Color(0.94, 0.66, 0.88, 0.9))

    var mitte := breite * 0.5
    _text(Vector2(mitte - 40.0, 40.0), "BROOD", 13, Color(0.62, 0.52, 0.38))
    _text(Vector2(mitte - 40.0, 66.0), "%d / %d"
        % [_brut, Fortschritt.stand.brut_leben()], 19, Color(0.98, 0.80, 0.42))

    # Rechtsbuendig an der Randkante, nicht linksbuendig 120 Pixel davor: was
    # dort steht, ist mal "40" und mal "60.0T", und die Spalte soll bei beiden
    # am selben Rand enden.
    var rechts := breite - RAND
    _text(Vector2(rechts, 40.0), "NUTRIENTS", 13,
        Color(0.40, 0.66, 0.60), false, true)
    _text(Vector2(rechts, 66.0), Zahl.kurz(_naehrstoffe), 19,
        Color(0.52, 0.94, 0.80), false, true)

    if not _bauphase and not _ende:
        _text(Vector2(rechts, 108.0), "%d left" % _offen, 15,
            Color(0.62, 0.74, 0.80, 0.8), false, true)
    elif _bauphase and not _ende:
        # Derselbe Platz, andere Auskunft: in der Bauphase steht dort, was der
        # Tag noch hergibt. Ein Bonus, den man erst im Koloniebildschirm
        # entdeckt, wirkt nicht.
        var hinweis := Tagesstroemung.hinweis(Fortschritt.stand.stroemung_offen)
        if not hinweis.is_empty():
            _text(Vector2(rechts, 108.0), hinweis, 14,
                Color(0.52, 0.94, 0.80, 0.85), false, true)


## Weltpunkt zu Bildschirmpunkt.
##
## **`Control.get_canvas_transform()` ist die falsche Frage.** Sie liefert die
## Verschiebung der CanvasLayer, in der das Bedienbild selbst haengt - und die
## ist die Einheitsabbildung, weil das HUD sich nicht mitbewegen soll. Was
## gebraucht wird, ist die Abbildung der **Kamera**, und die haengt am
## Viewport.
##
## Der Fehler war lange unsichtbar, weil die schwebenden Zahlen an den
## Bildrand geklemmt werden: sie standen also da, nur nie ueber dem Tier, das
## gestorben war. Aufgefallen ist er erst, als der Lehrring auf eine Knospe
## zeigen sollte und gar nicht im Bild auftauchte - der wird nicht geklemmt.
func _auf_bildschirm(welt: Vector2) -> Vector2:
    return _flaeche.get_viewport().get_canvas_transform() * welt


func _schwebende_zahlen() -> void:
    for a in _ausbeuten:
        var f: float = a[&"leben"] / 0.9
        var ort: Vector2 = _auf_bildschirm(a[&"ort"] as Vector2)
        ort.y -= (1.0 - f) * 34.0
        # In den Rand hinein, nicht darueber hinaus. Ein Raeuber, der an der
        # Grabenwand stirbt, hinterliess sonst ein halbes "+4" am Bildrand -
        # im Bild sah es aus wie ein Textfehler.
        ort.x = clampf(ort.x, RAND + 12.0, _flaeche.size.x - RAND - 12.0)
        # Unter die Kopfzeile, nicht hinein: dort standen die Zahlen sonst
        # auf "BROOD" und "WAVE".
        # Unter das Mutationsband, nicht darauf: dort stand die Ausbeute
        # sonst auf "PLATED" und beides war unlesbar.
        ort.y = maxf(ort.y, 152.0)
        _text(ort, "+" + Zahl.kurz(a[&"wert"]), 15,
            Color(0.52, 0.94, 0.80, f), true)


## --- Die Bauphase ---
##
## Zwei Knoepfe **nebeneinander am unteren Rand** und eine Zeile oben, die
## sagt, was eine Knospe kostet.
##
## **Vorher standen drei Kaesten uebereinander in der unteren Bildhaelfte** -
## und genau dort haengen die Knospen an den Ranken. Vier der acht
## Tippflaechen lagen unter einem Kasten: sichtbar, gemeint, und nicht
## erreichbar. Ein Bedienelement, das ein anderes verdeckt, ist schlimmer
## als eines, das fehlt, denn der Spieler haelt sich fuer zu ungeschickt.
##
## Unten am Rand liegt nichts als der Grund; dort ist Platz, und dort liegt
## der Daumen ohnehin.
##
## **Der Wellenstart ist ein Knopf.** Er war "tipp irgendwohin", und das ist
## der bequemste Weg, ein Spiel unfair zu machen: neben eine Knospe getippt,
## und die Welle laeuft - ohne Warnung und ohne Weg zurueck.
const KNOPF_HOCH := 58.0
const KNOPF_LUECKE := 10.0


func _kolonieknopf_zeichnen(breite: float, hoehe: float, links_text: String,
        rechts_text: String) -> void:
    var y := hoehe - KNOPF_HOCH - 26.0
    var weit := breite - RAND * 2.0 - KNOPF_LUECKE
    # Der Wellenstart ist die Haupthandlung dieser Phase und bekommt den
    # groesseren Anteil; die Kolonie ist der Umweg und bekommt den kleineren.
    var links_weit := weit * 0.42

    _kolonieknopf = Rect2(RAND, y, links_weit, KNOPF_HOCH)
    _flaeche.draw_rect(_kolonieknopf, Color(0.05, 0.14, 0.18, 0.88))
    _flaeche.draw_rect(_kolonieknopf, Color(0.42, 0.86, 0.92, 0.30), false, 1.4)
    _text(_kolonieknopf.get_center() + Vector2(0.0, 6.0), links_text,
        17, Color(0.72, 0.94, 0.98), true)

    var puls := 0.5 + 0.5 * sin(_zeit * 1.8)
    _wellenknopf = Rect2(RAND + links_weit + KNOPF_LUECKE, y,
        weit - links_weit, KNOPF_HOCH)
    _flaeche.draw_rect(_wellenknopf, Color(0.08, 0.26, 0.28, 0.92))
    _flaeche.draw_rect(_wellenknopf, Color(0.52, 0.94, 0.86, 0.42 + 0.30 * puls),
        false, 1.8)
    _text(_wellenknopf.get_center() + Vector2(0.0, 7.0),
        rechts_text, 19, Color(0.84, 1.0, 0.94), true)


## Was eine Knospe kostet - eine Zeile unter der Kopfzeile, wo sie nichts
## verdeckt. Sie ist Auskunft, kein Bedienelement, und braucht deshalb keinen
## Kasten und keinen Platz in der unteren Bildhaelfte.
func _bauhinweis(breite: float, hoehe: float) -> void:
    var frei := _gebaut < Graben.NISCHEN.size()
    var kann := frei and _naehrstoffe >= _preis
    var zeile := "Tap a bud on the vines - guard polyp for %s" % Zahl.kurz(_preis)
    if not frei:
        zeile = "Every bud has a polyp"
    elif not kann:
        zeile = "Guard polyp costs %s - %s short" % [Zahl.kurz(_preis),
            Zahl.kurz(_preis - _naehrstoffe)]

    _text(Vector2(breite * 0.5, 132.0), zeile, 15,
        Color(0.62, 0.90, 0.86) if kann else Color(0.50, 0.60, 0.66), true)


## --- Das Schlussbild ---
##
## **Es war eine Wand aus sechs zentrierten Zeilen.** Titel, Welle, Ausbeute,
## Rang, ein Trostabsatz und "Tap for another run" - alles untereinander,
## alles mittig, alles ungefaehr gleich wichtig. Und es hatte genau einen
## Ausgang, der sofort in die naechste Welle fuehrte.
##
## Beides ist am Punkt des Verlierens genau falsch herum. Was man in diesem
## Augenblick wissen will, ist **was der Lauf gebracht hat** - das sind zwei
## Zahlen, keine sechs Zeilen -, und was man tun will, ist **besser werden**.
## Die nuetzliche Handlung nach einem Fall ist der Ausbau, nicht der sofortige
## nachste Versuch; sie stand nicht zur Wahl.
##
## Jetzt: eine Karte mit zwei grossen Kacheln, darunter dieselben zwei
## Knoepfe wie in der Bauphase - Kolonie links, weiter rechts.
func _endschirm(breite: float, hoehe: float) -> void:
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe), Color(0.01, 0.03, 0.05, 0.84))

    var titel := "THE BROOD FELL"
    var unter := "Wave %d  ·  %s" % [_welle,
        Regeln.name_von(Graben.abschnitt(_welle))]
    var ton := Color(1.0, 0.62, 0.52)
    if _gewonnen:
        titel = "A FULL DESCENT"
        unter = "%d waves down. The trench turns over - deeper, not finished." % _welle
        ton = Color(0.62, 0.98, 0.86)
    elif _sitzung:
        titel = "SESSION HELD"
        unter = "%d waves in a row - next up is wave %d" \
            % [Graben.WELLEN_JE_SITZUNG, _welle]
        ton = Color(0.62, 0.98, 0.86)

    var karte := Rect2(RAND, hoehe * 0.20, breite - RAND * 2.0, 342.0)
    _flaeche.draw_rect(karte, Color(0.030, 0.078, 0.098, 0.92))
    _flaeche.draw_rect(karte, Color(ton.r, ton.g, ton.b, 0.34), false, 1.6)
    _flaeche.draw_rect(Rect2(karte.position, Vector2(karte.size.x, 3.0)),
        Color(ton.r, ton.g, ton.b, 0.85))

    var mitte_x := karte.get_center().x
    _text(Vector2(mitte_x, karte.position.y + 50.0), titel, 26, ton, true)
    var unterzeilen := _umbrich(unter, karte.size.x - 40.0, 14)
    for i in unterzeilen.size():
        _text(Vector2(mitte_x, karte.position.y + 76.0 + float(i) * 19.0),
            unterzeilen[i], 14, Color(0.68, 0.82, 0.86), true)

    # Zwei Kacheln: was der Lauf eingebracht hat und was er gekostet hat.
    # Nebeneinander und gross - eine Zahl in einer Zeile Fliesstext ist ein
    # Wort, eine Zahl in einer Kachel ist ein Ergebnis.
    var kachel_y := karte.position.y + 116.0
    var kachel_b := (karte.size.x - 52.0) * 0.5
    _kachel(Rect2(karte.position.x + 18.0, kachel_y, kachel_b, 84.0),
        Zahl.kurz(_verdient), "NUTRIENTS", Color(0.52, 0.94, 0.80))
    _kachel(Rect2(karte.position.x + 34.0 + kachel_b, kachel_y, kachel_b, 84.0),
        Zahl.kurz(_erlegt), "RAIDERS BURNED", Color(0.72, 0.90, 0.98))

    # Die Wertung steht genau hier, weil sie hier wirkt: im Augenblick des
    # Aufhoerens der Grund, es noch einmal zu versuchen.
    _grabenwertung(Vector2(mitte_x, kachel_y + 126.0))

    # **Was jetzt passiert, muss dastehen.** Zwischen zwei Sitzungen aendert
    # sich dreierlei auf einmal: die Brut ist wieder voll, die Wehrpolypen
    # sind weg, und der Naehrstoff bleibt.
    var nachher := "Brood whole again, vines bare - polyps last one session, nutrients stay."
    if not (_gewonnen or _sitzung):
        nachher = "The colony keeps every nutrient it earned. Spend it before you go back down."
    var zeilen := _umbrich(nachher, karte.size.x - 40.0, 13)
    for i in zeilen.size():
        _text(Vector2(mitte_x, karte.end.y - 20.0
            - float(zeilen.size() - 1 - i) * 18.0), zeilen[i], 13,
            Color(0.58, 0.76, 0.82), true)

    _kolonieknopf_zeichnen(breite, hoehe, "COLONY",
        "GO ON" if _sitzung or _gewonnen else "DIVE AGAIN")


## Eine Ergebniskachel: eine grosse Zahl mit einem kleinen Wort darunter.
func _kachel(kasten: Rect2, wert: String, wort: String, farbe: Color) -> void:
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.07))
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.24), false, 1.3)
    var mitte := kasten.get_center()
    _text(Vector2(mitte.x, mitte.y + 4.0), wert, 28, farbe, true)
    _text(Vector2(mitte.x, kasten.end.y - 12.0), wort, 11,
        Color(0.52, 0.70, 0.76), true)


## Der eigene Platz und der Naechste, den man einholen kann.
func _grabenwertung(wo: Vector2) -> void:
    var tiefe: int = Fortschritt.stand.hoechste_welle
    var platz := Geister.platz(tiefe)
    var gesamt := Geister.zahl() + 1
    _text(wo, "Rank %d of %d in the trench" % [platz, gesamt], 16,
        Color(0.72, 0.86, 0.92), true)

    var vor := Geister.naechster_vor(tiefe)
    var name: String = vor[&"name"]
    if name.is_empty():
        _text(wo + Vector2(0.0, 24.0), "Nobody has gone deeper.", 14,
            Color(0.62, 0.92, 0.84), true)
        return
    var abstand: int = int(vor[&"tiefe"]) - tiefe
    _text(wo + Vector2(0.0, 24.0),
        "%s is %d waves ahead of you" % [name, maxi(1, abstand)], 14,
        Color(0.56, 0.74, 0.80), true)


## `rechtsbuendig` setzt `wo` als **rechte** Kante statt als linke.
##
## Gebraucht wird das oben rechts: dort stehen Zahlen und Hinweise
## unterschiedlicher Laenge in einer Spalte, und links auszurichten heisst,
## sich auf die laengste festzulegen. Die Tagesstroemung ("Day current x2 -
## 3 left") lief so aus dem Bild.
func _text(wo: Vector2, was: String, groesse: int, farbe: Color,
        zentriert := false, rechtsbuendig := false) -> void:
    var breite := _schrift.get_string_size(was, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse).x
    var ort := wo
    if zentriert:
        ort.x -= breite * 0.5
    elif rechtsbuendig:
        ort.x -= breite
    # Schatten zuerst - heller Text auf bewegtem Wasser ist sonst stellenweise
    # unlesbar, und genau dort steht die Brutzahl.
    _flaeche.draw_string(_schrift, ort + Vector2(1.0, 1.0), was,
        HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(0.0, 0.0, 0.0, farbe.a * 0.7))
    _flaeche.draw_string(_schrift, ort, was, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse, farbe)
