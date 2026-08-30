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
## Links und rechts. Als Konstante, weil ein Feldliteral in einer for-Schleife
## seinen Typ verliert und jede Ableitung daraus mit.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]

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
var _reiter: Array[Rect2] = []

## Vier Ansichten statt einer langen Liste: fuenf Kammern, drei Linien, acht
## Arten und der Tag nebeneinander waeren auf einem Telefon zwanzig gedraengte
## Zeilen.
enum Sicht { KAMMERN, LINIEN, ARTEN, TAG }
var _sicht := Sicht.KAMMERN

## Tippziele der Tagesansicht, in Bildschirmkoordinaten.
var _kalender := Rect2()
var _lauter := Rect2()
var _leiser := Rect2()
var _loeschen := Rect2()
var _loeschen_sicher := false
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
    _sicht = Sicht.KAMMERN
    _loeschen_sicher = false
    Fortschritt.pruefe_tag()
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
        Klang.spiele(Klang.Ton.TIPP)
        geschlossen.emit()
        hide()
        return

    for r in _reiter.size():
        if _reiter[r].has_point(ort):
            Klang.spiele(Klang.Ton.TIPP)
            _sicht = r as Sicht
            _loeschen_sicher = false
            _meldung_leben = 0.0
            return

    if _sicht == Sicht.TAG:
        if _kalender.has_point(ort):
            _hole_kalender()
            return
        if _lauter.has_point(ort):
            Klang.laut = Klang.laut + 0.2
            Klang.spiele(Klang.Ton.TIPP)
            return
        if _leiser.has_point(ort):
            Klang.laut = Klang.laut - 0.2
            Klang.spiele(Klang.Ton.TIPP)
            return
        if _loeschen.has_point(ort):
            # Zwei Tipps, nicht einer. Ein Spielstand, den ein Fehlgriff
            # loescht, ist kein Spielstand.
            if _loeschen_sicher:
                Fortschritt.von_vorn()
                _loeschen_sicher = false
                _zeige("Colony founded anew")
            else:
                _loeschen_sicher = true
                _zeige("Tap again to really delete")
            Klang.spiele(Klang.Ton.TIPP, 0.6)
            return

    for i in _baender.size():
        if _baender[i].has_point(ort):
            _gedrueckt = i
            match _sicht:
                Sicht.LINIEN:
                    _versuche_linie(i + 1)
                Sicht.ARTEN:
                    # Nichts zu tun - das Bestiarium ist zum Nachschlagen da.
                    pass
                Sicht.TAG:
                    _hole_ziel(i)
                _:
                    _versuche_ausbau(i)
            return


func _versuche_ausbau(kammer: int) -> void:
    var stand: KolonieStand = Fortschritt.stand
    var grund := stand.hindernis(kammer)
    if not grund.is_empty():
        # Der Grund wird angezeigt, nicht verschwiegen. Ein Knopf, der nur
        # grau ist, laesst den Spieler raten.
        Klang.spiele(Klang.Ton.TIPP, 0.6, 0.5)
        _zeige(grund)
        return
    if stand.starte_bau(kammer, Time.get_unix_time_from_system()):
        Klang.spiele(Klang.Ton.POLYP, 0.8)
        Fortschritt.sichere()
        Fortschritt.stand_geaendert.emit()
        _zeige("Digging the %s" % Kammern.name_von(kammer))


func _hole_kalender() -> void:
    var stand: KolonieStand = Fortschritt.stand
    var lohn := stand.hole_kalender()
    if lohn.is_empty():
        return
    Fortschritt.sichere()
    Fortschritt.stand_geaendert.emit()
    if lohn.has(&"linie"):
        Klang.spiele(Klang.Ton.KAMMER, 1.5, 0.85)
        _zeige("%s bred - it takes over the watch"
            % Brutlinien.name_von(int(lohn[&"linie"])))
    else:
        Klang.spiele(Klang.Ton.KAMMER, 1.2, 0.7)
        _zeige("+%d nutrients" % int(lohn[&"naehrstoff"]))


