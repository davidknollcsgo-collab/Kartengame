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
var _neue_art := -1
var _verdient := 0
var _zeit := 0.0
var _meldung := ""
var _meldung_leben := 0.0

## Tippziel des Koloniknopfs, in Bildschirmkoordinaten. `wache.gd` fragt es
## ab, statt selbst zu rechnen - so gibt es genau eine Stelle, an der steht,
## wo der Knopf liegt.
var _kolonieknopf := Rect2()

## Ankuendigung einer neuen Abschnittsregel. Steht laenger als eine Meldung,
## weil sie erklaert, warum sich das Spiel gerade anders anfuehlt.
var _abschnitt := -1
var _abschnitt_leben := 0.0

## Die Mutationen der laufenden Welle. `wache.gd` setzt sie; der Kopf zeigt
## sie als Band unter der Wellennummer. Eine Mutation, die man erst merkt,
## wenn die Brut faellt, ist keine Abwechslung, sondern eine Falle.
var mutationen := PackedInt32Array()
var _neue_mutation := -1

## Einstieg. Ein Satz zur Zeit, mitten im Spiel statt als Textwand davor -
## wer eine Anleitung lesen muss, bevor er etwas anfassen darf, faengt bei
## einem Einminutenspiel gar nicht erst an.
const EINSTIEG: PackedStringArray = [
    "Hold your finger on the screen and sweep the light cone.",
    "Whatever stands in the light burns. The cone holds only a few at once.",
    "Let nothing reach the brood - those eggs below are what you guard.",
    "Between waves: tap the niches to place guard polyps.",
    "And in the trench below, your colony grows.",
]
var _einstieg := -1

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
    _neue_art = -1
    _abschnitt_leben = 5.0


## Kuendigt eine Art an, die zum ersten Mal auftritt.
##
## Dieselbe Tafel wie beim Abschnitt, nur mit anderem Inhalt. Eine Regel, die
## man sich erspielen muss, ist bei einem Gegner, der nach vierzig Sekunden
## bei der Brut steht, keine Regel, sondern eine Falle.
func zeige_art(art: int) -> void:
    _neue_art = art
    _neue_mutation = -1
    _abschnitt_leben = 5.0


## Kuendigt eine Mutation an, die zum ersten Mal auftritt. Dieselbe Tafel.
func zeige_mutation(m: int) -> void:
    _neue_mutation = m
    _neue_art = -1
    _abschnitt_leben = 5.0


## Zeigt den Einstiegssatz mit dieser Nummer, oder -1 fuer keinen.
func zeige_einstieg(schritt: int) -> void:
    _einstieg = schritt if schritt >= 0 and schritt < EINSTIEG.size() else -1


func kolonieknopf_bei(bildschirm: Vector2) -> bool:
    return _bauphase and not _ende and _kolonieknopf.has_point(bildschirm)


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


func zeige_ende(gewonnen: bool, nummer: int, verdient: int) -> void:
    _ende = true
    _gewonnen = gewonnen
    _sitzung = false
    _welle = nummer
    _verdient = verdient


## Das Ende einer Sitzung - kein Verlust, sondern ein Punkt zum Aufhoeren.
## Bewusst anders gefaerbt und anders formuliert als der Fall der Brut: wer
## gerade fuenf Wellen gehalten hat, darf das nicht wie eine Niederlage lesen.
func zeige_sitzungsende(naechste: int, verdient: int) -> void:
    _ende = true
    _gewonnen = false
    _sitzung = true
    _welle = naechste
    _verdient = verdient


## Eine aufsteigende Zahl am Ort des Treffers. Die einzige Stelle, an der das
## HUD Spielkoordinaten kennt - deshalb wird hier umgerechnet.
func zeige_ausbeute(welt: Vector2, wert: int) -> void:
    if _ausbeuten.size() > 40:
        return
    _ausbeuten.append({&"ort": welt, &"wert": wert, &"leben": 0.9})


func _zeichne() -> void:
    var breite := _flaeche.size.x
    var hoehe := _flaeche.size.y

    _kopfzeile(breite)
    _schwebende_zahlen()

    if _bauphase and not _ende:
        _kolonieknopf_zeichnen(breite, hoehe)
        _bauhinweis(breite, hoehe)
    else:
        _kolonieknopf = Rect2()
    if _ende:
        _endschirm(breite, hoehe)

    if _meldung_leben > 0.0:
        var f := clampf(_meldung_leben / 0.8, 0.0, 1.0)
        _text(Vector2(breite * 0.5, 118.0), _meldung, 17,
            Color(0.62, 0.98, 0.86, f), true)

    if _abschnitt_leben > 0.0:
        _abschnittstafel(breite, hoehe)
    elif _einstieg >= 0 and not _ende:
        _einstiegszeile(breite, hoehe)


