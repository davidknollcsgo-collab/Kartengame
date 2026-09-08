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

## Was auf dem Schliessknopf steht.
##
## **Er sagt, wohin er zurueckfuehrt, und das ist nicht mehr immer derselbe
## Ort.** Diese Ebene haengt jetzt in beiden Schleifen; "BACK TO THE MAW" in
## einem Boot mitten im Graben ist schlicht falsch. Der Wirt setzt es.
var zurueck_beschriftung := "BACK TO THE MAW"

const RAND := 18.0
const KOPF := 96.0
const FUSS := 78.0
const BAND := 116.0
const BAND_TAG := 68.0
## **Ein Zug ist zwei Zeilen, kein halbes Blatt.** Hier wurde die Bandhoehe
## einmal auf die freie Flaeche gestreckt, weil sechs Eintraege in
## Normalhoehe das untere Drittel leer liessen - "das sieht nach fehlendem
## Inhalt aus". Das Ergebnis war schlimmer als der Anlass: sechs Kaesten von
## zweihundertzwanzig Pixeln mit je einem Namen und einer Zeile darin, also
## sechsmal ein Loch statt eines am Ende. Rand unter einer kurzen Liste ist
## Rand; ein aufgeblasener Eintrag ist ein Fehler.
const BAND_ZUG := 88.0
const LUECKE := 10.0

## Wie hoch der Fuss des Tagesreiters ist: eine Zeile Anwesenheit und
## Bestmarken, mehr nicht.
##
## **Er stand auf 224, und das war der Platz fuer die Einstellungen.** Seit
## die auf dem Bootsreiter liegen, blieben dreihundert Pixel Nichts zwischen
## der Rangliste und einer Zeile, die ganz unten allein herumstand - der
## Reiter sah aus, als fehle etwas. Eine Zahl, die einmal richtig war, wird
## falsch, sobald das weg ist, wofuer sie stand.
##
## **Als Zahl an einer Stelle, nicht zweimal als Literal.** Die Bildratenzeile
## kam einmal dazu, und weil die Hoehe an zwei Stellen stand, wanderte der
## Loeschknopf unter den Bildrand statt der Rest nach oben.
const TAGESFUSS_HOCH := 54.0

## Hoehe einer Einstellungszeile und eines Anstrichfeldes. Beide ueber
## vierzig Pixel, damit ein Daumen sie trifft - 34 waren zu knapp.
const ZEILE := 52.0
const SKINHOCH := 66.0

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

## Was das Geraet fuer sich beansprucht - dieselbe Rechnung wie im HUD, aus
## demselben Grund: Kopfzeile unter der Kerbe, Fusszeile unter dem
## Gestenbalken. Siehe `hud.gd::_miss_geraeterand()`.
var _rand_oben := 0.0
var _rand_unten := 0.0
var _rand_seite := 0.0


func _miss_geraeterand() -> void:
    # **Nur auf dem Telefon fragen.** `get_display_safe_area()` liefert auf
    # dem Schreibtisch den ganzen *Bildschirm*, nicht das Fenster - und der
    # ist gerne kleiner als ein Hochformatfenster von 1280 Pixeln. Aus der
    # Differenz wurde dann ein unterer Rand von vierhundert Pixeln, und die
    # Knopfzeile sprang mitten ins Bild. Der Aufnahmelauf hat es sofort
    # gezeigt; auf einem Telefon waere es richtig gewesen und hier falsch.
    if not OS.has_feature("mobile"):
        return
    var fenster := DisplayServer.window_get_size()
    if fenster.x <= 0 or fenster.y <= 0 or _flaeche.size.x <= 0.0:
        return
    var sicher := DisplayServer.get_display_safe_area()
    if sicher.size.x <= 0 or sicher.size.y <= 0:
        return
    var skala := _flaeche.size / Vector2(fenster)
    # Und gedeckelt: kein Geraet nimmt sich ein Achtel des Bildes. Was
    # darueber liegt, ist eine Fehlmessung und keine Kerbe.
    var deckel := _flaeche.size * 0.12
    _rand_oben = clampf(float(sicher.position.y) * skala.y, 0.0, deckel.y)
    _rand_unten = clampf(
        float(fenster.y - sicher.position.y - sicher.size.y) * skala.y,
        0.0, deckel.y)
    var links := float(sicher.position.x) * skala.x
    var rechts := float(fenster.x - sicher.position.x - sicher.size.x) * skala.x
    _rand_seite = clampf(maxf(links, rechts), 0.0, deckel.x)


@onready var _flaeche: Control = $Flaeche

var _schrift: Font
var _zeit := 0.0
var _baender: Array[Rect2] = []
var _schliessen := Rect2()
var _reiter: Array[Rect2] = []

## Vier Ansichten statt einer langen Liste: fuenf Kammern, drei Linien, acht
## Arten und der Tag nebeneinander waeren auf einem Telefon zwanzig gedraengte
## Zeilen.
## **Der Bootsreiter ist entstanden, weil der Tagesreiter eine Rumpelkammer
## war.** Dort standen Tagesziele, Zuchtkalender, Rangliste **und** saemtliche
## Einstellungen samt Lizenzzeile und Loeschknopf untereinander - und als eine
## Einstellung dazukam, fiel der Loeschknopf unter den Bildrand. Was nichts
## miteinander zu tun hat, gehoert nicht in dieselbe Liste, und ein Reiter,
## der nach unten ueberlaeuft, sagt das nur nicht.
enum Sicht { KAMMERN, LINIEN, ARTEN, ZUEGE, TAG, BOOT }
var _sicht := Sicht.KAMMERN

## Tippziele der Tagesansicht, in Bildschirmkoordinaten.
var _kalender := Rect2()
var _lauter := Rect2()
var _beben := Rect2()
var _bildrate := Rect2()
var _autobau := Rect2()
var _skinfelder: Array[Rect2] = []
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
            # Wer den Tagesreiter aufschlaegt, hat den Satz darueber gelesen.
            if _sicht == Sicht.TAG:
                _einstieg_weiter(&"TAG")
            _loeschen_sicher = false
            _meldung_leben = 0.0
            return

    if _sicht == Sicht.TAG and _kalender.has_point(ort):
        _hole_kalender()
        return

    if _sicht == Sicht.BOOT:
        for i in _skinfelder.size():
            if not _skinfelder[i].has_point(ort):
                continue
            var st2 := Fortschritt.stand
            if st2.waehle_skin(i):
                Klang.spiele(Klang.Ton.TIPP, 1.0, 1.15)
                _zeige("%s on the hull" % Skins.name_von(i))
                Fortschritt.sichere()
            else:
                # **Sagen, was fehlt, statt nichts zu tun.** Ein Tipp, auf
                # den gar nichts folgt, sieht aus wie ein kaputter Knopf.
                Klang.spiele(Klang.Ton.TIPP, 0.5, 0.7)
                _zeige("Reach wave %d to earn this" % Skins.ab_welle(i))
            return
        if _lauter.has_point(ort):
            Klang.laut = Klang.laut + 0.2
            Klang.spiele(Klang.Ton.TIPP)
            Fortschritt.merke_einstellungen()
            return
        if _leiser.has_point(ort):
            Klang.laut = Klang.laut - 0.2
            Klang.spiele(Klang.Ton.TIPP)
            Fortschritt.merke_einstellungen()
            return
        if _beben.has_point(ort):
            Tastsinn.an = not Tastsinn.an
            Klang.spiele(Klang.Ton.TIPP)
            Tastsinn.gib(Tastsinn.Art.STOSS)
            Fortschritt.merke_einstellungen()
            return
        if _bildrate.has_point(ort):
            # Reihum: frei, 60, 120. Drei Werte auf einem Knopf statt drei
            # Knoepfen - es ist eine Einstellung, die man einmal trifft.
            var stand := Fortschritt.stand
            stand.bildrate = 60 if stand.bildrate == 0 \
                else (120 if stand.bildrate == 60 else 0)
            Klang.spiele(Klang.Ton.TIPP)
            Fortschritt.merke_einstellungen()
            return
        if _autobau.has_point(ort):
            var st := Fortschritt.stand
            st.auto_ausbau = not st.auto_ausbau
            Klang.spiele(Klang.Ton.TIPP)
            Fortschritt.merke_einstellungen()
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
        # Getan, wovon der Satz redet - erst die Kammer, dann der Schacht.
        _einstieg_weiter(&"KAMMER")
        _einstieg_weiter(&"WOFUER")
        if kammer == Kammern.Kammer.TIEFENSCHACHT:
            _einstieg_weiter(&"SCHACHT")
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


## Zuechten oder, wenn schon gezuechtet, auf einen Platz legen und wieder
## herunternehmen.
func _versuche_linie(index: int) -> void:
    var stand: KolonieStand = Fortschritt.stand
    if stand.hat_linie(index):
        if stand.linie_traegt(index):
            # Herunternehmen ist ausdruecklich erlaubt: ein Aufbau, den man
            # nur ergaenzen und nie umstellen kann, ist keine Wahl.
            if stand.schalte_linie(index):
                Klang.spiele(Klang.Ton.TIPP, 0.9)
                Fortschritt.sichere()
                Fortschritt.stand_geaendert.emit()
                _zeige("%s stood down" % Brutlinien.name_von(index))
        elif stand.schalte_linie(index):
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
        _einstieg_weiter(&"LINIEN")
        Fortschritt.sichere()
        Fortschritt.stand_geaendert.emit()
        _zeige("%s bred" % Brutlinien.name_von(index))


func _zeige(was: String) -> void:
    _meldung = was
    _meldung_leben = 2.4


# --- Zeichnen --------------------------------------------------------------

