extends Node2D

## **Der Rundumlauf - ein Versuch, kein Ersatz.**
##
## Das Spiel bleibt, wie es ist; diese Szene liegt daneben und wird nur mit
## `--rundum` gestartet. Genau so steht es in Abschnitt 7 des Plans: erst
## einen Bildschirm bauen und ansehen, ob er sich gut anfuehlt, und erst
## danach entscheiden. Wenn er es nicht tut, ist ein Nachmittag weg und nicht
## ein halbes Jahr.
##
## **Was hier wiederverwendet wird, und warum das ueberhaupt geht.**
##
##   * `Schlund.beleuchtung()`, `getroffen()`, `zielrichtung()`, `gedreht()` -
##     unveraendert. Sie rechnen seit jeher mit freien Vektoren und wissen
##     nichts von oben und unten. Damit gilt die Zusage weiter, dass
##     gezeichnetes Licht und Schaden dieselbe Rechnung sind.
##   * `Schwarm` und alle zwoelf Arten - unveraendert. Jede Art wird relativ
##     zu `t.richtung` und deren Senkrechten gezeichnet; in der Tierkunst
##     steht nirgends ein absolutes Oben. Sie sehen in jeder Blickrichtung
##     richtig aus, ohne dass eine Linie neu gezogen werden musste.
##   * `Kegel` - mit einer einzigen Aenderung: seine Spitze ist jetzt ein
##     Feld statt einer Konstanten.
##   * `Arten`, `Wellen`, `Funken`, `Klang`, `Tastsinn` - unveraendert.
##
## **Was neu ist:** der Weg der Raeuber (`Rundum.schritt`, weil das Ziel sich
## bewegt), die Steuerung (ein Finger fuer Fahrt und Blick), die Begleiter,
## und die Huelle anstelle der Brut.
##
## **Die Huelle ist die Brut.** Wer faehrt, hat kein Gelege mehr zu
## verteidigen - der Verlust muss also am Boot haengen. `Arten.wucht()` sagt
## weiter, wie teuer ein Durchkommen ist, und die Brutkammer hebt weiter die
## Zahl der Fehler, die man uebersteht. Die ganze Meta-Ebene bleibt damit
## gueltig, ohne dass eine Zahl umgerechnet werden muesste.

const BOOT_TEMPO := 260.0
const BOOT_TRAEGHEIT := 6.0
const BOOT_RADIUS := 26.0
const DREH_TEMPO := 7.0

const BEGLEITER_ABSTAND := 96.0
const BEGLEITER_TRAEGHEIT := 3.4
const BEGLEITER_REICHWEITE := 210.0
const BEGLEITER_TAKT := 0.9

## Wie lange ein Raeuber braucht, bis er nach einem Treffer wieder beisst.
const BISS_SPERRE := 0.9

@onready var _schwarm: Node2D = $Schwarm
@onready var _kegel: Node2D = $Kegel
@onready var _funken: Node2D = $Funken
@onready var _kamera: Camera2D = $Kamera

var welle_nummer := 1
var huelle := 12
var huelle_voll := 12
var erlegt := 0

var _ort := Vector2.ZERO
var _fahrt := Vector2.ZERO
var _blick := Vector2.UP
var _finger := Vector2(0.0, -200.0)
var _zieht := false

var _tiere: Array[Raeuber] = []
var _wellenzeit := 0.0
var _offen := 0
var _schuetteln := 0.0

## Begleiter: Ort und was sie gerade anleuchten.
var _begleiter: Array[Vector2] = []
var _begleiter_ziel: Array[int] = []


func _ready() -> void:
    _lies_argumente()
    _kamera.position = Vector2.ZERO
    _kegel.halbwinkel = Graben.HALBWINKEL
    _kegel.reichweite = Graben.REICHWEITE
    for i in 3:
        _begleiter.append(Vector2.ZERO)
        _begleiter_ziel.append(-1)
    _bereite_welle_vor()
    if not _schuss.is_empty():
        _nimm_auf.call_deferred()


