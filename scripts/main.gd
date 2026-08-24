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
var _leiste: Leiste
var _prestige_dialog: Dialog
var _offline_dialog: Dialog
var _ausbau_schirm: AusbauSchirm
var _bericht_schirm: BerichtSchirm
var _loesch_dialog: Dialog
var _modul_schirm: ModulSchirm
var _lizenz_schirm: LizenzSchirm

var _druck_bei := Vector2.ZERO
var _druck_aktiv := false

var _schuss_pfad := ""
var _schuss_zaehler := 0


func _ready() -> void:
    # Vor allem anderen: erst laden, dann Offline verrechnen, dann anzeigen.
    Spielstand.lade_von_platte()

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

    _baue_oberflaeche()

    # Abwesenheit gutschreiben, bevor der Spieler das erste Bild sieht.
    var offline := Spielstand.verbuche_offline()
    if offline > 0.0:
        _zeige_offline(offline)

    _pruefe_schussauftrag()


func _baue_oberflaeche() -> void:
    var schicht := CanvasLayer.new()
    schicht.layer = 1
    add_child(schicht)

    schicht.add_child(Hud.new())

    _leiste = Leiste.new()
    _leiste.menge = Spielstand.kaufmenge
    _leiste.menge_gewaehlt.connect(_bei_menge)
    _leiste.prestige_gewuenscht.connect(_frage_prestige)
    _leiste.ausbau_gewuenscht.connect(func(): _ausbau_schirm.visible = true)
    _leiste.bericht_gewuenscht.connect(func(): _bericht_schirm.visible = true)
    schicht.add_child(_leiste)

    # Dialoge oben auf, damit nichts dahinter bedienbar bleibt.
    var oben := CanvasLayer.new()
    oben.layer = 2
    add_child(oben)

    _prestige_dialog = Dialog.new()
    _prestige_dialog.visible = false
    _prestige_dialog.bestaetigt.connect(_fuehre_prestige_aus)
    oben.add_child(_prestige_dialog)

    _offline_dialog = Dialog.new()
    _offline_dialog.visible = false
    oben.add_child(_offline_dialog)

    _ausbau_schirm = AusbauSchirm.new()
    _ausbau_schirm.visible = false
    oben.add_child(_ausbau_schirm)

    _bericht_schirm = BerichtSchirm.new()
    _bericht_schirm.visible = false
    _bericht_schirm.zuruecksetzen_gewuenscht.connect(_frage_loeschen)
    _bericht_schirm.lizenzen_gewuenscht.connect(func(): _lizenz_schirm.visible = true)
    oben.add_child(_bericht_schirm)

    _lizenz_schirm = LizenzSchirm.new()
    _lizenz_schirm.visible = false
    oben.add_child(_lizenz_schirm)

    _modul_schirm = ModulSchirm.new()
    _modul_schirm.visible = false
    _modul_schirm.geschlossen.connect(func(): _station.aktualisiere())
    oben.add_child(_modul_schirm)

    _loesch_dialog = Dialog.new()
    _loesch_dialog.visible = false
    _loesch_dialog.bestaetigt.connect(_fuehre_loeschen_aus)
    oben.add_child(_loesch_dialog)


func _bei_menge(menge: int) -> void:
    Spielstand.kaufmenge = menge
    _station.aktualisiere()


func _frage_prestige() -> void:
    var gewinn := Oekonomie.prestige_ertrag(Spielstand.lebenszeit_plasma)
    if gewinn <= 0:
        return
    var neu := Spielstand.protokolle + gewinn
    # Ausdruecklich benennen, was verloren geht: ein versehentlicher Reset
    # kostet Stunden und ist nicht rueckgaengig zu machen.
    _prestige_dialog.zeige("Station zurücksetzen?", PackedStringArray([
        "Alle Baugruppen und alles Plasma gehen verloren.",
        "",
        "Du erhältst %d Protokolle (insgesamt %d)." % [gewinn, neu],
        "Produktion dann dauerhaft x%.2f statt x%.2f." % [
            Oekonomie.prestige_mult(neu), Oekonomie.prestige_mult(Spielstand.protokolle)],
    ]), "Zurücksetzen", "Abbrechen")


func _fuehre_prestige_aus() -> void:
    Spielstand.prestige()
    _station.aktualisiere()
    Spielstand.speichere()


func _frage_loeschen() -> void:
    # Unwiderruflich, deshalb ausdruecklich benennen, was verschwindet - und
    # den bestaetigenden Knopf nicht harmloser aussehen lassen, als er ist.
    _loesch_dialog.zeige("Wirklich alles löschen?", PackedStringArray([
        "Station, Protokolle, Quanten und",
        "Errungenschaften werden gelöscht.",
        "",
        "Das lässt sich nicht rückgängig machen.",
    ]), "Endgültig löschen", "Abbrechen")


