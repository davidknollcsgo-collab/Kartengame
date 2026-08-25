## Hauptszene: baut die Kammer auf, nimmt Eingaben entgegen, führt Buch.
##
## Der Zustandsfluss ist bewusst schlicht: es wird gezielt, geschossen,
## gewartet, bis die Spore liegt - und dann wieder gezielt. Keine Eingabe
## während des Flugs. Das macht aus dem Spiel ein Puzzle statt einer
## Geschicklichkeitsübung, und nur so lässt es sich einhändig im Bus spielen.
extends Node2D

## Kürzeste und weiteste Flugstrecke, je nach Spannung.
const STRECKE_MIN := 900.0
const STRECKE_MAX := 3400.0

enum Lage { ZIELEN, FLUG, GERAEUMT, LEER }

var lage := Lage.ZIELEN
var kammer_nummer := 1
var sporen_uebrig := 0

var _kammer: Kammer
var _werfer: Werfer
var _hud: Hud
var _kamera: Camera2D
var _zug_start := Vector2.ZERO
var _zieht := false


func _ready() -> void:
    _baue()
    lade_kammer(maxi(Fortschritt.fortschrittstiefe + 1, 1))
    _pruefe_entwicklerschalter()


func _baue() -> void:
    var feld := KammerDaten.FELD
    _kamera = Camera2D.new()
    _kamera.position = feld.get_center()
    add_child(_kamera)
    _kamera.make_current()

    var hintergrund := Hintergrund.new()
    hintergrund.z_index = -10
    add_child(hintergrund)

    _kammer = Kammer.new()
    add_child(_kammer)
    _kammer.geraeumt.connect(_bei_geraeumt)

    _werfer = Werfer.new()
    _werfer.position = KammerDaten.WERFER
    add_child(_werfer)

    var schicht := CanvasLayer.new()
    add_child(schicht)
    _hud = Hud.new()
    _hud.weiter_gewuenscht.connect(naechste_kammer)
    _hud.wiederholen_gewuenscht.connect(wiederhole)
    schicht.add_child(_hud)


## Lädt eine Kammer und setzt den Vorrat zurück.
func lade_kammer(nummer: int) -> void:
    kammer_nummer = maxi(nummer, 1)
    var plan := KammerDaten.baue(kammer_nummer)
    _kammer.setze(plan)
    sporen_uebrig = plan.sporen
    lage = Lage.ZIELEN
    _werfer.vorschau = PackedVector2Array()
    _werfer.zieht = false
    _aktualisiere_hud()


# --- Eingabe ----------------------------------------------------------------

func _unhandled_input(ereignis: InputEvent) -> void:
    if lage != Lage.ZIELEN:
        return

    if ereignis is InputEventMouseButton:
        var m := ereignis as InputEventMouseButton
        if m.button_index != MOUSE_BUTTON_LEFT:
            return
        if m.pressed:
            _beginne_zug(get_global_mouse_position())
        else:
            _beende_zug()
    elif ereignis is InputEventMouseMotion and _zieht:
        _fuehre_zug(get_global_mouse_position())
    elif ereignis is InputEventScreenTouch:
        var t := ereignis as InputEventScreenTouch
        if t.pressed:
            _beginne_zug(_welt(t.position))
        else:
            _beende_zug()
    elif ereignis is InputEventScreenDrag and _zieht:
        _fuehre_zug(_welt((ereignis as InputEventScreenDrag).position))


## Bildschirmpunkt in Weltkoordinaten.
func _welt(p: Vector2) -> Vector2:
    return get_canvas_transform().affine_inverse() * p


func _beginne_zug(ort: Vector2) -> void:
    _zug_start = ort
    _zieht = true
    _werfer.zieht = true


func _fuehre_zug(ort: Vector2) -> void:
    _werfer.setze_zug(_zug_start, ort)
    _werfer.vorschau = _berechne(Werfer.VORSCHAU_ABPRALLER).punkte


func _beende_zug() -> void:
    if not _zieht:
        return
    _zieht = false
    _werfer.zieht = false
    _werfer.vorschau = PackedVector2Array()
    if _werfer.genug_gezogen():
        _feuere()


## Berechnet die Bahn mit der aktuellen Zielrichtung.
##
## Vorschau und echter Schuss gehen beide hier durch, nur mit anderer
## Abprallgrenze. Zwei getrennte Rechnungen würden unweigerlich auseinander
## driften.
func _berechne(abpraller: int) -> Ballistik.Flug:
    var strecke := lerpf(STRECKE_MIN, STRECKE_MAX, _werfer.spannung)
    return Ballistik.flug(KammerDaten.WERFER, _werfer.richtung,
        _kammer.alle_waende(), abpraller, strecke)