func _zeichne() -> void:
    _miss_geraeterand()
    _fuehre_einstieg()
    var breite := _flaeche.size.x
    # Der Fuss haengt am unteren Rand; was das Geraet dort beansprucht, muss
    # von der nutzbaren Hoehe ab, sonst liegt "BACK TO THE MAW" unter dem
    # Gestenbalken.
    var hoehe := _flaeche.size.y - _rand_unten
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
    elif _sicht == Sicht.BOOT:
        # Der Bootsreiter hat keine Bandliste - er zeichnet sich selbst.
        # `_fusszeile` muss trotzdem kommen: ohne sie faehrt niemand zurueck.
        _kalender = Rect2()
        _bootreiter(breite, hoehe, stand)
        _fusszeile(breite, hoehe)
        if _meldung_leben > 0.0:
            var mf := clampf(_meldung_leben / 0.6, 0.0, 1.0)
            _text(Vector2(breite * 0.5, hoehe - FUSS - 16.0), _meldung, 16,
                Color(0.88, 0.96, 1.0, mf), true)
        return
    var oben := KOPF + _rand_oben + 58.0
    # **Eine Erklaerung, nicht sechs.** Auf dem Zuegereiter stand vor der
    # ersten Begegnung sechsmal dasselbe Band: "Not yet encountered / Waves
    # start to mutate in trench depth II". Sechs gleiche Zeilen sind keine
    # Liste, sondern ein Fehler, der aussieht wie Absicht. Der Satz gehoert
    # einmal ueber die Liste; in den Baendern steht dann, welcher Platz das
    # ist und nicht noch einmal, warum er leer ist.
    if _sicht == Sicht.ZUEGE:
        _text(Vector2(RAND, oben + 12.0),
            "A trait changes every raider in a wave. They begin in trench depth II.",
            12, LEISE)
        oben += 26.0
    var verfuegbar := hoehe - oben - FUSS - 24.0
    # **Nicht jede Liste braucht dieselbe Bandhoehe.** 116 Pixel sind das
    # Mass einer Kammerkarte: Sinnbild, Name, Satz, Wirkung, Stufenzeile -
    # fuenf Zeilen. Ein Tagesziel hat drei kurze, und in derselben Hoehe
    # gezeichnet stand darunter jedesmal ein Handbreit Nichts. Vier Ziele
    # verbrauchten so zweihundert Pixel, die Kalender und Rangliste
    # gebrauchen koennen.
    var passt := BAND
    if _sicht == Sicht.TAG:
        passt = BAND_TAG
    elif _sicht == Sicht.ZUEGE:
        passt = BAND_ZUG
    var gebraucht := float(anzahl) * (passt + LUECKE)
    if gebraucht > verfuegbar:
        passt = verfuegbar / float(anzahl) - LUECKE
        gebraucht = verfuegbar

    # Oben ansetzen, nicht mittig. Mittig sah bei fuenf Kammern noch aus wie
    # Absicht, bei drei Linien wie ein Versehen - und auf dem Tagesreiter
    # schob es die Fusszeile unter den Bildrand.
    var y := oben + minf(28.0, maxf(0.0, (verfuegbar - gebraucht) * 0.5))

    for k in anzahl:
        var kasten := Rect2(RAND + _rand_seite, y,
            breite - (RAND + _rand_seite) * 2.0, passt)
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
        # Der Fuss haengt am unteren Rand; was dazwischen frei bleibt,
        # bekommt die Wertung.
        var wertung_unten := _grabenwertung(breite, y + 18.0, stand,
            (hoehe - FUSS - TAGESFUSS_HOCH) - (y + 18.0) - 8.0)
        _tagesstroemung(breite, wertung_unten + 22.0, stand)
        # Der Fuss haengt unten, nicht hinter dem Kalender. Sonst stand die
        # untere Haelfte des Tagesreiters leer und der Loeschknopf mitten im
        # Bild - genau dort, wo der Daumen ohnehin liegt.
        _tagesfuss(breite, hoehe - FUSS - TAGESFUSS_HOCH, stand)
    else:
        _kalender = Rect2()

    # Die Einstellungen liegen auf dem Bootsreiter. Ausserhalb davon gibt es
    # sie nicht - ein Tippziel, das an einer Stelle liegenbleibt, an der
    # nichts gezeichnet ist, ist ein unsichtbarer Knopf.
    if _sicht != Sicht.BOOT:
        _lauter = Rect2()
        _beben = Rect2()
        _bildrate = Rect2()
        _autobau = Rect2()
        _leiser = Rect2()
        _loeschen = Rect2()
        _skinfelder.clear()

    # **Nur auf dem Reiter, um den es geht.** Auf dem Tagesreiter reicht der
    # Inhalt bis an den Fuss hinunter, und die Tafel lag dort ueber dem Knopf,
    # der den Spielstand loescht. Ein Erklaertext, der eine Schaltflaeche
    # verdeckt, ist schlimmer als keiner - und der Satz redet ohnehin von den
    # Kammern.
    if Lehrpfad.gilt(_lehre) and Lehrpfad.reiter(_lehre) == int(_sicht):
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
    var o := _rand_oben
    var links := RAND + _rand_seite
    _text(Vector2(links, 34.0 + o), "COLONY", 21, SCHRIFT)
    _text(Vector2(links, 58.0 + o), "Deepest wave %d  ·  rank %d of %d"
        % [stand.hoechste_welle,
           Geister.platz(stand.hoechste_welle), Geister.zahl() + 1], 14, LEISE)

    # **Der Naehrstoff bekommt eine Flaeche.**
    #
    # Er stand als blanke Zahl an der Kante, in derselben Schrift wie der
    # Rang darunter - und er ist das Einzige auf diesem Bildschirm, das man
    # ausgibt. Jede Zahl auf den Karten wird gegen ihn gelesen; also gehoert
    # er in einen eigenen Rahmen, damit das Auge ihn beim Vergleichen
    # wiederfindet.
    var strom := stand.je_stunde()
    var unten := "" if strom <= 0.0 else "+%s / h" % Zahl.kurz(int(strom))
    var chip := Rect2(breite - RAND - _rand_seite - 150.0, 18.0 + o, 150.0, 52.0)
    _tafelfuellung(chip, Color(NAEHR.r, NAEHR.g, NAEHR.b, 0.07))
    _tafelrand(chip, Color(NAEHR.r, NAEHR.g, NAEHR.b, 0.28), 1.3)
    _text(Vector2(chip.end.x - 12.0, chip.position.y + 28.0),
        Zahl.kurz(stand.naehrstoffe), 22, NAEHR, false, true)
    _text(Vector2(chip.position.x + 12.0, chip.position.y + 45.0),
        "NUTRIENTS", 10, LEISE)
    if not unten.is_empty():
        _text(Vector2(chip.end.x - 12.0, chip.position.y + 45.0), unten, 11,
            Color(NAEHR.r, NAEHR.g, NAEHR.b, 0.75), false, true)

    # **Alle tragenden Linien, nicht nur die erste.** In der Kopfzeile stand
    # eine einzelne, und seit mehrere zugleich tragen koennen, waere das eine
    # Auskunft, die nur manchmal stimmt.
    var traegt_jetzt := stand.tragende()
    if not traegt_jetzt.is_empty():
        var namen := PackedStringArray()
        for i in traegt_jetzt:
            namen.append(Brutlinien.name_von(i))
        _text(Vector2(breite * 0.5, 58.0), " + ".join(namen), 14,
            Brutlinien.farbe(traegt_jetzt[traegt_jetzt.size() - 1]), true)

    _flaeche.draw_line(Vector2(0.0, KOPF + _rand_oben),
        Vector2(breite, KOPF + _rand_oben),
        Color(BAND_KANTE.r, BAND_KANTE.g, BAND_KANTE.b, 0.4), 1.4)


## Die Umschaltzeile: drei Reiter, der aktive hell.
func _umschalterzeile(breite: float) -> void:
    # **Kurz genug fuer sechs Spalten.** Bei 720 Pixeln Breite bleiben je
    # Reiter knapp hundert; "CHAMBERS" passte dort nicht mehr und wurde
    # abgeschnitten. Ein Wort, das man raten muss, ist keine Beschriftung.
    const BESCHRIFTUNG: PackedStringArray = ["BUILD", "LINES", "BEASTS",
        "TRAITS", "DAY", "BOAT"]
    var y := KOPF + _rand_oben + 12.0
    var anzahl := BESCHRIFTUNG.size()
    var breit := (breite - (RAND + _rand_seite) * 2.0 - 5.0 * float(anzahl - 1)) / float(anzahl)
    _reiter.clear()

    for i in anzahl:
        var kasten := Rect2(RAND + _rand_seite + (breit + 5.0) * float(i), y,
            breit, 36.0)
        _reiter.append(kasten)
        # **Der aktive Reiter braucht mehr als eine Nuance.** Er unterschied
        # sich nur in der Deckung von den anderen; auf einem Telefon in der
        # Hand sieht man das nicht. Ein Strich unter dem aktiven sagt es
        # sofort - das ist der Reiter, in dem man steht.
        var aktiv := _sicht == i
        _tafelgrund(kasten, 0.92 if aktiv else 0.35)
        _tafelkante(kasten, Color(0.42, 0.86, 0.92),
            0.45 if aktiv else 0.12, 1.4)
        _text(kasten.get_center() + Vector2(0.0, 5.0), BESCHRIFTUNG[i], 12,
            SCHRIFT if aktiv else LEISE, true)
        if aktiv:
            _flaeche.draw_rect(Rect2(kasten.position.x + 6.0,
                kasten.end.y - 3.0, kasten.size.x - 12.0, 3.0),
                Color(0.52, 0.94, 0.86, 0.9))

        # Ein Punkt am Reiter, wenn dort etwas abzuholen ist. Sonst muesste
        # man jeden Tag nachsehen, ob sich etwas getan hat.
        if i == Sicht.TAG and (Fortschritt.stand.ziele_offen() > 0
                or Fortschritt.stand.kalender_offen()):
            _flaeche.draw_circle(kasten.position + Vector2(kasten.size.x - 10.0, 10.0),
                4.0, NAEHR)


## --- Tafeln ---------------------------------------------------------------
##
## **Eine Karte ist kein Formular.** Jede Tafel auf diesem Schirm bestand aus
## denselben drei Anweisungen: eine Flaeche in einer Farbe, ein Rahmen von
## anderthalb Pixeln rundum, ein Streifen an der linken Kante. Fuenf davon
## untereinander sind fuenf gleiche Rechtecke mit Haarlinie - im Bild ist das
## ein Antragsformular und kein Ort unter Wasser.
##
## Dieselbe Regel wie draussen im Graben (siehe CLAUDE.md, "Ein Ring ist kein
## Kreis"): **wo ein Uebergang hingehoert, wird keine Kante gezeichnet.**
## Drei Helfer setzen sie hier um, und alle Tafeln gehen durch sie.

## Wie weit die Ecken einer Tafel gerundet sind.
##
## **Es gibt in diesem Spiel keine rechten Winkel** - kein Fels, kein Tier,
## kein Riff hat eine gerade Kante. Die Bedienoberflaeche hatte nichts als
## rechte Winkel, und deshalb sah sie aus wie ein Formular, das jemand ueber
## den Graben gelegt hat. Zehn Pixel sind genug, dass eine Karte nicht mehr
## gestanzt wirkt, und wenig genug, dass eine Zeile nicht ins Runde laeuft.
const ECKE := 10.0

## Wieviele Punkte eine Ecke bekommt. Drei reichen: bei zehn Pixeln Radius
## liegt zwischen zwei Punkten weniger als ein Pixel Abweichung.
const ECKPUNKTE := 4


## Der Umriss einer Tafel mit gerundeten Ecken.
func _tafelform(kasten: Rect2) -> PackedVector2Array:
    var r := minf(ECKE, minf(kasten.size.x, kasten.size.y) * 0.5)
    var punkte := PackedVector2Array()
    var mitten := PackedVector2Array([
        kasten.position + Vector2(r, r),
        Vector2(kasten.end.x - r, kasten.position.y + r),
        kasten.end - Vector2(r, r),
        Vector2(kasten.position.x + r, kasten.end.y - r)])
    for i in 4:
        var von := PI + PI * 0.5 * float(i)
        for j in ECKPUNKTE:
            var w := von + PI * 0.5 * float(j) / float(ECKPUNKTE - 1)
            punkte.append(mitten[i] + Vector2.RIGHT.rotated(w) * r)
    return punkte


## Der Grund einer Tafel: ein Verlauf von oben nach unten.
##
## Licht faellt in dieser Welt von oben - der Kegel des Bootes, das Glimmen
## der Kolonie. Eine Flaeche, die oben so dunkel ist wie unten, ist ein
## Aufkleber; ein Verlauf legt sie in denselben Raum wie alles andere.
func _tafelgrund(kasten: Rect2, deckung: float) -> void:
    var form := _tafelform(kasten)
    var toene := PackedColorArray()
    for punkt in form:
        var t := clampf((punkt.y - kasten.position.y)
            / maxf(1.0, kasten.size.y), 0.0, 1.0)
        var st := lerpf(1.90, 0.42, t * t)
        toene.append(Color(BAND_FARBE.r * st, BAND_FARBE.g * st * 0.94,
            BAND_FARBE.b * st * 0.90, deckung))
    _flaeche.draw_polygon(form, toene)