func _fuehre_loeschen_aus() -> void:
    Spielstand.loesche_alles()
    _bericht_schirm.visible = false
    _station.aktualisiere()


func _zeige_offline(betrag: float) -> void:
    _offline_dialog.zeige("Willkommen zurück", PackedStringArray([
        "Die Station lief %s ohne dich weiter." % Zahl.zeit(Spielstand.letzte_offline_dauer),
        "",
        "Gutschrift: %s %s" % [Zahl.kurz(betrag), Waehrung.PLASMA],
    ]), "Übernehmen")


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
        var ertrag: float = Spielstand.manuell_sammeln()
        _station.kern_blitzen()
        _station.zeige_gutschrift(lokal + Vector2(0.0, -20.0),
            "+" + Zahl.kurz(ertrag), Color(0.55, 0.90, 1.0))
        return

    # Funde zuerst: sie treiben ueber die Station hinweg und verschwinden
    # wieder. Laege eine Baugruppe darunter, kaeme der Kauf dem Fund zuvor.
    if _station.fund_bei(lokal):
        return

    # Dann die Detailecke: sie liegt innerhalb der Karte, und wer sie trifft,
    # will das Fenster und nicht den Kauf.
    var detail := _station.detail_bei(lokal)
    if detail >= 0:
        _modul_schirm.zeige(detail)
        return

    var index := _station.modul_bei(lokal)
    if index >= 0:
        var vorher := Spielstand.rate()
        if _station.kaufe_an(index):
            # Der Zugewinn an Foerderung ist die Zahl, die den Spieler
            # interessiert - nicht der bezahlte Preis.
            var zuwachs := Spielstand.rate() - vorher
            _station.zeige_gutschrift(lokal + Vector2(0.0, -30.0),
                "+" + Zahl.kurz(zuwachs) + "/s", Modul.farbe(index))


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
    if args.has("--speichern"):
        # Erzwingt eine Sicherung vor der Aufnahme. Dient dem Nachweis, dass
        # Speichern und Laden im laufenden Spiel zusammenspielen - die
        # Unit-Tests pruefen nur die Dateiebene, nicht die Verdrahtung hier.
        Spielstand.speichere()
    var d := args.find("--zeige")
    if d >= 0 and d + 1 < args.size():
        _zeige_probe(args[d + 1])


## Oeffnet einen Dialog fuer die Aufnahme.
func _zeige_probe(was: String) -> void:
    match was:
        "prestige":
            _frage_prestige()
        "bericht":
            _bericht_schirm.visible = true
        "lizenzen":
            _lizenz_schirm.visible = true
        "fund":
            _station.zeige_fund(Ereignis.Art.QUANTEN)
        "modul":
            _modul_schirm.zeige(1)
        "ausbau":
            Spielstand.gutschrift_quanten(64)
            _ausbau_schirm.visible = true
        "protokolle":
            Spielstand.protokolle = 240
            Spielstand.protokolle_gesamt = 240
            _ausbau_schirm.reiter = AusbauSchirm.Reiter.PROTOKOLLE
            _ausbau_schirm.visible = true
        "offline":
            # Plausible Dauer fuer die Aufnahme; im Spiel kommt sie aus
            # verbuche_offline().
            Spielstand.letzte_offline_dauer = 3.0 * 3600.0
            _zeige_offline(4.2e9)


## Baut fuer Aufnahmen eine laufende Station auf.
##
## Der Anfangszustand zeigt nur dunkle Baugruppen; wie das Spiel im Betrieb
## aussieht, laesst sich daran nicht beurteilen.
func _fuelle_vorrat() -> void:
    Spielstand.protokolle = 12
    Spielstand.plasma = 5.0e7
    # Ohne Lebenszeitertrag waere Prestige gesperrt und der Knopf nie zu sehen.
    # Auf die aktuelle Prestige-Kurve abgestimmt: entspricht knapp dem ersten
    # erreichbaren Reset. Der alte Wert stammte aus der Kurve vor dem
    # Balancing und liess den Knopf viertausend Protokolle ausweisen.
    Spielstand.lebenszeit_plasma = 6.0e7
    Spielstand.gutschrift_quanten(18)
    for paar in [[0, 27], [1, 14], [2, 11], [3, 6], [4, 3], [5, 1]]:
        Spielstand.bestand[paar[0]] = paar[1]
        Spielstand.bestand_geaendert.emit(paar[0], paar[1])
    Spielstand.plasma_geaendert.emit(Spielstand.plasma)
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