func _hole_ziel(index: int) -> void:
    var stand: KolonieStand = Fortschritt.stand
    if not stand.ziel_erfuellt(index):
        Klang.spiele(Klang.Ton.TIPP, 0.6, 0.5)
        _zeige("%d of %d so far" % [stand.ziel_fortschritt[index],
            Tagesziel.menge(index)])
        return
    var lohn := stand.hole_ziel(index)
    if lohn > 0:
        Klang.spiele(Klang.Ton.KAMMER, 1.2, 0.7)
        Fortschritt.sichere()
        Fortschritt.stand_geaendert.emit()
        _zeige("+%d nutrients" % lohn)
    else:
        _zeige("Already collected")


## Zuechten oder, wenn schon gezuechtet, auswaehlen.
func _versuche_linie(index: int) -> void:
    var stand: KolonieStand = Fortschritt.stand
    if stand.hat_linie(index):
        if stand.linie == index:
            _zeige("%s already carries the watch" % Brutlinien.name_von(index))
        elif stand.waehle_linie(index):
            Klang.spiele(Klang.Ton.POLYP, 0.9)
            Fortschritt.sichere()
            Fortschritt.stand_geaendert.emit()
            _zeige("%s takes over the watch" % Brutlinien.name_von(index))
        return

    var grund := stand.linie_hindernis(index)
    if not grund.is_empty():
        Klang.spiele(Klang.Ton.TIPP, 0.6, 0.5)
        _zeige(grund)
        return
    if stand.zuechte(index):
        Klang.spiele(Klang.Ton.KAMMER, 1.1, 0.7)
        Fortschritt.sichere()
        Fortschritt.stand_geaendert.emit()
        _zeige("%s bred" % Brutlinien.name_von(index))


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

    _umschalterzeile(breite)

    _baender.clear()
    var anzahl := Kammern.zahl()
    if _sicht == Sicht.LINIEN:
        anzahl = Brutlinien.zahl() - 1
    elif _sicht == Sicht.ARTEN:
        anzahl = Arten.zahl()
    elif _sicht == Sicht.TAG:
        anzahl = Tagesziel.zahl()
    var oben := KOPF + 58.0
    var verfuegbar := hoehe - oben - FUSS - 24.0
    var passt := BAND
    var gebraucht := float(anzahl) * (BAND + LUECKE)
    if gebraucht > verfuegbar:
        passt = verfuegbar / float(anzahl) - LUECKE
        gebraucht = verfuegbar

    # Oben ansetzen, nicht mittig. Mittig sah bei fuenf Kammern noch aus wie
    # Absicht, bei drei Linien wie ein Versehen - und auf dem Tagesreiter
    # schob es die Fusszeile unter den Bildrand.
    var y := oben + minf(28.0, maxf(0.0, (verfuegbar - gebraucht) * 0.5))

    for k in anzahl:
        var kasten := Rect2(RAND, y, breite - RAND * 2.0, passt)
        _baender.append(kasten)
        match _sicht:
            Sicht.LINIEN:
                _brutlinie(kasten, k + 1, stand)
            Sicht.ARTEN:
                _artband(kasten, k, stand)
            Sicht.TAG:
                _tagesziel(kasten, k, stand)
            _:
                _kammer(kasten, k, stand, jetzt)
        y += passt + LUECKE

    if _sicht == Sicht.TAG:
        y = _zuchtkalender(breite, y + 8.0, stand)
        _grabenwertung(breite, y + 18.0, stand)
        # Der Fuss haengt unten, nicht hinter dem Kalender. Sonst stand die
        # untere Haelfte des Tagesreiters leer und der Loeschknopf mitten im
        # Bild - genau dort, wo der Daumen ohnehin liegt.
        _tagesfuss(breite, hoehe - FUSS - 186.0, stand)
    else:
        _kalender = Rect2()
        _lauter = Rect2()
        _leiser = Rect2()
        _loeschen = Rect2()

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
    _text(Vector2(RAND, 34.0), "COLONY", 21, SCHRIFT)
    _text(Vector2(RAND, 58.0), "Deepest wave %d of %d  ·  rank %d of %d"
        % [stand.hoechste_welle, Graben.WELLEN_GESAMT,
           Geister.platz(stand.hoechste_welle), Geister.zahl() + 1], 14, LEISE)

    var rechts := breite - RAND
    _text(Vector2(rechts, 34.0), str(stand.naehrstoffe), 21, NAEHR, false, true)
    var strom := stand.je_stunde()
    var zeile := "Nutrients" if strom <= 0.0 else "Nutrients  +%d/h" % int(strom)
    _text(Vector2(rechts, 58.0), zeile, 13, LEISE, false, true)

    if stand.linie != Brutlinien.Linie.KEINE:
        _text(Vector2(breite * 0.5, 58.0), Brutlinien.name_von(stand.linie), 14,
            Brutlinien.farbe(stand.linie), true)

    _flaeche.draw_line(Vector2(0.0, KOPF), Vector2(breite, KOPF),
        Color(BAND_KANTE.r, BAND_KANTE.g, BAND_KANTE.b, 0.4), 1.4)


