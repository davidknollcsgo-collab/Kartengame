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

## Die Farbe der Mutationen - dieselbe wie im Wellenkopf, damit die Tafel im
## Spiel und der Eintrag im Nachschlagewerk erkennbar dasselbe meinen.
const MUTATION := Color(0.94, 0.66, 0.88)
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

## Der Lehrschritt, wenn er hier faellig ist. Das HUD ist waehrend des
## Koloniebildschirms unsichtbar - ein Satz, der hier gilt, muss auch hier
## gezeichnet werden, sonst zeigt er auf einen Bildschirm, den niemand sieht.
var _lehre := -1

@onready var _flaeche: Control = $Flaeche

var _schrift: Font
var _zeit := 0.0
var _baender: Array[Rect2] = []
var _schliessen := Rect2()
var _reiter: Array[Rect2] = []

## Vier Ansichten statt einer langen Liste: fuenf Kammern, drei Linien, acht
## Arten und der Tag nebeneinander waeren auf einem Telefon zwanzig gedraengte
## Zeilen.
enum Sicht { KAMMERN, LINIEN, ARTEN, ZUEGE, TAG }
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


## Ob der Koloniebildschirm gerade offen ist - `wache.gd` fragt das fuer die
## Zurueck-Taste.
func sichtbar() -> bool:
    return visible


## Schliesst ihn, als haette man auf den Knopf getippt. Die Zurueck-Taste soll
## dasselbe tun wie der Knopf und nicht etwas Eigenes.
func schliesse() -> void:
    if not visible:
        return
    Klang.spiele(Klang.Ton.TIPP)
    geschlossen.emit()
    hide()


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
    _tiefenverlauf(breite, hoehe)
    _grabenwand(breite, hoehe)
    _schwebstoff(breite, hoehe)
    _kopfzeile(breite, stand)

    _umschalterzeile(breite)

    _baender.clear()
    var anzahl := Kammern.zahl()
    if _sicht == Sicht.LINIEN:
        anzahl = Brutlinien.zahl() - 1
    elif _sicht == Sicht.ARTEN:
        anzahl = Arten.zahl()
    elif _sicht == Sicht.ZUEGE:
        anzahl = Mutationen.Mutation.size()
    elif _sicht == Sicht.TAG:
        anzahl = Tagesziel.zahl()
    var oben := KOPF + 58.0
    var verfuegbar := hoehe - oben - FUSS - 24.0
    var passt := BAND
    var gebraucht := float(anzahl) * (BAND + LUECKE)
    if gebraucht > verfuegbar:
        passt = verfuegbar / float(anzahl) - LUECKE
        gebraucht = verfuegbar
    elif _sicht == Sicht.ZUEGE:
        # Unter den Zuegen steht kein Bild, das den Rest fuellen koennte -
        # sechs Baender in Normalhoehe liessen das untere Drittel leer, und
        # das sieht nach fehlendem Inhalt aus statt nach sechs Eintraegen.
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
            Sicht.ZUEGE:
                _mutationsband(kasten, k, stand)
            Sicht.TAG:
                _tagesziel(kasten, k, stand)
            _:
                _kammer(kasten, k, stand, jetzt)
        y += passt + LUECKE

    if _sicht == Sicht.KAMMERN:
        _schnitt(breite, y + 18.0, hoehe - FUSS - 24.0, stand, jetzt)
    elif _sicht == Sicht.LINIEN:
        _linienbild(breite, y + 18.0, hoehe - FUSS - 24.0, stand)

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

    # **Nur auf dem Reiter, um den es geht.** Auf dem Tagesreiter reicht der
    # Inhalt bis an den Fuss hinunter, und die Tafel lag dort ueber dem Knopf,
    # der den Spielstand loescht. Ein Erklaertext, der eine Schaltflaeche
    # verdeckt, ist schlimmer als keiner - und der Satz redet ohnehin von den
    # Kammern.
    if Lehrpfad.in_der_kolonie(_lehre) and _sicht == Sicht.KAMMERN:
        _lehrtafel(breite, hoehe)
    _fusszeile(breite, hoehe)

    if _meldung_leben > 0.0:
        var f := clampf(_meldung_leben / 0.6, 0.0, 1.0)
        _text(Vector2(breite * 0.5, hoehe - FUSS - 16.0), _meldung, 16,
            Color(0.88, 0.96, 1.0, f), true)


## Der Blick geht nach unten, also wird es nach unten heller: dort liegt die
## Kolonie. Ein gleichmaessig dunkler Grund ist ein Menuehintergrund, ein
## Verlauf ist ein Ort.
func _tiefenverlauf(breite: float, hoehe: float) -> void:
    const STUFEN := 14
    for i in STUFEN:
        var t0 := float(i) / float(STUFEN)
        var t1 := float(i + 1) / float(STUFEN)
        var kraft := pow(t0, 2.1)
        _flaeche.draw_rect(Rect2(0.0, t0 * hoehe, breite, (t1 - t0) * hoehe + 1.0),
            Color(0.030, 0.090, 0.100, 0.30 * kraft))

    # Und ein Schein, der von unten heraufkommt - dieselbe Geste wie im
    # Schlund, wo die Kolonie unten leuchtet.
    for i in 7:
        var f := float(i + 1) / 7.0
        _flaeche.draw_circle(Vector2(breite * 0.5, hoehe * 1.06),
            breite * 0.42 * f, Color(0.10, 0.30, 0.30, 0.030 * (1.0 - f)))


## Angedeutete Felswand links und rechts, damit der Bildschirm im Graben
## bleibt und nicht wie ein aufgesetztes Menue wirkt.
##
## Drei Ebenen, wie im Schlund: die hintere hell und weich vom Wasserdunst,
## die vordere dunkel und scharf. Das ist derselbe Trick und derselbe Grund -
## ohne Versatz bleibt es eine Zeichnung.
func _grabenwand(breite: float, hoehe: float) -> void:
    const WAND_EBENEN := 3
    for ebene in WAND_EBENEN:
        var dunst := 1.0 - float(ebene) / float(WAND_EBENEN)
        var tiefe := RAND * (0.62 + 1.5 * (1.0 - dunst))
        var farbe := Color(0.045, 0.075, 0.095).lerp(
            Color(0.052, 0.112, 0.132), dunst)
        for seite: float in [0.0, 1.0]:
            var punkte := PackedVector2Array()
            var x0: float = seite * breite
            var richtung: float = 1.0 if seite < 0.5 else -1.0
            punkte.append(Vector2(x0, 0.0))
            for i in 19:
                var t := float(i) / 18.0
                var zack := tiefe * (1.0 + 0.5 * sin(t * 9.0 + seite * 3.0
                    + float(ebene) * 2.2)
                    + 0.22 * sin(t * 23.0 + float(ebene)))
                punkte.append(Vector2(x0 + richtung * zack, t * hoehe))
            punkte.append(Vector2(x0, hoehe))
            _flaeche.draw_colored_polygon(punkte, farbe)


