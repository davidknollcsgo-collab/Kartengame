extends Node2D

## Die Schlundwache - die Kernschleife.
##
## Ein Finger halten und schwenken, alles im Licht wird verbrannt, zwischen
## den Wellen Wehrpolypen in freie Nischen setzen.
##
## **Was sich dieser Knoten mit dem Wellenpruefer teilt**, und zwar wortwoertlich
## dieselben Funktionen:
##
##   * `Schlund.bahn()`      - wo ein Raeuber zu einem Zeitpunkt steht
##   * `Schlund.beleuchtung()` - wie hell er im Kegel steht
##   * `Schlund.brennende()` - wen der Kegel tatsaechlich fasst
##   * `Wellen.leben_in()`   - wieviel Leben er mitbringt
##
## Was sich unterscheidet, ist genau eine Sache: dort zielt eine Rechnung,
## hier ein Daumen. Alles andere getrennt zu fuehren waere derselbe Fehler wie
## bei HYPHA - getrennte Loeser, verschiedene Ergebnisse.

enum Lage { BAUEN, WELLE, VERLOREN, GESCHAFFT, SITZUNG_ENDE, PAUSE }

## Wie lange die Trefferanzeige eines Raeubers nachgluecht. Ohne Nachhall
## flackert sie bei jedem Schwenk, und man sieht nicht mehr, wen man fasst.
const HITZE_ABKLINGEN := 5.0

## Glieder der Grabnatter und ihr zeitlicher Abstand.
const NATTER_GLIEDER := 7
const NATTER_ABSTAND := 0.055

## **Kurz und flach.** Ein Bild, das bei jedem Treffer springt, laesst sich
## nicht mehr entspannt spielen - und genau das soll dieses Spiel sein: eine
## Minute, in der man einen Lichtkegel zieht, nicht ein Ruettelbrett. Der
## Ausschlag ist deshalb halbiert und klingt schneller ab; was die Nachricht
## traegt, ist der farbige Rand, nicht das Wackeln.
const SCHUETTELN_ABKLINGEN := 9.5
const SCHUETTELN_WEITE := 3.4


@onready var _kegel: Node2D = $Kegel
@onready var _schwarm: Node2D = $Schwarm
@onready var _kolonie: Node2D = $Kolonie
@onready var _waechter: Node2D = $Waechter
@onready var _funken: Node2D = $Funken
@onready var _vordergrund: Node2D = $Vordergrund
@onready var _wasser: ColorRect = $Wasser/Flaeche
@onready var _kamera: Camera2D = $Kamera

## Wie weit die Brut ueber der Unterkante steht - in Entwurfseinheiten, also
## bei einem Bild von 720 mal 1280.
##
## **Daran haengt die ganze Komposition auf einem echten Telefon.** Der
## Entwurf steht auf 16:9; ein heutiges Handy hat 20:9 und mehr. Bei
## `stretch/aspect=expand` waechst dabei die sichtbare Hoehe, und weil Brut
## und Waechter feste Weltpunkte sind, rutschen sie nach oben: auf 1080 mal
## 2400 stand der Waechter hinter dem Bedienfeld, und unter der Brut klaffte
## ein Viertel des Bildes leer.
##
## Die Kamera wird deshalb nicht auf den Ursprung gesetzt, sondern so, dass
## dieser Abstand stimmt - egal wie hoch das Bild ist.
##
## **Der Zusatz faellt aber nach unten und nicht nach oben.** Hier stand
## einmal das Gegenteil: "was dazukommt, kommt oben dazu, und dort gehoert es
## auch hin - mehr Graben, aus dem die Raeuber kommen". Das war falsch. Oben
## liegt bei y = -760 der Eintrittsrand, und der ist bei 1280 Einheiten
## gerade eben ausserhalb des Bildes. Ein Schuss bei 720x1600 zeigte
## vierzehn Raeuber nebeneinander auf einer Reihe - die Linie, auf der sie
## erscheinen. Die Regel steht jetzt in `Graben.kamera_y()` und deckelt das.

@onready var _hud: CanvasLayer = $Hud
@onready var _koloniebild: CanvasLayer = $Koloniebild

var lage := Lage.BAUEN
var welle_nummer := 1
var brut := Graben.BRUT_LEBEN
var polypen: Array[Vector2] = []
var verdient := 0

## Wie viele Wellen diese Sitzung schon gelaufen sind.
##
## **Warum es das ueberhaupt gibt.** Der Wellenpruefer und der Kolonielauf
## rechnen seit jeher in Sitzungen zu `Graben.WELLEN_JE_SITZUNG` Wellen: volle
## Brut am Anfang, Wehrpolypen aus dem Verdienst der Sitzung. Das Spiel tat
## das nicht - dort trug die Brut ihren Schaden ueber beliebig viele Wellen
## weiter, und einmal gesetzte Polypen standen fuer immer. Beides zusammen
## heisst: gemessen wurde ein anderes Spiel als gespielt.
var welle_in_sitzung := 0

## --- Das Stosslicht ---
##
## `_stoss_kuehl` sind die Sekunden, bis es wieder bereit ist. `_stoss_weit`
## ist der Radius des laufenden Rings, oder -1, wenn keiner unterwegs ist.
## `_stoss_nr` zaehlt die Stoesse durch; jedes Tier merkt sich die Nummer des
## Rings, der es getroffen hat.
var _stoss_kuehl := 0.0
var _stoss_weit := -1.0
var _stoss_nr := 0

## Die Funkenbluete dieser Welle, oder null. Hoechstens eine je Welle: zwei
## gleichzeitig waeren keine Entscheidung mehr, sondern eine zweite Front.
var _bluete: Bluete = null

## Ob in dieser Sitzung schon eine Bluete erklaert wurde.
var _bluete_gesehen := false

## --- Kette und Punkte ---
##
## `kette` ist die Zahl der Abschuesse in Folge, `_kette_zeit` die Restzeit,
## in der sie weitergeht. `punkte` sammelt ueber die ganze Sitzung, nicht ueber
## die Welle: eine Bestmarke, die sich nach fuenf Wellen entscheidet, ist eine
## Sitzung wert - eine, die sich nach einer entscheidet, ist ein Wuerfelwurf.
var kette := 0
var kette_hoechste := 0
var punkte := 0
var _kette_zeit := 0.0

## Wieviele Raeuber diese Sitzung gekostet hat. Steht auf dem Schlussbild
## neben dem Naehrstoff - die eine Zahl sagt, was man mitnimmt, die andere,
## was man getan hat.
var erlegt := 0

var _tiere: Array[Raeuber] = []
var _offen := 0
var _wellenzeit := 0.0
var _richtung := Vector2.UP
var _wirksam := Vector2.UP
var _finger := Graben.WAECHTER + Vector2.UP * 300.0
var _zieht := false
var _schuetteln := 0.0
var _polyp_takt := PackedFloat32Array()

## Wieviele Treffer ohne Unterbrechung. Treibt nur die Tonhoehe.
var _folge := 0.0

## Ueberblendung zwischen zwei Abschnittsfarben.
## Die Mutationen der laufenden Welle. Steht im Kopf, damit man vor dem
## Ziehen weiss, womit man es zu tun hat.
var _mutationen := PackedInt32Array()

var _alt_abschnitt := 0
var _ziel_abschnitt := 0
var _farbmischung := 1.0

## Ob die laufende Welle eine Tagesstroemung ist. Wird beim Start der Welle
## entschieden und verbraucht - nicht bei jedem Treffer neu gefragt, sonst
## koennte eine einzige Welle den ganzen Tagesvorrat aufzehren.
var _stroemung := false


func _ready() -> void:
    # Der Fels soll vom selben Kegel angeleuchtet werden, der auch Schaden
    # macht. Deshalb bekommt die Kolonie den Knoten selbst, nicht eine Kopie
    # seiner Werte - eine Kopie liefe irgendwann auseinander.
    _kolonie.kegel = _kegel
    _waechter.kegel = _kegel

    _richte_kamera()
    get_viewport().size_changed.connect(_richte_kamera)
    _faerbe_abschnitt(Graben.abschnitt(welle_nummer), true)
    _koloniebild.geschlossen.connect(_kolonie_geschlossen)
    Fortschritt.stand_geaendert.connect(_stelle_ausbau_ein)
    Fortschritt.bau_fertig.connect(_bau_fertig)

    welle_nummer = Fortschritt.stand.naechste_welle()
    brut = Fortschritt.stand.brut_leben()
    var heim := Fortschritt.begruesse()
    _stelle_ausbau_ein()
    # Nach `begruesse()`: die Brut haengt an der Brutkammer, und die kann in
    # der Abwesenheit fertig geworden sein.
    brut = Fortschritt.stand.brut_leben()
    _bereite_welle_vor()
    _hud.zeige_rueckkehr(heim)
    _zeige_einstieg()
    _lies_entwicklerschalter()


