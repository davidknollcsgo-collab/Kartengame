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

enum Lage { BAUEN, WELLE, VERLOREN, GESCHAFFT }

## Wie lange die Trefferanzeige eines Raeubers nachgluecht. Ohne Nachhall
## flackert sie bei jedem Schwenk, und man sieht nicht mehr, wen man fasst.
const HITZE_ABKLINGEN := 5.0

## Glieder der Grabnatter und ihr zeitlicher Abstand.
const NATTER_GLIEDER := 7
const NATTER_ABSTAND := 0.055

const SCHUETTELN_ABKLINGEN := 7.0


@onready var _kegel: Node2D = $Kegel
@onready var _schwarm: Node2D = $Schwarm
@onready var _kolonie: Node2D = $Kolonie
@onready var _funken: Node2D = $Funken
@onready var _kamera: Camera2D = $Kamera
@onready var _hud: CanvasLayer = $Hud
@onready var _koloniebild: CanvasLayer = $Koloniebild

var lage := Lage.BAUEN
var welle_nummer := 1
var brut := Graben.BRUT_LEBEN
var polypen: Array[Vector2] = []
var verdient := 0

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

## Ob die laufende Welle eine Tagesstroemung ist. Wird beim Start der Welle
## entschieden und verbraucht - nicht bei jedem Treffer neu gefragt, sonst
## koennte eine einzige Welle den ganzen Tagesvorrat aufzehren.
var _stroemung := false


func _ready() -> void:
    _koloniebild.geschlossen.connect(_kolonie_geschlossen)
    Fortschritt.stand_geaendert.connect(_stelle_ausbau_ein)
    Fortschritt.bau_fertig.connect(_bau_fertig)

    welle_nummer = Fortschritt.stand.naechste_welle()
    brut = Fortschritt.stand.brut_leben()
    var offline := Fortschritt.begruesse()
    _stelle_ausbau_ein()
    _bereite_welle_vor()
    if offline > 0:
        _hud.zeige_ausbeute(Graben.WAECHTER + Vector2(0.0, -70.0), offline)
    _zeige_einstieg()
    _lies_entwicklerschalter()


## Der Einstieg schreitet an Ereignissen fort, nicht an einer Uhr. Wer
## langsamer ist, bekommt mehr Zeit; wer es sofort versteht, wird nicht
## aufgehalten.
func _zeige_einstieg() -> void:
    _hud.zeige_einstieg(Fortschritt.stand.einstieg
        if Fortschritt.stand.einstieg < _hud.EINSTIEG.size() else -1)


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
    _hud.melde("%s fertig" % Kammern.name_von(kammer))

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
    _hud.zeige_bauphase(welle_nummer, brut, Fortschritt.stand.naehrstoffe,
        Fortschritt.stand.polyp_kosten(polypen.size()), polypen.size())


func oeffne_kolonie() -> void:
    if lage != Lage.BAUEN:
        return
    _hud.visible = false
    _einstieg_weiter(4)
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


func starte_welle() -> void:
    if lage != Lage.BAUEN:
        return
    _tiere.clear()
    for a in Wellen.auftritte(welle_nummer):
        var r := Raeuber.new()
        r.art = a[&"art"]
        r.eintritt = a[&"zeit"]
        r.start_x = a[&"x"]
        r.phase = a[&"phase"]
        r.leben_voll = Wellen.leben_in(r.art, welle_nummer)
        r.leben = r.leben_voll
        r.ort = Vector2(r.start_x, Graben.EINTRITT_Y)
        _tiere.append(r)

    _stroemung = Fortschritt.stand.nutze_stroemung()
    _hud.stroemung = _stroemung
    _offen = _tiere.size()
    _wellenzeit = 0.0
    _polyp_takt.resize(polypen.size())
    _polyp_takt.fill(0.0)
    _schwarm.tiere = _tiere
    lage = Lage.WELLE
    _folge = 0.0
    Klang.spiele(Klang.Ton.WELLE, 1.0, 0.55)
    _hud.zeige_welle(welle_nummer, brut, Fortschritt.stand.naehrstoffe, _tiere.size())
    if _stroemung:
        _hud.melde("Tagesstroemung - doppelte Ausbeute")

    # Eine neue Regel gehoert angekuendigt. Wer in Welle 31 ploetzlich im
    # Dunkeln steht und nicht weiss warum, haelt es fuer einen Fehler.
    var a := Graben.abschnitt(welle_nummer)
    if Regeln.neu_in(a) and welle_nummer == a * Graben.WELLEN_JE_ABSCHNITT + 1:
        _hud.zeige_abschnitt(a)