## Ein Satz, unten, ohne Kasten. Er soll begleiten, nicht unterbrechen.
func _einstiegszeile(breite: float, hoehe: float) -> void:
    var puls := 0.6 + 0.4 * sin(_zeit * 2.0)
    var y := hoehe * 0.24
    _text(Vector2(breite * 0.5, y), EINSTIEG[_einstieg], 16,
        Color(0.80, 0.94, 0.98, puls), true)


## Zwei Zeilen in der Bildmitte: der Name des Abschnitts und was er aendert.
func _abschnittstafel(breite: float, hoehe: float) -> void:
    var f := clampf(_abschnitt_leben / 1.2, 0.0, 1.0)
    var mitte := Vector2(breite * 0.5, hoehe * 0.34)
    var kasten := Rect2(RAND, mitte.y - 54.0, breite - RAND * 2.0, 96.0)

    var titel := Regeln.name_von(_abschnitt).to_upper()
    var zeile := Regeln.hinweis(_abschnitt)
    var rahmen := Color(0.42, 0.86, 0.92, 0.34 * f)
    var farbe := Color(0.72, 0.96, 1.0, f)
    if _neue_art >= 0:
        var a := Arten.farbe(_neue_art)
        titel = "NEW: %s" % Arten.name_von(_neue_art).to_upper()
        zeile = Arten.regel(_neue_art)
        rahmen = Color(a.r, a.g, a.b, 0.45 * f)
        farbe = Color(a.r, a.g, a.b, f)
    elif _neue_mutation >= 0:
        titel = "MUTATION: %s" % Mutationen.name_von(_neue_mutation).to_upper()
        zeile = Mutationen.hinweis(_neue_mutation)
        rahmen = Color(0.94, 0.62, 0.86, 0.45 * f)
        farbe = Color(0.96, 0.72, 0.90, f)

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

    _text(Vector2(breite - RAND - 120.0, 40.0), "NUTRIENTS", 13,
        Color(0.40, 0.66, 0.60))
    _text(Vector2(breite - RAND - 120.0, 66.0), Zahl.kurz(_naehrstoffe), 19,
        Color(0.52, 0.94, 0.80))

    if not _bauphase and not _ende:
        _text(Vector2(breite - RAND - 120.0, 108.0), "%d left" % _offen, 15,
            Color(0.62, 0.74, 0.80, 0.8))
    elif _bauphase and not _ende:
        # Derselbe Platz, andere Auskunft: in der Bauphase steht dort, was der
        # Tag noch hergibt. Ein Bonus, den man erst im Koloniebildschirm
        # entdeckt, wirkt nicht.
        var hinweis := Tagesstroemung.hinweis(Fortschritt.stand.stroemung_offen)
        if not hinweis.is_empty():
            _text(Vector2(breite - RAND - 120.0, 108.0), hinweis, 14,
                Color(0.52, 0.94, 0.80, 0.85))


func _schwebende_zahlen() -> void:
    var wandel := _flaeche.get_canvas_transform()
    for a in _ausbeuten:
        var f: float = a[&"leben"] / 0.9
        var ort: Vector2 = wandel * (a[&"ort"] as Vector2)
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


## Der Weg in die Kolonie. Steht nur zwischen den Wellen da - waehrend einer
## Welle gehoert der Bildschirm dem Schlund.
func _kolonieknopf_zeichnen(breite: float, hoehe: float) -> void:
    # Ueber der Brut, nicht darauf. Im ersten Bild lagen beide Tafeln genau
    # auf der Eierreihe - der Spieler sah in der Bauphase nicht, was er
    # verteidigt.
    _kolonieknopf = Rect2(RAND, hoehe - 410.0, breite - RAND * 2.0, 54.0)
    var puls := 0.5 + 0.5 * sin(_zeit * 1.8)
    _flaeche.draw_rect(_kolonieknopf, Color(0.05, 0.14, 0.18, 0.82))
    _flaeche.draw_rect(_kolonieknopf, Color(0.42, 0.86, 0.92, 0.28 + 0.2 * puls),
        false, 1.5)
    _text(_kolonieknopf.get_center() + Vector2(0.0, 6.0), "BUILD THE COLONY",
        17, Color(0.72, 0.94, 0.98), true)