## Meeresschnee hinter den Tafeln. Er bewegt sich - und Bewegung ist der
## Unterschied zwischen einem Bild vom Graben und dem Graben selbst.
func _schwebstoff(breite: float, hoehe: float) -> void:
    const FLOCKEN := 46
    for i in FLOCKEN:
        var saat := float(i) * 12.9898
        var x := fposmod(sin(saat) * 43758.5453, 1.0) * breite
        var tempo := 6.0 + fposmod(cos(saat) * 21237.13, 1.0) * 18.0
        var y := fposmod(fposmod(sin(saat * 1.7) * 1237.3, 1.0) * hoehe
            + _zeit * tempo, hoehe)
        var r := 0.8 + fposmod(sin(saat * 3.1) * 917.7, 1.0) * 1.9
        var glimmen := 0.5 + 0.5 * sin(_zeit * 0.7 + saat)
        _flaeche.draw_circle(Vector2(x, y), r,
            Color(0.44, 0.66, 0.72, 0.05 + 0.05 * glimmen))


func _kopfzeile(breite: float, stand: KolonieStand) -> void:
    _text(Vector2(RAND, 34.0), "COLONY", 21, SCHRIFT)
    _text(Vector2(RAND, 58.0), "Deepest wave %d  ·  rank %d of %d"
        % [stand.hoechste_welle,
           Geister.platz(stand.hoechste_welle), Geister.zahl() + 1], 14, LEISE)

    var rechts := breite - RAND
    _text(Vector2(rechts, 34.0), Zahl.kurz(stand.naehrstoffe), 21, NAEHR, false, true)
    var strom := stand.je_stunde()
    var zeile := "Nutrients" if strom <= 0.0 else "Nutrients  +%s/h" % Zahl.kurz(int(strom))
    _text(Vector2(rechts, 58.0), zeile, 13, LEISE, false, true)

    if stand.linie != Brutlinien.Linie.KEINE:
        _text(Vector2(breite * 0.5, 58.0), Brutlinien.name_von(stand.linie), 14,
            Brutlinien.farbe(stand.linie), true)

    _flaeche.draw_line(Vector2(0.0, KOPF), Vector2(breite, KOPF),
        Color(BAND_KANTE.r, BAND_KANTE.g, BAND_KANTE.b, 0.4), 1.4)


## Die Umschaltzeile: drei Reiter, der aktive hell.
func _umschalterzeile(breite: float) -> void:
    const BESCHRIFTUNG: PackedStringArray = ["CHAMBERS", "LINES", "SPECIES",
        "TRAITS", "DAY"]
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


## Der senkrechte Schnitt durch den Graben.
##
## **Das ist der Bildschirm, den der Plan beschreibt** - "die Kolonie als
## senkrechter Schnitt, Kammern werden nach unten gegraben". Bisher stand
## darueber eine Liste, und darunter war Platz. Eine Liste sagt, was man
## kaufen kann; ein Schnitt sagt, wo man ist.
##
## Der Schacht faellt in der Mitte, die Kammern haengen abwechselnd links und
## rechts daran. Jede waechst mit ihrer Stufe und leuchtet staerker - man
## sieht seine Kolonie also wachsen, statt es aus Zahlen abzuleiten.
## --- Der Fels, aus dem gegraben wird ---
##
## **Ohne ihn ist ein Schnitt kein Schnitt.** Der erste Entwurf zeichnete den
## Schacht und vier Kammern in einen leeren dunklen Kasten: fuenf umrandete
## Blasen, die im Nichts schwebten, verbunden mit gestrichelten Linien. Eine
## Kammer ist aber kein Objekt, sondern ein **Loch** - sie wird erst dadurch
## zur Kammer, dass um sie herum Stein steht. Genau das fehlte, und deshalb
## sah der wichtigste Bildschirm des Aufbauspiels aus wie ein Schaubild.
##
## Nach unten dunkler: hier ist es umgekehrt zum Wasser draussen. Im Graben
## streut die Strecke und macht Fernes heller; im Stein kommt kein Licht an,
## und je tiefer gegraben ist, desto weniger.
const FELS_OBEN := Color(0.062, 0.088, 0.104)
const FELS_UNTEN := Color(0.014, 0.026, 0.036)