## Die Umschaltzeile: drei Reiter, der aktive hell.
func _umschalterzeile(breite: float) -> void:
    const BESCHRIFTUNG: PackedStringArray = ["CHAMBERS", "LINES", "SPECIES", "DAY"]
    var y := KOPF + 12.0
    var anzahl := BESCHRIFTUNG.size()
    var breit := (breite - RAND * 2.0 - 8.0 * float(anzahl - 1)) / float(anzahl)
    _reiter.clear()

    for i in anzahl:
        var kasten := Rect2(RAND + (breit + 8.0) * float(i), y, breit, 36.0)
        _reiter.append(kasten)
        var aktiv := _sicht == i
        _flaeche.draw_rect(kasten, Color(0.06, 0.16, 0.20, 0.9 if aktiv else 0.45))
        _flaeche.draw_rect(kasten, Color(0.42, 0.86, 0.92, 0.5 if aktiv else 0.16),
            false, 1.4)
        _text(kasten.get_center() + Vector2(0.0, 5.0), BESCHRIFTUNG[i], 13,
            SCHRIFT if aktiv else LEISE, true)

        # Ein Punkt am Reiter, wenn dort etwas abzuholen ist. Sonst muesste
        # man jeden Tag nachsehen, ob sich etwas getan hat.
        if i == Sicht.TAG and (Fortschritt.stand.ziele_offen() > 0
                or Fortschritt.stand.kalender_offen()):
            _flaeche.draw_circle(kasten.position + Vector2(kasten.size.x - 10.0, 10.0),
                4.0, NAEHR)


## Ein Tagesziel mit Fortschrittsbalken.
func _tagesziel(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var erfuellt := stand.ziel_erfuellt(index)
    var geholt := stand.ziel_geholt[index] == 1
    var farbe := NAEHR if erfuellt and not geholt else LEISE

    _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g, BAND_FARBE.b, 0.85))
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.32), false, 1.4)
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(farbe.r, farbe.g, farbe.b, 0.85))

    var links := kasten.position.x + 20.0
    _text(Vector2(links, kasten.position.y + 32.0), Tagesziel.name_von(index), 16,
        LEISE if geholt else SCHRIFT)

    var soll := Tagesziel.menge(index)
    var ist: int = stand.ziel_fortschritt[index]
    var balken := Rect2(links, kasten.end.y - 30.0, kasten.size.x - 150.0, 5.0)
    _flaeche.draw_rect(balken, Color(0.0, 0.0, 0.0, 0.45))
    _flaeche.draw_rect(Rect2(balken.position,
        Vector2(balken.size.x * clampf(float(ist) / float(soll), 0.0, 1.0),
        balken.size.y)), farbe)
    _text(Vector2(links, kasten.end.y - 8.0), "%d / %d" % [ist, soll], 12, LEISE)

    var rechts := kasten.end.x - 14.0
    if geholt:
        _text(Vector2(rechts, kasten.get_center().y + 5.0), "collected", 14, LEISE,
            false, true)
    elif erfuellt:
        _text(Vector2(rechts, kasten.get_center().y - 4.0), "collect", 13, NAEHR,
            false, true)
        _text(Vector2(rechts, kasten.get_center().y + 18.0),
            "+%d" % Tagesziel.lohn(index, stand.hoechste_welle), 17, NAEHR,
            false, true)
    else:
        _text(Vector2(rechts, kasten.get_center().y + 5.0),
            "+%d" % Tagesziel.lohn(index, stand.hoechste_welle), 15, LEISE,
            false, true)