## Eine gerundete Flaeche in einer Farbe. Fuer Knoepfe und Felder, die ihre
## Deckung schon in der Farbe tragen.
func _tafelfuellung(kasten: Rect2, farbe: Color) -> void:
    var form := _tafelform(kasten)
    _flaeche.draw_polygon(form, _einfarbig(form.size(), farbe))


## Ein Feld aus n gleichen Farben. `draw_polygon` verlangt entweder genau
## eine Farbe oder genau so viele wie Punkte; eine einzelne uebergeben zu
## koennen waere bequem, geht aber nicht mit gerundeten Ecken.
func _einfarbig(n: int, farbe: Color) -> PackedColorArray:
    var feld := PackedColorArray()
    feld.resize(n)
    feld.fill(farbe)
    return feld


## Der Rand einer gerundeten Flaeche, in einer Farbe.
func _tafelrand(kasten: Rect2, farbe: Color, dick: float) -> void:
    var form := _tafelform(kasten)
    form.append(form[0])
    _flaeche.draw_polyline(form, farbe, dick, true)


## Die Kante einer Tafel: oben hell, unten aus.
##
## `draw_rect(..., false, w)` zieht einen Rahmen mit ueberall derselben
## Deckung - vier Striche, die zusammen ein Kaestchen ergeben. Ein Koerper
## unter Licht hat eine helle Oberkante und keine helle Unterkante; der Zug
## laeuft deshalb von unten links ueber oben nach unten rechts und verliert
## dabei seine Deckung.
func _tafelkante(kasten: Rect2, farbe: Color, deckung: float,
        dick: float) -> void:
    var form := _tafelform(kasten)
    form.append(form[0])
    var toene := PackedColorArray()
    for punkt in form:
        var t := clampf((punkt.y - kasten.position.y)
            / maxf(1.0, kasten.size.y), 0.0, 1.0)
        toene.append(Color(farbe.r, farbe.g, farbe.b,
            deckung * lerpf(1.0, 0.16, t * t)))
    _flaeche.draw_polyline_colors(form, toene, dick, true)


## Der Streifen an der linken Kante - mit Schein statt als harter Balken.
##
## Er sagt, worum es in der Tafel geht, und er ist das Einzige darauf, das
## eine kraeftige Farbe traegt. Als drei Pixel breiter Balken sass er wie ein
## Aufkleber auf der Karte; der Schein daneben legt ihn hinein.
func _tafelstreifen(kasten: Rect2, farbe: Color, deckung: float) -> void:
    var kern := Color(farbe.r, farbe.g, farbe.b, deckung)
    var aus := Color(farbe.r, farbe.g, farbe.b, 0.0)
    var breit := minf(34.0, kasten.size.x * 0.4)
    var r := minf(ECKE, minf(kasten.size.x, kasten.size.y) * 0.5)
    _flaeche.draw_polygon(PackedVector2Array([
        kasten.position + Vector2(0.0, r),
        Vector2(kasten.position.x + breit, kasten.position.y),
        Vector2(kasten.position.x + breit, kasten.end.y),
        Vector2(kasten.position.x, kasten.end.y - r)]),
        PackedColorArray([
            Color(kern.r, kern.g, kern.b, deckung * 0.34), aus, aus,
            Color(kern.r, kern.g, kern.b, deckung * 0.34)]))
    # Der Kern des Streifens laeuft an beiden Enden aus, damit er nicht in
    # die gerundete Ecke stoesst und dort abgeschnitten aussieht.
    _flaeche.draw_polyline_colors(PackedVector2Array([
        kasten.position + Vector2(1.6, r * 0.4),
        kasten.position + Vector2(1.6, r * 1.2),
        Vector2(kasten.position.x + 1.6, kasten.end.y - r * 1.2),
        Vector2(kasten.position.x + 1.6, kasten.end.y - r * 0.4)]),
        PackedColorArray([aus, kern, kern, aus]), 2.6, true)