## Der senkrechte Schnitt durch den Graben.
##
## **Das ist der Bildschirm, den der Plan beschreibt** - "die Kolonie als
## senkrechter Schnitt, Kammern werden nach unten gegraben". Eine Liste sagt,
## was man kaufen kann; ein Schnitt sagt, wo man ist.
##
## Der Schacht faellt in der Mitte, die Kammern haengen abwechselnd links und
## rechts daran. Jede waechst mit ihrer Stufe und leuchtet staerker - man
## sieht seine Kolonie also wachsen, statt es aus Zahlen abzuleiten.
func _schnitt(breite: float, oben: float, unten: float, stand: KolonieStand,
        _jetzt: float) -> void:
    var hoch := unten - oben
    if hoch < 140.0:
        return
    var mitte := breite * 0.5
    var tiefste := stand.stufe(Kammern.Kammer.TIEFENSCHACHT)
    var puls := 0.5 + 0.5 * sin(_zeit * 2.4)

    _text(Vector2(RAND, oben + 12.0), "THE COLONY", 13, LEISE)
    _text(Vector2(breite - RAND, oben + 12.0),
        "trench open to wave %d" % stand.offene_welle(), 12, LEISE, false, true)

    var kopf := oben + 30.0
    var fuss := unten - 16.0
    var spanne := fuss - kopf

    _fels(breite, kopf, fuss)

    # **Der Schacht laeuft durch.** Im ersten Entwurf endete er dort, wo
    # gerade gegraben ist - und die beiden unteren Kammern hingen frei im
    # Bild, weil ihre Gaenge ins Leere zeigten. Jetzt ist der ganze Schacht
    # da; hell ist, was gegraben wurde, und der Rest steht als Umriss.
    # **Wie tief der Schacht gezeichnet wird, misst nicht die Hoechststufe.**
    #
    # Hier stand `tiefste / Kammern.HOECHSTSTUFE`. Seit der Graben keinen
    # Boden mehr hat, ist die Hoechststufe 80 - bei Schacht 13, also einem
    # voellig normalen Stand, endete der Schacht nach einem Sechstel der
    # Hoehe, und drei der vier Kammern hingen darunter als "noch nicht
    # erreicht" im Bild. Das Bild sagte den ganzen Mittelteil des Spiels
    # lang: du hast noch nicht angefangen.
    #
    # Was der Tiefenschacht wirklich tut, ist Abschnitte aufmachen. Also
    # misst der gezeichnete Rest genau das: wie weit es von der Stufe, die
    # den jetzigen Abschnitt geoeffnet hat, bis zu der ist, die den naechsten
    # oeffnet. Die vier Kammern haengen ueber den oberen drei Vierteln und
    # sind immer angeschlossen; das untere Viertel ist die Anzeige.
    var offen_nr := Graben.abschnitt_gesamt(stand.offene_welle())
    var von := Ausbau.schacht_fuer_abschnitt(offen_nr)
    var ziel_stufe := stand.naechste_tiefe()
    var anteil := clampf(float(tiefste - von) / maxf(1.0, float(ziel_stufe - von)),
        0.0, 1.0)
    var letzte_kammer := 0.10 + 0.21 * 3.0
    var gegraben := letzte_kammer + 0.06 + (0.94 - letzte_kammer - 0.06) * anteil
    var spitze_y := kopf + spanne * gegraben
    var schachtfarbe: Color = FARBEN[Kammern.Kammer.TIEFENSCHACHT]

    var halb := 15.0
    var offen := PackedVector2Array([
        Vector2(mitte - halb, kopf), Vector2(mitte + halb, kopf),
        Vector2(mitte + halb * 0.62, spitze_y), Vector2(mitte - halb * 0.62, spitze_y),
    ])
    # Der Schacht ist ein Hohlraum: dunkler als der Fels, mit einem hellen
    # Saum an beiden Waenden. Dasselbe Mittel wie am Sockel in der
    # Schlundwache - was einem Loch Tiefe gibt, ist die Kante, nicht die
    # Flaeche.
    _flaeche.draw_colored_polygon(offen, Color(0.008, 0.018, 0.026))
    # **Und Licht darin.** Ein Hohlraum in fast schwarzem Fels ist unsichtbar:
    # der Schacht war dunkler als der Stein oben und heller als der Stein
    # unten, verschwand also auf halber Hoehe. Die Kolonie leuchtet aber
    # selbst - der Schacht ist der Weg, auf dem ihr Licht nach unten geht.
    # Oben hell, zur Bohrspitze hin aus.
    var schein := PackedColorArray()
    for v in offen:
        var t := clampf((v.y - kopf) / maxf(1.0, spitze_y - kopf), 0.0, 1.0)
        schein.append(Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b,
            0.30 * (1.0 - t) + 0.06))
    _flaeche.draw_polygon(offen, schein)
    for seite: float in SEITEN:
        _flaeche.draw_line(Vector2(mitte + seite * halb, kopf),
            Vector2(mitte + seite * halb * 0.62, spitze_y),
            Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.55), 2.0)

    # Was noch bevorsteht - nur angedeutet, in Strichen.
    if gegraben < 0.995:
        var y := spitze_y
        while y < fuss:
            var bis := minf(y + 9.0, fuss)
            var b := lerpf(halb * 0.62, halb * 0.24,
                (y - spitze_y) / maxf(1.0, fuss - spitze_y))
            _flaeche.draw_line(Vector2(mitte - b, y), Vector2(mitte - b, bis),
                Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.13), 1.2)
            _flaeche.draw_line(Vector2(mitte + b, y), Vector2(mitte + b, bis),
                Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.13), 1.2)
            y += 16.0

    # Die Bohrspitze: dort ist die Kolonie gerade angekommen.
    _flaeche.draw_circle(Vector2(mitte, spitze_y), 5.0 + 3.5 * puls,
        Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.22 + 0.24 * puls))
    _text(Vector2(mitte, spitze_y + 22.0), "shaft %d of %d" % [tiefste, ziel_stufe], 11,
        Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.7), true)

    # Vier Kammern am Schacht, abwechselnd links und rechts - ueber die ganze
    # Laenge verteilt, damit jeder Gang den Schacht auch trifft.
    var reihe: PackedInt32Array = [
        Kammern.Kammer.LEUCHTORGAN, Kammern.Kammer.ZUCHTKAMMER,
        Kammern.Kammer.BRUTKAMMER, Kammern.Kammer.FILTERBECKEN,
    ]
    for i in reihe.size():
        var k := reihe[i]
        var stufe := stand.stufe(k)
        var voll := clampf(float(stufe) / float(Kammern.HOECHSTSTUFE), 0.0, 1.0)
        var seite: float = SEITEN[i % 2]
        var y := kopf + spanne * (0.10 + 0.21 * float(i))
        # **Groesser und weiter aussen.** Bei 52 Pixeln Grundweite und einem
        # Abstand von 18 zum Schacht standen die vier Kammern in einer Spalte
        # von zweihundert Pixeln Breite, waehrend links und rechts je
        # zweihundertsechzig Pixel Fels leer blieben. Ein Schnitt soll die
        # Flaeche fuellen, die er bekommt.
        var weite := 130.0 + 110.0 * voll
        var kammerhoch := 21.0 + 20.0 * voll
        var wo := Vector2(mitte + seite * (halb + 26.0 + weite * 0.5), y)
        var farbe: Color = FARBEN[k]
        var baut_hier := stand.bau_kammer == k
        var erreicht := y <= spitze_y + 4.0

        # Der Gang: ein Hohlraum im Stein, kein Kabel. Er ist deshalb dunkler
        # als der Fels und hat oben und unten eine Kante.
        var gang_a := Vector2(mitte + seite * halb * 0.7, y)
        var dick := 5.0
        _flaeche.draw_line(gang_a, wo, Color(0.008, 0.018, 0.026),
            dick + 2.0)
        _flaeche.draw_line(gang_a, wo,
            Color(farbe.r, farbe.g, farbe.b, 0.30 if erreicht else 0.10), 1.2)

        # Eine gegrabene Blase, kein Rechteck. Ein Rechteck waere ein Raum,
        # den jemand gebaut hat; das hier ist aus dem Fels geholt.
        var blase := PackedVector2Array()
        for e in 13:
            var w := TAU * float(e) / 13.0
            var zerre := 1.0 + 0.13 * sin(float(e) * 2.7 + float(i) * 1.9)
            blase.append(wo + Vector2(cos(w) * weite * 0.5,
                sin(w) * kammerhoch) * zerre)

        var leuchten := 0.10 + 0.32 * voll
        if baut_hier:
            leuchten += 0.20 * puls

        # Erst der Hohlraum - dunkler als der Fels, damit die Kammer ein Loch
        # ist und kein Aufkleber -, dann das, was darin leuchtet.
        _flaeche.draw_colored_polygon(blase, Color(0.010, 0.020, 0.028))
        var farben := PackedColorArray()
        for v in blase:
            # Zur Schachtseite hin heller: das Licht der Kolonie kommt aus
            # dem Schacht, nicht aus dem Stein.
            var t := clampf(0.5 - 0.5 * (v.x - wo.x) * seite / maxf(1.0, weite * 0.5),
                0.0, 1.0)
            farben.append(Color(farbe.r, farbe.g, farbe.b,
                leuchten * (0.16 + 0.62 * t)))
        _flaeche.draw_polygon(blase, farben)
        _flaeche.draw_polyline(blase + PackedVector2Array([blase[0]]),
            Color(farbe.r, farbe.g, farbe.b, 0.28 + leuchten), 1.4, true)
        _flaeche.draw_circle(wo, 3.0 + 4.5 * voll,
            Color(farbe.r, farbe.g, farbe.b, 0.55 + 0.35 * leuchten))

        var beschriftung := "%s %d" % [Kammern.name_von(k).split(" ")[0], stufe]
        _text(wo + Vector2(0.0, kammerhoch + 15.0), beschriftung, 11,
            Color(farbe.r, farbe.g, farbe.b, 0.75), true)