## Der Einstieg schreitet an Ereignissen fort, nicht an einer Uhr. Wer
## langsamer ist, bekommt mehr Zeit; wer es sofort versteht, wird nicht
## aufgehalten.
func _zeige_einstieg() -> void:
    var schritt: int = Fortschritt.stand.einstieg
    if not Lehrpfad.gilt(schritt):
        _hud.zeige_einstieg(-1)
        _koloniebild.zeige_einstieg(-1)
        return
    # **Die Wache zielt, nicht das HUD.** Wohin der Ring zeigt, haengt am
    # Spielstand - welche Knospe frei ist, wo die Brut liegt -, und das weiss
    # nur die Wache. Ein HUD, das sich das selbst zusammensucht, waere eine
    # zweite Beschreibung derselben Sache.
    _hud.zeige_einstieg(schritt, _lehr_ort(schritt))
    _koloniebild.zeige_einstieg(schritt)


## Traegt die Punktzahl der Sitzung in die Bestmarke ein und sagt, ob sie
## eine neue ist. Wird genau einmal je Schlussbild gerufen.
func _bestmarke_setzen() -> bool:
    var stand: KolonieStand = Fortschritt.stand
    stand.beste_kette = maxi(stand.beste_kette, kette_hoechste)
    if punkte <= stand.bestpunkte:
        return false
    stand.bestpunkte = punkte
    return true


## Der Weltpunkt, auf den der Ring dieses Schritts zeigt.
func _lehr_ort(schritt: int) -> Vector2:
    match Lehrpfad.ziel(schritt):
        Lehrpfad.Ziel.BRUT:
            return Vector2(0.0, Graben.BRUT_Y - 6.0)
        Lehrpfad.Ziel.NISCHE:
            # Die naechste, die gebaut wuerde - dieselbe Reihenfolge, in der
            # `baue_polyp()` sie vergibt.
            var frei := mini(polypen.size(), Graben.NISCHEN.size() - 1)
            return Graben.NISCHEN[frei]
        _:
            return Vector2.ZERO


func _einstieg_weiter(ab: int) -> void:
    if Fortschritt.stand.einstieg == ab:
        Fortschritt.stand.einstieg += 1
        _zeige_einstieg()


func _bau_fertig(kammer: int) -> void:
    Fortschritt.melde_ziel(Tagesziel.Ziel.AUSBAU)
    _stelle_ausbau_ein()
    if lage == Lage.BAUEN:
        # Eine fertige Kammer waehrend der Welle stumm zu schlucken waere die
        # unsichtbarste Belohnung des Spiels. Zwischen den Wellen darf sie
        # sich zeigen.
        _funken.platzen(Graben.WAECHTER + Vector2(0.0, -40.0),
            Color(0.62, 0.94, 1.0), 26.0)
    Klang.spiele(Klang.Ton.KAMMER, 1.0, 0.7)
    _hud.melde("%s finished" % Kammern.name_von(kammer))
    _einstieg_weiter(7)

    # Ein Schacht, der einen Abschnitt oeffnet, ist mehr als eine Stufe mehr:
    # er gibt den Weg frei, auf dem der Spieler gerade steht.
    if kammer == Kammern.Kammer.TIEFENSCHACHT \
            and Fortschritt.stand.naechste_welle() > welle_nummer:
        welle_nummer = Fortschritt.stand.naechste_welle()
        _hud.zeige_abschnitt(Graben.abschnitt(welle_nummer))
        _bereite_welle_vor()


func _kolonie_geschlossen() -> void:
    _hud.visible = true
    _stelle_ausbau_ein()
    _aktualisiere_kolonie()
    # **Nicht zurueck in die Bauphase, wenn man gar nicht dort war.** Wer die
    # Kolonie vom Schlussbild aus geoeffnet hat, kommt auf das Schlussbild
    # zurueck; `zeige_bauphase()` haette es weggewischt und den Spieler
    # mitten in einer Welle stehen lassen, die er verloren hat.
    if lage != Lage.BAUEN:
        return
    _hud.zeige_bauphase(welle_nummer, brut, Fortschritt.stand.naehrstoffe,
        Fortschritt.stand.polyp_kosten(polypen.size()), polypen.size())


func oeffne_kolonie() -> void:
    # Auch von den Schlussbildern aus: dort ist der Ausbau die Handlung, die
    # etwas aendert, und sie war von dort aus nicht erreichbar.
    if lage not in [Lage.BAUEN, Lage.VERLOREN, Lage.GESCHAFFT,
            Lage.SITZUNG_ENDE]:
        return
    _hud.visible = false
    _einstieg_weiter(6)
    _koloniebild.oeffne()


# --- Ausbau und Wellenvorbereitung ----------------------------------------

## Die vier Werte des Kegels kommen aus der **Kolonie**, nicht mehr aus der
## Sollkurve. `Ausbau` bleibt daneben die Vorgabe, an der sich die Kolonie
## messen lassen muss - `tools/kolonielauf.gd` prueft das ueber 30 Tage.
func _stelle_ausbau_ein() -> void:
    var stand: KolonieStand = Fortschritt.stand
    _kegel.halbwinkel = Graben.HALBWINKEL * stand.winkel_faktor()
    _kegel.reichweite = Graben.REICHWEITE * stand.reichweite_faktor()


func leistung() -> float:
    return Graben.LEISTUNG * Fortschritt.stand.leistung_faktor()


func ziele() -> int:
    return Fortschritt.stand.ziele()


func _bereite_welle_vor() -> void:
    lage = Lage.BAUEN
    _tiere.clear()
    _wellenzeit = 0.0
    _stelle_ausbau_ein()
    _schwarm.tiere = _tiere
    _aktualisiere_kolonie()
    _hud.zeige_bauphase(welle_nummer, brut, Fortschritt.stand.naehrstoffe,
        Fortschritt.stand.polyp_kosten(polypen.size()), polypen.size())
    # Der Ring auf der freien Knospe muss die aktuelle sein - zwischen zwei
    # Wellen sind die Polypen weg, und damit zeigt er wieder auf die erste.
    _zeige_einstieg()