## Ein Tagesziel mit Fortschrittsbalken.
func _tagesziel(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var erfuellt := stand.ziel_erfuellt(index)
    var geholt := stand.ziel_geholt[index] == 1
    var farbe := NAEHR if erfuellt and not geholt else LEISE

    _tafelgrund(kasten, 0.85)
    _tafelkante(kasten, farbe, 0.32, 1.4)
    _tafelstreifen(kasten, farbe, 0.85)

    # Drei Zeilen dicht uebereinander statt drei ueber ein halbes Blatt
    # verteilt: Name, Balken, Zaehler. Der Lohn steht rechts daneben, weil er
    # zum Ziel gehoert und nicht darunter.
    var links := kasten.position.x + 20.0
    var soll := Tagesziel.menge(index)
    var ist: int = stand.ziel_fortschritt[index]
    var zahl := "%d / %d" % [ist, soll]
    var zahl_breit := _schrift.get_string_size(zahl,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
    var rechts := kasten.end.x - 14.0

    _text(Vector2(links, kasten.position.y + 26.0), Tagesziel.name_von(index), 16,
        LEISE if geholt else SCHRIFT)

    var balken := Rect2(links, kasten.end.y - 22.0,
        kasten.size.x - 150.0 - zahl_breit, 5.0)
    _tafelfuellung(balken, Color(0.0, 0.0, 0.0, 0.45))
    _tafelfuellung(Rect2(balken.position,
        Vector2(balken.size.x * clampf(float(ist) / float(soll), 0.0, 1.0),
        balken.size.y)), farbe)
    _text(Vector2(balken.end.x + 12.0, kasten.end.y - 15.0), zahl, 12, LEISE)

    if geholt:
        _text(Vector2(rechts, kasten.get_center().y + 5.0), "collected", 14, LEISE,
            false, true)
    elif erfuellt:
        _text(Vector2(rechts, kasten.get_center().y - 3.0), "collect", 12, NAEHR,
            false, true)
        _text(Vector2(rechts, kasten.get_center().y + 17.0),
            "+%d" % Tagesziel.lohn(index, stand.hoechste_welle), 16, NAEHR,
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
## **Der Stein muss heller sein als die Hohlraeume.**
##
## Hier stand unten `(0.014, 0.026, 0.036)`, und ein ausgehoehlter Raum wird
## mit `(0.010, 0.020, 0.028)` gezeichnet - der Unterschied lag im
## Tausendstel. In der unteren Bildhaelfte, wo die Kammern sitzen, gab es
## also gar keinen Fels, gegen den sie sich haetten abheben koennen: uebrig
## blieben vier freischwebende Umrisse. Ein Schnitt durch Gestein lebt davon,
## dass das Volle heller ist als das Leere; ist es das nicht, ist es kein
## Schnitt, sondern ein Diagramm.
const FELS_OBEN := Color(0.132, 0.172, 0.194)
const FELS_UNTEN := Color(0.074, 0.100, 0.118)

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
    # Null heisst: nichts mehr verschlossen. Dann ist der Deckel des Spiels
    # das Ziel, sonst stuende hier "of 0" und der Balken teilte durch nichts.
    var ziel_stufe := stand.naechste_tiefe()
    if ziel_stufe <= 0:
        ziel_stufe = Kammern.HOECHSTSTUFE
    var anteil := clampf(float(tiefste - von) / maxf(1.0, float(ziel_stufe - von)),
        0.0, 1.0)
    var letzte_kammer := 0.10 + 0.21 * 3.0
    var gegraben := letzte_kammer + 0.06 + (0.94 - letzte_kammer - 0.06) * anteil
    var spitze_y := kopf + spanne * gegraben
    var schachtfarbe: Color = FARBEN[Kammern.Kammer.TIEFENSCHACHT]

    var halb := 15.0

    # **Ein gegrabener Schacht hat keine geraden Waende.**
    #
    # Er war ein Trapez aus vier Ecken, und seine beiden Waende waren zwei
    # `draw_line` - im Bild eine kerzengerade magentafarbene Linie durch den
    # halben Schirm. Das ist genau das, was diese Welt sonst nirgends hat
    # (CLAUDE.md: "Es gibt in diesem Spiel keine rechten Winkel"), und weil
    # der Schnitt durch den Graben das Kernbild der Kolonie ist, war die
    # geradeste Linie im Spiel ausgerechnet sein Mittelpunkt.
    #
    # Zwei Schwebungen ueber die Tiefe, je Wand mit eigener Phase. Aus der
    # Tiefe gerechnet und nicht gewuerfelt: der Schacht sieht in jedem Bild
    # gleich aus - er wird gegraben, nicht neu gebohrt -, aber nirgends wie
    # mit dem Lineal.
    var stufen := 20
    var wand_links := PackedVector2Array()
    var wand_rechts := PackedVector2Array()
    for i in stufen + 1:
        var t := float(i) / float(stufen)
        var y := lerpf(kopf, spitze_y, t)
        var w := halb * lerpf(1.0, 0.62, t)
        wand_links.append(Vector2(mitte - w * (1.0
            + 0.17 * sin(t * 11.0) + 0.09 * sin(t * 27.0 + 1.7)), y))
        wand_rechts.append(Vector2(mitte + w * (1.0
            + 0.17 * sin(t * 9.0 + 2.3) + 0.09 * sin(t * 31.0)), y))
    var rueck := wand_rechts.duplicate()
    rueck.reverse()
    var offen := wand_links + rueck
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
    # **Schwach, und das Licht gehoert an die Waende.**
    #
    # Der Schein stand auf 0.30 - der Schacht kam damit auf RGB (80, 65, 92)
    # gegen einen Fels von (30, 40, 45). Er war also **heller** als das
    # Gestein, und ein Hohlraum, der heller ist als das Volle, ist kein
    # Hohlraum, sondern ein Balken. Genau so sah er auch aus. Ein Loch
    # erkennt man an seinen beleuchteten Kanten und seiner dunklen Mitte.
    var schein := PackedColorArray()
    for v in offen:
        var t := clampf((v.y - kopf) / maxf(1.0, spitze_y - kopf), 0.0, 1.0)
        schein.append(Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b,
            0.11 * (1.0 - t) + 0.02))
    _flaeche.draw_polygon(offen, schein)
    for wand: PackedVector2Array in [wand_links, wand_rechts]:
        _flaeche.draw_polyline(wand,
            Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.16),
            5.0, true)
        _flaeche.draw_polyline(wand,
            Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.85),
            2.0, true)

    # Was noch bevorsteht - nur angedeutet, in Strichen.
    if gegraben < 0.995:
        var y := spitze_y
        while y < fuss:
            var bis := minf(y + 9.0, fuss)
            var u := (y - spitze_y) / maxf(1.0, fuss - spitze_y)
            var b := lerpf(halb * 0.62, halb * 0.24, u)
            # Auch das Bevorstehende ist unruhig - sonst haengt unter dem
            # gegrabenen Schacht ein Lineal.
            var vl := b * (1.0 + 0.20 * sin(u * 13.0 + 0.6))
            var vr := b * (1.0 + 0.20 * sin(u * 15.0 + 2.9))
            _flaeche.draw_line(Vector2(mitte - vl, y), Vector2(mitte - vl, bis),
                Color(schachtfarbe.r, schachtfarbe.g, schachtfarbe.b, 0.13), 1.2)
            _flaeche.draw_line(Vector2(mitte + vr, y), Vector2(mitte + vr, bis),
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
        # **Gemessen am Deckel, nicht an der Hoechststufe.** Gegen 80
        # gerechnet war Stufe 6 ein Wert von 0.075: die Kammer blieb ueber
        # das halbe Spiel hinweg auf ihrer Mindestgroesse und ihr Leuchten
        # bei einem Achtel. Derselbe Fehler wie bei den Balken - die
        # Hoechststufe ist kein Ziel, das jemand vor sich hat.
        var voll := clampf(float(stufe)
            / float(maxi(1, Kammern.deckel(k, stand.schacht()))), 0.0, 1.0)
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
        var dick := 7.0
        _flaeche.draw_line(gang_a, wo, Color(0.008, 0.018, 0.026), dick)
        # Zwei Kanten statt einer Mittellinie: ein Gang ist ein Hohlraum, und
        # ein Hohlraum leuchtet an den Waenden. Eine Linie in der Mitte waere
        # ein Kabel.
        for rand: float in SEITEN:
            _flaeche.draw_line(gang_a + Vector2(0.0, rand * dick * 0.42),
                wo + Vector2(0.0, rand * dick * 0.42),
                Color(farbe.r, farbe.g, farbe.b, 0.42 if erreicht else 0.12), 1.2)

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
        # Das Sinnbild **in** der Kammer, nicht ein Punkt darin. Dasselbe
        # Zeichen wie oben in der Liste: wer die Karte gelesen hat, findet
        # die Kammer im Schnitt wieder, ohne die Beschriftung zu brauchen.
        _sinnbild(wo - Vector2(weite * 0.18, 0.0),
            minf(kammerhoch * 0.72, 17.0), k, farbe, stufe)
        _text(wo + Vector2(weite * 0.16, 6.0), "%d" % stufe,
            int(clampf(kammerhoch * 0.9, 13.0, 22.0)),
            Color(farbe.r, farbe.g, farbe.b, 0.92), true)

        _text(wo + Vector2(0.0, kammerhoch + 15.0),
            Kammern.name_von(k).split(" ")[0], 11,
            Color(farbe.r, farbe.g, farbe.b, 0.65), true)


## Der Stein, in dem die Kolonie sitzt: ein Verlauf nach unten und ein paar
## Schichten quer darueber.
##
## Die Schichten sind der billigste Weg zu Gestein - waagerecht, ungleich weit
## auseinander und nur wenige. Vier reichen; bei zwanzig waere es ein
## Notenblatt.
func _fels(breite: float, kopf: float, fuss: float) -> void:
    # **Die Oberkante ist gezackt, nicht gerade.** Sie war eine waagerechte
    # Linie ueber die volle Breite, und genau daran sah der halbe Bildschirm
    # aus wie ein aufgesetztes Feld: Fels hat keine Wasserwaage. Der Verlauf
    # daran zu heften genuegt nicht - man sieht die Kante trotzdem, weil
    # links und rechts derselbe Ton auf derselben Hoehe steht.
    #
    # Gerechnet, nicht gewuerfelt: drei Sinus mit teilerfremden Perioden. Ein
    # Wurf sähe bei jedem Bild anders aus, und ein Fels, der flackert, ist
    # kein Fels.
    const ZACKEN := 26
    var tief := minf(22.0, (fuss - kopf) * 0.06)
    var ecken := PackedVector2Array()
    var farben := PackedColorArray()
    for i in ZACKEN + 1:
        var t := float(i) / float(ZACKEN)
        var x := t * breite
        var wellig := 0.55 * sin(t * 7.1) + 0.30 * sin(t * 17.3 + 1.7) \
            + 0.15 * sin(t * 31.7 + 0.4)
        ecken.append(Vector2(x, kopf + tief * (0.5 + 0.5 * wellig)))
        farben.append(FELS_OBEN)
    ecken.append(Vector2(breite, fuss))
    farben.append(FELS_UNTEN)
    ecken.append(Vector2(0.0, fuss))
    farben.append(FELS_UNTEN)
    _flaeche.draw_polygon(ecken, farben)

    # Ein heller Saum auf der Kante - Streulicht von oben faellt auf den
    # Grat und nicht in die Kerbe.
    var saum := PackedVector2Array()
    for i in ZACKEN + 1:
        saum.append(ecken[i])
    _flaeche.draw_polyline(saum, Color(0.46, 0.66, 0.70, 0.16), 1.4, true)

    # **Eine Schichtfuge ist nicht waagerecht.**
    #
    # Fuenf `draw_line` ueber die volle Breite - im Bild fuenf Lineale quer
    # durch den Fels, und zwar genau in der Flaeche, deren Oberkante
    # aufwendig gezackt ist. Der Widerspruch stand nebeneinander: oben eine
    # Kante wie Gestein, darunter ein Notenblatt.
    #
    # Sediment legt sich auf die Flaeche, die schon da ist. Die Fugen folgen
    # deshalb **derselben** Welligkeit wie die Oberkante, nach unten
    # gedaempft und je Schicht ein Stueck verschoben - so, wie sich eine
    # Ablagerung mit der Tiefe glaettet.
    var spanne := fuss - kopf
    for i in 5:
        var t := 0.14 + 0.19 * float(i) + 0.03 * sin(float(i) * 2.9)
        var y := kopf + spanne * t
        # Tiefer heisst ruhiger: die unterste Fuge ist fast gerade, die
        # oberste folgt der Kante darueber noch deutlich.
        var daempfung := lerpf(1.0, 0.25, t)
        var hoehe := tief * 0.9 * daempfung
        var versatz := float(i) * 0.7
        var hell := PackedVector2Array()
        var dunkel := PackedVector2Array()
        for j in ZACKEN + 1:
            var u := float(j) / float(ZACKEN)
            var wellig := 0.55 * sin(u * 7.1 + versatz) \
                + 0.30 * sin(u * 17.3 + 1.7 + versatz) \
                + 0.15 * sin(u * 31.7 + 0.4)
            var yy := y + hoehe * wellig
            hell.append(Vector2(u * breite, yy))
            dunkel.append(Vector2(u * breite, yy + 1.6))
        _flaeche.draw_polyline(hell,
            Color(0.44, 0.58, 0.64, 0.075 + 0.03 * sin(float(i))), 1.0, true)
        # Eine dunkle Linie dicht darunter: eine Schichtfuge hat eine Kante
        # und einen Schatten, sonst ist sie ein Strich auf Papier.
        _flaeche.draw_polyline(dunkel, Color(0.0, 0.0, 0.0, 0.16), 1.6, true)


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
    # Ein Rand innen, sonst laeuft die Beschriftung der aeussersten Spalte
    # ueber die Bildkante - "Duskveil" stand rechts angeschnitten.
    var streifen := breite - RAND * 2.0 - 24.0
    var breit := streifen / float(Brutlinien.zahl())
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

    # **Die Ueberschrift wandert mit.** Sie stand fest unter der Liste,
    # waehrend das Bild in der freien Flaeche mittig sitzt - auf einem
    # 20:9-Schirm klafften dazwischen hundertneunzig Pixel, und eine
    # Ueberschrift ohne etwas darunter liest sich als fehlender Inhalt.
    # Sie gehoert an das Bild und nicht an die Kante.
    # **Wieviele Plaetze belegt sind, steht hier und nirgends sonst.**
    # Ohne die Zahl tippt man eine siebte Linie an, eine andere faellt
    # heraus, und man sucht, welche - eine Regel, die man nur an ihrer
    # Wirkung merkt, ist keine Regel.
    var plaetze := stand.linien_plaetze()
    _text(Vector2(RAND, maxf(oben + 12.0, mitte_y - kegelhoch * 0.5 - 16.0)),
        "CARRYING %d OF %d - THE BROOD CHAMBER OPENS MORE"
        % [stand.tragende().size(), plaetze], 13, LEISE)

    for index in Brutlinien.zahl():
        var mitte_x := RAND + 12.0 + breit * (float(index) + 0.5)
        var traegt := stand.linie_traegt(index)
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

    _tafelgrund(kasten, 0.88 if kennt else 0.52)
    _tafelkante(kasten, farbe, 0.28, 1.4)
    _tafelstreifen(kasten, farbe, 0.85 if kennt else 0.30)

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _artsinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 22.0, index, farbe, kennt)

    # **Die Zeilen haengen an der Bandhoehe, nicht an festen Abstaenden.**
    #
    # Sie standen bei 32, 56 und `end.y - 16` - richtig fuer ein Band von
    # 116 Pixeln. Mit zwoelf Arten teilt sich die Liste den Platz auf 75, und
    # die Werte lagen dann quer ueber der Regel. Der Fehler faellt in keinem
    # Test auf und in keinem Bild, ausser man sieht sich genau die Liste an,
    # die eine Art zu lang geworden ist.
    var links := kasten.position.x + 84.0
    var hoch := kasten.size.y
    var eng := hoch < 92.0
    _text(Vector2(links, kasten.position.y + hoch * (0.36 if eng else 0.28)),
        Arten.name_von(index) if kennt else "Not yet encountered", 17,
        SCHRIFT if kennt else LEISE)
    _text(Vector2(links, kasten.position.y + hoch * (0.60 if eng else 0.48)),
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
    _text(Vector2(links, kasten.position.y + hoch * (0.86 if eng else 0.72)),
        zeile, 11, Color(0.40, 0.54, 0.60))

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

    _tafelgrund(kasten, 0.88 if kennt else 0.52)
    _tafelkante(kasten, farbe, 0.28, 1.4)
    _tafelstreifen(kasten, farbe, 0.85 if kennt else 0.30)

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _mutationssinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 22.0, index,
        farbe, kennt)

    var links := kasten.position.x + 84.0
    _text(Vector2(links, mitte_y - 6.0),
        Mutationen.name_von(index) if kennt else "Trait %d" % (index + 1), 17,
        SCHRIFT if kennt else LEISE)
    _text(Vector2(links, mitte_y + 18.0),
        Mutationen.hinweis(index) if kennt else "Not yet encountered",
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
        Arten.Art.LAICHWOLKE:
            # Viele winzige Koerper in einer Wolke - das ist die ganze
            # Aussage der Art.
            for i in 9:
                var w := TAU * float(i) / 9.0 + _zeit * 0.3
                var weit := r * (0.30 + 0.52 * absf(sin(float(i) * 2.1)))
                _flaeche.draw_circle(p + Vector2(cos(w), sin(w) * 0.8) * weit,
                    r * 0.13, Color(farbe.r, farbe.g, farbe.b, 0.85))
        Arten.Art.KREISER:
            # Ein Ring um eine Mitte, an der er nie ankommt.
            _flaeche.draw_arc(p, r * 0.82, 0.0, TAU, 26,
                Color(farbe.r, farbe.g, farbe.b, 0.55), 1.6)
            _flaeche.draw_circle(p, r * 0.16,
                Color(farbe.r, farbe.g, farbe.b, 0.35))
            var lauf := _zeit * 1.2
            _flaeche.draw_circle(p + Vector2(cos(lauf), sin(lauf)) * r * 0.82,
                r * 0.22, farbe)
        Arten.Art.LICHTSCHEU:
            # Ein Koerper, der vor einem Strahl zurueckweicht.
            _flaeche.draw_line(p + Vector2(-r * 0.95, -r * 0.7),
                p + Vector2(-r * 0.2, -r * 0.1),
                Color(1.0, 1.0, 0.96, 0.8), 1.8)
            var bogen := PackedVector2Array()
            for i in 9:
                var w := lerpf(-PI * 0.55, PI * 0.55, float(i) / 8.0)
                bogen.append(p + Vector2(r * 0.35, 0.0)
                    + Vector2(cos(w), sin(w)) * r * 0.6)
            _flaeche.draw_polyline(bogen, farbe, 2.2)
            for i in 2:
                _flaeche.draw_line(p + Vector2(r * 0.62, 0.0),
                    p + Vector2(r * 0.95, (float(i) - 0.5) * r * 0.8),
                    Color(farbe.r, farbe.g, farbe.b, 0.5), 1.4)
        Arten.Art.RINGMAUL:
            # Wie der Kreiser, aber weiter draussen und mit Zaehnen: ein
            # Leitwesen muss man am Umriss erkennen.
            _flaeche.draw_arc(p, r * 0.9, 0.0, TAU, 30,
                Color(farbe.r, farbe.g, farbe.b, 0.45), 1.4)
            for i in 10:
                var w := TAU * float(i) / 10.0
                var richtung := Vector2(cos(w), sin(w))
                _flaeche.draw_line(p + richtung * r * 0.9,
                    p + richtung * r * 0.66, farbe, 1.8)
            _flaeche.draw_circle(p, r * 0.26,
                Color(farbe.r, farbe.g, farbe.b, 0.75))
        Arten.Art.BRUTSTOCK:
            # Ein Stock, an dem Junge haengen und abfallen.
            _flaeche.draw_line(p + Vector2(0.0, r * 0.9),
                p + Vector2(0.0, -r * 0.5), farbe, 2.6)
            for i in 3:
                var t := float(i) / 2.0
                var y := lerpf(r * 0.6, -r * 0.35, t)
                var seite := 1.0 if i % 2 == 0 else -1.0
                _flaeche.draw_line(p + Vector2(0.0, y),
                    p + Vector2(seite * r * 0.6, y - r * 0.18),
                    Color(farbe.r, farbe.g, farbe.b, 0.6), 1.6)
                _flaeche.draw_circle(p + Vector2(seite * r * 0.68,
                    y - r * 0.2), r * 0.16,
                    Color(farbe.r, farbe.g, farbe.b, 0.9))
            _flaeche.draw_circle(p + Vector2(0.0, -r * 0.62), r * 0.24, farbe)
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
        Arten.Art.KALKROCHEN:
            # Eine flache Raute quer zur Bahn, mit Platten darauf - derselbe
            # Umriss wie im Schlund, nur klein.
            _flaeche.draw_polyline(PackedVector2Array([
                p + Vector2(0.0, -r * 0.5), p + Vector2(r * 0.95, 0.0),
                p + Vector2(0.0, r * 0.5), p + Vector2(-r * 0.95, 0.0),
                p + Vector2(0.0, -r * 0.5)]), farbe, 2.0, true)
            for i in 3:
                var y := lerpf(-r * 0.22, r * 0.22, float(i) / 2.0)
                var halb := r * (0.72 - 0.5 * absf(y) / (r * 0.5))
                _flaeche.draw_line(p + Vector2(-halb, y), p + Vector2(halb, y),
                    Color(farbe.r, farbe.g, farbe.b, 0.6), 1.4)
        Arten.Art.SCHWARMHERZ:
            # Ein Kern mit einem Ring aus Trabanten - das Zeichen sagt
            # dasselbe wie das Tier: das hier steht nicht still.
            _flaeche.draw_circle(p, r * 0.3, farbe)
            for i in 7:
                var w := TAU * float(i) / 7.0 + _zeit * 0.7
                _flaeche.draw_circle(p + Vector2(cos(w), sin(w) * 0.75) * r * 0.82,
                    r * 0.13, Color(farbe.r, farbe.g, farbe.b, 0.75))
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
## **Wieviele Zeilen, richtet sich nach dem Platz.**
##
## Hier standen fest fuenf, und darunter blieben auf dem Tagesreiter
## hundertsiebzig Pixel leer - eine Luecke mitten im Bildschirm, die aussieht,
## als fehle dort etwas. Es fehlte auch etwas: sechs weitere Kolonien, die
## ohnehin in der Liste stehen. Der Platz ist da, die Daten sind da; es gab
## keinen Grund, beides nicht zusammenzubringen.
func _grabenwertung(breite: float, y: float, stand: KolonieStand,
        raum := 0.0) -> float:
    var zeigen := 5
    if raum > 0.0:
        zeigen = clampi(int((raum - 24.0) / 34.0), 3, Geister.zahl() + 1)
    var liste := Geister.rangliste(stand.hoechste_welle)
    # **Wenn alle hineinpassen, fuellen sie den Platz aus.** Seit die
    # Einstellungen auf dem Bootsreiter liegen, ist unter der Rangliste
    # Platz frei geworden - elf Zeilen zu 34 Punkten liessen darunter eine
    # halbe Bildschirmhoehe Nichts stehen, und der Reiter sah aus, als fehle
    # etwas. Gedeckelt bleibt es trotzdem: eine Zeile von achtzig Punkten
    # waere kein Eintrag mehr, sondern eine Karte.
    var zeilenhoch := 34.0
    var passt := mini(zeigen, liste.size())
    if raum > 0.0 and passt > 0:
        zeilenhoch = clampf((raum - 30.0) / float(passt), 34.0, 46.0)
    var eigen := Geister.platz(stand.hoechste_welle) - 1
    var erste := clampi(eigen - 2, 0, maxi(0, liste.size() - zeigen))

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
    for i in range(erste, mini(erste + zeigen, liste.size())):
        var eintrag := liste[i]
        var selbst: bool = eintrag[&"selbst"]
        var kasten := Rect2(RAND, zeile_y, breite - RAND * 2.0,
            zeilenhoch - 2.0)
        if selbst:
            _tafelgrund(kasten, 0.9)
            _tafelstreifen(kasten, NAEHR, 0.95)

        var farbe := NAEHR if selbst else LEISE
        var text_y := zeile_y + zeilenhoch * 0.5 + 5.0
        _text(Vector2(RAND + 14.0, text_y), "%d." % (i + 1), 13, farbe)
        _text(Vector2(RAND + 46.0, text_y), String(eintrag[&"name"]), 15,
            SCHRIFT if selbst else LEISE)
        _text(Vector2(breite - RAND - 10.0, text_y),
            "Wave %d" % int(eintrag[&"tiefe"]), 14, farbe, false, true)
        zeile_y += zeilenhoch

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

        _tafelgrund(kasten, 0.9 if geholt or dran else 0.55)
        _tafelkante(kasten, farbe, 0.7 if dran else 0.3,
            1.8 if dran else 1.2)

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


## Wieviele Bonuswellen der Tag noch hergibt.
##
## **Sie stand nur im Kopf der Fahrt, und dort ist es zu spaet.** Die Frage
## lautet "lohnt sich heute noch eine Fahrt", und die stellt man hier, vor
## dem Tauchen - nicht in der dritten Welle. Drei Marken sagen es ohne
## Rechnung: was gefuellt ist, liegt noch bereit.
func _tagesstroemung(breite: float, y: float, stand: KolonieStand) -> void:
    var offen: int = stand.stroemung_offen
    _text(Vector2(RAND, y + 14.0), "DAY CURRENT", 13, LEISE)
    _text(Vector2(RAND + 130.0, y + 14.0),
        "double yield on the next %d dive%s" % [offen, "" if offen == 1 else "s"]
        if offen > 0 else "spent for today - it returns tomorrow", 12,
        NAEHR if offen > 0 else Color(0.40, 0.52, 0.58))
    for i in Tagesstroemung.JE_TAG:
        var p := Vector2(breite - RAND - 14.0 - float(
            Tagesstroemung.JE_TAG - 1 - i) * 26.0, y + 9.0)
        if i < offen:
            _flaeche.draw_circle(p, 9.0, Color(NAEHR.r, NAEHR.g, NAEHR.b, 0.16))
            _flaeche.draw_circle(p, 5.0, NAEHR)
        else:
            _flaeche.draw_arc(p, 5.0, 0.0, TAU, 14,
                Color(0.36, 0.48, 0.54, 0.7), 1.2, true)


## Unter den Zielen: Anwesenheit und Bestmarken. Mehr nicht - die
## Einstellungen sind auf den Bootsreiter gezogen, weil sie mit dem Tag
## nichts zu tun haben und ihn nach unten aus dem Bild schoben.
func _tagesfuss(breite: float, y: float, stand: KolonieStand) -> void:
    var tage := "1 day" if stand.strecke == 1 else "%d days" % stand.strecke
    _text(Vector2(RAND, y + 22.0), "%s in the trench in a row" % tage,
        15, Color(0.72, 0.88, 0.92))

    # **Die Bestmarken gehoeren hierher und nicht nur auf das Schlussbild.**
    # Dort sieht man sie einmal und dann nie wieder; hier stehen sie, wenn man
    # ueberlegt, ob man noch eine Sitzung spielt. Eine Bestleistung, die man
    # nur im Augenblick ihres Entstehens sieht, ist keine Marke, sondern eine
    # Meldung.
    if stand.bestpunkte > 0:
        _text(Vector2(breite - RAND, y + 22.0),
            "best %s  ·  chain %d" % [Zahl.kurz(stand.bestpunkte),
                stand.beste_kette], 13, NAEHR, false, true)


## Der Bootsreiter: wie es aussieht, und wie es sich bedienen laesst.
##
## **Zwei Dinge, die zusammengehoeren, weil beide das Boot betreffen** - der
## Anstrich und die Regler. Getrennt haette jeder von beiden einen halbleeren
## Reiter, und der Anstrich allein waere ein Schaufenster.
func _bootreiter(breite: float, hoehe: float, stand: KolonieStand) -> void:
    var oben := KOPF + _rand_oben + 58.0
    _text(Vector2(RAND, oben + 12.0), "HULL PAINT", 13, LEISE)
    var gesperrt := Skins.naechster_gesperrt(stand.hoechste_welle)
    if gesperrt >= 0:
        _text(Vector2(breite - RAND, oben + 12.0),
            "next at wave %d" % Skins.ab_welle(gesperrt), 12,
            Color(0.40, 0.52, 0.58), false, true)

    # **Zwei Spalten, nicht sechs Zeilen.** Ein Anstrich ist eine Farbe; man
    # waehlt ihn mit dem Auge und nicht durch Lesen. Nebeneinander sieht man
    # den Unterschied, untereinander liest man Namen.
    var y := oben + 26.0
    _skinfelder.clear()
    var spalten := 2
    var breit := (breite - RAND * 2.0 - 10.0) / float(spalten)
    for i in Skins.zahl():
        var kasten := Rect2(RAND + (breit + 10.0) * float(i % spalten),
            y + (SKINHOCH + 10.0) * float(i / spalten), breit, SKINHOCH)
        _skinfelder.append(kasten)
        _skinfeld(kasten, i, stand)
    y += float((Skins.zahl() + spalten - 1) / spalten) * (SKINHOCH + 10.0) + 14.0

    _flaeche.draw_line(Vector2(RAND, y), Vector2(breite - RAND, y),
        Color(0.24, 0.44, 0.50, 0.30), 1.0)
    _text(Vector2(RAND, y + 20.0), "SETTINGS", 13, LEISE)
    y += 34.0

    # **Ganze Zeilen mit einer Trennlinie dazwischen.** Vorher standen die
    # Regler als Kaesten am rechten Rand einer Liste, die eigentlich von
    # Tageszielen handelte; welche Beschriftung zu welchem Knopf gehoerte,
    # musste man sich zusammenreimen. Eine Zeile, die ueber die ganze Breite
    # geht, beantwortet das von selbst.
    y = _reglerzeile(breite, y, "Sound", "%d%%" % int(round(Klang.laut * 100.0)))
    _leiser = Rect2(breite - RAND - 104.0, y - ZEILE + 7.0, 48.0, 38.0)
    _lauter = Rect2(breite - RAND - 52.0, y - ZEILE + 7.0, 48.0, 38.0)
    for paar in [[_leiser, "-"], [_lauter, "+"]]:
        _knopffeld(paar[0], paar[1], SCHRIFT, Color(0.42, 0.86, 0.92))

    y = _reglerzeile(breite, y, "Rumble", "")
    _beben = Rect2(breite - RAND - 104.0, y - ZEILE + 7.0, 100.0, 38.0)
    _schalterfeld(_beben, Tastsinn.an)

    y = _reglerzeile(breite, y, "Frame rate", "")
    _bildrate = Rect2(breite - RAND - 104.0, y - ZEILE + 7.0, 100.0, 38.0)
    var fr: int = stand.bildrate
    _knopffeld(_bildrate, "SCREEN" if fr == 0 else "%d FPS" % fr, SCHRIFT,
        Color(0.42, 0.86, 0.92))

    # **Der Halt beim Ausbau, abschaltbar.** Er ist standardmaessig an, weil
    # ein Spieler, der ihn nicht kennt, sonst mit dem gestrigen Boot
    # weiterfaehrt - aber er greift in die Fahrt ein, und was in die Fahrt
    # eingreift, muss man ausschalten koennen.
    y = _reglerzeile(breite, y, "Stop to build", "")
    _autobau = Rect2(breite - RAND - 104.0, y - ZEILE + 7.0, 100.0, 38.0)
    _schalterfeld(_autobau, stand.auto_ausbau)

    # **Was man anmalt, soll man sehen.** Unter den Einstellungen blieb sonst
    # eine halbe Bildschirmhoehe leer, und die Auswahl bestand aus sechs
    # Daumennagelbooten - man waehlte eine Farbe, ohne sie je gross zu sehen.
    _bootvorschau(breite, y + 34.0, hoehe - FUSS - 96.0, stand)

    # Lizenzen sind Pflicht, nicht Kuer: Godot steht unter MIT, die Schriften
    # unter SIL OFL, und beide verlangen, dass der Text mit ausgeliefert wird.
    _text(Vector2(RAND, y + 16.0),
        "Godot Engine (MIT)  -  fonts SIL OFL 1.1  -  all art and sound "
        + "generated by this game itself", 12, Color(0.40, 0.52, 0.58))

    # **Ganz unten, mit Abstand.** Ein Knopf, der alles loescht, gehoert nicht
    # neben einen, den man oft tippt.
    var unten := hoehe - FUSS - 24.0 - 40.0
    _loeschen = Rect2(RAND, maxf(y + 30.0, unten), breite - RAND * 2.0, 38.0)
    var warnfarbe := Color(1.0, 0.52, 0.44) if _loeschen_sicher \
        else Color(0.44, 0.36, 0.36)
    _tafelfuellung(_loeschen, Color(0.10, 0.05, 0.05, 0.7))
    _tafelrand(_loeschen, Color(warnfarbe.r, warnfarbe.g, warnfarbe.b, 0.4),
        1.3)
    _text(_loeschen.get_center() + Vector2(0.0, 5.0),
        "REALLY DELETE?" if _loeschen_sicher else "Found the colony anew",
        14, warnfarbe, true)


## Das Boot in Lebensgroesse, im gewaehlten Anstrich.
##
## **Dieselben Proportionen wie in der Fahrt**, nur ohne die Rechnung
## dahinter: Rumpf, Turm, Scheinwerfer, Kegel, Begleiter. Ein Vorschaubild,
## das anders aussieht als das Boot, waere eine zweite Wahrheit ueber den
## Anstrich - man waehlte eine Farbe und bekaeme eine andere.
##
## Der Kegel ist hier **Zierde und darf es sein**: er trifft nichts. Was in
## der Fahrt gilt, gilt weiter - dort kommt seine Deckung aus
## `Schlund.beleuchtung()` und der Anstrich faerbt nur (Zusage 2).
func _bootvorschau(breite: float, oben: float, unten: float,
        stand: KolonieStand) -> void:
    var hoch := unten - oben
    if hoch < 160.0:
        return
    var haut := Skins.haut(stand.skin)
    var strahl := Skins.strahl(stand.skin)
    var kern := Skins.kern(stand.skin)
    var glut := Skins.glut(stand.skin)

    # **Es zeigt nach oben, nicht nach rechts.** Nach rechts lief der Kegel
    # ueber den Bildrand hinaus und nahm die halbe Flaeche ein; das Bild war
    # dann ein Scheinwerfer mit einem Boot daran. Hochkant ist auch die Form
    # des Bildschirms - der Kegel hat Platz, ohne dass er breiter wird.
    var k := Vector2.UP
    var quer := k.orthogonal()
    var r := clampf(hoch * 0.10, 24.0, 54.0)
    # **Der Abstand nach unten kommt aus dem Boot, nicht aus dem Kasten.**
    # Ein Drittel der Hoehe reichte bei 720x1600 und nicht bei 720x1280 -
    # dort standen die Begleiter im Beschreibungstext. Sie haengen 2,7
    # Rumpfradien hinter dem Boot, also braucht es genau so viel Luft.
    var mitte := Vector2(breite * 0.5,
        unten - maxf(hoch * 0.34, r * 4.0 + 26.0))

    # Der Kegel: vier Lagen, die nach aussen blasser werden. **Nicht als
    # Verlaufspolygon** - `draw_polygon` mit Farbe je Ecke zeichnet auf einer
    # HUD-Ebene nichts, derselbe Fund wie beim Trefferaum in `rund_hud.gd`.
    var weite := minf(r * 6.0, mitte.y - oben - 8.0)
    for lage in 4:
        var t := float(lage + 1) / 4.0
        var oeffnung := 0.13 + 0.20 * t
        var keil := PackedVector2Array([mitte])
        for i in 9:
            var w := lerpf(-oeffnung, oeffnung, float(i) / 8.0)
            keil.append(mitte + k.rotated(w) * weite * (1.0 - 0.08 * t))
        _flaeche.draw_colored_polygon(keil,
            Color(strahl.r, strahl.g, strahl.b, 0.030 / t))

    # Rumpf: dieselben Proportionen wie in der Fahrt, nur gross gezogen.
    var rumpf := PackedVector2Array()
    for punkt: Vector2 in [Vector2(1.85, 0.0), Vector2(1.10, -0.34),
            Vector2(0.20, -0.50), Vector2(-0.90, -0.42),
            Vector2(-1.40, -0.20), Vector2(-1.48, 0.0),
            Vector2(-1.40, 0.20), Vector2(-0.90, 0.42),
            Vector2(0.20, 0.50), Vector2(1.10, 0.34)]:
        rumpf.append(mitte + k * punkt.x * r + quer * punkt.y * r)
    _flaeche.draw_colored_polygon(rumpf, Color(0.020, 0.052, 0.068))
    var ring := rumpf + PackedVector2Array([rumpf[0]])
    _flaeche.draw_polyline(ring, Color(haut.r, haut.g, haut.b, 0.10), 6.0, true)
    _flaeche.draw_polyline(ring, Color(haut.r, haut.g, haut.b, 0.60), 1.8, true)

    # Kiellinie und zwei Spanten - das, was aus einem Umriss einen Koerper
    # macht.
    _flaeche.draw_line(mitte - k * r * 1.30, mitte + k * r * 1.55,
        Color(haut.r, haut.g, haut.b, 0.18), 1.0, true)
    for anteil: float in [-0.55, 0.30]:
        var br := r * (0.50 - absf(anteil) * 0.16)
        _flaeche.draw_line(mitte + k * r * anteil - quer * br,
            mitte + k * r * anteil + quer * br,
            Color(haut.r, haut.g, haut.b, 0.18), 1.0, true)

    # Turm mittschiffs, Scheinwerfer an der Spitze - dort setzt der Kegel an.
    _flaeche.draw_circle(mitte - k * r * 0.28, r * 0.28,
        Color(0.030, 0.075, 0.095))
    _flaeche.draw_arc(mitte - k * r * 0.28, r * 0.28, 0.0, TAU, 22,
        Color(haut.r, haut.g, haut.b, 0.50), 1.6, true)
    _flaeche.draw_circle(mitte + k * r * 1.62, r * 0.30,
        Color(strahl.r, strahl.g, strahl.b, 0.16))
    _flaeche.draw_circle(mitte + k * r * 1.62, r * 0.13,
        Color(kern.r, kern.g, kern.b, 0.80))

    # Der Antrieb glueht am Heck, drei Duesen nebeneinander.
    for i in 3:
        var p := mitte - k * r * 1.46 + quer * (float(i) - 1.0) * r * 0.26
        _flaeche.draw_circle(p, r * 0.16, Color(glut.r, glut.g, glut.b, 0.26))
        _flaeche.draw_circle(p, r * 0.06, Color(glut.r, glut.g, glut.b, 0.85))

    # Drei Begleiter im Kielwasser, in einer Reihe dahinter.
    for i in 3:
        var p2 := mitte - k * r * 2.7 + quer * (float(i) - 1.0) * r * 0.85
        _flaeche.draw_circle(p2, r * 0.20, Color(haut.r, haut.g, haut.b, 0.10))
        _flaeche.draw_circle(p2, r * 0.08, Color(haut.r, haut.g, haut.b, 0.65))

    _text(Vector2(breite * 0.5, unten - 10.0), Skins.regel(stand.skin), 12,
        LEISE, true)


## Eine Einstellungszeile: Beschriftung links, Wert daneben, Trennlinie unten.
## Gibt die naechste Zeilenoberkante zurueck.
func _reglerzeile(breite: float, y: float, was: String, wert: String) -> float:
    _text(Vector2(RAND, y + 28.0), was, 15, Color(0.72, 0.88, 0.92))
    if not wert.is_empty():
        _text(Vector2(RAND + 150.0, y + 28.0), wert, 15, LEISE)
    _flaeche.draw_line(Vector2(RAND, y + ZEILE - 1.0),
        Vector2(breite - RAND, y + ZEILE - 1.0), Color(0.20, 0.36, 0.42, 0.28), 1.0)
    return y + ZEILE


func _knopffeld(kasten: Rect2, text: String, farbe: Color, kante: Color) -> void:
    _tafelgrund(kasten, 0.95)
    _tafelkante(kasten, kante, 0.34, 1.3)
    _text(kasten.get_center() + Vector2(0.0, 5.0), text, 14, farbe, true)


## Ein Schalter. **Der Zustand steht im Knopf und in seiner Farbe** - ein
## Knopf, der nur "ON" sagt, ohne dass man sieht, ob das der Zustand oder die
## Handlung ist, zwingt zum Ausprobieren.
func _schalterfeld(kasten: Rect2, an: bool) -> void:
    var farbe := NAEHR if an else Color(0.40, 0.52, 0.58)
    _knopffeld(kasten, "ON" if an else "OFF", farbe, farbe)


## Ein Anstrich zur Auswahl: der Rumpf in seinen eigenen Farben, daneben der
## Name. Gesperrte stehen blass da und sagen, ab welcher Welle sie aufgehen -
## ein gesperrtes Feld ohne Ziel daneben ist nur eine Absage.
func _skinfeld(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var frei := Skins.frei(index, stand.hoechste_welle)
    var gewaehlt := stand.skin == index
    var haut := Skins.haut(index)
    var strahl := Skins.strahl(index)

    _tafelgrund(kasten, 0.92 if frei else 0.55)
    _tafelkante(kasten, haut, 0.75 if gewaehlt else (0.22 if frei else 0.08),
        2.2 if gewaehlt else 1.3)

    # Ein Boot im Kleinen, in den Farben dieses Anstrichs. **Gezeichnet und
    # nicht beschrieben**: was man waehlt, ist ein Aussehen, und ein
    # Farbklecks daneben zeigt es genauer als jeder Name.
    var mitte := Vector2(kasten.position.x + 38.0, kasten.get_center().y)
    var deckung := 1.0 if frei else 0.32
    if frei:
        _flaeche.draw_circle(mitte + Vector2(26.0, 0.0), 17.0,
            Color(strahl.r, strahl.g, strahl.b, 0.10))
    var rumpf := PackedVector2Array([
        mitte + Vector2(24.0, 0.0), mitte + Vector2(4.0, -9.0),
        mitte + Vector2(-16.0, -7.0), mitte + Vector2(-20.0, 0.0),
        mitte + Vector2(-16.0, 7.0), mitte + Vector2(4.0, 9.0)])
    _flaeche.draw_colored_polygon(rumpf, Color(0.020, 0.052, 0.068, deckung))
    _flaeche.draw_polyline(rumpf + PackedVector2Array([rumpf[0]]),
        Color(haut.r, haut.g, haut.b, 0.85 * deckung), 1.6, true)
    _flaeche.draw_circle(mitte + Vector2(14.0, 0.0), 3.4,
        Color(strahl.r, strahl.g, strahl.b, 0.9 * deckung))

    var links := kasten.position.x + 68.0
    _text(Vector2(links, kasten.position.y + 26.0), Skins.name_von(index), 15,
        SCHRIFT if frei else Color(0.40, 0.50, 0.56))
    if frei:
        _text(Vector2(links, kasten.position.y + 46.0),
            "IN USE" if gewaehlt else "tap to wear", 12,
            NAEHR if gewaehlt else LEISE)
    else:
        _text(Vector2(links, kasten.position.y + 46.0),
            "wave %d" % Skins.ab_welle(index), 12, Color(0.40, 0.50, 0.56))


## Eine Brutlinie. Anders als eine Kammer hat sie keine Stufen - sie ist da
## oder nicht, und mehrere koennen zugleich tragen.
func _brutlinie(kasten: Rect2, index: int, stand: KolonieStand) -> void:
    var farbe := Brutlinien.farbe(index)
    var hat := stand.hat_linie(index)
    var traegt := stand.linie_traegt(index)

    _tafelgrund(kasten, 0.92 if hat else 0.62)
    _tafelkante(kasten, farbe, 0.62 if traegt else 0.26,
        2.0 if traegt else 1.4)
    _tafelstreifen(kasten, farbe, 0.85 if hat else 0.30)

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _brutsinnbild(Vector2(kasten.position.x + 46.0, mitte_y), 22.0, index, farbe, hat)

    var links := kasten.position.x + 84.0
    _text(Vector2(links, kasten.position.y + 32.0), Brutlinien.name_von(index), 17,
        SCHRIFT if hat else LEISE)
    _text(Vector2(links, kasten.position.y + 56.0), Brutlinien.wirkung(index), 12,
        LEISE if hat else Color(0.34, 0.44, 0.50))

    # Derselbe Knopf wie auf den Kammerkarten - aus demselben Grund: was man
    # antippen kann, muss aussehen wie etwas, das man antippt. Zwei
    # Bildschirme mit derselben Handlung und zwei verschiedenen Formen dafuer
    # sind ein Bildschirm zu viel.
    var knopf := Rect2(kasten.end.x - KNOPF_BREIT - 10.0, kasten.position.y + 10.0,
        KNOPF_BREIT, kasten.size.y - 20.0)
    var mitte := knopf.get_center()
    if traegt:
        _tafelfuellung(knopf, Color(farbe.r, farbe.g, farbe.b, 0.22))
        _tafelrand(knopf, Color(farbe.r, farbe.g, farbe.b, 0.9), 2.0)
        _text(mitte + Vector2(0.0, 5.0), "CARRIES", 14, SCHRIFT, true)
    elif hat:
        _tafelfuellung(knopf, Color(0.06, 0.14, 0.17, 0.6))
        _tafelrand(knopf, Color(farbe.r, farbe.g, farbe.b, 0.5), 1.5)
        _text(mitte + Vector2(0.0, 5.0), "SELECT", 14,
            Color(farbe.r, farbe.g, farbe.b, 0.9), true)
    else:
        var davor := Brutlinien.voraussetzung(index)
        var frei := stand.hat_linie(davor)
        var preis := Brutlinien.kosten(index)
        var reicht := frei and stand.naehrstoffe >= preis
        if reicht:
            _tafelfuellung(knopf, Color(farbe.r, farbe.g, farbe.b, 0.20))
            _tafelrand(knopf, Color(farbe.r, farbe.g, farbe.b, 0.85), 1.8)
        else:
            _tafelfuellung(knopf, Color(0.06, 0.08, 0.10, 0.5))
            _tafelrand(knopf, Color(SPERRE.r, SPERRE.g, SPERRE.b, 0.30), 1.4)
        if frei:
            _text(mitte + Vector2(0.0, -8.0), "BREED", 12,
                SCHRIFT if reicht else LEISE, true)
            _text(mitte + Vector2(0.0, 18.0), Zahl.kurz(preis), 19,
                NAEHR if reicht else SPERRE, true)
        else:
            _text(mitte + Vector2(0.0, 5.0), "LOCKED", 14, SPERRE, true)
            # **"locked" allein ist keine Auskunft, sondern eine Absage.**
            #
            # Fuenf von sechs Zeilen standen darauf, und nirgends stand,
            # woran es liegt. Dabei ist die Bedingung genau eine, und sie
            # steht eine Zeile weiter oben im selben Bildschirm.
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


## --- Die Kammerkarte ---
##
## **Sie sah nicht aus wie etwas, das man antippt.**
##
## Die ganze Zeile war das Tippziel, und nichts sagte das. Rechts stand ein
## kleines "to 7" mit einer Zahl darunter, frei an der Kante - kein Rahmen,
## keine Flaeche, nichts, was einen Knopf von einer Auskunft unterscheidet.
## Wer den Bildschirm zum ersten Mal sieht, liest fuenf Zeilen mit Zahlen und
## sucht dann den Ausbauknopf. Es gab keinen.
##
## Jetzt traegt jede Karte rechts eine Schaltflaeche ueber die volle Hoehe.
## Sie ist zugleich die Zustandsanzeige der Kammer: gefuellt, wenn der
## Naehrstoff reicht; nur umrandet, wenn nicht; ein Fortschrittsbalken samt
## Restzeit, waehrend gegraben wird; und stumpf mit einem Wort darin, wenn
## der Tiefenschacht sie deckelt. Ein Zustand, eine Stelle.
const KNOPF_BREIT := 128.0


func _kammer(kasten: Rect2, k: int, stand: KolonieStand, jetzt: float) -> void:
    var farbe := FARBEN[k]
    var stufe := stand.stufe(k)
    var deckel := Kammern.deckel(k, stand.schacht())
    var baut_hier := stand.bau_kammer == k
    var gedrueckt := _gedrueckt == k

    _tafelgrund(kasten, 0.95 if gedrueckt else 0.82)
    _tafelkante(kasten, farbe, 0.34, 1.4)
    # Farbstreifen links - so ist die Kammer schon vor dem Lesen erkennbar.
    _tafelstreifen(kasten, farbe, 0.85)

    var mitte_y := kasten.position.y + kasten.size.y * 0.5
    _sinnbild(Vector2(kasten.position.x + 44.0, mitte_y - 8.0), 23.0, k, farbe, stufe)
    # Die Stufe steht **am Sinnbild**, nicht in einer eigenen Spalte: das
    # Bild sagt, welche Kammer, die Zahl darunter, wie weit sie ist. Zwei
    # Angaben zu einer Sache gehoeren nebeneinander.
    _text(Vector2(kasten.position.x + 44.0, kasten.end.y - 16.0),
        "LVL %d" % stufe, 14, farbe, true)

    var links := kasten.position.x + 80.0
    var knopf := Rect2(kasten.end.x - KNOPF_BREIT - 10.0, kasten.position.y + 10.0,
        KNOPF_BREIT, kasten.size.y - 20.0)
    var textweit := knopf.position.x - links - 14.0

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
    if dann_wirkt != jetzt_wirkt and stufe < deckel:
        wirkzeile = "%s   →   %s" % [jetzt_wirkt, dann_wirkt]
    _text(Vector2(links, kasten.position.y + 76.0), wirkzeile, 12,
        Color(farbe.r, farbe.g, farbe.b, 0.80))

    # Der Tiefenschacht misst gegen die Stufe, die den naechsten Abschnitt
    # aufmacht; alle anderen gegen den Deckel, den er ihnen setzt.
    var schranke := deckel
    if k == Kammern.Kammer.TIEFENSCHACHT and stand.naechste_tiefe() > stufe:
        schranke = stand.naechste_tiefe()
    _stufenzeile(Vector2(links, kasten.position.y + 96.0), maxf(40.0, textweit),
        stufe, schranke, farbe)

    _ausbauknopf(knopf, k, stand, jetzt, farbe, stufe, deckel, baut_hier)


## Die Schaltflaeche rechts auf der Karte. Sie zeigt genau einen von fuenf
## Zustaenden, und der Zustand bestimmt Form **und** Farbe - eine gefuellte
## Flaeche heisst "geht", eine umrandete "kostet mehr, als du hast".
func _ausbauknopf(knopf: Rect2, k: int, stand: KolonieStand, jetzt: float,
        farbe: Color, stufe: int, deckel: int, baut_hier: bool) -> void:
    var mitte := knopf.get_center()

    if baut_hier:
        # Der Bau selbst ist der Knopf: der Balken fuellt ihn von unten,
        # darauf die Restzeit. Damit sieht man an derselben Stelle, an der
        # man getippt hat, was daraus geworden ist.
        var rest := stand.restzeit(jetzt)
        var ganz := maxf(0.001, Kammern.bauzeit(k, stufe))
        var anteil := clampf(1.0 - rest / ganz, 0.0, 1.0)
        _tafelfuellung(knopf, Color(0.0, 0.0, 0.0, 0.35))
        _flaeche.draw_rect(Rect2(knopf.position.x,
            knopf.end.y - knopf.size.y * anteil, knopf.size.x,
            knopf.size.y * anteil), Color(farbe.r, farbe.g, farbe.b, 0.30))
        _tafelrand(knopf, Color(farbe.r, farbe.g, farbe.b, 0.6), 1.6)
        _text(mitte + Vector2(0.0, -4.0), "DIGGING", 12,
            Color(farbe.r, farbe.g, farbe.b, 0.9), true)
        _text(mitte + Vector2(0.0, 18.0), _dauer(rest), 17, SCHRIFT, true)
        return

    if stufe >= deckel:
        # **Der Grund entscheidet ueber den Text, nicht die Kammerart.** Hier
        # stand "SHAFT TOO SHALLOW" fuer jede Kammer ausser dem Schacht - und
        # auf Stufe 80 meldeten damit alle vier, der Schacht sei zu flach,
        # waehrend er daneben mit MAXED bei 80 von 80 stand. Wer am Deckel des
        # Spiels angekommen ist, hat kein Schachtproblem.
        var voll := stufe >= Kammern.HOECHSTSTUFE
        var was := "MAXED" if voll or k == Kammern.Kammer.TIEFENSCHACHT \
            else "SHAFT TOO"
        var zweite := "" if voll or k == Kammern.Kammer.TIEFENSCHACHT \
            else "SHALLOW"
        _tafelfuellung(knopf, Color(0.10, 0.11, 0.12, 0.55))
        _tafelrand(knopf, Color(SPERRE.r, SPERRE.g, SPERRE.b, 0.35), 1.4)
        _text(mitte + Vector2(0.0, 0.0 if zweite.is_empty() else -6.0), was, 13,
            SPERRE, true)
        if not zweite.is_empty():
            _text(mitte + Vector2(0.0, 12.0), zweite, 13, SPERRE, true)
        return

    if stand.baut():
        # Es wird woanders gegraben. Kein zweiter Bau gleichzeitig - das steht
        # hier, damit niemand auf einen Knopf drueckt, der nichts tut.
        _tafelfuellung(knopf, Color(0.08, 0.10, 0.12, 0.5))
        _tafelrand(knopf, Color(LEISE.r, LEISE.g, LEISE.b, 0.25), 1.4)
        _text(mitte + Vector2(0.0, 5.0), "IN QUEUE", 13, LEISE, true)
        return

    var preis := stand.preis(k)
    var reicht := stand.naehrstoffe >= preis
    if reicht:
        _tafelfuellung(knopf, Color(farbe.r, farbe.g, farbe.b, 0.20))
        _tafelrand(knopf, Color(farbe.r, farbe.g, farbe.b, 0.85), 1.8)
    else:
        _tafelfuellung(knopf, Color(0.06, 0.08, 0.10, 0.5))
        _tafelrand(knopf, Color(SPERRE.r, SPERRE.g, SPERRE.b, 0.30), 1.4)

    # Ein Pfeil nach oben statt des Wortes "upgrade": er ist in jeder Sprache
    # dasselbe und braucht ein Drittel des Platzes.
    var pfeil_farbe := farbe if reicht else SPERRE
    var spitze := Vector2(mitte.x - 34.0, knopf.position.y + 20.0)
    _flaeche.draw_polyline(PackedVector2Array([
        spitze + Vector2(-6.0, 6.0), spitze, spitze + Vector2(6.0, 6.0)]),
        pfeil_farbe, 2.0, true)
    _flaeche.draw_line(spitze, spitze + Vector2(0.0, 12.0), pfeil_farbe, 2.0)

    _text(Vector2(mitte.x + 8.0, knopf.position.y + 26.0),
        "LVL %d" % (stufe + 1), 13, LEISE if not reicht else SCHRIFT, true)
    _text(Vector2(mitte.x, knopf.end.y - 16.0), Zahl.kurz(preis), 20,
        NAEHR if reicht else SPERRE, true)


## Der Stufenbalken: wie weit die Kammer bis zur naechsten Schranke ist.
##
## **Hier stand einmal eine Punktreihe**, ein Punkt je Stufe. Das war lesbar,
## solange die Hoechststufe 20 war; seit der Graben keinen Boden hat, sind es
## achtzig Punkte, von denen sechs gefuellt waren. Die Zahl steht jetzt als
## Marke am Sinnbild, und hier bleibt das, was eine Zahl nicht kann: das
## Gefuehl, wie weit es noch geht.
##
## **Gemessen wird gegen die Schranke, nicht gegen die Hoechststufe.** Gegen
## 80 gemessen ist Stufe 6 ein Strich von vier Pixeln - richtig gerechnet und
## trotzdem nutzlos, weil die Hoechststufe kein Ziel ist, das jemand vor sich
## hat. Die Schranke ist eines: bei den vier Kammern der Deckel des
## Tiefenschachts, beim Tiefenschacht selbst die Stufe, die den naechsten
## Grabenabschnitt aufmacht.
const BALKEN_HOCH := 5.0


func _stufenzeile(wo: Vector2, breite: float, stufe: int, bis: int,
        farbe: Color) -> void:
    var y := wo.y
    var weit := maxf(30.0, breite - 46.0)
    var voll := float(maxi(1, bis))
    var anteil := clampf(float(stufe) / voll, 0.0, 1.0)

    _tafelfuellung(Rect2(wo.x, y - BALKEN_HOCH * 0.5, weit, BALKEN_HOCH),
        Color(0.34, 0.36, 0.38, 0.24))
    _tafelfuellung(Rect2(wo.x, y - BALKEN_HOCH * 0.5, weit * anteil,
        BALKEN_HOCH), farbe)
    _text(Vector2(wo.x + breite, y + 5.0), "of %d" % bis, 11,
        NAEHR if stufe >= bis else LEISE, false, true)


## Setzt den Lehrschritt von aussen. -1 heisst: nichts anzeigen.
##
## **Der Bildschirm treibt ihn seit der Loeschung selbst** - siehe
## `_fuehre_einstieg()`. Diese Tuer bleibt fuer die Werkzeuge (`--lehre`)
## und fuer den Fall, dass ihn spaeter wieder jemand von aussen setzen will.
func zeige_einstieg(schritt: int) -> void:
    _lehre = schritt
    _lehre_von_hand = schritt >= 0


## Ob der Schritt von aussen gesetzt wurde. Ohne diese Marke ueberschreibt
## `_fuehre_einstieg()` im naechsten Bild, was `--lehre` gerade gesetzt hat -
## und der Schalter, mit dem man den Einstieg ansehen will, zeigt nichts.
var _lehre_von_hand := false


## Den Einstieg fuehren, solange er laeuft.
##
## **Er lief nirgends mehr.** Gesetzt wurde er ausschliesslich aus
## `wache.gd`; seit deren Loeschung stand `_lehre` fuer immer auf -1, und ein
## neuer Spieler bekam die Fahrt erklaert und den Ausbau gar nicht. Der
## Bildschirm, um den es geht, ist dieser - also fuehrt er ihn selbst.
##
## Weiter geht es, wenn der Spieler **getan hat, wovon der Satz redet**: eine
## Kammer gehoben, eine Linie gezuechtet, den Tagesreiter geoeffnet. Eine Uhr
## waere hier falsch - wer liest, soll nicht ueberholt werden.
func _fuehre_einstieg() -> void:
    if _lehre_von_hand:
        return
    var stand: KolonieStand = Fortschritt.stand
    if stand.einstieg < 0 or stand.einstieg >= Lehrpfad.anzahl():
        _lehre = -1
        return
    _lehre = stand.einstieg


## Der Spieler hat getan, was der laufende Schritt verlangt.
func _einstieg_weiter(kennung: StringName) -> void:
    var stand: KolonieStand = Fortschritt.stand
    if not Lehrpfad.gilt(stand.einstieg):
        return
    if Lehrpfad.kennung(stand.einstieg) != kennung:
        return
    stand.einstieg += 1
    Fortschritt.sichere()


## Dieselbe Tafel wie im HUD, nur ohne Ring: hier zeigt der Bildschirm selbst
## schon auf die Kammern, weil er aus nichts anderem besteht.
## Wieviele Zeilen der Satz hoechstens bekommt, und wie hoch eine ist.
const LEHR_ZEILEN := 3
const LEHR_ZEILENHOCH := 18.0


func _lehrtafel(breite: float, hoehe: float) -> void:
    var puls := 0.5 + 0.5 * sin(_zeit * 2.0)
    # **Der Satz wird umgebrochen, und der Kasten waechst mit.**
    #
    # Er stand in einer Zeile in einem Kasten fester Hoehe, und die Saetze
    # des alten Einstiegs waren kurz genug dafuer. Die neuen sind es nicht:
    # "…even with the app closed" lief rechts aus dem Bild, und ein
    # Erklaertext, dessen Ende fehlt, erklaert die Haelfte.
    var innen := breite - RAND * 2.0 - 30.0
    var zeilen := _breche_um(Lehrpfad.satz(_lehre), 13, innen)
    var hoch := 34.0 + float(zeilen.size()) * LEHR_ZEILENHOCH + 10.0
    var kasten := Rect2(RAND, hoehe - FUSS - hoch - 10.0,
        breite - RAND * 2.0, hoch)
    _tafelgrund(kasten, 0.94)
    _tafelkante(kasten, Color(0.42, 0.86, 0.92), 0.24 + 0.16 * puls, 1.4)
    _tafelstreifen(kasten, Color(0.52, 0.94, 0.86), 0.85)
    _text(Vector2(kasten.position.x + 16.0, kasten.position.y + 25.0),
        Lehrpfad.titel(_lehre), 16, NAEHR)
    _text(Vector2(kasten.end.x - 14.0, kasten.position.y + 24.0),
        "%d/%d" % [_lehre + 1, Lehrpfad.anzahl()], 12, LEISE, false, true)
    for i in zeilen.size():
        _text(Vector2(kasten.position.x + 16.0,
            kasten.position.y + 46.0 + float(i) * LEHR_ZEILENHOCH),
            zeilen[i], 13, SCHRIFT)


## Einen Satz auf eine Breite umbrechen. Wortweise - mitten im Wort zu
## trennen braeuchte Silbenregeln, und die haengen an der Sprache.
func _breche_um(satz: String, groesse: int, weite: float) -> PackedStringArray:
    var zeilen := PackedStringArray()
    var laufend := ""
    for wort in satz.split(" "):
        var versuch := wort if laufend.is_empty() else laufend + " " + wort
        if _schrift.get_string_size(versuch, HORIZONTAL_ALIGNMENT_LEFT, -1,
                groesse).x <= weite or laufend.is_empty():
            laufend = versuch
        else:
            zeilen.append(laufend)
            laufend = wort
        if zeilen.size() >= LEHR_ZEILEN:
            break
    if not laufend.is_empty() and zeilen.size() < LEHR_ZEILEN:
        zeilen.append(laufend)
    return zeilen


func _fusszeile(breite: float, hoehe: float) -> void:
    _schliessen = Rect2(RAND + _rand_seite, hoehe - FUSS + 8.0,
        breite - (RAND + _rand_seite) * 2.0, 52.0)
    var puls := 0.5 + 0.5 * sin(_zeit * 2.2)
    _tafelfuellung(_schliessen, Color(0.08, 0.20, 0.24, 0.9))
    _tafelrand(_schliessen, Color(0.42, 0.86, 0.92, 0.30 + 0.25 * puls),
        1.6)
    _text(_schliessen.get_center() + Vector2(0.0, 6.0), zurueck_beschriftung,
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