## Der Stein, in dem die Kolonie sitzt: ein Verlauf nach unten und ein paar
## Schichten quer darueber.
##
## Die Schichten sind der billigste Weg zu Gestein - waagerecht, ungleich weit
## auseinander und nur wenige. Vier reichen; bei zwanzig waere es ein
## Notenblatt.
func _fels(breite: float, kopf: float, fuss: float) -> void:
    var ecken := PackedVector2Array([
        Vector2(0.0, kopf), Vector2(breite, kopf),
        Vector2(breite, fuss), Vector2(0.0, fuss),
    ])
    _flaeche.draw_polygon(ecken, PackedColorArray([
        FELS_OBEN, FELS_OBEN, FELS_UNTEN, FELS_UNTEN]))

    var spanne := fuss - kopf
    for i in 5:
        var t := 0.14 + 0.19 * float(i) + 0.03 * sin(float(i) * 2.9)
        var y := kopf + spanne * t
        _flaeche.draw_line(Vector2(0.0, y), Vector2(breite, y),
            Color(0.30, 0.44, 0.50, 0.055 + 0.02 * sin(float(i))), 1.0)


## Was die tragende Brutlinie mit dem Kegel macht - als Bild.
##
## Die Linien stehen als drei Saetze in der Liste, und ein Satz wie "der Kegel
## dreht schneller" laesst sich schwer mit einem anderen vergleichen. Hier
## steht derselbe Kegel viermal nebeneinander, einmal je Linie, und man sieht
## den Unterschied statt ihn zu lesen.
func _linienbild(breite: float, oben: float, unten: float,
        stand: KolonieStand) -> void:
    var hoch := unten - oben
    if hoch < 150.0:
        return

    _text(Vector2(RAND, oben + 12.0), "WHAT THE LINE CHANGES", 13, LEISE)

    # **Der Kegel darf den Platz nehmen, den er hat - aber nicht den des
    # Nachbarn.**
    #
    # Bei einem Deckel von 330 blieben unter dem Bild zweihundertachtzig
    # Pixel leer. Auf 470 hochgesetzt passte die Hoehe nicht mehr: Stromsinn
    # stand schraeg, sein weites Ende wanderte um hundertfuenfundfuenfzig
    # Pixel zur Seite bei einer Spalte von hunderteinundsiebzig - er lief in
    # den Kegel daneben. Die Neigung wieder herauszurechnen liess nur noch
    # hundertfuenfundzwanzig Pixel Hoehe uebrig, und dann war das Bild
    # winzig.
    #
    # **Also keine Neigung.** Ein schraeg stehender Kegel sagt ohnehin nicht
    # "er dreht schneller" - das sagt der Pfeil daneben. Und dieses Bild ist
    # zum **Vergleichen** da: vier aufrechte Kegel lassen sich in Weite und
    # Hitze nebeneinanderlegen, vier verschieden gekippte nicht. Die Hoehe
    # kommt jetzt aus der Spaltenbreite, damit keiner uebersteht.
    var breit := (breite - RAND * 2.0) / float(Brutlinien.zahl())
    # **Der laengste Kegel gibt den Massstab.**
    #
    # Tiefenblick reicht anderthalbmal so weit wie die anderen. Zeichnet man
    # ihn einfach laenger, laeuft er oben aus dem Kasten; setzt man dafuer
    # seine Spitze tiefer, steht seine Beschriftung hundertdreissig Pixel
    # unter allen anderen. Beides sieht nach Fehler aus. Also wird die
    # gemeinsame Hoehe durch den groessten Faktor geteilt: alle sieben teilen
    # sich Spitze und Oberkante, und der laengste fuellt den Platz genau aus.
    var laengster := maxf(1.0, Brutlinien.TIEFENBLICK_REICHWEITE)
    var kegelhoch := clampf(minf(hoch - 106.0, breit * 0.5 / sin(0.30)),
        90.0, 470.0) / laengster
    # **Senkrecht mittig, nicht oben angeschlagen.**
    #
    # Vorher stand das Bild direkt unter der Ueberschrift, mit der
    # Begruendung, es gehoere zu den Zeilen darueber. Die Weite der Kegel
    # haengt aber an der Spaltenbreite und nicht an der Hoehe: unter dem Bild
    # blieben zweihundertfuenfzig Pixel uebrig, und ein Loch am unteren Rand
    # liest sich als fehlender Inhalt. Mittig verteilt sich derselbe Rest auf
    # beide Seiten und liest sich als Rand.
    var block := kegelhoch + 36.0
    var mitte_y := (oben + 30.0 + unten) * 0.5 - 18.0
    mitte_y = maxf(mitte_y, oben + 40.0 + kegelhoch * 0.5)
    if block + 70.0 > hoch:
        mitte_y = oben + 40.0 + kegelhoch * 0.5

    for index in Brutlinien.zahl():
        var mitte_x := RAND + breit * (float(index) + 0.5)
        var traegt := stand.linie == index
        var hat := stand.hat_linie(index)
        var farbe := Brutlinien.farbe(index)
        var spitze := Vector2(mitte_x, mitte_y + kegelhoch * 0.5)

        # Der Kegel selbst. Kaltbrand ist schmaler und heisser, Stromsinn
        # steht schraeg - er dreht schneller, also faengt er auch, was
        # seitlich kommt.
        var halb := 0.30
        var neigung := 0.0
        var glut := 0.44
        # Tiefenblick aendert die **Form**, nicht die Staerke - also muss der
        # Kegel hier wirklich schmaler und laenger stehen. Ohne das saehe die
        # einzige Linie, die man an ihrem Umriss erkennt, aus wie keine.
        var laenger := 1.0
        match index:
            Brutlinien.Linie.TIEFENBLICK:
                halb = 0.30 * Brutlinien.TIEFENBLICK_WINKEL
                laenger = Brutlinien.TIEFENBLICK_REICHWEITE
            Brutlinien.Linie.KALTBRAND:
                # Deutlich schmaler und deutlich heisser. Bei 0.20 gegen 0.30
                # war der Unterschied im Bild eine Handbreit - und "ein Ziel
                # weniger, jedes haerter" ist die Linie, bei der man ihn am
                # ehesten sehen muss.
                halb = 0.15
                glut = 0.95
        var achse := Vector2.UP.rotated(neigung)

        # **Auch eine Linie, die man nicht hat, muss man sehen koennen.**
        #
        # Hier stand `0.26` fuer verschlossene Linien, multipliziert auf eine
        # Kegeldeckung von `0.36 * 0.10` - das ergibt neun Tausendstel. Im
        # Bild standen vier praktisch leere Rechtecke mit Namen darunter.
        # Der ganze Zweck dieses Bildes ist der **Vergleich**: es soll zeigen,
        # wofuer man spart. Was verschlossen ist, wird durch den gedaempften
        # Namen und den fehlenden Rahmen kenntlich, nicht durch
        # Unsichtbarkeit.
        var deckung := 1.0 if traegt else (0.78 if hat else 0.55)

        # **Ein Verlauf, keine vier gestapelten Dreiecke.**
        #
        # Vier ineinanderliegende Dreiecke mit fester Deckung geben vier
        # sichtbare Kanten im Kegel - dieselbe Sache, die schon bei den
        # Schlickschwaden und am Leib des Waechters schiefging. Eine Flaeche
        # mit Farbe je Eckpunkt kann, was eine Stapelung nicht kann: auf der
        # Achse voll und an den Flanken genau null.
        # Der laengere Kegel darf nicht aus dem Kasten laufen: was ueber die
        # gemeinsame Hoehe hinausginge, wird von der Spitze abgezogen.
        var weit := kegelhoch * laenger
        var strahl := PackedVector2Array([spitze])
        var farben := PackedColorArray([
            Color(farbe.r, farbe.g, farbe.b, 0.42 * glut * deckung)])
        var rippen := 14
        for e in rippen + 1:
            var w := lerpf(-halb, halb, float(e) / float(rippen))
            var rand_ab := 1.0 - pow(absf(w) / maxf(0.001, halb), 1.6)
            strahl.append(spitze + achse.rotated(w) * weit)
            farben.append(Color(farbe.r, farbe.g, farbe.b,
                0.30 * glut * deckung * rand_ab))
        _flaeche.draw_polygon(strahl, farben)

        # Ein Saum an beiden Flanken - er macht die Weite des Kegels
        # ablesbar, und genau die unterscheidet Kaltbrand von den anderen.
        for s_seite: float in SEITEN:
            _flaeche.draw_line(spitze,
                spitze + achse.rotated(s_seite * halb) * weit,
                Color(farbe.r, farbe.g, farbe.b, 0.34 * deckung), 1.4)

        # Stromsinn: ein Bogen mit Spitze - er dreht schneller. Ein gerader
        # Strich sah aus wie eine Stroemung, die von aussen draufhaelt; was
        # die Linie tut, ist aber schwenken.
        if index == Brutlinien.Linie.STROMSINN:
            var r := kegelhoch * 0.36
            var bogen := PackedVector2Array()
            for e in 13:
                var w := lerpf(-0.85, 0.85, float(e) / 12.0)
                bogen.append(spitze + Vector2.UP.rotated(w) * r)
            _flaeche.draw_polyline(bogen,
                Color(farbe.r, farbe.g, farbe.b, 0.55 * deckung), 1.8, true)
            var ende: Vector2 = bogen[bogen.size() - 1]
            var vor := (ende - bogen[bogen.size() - 2]).normalized()
            for s_dreh: float in SEITEN:
                _flaeche.draw_line(ende,
                    ende - vor.rotated(s_dreh * 0.7) * 9.0,
                    Color(farbe.r, farbe.g, farbe.b, 0.55 * deckung), 1.8)

        # Nachglut: Punkte, die hinter dem Kegel weiterbrennen.
        if index == Brutlinien.Linie.NACHGLUT:
            for k in 4:
                var t := float(k) / 3.0
                var wo := spitze + achse * kegelhoch * (0.45 + 0.3 * t) \
                    + Vector2(28.0 + 12.0 * t, 0.0)
                _flaeche.draw_circle(wo, 3.4 - 0.7 * float(k),
                    Color(farbe.r, farbe.g, farbe.b,
                        (0.55 - 0.11 * float(k)) * deckung))

        # Ziele als kleine Ringe: Kaltbrand hat einen weniger, aber heller.
        #
        # **Zwei Linien wirken nicht auf den Kegel, sondern auf das Ziel** -
        # Salzbrand auf seinen Panzer, Zwielicht auf die Schwelle, ab der es
        # ueberhaupt brennt. Die stehen deshalb an den Zielen und nicht am
        # Strahl: Zwielicht setzt sie an den **Rand** des Kegels, wo sie sonst
        # nichts abbekaemen, Salzbrand zeigt sie mit gesprungener Schale.
        var ziele := 3 if index != Brutlinien.Linie.KALTBRAND else 2
        var am_rand := index == Brutlinien.Linie.ZWIELICHT
        for k in ziele:
            var t := (float(k) + 0.5) / float(ziele)
            var quer := lerpf(-halb * 0.55, halb * 0.55, t)
            if am_rand:
                quer = halb * (0.86 if k % 2 == 0 else -0.86)
            var wo := spitze + achse.rotated(quer) \
                * weit * (0.44 + 0.10 * float(k % 2))
            _flaeche.draw_circle(wo, (5.0 + 3.0 * glut) * 1.8,
                Color(farbe.r, farbe.g, farbe.b, 0.10 * deckung))
            var ring := 5.0 + 3.0 * glut
            if index == Brutlinien.Linie.SALZBRAND:
                # Gesprungen: zwei Boegen mit einer Luecke statt eines Kreises.
                for haelfte in 2:
                    var a0 := PI * float(haelfte) + 0.34
                    _flaeche.draw_arc(wo, ring, a0, a0 + PI - 0.68, 10,
                        Color(1.0, 0.98, 0.94, (0.42 + 0.5 * glut) * deckung), 1.6)
                _flaeche.draw_line(wo + Vector2(-ring, 0.0), wo + Vector2(ring, 0.0),
                    Color(farbe.r, farbe.g, farbe.b, 0.55 * deckung), 1.4)
            else:
                _flaeche.draw_arc(wo, ring, 0.0, TAU, 14,
                    Color(1.0, 0.98, 0.94, (0.42 + 0.5 * glut) * deckung), 1.6)

        var beschriftung := Brutlinien.name_von(index)
        _text(Vector2(mitte_x, spitze.y + 20.0), beschriftung, 11,
            Color(farbe.r, farbe.g, farbe.b, 0.85 if traegt else 0.45), true)
        if traegt:
            _text(Vector2(mitte_x, spitze.y + 36.0), "carries", 10, NAEHR, true)


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