## Eine Art im Bestiarium.
##
## Unbekannte Arten stehen als Umriss da, mit der Welle, ab der sie kommen.
## Zu sehen, dass noch etwas kommt, ist ein Grund weiterzuspielen; zu sehen,
## *was* kommt, waere die Ueberraschung weg.
func _artband(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var kennt := stand.kennt(index)
    var farbe := Arten.farbe(index)
    if not kennt:
        farbe = Color(0.34, 0.44, 0.50)

    _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g, BAND_FARBE.b,
        0.88 if kennt else 0.52))
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.28), false, 1.4)
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(farbe.r, farbe.g, farbe.b, 0.85 if kennt else 0.30))

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _artsinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 22.0, index, farbe, kennt)

    var links := kasten.position.x + 84.0
    _text(Vector2(links, kasten.position.y + 32.0),
        Arten.name_von(index) if kennt else "Not yet encountered", 17,
        SCHRIFT if kennt else LEISE)
    _text(Vector2(links, kasten.position.y + 56.0),
        Arten.regel(index) if kennt else "Appears from wave %d on" % Arten.art(index)[&"ab_welle"],
        12, LEISE if kennt else Color(0.34, 0.44, 0.50))

    if not kennt:
        return

    # Die Zahlen, die man beim Zielen wirklich braucht - und nur die.
    # Das Leben aus der aktuellen Welle, nicht der Grundwert: die
    # Schlundmutter hat gar keinen: ihres faellt aus der Wellenstaerke, und
    # "Leben 1" waere schlicht falsch.
    var tiefe := maxi(1, stand.hoechste_welle)
    var zeile := "Health %d  ·  speed %d  ·  impact %d" % [
        int(Wellen.leben_in(index, tiefe)), int(Arten.tempo(index)),
        Arten.wucht(index)]
    _text(Vector2(links, kasten.end.y - 16.0), zeile, 11, Color(0.40, 0.54, 0.60))

    var rechts := kasten.end.x - 14.0
    _text(Vector2(rechts, mitte_y - 6.0), "from wave", 12, LEISE, false, true)
    _text(Vector2(rechts, mitte_y + 16.0), str(Arten.art(index)[&"ab_welle"]), 18,
        Color(farbe.r, farbe.g, farbe.b, 0.9), false, true)