func _bereite_welle_vor() -> void:
    _tiere.clear()
    _wellenzeit = 0.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x52554e44 + welle_nummer
    # Dieselbe Zusammensetzung wie im Schlund - nur der Weg ist ein anderer.
    for eintrag in Wellen.auftritte(welle_nummer):
        var t := Raeuber.new()
        t.art = int(eintrag[&"art"])
        t.welle = welle_nummer
        t.eintritt = float(eintrag[&"zeit"])
        t.phase = float(eintrag[&"phase"])
        t.leben = Wellen.leben_in(t.art, welle_nummer)
        t.leben_voll = t.leben
        # Der Eintrittswinkel kommt aus der Eintrittsstelle der flachen
        # Welle: dieselbe Zahl, nur rund gelegt statt in einer Zeile.
        var anteil := (float(eintrag[&"x"]) / Graben.EINTRITT_SEITE) * 0.5 + 0.5
        t.ort = Rundum.eintritt(anteil * TAU + rng.randf_range(-0.12, 0.12))
        t.richtung = (-t.ort).normalized()
        _tiere.append(t)
    _offen = _tiere.size()
    _schwarm.tiere = _tiere


func _process(delta: float) -> void:
    delta = Graben.takt(delta)
    _wellenzeit += delta
    _schuetteln = maxf(0.0, _schuetteln - delta * 4.0)
    _kamera.offset = Vector2(randf_range(-1.0, 1.0),
        randf_range(-1.0, 1.0)) * _schuetteln * 7.0

    _fuehre_boot(delta)
    _fuehre_begleiter(delta)
    _bewege(delta)
    _verbrenne(delta)

    if _offen <= 0 and huelle > 0:
        welle_nummer += 1
        _bereite_welle_vor()

    _schwarm.queue_redraw()
    queue_redraw()


## Ein Finger, zwei Aufgaben: Blickrichtung immer, Fahrt ab der Totzone.
func _fuehre_boot(delta: float) -> void:
    var soll := Schlund.zielrichtung(_ort, _finger, _blick)
    _blick = Schlund.gedreht(_blick, soll, DREH_TEMPO, delta)

    var wunsch := Vector2.ZERO
    if _zieht:
        wunsch = Rundum.fahrt(_ort, _finger, BOOT_TEMPO)
    _fahrt = _fahrt.lerp(wunsch, clampf(BOOT_TRAEGHEIT * delta, 0.0, 1.0))
    _ort = Rundum.gehalten(_ort + _fahrt * delta, BOOT_RADIUS)

    _kegel.spitze = _ort
    _kegel.richtung = _blick
    _kegel.queue_redraw()


func _fuehre_begleiter(delta: float) -> void:
    var lebende: Array[Vector2] = []
    var index: Array[int] = []
    for i in _tiere.size():
        var t := _tiere[i]
        if t.lebendig and t.alter >= 0.0:
            lebende.append(t.ort)
            index.append(i)

    for i in _begleiter.size():
        var ziel := Rundum.begleiter_ziel(i, _begleiter.size(), _ort, _blick,
            BEGLEITER_ABSTAND)
        _begleiter[i] = _begleiter[i].lerp(ziel,
            clampf(BEGLEITER_TRAEGHEIT * delta, 0.0, 1.0))
        var n := Rundum.naechstes_ziel(_begleiter[i], lebende,
            BEGLEITER_REICHWEITE)
        _begleiter_ziel[i] = index[n] if n >= 0 else -1
        if n < 0:
            continue
        # Derselbe Schaden wie im Schlund: ein Polyp auf Sollstufe.
        var t := _tiere[index[n]]
        var weg := Graben.POLYP_LEISTUNG * Ausbau.leistung_faktor(welle_nummer) \
            * delta
        t.leben -= weg
        t.hitze = minf(1.0, t.hitze + delta * 2.0)


func _bewege(delta: float) -> void:
    for t in _tiere:
        if not t.lebendig:
            continue
        t.alter = _wellenzeit - t.eintritt
        if t.alter < 0.0:
            continue
        var art := Arten.art(t.art)
        var vorher := t.ort
        t.ort = Rundum.schritt(t.ort, _ort,
            Wellen.tempo_in(t.art, t.welle), art[&"schlaengel"],
            art[&"takt"], t.phase, t.alter, delta,
            Wellen.drift_in(t.art, t.welle))
        var weg := t.ort - vorher
        if weg.length_squared() > 0.0001:
            t.richtung = weg.normalized()
        t.hitze = maxf(0.0, t.hitze - delta * 1.6)

        # Angekommen: die Huelle nimmt Schaden, das Tier prallt ab und
        # kommt wieder. Ein Raeuber, der beim Treffer verschwindet, macht
        # aus dem Boot eine Wand.
        if t.ort.distance_to(_ort) < BOOT_RADIUS + Wellen.radius_in(t.art, t.welle) * 0.5:
            huelle = maxi(0, huelle - Arten.wucht(t.art))
            _schuetteln = maxf(_schuetteln, 1.0)
            Klang.spiele(Klang.Ton.BRUT_FAELLT, 1.0, 0.8)
            Tastsinn.gib(Tastsinn.Art.TREFFER)
            _funken.platzen(t.ort, Color(1.0, 0.42, 0.34), 22.0)
            # Zurueckwerfen statt entfernen.
            t.ort = _ort + (t.ort - _ort).normalized() * (BOOT_RADIUS + 190.0)
            t.eintritt = _wellenzeit + BISS_SPERRE


