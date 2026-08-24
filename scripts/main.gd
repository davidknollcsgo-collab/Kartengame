## Setzt die Spielszene zusammen und leitet Eingaben weiter.
##
## Der Aufbau geschieht im Code statt in einer .tscn: das haelt die
## Abhaengigkeiten an einer Stelle sichtbar und erspart Szenendateien, die sich
## im Diff kaum lesen lassen.
extends Node2D

## Groesste Fingerbewegung, die noch als Antippen zaehlt statt als Schieben.
const TIPP_TOLERANZ := 12.0

var _station: Station
var _kamera: Kamera
var _sterne: ColorRect

var _druck_bei := Vector2.ZERO
var _druck_aktiv := false

var _schuss_pfad := ""
var _schuss_zaehler := 0


func _ready() -> void:
    _baue_hintergrund()

    _station = Station.new()
    add_child(_station)

    _kamera = Kamera.new()
    _kamera.grenzen = _station.ausmasse()
    add_child(_kamera)
    # Erst nach add_child: ausserhalb des Szenenbaums hat make_current keine
    # Wirkung und Godot warnt zu Recht.
    _kamera.make_current()
    _kamera.passe_ein(get_viewport_rect().size)

    var schicht := CanvasLayer.new()
    schicht.layer = 1
    add_child(schicht)
    schicht.add_child(Hud.new())

    # Abwesenheit gutschreiben, bevor der Spieler das erste Bild sieht.
    var offline := Spielstand.verbuche_offline()
    if offline > 0.0:
        print("Offline gutgeschrieben: %s ¢" % Zahl.kurz(offline))

    _pruefe_schussauftrag()


func _baue_hintergrund() -> void:
    var schicht := CanvasLayer.new()
    schicht.layer = -1
    add_child(schicht)

    _sterne = ColorRect.new()
    _sterne.set_anchors_preset(Control.PRESET_FULL_RECT)
    _sterne.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/sterne.gdshader")
    _sterne.material = mat
    schicht.add_child(_sterne)


func _process(_delta: float) -> void:
    if _sterne and _kamera:
        # Parallaxe: der Hintergrund folgt der Kamera abgeschwaecht.
        _sterne.material.set_shader_parameter("versatz", _kamera.position)
    _bearbeite_schussauftrag()


func _unhandled_input(ereignis: InputEvent) -> void:
    if ereignis is InputEventMouseButton:
        var m := ereignis as InputEventMouseButton
        if m.button_index != MOUSE_BUTTON_LEFT:
            return
        if m.pressed:
            _druck_bei = m.position
            _druck_aktiv = true
        elif _druck_aktiv:
            _druck_aktiv = false
            # Nur als Antippen werten, wenn kaum geschoben wurde - sonst
            # kauft jedes Verschieben der Karte versehentlich ein Modul.
            if m.position.distance_to(_druck_bei) <= TIPP_TOLERANZ:
                _tippe(m.position)


func _tippe(bildschirm: Vector2) -> void:
    var welt := _kamera.get_canvas_transform().affine_inverse() * bildschirm
    var lokal := _station.to_local(welt)

    if _station.kern_bei(lokal):
        Spielstand.manuell_sammeln()
        _station.kern_blitzen()
        return

    var index := _station.modul_bei(lokal)
    if index >= 0:
        Spielstand.kaufe(index, 1)


# --- Entwicklerwerkzeug -----------------------------------------------------

## Erkennt den Auftrag "godot --path . -- --schuss <datei>".
##
## Nur im Debug-Build aktiv, damit im ausgelieferten Spiel nichts davon uebrig
## bleibt. Erspart beim Bauen der Optik den Weg ueber ein echtes Geraet.
func _pruefe_schussauftrag() -> void:
    if not OS.is_debug_build():
        return
    var args := OS.get_cmdline_user_args()
    var i := args.find("--schuss")
    if i >= 0 and i + 1 < args.size():
        _schuss_pfad = args[i + 1]
    if args.has("--vorrat"):
        _fuelle_vorrat()


## Baut fuer Aufnahmen eine laufende Station auf.
##
## Der Anfangszustand zeigt nur dunkle Baugruppen; wie das Spiel im Betrieb
## aussieht, laesst sich daran nicht beurteilen.
func _fuelle_vorrat() -> void:
    Spielstand.protokolle = 12
    Spielstand.credits = 5.0e7
    for paar in [[0, 27], [1, 14], [2, 11], [3, 6], [4, 3], [5, 1]]:
        Spielstand.bestand[paar[0]] = paar[1]
        Spielstand.bestand_geaendert.emit(paar[0], paar[1])
    Spielstand.credits_geaendert.emit(Spielstand.credits)
    Spielstand.protokolle_geaendert.emit(Spielstand.protokolle)


func _bearbeite_schussauftrag() -> void:
    if _schuss_pfad.is_empty():
        return
    _schuss_zaehler += 1
    # Ein paar Bilder abwarten, damit Puls und Drohnen nicht im Startzustand
    # eingefroren erscheinen.
    if _schuss_zaehler < 45:
        return
    var bild := get_viewport().get_texture().get_image()
    bild.save_png(_schuss_pfad)
    _schuss_pfad = ""
    get_tree().quit(0)