func starte_welle() -> void:
    if lage != Lage.BAUEN:
        return
    _tiere.clear()
    for a in Wellen.auftritte(welle_nummer):
        var r := Raeuber.new()
        r.art = a[&"art"]
        r.welle = welle_nummer
        r.eintritt = a[&"zeit"]
        r.start_x = a[&"x"]
        r.phase = a[&"phase"]
        r.leben_voll = Wellen.leben_in(r.art, welle_nummer)
        r.leben = r.leben_voll
        r.ort = Vector2(r.start_x, Graben.EINTRITT_Y)
        _tiere.append(r)

    # Jede Welle faengt mit einem geladenen Stosslicht an. Es aufzuheben
    # waere eine Buchhaltung ueber Wellen hinweg, und die passt nicht zu
    # einer Handlung, die man im Augenblick trifft.
    _stoss_kuehl = 0.0
    _stoss_weit = -1.0
    # Die Kette gilt je Welle. Ueber die Bauphase hinweg weiterzuzaehlen
    # hiesse, sie im Stehen zu halten - und eine Kette, die man nicht
    # verlieren kann, ist keine.
    kette = 0
    _kette_zeit = 0.0
    _hud.setze_kette(0, 0.0)

    _bluete = null
    _schwarm.bluete = null
    if Wellen.hat_bluete(welle_nummer):
        var b := Wellen.bluete_in(welle_nummer)
        _bluete = Bluete.new()
        _bluete.eintritt = b[&"zeit"]
        _bluete.seite = b[&"seite"]
        _bluete.bahn_y = b[&"y"]
        _bluete.hub = b[&"hub"]
        _bluete.phase = b[&"phase"]
        _bluete.leben_voll = Wellen.bluete_leben(welle_nummer)
        _bluete.leben = _bluete.leben_voll
        _bluete.ort = _bluete.ort_bei(0.0)
    _schwarm.bluete = _bluete

    welle_in_sitzung += 1
    # Der Lehrpfad wartet an dieser Stelle darauf, dass die Welle wirklich
    # losgeht. Ohne den Schritt stand der Spieler vor einem Knopf, auf den
    # nichts zeigte, und mit einem Satz ueber Licht, das noch nichts trifft.
    _einstieg_weiter(0)
    _stroemung = Fortschritt.stand.nutze_stroemung()
    _hud.stroemung = _stroemung
    _offen = _tiere.size()
    _wellenzeit = 0.0
    _polyp_takt.resize(polypen.size())
    _polyp_takt.fill(0.0)
    _schwarm.tiere = _tiere
    lage = Lage.WELLE
    # **Die Kolonie muss erfahren, dass die Bauphase vorbei ist.**
    #
    # `_kolonie.bauphase` wurde in `_bereite_welle_vor()` gesetzt und danach
    # erst wieder, wenn die Brut getroffen wird - bis dahin blinkten die
    # Kreuze auf den freien Nischen die ganze Welle lang weiter. Der
    # Kommentar an der Zeichenstelle sagte sogar, warum das falsch ist
    # ("waehrend der Welle darf hier nichts blinken - der Blick gehoert dem
    # Schlund"); nur wurde die Lage nie durchgereicht.
    _aktualisiere_kolonie()
    _folge = 0.0
    Klang.spiele(Klang.Ton.WELLE, 1.0, 0.55)
    _hud.zeige_welle(welle_nummer, brut, Fortschritt.stand.naehrstoffe, _tiere.size())
    if _stroemung:
        _hud.melde("Day current - double yield")

    # Eine neue Regel gehoert angekuendigt. Wer in Welle 31 ploetzlich im
    # Dunkeln steht und nicht weiss warum, haelt es fuer einen Fehler.
    var a := Graben.abschnitt(welle_nummer)
    _faerbe_abschnitt(a)
    Klang.setze_abschnitt(a)
    if Regeln.neu_in(a) and welle_nummer == a * Graben.WELLEN_JE_ABSCHNITT + 1:
        _hud.zeige_abschnitt(a)

    # **Ein neues Tier wird nicht mehr angekuendigt.**
    #
    # Hier stand eine Tafel "NEW: VEILFORM - comes in swarms and is very
    # fast", mitten im Bild, bevor das erste davon eintrat. Die Begruendung
    # war, dass eine Regel, die man sich erspielen muss, bei einem Gegner an
    # der Brut keine Regel sei, sondern eine Falle.
    #
    # Sie war trotzdem falsch, und zwar aus einem Grund, den man nur beim
    # Spielen merkt: die Tafel nimmt der Welle ihren Anfang. Aus dem Dunkel
    # kommt etwas, das man noch nie gesehen hat - das ist der Augenblick, um
    # den es in diesem Spiel geht -, und eine Schrifttafel sagt vorher, was
    # es ist und wie es sich verhaelt. Aus einer Begegnung wird eine Ansage.
    #
    # Gemerkt wird die Art weiterhin: sie steht danach im Bestiarium, mit
    # ihrer Regel und ihren Werten. Der Unterschied ist, wann man es erfaehrt
    # - hinterher beim Nachschlagen statt vorher als Untertitel.
    for r in _tiere:
        Fortschritt.stand.merke_art(r.art)

    # Die Mutationen dagegen bleiben angesagt. Sie sind keine Gegner, sondern
    # die Bedingungen dieser Welle - was der Kegel heute schlechter kann,
    # sieht man dem Tier nicht an, und es zu verschweigen macht die Welle
    # nicht spannender, sondern nur unerklaerlich.
    var neue_mutation := -1
    _mutationen = Mutationen.in_welle(welle_nummer)
    for m in _mutationen:
        if Fortschritt.stand.merke_mutation(m) and neue_mutation < 0:
            neue_mutation = m

    _hud.mutationen = _mutationen
    if neue_mutation >= 0:
        _hud.zeige_mutation(neue_mutation)
    Fortschritt.sichere()


# --- Schleife --------------------------------------------------------------

## Wie lange die Zeit nach einem erlegten Leitwesen langsamer laeuft, und wie
## langsam. Kurz: eine Zeitlupe, die man abwarten muss, ist keine Belohnung
## mehr, sondern eine Pause.
const ZEITLUPE_DAUER := 0.42
const ZEITLUPE_TIEFE := 0.35

var _zeitlupe := 0.0


## **Die Restzeit wird in echter Zeit gezaehlt, nicht in gespielter.**
##
## `delta` kommt bereits mit `Engine.time_scale` multipliziert herein. Zieht
## man es ungeteilt ab, dauert die Zeitlupe genau um den Faktor laenger, um
## den sie verlangsamt - bei 0.35 also dreimal so lang wie eingestellt, und
## die eingestellte Zahl bedeutet nichts mehr.
## Sicherung: `Engine.time_scale` ist global. Wer diese Szene mitten in einer
## Zeitlupe verlaesst, laesst sonst das ganze Spiel im Schneckentempo zurueck.
func _exit_tree() -> void:
    Engine.time_scale = 1.0


func _zeitlupe_fuehren(delta: float) -> void:
    if _zeitlupe <= 0.0:
        if not is_equal_approx(Engine.time_scale, 1.0):
            Engine.time_scale = 1.0
        return
    _zeitlupe = maxf(0.0, _zeitlupe - delta / maxf(0.05, Engine.time_scale))
    # Am Ende wieder herausfahren statt zurueckzuspringen.
    var t := clampf(_zeitlupe / ZEITLUPE_DAUER, 0.0, 1.0)
    Engine.time_scale = lerpf(1.0, ZEITLUPE_TIEFE, pow(t, 0.6))


## Setzt die Kamera. Die Regel selbst steht in `Graben.kamera_y()` - sie ist
## reine Rechnung und wird dort geprueft.
func _richte_kamera() -> void:
    _kamera.position.y = Graben.kamera_y(get_viewport_rect().size.y)