func _verbrenne(delta: float) -> void:
    var wirkungen := PackedFloat32Array()
    var kandidaten: Array[int] = []
    for i in _tiere.size():
        var t := _tiere[i]
        if not t.lebendig or t.alter < 0.0:
            continue
        var hell := Schlund.beleuchtung(_ort, _blick, _kegel.halbwinkel,
            _kegel.reichweite, t.ort)
        t.licht = hell
        if hell <= 0.0:
            continue
        wirkungen.append(hell)
        kandidaten.append(i)

    # Derselbe Deckel wie im Schlund: der Kegel haelt nur so viele auf einmal.
    var ziele := Ausbau.ziele(welle_nummer)
    for k in Schlund.brennende(wirkungen, ziele):
        var t := _tiere[kandidaten[k]]
        t.leben -= Schlund.schaden_an(
            Graben.LEISTUNG * Ausbau.leistung_faktor(welle_nummer),
            wirkungen[k], Wellen.panzer_in(t.art, t.welle),
            Wellen.mindest_licht_in(t.art, t.welle), delta)
        t.hitze = minf(1.0, t.hitze + delta * 3.0)

    for t in _tiere:
        if t.lebendig and t.leben <= 0.0:
            t.lebendig = false
            _offen -= 1
            erlegt += 1
            _funken.platzen(t.ort, Arten.farbe(t.art), 20.0)
            Klang.spiele(Klang.Ton.TOD, 0.9, 0.45)


func _unhandled_input(ereignis: InputEvent) -> void:
    if _finger_fest:
        return
    if ereignis is InputEventScreenTouch:
        _zieht = ereignis.pressed
        _finger = _welt(ereignis.position)
    elif ereignis is InputEventScreenDrag:
        _finger = _welt(ereignis.position)
    elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
        _zieht = ereignis.pressed
        _finger = _welt(ereignis.position)
    elif ereignis is InputEventMouseMotion:
        _finger = _welt(ereignis.position)


func _welt(bild: Vector2) -> Vector2:
    return get_viewport().get_canvas_transform().affine_inverse() * bild


# --- Zeichnen ---------------------------------------------------------------
#
# Nur so viel, wie der Versuch braucht: der Rand des Feldes, das Boot, die
# drei Begleiter und eine Zeile Zahlen. Die Raeuber zeichnet `Schwarm`, das
# Licht der `Kegel` - beides unveraendert.

const HAUT := Color(0.62, 0.88, 0.94)
const HAUT_TIEF := Color(0.10, 0.24, 0.30)


func _draw() -> void:
    _zeichne_rand()
    _zeichne_begleiter()
    _zeichne_boot()


## Der Rand des Feldes. Kein Zaun, sondern ein Saum, der andeutet, wo das
## Licht der Kolonie aufhoert - sonst faehrt man gegen eine unsichtbare Wand
## und haelt es fuer einen Fehler.
func _zeichne_rand() -> void:
    var punkte := PackedVector2Array()
    for i in 97:
        var w := TAU * float(i) / 96.0
        punkte.append(Vector2.RIGHT.rotated(w) * Rundum.FELD_RADIUS)
    draw_polyline(punkte, Color(0.26, 0.48, 0.52, 0.20), 2.0, true)
    for i in 97:
        var w := TAU * float(i) / 96.0
        punkte[i] = Vector2.RIGHT.rotated(w) * (Rundum.FELD_RADIUS - 26.0)
    draw_polyline(punkte, Color(0.26, 0.48, 0.52, 0.08), 1.2, true)


