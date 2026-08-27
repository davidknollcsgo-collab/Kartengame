extends CanvasLayer

## Der Blick nach unten: die Kolonie als senkrechter Schnitt durch den Graben.
##
## Keine Szene fuer sich, sondern eine Ebene ueber der Schlundwache. Der
## Waechter sitzt am oberen Ende desselben Grabens - man dreht nur den Blick.
## Das spart Szenenwechsel, Ladezeit und die Frage, wo der Spieler gerade ist.
##
## Gezeichnet wie das HUD: eine Flaeche, ein `_draw()`, Tippziele als
## Rechtecke. Ein Baum aus Control-Knoten waere mehr Verwaltung und weniger
## Freiheit fuer die Optik - und die Optik ist hier die halbe Miete.

signal geschlossen

const RAND := 18.0
const KOPF := 96.0
const FUSS := 78.0
const BAND := 116.0
const LUECKE := 10.0

const GRUND := Color(0.020, 0.052, 0.070)
const BAND_FARBE := Color(0.055, 0.115, 0.140)
const BAND_KANTE := Color(0.16, 0.38, 0.44)
const SCHRIFT := Color(0.82, 0.94, 0.96)
const LEISE := Color(0.46, 0.64, 0.70)
const NAEHR := Color(0.52, 0.94, 0.80)
const SPERRE := Color(0.62, 0.52, 0.48)

## Eine Farbe je Kammer, in der Reihenfolge von `Kammern.Kammer`. Sie taucht
## im Sinnbild, im Balken und in der Stufenzahl auf - dieselbe Kammer ist
## ueberall dieselbe Farbe.
const FARBEN: PackedColorArray = [
    Color(0.42, 0.88, 1.00),   ## Leuchtorgan
    Color(0.52, 0.94, 0.80),   ## Zuchtkammer
    Color(0.98, 0.80, 0.42),   ## Brutkammer
    Color(0.62, 0.82, 0.98),   ## Filterbecken
    Color(0.86, 0.68, 0.96),   ## Tiefenschacht
]

@onready var _flaeche: Control = $Flaeche

var _schrift: Font
var _zeit := 0.0
var _baender: Array[Rect2] = []
var _schliessen := Rect2()
var _gedrueckt := -1
var _meldung := ""
var _meldung_leben := 0.0


func _ready() -> void:
    _schrift = ThemeDB.fallback_font
    _flaeche.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flaeche.offset_left = 0.0
    _flaeche.offset_top = 0.0
    _flaeche.offset_right = 0.0
    _flaeche.offset_bottom = 0.0
    # Diese Ebene *soll* Beruehrungen fangen - sie ist der Bildschirm, nicht
    # eine Anzeige darueber. Das ist der Gegenfall zum HUD, wo genau das der
    # Fehler war.
    _flaeche.mouse_filter = Control.MOUSE_FILTER_STOP
    _flaeche.draw.connect(_zeichne)
    _flaeche.gui_input.connect(_eingabe)
    hide()


func oeffne() -> void:
    show()
    _meldung = ""
    _meldung_leben = 0.0
    _flaeche.queue_redraw()


func _process(delta: float) -> void:
    if not visible:
        return
    _zeit += delta
    if _meldung_leben > 0.0:
        _meldung_leben -= delta
    _flaeche.queue_redraw()


# --- Eingabe ---------------------------------------------------------------

func _eingabe(ereignis: InputEvent) -> void:
    var ort := Vector2.ZERO
    var gedrueckt := false
    if ereignis is InputEventScreenTouch:
        ort = ereignis.position
        gedrueckt = ereignis.pressed
    elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
        ort = ereignis.position
        gedrueckt = ereignis.pressed
    else:
        return

    if not gedrueckt:
        _gedrueckt = -1
        return

    if _schliessen.has_point(ort):
        geschlossen.emit()
        hide()
        return

    for i in _baender.size():
        if _baender[i].has_point(ort):
            _gedrueckt = i
            _versuche_ausbau(i)
            return


func _versuche_ausbau(kammer: int) -> void:
    var stand: KolonieStand = Fortschritt.stand
    var grund := stand.hindernis(kammer)
    if not grund.is_empty():
        # Der Grund wird angezeigt, nicht verschwiegen. Ein Knopf, der nur
        # grau ist, laesst den Spieler raten.
        _zeige(grund)
        return
    if stand.starte_bau(kammer, Time.get_unix_time_from_system()):
        Fortschritt.sichere()
        Fortschritt.stand_geaendert.emit()
        _zeige("%s wird gegraben" % Kammern.name_von(kammer))