## Eine Mutation im Nachschlagewerk. Dieselbe Bauform wie ein Artband, aus
## demselben Grund: was einen im Graben umbringt, muss man nachlesen koennen.
## Was man noch nie gesehen hat, bleibt verdeckt - eine Liste, die alles
## vorwegnimmt, nimmt jeder Begegnung ihren Moment.
func _mutationsband(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var kennt := stand.kennt_mutation(index)
    var farbe := MUTATION if kennt else Color(0.34, 0.44, 0.50)

    _flaeche.draw_rect(kasten, Color(BAND_FARBE.r, BAND_FARBE.g, BAND_FARBE.b,
        0.88 if kennt else 0.52))
    _flaeche.draw_rect(kasten, Color(farbe.r, farbe.g, farbe.b, 0.28), false, 1.4)
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(farbe.r, farbe.g, farbe.b, 0.85 if kennt else 0.30))

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _mutationssinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 22.0, index,
        farbe, kennt)

    var links := kasten.position.x + 84.0
    _text(Vector2(links, mitte_y - 6.0),
        Mutationen.name_von(index) if kennt else "Not yet encountered", 17,
        SCHRIFT if kennt else LEISE)
    _text(Vector2(links, mitte_y + 18.0),
        Mutationen.hinweis(index) if kennt
            else "Waves start to mutate in trench depth II",
        12, LEISE if kennt else Color(0.34, 0.44, 0.50))


