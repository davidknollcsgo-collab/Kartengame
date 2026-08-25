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

var lage := Lage.BAUEN
var welle_nummer := 1
var brut := Graben.BRUT_LEBEN
var naehrstoffe := 0
var polypen: Array[Vector2] = []
var verdient := 0

var _tiere: Array[Raeuber] = []
var _offen := 0
var _wellenzeit := 0.0
var _richtung := Vector2.UP
var _finger := Graben.WAECHTER + Vector2.UP * 300.0
var _zieht := false
var _schuetteln := 0.0
var _polyp_takt := PackedFloat32Array()


func _ready() -> void:
    _stelle_ausbau_ein()
    _bereite_welle_vor()
    _lies_entwicklerschalter()


# --- Ausbau und Wellenvorbereitung ----------------------------------------

func _stelle_ausbau_ein() -> void:
    # Der Koloniestand kommt vorerst aus der Sollkurve. Sobald die Kolonie
    # gebaut ist, liefert sie diese vier Werte - `Ausbau` bleibt dann die
    # Vorgabe, an der sie sich messen lassen muss.
    _kegel.halbwinkel = Graben.HALBWINKEL * Ausbau.winkel_faktor(welle_nummer)
    _kegel.reichweite = Graben.REICHWEITE * Ausbau.reichweite_faktor(welle_nummer)


func leistung() -> float:
    return Graben.LEISTUNG * Ausbau.leistung_faktor(welle_nummer)


func ziele() -> int:
    return Ausbau.ziele(welle_nummer)


func _bereite_welle_vor() -> void:
    lage = Lage.BAUEN
    _tiere.clear()
    _wellenzeit = 0.0
    _stelle_ausbau_ein()
    _schwarm.tiere = _tiere
    _aktualisiere_kolonie()
    _hud.zeige_bauphase(welle_nummer, brut, naehrstoffe,
        Graben.polyp_kosten(polypen.size()), polypen.size())


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

    _offen = _tiere.size()
    _wellenzeit = 0.0
    _polyp_takt.resize(polypen.size())
    _polyp_takt.fill(0.0)
    _schwarm.tiere = _tiere
    lage = Lage.WELLE
    _hud.zeige_welle(welle_nummer, brut, naehrstoffe, _tiere.size())


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
        if _offen <= 0:
            _welle_geschafft()
    elif lage == Lage.BAUEN:
        _fuehre_kegel(delta)

    _kegel.richtung = _richtung
    _schwarm.queue_redraw()


func _fuehre_kegel(delta: float) -> void:
    var soll := Schlund.zielrichtung(Graben.WAECHTER, _finger, _richtung)
    _richtung = Schlund.gedreht(_richtung, soll, Graben.DREHTEMPO, delta)


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
        hell.append(Schlund.beleuchtung(Graben.WAECHTER, _richtung,
            _kegel.halbwinkel, _kegel.reichweite, r.ort))

    for i in Schlund.brennende(hell, ziele()):
        var r := sichtbar[i]
        r.leben -= Schlund.schaden_je_sekunde(leistung(), hell[i]) * delta
        r.hitze = 1.0
        if randf() < hell[i] * delta * 26.0:
            _funken.strahl(Graben.WAECHTER, r.ort, Arten.farbe(r.art))


func _polypen_feuern(delta: float) -> void:
    for n in polypen.size():
        _polyp_takt[n] = maxf(0.0, _polyp_takt[n] - delta)
        for r in _tiere:
            if not r.lebendig or r.alter < 0.0:
                continue
            if r.ort.distance_to(polypen[n]) > Graben.POLYP_REICHWEITE:
                continue
            r.leben -= Graben.POLYP_LEISTUNG * delta
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
            var lohn := Arten.wert(r.art)
            naehrstoffe += lohn
            verdient += lohn
            _funken.platzen(r.ort, Arten.farbe(r.art), Arten.radius(r.art))
            _hud.zeige_ausbeute(r.ort, lohn)
        elif r.ort.y >= Graben.BRUT_Y - 0.5:
            r.lebendig = false
            _offen -= 1
            brut = maxi(0, brut - Arten.wucht(r.art))
            _schuetteln = 1.0
            _funken.platzen(r.ort, Color(1.0, 0.42, 0.34), Arten.radius(r.art) * 1.6)
            _aktualisiere_kolonie()
            if brut <= 0:
                _verloren()
                return
    _hud.setze_zahlen(brut, naehrstoffe, _offen)


# --- Uebergaenge -----------------------------------------------------------

func _welle_geschafft() -> void:
    if welle_nummer >= Graben.WELLEN_GESAMT:
        lage = Lage.GESCHAFFT
        _hud.zeige_ende(true, welle_nummer, verdient)
        return
    welle_nummer += 1
    _bereite_welle_vor()


func _verloren() -> void:
    lage = Lage.VERLOREN
    _schuetteln = 1.6
    _hud.zeige_ende(false, welle_nummer, verdient)


func neu_anfangen() -> void:
    brut = Graben.BRUT_LEBEN
    naehrstoffe = 0
    verdient = 0
    polypen.clear()
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
    var preis := Graben.polyp_kosten(polypen.size())
    if naehrstoffe < preis:
        return false
    naehrstoffe -= preis
    polypen.append(ort)
    _funken.platzen(ort, Color(0.52, 0.94, 0.80), 20.0)
    _aktualisiere_kolonie()
    _hud.zeige_bauphase(welle_nummer, brut, naehrstoffe,
        Graben.polyp_kosten(polypen.size()), polypen.size())
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
    _kolonie.naehrstoffe = naehrstoffe
    _kolonie.bauphase = lage == Lage.BAUEN
    _kolonie.queue_redraw()


# --- Eingabe ---------------------------------------------------------------

func _unhandled_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventScreenTouch:
        _beruehrung(ereignis.pressed, _welt(ereignis.position))
    elif ereignis is InputEventScreenDrag:
        _finger = _welt(ereignis.position)
    elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
        _beruehrung(ereignis.pressed, _welt(ereignis.position))
    elif ereignis is InputEventMouseMotion and _zieht:
        _finger = _welt(ereignis.position)


func _beruehrung(gedrueckt: bool, ort: Vector2) -> void:
    _zieht = gedrueckt
    if not gedrueckt:
        return
    _finger = ort

    match lage:
        Lage.BAUEN:
            var n := nische_bei(ort)
            if n >= 0:
                if baue_polyp(n):
                    return
            starte_welle()
        Lage.VERLOREN, Lage.GESCHAFFT:
            neu_anfangen()


func _welt(bildschirm: Vector2) -> Vector2:
    return get_canvas_transform().affine_inverse() * bildschirm


# --- Entwicklerschalter ----------------------------------------------------
#
# Wie bei HYPHA: Bilder werden aufgenommen, nicht beschrieben. Siehe CLAUDE.md.

func _lies_entwicklerschalter() -> void:
    var argumente := OS.get_cmdline_user_args()
    var bild := ""
    var vorlauf := 0.0
    var bauen := false
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

    if welle > 0:
        welle_nummer = clampi(welle, 1, Graben.WELLEN_GESAMT)
    for p in mini(polypenzahl, Graben.NISCHEN.size()):
        polypen.append(Graben.NISCHEN[p])
    if welle > 0 or polypenzahl > 0:
        _bereite_welle_vor()

    if bild.is_empty():
        return
    _nimm_auf(bild, vorlauf, bauen)


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