func _zeige(was: String) -> void:
    _meldung = was
    _meldung_leben = 2.4


# --- Zeichnen --------------------------------------------------------------

func _zeichne() -> void:
    var breite := _flaeche.size.x
    var hoehe := _flaeche.size.y
    var stand: KolonieStand = Fortschritt.stand
    var jetzt := Time.get_unix_time_from_system()

    # Deckend, nicht durchscheinend. Bei 0.94 schien der Lichtkegel der
    # Schlundwache durch die Kammern und die alte Naehrstoffzahl des HUD stand
    # neben der neuen - zwei Bildschirme uebereinander statt einem.
    _flaeche.draw_rect(Rect2(0.0, 0.0, breite, hoehe), GRUND)
    _grabenwand(breite, hoehe)
    _kopfzeile(breite, stand)

    _baender.clear()
    var verfuegbar := hoehe - KOPF - FUSS - 24.0
    var passt := BAND
    var gebraucht := float(Kammern.zahl()) * (BAND + LUECKE)
    if gebraucht > verfuegbar:
        passt = verfuegbar / float(Kammern.zahl()) - LUECKE
        gebraucht = verfuegbar

    # Auf hohen Bildschirmen bleibt Platz uebrig. Der Block sitzt dann mittig
    # statt oben - sonst klebt die Kolonie am Kopf und darunter gaehnt der
    # halbe Bildschirm.
    var y := KOPF + 12.0 + maxf(0.0, (verfuegbar - gebraucht) * 0.5)

    for k in Kammern.zahl():
        var kasten := Rect2(RAND, y, breite - RAND * 2.0, passt)
        _baender.append(kasten)
        _kammer(kasten, k, stand, jetzt)
        y += passt + LUECKE

    _fusszeile(breite, hoehe)

    if _meldung_leben > 0.0:
        var f := clampf(_meldung_leben / 0.6, 0.0, 1.0)
        _text(Vector2(breite * 0.5, hoehe - FUSS - 16.0), _meldung, 16,
            Color(0.88, 0.96, 1.0, f), true)


## Angedeutete Felswand links und rechts, damit der Bildschirm im Graben
## bleibt und nicht wie ein aufgesetztes Menue wirkt.
func _grabenwand(breite: float, hoehe: float) -> void:
    for seite: float in [0.0, 1.0]:
        var punkte := PackedVector2Array()
        var x0: float = seite * breite
        var richtung: float = 1.0 if seite < 0.5 else -1.0
        punkte.append(Vector2(x0, 0.0))
        for i in 15:
            var t := float(i) / 14.0
            var tief := RAND * 0.62 * (1.0 + 0.5 * sin(t * 9.0 + seite * 3.0))
            punkte.append(Vector2(x0 + richtung * tief, t * hoehe))
        punkte.append(Vector2(x0, hoehe))
        _flaeche.draw_colored_polygon(punkte, Color(0.045, 0.075, 0.095))


func _kopfzeile(breite: float, stand: KolonieStand) -> void:
    _text(Vector2(RAND, 34.0), "KOLONIE", 21, SCHRIFT)
    _text(Vector2(RAND, 58.0), "Tiefste Welle %d von %d"
        % [stand.hoechste_welle, Graben.WELLEN_GESAMT], 14, LEISE)

    var rechts := breite - RAND
    _text(Vector2(rechts, 34.0), str(stand.naehrstoffe), 21, NAEHR, false, true)
    var strom := stand.je_stunde()
    var zeile := "Naehrstoff" if strom <= 0.0 else "Naehrstoff  +%d/h" % int(strom)
    _text(Vector2(rechts, 58.0), zeile, 13, LEISE, false, true)

    _flaeche.draw_line(Vector2(0.0, KOPF), Vector2(breite, KOPF),
        Color(BAND_KANTE.r, BAND_KANTE.g, BAND_KANTE.b, 0.4), 1.4)