## Ein Zeichen je Mutation - gerechnet wie alles andere. Sechs Ringe, und was
## die Mutation tut, tut auch das Zeichen: der gepanzerte ist doppelt, der
## lichtscheue halb ausgeblendet, der unstete versetzt.
func _mutationssinnbild(p: Vector2, r: float, index: int, farbe: Color,
        kennt: bool) -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 1.5 + float(index))
    _flaeche.draw_circle(p, r * 1.2, Color(farbe.r, farbe.g, farbe.b,
        0.06 + 0.06 * puls))
    if not kennt:
        _flaeche.draw_arc(p, r * 0.8, 0.0, TAU, 20,
            Color(farbe.r, farbe.g, farbe.b, 0.35), 1.2)
        _text(p + Vector2(0.0, 6.0), "?", 18, Color(farbe.r, farbe.g, farbe.b,
            0.55), true)
        return

    var hell := Color(farbe.r, farbe.g, farbe.b, 0.9)
    match index:
        Mutationen.Mutation.PANZERUNG:
            _flaeche.draw_arc(p, r * 0.86, 0.0, TAU, 24, hell, 2.2)
            _flaeche.draw_arc(p, r * 0.58, 0.0, TAU, 20, hell, 1.4)
        Mutationen.Mutation.LICHTSCHEU:
            _flaeche.draw_arc(p, r * 0.8, -PI * 0.5, PI * 0.5, 16, hell, 2.0)
            _flaeche.draw_arc(p, r * 0.8, PI * 0.5, PI * 1.5, 16,
                Color(hell.r, hell.g, hell.b, 0.2), 2.0)
        Mutationen.Mutation.UNSTET:
            for i in 3:
                var v := (float(i) - 1.0) * r * 0.62
                _flaeche.draw_line(p + Vector2(v - r * 0.3, -r * 0.7),
                    p + Vector2(v + r * 0.3, r * 0.7), hell, 1.8)
        Mutationen.Mutation.SCHUB:
            for i in 3:
                var y := p.y + (float(i) - 1.0) * r * 0.6
                var b := r * (0.3 + 0.28 * float(i))
                _flaeche.draw_line(Vector2(p.x - b, y), Vector2(p.x + b, y),
                    hell, 1.8)
        Mutationen.Mutation.HAST:
            for i in 3:
                var y := p.y + (float(i) - 1.0) * r * 0.5
                _flaeche.draw_line(Vector2(p.x - r * 0.8, y),
                    Vector2(p.x + r * 0.8 - float(i) * r * 0.2, y), hell, 1.8)
        Mutationen.Mutation.AUFGEDUNSEN:
            _flaeche.draw_circle(p, r * 0.72, Color(hell.r, hell.g, hell.b, 0.28))
            _flaeche.draw_arc(p, r * 0.72, 0.0, TAU, 24, hell, 1.8)


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
        Arten.Art.SPIEGLER:
            # Ein facettierter Panzer und ein Strahl, der daran umkehrt -
            # genau das, was die Regel sagt.
            _flaeche.draw_arc(p + Vector2(0.0, r * 0.3), r * 0.8, PI, TAU, 18,
                farbe, 2.2)
            for i in 3:
                var x := lerpf(-r * 0.5, r * 0.5, float(i) / 2.0)
                _flaeche.draw_line(p + Vector2(x, r * 0.3),
                    p + Vector2(x * 0.45, -r * 0.4),
                    Color(farbe.r, farbe.g, farbe.b, 0.55), 1.4)
            _flaeche.draw_line(p + Vector2(-r * 0.75, -r * 0.9),
                p + Vector2(0.0, -r * 0.2), Color(1.0, 1.0, 0.96, 0.85), 1.8)
            _flaeche.draw_line(p + Vector2(0.0, -r * 0.2),
                p + Vector2(r * 0.75, -r * 0.9), Color(1.0, 1.0, 0.96, 0.85), 1.8)
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
            "Wave %d" % int(eintrag[&"tiefe"]), 14, farbe, false, true)
        zeile_y += 34.0

    return zeile_y


