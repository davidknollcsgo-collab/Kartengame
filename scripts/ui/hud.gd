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

var _welle := 1
var _brut := Graben.BRUT_LEBEN
var _naehrstoffe := 0
var _offen := 0
var _preis := Graben.polyp_kosten(0)
var _gebaut := 0
var _bauphase := true
var _ende := false
var _gewonnen := false
var _verdient := 0
var _zeit := 0.0
var _meldung := ""
var _meldung_leben := 0.0

## Tippziel des Koloniknopfs, in Bildschirmkoordinaten. `wache.gd` fragt es
## ab, statt selbst zu rechnen - so gibt es genau eine Stelle, an der steht,
## wo der Knopf liegt.
var _kolonieknopf := Rect2()

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
    for i in range(_ausbeuten.size() - 1, -1, -1):
        _ausbeuten[i][&"leben"] -= delta
        if _ausbeuten[i][&"leben"] <= 0.0:
            _ausbeuten.remove_at(i)
    _flaeche.queue_redraw()


## Kurze Rueckmeldung oben, etwa wenn eine Kammer fertig wird.
func melde(was: String) -> void:
    _meldung = was
    _meldung_leben = 3.0


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
    _welle = nummer
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


func _kopfzeile(breite: float) -> void:
    var balken := Rect2(0.0, 0.0, breite, 84.0)
    _flaeche.draw_rect(balken, Color(0.02, 0.05, 0.07, 0.55))
    _flaeche.draw_line(Vector2(0.0, 84.0), Vector2(breite, 84.0),
        Color(0.24, 0.56, 0.62, 0.35), 1.5)

    _text(Vector2(RAND, 36.0), "WELLE %d" % _welle, 20, Color(0.72, 0.94, 0.98))
    _text(Vector2(RAND, 64.0), "Abschnitt %d" % (Graben.abschnitt(_welle) + 1),
        14, Color(0.44, 0.66, 0.72))

    var mitte := breite * 0.5
    _text(Vector2(mitte - 40.0, 40.0), "BRUT", 13, Color(0.62, 0.52, 0.38))
    _text(Vector2(mitte - 40.0, 66.0), "%d / %d"
        % [_brut, Fortschritt.stand.brut_leben()], 19, Color(0.98, 0.80, 0.42))

    _text(Vector2(breite - RAND - 120.0, 40.0), "NAEHRSTOFF", 13,
        Color(0.40, 0.66, 0.60))
    _text(Vector2(breite - RAND - 120.0, 66.0), str(_naehrstoffe), 19,
        Color(0.52, 0.94, 0.80))

    if not _bauphase and not _ende:
        _text(Vector2(breite - RAND - 120.0, 108.0), "noch %d" % _offen, 15,
            Color(0.62, 0.74, 0.80, 0.8))


func _schwebende_zahlen() -> void:
    var wandel := _flaeche.get_canvas_transform()
    for a in _ausbeuten:
        var f: float = a[&"leben"] / 0.9
        var ort: Vector2 = wandel * (a[&"ort"] as Vector2)
        ort.y -= (1.0 - f) * 34.0
        _text(ort, "+%d" % a[&"wert"], 15,
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
    _text(_kolonieknopf.get_center() + Vector2(0.0, 6.0), "KOLONIE AUSBAUEN",
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
    var zeile := "Nische antippen: Wehrpolyp fuer %d" % _preis
    if not frei:
        zeile = "Alle Nischen besetzt"
    elif not kann:
        zeile = "Wehrpolyp kostet %d - noch %d fehlen" % [_preis, _preis - _naehrstoffe]

    _text(kasten.position + Vector2(18.0, 32.0), zeile, 16,
        Color(0.62, 0.90, 0.86) if kann else Color(0.50, 0.60, 0.66))
    _text(kasten.position + Vector2(18.0, 62.0),
        "Irgendwo sonst tippen startet Welle %d" % _welle, 15,
        Color(0.78, 0.94, 0.98, 0.55 + 0.45 * puls))


func _endschirm(breite: float, hoehe: float) -> void:
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe), Color(0.01, 0.03, 0.05, 0.80))
    var mitte := Vector2(breite * 0.5, hoehe * 0.42)

    if _gewonnen:
        _text(mitte, "DER GRABEN HAELT", 30, Color(0.62, 0.98, 0.86), true)
        _text(mitte + Vector2(0.0, 44.0),
            "Alle %d Wellen ueberstanden" % Graben.WELLEN_GESAMT, 17,
            Color(0.66, 0.84, 0.88), true)
    else:
        _text(mitte, "DIE BRUT IST GEFALLEN", 30, Color(1.0, 0.52, 0.44), true)
        _text(mitte + Vector2(0.0, 44.0), "Welle %d" % _welle, 17,
            Color(0.72, 0.72, 0.76), true)

    _text(mitte + Vector2(0.0, 86.0), "%d Naehrstoff geerntet" % _verdient, 17,
        Color(0.52, 0.94, 0.80), true)

    var puls := 0.5 + 0.5 * sin(_zeit * 2.6)
    _text(mitte + Vector2(0.0, 148.0), "Tippen fuer einen neuen Anlauf", 17,
        Color(0.82, 0.94, 0.98, 0.45 + 0.55 * puls), true)


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