func _kammer(kasten: Rect2, k: int, stand: KolonieStand, jetzt: float) -> void:
    var farbe := FARBEN[k]
    var stufe := stand.stufe(k)
    var baut_hier := stand.bau_kammer == k
    var gedrueckt := _gedrueckt == k

    _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g, BAND_FARBE.b,
        0.95 if gedrueckt else 0.82))
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.34), false, 1.4)

    # Farbstreifen links - so ist die Kammer schon vor dem Lesen erkennbar.
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(farbe.r, farbe.g, farbe.b, 0.85))

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _sinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 24.0, k, farbe, stufe)

    var links := kasten.position.x + 84.0
    _text(Vector2(links, kasten.position.y + 30.0), Kammern.name_von(k), 17, SCHRIFT)
    _text(Vector2(links, kasten.position.y + 52.0), Kammern.zweck(k), 12, LEISE)

    # Stufenpunkte statt einer Zahl: man sieht auf einen Blick, wieviel noch
    # geht, ohne rechnen zu muessen.
    var deckel := Kammern.deckel(k, stand.schacht())
    _stufenreihe(Vector2(links, kasten.position.y + 76.0), stufe, deckel, farbe)

    var rechts := kasten.end.x - 12.0
    if baut_hier:
        _baufortschritt(kasten, stand, jetzt, farbe)
    elif stand.baut():
        _text(Vector2(rechts, mitte_y + 5.0), "wartet", 14, LEISE, false, true)
    elif stufe >= deckel:
        var was := "voll" if k == Kammern.Kammer.TIEFENSCHACHT else "gesperrt"
        _text(Vector2(rechts, mitte_y + 5.0), was, 14, SPERRE, false, true)
    else:
        var preis := stand.preis(k)
        var reicht := stand.naehrstoffe >= preis
        _text(Vector2(rechts, mitte_y - 6.0), "Stufe %d" % (stufe + 1), 13, LEISE, false, true)
        _text(Vector2(rechts, mitte_y + 16.0), str(preis), 18,
            NAEHR if reicht else SPERRE, false, true)


func _baufortschritt(kasten: Rect2, stand: KolonieStand, jetzt: float,
        farbe: Color) -> void:
    var rest := stand.restzeit(jetzt)
    var ganz := maxf(0.001, Kammern.bauzeit(stand.bau_kammer,
        stand.stufe(stand.bau_kammer)))
    var anteil := clampf(1.0 - rest / ganz, 0.0, 1.0)

    var balken := Rect2(kasten.position.x + 84.0, kasten.end.y - 22.0,
        kasten.size.x - 100.0, 5.0)
    _flaeche.draw_rect(balken, Color(0.0, 0.0, 0.0, 0.45))
    _flaeche.draw_rect(Rect2(balken.position, Vector2(balken.size.x * anteil,
        balken.size.y)), farbe)

    _text(Vector2(kasten.end.x - 12.0, kasten.position.y + 30.0),
        _dauer(rest), 16, farbe, false, true)


func _stufenreihe(wo: Vector2, stufe: int, deckel: int, farbe: Color) -> void:
    var abstand := 9.0
    for i in Kammern.HOECHSTSTUFE:
        var p := wo + Vector2(abstand * float(i) + 3.0, 0.0)
        if i < stufe:
            _flaeche.draw_circle(p, 3.4, farbe)
        elif i < deckel:
            _flaeche.draw_arc(p, 3.0, 0.0, TAU, 8,
                Color(farbe.r, farbe.g, farbe.b, 0.38), 1.2, true)
        else:
            # Jenseits des Deckels: was der Tiefenschacht noch verschlossen haelt.
            _flaeche.draw_circle(p, 1.6, Color(0.34, 0.36, 0.38, 0.42))


func _fusszeile(breite: float, hoehe: float) -> void:
    _schliessen = Rect2(RAND, hoehe - FUSS + 8.0, breite - RAND * 2.0, 52.0)
    var puls := 0.5 + 0.5 * sin(_zeit * 2.2)
    _flaeche.draw_rect(_schliessen, Color(0.08, 0.20, 0.24, 0.9))
    _flaeche.draw_rect(_schliessen, Color(0.42, 0.86, 0.92, 0.30 + 0.25 * puls),
        false, 1.6)
    _text(_schliessen.get_center() + Vector2(0.0, 6.0), "ZURUECK ZUM SCHLUND",
        17, Color(0.82, 0.96, 1.0), true)


# --- Sinnbilder ------------------------------------------------------------
#
# Je Kammer eine eigene Form, aus Grundformen gezeichnet. Keine Bilddatei im
# Projekt - siehe ASSETS.md.