# --- Schleife --------------------------------------------------------------

func _process(delta: float) -> void:
    _schuetteln = maxf(0.0, _schuetteln - delta * SCHUETTELN_ABKLINGEN)
    _kamera.offset = Vector2(
        randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _schuetteln * 7.0

    if lage == Lage.WELLE:
        _fuehre_kegel(delta)
        _bewege(delta)
        _verbrenne(delta)
        _polypen_feuern(delta)
        _raeume_auf()
        _wellenzeit += delta
        _folge = maxf(0.0, _folge - delta * 6.0)
        if _offen <= 0:
            _welle_geschafft()
    elif lage == Lage.BAUEN:
        _fuehre_kegel(delta)

    _schwarm.queue_redraw()


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
            art[&"tempo"], art[&"schlaengel"], art[&"takt"], r.phase, r.alter)

        var weg := r.ort - vorher
        if weg.length_squared() > 0.0001:
            r.richtung = weg.normalized()

        if r.art == Arten.Art.GRABNATTER:
            r.rueckweg.clear()
            for k in NATTER_GLIEDER:
                var t := maxf(0.0, r.alter - float(k + 1) * NATTER_ABSTAND)
                r.rueckweg.append(Schlund.bahn(
                    Vector2(r.start_x, Graben.EINTRITT_Y), Graben.BRUT_Y,
                    art[&"tempo"], art[&"schlaengel"], art[&"takt"], r.phase, t))

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
        hell.append(Schlund.beleuchtung(Graben.WAECHTER, _wirksam,
            _kegel.halbwinkel, _kegel.reichweite, r.ort,
            _kegel.rand_kern, _kegel.tiefe_kern) * _kegel.schein)

    # Nachglut (Brutlinie): wer getroffen wurde, brennt kurz weiter. Das
    # belohnt Ueberstreichen statt Verweilen - eine andere Handbewegung, nicht
    # nur eine groessere Zahl.
    var glut_dauer := Fortschritt.stand.nachglut_dauer()
    if glut_dauer > 0.0:
        var glut := leistung() * Fortschritt.stand.nachglut_anteil() * delta
        for r in sichtbar:
            if r.glut > 0.0:
                r.glut = maxf(0.0, r.glut - delta)
                r.leben -= glut
                r.hitze = maxf(r.hitze, 0.35)

    for i in Schlund.brennende(hell, ziele()):
        var r := sichtbar[i]
        r.leben -= Schlund.schaden_je_sekunde(leistung(), hell[i]) * delta
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
            r.leben -= Fortschritt.stand.polyp_leistung() * delta
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
            _funken.platzen(r.ort, Arten.farbe(r.art), Arten.radius(r.art))
            _hud.zeige_ausbeute(r.ort, lohn)
            _folge = minf(24.0, _folge + 1.0)
            Fortschritt.melde_ziel(Tagesziel.Ziel.RAEUBER)
            _einstieg_weiter(1)
            Klang.spiele(Klang.Ton.TOD, 0.82 + _folge * 0.025, 0.5)
        elif r.ort.y >= Graben.BRUT_Y - 0.5:
            r.lebendig = false
            _offen -= 1
            brut = maxi(0, brut - Arten.wucht(r.art))
            _schuetteln = 1.0
            _folge = 0.0
            Klang.spiele(Klang.Ton.BRUT_FAELLT, 1.0, 0.85)
            _funken.platzen(r.ort, Color(1.0, 0.42, 0.34), Arten.radius(r.art) * 1.6)
            _aktualisiere_kolonie()
            if brut <= 0:
                _verloren()
                return
    _hud.setze_zahlen(brut, Fortschritt.stand.naehrstoffe, _offen)


# --- Uebergaenge -----------------------------------------------------------