func _feuere() -> void:
    if sporen_uebrig <= 0:
        return
    var flug := _berechne(_kammer.bauplan.abpraller)
    if flug.punkte.size() < 2:
        return

    sporen_uebrig -= 1
    lage = Lage.FLUG
    _aktualisiere_hud()

    var s := Spore.new()
    add_child(s)
    s.angekommen.connect(_bei_angekommen)
    s.abgeprallt.connect(_bei_abprall)
    s.starte(flug.punkte, _kammer)


# --- Ablauf -----------------------------------------------------------------

func _bei_abprall(_ort: Vector2, _nummer: int) -> void:
    pass


func _bei_angekommen(spur: PackedVector2Array) -> void:
    # Die geflogene Bahn wird zur Wand für den nächsten Schuss - der Kniff des
    # Spiels. Erst danach darf wieder gezielt werden.
    _kammer.lege_spur(spur)

    if lage == Lage.GERAEUMT:
        return
    if _kammer.knoten_uebrig() == 0:
        _bei_geraeumt()
    elif sporen_uebrig <= 0:
        lage = Lage.LEER
        _hud.zeige_ende(false)
    else:
        lage = Lage.ZIELEN
    _aktualisiere_hud()


func _bei_geraeumt() -> void:
    if lage == Lage.GERAEUMT:
        return
    lage = Lage.GERAEUMT
    var ertrag := KammerDaten.ertrag(kammer_nummer, sporen_uebrig)
    Fortschritt.schreibe_gut(ertrag)
    Fortschritt.vermerke_kammer(kammer_nummer)
    _hud.zeige_ende(true, ertrag)
    _aktualisiere_hud()


func naechste_kammer() -> void:
    _hud.verbirg_ende()
    lade_kammer(kammer_nummer + 1)


func wiederhole() -> void:
    _hud.verbirg_ende()
    lade_kammer(kammer_nummer)


func _aktualisiere_hud() -> void:
    _hud.setze(kammer_nummer, sporen_uebrig, _kammer.knoten_uebrig())


# --- Entwicklerschalter -----------------------------------------------------

## Nur im Debug-Build: Aufnahmen und Sprünge für die Entwicklung.
func _pruefe_entwicklerschalter() -> void:
    if not OS.is_debug_build():
        return
    var args := OS.get_cmdline_user_args()

    var k := args.find("--kammer")
    if k >= 0 and k + 1 < args.size():
        lade_kammer(int(args[k + 1]))

    if args.has("--gezielt"):
        _zeige_zielvorschau()

    # Feuert echte Schuesse ab, damit sich die Spur und die Treffer ansehen
    # lassen. Ohne das zeigt jede Aufnahme nur den Anfangszustand.
    var f := args.find("--feuere")
    var schuesse := 0
    if f >= 0 and f + 1 < args.size():
        schuesse = int(args[f + 1])

    var s := args.find("--schuss")
    if s >= 0 and s + 1 < args.size():
        _nimm_auf(args[s + 1], schuesse)


## Stellt eine gezogene Zielhilfe für die Aufnahme her.
func _zeige_zielvorschau() -> void:
    _werfer.zieht = true
    _werfer.setze_zug(KammerDaten.WERFER, KammerDaten.WERFER + Vector2(-58.0, 150.0))
    _werfer.vorschau = _berechne(Werfer.VORSCHAU_ABPRALLER).punkte


## Ein noch stehender Knoten, auf den sich zielen laesst.
func _naechstes_ziel() -> Vector2:
    var plan := _kammer.bauplan
    for k in plan.knoten:
        # Nur Knoten, die es noch gibt.
        var steht := false
        for offen in _kammer._knoten:
            if offen.distance_to(k) < 1.0:
                steht = true
        if steht:
            return k
    return KammerDaten.FELD.get_center()


func _nimm_auf(pfad: String, schuesse: int = 0) -> void:
    for i in 20:
        await get_tree().process_frame

    # Auf tatsaechliche Knoten zielen. Blind in den Raum zu feuern zeigt zwar
    # die Spuren, aber nie einen Treffer - und Treffer sind das, was gepruefet
    # werden muss.
    for n in schuesse:
        var ziel := _naechstes_ziel()
        _werfer.richtung = (ziel - KammerDaten.WERFER).normalized()
        _werfer.spannung = 0.75
        _feuere()
        var wache := 0
        while lage == Lage.FLUG and wache < 400:
            wache += 1
            await get_tree().process_frame
        for i in 8:
            await get_tree().process_frame
        print("Schuss %d: %d Spuren, %d Waende, %d Knoten"
            % [n + 1, _kammer._spuren.size(), _kammer.alle_waende().size(),
               _kammer.knoten_uebrig()])

    if schuesse == 0:
        for i in 25:
            await get_tree().process_frame
    var bild := get_viewport().get_texture().get_image()
    bild.save_png(pfad)
    get_tree().quit(0)