func _sinnbild(p: Vector2, r: float, k: int, farbe: Color, stufe: int) -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 1.6 + float(k))
    var kraft := clampf(0.35 + 0.65 * float(stufe) / float(Kammern.HOECHSTSTUFE), 0.0, 1.0)
    _flaeche.draw_circle(p, r * 1.25, Color(farbe.r, farbe.g, farbe.b,
        0.07 + 0.06 * puls * kraft))

    match k:
        Kammern.Kammer.LEUCHTORGAN:
            for i in 8:
                var w := TAU * float(i) / 8.0
                var richtung := Vector2(cos(w), sin(w))
                _flaeche.draw_line(p + richtung * r * 0.5,
                    p + richtung * r * (0.85 + 0.2 * puls),
                    Color(farbe.r, farbe.g, farbe.b, 0.30 + 0.4 * kraft), 1.6)
            _flaeche.draw_circle(p, r * 0.40, Color(0.92, 1.0, 0.98, 0.75 + 0.2 * kraft))
        Kammern.Kammer.ZUCHTKAMMER:
            for i in 3:
                var wurzel := p + Vector2((float(i) - 1.0) * r * 0.52, r * 0.68)
                _flaeche.draw_line(wurzel, wurzel - Vector2(0.0, r * 0.72), farbe, 2.4)
                _flaeche.draw_circle(wurzel - Vector2(0.0, r * 0.82), r * 0.20,
                    Color(farbe.r, farbe.g, farbe.b, 0.85))
        Kammern.Kammer.BRUTKAMMER:
            for i in 3:
                var w := PI * (0.2 + 0.3 * float(i))
                var wo := p + Vector2(cos(w), sin(w)) * r * 0.5
                _flaeche.draw_circle(wo, r * 0.26, farbe)
                _flaeche.draw_circle(wo, r * 0.12, Color(1.0, 0.98, 0.90, 0.85))
        Kammern.Kammer.FILTERBECKEN:
            for i in 4:
                var y := p.y - r * 0.6 + r * 0.4 * float(i)
                _flaeche.draw_line(Vector2(p.x - r * 0.7, y), Vector2(p.x + r * 0.7, y),
                    Color(farbe.r, farbe.g, farbe.b, 0.45 + 0.14 * float(i)), 2.0)
            for i in 3:
                var x := p.x - r * 0.5 + r * 0.5 * float(i)
                var t := fmod(_zeit * 0.6 + float(i) * 0.33, 1.0)
                _flaeche.draw_circle(Vector2(x, p.y - r * 0.7 + r * 1.4 * t), 1.8,
                    Color(0.9, 1.0, 1.0, 0.6 * (1.0 - t)))
        Kammern.Kammer.TIEFENSCHACHT:
            var schacht := PackedVector2Array([
                p + Vector2(-r * 0.55, -r * 0.75), p + Vector2(r * 0.55, -r * 0.75),
                p + Vector2(r * 0.24, r * 0.85), p + Vector2(-r * 0.24, r * 0.85),
            ])
            _flaeche.draw_colored_polygon(schacht, Color(farbe.r, farbe.g, farbe.b, 0.22))
            _flaeche.draw_polyline(schacht + PackedVector2Array([schacht[0]]),
                farbe, 1.6, true)
            for i in 3:
                var y := p.y - r * 0.4 + r * 0.5 * float(i)
                var halb := lerpf(r * 0.5, r * 0.26, float(i) / 2.0)
                _flaeche.draw_line(Vector2(p.x - halb, y), Vector2(p.x + halb, y),
                    Color(farbe.r, farbe.g, farbe.b, 0.35), 1.2)


# --- Kleinkram -------------------------------------------------------------

static func _dauer(sekunden: float) -> String:
    var s := int(ceil(maxf(0.0, sekunden)))
    if s >= 3600:
        return "%d h %02d m" % [s / 3600, (s % 3600) / 60]
    if s >= 60:
        return "%d m %02d s" % [s / 60, s % 60]
    return "%d s" % s


func _text(wo: Vector2, was: String, groesse: int, farbe: Color,
        zentriert := false, rechtsbuendig := false) -> void:
    var breite := _schrift.get_string_size(was, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
    var ort := wo
    if zentriert:
        ort.x -= breite * 0.5
    elif rechtsbuendig:
        ort.x -= breite
    _flaeche.draw_string(_schrift, ort + Vector2(1.0, 1.0), was,
        HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(0.0, 0.0, 0.0, farbe.a * 0.7))
    _flaeche.draw_string(_schrift, ort, was, HORIZONTAL_ALIGNMENT_LEFT, -1,
        groesse, farbe)