func _zeichne_boot() -> void:
    var k := _blick
    var quer := k.orthogonal()
    var r := BOOT_RADIUS

    # Rumpf: vorn spitz, hinten stumpf - man sieht ihm an, wohin er faehrt,
    # auch wenn er steht.
    var rumpf := PackedVector2Array([
        _ort + k * r * 1.7,
        _ort + k * r * 0.5 + quer * r * 0.72,
        _ort - k * r * 0.9 + quer * r * 0.58,
        _ort - k * r * 1.25,
        _ort - k * r * 0.9 - quer * r * 0.58,
        _ort + k * r * 0.5 - quer * r * 0.72,
    ])
    draw_colored_polygon(rumpf, HAUT_TIEF)
    draw_polyline(rumpf + PackedVector2Array([rumpf[0]]), HAUT, 1.6, true)

    # Die Lampe sitzt dort, wo der Kegel ansetzt. Was leuchtet, macht
    # Schaden - dann soll man auch sehen, woher es kommt.
    draw_circle(_ort + k * r * 1.25, r * 0.30, Color(0.80, 1.0, 0.96, 0.30))
    draw_circle(_ort + k * r * 1.25, r * 0.16, Color(1.0, 1.0, 0.96, 0.95))

    # Huelle als Ring um das Boot: keine Leiste am Bildrand, sondern dort,
    # wo der Daumen ohnehin hinsieht.
    var anteil := clampf(float(huelle) / float(maxi(1, huelle_voll)), 0.0, 1.0)
    if anteil < 1.0:
        draw_arc(_ort, r * 1.9, -PI * 0.5, -PI * 0.5 + TAU * anteil, 40,
            Color(1.0, 0.62, 0.44, 0.65), 2.6, true)


func _zeichne_begleiter() -> void:
    for i in _begleiter.size():
        var p: Vector2 = _begleiter[i]
        var atem := 0.5 + 0.5 * sin(_wellenzeit * BEGLEITER_TAKT + float(i) * 2.1)
        draw_circle(p, 13.0 + 2.0 * atem, Color(0.34, 0.86, 0.72, 0.10))
        draw_circle(p, 6.0 + 1.2 * atem, Color(0.46, 0.94, 0.78, 0.55))
        draw_circle(p, 2.6, Color(0.86, 1.0, 0.92, 0.9))
        # Der Strahl auf sein Ziel. Er ist die einzige Anzeige dafuer, dass
        # ein Begleiter etwas tut - ohne ihn sind es drei Punkte, die
        # mitschwimmen.
        var n: int = _begleiter_ziel[i]
        if n >= 0 and n < _tiere.size() and _tiere[n].lebendig:
            draw_line(p, _tiere[n].ort,
                Color(0.46, 0.94, 0.78, 0.16 + 0.10 * atem), 1.4, true)


# --- Aufnahme ---------------------------------------------------------------
#
# Dieselben Schalter wie im Schlund, damit man den Versuch mit denselben
# Befehlen ansehen kann: `--welle`, `--zeit`, `--schuss`. Ohne sie laeuft die
# Szene ganz normal.

var _schuss := ""
var _vorlauf := 0.0
var _finger_fest := false


func _lies_argumente() -> void:
    var argumente := OS.get_cmdline_user_args()
    for i in argumente.size():
        match argumente[i]:
            "--welle":
                if i + 1 < argumente.size():
                    welle_nummer = maxi(1, int(argumente[i + 1]))
            "--zeit":
                if i + 1 < argumente.size():
                    _vorlauf = maxf(0.0, float(argumente[i + 1]))
            "--schuss":
                if i + 1 < argumente.size():
                    _schuss = argumente[i + 1]


func _spiele_vor() -> void:
    # Fester Takt, damit dasselbe Bild entsteht, egal wie schnell der Rechner
    # ist - genauso wie `wache.gd::_nimm_auf()` es macht.
    _finger_fest = true
    _zieht = true
    var takt := 1.0 / 60.0
    for i in int(_vorlauf / takt):
        # Ein Daumen, der langsam kreist: so sieht man Fahrt und Drehung
        # zugleich, statt eines stehenden Bootes.
        var w := float(i) * takt * 0.55
        _finger = Vector2.RIGHT.rotated(w) * 240.0
        _process(takt)


func _nimm_auf() -> void:
    if _schuss.is_empty():
        return
    _spiele_vor()
    await RenderingServer.frame_post_draw
    var bild := get_viewport().get_texture().get_image()
    bild.save_png(_schuss)
    get_tree().quit()