## Ein Zeichen je Art. Wie bei den Kammern: gezeichnet, keine Bilddatei - und
## jedes zeigt die Eigenart, nicht nur den Umriss.
func _artsinnbild(p: Vector2, r: float, index: int, farbe: Color, kennt: bool) -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 1.5 + float(index))
    _flaeche.draw_circle(p, r * 1.2, Color(farbe.r, farbe.g, farbe.b,
        0.06 + 0.06 * puls))
    if not kennt:
        _flaeche.draw_arc(p, r * 0.8, 0.0, TAU, 20,
            Color(farbe.r, farbe.g, farbe.b, 0.35), 1.4)
        return

    match index:
        Arten.Art.ZAHNKIEFER:
            _flaeche.draw_circle(p, r * 0.6, Color(farbe.r, farbe.g, farbe.b, 0.55))
            for i in 4:
                var w := PI * (0.15 + 0.23 * float(i))
                _flaeche.draw_line(p + Vector2(cos(w), sin(w)) * r * 0.6,
                    p + Vector2(cos(w), sin(w)) * r * 0.95, farbe, 1.6)
        Arten.Art.SCHLEIER:
            for i in 3:
                _flaeche.draw_arc(p + Vector2(0.0, r * 0.2 * float(i)), r * 0.62,
                    PI, TAU, 14, Color(farbe.r, farbe.g, farbe.b, 0.7 - 0.2 * float(i)), 1.6)
        Arten.Art.PANZERKREBS:
            _flaeche.draw_arc(p, r * 0.7, PI, TAU, 18, farbe, 2.6)
            for s: float in SEITEN:
                _flaeche.draw_line(p + Vector2(s * r * 0.7, 0.0),
                    p + Vector2(s * r * 0.95, r * 0.5), farbe, 1.6)
        Arten.Art.GRABNATTER:
            var welle := PackedVector2Array()
            for i in 12:
                var t := float(i) / 11.0
                welle.append(p + Vector2(lerpf(-r * 0.9, r * 0.9, t),
                    sin(t * TAU) * r * 0.42))
            _flaeche.draw_polyline(welle, farbe, 2.0)
        Arten.Art.SCHILDKORALLE:
            for i in 3:
                var y := p.y - r * 0.5 + r * 0.5 * float(i)
                var halb := lerpf(r * 0.42, r * 0.86, float(i) / 2.0)
                _flaeche.draw_line(Vector2(p.x - halb, y), Vector2(p.x + halb, y),
                    farbe, 3.0)
        Arten.Art.GLUTQUALLE:
            _flaeche.draw_arc(p, r * 0.86, PI, TAU, 18,
                Color(farbe.r, farbe.g, farbe.b, 0.4), 1.6)
            _flaeche.draw_circle(p, r * (0.30 + 0.05 * puls),
                Color(1.0, 0.90, 0.80, 0.85))
        Arten.Art.TREIBANKER:
            _flaeche.draw_line(p + Vector2(-r * 0.9, r * 0.3),
                p + Vector2(r * 0.9, r * 0.3), farbe, 2.2)
            _flaeche.draw_line(p + Vector2(r * 0.9, r * 0.3),
                p + Vector2(r * 0.45, 0.0), farbe, 2.0)
            _flaeche.draw_line(p + Vector2(r * 0.9, r * 0.3),
                p + Vector2(r * 0.45, r * 0.6), farbe, 2.0)
            _flaeche.draw_circle(p + Vector2(-r * 0.7, -r * 0.35), r * 0.2,
                Color(farbe.r, farbe.g, farbe.b, 0.7))
        Arten.Art.SPRUNGAAL:
            var zack := PackedVector2Array([
                p + Vector2(-r * 0.9, r * 0.4), p + Vector2(-r * 0.2, -r * 0.4),
                p + Vector2(r * 0.2, r * 0.2), p + Vector2(r * 0.9, -r * 0.5),
            ])
            _flaeche.draw_polyline(zack, farbe, 2.2)
        Arten.Art.SCHLUNDMUTTER:
            # Breiter Mantel und ein Kranz aus Augen - dieselbe Silhouette wie
            # im Schlund, nur klein.
            _flaeche.draw_arc(p + Vector2(0.0, r * 0.24), r * 0.94, PI, TAU, 22,
                farbe, 2.4)
            for i in 5:
                var w := lerpf(-PI * 0.62, PI * 0.62, float(i) / 4.0)
                _flaeche.draw_circle(p + Vector2(sin(w), -cos(w) * 0.5) * r * 0.58,
                    r * 0.11, Color(1.0, 0.94, 0.86, 0.85))
            for i in 4:
                var x := lerpf(-r * 0.62, r * 0.62, float(i) / 3.0)
                _flaeche.draw_line(p + Vector2(x, r * 0.3),
                    p + Vector2(x * 1.2, r * 0.92),
                    Color(farbe.r, farbe.g, farbe.b, 0.42), 1.4)


## Die Grabenwertung: wo man zwischen den Nachbarkolonien steht.
##
## Nicht die ganze Liste, sondern der eigene Platz mit zwei Namen darueber und
## zwei darunter. Elf Zeilen waeren eine Tabelle; fuenf sind eine Aussage.
func _grabenwertung(breite: float, y: float, stand: KolonieStand) -> float:
    const ZEIGEN := 5
    var liste := Geister.rangliste(stand.hoechste_welle)
    var eigen := Geister.platz(stand.hoechste_welle) - 1
    var erste := clampi(eigen - 2, 0, maxi(0, liste.size() - ZEIGEN))

    _text(Vector2(RAND, y + 14.0), "TRENCH STANDINGS", 13, LEISE)
    var vor := Geister.naechster_vor(stand.hoechste_welle)
    if not String(vor[&"name"]).is_empty():
        var abstand := int(vor[&"tiefe"]) - stand.hoechste_welle
        _text(Vector2(breite - RAND, y + 14.0),
            "%d waves to %s" % [maxi(0, abstand), vor[&"name"]], 12, LEISE,
            false, true)
    else:
        _text(Vector2(breite - RAND, y + 14.0), "deepest in the trench", 12, NAEHR,
            false, true)

    var zeile_y := y + 24.0
    for i in range(erste, mini(erste + ZEIGEN, liste.size())):
        var eintrag := liste[i]
        var selbst: bool = eintrag[&"selbst"]
        var kasten := Rect2(RAND, zeile_y, breite - RAND * 2.0, 32.0)
        if selbst:
            _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g,
                BAND_FARBE.b, 0.9))
            _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
                NAEHR)

        var farbe := NAEHR if selbst else LEISE
        _text(Vector2(RAND + 14.0, zeile_y + 21.0), "%d." % (i + 1), 13, farbe)
        _text(Vector2(RAND + 46.0, zeile_y + 21.0), String(eintrag[&"name"]), 15,
            SCHRIFT if selbst else LEISE)
        _text(Vector2(breite - RAND - 10.0, zeile_y + 21.0),
            "Welle %d" % int(eintrag[&"tiefe"]), 14, farbe, false, true)
        zeile_y += 34.0

    return zeile_y