## Schaltet die Ansicht um. Nur fuer die Entwicklerschalter - im Spiel tippt
## man die Reiter an.
func zeige_reiter(welche: int) -> void:
    _sicht = clampi(welche, 0, Sicht.size() - 1) as Sicht


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
        var davor := Brutlinien.voraussetzung(index)
        var frei := stand.hat_linie(davor)
        var preis := Brutlinien.kosten(index)
        var reicht := frei and stand.naehrstoffe >= preis
        _text(Vector2(rechts, mitte_y - 6.0), "breed", 13, LEISE, false, true)
        _text(Vector2(rechts, mitte_y + 16.0), Zahl.kurz(preis) if frei else "locked", 18,
            NAEHR if reicht else SPERRE, false, true)
        # **"locked" allein ist keine Auskunft, sondern eine Absage.**
        #
        # Fuenf von sechs Zeilen standen auf "locked", und nirgends stand,
        # woran es liegt. Wer das sieht, haelt die Linien fuer etwas, das
        # spaeter irgendwie kommt - dabei ist die Bedingung genau eine, und
        # sie steht eine Zeile weiter oben im selben Bildschirm.
        if not frei:
            _text(Vector2(links, kasten.position.y + 78.0),
                "Needs %s first" % Brutlinien.name_von(davor), 12,
                Color(0.62, 0.52, 0.48))


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
        Brutlinien.Linie.SALZBRAND:
            # Ein gesprungener Panzer: die Platte bleibt, der Riss geht durch.
            var schale := PackedVector2Array()
            for k in 9:
                var w := lerpf(-PI * 0.9, PI * 0.9, float(k) / 8.0)
                schale.append(p + Vector2(cos(w), sin(w) * 0.82) * r * 0.9)
            _flaeche.draw_polyline(schale,
                Color(farbe.r, farbe.g, farbe.b, 0.60 * deckung), 2.2, true)
            var riss := PackedVector2Array([
                p + Vector2(-r * 0.55, -r * 0.60),
                p + Vector2(-r * 0.12, -r * 0.10),
                p + Vector2(-r * 0.30, r * 0.18),
                p + Vector2(r * 0.20, r * 0.72),
            ])
            _flaeche.draw_polyline(riss,
                Color(1.0, 0.94, 0.72, 0.90 * deckung), 2.0, true)
        Brutlinien.Linie.TIEFENBLICK:
            # Ein schmaler Keil, der ueber den Rand hinausreicht.
            var keil := PackedVector2Array([
                p + Vector2(0.0, r * 0.95),
                p + Vector2(-r * 0.30, -r * 1.05),
                p + Vector2(r * 0.30, -r * 1.05),
            ])
            _flaeche.draw_colored_polygon(keil,
                Color(farbe.r, farbe.g, farbe.b, 0.20 * deckung))
            _flaeche.draw_polyline(keil + PackedVector2Array([keil[0]]),
                Color(farbe.r, farbe.g, farbe.b, 0.70 * deckung), 1.6, true)
            _flaeche.draw_circle(p + Vector2(0.0, -r * 0.85), r * 0.14,
                Color(1.0, 1.0, 0.96, 0.85 * deckung))
        Brutlinien.Linie.ZWIELICHT:
            # Zwei Schwellen, die sich zur Mitte hin aufloesen: aussen hart,
            # innen ein Verlauf. Das ist genau, was die Linie tut.
            for seite: float in SEITEN:
                var x := p.x + seite * r * 0.72
                _flaeche.draw_line(Vector2(x, p.y - r * 0.8),
                    Vector2(x, p.y + r * 0.8),
                    Color(farbe.r, farbe.g, farbe.b, 0.70 * deckung), 2.0)
            for i in 7:
                var t := float(i) / 6.0
                var x2 := lerpf(p.x - r * 0.66, p.x + r * 0.66, t)
                var kraft := 1.0 - absf(t - 0.5) * 2.0
                _flaeche.draw_line(Vector2(x2, p.y - r * 0.5),
                    Vector2(x2, p.y + r * 0.5),
                    Color(farbe.r, farbe.g, farbe.b,
                        (0.12 + 0.42 * kraft) * deckung), 1.4)


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
        var naechste_welle := stand.offene_welle() + 1
        zweite = "%s opens at level %d" % [
            Regeln.name_von(Graben.abschnitt(naechste_welle))
                + Graben.tiefe_zeichen(naechste_welle),
            stand.naechste_tiefe()]
        if stand.graben_haelt():
            zweite_farbe = NAEHR
    _text(Vector2(links, kasten.position.y + 52.0), zweite, 12, zweite_farbe)

    # Was die Stufe konkret bringt - jetzt und nach dem naechsten Ausbau.
    # Die Zahlen kommen aus `Kammern.wirkung()`, also aus derselben Rechnung,
    # die das Spiel benutzt. Ein zweiter Satz Zahlen fuer die Anzeige waere
    # eine zweite Wahrheit, und die laeuft auseinander.
    var jetzt_wirkt := Kammern.wirkung(k, stufe)
    var dann_wirkt := Kammern.wirkung(k, stufe + 1)
    var wirkzeile := jetzt_wirkt
    if dann_wirkt != jetzt_wirkt and stufe < Kammern.deckel(k, stand.schacht()):
        wirkzeile = "%s   →   %s" % [jetzt_wirkt, dann_wirkt]
    _text(Vector2(links, kasten.position.y + 100.0), wirkzeile, 12,
        Color(farbe.r, farbe.g, farbe.b, 0.78))

    var deckel := Kammern.deckel(k, stand.schacht())
    var rechts := kasten.end.x - 12.0
    # Die Zeile endet vor der Preisspalte, nicht am Kastenrand - sonst laeuft
    # sie unter die Zahl.
    _stufenzeile(Vector2(links, kasten.position.y + 78.0),
        maxf(40.0, rechts - links - 96.0), stufe, deckel, farbe)
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
        # "to 9" und nicht "Level 9": links steht schon eine Stufe, und zwei
        # Zahlen mit demselben Wort davor liest man als Widerspruch.
        _text(Vector2(rechts, mitte_y - 6.0), "to %d" % (stufe + 1), 13, LEISE, false, true)
        _text(Vector2(rechts, mitte_y + 16.0), Zahl.kurz(preis), 18,
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


## Die Stufenzeile: **eine Zahl**, ein schmaler Balken und der Deckel.
##
## **Hier stand eine Punktreihe, ein Punkt je Stufe.** Das war lesbar, solange
## die Hoechststufe 20 war. Seit der Graben keinen Boden mehr hat, sind es 80
## - achtzig Punkte nebeneinander, von denen acht gefuellt waren. Niemand
## zaehlt achtzig Punkte ab; man sieht "viele Punkte, vorne ein bisschen
## voll", und das ist keine Auskunft, sondern ein Muster.
##
## Eine Zahl ist an dieser Stelle beides zugleich: genau und sofort ablesbar.
## Der Balken daneben behaelt, was die Punktreihe konnte und die Zahl nicht -
## das Gefuehl, wie weit es noch geht -, und er zeigt zusaetzlich den Deckel,
## den der Tiefenschacht setzt.
const BALKEN_HOCH := 5.0


func _stufenzeile(wo: Vector2, breite: float, stufe: int, deckel: int,
        farbe: Color) -> void:
    var beschriftung := "LEVEL %d" % stufe
    _text(wo + Vector2(0.0, 5.0), beschriftung, 15, farbe)

    # Der Balken beginnt hinter der Zahl. 96 statt einer gemessenen Breite,
    # weil `draw_string` die Breite nur ueber einen zweiten Aufruf hergibt und
    # die Zahl hier nie mehr als vier Zeichen hat.
    var links := wo.x + 96.0
    var weit := maxf(30.0, wo.x + breite - links)
    var y := wo.y

    # **Der Balken misst gegen den Deckel, nicht gegen die Hoechststufe.**
    #
    # Gegen 80 gemessen ist Stufe 7 ein Strich von vier Pixeln - richtig
    # gerechnet und trotzdem nutzlos, weil die Hoechststufe kein Ziel ist,
    # das jemand vor sich hat. Der Deckel ist eines: bis dahin geht es, und
    # dann muss der Tiefenschacht tiefer. Der Balken fuellt sich also bis zur
    # naechsten Schranke und faengt danach neu an.
    var bis := float(maxi(1, deckel))
    var anteil := clampf(float(stufe) / bis, 0.0, 1.0)

    _flaeche.draw_rect(Rect2(links, y - BALKEN_HOCH * 0.5, weit, BALKEN_HOCH),
        Color(0.34, 0.36, 0.38, 0.24))
    _flaeche.draw_rect(Rect2(links, y - BALKEN_HOCH * 0.5, weit * anteil,
        BALKEN_HOCH), farbe)

    # Wo Schluss ist. Nur wenn es einen Deckel gibt - wer die Hoechststufe
    # erreicht hat, braucht keine Schranke mehr angezeigt zu bekommen.
    if deckel < Kammern.HOECHSTSTUFE:
        _text(Vector2(wo.x + breite, y + 5.0), "of %d" % deckel, 11,
            NAEHR if stufe >= deckel else LEISE, false, true)


## Setzt den Lehrschritt. `wache.gd` ruft das; -1 heisst: nichts anzeigen.
func zeige_einstieg(schritt: int) -> void:
    _lehre = schritt


## Dieselbe Tafel wie im HUD, nur ohne Ring: hier zeigt der Bildschirm selbst
## schon auf die Kammern, weil er aus nichts anderem besteht.
func _lehrtafel(breite: float, hoehe: float) -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 2.0)
    var kasten := Rect2(RAND, hoehe - FUSS - 74.0, breite - RAND * 2.0, 64.0)
    _flaeche.draw_rect(kasten, Color(0.035, 0.105, 0.135, 0.92))
    _flaeche.draw_rect(kasten, Color(0.42, 0.86, 0.92, 0.24 + 0.16 * puls),
        false, 1.4)
    _flaeche.draw_rect(Rect2(kasten.position, Vector2(3.0, kasten.size.y)),
        Color(0.52, 0.94, 0.86, 0.85))
    _text(Vector2(kasten.position.x + 16.0, kasten.position.y + 25.0),
        Lehrpfad.titel(_lehre), 16, NAEHR)
    _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 24.0),
        "%d/%d" % [_lehre + 1, Lehrpfad.anzahl()], 12, LEISE, false, true)
    _text(Vector2(kasten.position.x + 16.0, kasten.position.y + 48.0),
        Lehrpfad.satz(_lehre), 13, SCHRIFT)


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