func _bauhinweis(breite: float, hoehe: float) -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 2.4)
    # Ueber dem Knopf und ueber dem Waechter. Vorher lag die Tafel auf seinem
    # Kopf, davor auf der Brut - beides Dinge, die der Spieler in der Bauphase
    # sehen muss.
    var kasten := Rect2(RAND, hoehe - 500.0, breite - RAND * 2.0, 76.0)
    _flaeche.draw_rect(kasten, Color(0.03, 0.08, 0.10, 0.72))
    _flaeche.draw_rect(kasten, Color(0.26, 0.60, 0.66, 0.35), false, 1.4)

    var frei := _gebaut < Graben.NISCHEN.size()
    var kann := frei and _naehrstoffe >= _preis
    var zeile := "Tap a niche: guard polyp for %s" % Zahl.kurz(_preis)
    if not frei:
        zeile = "Every niche taken"
    elif not kann:
        zeile = "Guard polyp costs %s - %s short" % [Zahl.kurz(_preis),
            Zahl.kurz(_preis - _naehrstoffe)]

    _text(kasten.position + Vector2(18.0, 32.0), zeile, 16,
        Color(0.62, 0.90, 0.86) if kann else Color(0.50, 0.60, 0.66))
    _text(kasten.position + Vector2(18.0, 62.0),
        "Tap anywhere else to start wave %d" % _welle, 15,
        Color(0.78, 0.94, 0.98, 0.55 + 0.45 * puls))


func _endschirm(breite: float, hoehe: float) -> void:
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe), Color(0.01, 0.03, 0.05, 0.80))
    var mitte := Vector2(breite * 0.5, hoehe * 0.42)

    if _gewonnen:
        _text(mitte, "A FULL DESCENT", 30, Color(0.62, 0.98, 0.86), true)
        _text(mitte + Vector2(0.0, 44.0),
            "%d waves down. The trench turns over - deeper, not finished." % _welle,
            15, Color(0.66, 0.84, 0.88), true)
    elif _sitzung:
        _text(mitte, "SESSION HELD", 30, Color(0.62, 0.98, 0.86), true)
        _text(mitte + Vector2(0.0, 44.0),
            "%d waves in a row - next up is wave %d"
            % [Graben.WELLEN_JE_SITZUNG, _welle], 17,
            Color(0.66, 0.84, 0.88), true)
    else:
        _text(mitte, "THE BROOD HAS FALLEN", 30, Color(1.0, 0.52, 0.44), true)
        _text(mitte + Vector2(0.0, 44.0), "Wave %d" % _welle, 17,
            Color(0.72, 0.72, 0.76), true)

    _text(mitte + Vector2(0.0, 86.0),
        "%s nutrients harvested" % Zahl.kurz(_verdient), 17,
        Color(0.52, 0.94, 0.80), true)

    # Die Wertung steht genau hier, weil sie hier wirkt: im Moment des
    # Aufhoerens der Grund, es noch einmal zu versuchen.
    _grabenwertung(mitte + Vector2(0.0, 122.0))

    var puls := 0.5 + 0.5 * sin(_zeit * 2.6)
    var weiter := "Tap to continue the watch" if _sitzung \
        else "Tap for another run"
    # 196 und nicht 148: die Wertung darueber ist zwei Zeilen hoch, und die
    # zweite lag genau hier. Auf dem Bild sah es aus wie ein Schriftfehler.
    _text(mitte + Vector2(0.0, 196.0), weiter, 17,
        Color(0.82, 0.94, 0.98, 0.45 + 0.55 * puls), true)


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


func _text(wo: Vector2, was: String, groesse: int, farbe: Color,
        zentriert := false) -> void:
    var breite := _schrift.get_string_size(was, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse).x
    var ort := wo
    if zentriert:
        ort.x -= breite * 0.5
    # Schatten zuerst - heller Text auf bewegtem Wasser ist sonst stellenweise
    # unlesbar, und genau dort steht die Brutzahl.
    _flaeche.draw_string(_schrift, ort + Vector2(1.0, 1.0), was,
        HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(0.0, 0.0, 0.0, farbe.a * 0.7))
    _flaeche.draw_string(_schrift, ort, was, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse, farbe)