## Schaltet die Ansicht um. Nur fuer die Entwicklerschalter - im Spiel tippt
## man die Reiter an.
func zeige_reiter(welche: int) -> void:
    _sicht = clampi(welche, 0, 2) as Sicht


## Sieben Kaesten in einer Reihe. Der letzte traegt keine Zahl, sondern eine
## Brutlinie - und sieht deshalb anders aus als die sechs davor.
func _zuchtkalender(breite: float, y: float, stand: KolonieStand) -> float:
    var fertig := stand.kalender >= Zuchtkalender.TAGE
    var offen := stand.kalender_offen()

    var kopf := "BREEDING CALENDAR"
    var kopffarbe := LEISE
    if fertig:
        kopf = "BREEDING CALENDAR  ·  complete"
    elif offen:
        kopf = "BREEDING CALENDAR  ·  collect day %d" % (stand.kalender + 1)
        kopffarbe = NAEHR
    else:
        kopf = "BREEDING CALENDAR  ·  day %d of %d" % [stand.kalender, Zuchtkalender.TAGE]
    _text(Vector2(RAND, y + 16.0), kopf, 13, kopffarbe)

    var reihe_y := y + 28.0
    var hoch := 54.0
    var breit := (breite - RAND * 2.0 - 6.0 * 4.0) / float(Zuchtkalender.TAGE)
    var puls := 0.5 + 0.5 * sin(_zeit * 2.6)

    for i in Zuchtkalender.TAGE:
        var kasten := Rect2(RAND + (breit + 4.0) * float(i), reihe_y, breit, hoch)
        var geholt := i < stand.kalender
        var dran := i == stand.kalender and offen
        var linientag := Zuchtkalender.ist_linientag(i)

        var farbe := LEISE
        if geholt:
            farbe = NAEHR
        elif dran:
            farbe = Color(NAEHR.r, NAEHR.g, NAEHR.b, 0.55 + 0.45 * puls)
        elif linientag:
            farbe = Brutlinien.farbe(Brutlinien.Linie.STROMSINN)

        _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g, BAND_FARBE.b,
            0.9 if geholt or dran else 0.55))
        _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b,
            0.7 if dran else 0.3), false, 1.8 if dran else 1.2)

        _text(Vector2(kasten.get_center().x, kasten.position.y + 20.0),
            str(i + 1), 13, farbe if geholt or dran else LEISE, true)
        _text(Vector2(kasten.get_center().x, kasten.position.y + 42.0),
            Zuchtkalender.kurz(i, stand.hoechste_welle), 11,
            farbe if geholt or dran else Color(0.34, 0.44, 0.50), true)

        if geholt:
            # Ein Haken waere ein Zeichen mehr, das die Schrift tragen muss.
            # Ein Strich durch den Kasten sagt dasselbe und ist gezeichnet.
            _flaeche.draw_line(kasten.position + Vector2(6.0, hoch - 7.0),
                kasten.position + Vector2(breit - 6.0, hoch - 7.0),
                Color(NAEHR.r, NAEHR.g, NAEHR.b, 0.7), 1.6)

    _kalender = Rect2(RAND, y, breite - RAND * 2.0, hoch + 28.0) if offen else Rect2()
    return reihe_y + hoch