func _welle_geschafft() -> void:
    Fortschritt.melde_ziel(Tagesziel.Ziel.WELLEN)
    _einstieg_weiter(2)
    Fortschritt.merke_welle(welle_nummer + 1)
    if welle_nummer >= Graben.WELLEN_GESAMT:
        lage = Lage.GESCHAFFT
        _hud.zeige_ende(true, welle_nummer, verdient)
        return

    # Der Graben gibt nur her, was der Tiefenschacht geoeffnet hat. Wer am
    # Ende des Abschnitts steht, spielt ihn weiter - und erfaehrt, woran es
    # liegt. Eine Wand ohne Grund ist ein Fehler; eine mit Grund ist ein Ziel.
    var stand: KolonieStand = Fortschritt.stand
    if welle_nummer + 1 > stand.offene_welle():
        _hud.melde("Der Graben endet hier - Tiefenschacht Stufe %d graebt weiter"
            % stand.naechste_tiefe())
        _bereite_welle_vor()
        return

    welle_nummer += 1
    _bereite_welle_vor()


func _verloren() -> void:
    lage = Lage.VERLOREN
    _schuetteln = 1.6
    _hud.zeige_ende(false, welle_nummer, verdient)


## Nach einem Fall: die Sitzung beginnt neu, die Kolonie bleibt.
##
## Das ist die Zusage aus dem Konzept - der Fortschritt der Sitzung geht
## verloren, der Koloniefortschritt nicht. Ohne sie waere jede Niederlage ein
## Grund, das Spiel zu loeschen.
func neu_anfangen() -> void:
    brut = Fortschritt.stand.brut_leben()
    verdient = 0
    polypen.clear()
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
    _einstieg_weiter(3)
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


# --- Eingabe ---------------------------------------------------------------

func _unhandled_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventScreenTouch:
        _beruehrung(ereignis.pressed, _welt(ereignis.position))
    elif ereignis is InputEventScreenDrag:
        _finger = _welt(ereignis.position)
        _einstieg_weiter(0)
    elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
        _beruehrung(ereignis.pressed, _welt(ereignis.position))
    elif ereignis is InputEventMouseMotion and _zieht:
        _finger = _welt(ereignis.position)
        _einstieg_weiter(0)


func _beruehrung(gedrueckt: bool, ort: Vector2) -> void:
    _zieht = gedrueckt
    if not gedrueckt:
        return
    _finger = ort

    match lage:
        Lage.BAUEN:
            if _hud.kolonieknopf_bei(_bildschirm(ort)):
                Klang.spiele(Klang.Ton.TIPP)
                oeffne_kolonie()
                return
            var n := nische_bei(ort)
            if n >= 0:
                if baue_polyp(n):
                    return
            starte_welle()
        Lage.VERLOREN, Lage.GESCHAFFT:
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
    var welle := 0
    var polypenzahl := 0

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
            "--messen":
                if i + 1 < argumente.size():
                    messen = float(argumente[i + 1])
            "--stau":
                stau = true

    if welle > 0:
        welle_nummer = clampi(welle, 1, Graben.WELLEN_GESAMT)
    for p in mini(polypenzahl, Graben.NISCHEN.size()):
        polypen.append(Graben.NISCHEN[p])
    if welle > 0 or polypenzahl > 0:
        _bereite_welle_vor()

    if messen > 0.0:
        _miss_bildrate(messen, stau)
        return
    if bild.is_empty():
        return
    _nimm_auf(bild, vorlauf, bauen)


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
        brut = 1000000

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


func _nimm_auf(datei: String, vorlauf: float, bauen: bool) -> void:
    if not bauen:
        starte_welle()
        _finger = Graben.WAECHTER + Vector2(-70.0, -520.0)
        # Im Vorlauf mit festem Takt rechnen, damit dasselbe Bild entsteht,
        # egal wie schnell der Rechner ist.
        var takt := 1.0 / 60.0
        var schritte := int(vorlauf / takt)
        for i in schritte:
            if lage != Lage.WELLE:
                break
            _process(takt)
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var bildchen := get_viewport().get_texture().get_image()
    bildchen.save_png(datei)
    print("Bild gespeichert: ", datei)
    get_tree().quit()