func _process(delta: float) -> void:
    # **Der Deckel steht vor allem anderen.** Siehe `Graben.takt()`: das erste
    # Bild nach einer Pause bringt die volle verstrichene Zeit mit, und ein
    # einziger ungebremster Schritt raeumt die ganze Brut ab.
    delta = Graben.takt(delta)

    if lage == Lage.PAUSE:
        # Nur das Bild weiterlaufen lassen, nicht die Welle. Der Graben atmet
        # dabei sichtbar weiter - eine eingefrorene Kulisse sieht aus wie ein
        # Absturz, nicht wie eine Pause.
        _schwarm.queue_redraw()
        return

    _zeitlupe_fuehren(delta)
    _stimmung_nachfuehren(delta)
    _schuetteln = maxf(0.0, _schuetteln - delta * SCHUETTELN_ABKLINGEN)
    _kamera.offset = Vector2(
        randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
        * _schuetteln * SCHUETTELN_WEITE

    if lage == Lage.WELLE:
        _fuehre_kegel(delta)
        _bewege(delta)
        _verbrenne(delta)
        _stosslicht_fuehren(delta)
        _bluete_fuehren(delta)
        _polypen_feuern(delta)
        _raeume_auf()
        _wellenzeit += delta
        _folge = maxf(0.0, _folge - delta * 6.0)
        if kette > 0:
            _kette_zeit -= delta
            if _kette_zeit <= 0.0:
                kette = 0
                _hud.setze_kette(0, 0.0)
            else:
                _hud.setze_kette(kette,
                    _kette_zeit / Graben.KETTE_FENSTER)
        if _offen <= 0:
            _welle_geschafft()
    elif lage == Lage.BAUEN:
        _fuehre_kegel(delta)

    _hud.stoss_ladung = stoss_ladung()
    _schwarm.queue_redraw()


## Fuehrt die Funkenbluete: treiben, brennen, vergehen.
##
## **Nur der Kegel oeffnet sie** - das Stosslicht laeuft durch sie hindurch.
## Ohne diese Regel waere die Entscheidung keine: man wartet, bis der Ring
## geladen ist, tippt, und bekommt sie geschenkt. Deshalb steht sie hier und
## nicht in `_stosslicht_fuehren()`.
func _bluete_fuehren(delta: float) -> void:
    if _bluete == null or not _bluete.lebendig:
        return
    _bluete.alter = _wellenzeit - _bluete.eintritt
    if _bluete.alter < 0.0:
        return
    if _bluete.vorbei(_bluete.alter):
        # Sie geht, und das ist kein Fehler - eine Gelegenheit, die man nicht
        # verpassen kann, ist keine.
        _bluete.lebendig = false
        _schwarm.bluete = null
        return

    if not _bluete_gesehen:
        # Einmal je Spielstand: was da treibt, erklaert sich nicht von selbst,
        # und beim zweiten Mal braucht es keine Erklaerung mehr.
        _bluete_gesehen = true
        _hud.melde("Sparkbloom - only the beam opens it")
    _bluete.ort = _bluete.ort_bei(_bluete.alter)
    _bluete.hitze = maxf(0.0, _bluete.hitze - delta * 2.4)
    # `_kegel` ist eine untypisierte Knotenreferenz, also ist jedes Feld daran
    # `Variant` - und ein Produkt daraus laesst sich nicht ableiten. Deshalb
    # steht der Typ hier von Hand.
    var hell: float = Schlund.beleuchtung(Graben.WAECHTER, _wirksam,
        _kegel.halbwinkel, _kegel.reichweite, _bluete.ort,
        _kegel.rand_kern, _kegel.tiefe_kern) * _kegel.schein
    _bluete.licht = hell
    var wirkung := Schlund.schaden_an(leistung(), hell, 0.0, 0.0)
    if wirkung <= 0.0:
        return

    _bluete.leben -= wirkung * delta
    _bluete.hitze = 1.0
    if _bluete.leben > 0.0:
        return

    # Aufgebrochen. Sie zahlt Punkte und Kette - keinen Naehrstoff.
    _bluete.lebendig = false
    _schwarm.bluete = null
    kette += Wellen.BLUETE_KETTE
    kette_hoechste = maxi(kette_hoechste, kette)
    Fortschritt.setze_ziel(Tagesziel.Ziel.KETTE, kette)
    _kette_zeit = Graben.KETTE_FENSTER
    punkte += int(round(float(Wellen.BLUETE_PUNKTE)
        * Graben.kette_faktor(kette)))
    _hud.setze_kette(kette, 1.0)
    _hud.blitze(Color(0.98, 0.84, 0.46), 0.5)
    _schuetteln = maxf(_schuetteln, 0.55)
    _funken.platzen(_bluete.ort, Color(1.0, 0.88, 0.52), 54.0)
    Klang.spiele(Klang.Ton.KAMMER, 1.35, 0.8)


## Ob das Stosslicht gerade bereit ist. Das HUD zeichnet daraus den Ladering.
func stoss_bereit() -> bool:
    return lage == Lage.WELLE and _stoss_kuehl <= 0.0


## Wie weit es geladen ist, 0 bis 1.
func stoss_ladung() -> float:
    if lage != Lage.WELLE:
        return 0.0
    return clampf(1.0 - _stoss_kuehl / Graben.STOSS_ABKUEHLUNG, 0.0, 1.0)


## Stoesst den Ring ab. Gibt zurueck, ob es geklappt hat.
func stosslicht() -> bool:
    if not stoss_bereit():
        return false
    _stoss_kuehl = Graben.STOSS_ABKUEHLUNG
    _stoss_weit = 0.0
    _stoss_nr += 1
    _schuetteln = maxf(_schuetteln, 0.7)
    _waechter.feuer()
    _funken.platzen(Graben.WAECHTER, Color(0.72, 0.98, 1.0), 46.0)
    Klang.spiele(Klang.Ton.WELLE, 0.7, 0.9)
    Tastsinn.gib(Tastsinn.Art.STOSS)
    _einstieg_weiter(3)
    return true


## Laesst den Ring nach aussen laufen und rechnet ab, was er kreuzt.
##
## **Der Schaden kommt aus derselben `Schlund.schaden_an()` wie der Kegel** -
## bei voller Helligkeit, weil der Stoss aus dem Waechter selbst kommt. Panzer
## zieht also ab, eine Glutqualle nimmt ihn ganz, und ein Spiegler wirft ihn
## bis auf den Rest zurueck. Dieselben Regeln, ein anderer Weg; eine zweite
## Schadensrechnung waere eine zweite Wahrheit.
func _stosslicht_fuehren(delta: float) -> void:
    _stoss_kuehl = maxf(0.0, _stoss_kuehl - delta)
    if _stoss_weit < 0.0:
        return

    var vorher := _stoss_weit
    _stoss_weit += Graben.STOSS_TEMPO * delta
    var bruch := Fortschritt.stand.panzerbruch()
    var nachlass := Fortschritt.stand.schwellen_nachlass()

    for r in _tiere:
        if not r.lebendig or r.alter < 0.0 or r.stoss_nr == _stoss_nr:
            continue
        var weit := r.ort.distance_to(Graben.WAECHTER)
        if weit > _stoss_weit or weit <= vorher:
            continue
        r.stoss_nr = _stoss_nr
        var wirkung := Schlund.schaden_an(leistung(), 1.0,
            Wellen.panzer_in(r.art, r.welle) * (1.0 - bruch),
            maxf(0.0, Wellen.mindest_licht_in(r.art, r.welle) - nachlass),
            Wellen.hoechst_licht_in(r.art, r.welle))
        r.leben -= wirkung * Graben.STOSS_WERT
        r.hitze = 1.0
        _funken.zerfall(r.ort, Arten.farbe(r.art),
            Wellen.radius_in(r.art, r.welle) * 0.4, r.richtung)

    if _stoss_weit > _kegel.reichweite:
        _stoss_weit = -1.0
    _waechter.stoss_weit = _stoss_weit


## Fuehrt den Kegel dem Finger nach und legt die Regeln des Abschnitts an.
##
## `_richtung` ist, wohin der Spieler zielt. `_wirksam` ist, wo das Licht
## tatsaechlich hinfaellt - dazwischen liegt die Stroemung. Beide auseinander
## zu halten ist der ganze Reiz von Abschnitt 2: man zielt nicht dorthin, wo
## man treffen will.
func _fuehre_kegel(delta: float) -> void:
    var stand: KolonieStand = Fortschritt.stand
    var soll := Schlund.zielrichtung(Graben.WAECHTER, _finger, _richtung)
    _richtung = Schlund.gedreht(_richtung, soll, stand.drehtempo(), delta)

    var abtrieb := Regeln.stroemung(welle_nummer, _wellenzeit) * stand.stroemung_faktor()
    _wirksam = _richtung.rotated(abtrieb)
    _kegel.richtung = _wirksam
    _kegel.rand_kern = Regeln.rand_kern(welle_nummer)
    _kegel.tiefe_kern = Regeln.tiefe_kern(welle_nummer)
    _kegel.schein = Regeln.helligkeit(welle_nummer, _wellenzeit)


func _bewege(delta: float) -> void:
    for r in _tiere:
        if not r.lebendig:
            continue
        r.alter = _wellenzeit - r.eintritt
        if r.alter < 0.0:
            continue

        var art := Arten.art(r.art)
        var vorher := r.ort
        r.ort = Schlund.bahn(Vector2(r.start_x, Graben.EINTRITT_Y), Graben.BRUT_Y,
            Wellen.tempo_in(r.art, r.welle), art[&"schlaengel"], art[&"takt"],
            r.phase, r.alter,
            Wellen.drift_in(r.art, r.welle), Wellen.stoss_in(r.art, r.welle))

        var weg := r.ort - vorher
        if weg.length_squared() > 0.0001:
            r.richtung = weg.normalized()

        if r.art == Arten.Art.GRABNATTER:
            r.rueckweg.clear()
            for k in NATTER_GLIEDER:
                var t := maxf(0.0, r.alter - float(k + 1) * NATTER_ABSTAND)
                r.rueckweg.append(Schlund.bahn(
                    Vector2(r.start_x, Graben.EINTRITT_Y), Graben.BRUT_Y,
                    Wellen.tempo_in(r.art, r.welle), art[&"schlaengel"],
                    art[&"takt"], r.phase, t,
                    Wellen.drift_in(r.art, r.welle),
                    Wellen.stoss_in(r.art, r.welle)))

        r.hitze = maxf(0.0, r.hitze - delta * HITZE_ABKLINGEN)


func _verbrenne(delta: float) -> void:
    # Erst die Helligkeit aller Lebenden sammeln, dann entscheiden lassen, wen
    # der Kegel fasst - Wort fuer Wort dieselbe Reihenfolge wie im Pruefer.
    var sichtbar: Array[Raeuber] = []
    var hell := PackedFloat32Array()
    for r in _tiere:
        if not r.lebendig or r.alter < 0.0:
            continue
        sichtbar.append(r)
        # Ausgeschriebener Typ, nicht `:=`. `_kegel.schein` ist untypisiert
        # (der Knoten ist ein Node2D), damit hat das Produkt keinen Typ, und
        # GDScript bricht die ganze Datei mit einem Parse-Fehler ab - der im
        # Testlauf nicht auffaellt, weil der `wache.gd` nie laedt.
        var h: float = Schlund.beleuchtung(Graben.WAECHTER, _wirksam,
            _kegel.halbwinkel, _kegel.reichweite, r.ort,
            _kegel.rand_kern, _kegel.tiefe_kern) * _kegel.schein
        # Fuer das Randlicht beim Zeichnen. Es ist dieselbe Zahl, die gleich
        # den Schaden bestimmt - was hell aussieht, brennt auch.
        r.licht = h
        hell.append(h)

    # Nachglut (Brutlinie): wer getroffen wurde, brennt kurz weiter. Das
    # belohnt Ueberstreichen statt Verweilen - eine andere Handbewegung, nicht
    # nur eine groessere Zahl.
    var glut_dauer := Fortschritt.stand.nachglut_dauer()
    if glut_dauer > 0.0:
        var glut := leistung() * Fortschritt.stand.nachglut_anteil()
        for r in sichtbar:
            if r.glut > 0.0:
                r.glut = maxf(0.0, r.glut - delta)
                r.leben -= maxf(0.0, glut - Wellen.panzer_in(r.art, r.welle)) * delta
                r.hitze = maxf(r.hitze, 0.35)

    # **Erst die Wirkung, dann die Auswahl.** `brennende()` bekommt nicht mehr
    # die Helligkeit, sondern was das Tier davon tatsaechlich abbekommt -
    # sonst belegt ein Tier, das gerade gar nicht brennen kann, einen der
    # wenigen Zielplaetze. Siehe `Schlund.brennende()`.
    # Was die getragene Brutlinie an den Werten des Raeubers aendert. Beides
    # einmal je Bild geholt und nicht je Tier - `Fortschritt.stand` ist ein
    # Autoload-Zugriff, und hier stehen bis zu zweihundert Tiere.
    var bruch := Fortschritt.stand.panzerbruch()
    var nachlass := Fortschritt.stand.schwellen_nachlass()

    var wirkung := PackedFloat32Array()
    wirkung.resize(sichtbar.size())
    for i in sichtbar.size():
        var t := sichtbar[i]
        # Salzbrand frisst den Panzer, Zwielicht nimmt den Schwellen die
        # Schaerfe: die Mindesthelligkeit sinkt, die Obergrenze steigt.
        var hoechst := Wellen.hoechst_licht_in(t.art, t.welle)
        if hoechst > 0.0:
            hoechst = minf(1.0, hoechst + nachlass)
        wirkung[i] = Schlund.schaden_an(leistung(), hell[i],
            Wellen.panzer_in(t.art, t.welle) * (1.0 - bruch),
            maxf(0.0, Wellen.mindest_licht_in(t.art, t.welle) - nachlass),
            hoechst)

    for i in Schlund.brennende(wirkung, ziele()):
        var r := sichtbar[i]
        r.leben -= wirkung[i] * delta
        r.hitze = 1.0
        r.glut = glut_dauer
        if randf() < hell[i] * delta * 26.0:
            _funken.strahl(Graben.WAECHTER, r.ort, Arten.farbe(r.art))
            # Die Tonhoehe steigt, solange man dranbleibt, und faellt beim
            # Abrutschen. Das ist die einzige Rueckmeldung, die man auch mit
            # dem Daumen auf dem Bildschirm noch mitbekommt.
            Klang.spiele(Klang.Ton.TREFFER, 0.8 + _folge * 0.02, 0.28)


func _polypen_feuern(delta: float) -> void:
    for n in polypen.size():
        _polyp_takt[n] = maxf(0.0, _polyp_takt[n] - delta)
        for r in _tiere:
            if not r.lebendig or r.alter < 0.0:
                continue
            if r.ort.distance_to(polypen[n]) > Graben.POLYP_REICHWEITE:
                continue
            # Der Panzer gilt auch hier - genau das macht ihn aus: ein
            # Wehrpolyp kratzt an einer Schildkoralle kaum noch.
            r.leben -= maxf(0.0, Fortschritt.stand.polyp_leistung()
                - Wellen.panzer_in(r.art, r.welle)) * delta
            r.hitze = maxf(r.hitze, 0.45)
            if _polyp_takt[n] <= 0.0:
                _polyp_takt[n] = 0.22
                _funken.strahl(polypen[n], r.ort, Color(0.52, 0.94, 0.80))
            break


func _raeume_auf() -> void:
    for r in _tiere:
        if not r.lebendig or r.alter < 0.0:
            continue
        if r.leben <= 0.0:
            r.lebendig = false
            _offen -= 1
            var lohn := Tagesstroemung.ausbeute(
                Wellen.wert_in(r.art, welle_nummer), _stroemung)
            Fortschritt.aendere(lohn)
            verdient += lohn
            _funken.zerfall(r.ort, Arten.farbe(r.art), Wellen.radius_in(r.art, r.welle),
                r.richtung)
            _hud.zeige_ausbeute(r.ort, lohn)

            # Die Kette: jeder Abschuss innerhalb des Fensters verlaengert
            # sie. Punkte fallen mit ihrem Faktor an - Naehrstoff nicht, denn
            # die Wirtschaft ist aus den Kammerkosten abgeleitet und vertraegt
            # keinen Multiplikator, der am Koennen haengt.
            kette += 1
            kette_hoechste = maxi(kette_hoechste, kette)
            Fortschritt.setze_ziel(Tagesziel.Ziel.KETTE, kette)
            _kette_zeit = Graben.KETTE_FENSTER
            punkte += int(round(float(Wellen.wert_in(r.art, welle_nummer))
                * Graben.kette_faktor(kette)))
            _hud.setze_kette(kette, 1.0)
            if kette >= Graben.KETTE_AB and kette % 5 == 0:
                _funken.platzen(r.ort, Color(0.72, 1.0, 0.92), 24.0)
                _schuetteln = maxf(_schuetteln, 0.35)

            _folge = minf(24.0, _folge + 1.0)
            Fortschritt.melde_ziel(Tagesziel.Ziel.RAEUBER)
            erlegt += 1
            _einstieg_weiter(2)
            Klang.spiele(Klang.Ton.TOD, 0.82 + _folge * 0.025, 0.5)
            _waechter.feuer()

            # Ein Leitwesen ist der Hoehepunkt eines Abschnitts, und ein
            # Hoehepunkt braucht einen Augenblick, in dem die Zeit stehen
            # bleibt. Bei einem gewoehnlichen Raeuber waere dasselbe ein
            # Ruckeln - deshalb nur hier.
            if Arten.ist_leitwesen(r.art):
                _zeitlupe = ZEITLUPE_DAUER
                _schuetteln = maxf(_schuetteln, 1.1)
                _hud.blitze(Color(0.62, 0.98, 0.86), 0.7)
                Tastsinn.gib(Tastsinn.Art.LEITWESEN)
        elif r.ort.y >= Graben.BRUT_Y - 0.5:
            r.lebendig = false
            _offen -= 1
            var vorher := brut
            if not _brut_unverwundbar:
                brut = maxi(0, brut - Arten.wucht(r.art))
            _schuetteln = 0.8 + 0.3 * float(vorher - brut)
            # Ein Treffer an der Brut bricht die Kette. Das ist der Preis, der
            # sie zur Spannung macht: sonst waere sie eine Zahl, die nur
            # steigt.
            kette = 0
            _kette_zeit = 0.0
            _hud.setze_kette(0, 0.0)
            _folge = 0.0
            Klang.spiele(Klang.Ton.BRUT_FAELLT, 1.0, 0.85)
            # Der eine Augenblick, in dem das Spiel wehtun soll - und der
            # einzige, den man auch dann mitbekommt, wenn der Ton aus ist.
            Tastsinn.gib(Tastsinn.Art.TREFFER)
            # Der Waechter zuckt, und das Bild bekommt einen roten Rand. Wer
            # den Daumen auf der unteren Bildhaelfte hat, sieht von der Brut
            # nichts - dann ist der Rand die einzige Nachricht, die ankommt.
            _waechter.zucke(vorher - brut)
            _hud.blitze(Color(1.0, 0.38, 0.30), 0.55)
            _funken.platzen(r.ort, Color(1.0, 0.42, 0.34),
                Wellen.radius_in(r.art, r.welle) * 1.6)
            # Und je zerbrochenem Ei ein eigener Bruch an seiner Stelle. Ein
            # Treffer an der Brut ist das Teuerste im Spiel; er darf nicht
            # aussehen wie ein Treffer an einem Raeuber.
            for k in range(brut, vorher):
                _funken.ei_zerbricht(_ei_ort(k), Color(0.98, 0.80, 0.42))
            _aktualisiere_kolonie()
            if brut <= 0:
                _verloren()
                return
    _hud.setze_zahlen(brut, Fortschritt.stand.naehrstoffe, _offen)


## Wo das Ei mit dieser Nummer liegt.
##
## **Die Rechnung stand einmal hier und noch einmal in `kolonie.gd`**, mit
## einem Kommentar, der auf die andere Stelle verwies. Genau dieser Kommentar
## ist der Beweis, dass es zwei Beschreibungen derselben Sache waren: als das
## Gelege von einer Reihe auf gestaffelte Reihen umgestellt wurde, waeren die
## Bruchstuecke woanders entstanden als das Ei lag. Jetzt gibt es eine
## Rechnung, und sie steht in der Datenschicht.
func _ei_ort(index: int) -> Vector2:
    return Graben.ei_ort(index, Fortschritt.stand.brut_leben())


## Faerbt Wasser und Fels nach dem Abschnitt ein.
##
## Sechs Abschnitte, die sich unterschiedlich spielen und identisch aussahen -
## damit fuehlte sich Welle 55 an wie Welle 5 mit mehr Tieren. Die Farben
## stehen in `Regeln`, weil dort auch steht, was der Abschnitt *tut*: die
## Truebe Tiefe ist wirklich truebe, das Finsterband wirklich finster.
##
## `sofort` setzt hart, sonst wird ueberblendet - ein Farbsprung mitten im
## Spiel sieht aus wie ein Fehler, ein langsamer Wechsel wie ein Abstieg.
func _faerbe_abschnitt(abschnitt: int, sofort := false) -> void:
    if sofort:
        _alt_abschnitt = abschnitt
        _ziel_abschnitt = abschnitt
        _farbmischung = 1.0
        _schiebe_farben(1.0)
        return
    if abschnitt == _ziel_abschnitt:
        return

    # Von dort weiter, wo die Ueberblendung gerade steht. Erst wurde
    # `_ziel_abschnitt` oben gesetzt und dann als Startpunkt genommen - damit
    # war Start gleich Ziel und die Ueberblendung hatte kein Von.
    _alt_abschnitt = _ziel_abschnitt if _farbmischung >= 1.0 else _alt_abschnitt
    _ziel_abschnitt = abschnitt
    _farbmischung = 0.0
    _vordergrund.abstieg()


func _schiebe_farben(anteil: float) -> void:
    var stoff := _wasser.material as ShaderMaterial
    if stoff == null:
        return
    var a := _alt_abschnitt
    var b := _ziel_abschnitt
    stoff.set_shader_parameter("tief",
        Regeln.tief_farbe(a).lerp(Regeln.tief_farbe(b), anteil))
    stoff.set_shader_parameter("grund",
        Regeln.grund_farbe(a).lerp(Regeln.grund_farbe(b), anteil))
    stoff.set_shader_parameter("schein",
        Regeln.schein_farbe(a).lerp(Regeln.schein_farbe(b), anteil))
    stoff.set_shader_parameter("schnee_dichte",
        lerpf(Regeln.schnee_dichte(a), Regeln.schnee_dichte(b), anteil))
    stoff.set_shader_parameter("saeulen",
        lerpf(Regeln.saeulen(a), Regeln.saeulen(b), anteil))
    stoff.set_shader_parameter("enge",
        lerpf(Regeln.enge(a), Regeln.enge(b), anteil))
    _kolonie.fels = Regeln.fels_farbe(a).lerp(Regeln.fels_farbe(b), anteil)


## Staub und Vordergrund weichen zurueck, wenn das Bild voll wird.
##
## Dieselbe Regel wie bei den Zeichenstufen im Schwarm: Stimmung ist das
## Erste, was geht, und die Raeuber sind das Letzte. Ein Bild, in dem man den
## naechsten Gegner nicht mehr findet, ist kein schoenes Bild.
## **`delta` kommt als Wert herein und wird nicht von der Uhr geholt.**
##
## Hier stand `get_process_delta_time()`. Im laufenden Spiel ist das dasselbe,
## im Vorlauf einer Aufnahme aber nicht: `_nimm_auf()` ruft `_process()` mit
## festem Takt auf, damit dasselbe Bild entsteht, egal wie schnell der Rechner
## ist - die Uhr weiss davon nichts. Die Farbueberblendung stand deshalb
## still, und **jedes** Abschnittsbild zeigte die Farben von Abschnitt 0.
##
## Gemerkt habe ich es beim Nachmessen: Grabensturm sollte eisenrot sein
## (0.044, 0.026, 0.024) und kam als dasselbe Blau heraus wie die
## Randschlucht. Eine Farbe, die es in den Konstanten gibt und im Bild nicht,
## ist derselbe Fehler wie ein Dunst, der so hell ist wie sein Fels.
func _stimmung_nachfuehren(delta: float) -> void:
    if _farbmischung < 1.0:
        _farbmischung = minf(1.0, _farbmischung + delta * 0.55)
        _schiebe_farben(_farbmischung)

    var lebende := 0
    for r in _tiere:
        if r.lebendig and r.alter >= 0.0:
            lebende += 1
    var anteil := clampf(1.0 - float(lebende) / 110.0, 0.22, 1.0)
    _kegel.staub_anteil = anteil
    _vordergrund.staerke = anteil


# --- Uebergaenge -----------------------------------------------------------

func _welle_geschafft() -> void:
    Fortschritt.melde_ziel(Tagesziel.Ziel.WELLEN)
    _einstieg_weiter(4)
    Fortschritt.merke_welle(welle_nummer + 1)
    # Der Graben gibt nur her, was der Tiefenschacht geoeffnet hat. Wer am
    # Ende des Abschnitts steht, spielt ihn weiter - und erfaehrt, woran es
    # liegt. Eine Wand ohne Grund ist ein Fehler; eine mit Grund ist ein Ziel.
    var stand: KolonieStand = Fortschritt.stand
    if welle_nummer + 1 > stand.offene_welle():
        # `naechste_tiefe()` gibt 0 zurueck, wenn gar nichts mehr verschlossen
        # ist. Dann liegt es nicht am Schacht, und "level 0 digs on" waere
        # eine Wand mit einem falschen Grund - schlimmer als eine ohne.
        var tiefe := stand.naechste_tiefe()
        _hud.melde("The trench ends here - deep shaft level %d digs on" % tiefe
            if tiefe > 0 else "You have reached the bottom of the trench")
        welle_in_sitzung = 0
        _bereite_welle_vor()
        return

    # Eine volle Umdrehung durch den Graben ist der groessere Moment und
    # bekommt den groesseren Bildschirm. Er stand hier einmal fuer das Ende
    # des Spiels - seit der Graben keinen Boden hat, ist er kein Ende mehr,
    # sondern eine Marke: sechzig Wellen tiefer, und der naechste Abstieg
    # faengt oben wieder an, nur haerter.
    var abgeschlossen := welle_nummer
    welle_nummer += 1
    if abgeschlossen % Graben.ZYKLUS == 0:
        lage = Lage.GESCHAFFT
        _hud.zeige_ende(true, abgeschlossen, verdient, erlegt, punkte,
            _bestmarke_setzen())
        return
    if welle_in_sitzung >= Graben.WELLEN_JE_SITZUNG:
        lage = Lage.SITZUNG_ENDE
        Tastsinn.gib(Tastsinn.Art.ENDE)
        _einstieg_weiter(8)
        _hud.zeige_sitzungsende(welle_nummer, verdient, erlegt, punkte,
            _bestmarke_setzen())
        return
    _bereite_welle_vor()


func _verloren() -> void:
    lage = Lage.VERLOREN
    _schuetteln = 1.6
    Tastsinn.gib(Tastsinn.Art.ENDE)
    _hud.zeige_ende(false, welle_nummer, verdient, erlegt, punkte,
        _bestmarke_setzen())


## Nach einem Fall: die Sitzung beginnt neu, die Kolonie bleibt.
##
## Das ist die Zusage aus dem Konzept - der Fortschritt der Sitzung geht
## verloren, der Koloniefortschritt nicht. Ohne sie waere jede Niederlage ein
## Grund, das Spiel zu loeschen.
func neu_anfangen() -> void:
    brut = Fortschritt.stand.brut_leben()
    verdient = 0
    erlegt = 0
    punkte = 0
    kette = 0
    kette_hoechste = 0
    polypen.clear()
    welle_in_sitzung = 0
    welle_nummer = Fortschritt.stand.naechste_welle()
    Fortschritt.sichere()
    _bereite_welle_vor()


# --- Bauen -----------------------------------------------------------------

func baue_polyp(nische: int) -> bool:
    if lage != Lage.BAUEN:
        return false
    if nische < 0 or nische >= Graben.NISCHEN.size():
        return false
    var ort := Graben.NISCHEN[nische]
    if polypen.has(ort):
        return false
    var preis := Fortschritt.stand.polyp_kosten(polypen.size())
    if Fortschritt.stand.naehrstoffe < preis:
        return false
    Fortschritt.aendere(-preis)
    polypen.append(ort)
    _funken.platzen(ort, Color(0.52, 0.94, 0.80), 20.0)
    Klang.spiele(Klang.Ton.POLYP)
    _einstieg_weiter(5)
    _aktualisiere_kolonie()
    _hud.zeige_bauphase(welle_nummer, brut, Fortschritt.stand.naehrstoffe,
        Fortschritt.stand.polyp_kosten(polypen.size()), polypen.size())
    return true


## Welche Nische unter dem Finger liegt, oder -1.
func nische_bei(punkt: Vector2) -> int:
    for i in Graben.NISCHEN.size():
        if Graben.NISCHEN[i].distance_to(punkt) <= Graben.POLYP_RADIUS * 2.6:
            return i
    return -1


func _aktualisiere_kolonie() -> void:
    _kolonie.polypen = polypen
    _kolonie.brut = brut
    _kolonie.brut_voll = Fortschritt.stand.brut_leben()
    _kolonie.naehrstoffe = Fortschritt.stand.naehrstoffe
    _kolonie.bauphase = lage == Lage.BAUEN
    _kolonie.queue_redraw()


# --- Pause -----------------------------------------------------------------
#
# **Zurueck aus der Tasche heisst nicht mitten in die Welle.** Selbst mit
# gedeckeltem Rechenschritt waere es unfair, jemanden ohne Vorwarnung in
# fallende Raeuber zu setzen: er hat das Telefon weggelegt, nicht aufgegeben.
# Also haelt das Spiel an, sobald Android die App pausiert, und wartet auf
# eine Beruehrung.

var _vor_pause := Lage.BAUEN

## Nur fuer `--stau`: die Brut nimmt keinen Schaden.
##
## **Vorher wurde dafuer `brut = 1000000` gesetzt**, und in der Kopfzeile
## stand dann "999997 / 44". Fuer eine Bildratenmessung ist das gleichgueltig,
## fuer ein Ladenbild ist es ein Ausschlusskriterium: Google verlangt, dass
## Werbematerial das Spiel zeigt, das man bekommt. Eine Zahl, die es im Spiel
## nicht gibt, gehoert nicht auf einen Screenshot - und eine Anzeige zu
## faelschen, um eine Wirkung zu erreichen, ist ohnehin der falsche Weg. Die
## Wirkung war "die Brut soll nicht fallen"; also wird genau das gesagt.
var _brut_unverwundbar := false


func pausiere() -> void:
    if lage != Lage.WELLE and lage != Lage.BAUEN:
        return
    _vor_pause = lage
    lage = Lage.PAUSE
    _zieht = false
    Engine.time_scale = 1.0
    Fortschritt.sichere()
    _hud.zeige_pause(true)


func weiter() -> void:
    if lage != Lage.PAUSE:
        return
    lage = _vor_pause
    _hud.zeige_pause(false)


## Android meldet Hintergrund und Zurueck-Taste hierher.
##
## `quit_on_go_back` steht in `project.godot` auf false - sonst beendet Godot
## die App beim ersten Druck auf Zurueck, und zwar mitten in der Welle. Die
## Taste tut jetzt das, was sie ueberall sonst tut: eine Ebene zurueck.
func _notification(was: int) -> void:
    match was:
        NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
            pausiere()
        NOTIFICATION_WM_GO_BACK_REQUEST:
            if _koloniebild.sichtbar():
                _koloniebild.schliesse()
            else:
                pausiere()


# --- Eingabe ---------------------------------------------------------------

func _unhandled_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventScreenTouch:
        _beruehrung(ereignis.pressed, _welt(ereignis.position))
    elif ereignis is InputEventScreenDrag:
        _finger = _welt(ereignis.position)
        _einstieg_weiter(1)
    elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
        _beruehrung(ereignis.pressed, _welt(ereignis.position))
    elif ereignis is InputEventMouseMotion and _zieht:
        _finger = _welt(ereignis.position)
        _einstieg_weiter(1)


func _beruehrung(gedrueckt: bool, ort: Vector2) -> void:
    _zieht = gedrueckt
    if not gedrueckt:
        return
    _finger = ort

    # Die Rueckkehrtafel liegt ueber allem und hat genau einen Ausgang.
    # Solange sie steht, darf kein Tipp dahinter ankommen - sonst startet
    # der erste Griff nach dem Aufwachen die Welle.
    if _hud.rueckkehr_offen():
        if _hud.rueckkehrknopf_bei(_bildschirm(ort)):
            Klang.spiele(Klang.Ton.TIPP)
            _hud.schliesse_rueckkehr()
        return

    match lage:
        Lage.PAUSE:
            weiter()
        Lage.BAUEN:
            if _hud.kolonieknopf_bei(_bildschirm(ort)):
                Klang.spiele(Klang.Ton.TIPP)
                oeffne_kolonie()
                return
            if _hud.wellenknopf_bei(_bildschirm(ort)):
                Klang.spiele(Klang.Ton.TIPP)
                starte_welle()
                return
            var n := nische_bei(ort)
            if n >= 0:
                baue_polyp(n)
        Lage.VERLOREN, Lage.GESCHAFFT, Lage.SITZUNG_ENDE:
            # **Zwei Ausgaenge, nicht einer.** Ein Tipp irgendwohin startete
            # sofort den naechsten Versuch - und der nuetzliche Weg nach
            # einem Fall ist der Ausbau, nicht die Wiederholung.
            var schirm := _bildschirm(ort)
            if _hud.kolonieknopf_bei(schirm):
                Klang.spiele(Klang.Ton.TIPP)
                oeffne_kolonie()
            elif _hud.wellenknopf_bei(schirm):
                Klang.spiele(Klang.Ton.TIPP)
                neu_anfangen()


func _welt(bildschirm: Vector2) -> Vector2:
    return get_canvas_transform().affine_inverse() * bildschirm


func _bildschirm(welt: Vector2) -> Vector2:
    return get_canvas_transform() * welt


# --- Entwicklerschalter ----------------------------------------------------
#
# Wie bei HYPHA: Bilder werden aufgenommen, nicht beschrieben. Siehe CLAUDE.md.

func _lies_entwicklerschalter() -> void:
    var argumente := OS.get_cmdline_user_args()
    var bild := ""
    var vorlauf := 0.0
    var bauen := false
    var messen := 0.0
    var stau := false
    var halt := false
    var welle := 0
    var polypenzahl := 0
    var reiter := -1
    var endschirm := -1
    var stufen := -1
    var lehre := -1
    var stoss_bei := -1.0

    for i in argumente.size():
        match argumente[i]:
            "--schuss":
                if i + 1 < argumente.size():
                    bild = argumente[i + 1]
            "--welle":
                if i + 1 < argumente.size():
                    welle = int(argumente[i + 1])
            "--zeit":
                if i + 1 < argumente.size():
                    vorlauf = float(argumente[i + 1])
            "--polypen":
                if i + 1 < argumente.size():
                    polypenzahl = int(argumente[i + 1])
            "--bauen":
                bauen = true
            "--endschirm":
                # Die drei Schlussbilder lassen sich sonst nur erspielen.
                # 0 gefallen, 1 Sitzung gehalten, 2 Graben durchgestanden.
                endschirm = int(argumente[i + 1]) if i + 1 < argumente.size() else 0
            "--stufen":
                # Alle Kammern auf diese Stufe. Der Koloniebildschirm sieht
                # bei Stufe 0 anders aus als bei 14, und beides muss sich
                # ansehen lassen, ohne es zu erspielen.
                stufen = int(argumente[i + 1]) if i + 1 < argumente.size() else 0
            "--kolonie":
                # Auch der Koloniebildschirm muss sich ansehen lassen, ohne
                # ihn von Hand aufzutippen. 0 Kammern, 1 Linien, 2 Arten,
                # 3 Zuege, 4 Tag.
                reiter = int(argumente[i + 1]) if i + 1 < argumente.size() else 0
            "--messen":
                if i + 1 < argumente.size():
                    messen = float(argumente[i + 1])
            "--stau":
                stau = true
            "--lehre":
                # Der Lehrpfad laeuft genau einmal je Spielstand. Ohne
                # Schalter liesse sich Schritt 6 nur ansehen, indem man die
                # fuenf davor noch einmal spielt - und ein Bild, das man
                # nicht nachpruefen kann, ist ein Bild, das schief steht.
                lehre = int(argumente[i + 1]) if i + 1 < argumente.size() else 0
            "--heim":
                # Die Rueckkehrtafel zeigt sich nur nach einer echten Pause
                # von Stunden. Ohne Schalter muesste man das Spiel schliessen,
                # die Systemuhr stellen und zurueckkommen.
                _hud.zeige_rueckkehr({
                    &"ertrag": 12480, &"stunden": 6.2,
                    &"kammer": Kammern.Kammer.LEUCHTORGAN, &"tag": true,
                })
            "--stoss":
                stoss_bei = float(argumente[i + 1]) if i + 1 < argumente.size() else 0.3
            "--pause":
                # Die Pause laesst sich sonst nur ansehen, indem man die App
                # auf einem Telefon in den Hintergrund schiebt.
                halt = true

    if stufen >= 0:
        var st := clampi(stufen, 0, Kammern.HOECHSTSTUFE)
        for k in Kammern.zahl():
            Fortschritt.stand.stufen[k] = st
        Fortschritt.stand.hoechste_welle = Graben.ZYKLUS
        _stelle_ausbau_ein()

    if lehre >= 0:
        Fortschritt.stand.einstieg = lehre
        _zeige_einstieg()

    if welle > 0:
        welle_nummer = clampi(welle, 1, Graben.TIEFSTE)
    for p in mini(polypenzahl, Graben.NISCHEN.size()):
        polypen.append(Graben.NISCHEN[p])
    if welle > 0 or polypenzahl > 0:
        _bereite_welle_vor()

    if messen > 0.0:
        _miss_bildrate(messen, stau)
        return
    if endschirm >= 0:
        verdient = 1840
        erlegt = 214
        punkte = 38420
        match endschirm:
            1:
                lage = Lage.SITZUNG_ENDE
                _hud.zeige_sitzungsende(welle_nummer + 1, verdient, erlegt,
                    punkte, true)
            2:
                lage = Lage.GESCHAFFT
                _hud.zeige_ende(true, Graben.ZYKLUS * 2, verdient, erlegt,
                    punkte, true)
            _:
                lage = Lage.VERLOREN
                _hud.zeige_ende(false, welle_nummer, verdient, erlegt, punkte,
        _bestmarke_setzen())
    if bild.is_empty():
        if reiter >= 0:
            oeffne_kolonie()
            _koloniebild.zeige_reiter(reiter)
        return
    _nimm_auf(bild, vorlauf, bauen or endschirm >= 0, reiter, stau, halt,
        stoss_bei)


## Misst die tatsaechliche Bildrate ueber `dauer` Sekunden.
##
## **Was diese Messung kann und was nicht.** Hier rendert xvfb in Software, es
## gibt keine Grafikkarte - die absolute Bildrate sagt also nichts ueber ein
## Telefon aus. Was sie sehr wohl sagt, ist die **Kosten je Raeuber**: waechst
## die Bildzeit linear und flach, traegt der Entwurf; explodiert sie, ist es
## auf jeder Hardware ein Problem.
##
## Mit `--stau` faellt kein Raeuber, damit sich eine feste Zahl ansammelt und
## verschiedene Laeufe vergleichbar sind.
func _miss_bildrate(dauer: float, stau: bool) -> void:
    starte_welle()
    _finger = Graben.WAECHTER + Vector2(-70.0, -520.0)
    if stau:
        # Kegel aus dem Feld drehen und die Brut unverwundbar machen. Ohne
        # beides endete die Messung, bevor sich etwas angesammelt hatte: die
        # Raeuber erreichten die Brut, die Brut fiel, die Welle war vorbei.
        _finger = Graben.WAECHTER + Vector2(0.0, 400.0)
        _brut_unverwundbar = true

    var takt := 1.0 / 60.0
    for _i in int(20.0 / takt):
        if lage != Lage.WELLE:
            break
        _process(takt)

    var lebende := 0
    for r in _tiere:
        if r.lebendig and r.alter >= 0.0:
            lebende += 1

    var bilder := 0
    var schlimmstes := 0.0
    var beginn := Time.get_ticks_usec()
    var letztes := beginn
    while float(Time.get_ticks_usec() - beginn) / 1e6 < dauer:
        await RenderingServer.frame_post_draw
        var jetzt := Time.get_ticks_usec()
        var schritt := float(jetzt - letztes) / 1e6
        letztes = jetzt
        bilder += 1
        if bilder > 5:
            schlimmstes = maxf(schlimmstes, schritt)

    var verstrichen := float(Time.get_ticks_usec() - beginn) / 1e6
    print("Welle %d: %d Raeuber im Bild, %.1f Bilder/s, schlimmstes Bild %.1f ms"
        % [welle_nummer, lebende, float(bilder) / verstrichen, schlimmstes * 1000.0])
    get_tree().quit()


## `--stau` gilt hier wie bei der Bildratenmessung: der Kegel wird aus dem
## Feld gedreht und die Brut unverwundbar gemacht, damit sich die Welle
## ansammelt.
##
## **Ohne das laesst sich kein Raeuber ansehen.** Der Finger steht im Vorlauf
## fest ueber dem Schlund, und der Kegel raeumt in spaeten Wellen alles weg,
## was eintritt: ein Bild von Welle 30 nach sechs Sekunden zeigte zwanzig
## verbleibende Tiere in der Anzeige und kein einziges im Bild. Wer die Tiere
## zeichnet, muss sie sehen koennen.
## `stoss_bei` stoesst das Stosslicht so viele Sekunden vor dem Bild ab. Ohne
## das laesst sich der Ring nicht ansehen: er ist eine halbe Sekunde
## unterwegs und haengt an einer Beruehrung, die es in einer Aufnahme nicht
## gibt.
func _nimm_auf(datei: String, vorlauf: float, bauen: bool, reiter := -1,
        stau := false, halt := false, stoss_bei := -1.0) -> void:
    if not bauen:
        starte_welle()
        _finger = Graben.WAECHTER + Vector2(-70.0, -520.0)
        if stau:
            _finger = Graben.WAECHTER + Vector2(0.0, 400.0)
            _brut_unverwundbar = true
        # Im Vorlauf mit festem Takt rechnen, damit dasselbe Bild entsteht,
        # egal wie schnell der Rechner ist.
        var takt := 1.0 / 60.0
        var schritte := int(vorlauf / takt)
        var stoss_schritt := -1
        if stoss_bei >= 0.0:
            stoss_schritt = maxi(0, schritte - int(stoss_bei / takt))
        for i in schritte:
            if lage != Lage.WELLE:
                break
            if i == stoss_schritt:
                stosslicht()
            _process(takt)

    if halt:
        pausiere()

    # Der Koloniebildschirm **nach** der Welle: so steht im Bestiarium, was
    # gerade aufgetreten ist, statt einer Liste aus lauter Fragezeichen.
    if reiter >= 0:
        lage = Lage.BAUEN
        oeffne_kolonie()
        _koloniebild.zeige_reiter(reiter)
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var bildchen := get_viewport().get_texture().get_image()
    bildchen.save_png(datei)
    print("Bild gespeichert: ", datei)
    get_tree().quit()