## Unter den Zielen: Anwesenheit, Lautstaerke, Lizenzen, Neuanfang.
func _tagesfuss(breite: float, y: float, stand: KolonieStand) -> void:
    var tage := "1 day" if stand.strecke == 1 else "%d days" % stand.strecke
    _text(Vector2(RAND, y + 22.0), "%s in the trench in a row" % tage,
        15, Color(0.72, 0.88, 0.92))

    # Lautstaerke in Schritten statt als Schieber: einen Schieber trifft man
    # mit dem Daumen schlecht, zwei Knoepfe immer.
    var zeile := y + 44.0
    _text(Vector2(RAND, zeile + 24.0), "Sound  %d%%" % int(round(Klang.laut * 100.0)),
        15, LEISE)
    _leiser = Rect2(breite - RAND - 96.0, zeile, 44.0, 34.0)
    _lauter = Rect2(breite - RAND - 44.0, zeile, 44.0, 34.0)
    for paar in [[_leiser, "-"], [_lauter, "+"]]:
        var kasten: Rect2 = paar[0]
        _flaeche.draw_rect(kasten, Color(0.06, 0.16, 0.20, 0.8))
        _flaeche.draw_rect(kasten, Color(0.42, 0.86, 0.92, 0.28), false, 1.3)
        _text(kasten.get_center() + Vector2(0.0, 6.0), paar[1], 18, SCHRIFT, true)

    # Lizenzen sind Pflicht, nicht Kuer: Godot steht unter MIT, die Schriften
    # unter SIL OFL, und beide verlangen, dass der Text mit ausgeliefert wird.
    var lz := zeile + 46.0
    _text(Vector2(RAND, lz + 16.0),
        "Godot Engine (MIT) - fonts SIL OFL 1.1", 12, Color(0.40, 0.52, 0.58))
    _text(Vector2(RAND, lz + 34.0),
        "All graphics and sound generated by this game itself", 12, Color(0.40, 0.52, 0.58))

    _loeschen = Rect2(RAND, lz + 46.0, breite - RAND * 2.0, 34.0)
    var warnfarbe := Color(1.0, 0.52, 0.44) if _loeschen_sicher else Color(0.44, 0.36, 0.36)
    _flaeche.draw_rect(_loeschen, Color(0.10, 0.05, 0.05, 0.7))
    _flaeche.draw_rect(_loeschen, Color(warnfarbe.r, warnfarbe.g, warnfarbe.b, 0.4),
        false, 1.3)
    _text(_loeschen.get_center() + Vector2(0.0, 5.0),
        "REALLY DELETE?" if _loeschen_sicher else "Found the colony anew",
        14, warnfarbe, true)


## Eine Brutlinie. Anders als eine Kammer hat sie keine Stufen - sie ist da
## oder nicht, und genau eine traegt.
func _brutlinie(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var farbe := Brutlinien.farbe(index)
    var hat := stand.hat_linie(index)
    var traegt := stand.linie == index

    _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g, BAND_FARBE.b,
        0.92 if hat else 0.62))
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b,
        0.62 if traegt else 0.26), false, 2.0 if traegt else 1.4)
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(farbe.r, farbe.g, farbe.b, 0.85 if hat else 0.30))

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _brutsinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 22.0, index, farbe, hat)

    var links := kasten.position.x + 84.0
    _text(Vector2(links, kasten.position.y + 32.0), Brutlinien.name_von(index), 17,
        SCHRIFT if hat else LEISE)
    _text(Vector2(links, kasten.position.y + 56.0), Brutlinien.wirkung(index), 12,
        LEISE if hat else Color(0.34, 0.44, 0.50))

    var rechts := kasten.end.x - 12.0
    if traegt:
        _text(Vector2(rechts, mitte_y + 5.0), "carries", 15, farbe, false, true)
    elif hat:
        _text(Vector2(rechts, mitte_y + 5.0), "select", 15, LEISE, false, true)
    else:
        var frei := stand.hat_linie(Brutlinien.voraussetzung(index))
        var preis := Brutlinien.kosten(index)
        var reicht := frei and stand.naehrstoffe >= preis
        _text(Vector2(rechts, mitte_y - 6.0), "breed", 13, LEISE, false, true)
        _text(Vector2(rechts, mitte_y + 16.0), str(preis) if frei else "locked", 18,
            NAEHR if reicht else SPERRE, false, true)


## Ein Sinnbild je Linie. Wie bei den Kammern: gezeichnet, keine Bilddatei.
func _brutsinnbild(p: Vector2, r: float, index: int, farbe: Color, hat: bool) -> void:
    var deckung := 1.0 if hat else 0.38
    var puls := 0.5 + 0.5 * sin(_zeit * 1.4 + float(index))
    _flaeche.draw_circle(p, r * 1.3, Color(farbe.r, farbe.g, farbe.b,
        (0.08 + 0.05 * puls) * deckung))

    match index:
        Brutlinien.Linie.STROMSINN:
            # Drei Stromlinien, die sich biegen.
            for i in 3:
                var y := p.y - r * 0.5 + r * 0.5 * float(i)
                var punkte := PackedVector2Array()
                for k in 9:
                    var t := float(k) / 8.0
                    punkte.append(Vector2(p.x - r + t * r * 2.0,
                        y + sin(t * PI * 1.6 + _zeit * 1.2 + float(i)) * r * 0.22))
                _flaeche.draw_polyline(punkte,
                    Color(farbe.r, farbe.g, farbe.b, 0.75 * deckung), 1.8, true)
        Brutlinien.Linie.NACHGLUT:
            # Ein Kern mit abklingenden Ringen.
            for i in 4:
                var f := 1.0 - float(i) / 4.0
                _flaeche.draw_arc(p, r * (0.35 + 0.22 * float(i)), 0.0, TAU, 18,
                    Color(farbe.r, farbe.g, farbe.b, 0.55 * f * deckung), 1.6, true)
            _flaeche.draw_circle(p, r * 0.26, Color(1.0, 0.92, 0.78, 0.85 * deckung))
        Brutlinien.Linie.KALTBRAND:
            # Ein einzelner, scharfer Strahl statt vieler.
            _flaeche.draw_line(p - Vector2(0.0, r * 0.9), p + Vector2(0.0, r * 0.9),
                Color(farbe.r, farbe.g, farbe.b, 0.85 * deckung), 3.4)
            for seite: float in SEITEN:
                _flaeche.draw_line(p + Vector2(seite * r * 0.55, -r * 0.3),
                    p + Vector2(seite * r * 0.55, r * 0.3),
                    Color(farbe.r, farbe.g, farbe.b, 0.30 * deckung), 1.4)
            _flaeche.draw_circle(p, r * 0.2, Color(1.0, 0.96, 1.0, 0.9 * deckung))


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

    # Der Tiefenschacht sagt, was er als naechstes aufmacht. Ein Spieler, der
    # am Ende eines Abschnitts steht, muss hier ablesen koennen, woran es
    # liegt - sonst haelt er den Graben fuer kaputt statt fuer verschlossen.
    var zweite := Kammern.zweck(k)
    var zweite_farbe := LEISE
    if k == Kammern.Kammer.TIEFENSCHACHT and stand.naechste_tiefe() > 0:
        var naechster := Graben.abschnitt(stand.offene_welle()) + 1
        zweite = "%s opens at level %d" % [Regeln.name_von(naechster),
            stand.naechste_tiefe()]
        if stand.graben_haelt():
            zweite_farbe = NAEHR
    _text(Vector2(links, kasten.position.y + 52.0), zweite, 12, zweite_farbe)

    # Stufenpunkte statt einer Zahl: man sieht auf einen Blick, wieviel noch
    # geht, ohne rechnen zu muessen.
    var deckel := Kammern.deckel(k, stand.schacht())
    _stufenreihe(Vector2(links, kasten.position.y + 76.0), stufe, deckel, farbe)

    var rechts := kasten.end.x - 12.0
    if baut_hier:
        _baufortschritt(kasten, stand, jetzt, farbe)
    elif stand.baut():
        _text(Vector2(rechts, mitte_y + 5.0), "waiting", 14, LEISE, false, true)
    elif stufe >= deckel:
        var was := "full" if k == Kammern.Kammer.TIEFENSCHACHT else "locked"
        _text(Vector2(rechts, mitte_y + 5.0), was, 14, SPERRE, false, true)
    else:
        var preis := stand.preis(k)
        var reicht := stand.naehrstoffe >= preis
        _text(Vector2(rechts, mitte_y - 6.0), "Level %d" % (stufe + 1), 13, LEISE, false, true)
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
    _text(_schliessen.get_center() + Vector2(0.0, 6.0), "BACK TO THE MAW",
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
