extends Node2D

## **TEN THOUSAND - die Schleife.**
##
## Von oben, ein Held, hundert Feinde. Der Finger fuehrt **nur den Mann**;
## die Waffen schlagen von selbst. Was man entscheidet, ist die Aufstellung -
## wohin man laeuft, wen man vor sich laesst, wann man durch eine Luecke geht -
## und bei jedem Aufstieg eines von drei Angeboten.
##
## Hier steht kein Spielregelwissen. Was ueber Leben und Tod entscheidet,
## steht in `Gefecht`; dieser Knoten fragt es, zeichnet es und macht Klang
## daraus.

enum Lage { TITEL, LAUF, ENDE, BURG, ZEUG }

const PERGAMENT := Palette.BODEN
const TINTE := Palette.UMRISS
const ZINNOBER := Palette.GEFAHR
const GOLD := Color(0.72, 0.55, 0.18)

## Wie gross eine Figur im Bild ist.
const HELD_HOEHE := 134.0
const FEIND_HOEHE := 104.0

## Der Stick: erst ab dieser Strecke bewegt sich etwas, und bei dieser ist er
## voll ausgelenkt. Ohne Totzone zittert der Held unter dem Daumen.
const STICK_TOT := 12.0
const STICK_VOLL := 96.0

## **Klang wird gedrosselt.** In Minute neun fallen dreissig Feinde je
## Sekunde; jeden zu vertonen ergibt kein Gefecht, sondern ein Rauschen.
const TOD_SPERRE := 0.09
const HIEB_SPERRE := 0.07

var lage := Lage.TITEL
var _stand: Gefecht.Stand = null
var _rng := RandomNumberGenerator.new()
## **Zierde wuerfelt mit eigenen Wuerfeln.** Funken und Staub zogen aus `_rng`,
## demselben Generator, mit dem das Gefecht rechnet: jedes Woelkchen
## verschob die Wuerfel, und dieselbe Saat spielte mit einer neuen Zierde ein
## anderes Gefecht. Gemessen sah der Umbau dadurch doppelt so teuer aus, weil
## im Schuss eine andere Zahl Figuren im Bild stand.
var _zier := RandomNumberGenerator.new()
var _zeit := 0.0
var _kamera_ort := Vector2.ZERO
var _ruettel := 0.0
var _tod_sperre := 0.0
var _hieb_sperre := 0.0
var _waffe_winkel := 0.0

var _zieht := false
## **Der erste Lauf erklaert sich, einmal.** Sekunden, die der Held in diesem
## Lauf schon gefuehrt wurde; der Hinweis blendet darueber aus. Kein
## Zeitlimit: wer nicht zieht, braucht ihn noch.
var _gezogen := 0.0
const HINWEIS_WEG := 0.8
var _von := Vector2.ZERO
var _jetzt := Vector2.ZERO

var _funken: Array = []
## **Gefallene liegen einen Augenblick** (`GEFALLEN_DAUER`), hoechstens
## `GEFALLEN_HOECHSTENS` zugleich - in den dichten Minuten fallen Feinde im
## Dutzend je Sekunde, und ein Leichenfeld waere ein Hintergrund aus Figuren.
var _gefallene: Array = []
const GEFALLEN_DAUER := 1.1
## **Wie einer faellt**, in Sekunden: erst blitzt er und wird zurueckgeworfen,
## dann knickt er ein, dann liegt er; am Ende blinkt er aus.
const FALL_BLITZ := 0.09
const FALL_KNIE := 0.22
const FALL_BLINKT := 0.30
## **Der Warlord faellt nicht wie einer von hundert**: er bleibt laenger
## stehen, kniet, das Schwert faellt ihm aus der Hand, dann liegt er.
const WARLORD_FALL := 2.6
const WARLORD_KNIE := 1.2
const GEFALLEN_HOECHSTENS := 40
## Staub: unter Gefallenen, hinter dem laufenden Helden, beim Aufsammeln.
var _staub: Array = []
var _staub_uhr := 0.0
## Ringe: goldener Ring beim Aufsammeln, heller beim Aufstieg.
var _ringe: Array = []
## Wie frisch der letzte Treffer am Helden ist: 1 gerade getroffen, 0 lange her.
var _wunde := 0.0
## **Schlagbilder.** Schwert, Speer und Hammer trafen unsichtbar: man hoerte
## einen Hieb und sah ein Ziel aufblitzen, aber keinen Schlag. Jeder Schlag
## hinterlaesst jetzt fuer einen Augenblick seine Form - die Sichel des
## Schwerts, den Stoss des Speers, die Bodenwelle des Hammers -, in genau
## der Richtung, Weite und Breite, in der das Gefecht ihn gerechnet hat.
var _hiebe: Array = []
## Wie lange ein Schlagbild steht, je Waffe (`Waffen.Art`).
const HIEB_DAUER: PackedFloat32Array = [0.20, 0.16, 0.0, 0.0, 0.34, 0.0]
## Wohin und wann der letzte Schlag ging - die Waffe in der Hand zeigt dorthin.
var _schlag_richtung := Vector2.RIGHT
var _schlag_alter := 9.0
var _fund := -1
var _fund_stufe := 0
## Rueckstoss der Armbruster nach dem Schuss, je Feind (Kennung -> Rest).
var _rueck := {}
## **Schadenszahlen, nur im Bild.** Das Leben jedes Feindes vom letzten Bild
## (Kennung -> Leben); was fehlt, wird je Feind kurz gesammelt
## (`ZAHL_SAMMELN`) und dann als eine Zahl gezeigt. Je Treffer eine Zahl
## gaebe beim Flegel, der je Bild ein wenig nimmt, einen Zahlenregen.
var _leben_alt := {}
var _treffer := {}
var _zahlen: Array = []
var _held_leben_alt := -1.0
const ZAHL_SAMMELN := 0.22
const ZAHL_DAUER := 0.75
const ZAHLEN_HOECHSTENS := 36
## **Treffer-Stopp**: so lange haelt die Ansicht an, wenn es zaehlt. Nur die
## Ansicht - das Gefecht rechnet danach dieselben Schritte, nur spaeter. Im
## Vorlauf eines Schusses nie (`_vorlauf`): dort zaehlen die Schritte.
var _stopp := 0.0
var _vorlauf := false
const STOPP_WUNDE := 0.045
const STOPP_WARLORD := 0.20
## Wann jede Muenze zuerst gesehen wurde (Kennung -> Zeit): sie springt.
var _muenz_zeit := {}
## Aufgesammelter Sold fliegt zum Helden.
var _flieger: Array = []
## Die Lichtsaeule beim Aufstieg: 1 gerade, 0 vorbei.
var _saeule := 0.0
## Wie lange der Warlord schon liegt, bevor der Bericht kommt.
var _nachspiel := 0.0
var _saeule_farbe := Color.WHITE

@onready var _kamera: Camera2D = $Bild/Boden/Ansicht/Kamera
@onready var _kamera_fig: Camera2D = $Bild/Figuren/Ansicht/Kamera
@onready var _feld: Node2D = $Bild/Boden/Ansicht/Feld
@onready var _licht: CanvasModulate = $Bild/Boden/Ansicht/Licht
@onready var _licht_fig: CanvasModulate = $Bild/Figuren/Ansicht/Licht
@onready var _teile: Array[Node2D] = [$Bild/Figuren/Ansicht/Hinten,
    $Bild/Figuren/Ansicht/Loch, $Bild/Figuren/Ansicht/Vorn]

## **Pixel-Art: das Feld in einem Drittel der Aufloesung.** Boden und Figuren
## liegen in zwei Unterbildern (`gefecht.tscn`), die scharf hochgezogen
## werden; die Figuren bekommen dabei ihren Umriss aus `umriss.gdshader`. Die
## Menues bleiben scharf. Muss zu `stretch_shrink` in der Szene passen.
const PIXEL := 3
@onready var _hud: Control = $Oberflaeche/Hud


func _ready() -> void:
    _rng.randomize()
    RenderingServer.set_default_clear_color(PERGAMENT)
    Klang.laut = Burg.stand.laut
    Tastsinn.an = Burg.stand.beben
    for t in _teile:
        t.lauf = self
    var zoom := Vector2.ONE * Gefecht.ZOOM / float(PIXEL)
    _kamera.zoom = zoom
    _kamera_fig.zoom = zoom
    set_process(true)
    _lies_schalter()


## --- Die Schleife ---

func beginne(held: int) -> void:
    Burg.stand.held = held
    _stand = Gefecht.baue(Burg.stand.stufen, held, Burg.stand.getragen())
    _funken.clear()
    _zahlen.clear()
    _treffer.clear()
    _leben_alt.clear()
    _flieger.clear()
    _muenz_zeit.clear()
    _held_leben_alt = -1.0
    _saeule = 0.0
    _stopp = 0.0
    _nachspiel = 0.0
    _hiebe.clear()
    _gefallene.clear()
    _staub.clear()
    _ringe.clear()
    _wunde = 0.0
    _fund = -1
    _gezogen = 0.0
    _kamera_ort = Vector2.ZERO
    lage = Lage.LAUF
    Klang.spiele(Klang.Ton.TIPP)


func _process(delta: float) -> void:
    _zeit += delta
    _ruettel = maxf(0.0, _ruettel - delta * 3.2)
    _tod_sperre = maxf(0.0, _tod_sperre - delta)
    _hieb_sperre = maxf(0.0, _hieb_sperre - delta)
    for f in _funken:
        f.alter += delta
    _funken = _funken.filter(func(f): return f.alter < 0.55)
    for h in _hiebe:
        h.alter += delta
    _hiebe = _hiebe.filter(func(h): return h.alter < h.dauer)
    _schlag_alter += delta
    for g in _gefallene:
        g.alter += delta
    _gefallene = _gefallene.filter(func(g): return g.alter < g.dauer)
    for s in _staub:
        s.alter += delta
    _staub = _staub.filter(func(s): return s.alter < s.dauer)
    for r in _ringe:
        r.alter += delta
    _ringe = _ringe.filter(func(r): return r.alter < r.dauer)
    _wunde = maxf(0.0, _wunde - delta * 2.5)
    _saeule = maxf(0.0, _saeule - delta * 1.4)
    for z in _zahlen:
        z.alter += delta
    _zahlen = _zahlen.filter(func(z): return z.alter < ZAHL_DAUER)
    for fl in _flieger:
        fl.alter += delta
    _flieger = _flieger.filter(func(fl): return fl.alter < 0.2)
    for k in _rueck.keys():
        _rueck[k] -= delta
        if _rueck[k] <= 0.0:
            _rueck.erase(k)
    # Laufstaub: wenige blasse Woelkchen an den Fersen, nur wer rennt.
    if lage == Lage.LAUF and _stand != null and not _stand.wartet_auf_wahl \
            and _stand.lauf.length_squared() > 0.35:
        _staub_uhr -= delta
        if _staub_uhr <= 0.0 and _staub.size() < 14:
            _staub_uhr = 0.11
            _staub.append({"ort": _stand.ort - _stand.lauf.normalized() * 14.0
                + Vector2((_zier.randf() - 0.5) * 16.0, 2.0), "alter": 0.0,
                "dauer": 0.45, "gross": 7.0})

    if lage == Lage.LAUF and _stand != null:
        var eingabe := _eingabe()
        if eingabe.length_squared() > 0.0025 and not _stand.wartet_auf_wahl:
            _gezogen += delta
        if _stand.warlord_gefallen and _stand.lebt():
            # **Der Sieg wartet, bis der Warlord liegt.** Der Lauf endete im
            # selben Bild, in dem er fiel, und sein Fall war nie zu sehen.
            # Das Gefecht steht dabei still: was noch lebt, schlaegt nicht mehr.
            _nachspiel += delta
        elif _stopp > 0.0 and not _vorlauf:
            _stopp -= delta
        else:
            _stopp = 0.0
            Gefecht.schritt(_stand, minf(delta, 1.0 / 30.0), eingabe, _rng)
            _werte_aus()
            _sammle_schaden(delta)
        _kamera_ort = _kamera_ort.lerp(_stand.ort, clampf(delta * 7.0, 0.0, 1.0))
        _feld.setze_mitte(_kamera_ort)
        if Gefecht.vorbei(_stand) and (not _stand.warlord_gefallen
                or not _stand.lebt() or _nachspiel >= WARLORD_FALL):
            _beende()
    # Das Beben schiebt beide Kameras, nicht die Zeichnung: Boden und Figuren
    # liegen in zwei Puffern und muessen gemeinsam wackeln.
    var beben := Vector2.ZERO
    if _ruettel > 0.0:
        beben = Vector2(sin(_zeit * 57.0), cos(_zeit * 43.0)) * _ruettel * 7.0
    # **Auf das Pixelraster gelegt.** Eine Kamera zwischen zwei Bildpunkten
    # laesst jede Figur beim Gehen um einen Pixel flackern, und Boden und
    # Figuren liegen in zwei Puffern - beide muessen auf demselben Raster
    # stehen.
    _licht.color = _tageslicht()
    _licht_fig.color = _licht.color
    var auf_raster := Pixel.raster(_kamera_ort + beben) * Pixel.P
    _kamera.position = auf_raster
    _kamera_fig.position = auf_raster
    for t in _teile:
        t.queue_redraw()


## **Das Licht wandert** ueber die zehn Minuten: Vormittag, warmer
## Nachmittag, Abendrot, wenn der Warlord kommt. Schwach, damit keine Sorte
## ihre Farbe verliert - die Waechter pruefen die ungetoenten Farben, und das
## Abendrot nimmt Blau nur um ein Sechstel. Die Menues bleiben ungetoent.
const LICHT_MITTAG := Color(1.0, 0.98, 0.93)
## 0,84 statt 0,76 im Blau: das erste Abendrot faerbte den Sand orange.
const LICHT_ABEND := Color(1.0, 0.91, 0.84)

func _tageslicht() -> Color:
    if lage != Lage.LAUF or _stand == null:
        return Color.WHITE
    var t := clampf(_stand.zeit / Andrang.WARLORD_ZEIT, 0.0, 1.0)
    if t < 0.5:
        return Color.WHITE.lerp(LICHT_MITTAG, t * 2.0)
    return LICHT_MITTAG.lerp(LICHT_ABEND, (t - 0.5) * 2.0)


## Der Stick: relativ zum Aufsetzpunkt, nicht an einer festen Ecke. Auf einem
## Telefon haelt niemand den Daumen dort, wo ein Entwerfer ihn hingelegt hat.
var _mit_daumen := false
## Nur fuer das Feature-Bild des Ladens: statt der Anzeige steht der Name
## ueber dem laufenden Gefecht. Siehe `tools/ladengrafik.sh`.
var marke := false

func _eingabe() -> Vector2:
    # Im Messstand fuehrt `Daumen` - dieselbe Rechnung, die auch `tools/probe.gd`
    # benutzt. Zwei Daumen waeren zwei Spiele.
    if _mit_daumen and _stand != null:
        return Daumen.richtung(_stand)
    if not _zieht:
        return Vector2.ZERO
    var d := _jetzt - _von
    var l := d.length()
    if l < STICK_TOT:
        return Vector2.ZERO
    return d.normalized() * clampf((l - STICK_TOT) / (STICK_VOLL - STICK_TOT),
        0.0, 1.0)


func _werte_aus() -> void:
    for v in _stand.vorfaelle:
        var art: int = v[0]
        match art:
            Gefecht.Vorfall.SCHLAG:
                if _hieb_sperre <= 0.0:
                    _hieb_sperre = HIEB_SPERRE
                    Klang.spiele(Klang.Ton.HIEB, 0.9 + randf() * 0.3, 0.5)
                var w: int = v[1]
                var richtung: Vector2 = v[2] if v.size() > 2 else _stand.blick
                # **Die Hand fuehrt nur die eigene Waffe.** Der Held traegt
                # die seiner Klasse; schluege sie bei jedem Bolzen und jedem
                # Flegelkreis mit, zappelte sie ohne Pause.
                if w == Helden.startwaffe(_stand.held):
                    _schlag_richtung = richtung
                    _schlag_alter = 0.0
                if not Waffen.fliegt(w):
                    _hiebe.append({"waffe": w, "richtung": richtung,
                        "alter": 0.0, "dauer": HIEB_DAUER[w],
                        "weite": Gefecht.weite_von(_stand, w),
                        "halb": Waffen.breite(w, _stand.waffe_stufe(w)) * 0.5})
            Gefecht.Vorfall.FEIND_FAELLT:
                if _tod_sperre <= 0.0:
                    _tod_sperre = TOD_SPERRE
                    Klang.spiele(Klang.Ton.TREFFER, 0.85 + randf() * 0.4, 0.7)
                var f: Gefecht.Feind = v[1]
                # Der letzte Schlag zaehlt mit, auch wenn er der einzige war.
                var id := f.get_instance_id()
                _zaehle(f, float(_leben_alt.get(id, f.leben_voll)) - maxf(0.0, f.leben), true)
                _leben_alt.erase(id)
                if Feinde.ist_warlord(f.art):
                    # **Der Warlord faellt nicht wie einer von hundert.**
                    _ruettel = 1.8
                    _stopp = STOPP_WARLORD
                    _spritz(f.ort + Vector2(0.0, -FEIND_HOEHE), Palette.sorte(f.art), 24)
                    _spritz(f.ort + Vector2(0.0, -FEIND_HOEHE), Palette.WEISS, 16)
                    _ringe.append({"ort": f.ort, "alter": 0.0, "dauer": 0.9,
                        "von": 20.0, "bis": 260.0, "farbe": Palette.WEISS})
                # **Der Funke traegt die Farbe dessen, der faellt.** Zinnober
                # bleibt dem Schaden am Spieler vorbehalten - darf alles rot
                # spritzen, heisst Rot nichts mehr.
                _spritz(f.ort, Palette.sorte(f.art), 4)
                var ist_w := Feinde.ist_warlord(f.art)
                if ist_w or (_gefallene.size() < GEFALLEN_HOECHSTENS and _im_bild(f.ort, 60.0)):
                    _gefallene.append({"ort": f.ort, "art": f.art,
                        "blick": f.blick, "alter": 0.0,
                        "dauer": WARLORD_FALL if ist_w else GEFALLEN_DAUER,
                        "weg": (f.ort - _stand.ort).normalized(),
                        "h": FEIND_HOEHE * (f.radius / 17.0)})
                    _staub.append({"ort": f.ort, "alter": 0.0, "dauer": 0.5,
                        "gross": 13.0})
            Gefecht.Vorfall.STREITER_GETROFFEN:
                Klang.spiele(Klang.Ton.WUNDE)
                Tastsinn.gib(Tastsinn.Art.WUNDE)
                _ruettel = 1.0
                _stopp = STOPP_WUNDE
                if _held_leben_alt > _stand.leben:
                    _zahl(int(ceilf(_held_leben_alt - _stand.leben)),
                        _stand.ort + Vector2(0.0, -HELD_HOEHE * 0.95), true)
                _wunde = 1.0
                _spritz(_stand.ort + Vector2(0.0, -HELD_HOEHE * 0.5), ZINNOBER, 6)
            Gefecht.Vorfall.SCHUSS:
                Klang.spiele(Klang.Ton.BOLZEN, 1.0, 0.45)
                if v.size() > 1 and v[1] != null:
                    _rueck[(v[1] as Gefecht.Feind).get_instance_id()] = 0.18
            Gefecht.Vorfall.MUENZE:
                Klang.spiele(Klang.Ton.MUENZE, 0.95 + randf() * 0.3, 0.35)
                if v.size() > 1 and v[1] != null and _flieger.size() < 16:
                    _flieger.append({"von": (v[1] as Gefecht.Muenze).ort, "alter": 0.0})
                if _ringe.size() < 12:
                    _ringe.append({"ort": _stand.ort + Vector2(0.0, -HELD_HOEHE * 0.25),
                        "alter": 0.0, "dauer": 0.3, "von": 6.0, "bis": 26.0,
                        "farbe": GOLD})
            Gefecht.Vorfall.AUFSTIEG:
                Klang.spiele(Klang.Ton.AUFSTIEG)
                Tastsinn.gib(Tastsinn.Art.SCHNITT)
                var glanz := Skins.glanz(_stand.held, Burg.stand.skin(_stand.held))
                _ringe.append({"ort": _stand.ort, "alter": 0.0, "dauer": 0.7,
                    "von": 20.0, "bis": HELD_HOEHE * 1.6, "farbe": glanz})
                _saeule = 1.0
                _saeule_farbe = glanz
                _spritz(_stand.ort + Vector2(0.0, -HELD_HOEHE * 0.4), glanz, 10)
            Gefecht.Vorfall.WARLORD:
                Klang.spiele(Klang.Ton.HORN)
                Tastsinn.gib(Tastsinn.Art.ENDE)
                _ruettel = 1.4


## **Was ein Feind seit dem letzten Bild verlor**, je Feind gesammelt. Nur
## wer im Bild steht, bekommt eine Zahl und Splitter.
func _sammle_schaden(delta: float) -> void:
    var neu := {}
    for f in _stand.feinde:
        if not f.lebt:
            continue
        var id := f.get_instance_id()
        var alt: float = _leben_alt.get(id, f.leben)
        neu[id] = f.leben
        var verlust := alt - f.leben
        if verlust > 0.5:
            _zaehle(f, verlust, false)
    _leben_alt = neu
    for id in _treffer.keys():
        var t: Dictionary = _treffer[id]
        t.uhr += delta
        if t.uhr >= ZAHL_SAMMELN:
            _zahl(int(roundf(t.summe)), t.ort, false)
            _treffer.erase(id)
    _held_leben_alt = _stand.leben


func _zaehle(f: Gefecht.Feind, verlust: float, fertig: bool) -> void:
    if verlust <= 0.5 or not _im_bild(f.ort, 60.0):
        return
    var id := f.get_instance_id()
    var kopf := f.ort + Vector2(0.0, -FEIND_HOEHE * (1.6 if Feinde.ist_warlord(f.art) else 0.85))
    var t: Variant = _treffer.get(id)
    if t == null:
        t = {"summe": 0.0, "ort": kopf, "uhr": 0.0}
        _treffer[id] = t
        if _funken.size() < 90:
            _spritz(f.ort + Vector2(0.0, -FEIND_HOEHE * 0.5), Palette.sorte(f.art), 2)
    t.summe += verlust
    t.ort = kopf
    if fertig:
        _zahl(int(roundf(t.summe)), t.ort, false)
        _treffer.erase(id)


func _zahl(wert: int, ort: Vector2, held: bool) -> void:
    if wert <= 0 or (_zahlen.size() >= ZAHLEN_HOECHSTENS and not held):
        return
    _zahlen.append({"wert": wert, "ort": ort + Vector2((_zier.randf() - 0.5) * 18.0, 0.0),
        "alter": 0.0, "held": held})


func _spritz(ort: Vector2, farbe: Color, zahl: int) -> void:
    for i in zahl:
        var w := _zier.randf() * TAU
        _funken.append({"ort": ort, "farbe": farbe, "alter": 0.0,
            "richtung": Vector2(cos(w), sin(w)) * (70.0 + _zier.randf() * 150.0),
            "gross": 2.0 + _zier.randf() * 3.4})


func _beende() -> void:
    lage = Lage.ENDE
    # **Jeder Lauf ist etwas wert, auch ein kurzer.** Ein Fund am Ende ist
    # der Grund, aus dem man nach einem schlechten Lauf noch einmal anfaengt.
    _fund = Ausruestung.fund(_stand.zeit, _rng)
    _fund_stufe = Burg.stand.finde(_fund, Ausruestung.fund_stufen(_stand.zeit))
    Burg.trage_ein(_stand.zeit, _stand.sold, _stand.erschlagen,
        _stand.warlord_gefallen)
    if Burg.stand.einstieg == 0:
        Burg.stand.einstieg = 1
        Burg.sichere()
    Tastsinn.gib(Tastsinn.Art.ENDE)


## --- Der Finger ---

func _unhandled_input(e: InputEvent) -> void:
    var runter := false
    var hoch := false
    var ort := Vector2.ZERO
    if e is InputEventScreenTouch:
        runter = e.pressed
        hoch = not e.pressed
        ort = e.position
    elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        runter = e.pressed
        hoch = not e.pressed
        ort = e.position
    elif e is InputEventScreenDrag or e is InputEventMouseMotion:
        if _zieht:
            _jetzt = e.position
        return
    else:
        return

    if runter:
        if lage == Lage.LAUF and _stand != null and not _stand.wartet_auf_wahl:
            _zieht = true
            _von = ort
            _jetzt = ort
        return
    if hoch:
        _zieht = false


## --- Das Bild ---

## Ein Bildpunkt des Pixelpuffers, in Punkten des Feldes.
const PIXEL_FELD := float(PIXEL) / Gefecht.ZOOM
const P := Pixel.P

const KLASSE_SCHWERT := 0
const KLASSE_BOGEN := 1
const KLASSE_SPEER := 2
const KLASSE_HAMMER := 3

## Die Feinde vor dem Helden, vom hinteren Teil fuer den vorderen gemerkt.
var _vor_held: Array = []

func zeichne_teil(teil: int, ci: RID) -> void:
    if lage != Lage.LAUF or _stand == null:
        return
    Pixel.bereit()
    match teil:
        0:
            _zeichne_hinten(ci)
        1:
            # Das Loch: dieselbe Form wie die alte Freistellung, aber in
            # einem Material, das Deckung null schreibt.
            _loch(ci)
        2:
            _zeichne_vorn(ci)


## **Die Freistellung als Loch** (Zusicherung 17): die Umrisse des Helden,
## zwei Bildpunkte weiter, in einem Material, das Deckung null schreibt
## (`loch.gdshader`). Der Held steht damit in einer Luecke, durch die der
## wirkliche Boden scheint.
func _loch(ci: RID) -> void:
    var o := _stand.ort
    Pixel.scheibe(ci, o + Vector2(0.0, -10.0 * P), 6.0 * P, Color.WHITE, 2.1)
    Pixel.scheibe(ci, o + Vector2(0.0, -21.0 * P), 5.0 * P, Color.WHITE, 1.0)


# --- Bilder aus dem Atlas ---------------------------------------------------

## Die Bilder der Feinde, einmal je Sorte, Laufbild, Richtung und Blitz
## gebaut und hier gemerkt: `[Rect2i, Anker]`. Ein Schluessel als Zahl, kein
## Text - es sind dreihundert Abfragen je Bild.
var _feind_bilder := {}

func _feind_bild(art: int, bild: int, spiegel: bool, blitz: bool) -> Array:
    var k := ((art * 8 + bild + 1) * 2 + int(spiegel)) * 2 + int(blitz)
    var v: Variant = _feind_bilder.get(k)
    if v == null:
        var name := "feind%d_%d" % [art, bild]
        var r := Pixel.bild(name, Figuren.feind(art, bild),
            Pixel.kleid(Palette.sorte(art)), Figuren.anker(art), spiegel, blitz)
        v = [r, Pixel.anker(name, spiegel, blitz)]
        _feind_bilder[k] = v
        Pixel.bereit()
    return v


## Ein beliebiges Bild aus Zeilen, gemerkt unter `name`.
var _bilder := {}

func _bild(name: String, zeilen: PackedStringArray, kleid: Dictionary, anker: int,
        spiegel := false) -> Array:
    var k := name + ("<" if spiegel else ">")
    var v: Variant = _bilder.get(k)
    if v == null:
        var r := Pixel.bild(name, zeilen, kleid, anker, spiegel)
        v = [r, Pixel.anker(name, spiegel)]
        _bilder[k] = v
        Pixel.bereit()
    return v


func _setze(ci: RID, b: Array, fuss: Vector2, modul := Color.WHITE) -> void:
    Pixel.setze(ci, b[0], b[1], fuss, modul)


func _schatten(ci: RID, fuss: Vector2, breite: int) -> void:
    var b := _bild("schatten%d" % breite, Figuren.schatten(breite), Pixel.grund(),
        breite / 2)
    _setze(ci, b, fuss + Vector2(0.0, float(maxi(2, breite / 4)) * 0.5 * P))


# --- Hinten: Boden, Gefallene, Sold, Figuren hinter dem Helden --------------

func _zeichne_hinten(ci: RID) -> void:
    # Was man sieht, in Punkten des Feldes: der Schirm durch den Zoom.
    _sicht = get_viewport_rect().size * 0.5 / Gefecht.ZOOM

    # **Staub als Pixelwoelkchen**: blass, steigt und waechst.
    for st in _staub:
        var u: float = st.alter / st.dauer
        var erde := Palette.ERDE.darkened(0.10)
        Pixel.scheibe(ci, st.ort + Vector2(0.0, -u * 10.0), st.gross * (0.5 + u),
            Color(erde.r, erde.g, erde.b, 0.40 * (1.0 - u)), 0.6)
    # **Gefallene fallen in Bildern**: Blitz und Rueckwurf, Einknicken,
    # Liegen, Ausblinken. Sie verblassen nicht stufenlos (der Umriss-Shader
    # zoege unter halber Deckung nur noch die Kante), sondern dunkeln nach,
    # blinken und verschwinden.
    for g in _gefallene:
        var alter: float = g.alter
        var art: int = g.art
        var spiegel: bool = g.blick < 0.0
        var weg: Vector2 = g.weg
        var b: Array
        var ort: Vector2 = g.ort
        var dauer: float = g.dauer
        var warlord := Feinde.ist_warlord(art)
        var knie := WARLORD_KNIE if warlord else FALL_KNIE
        if alter < FALL_BLITZ * (2.0 if warlord else 1.0):
            b = _feind_bild(art, -1, spiegel, true)
            ort += weg * P * (0.0 if warlord else 2.0)
        elif warlord and alter < knie:
            # Er kniet, und das Schwert faellt ihm aus der Hand: eine
            # Rasterlinie, die sich von senkrecht zu flach am Boden legt.
            b = _bild("sinkt%d" % art, Figuren.sinkt(Figuren.feind(art, -1), 8),
                Pixel.kleid(Palette.sorte(art)), Figuren.anker(art), spiegel)
            var u := clampf((alter - FALL_BLITZ * 2.0) / (knie - FALL_BLITZ * 2.0), 0.0, 1.0)
            var seite := -1.0 if spiegel else 1.0
            var griff: Vector2 = g.ort + Vector2(9.0 * P * seite, -6.0 * P)
            var w := lerpf(-PI * 0.5, 0.15, u * u)
            var spitze: Vector2 = griff + Vector2(cos(w) * seite, sin(w)) * 15.0 * P
            Pixel.linie(ci, griff, spitze, Palette.STAHL, 2)
            Pixel.linie(ci, griff, griff + (spitze - griff) * 0.85, Palette.STAHL_HELL, 1)
        elif alter < knie and art != Feinde.Art.WOLF:
            b = _bild("sinkt%d" % art, Figuren.sinkt(Figuren.feind(art, -1),
                4 if art != Feinde.Art.WARLORD else 8),
                Pixel.kleid(Palette.sorte(art)), Figuren.anker(art), spiegel)
            ort += weg * P * 3.0
        else:
            if dauer - alter < FALL_BLINKT and fmod(alter, 0.1) < 0.05:
                continue
            if art == Feinde.Art.WOLF:
                b = _bild("liegt%d" % art, _kopfueber(Figuren.feind(art, -1)),
                    Pixel.kleid(Palette.sorte(art)), Figuren.WOLF_ANKER, spiegel)
            else:
                b = _bild("liegt%d" % art, Figuren.liegend(Figuren.feind(art, -1)),
                    Pixel.kleid(Palette.sorte(art)), 10, spiegel)
            ort += weg * P * 3.0
        var u: float = alter / dauer
        var dunkel := lerpf(1.0, 0.6, u)
        _setze(ci, b, ort, Color(dunkel, dunkel, dunkel, 1.0))
    # **Sold glaenzt**: eine Pixelmuenze, die im Takt aufblinkt.
    # Neu gefallener Sold springt einmal hoch, bevor er liegt.
    var gesehen := {}
    for m in _stand.muenzen:
        var id := m.get_instance_id()
        var seit: float = _muenz_zeit.get(id, _zeit)
        gesehen[id] = seit
        if not _im_bild(m.ort, 20.0):
            continue
        var alter := _zeit - seit
        var sprung := sin(clampf(alter / 0.35, 0.0, 1.0) * PI) * 9.0 * P
        var blinkt := sin(_zeit * 6.0 + m.ort.x * 0.05) > 0.7
        var b := _bild("muenze%d" % int(blinkt), MUENZE_BLINKT if blinkt else MUENZE,
            Pixel.grund(), 2)
        _setze(ci, b, m.ort + Vector2(0.0, 6.0 - sprung))
    _muenz_zeit = gesehen

    # **Nach y sortiert, nicht nach Listenplatz.** Ohne das steht ein Feind
    # vor dem Helden, der hinter ihm ist - und in einem Bild ohne Perspektive
    # ist die Zeichenreihenfolge die einzige Tiefe, die es gibt.
    var sichtbar: Array = []
    for f in _stand.feinde:
        if _im_bild(f.ort, FEIND_HOEHE * 1.4):
            sichtbar.append(f)
    sichtbar.sort_custom(func(a, b): return a.ort.y < b.ort.y)

    # **Die Ansage liegt am Boden, unter allen Figuren.** Ein Band in
    # Zinnober entlang der Bahn, das sich bis zum Sturm fuellt: so weit traegt
    # er, und so viel Zeit bleibt. Zinnober heisst Schaden am Spieler - und
    # genau den kuendigt es an.
    for f in sichtbar:
        if f.angesagt and not f.stuermt:
            var weite: float = Feinde.sturm_weite(f.art)
            var voll: float = clampf(1.0 - f.uhr / Feinde.STURM_ANSAGE, 0.0, 1.0)
            Pixel.linie(ci, f.ort, f.ort + f.bahn * weite,
                Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.30), 4)
            Pixel.linie(ci, f.ort, f.ort + f.bahn * weite * voll,
                Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.45), 2)

    # **Hohe Dinge stehen in derselben Sortierung** (Runde vier): ein Baum
    # verdeckt, wer hinter ihm laeuft. Nur den Helden nicht - eine Krone, die
    # ihn verdecken wuerde, steht hinter ihm. *Wo bin ich* geht vor Tiefe.
    var stuecke: Array = []
    for f in sichtbar:
        stuecke.append([f.ort.y, f])
    for h in _feld.hohe_dinge(_kamera_ort, _sicht + Vector2(60.0, 160.0)):
        var ort: Vector2 = h[0]
        if _im_bild(ort, 140.0):
            stuecke.append([ort.y, h])
    stuecke.sort_custom(func(a, b): return a[0] < b[0])

    # **Die Gefaehrten laufen in derselben Sortierung mit.** Ein Begleiter,
    # der immer oben liegt, steht vor Feinden, hinter denen er steht.
    _vor_held.clear()
    for st in stuecke:
        var ding: Variant = st[1]
        if ding is Array:
            if st[0] > _stand.ort.y and not _deckt_held(ding):
                _vor_held.append(ding)
            else:
                _zeichne_hohes(ci, ding)
            continue
        var f: Gefecht.Feind = ding
        if f.ort.y > _stand.ort.y:
            _vor_held.append(f)
            continue
        _zeichne_feind(ci, f)
    for g in _stand.gefaehrten:
        if g.ort.y <= _stand.ort.y:
            _zeichne_gefaehrte(ci, g)


## **Ein hohes Ding im Figurenpuffer**: ohne eingebrannten Umriss, den gibt
## hier der Shader. Die Krone wiegt sich, wenn eine Windwelle durchgeht -
## dieselbe Welle wie ueber dem Gras (`boden_leben.gd`).
var _hohe_bilder := {}

func _hohes_bild(name: String, ausschlag: bool) -> Array:
    var k := name + ("|w" if ausschlag else "|r")
    var v: Variant = _hohe_bilder.get(k)
    if v == null:
        var d := Landschaft.bild_von(name)
        var schluessel := "hoch|" + k
        var r := Pixel.bild(schluessel, Landschaft.wiege(d[0], ausschlag),
            Landschaft.kleid(d[2]), d[1])
        v = [r, Pixel.anker(schluessel)]
        _hohe_bilder[k] = v
        Pixel.bereit()
    return v


func _zeichne_hohes(ci: RID, h: Array) -> void:
    var ort: Vector2 = h[0]
    var name: String = h[1]
    var welle := sin(_zeit * 2.1 - ort.x * 0.006 - ort.y * 0.004)
    var turm := name.begins_with("turm")
    _setze(ci, _hohes_bild(name, welle > 0.55 and not turm), ort)


## Wuerde dieses hohe Ding den Helden verdecken? Grob ueber seine Breite und
## Hoehe im Bild.
func _deckt_held(h: Array) -> bool:
    var ort: Vector2 = h[0]
    var b := _hohes_bild(h[1], false)
    var r: Rect2i = b[0]
    var breit := float(r.size.x) * P * 0.5 + 8.0 * P
    var hoch := float(r.size.y) * P
    var d := _stand.ort - ort
    return absf(d.x) < breit and d.y < 0.0 and d.y > -hoch - HELD_HOEHE * 0.2


## Fuer den Wolf: auf dem Ruecken statt gedreht - ein gedrehter Wolf steht
## auf dem Schwanz.
static func _kopfueber(zeilen: PackedStringArray) -> PackedStringArray:
    var aus := PackedStringArray()
    for i in range(zeilen.size() - 1, -1, -1):
        aus.append(zeilen[i])
    return aus


const MUENZE: PackedStringArray = [
    ".$$$.",
    "$$x$$",
    "$$$$%",
    "$$$$%",
    ".%%%.",
]
const MUENZE_BLINKT: PackedStringArray = [
    ".$x$.",
    "$xxx$",
    "$$x$%",
    "$$$$%",
    ".%%%.",
]


# --- Vorn: der Held, alles vor ihm, die Schlaege und Marken ----------------

func _zeichne_vorn(ci: RID) -> void:
    _zeichne_held(ci)

    for ding in _vor_held:
        if ding is Array:
            _zeichne_hohes(ci, ding)
        else:
            _zeichne_feind(ci, ding)
    for g in _stand.gefaehrten:
        if g.ort.y > _stand.ort.y:
            _zeichne_gefaehrte(ci, g)

    _zeichne_hiebe(ci)
    _zeichne_marke(ci)

    for g in _stand.geschosse:
        if not _im_bild(g.ort, 50.0):
            continue
        _zeichne_geschoss(ci, g)

    # **Funken als Pixel**: sie fliegen, fallen und verloeschen.
    for f in _funken:
        var t: float = f.alter / 0.55
        var c: Color = f.farbe
        var ort: Vector2 = f.ort + f.richtung * t * 0.55 + Vector2(0.0, 260.0 * t * t * 0.3)
        Pixel.punkt(ci, ort, Color(c.r, c.g, c.b, 1.0), 2 if t < 0.4 else 1)

    _zeichne_saeule(ci)
    _zeichne_flieger(ci)
    _zeichne_zahlen(ci)

    for r in _ringe:
        var u: float = r.alter / r.dauer
        var rad: float = lerpf(r.von, r.bis, 1.0 - pow(1.0 - u, 2.0))
        var c: Color = r.farbe
        # Zwei Bildpunkte breit: einer allein lag zwischen zwei Pixeln Umriss
        # und las sich als dunkler Reif statt als Licht.
        Pixel.ring(ci, r.ort, rad, Color(c.r, c.g, c.b, 1.0))
        Pixel.ring(ci, r.ort, rad - P, Color(c.r, c.g, c.b, 1.0))
        if u < 0.4:
            Pixel.ring(ci, r.ort, rad - 2.0 * P, Palette.WEISS)

    _zeichne_randpfeil(ci)


## **Ziffern aus Pixeln**, drei mal fuenf. Weiss fuer Schaden an Feinden,
## Zinnober fuer Schaden am Spieler - dieselbe Regel wie ueberall. Den
## Umriss gibt der Shader.
const ZIFFERN: Array = [
    ["xxx", "x.x", "x.x", "x.x", "xxx"], [".x.", "xx.", ".x.", ".x.", "xxx"],
    ["xxx", "..x", "xxx", "x..", "xxx"], ["xxx", "..x", ".xx", "..x", "xxx"],
    ["x.x", "x.x", "xxx", "..x", "..x"], ["xxx", "x..", "xxx", "..x", "xxx"],
    ["xxx", "x..", "xxx", "x.x", "xxx"], ["xxx", "..x", ".x.", ".x.", ".x."],
    ["xxx", "x.x", "xxx", "x.x", "xxx"], ["xxx", "x.x", "xxx", "..x", "xxx"],
]

func _ziffer(z: int, held: bool) -> Array:
    var zeilen := PackedStringArray()
    for zeile in ZIFFERN[z]:
        zeilen.append((zeile as String).replace("x", "z") if held else zeile)
    return _bild("ziffer%d_%d" % [z, int(held)], zeilen, Pixel.grund(), 0)


func _zeichne_zahlen(ci: RID) -> void:
    for z in _zahlen:
        var u: float = z.alter / ZAHL_DAUER
        # Am Ende blinkt sie aus, statt zu verblassen (siehe Gefallene).
        if u > 0.72 and fmod(z.alter, 0.08) < 0.04:
            continue
        var text := str(z.wert)
        var steig := (1.0 - pow(1.0 - minf(1.0, u * 1.6), 2.0)) * 12.0 * P
        var x: float = z.ort.x - float(text.length() * 4 - 1) * 0.5 * P
        for i in text.length():
            _setze(ci, _ziffer(int(text[i]), z.held),
                Vector2(x + float(i * 4) * P, z.ort.y - steig))


## **Sold fliegt zum Helden**, einen Augenblick lang, und verschwindet in ihm.
func _zeichne_flieger(ci: RID) -> void:
    var ziel := _stand.ort + Vector2(0.0, -HELD_HOEHE * 0.3)
    for fl in _flieger:
        var t: float = fl.alter / 0.2
        var e := t * t
        var ort: Vector2 = (fl.von as Vector2).lerp(ziel, e) + Vector2(0.0, -sin(t * PI) * 20.0)
        _setze(ci, _bild("muenze1", MUENZE_BLINKT, Pixel.grund(), 2), ort)


## **Die Lichtsaeule des Aufstiegs**: schiesst hoch und wird duenner.
func _zeichne_saeule(ci: RID) -> void:
    if _saeule <= 0.0:
        return
    var hoch := int(78.0 * minf(1.0, (1.0 - _saeule) * 5.0 + 0.15))
    var breit := 1 if _saeule < 0.35 else (2 if _saeule < 0.7 else 3)
    var fuss := _stand.ort + Vector2(0.0, -2.0 * P)
    for dx in range(-breit, breit + 1):
        var c := Palette.WEISS if absi(dx) < breit else _saeule_farbe
        Pixel.block(ci, fuss + Vector2(float(dx) * P, -float(hoch) * P), Vector2i(1, hoch), c)
    for k in 6:
        var y := fposmod(_zeit * 140.0 + float(k) * 41.0, float(hoch))
        Pixel.punkt(ci, fuss + Vector2(float(k - 3) * 2.0 * P, -y * P), Palette.WEISS)


## **Die Schlagbilder.** Jedes in der Richtung, Weite und Breite, mit der das
## Gefecht gerechnet hat - zwei Rechnungen waeren zwei Wahrheiten, und dann
## saehe man den Schwerthieb dort, wo er nicht traf.
func _zeichne_hiebe(ci: RID) -> void:
    var o := _stand.ort
    for h in _hiebe:
        var t: float = h.alter / h.dauer
        var r: Vector2 = h.richtung
        var weite: float = h.weite
        match int(h.waffe):
            Waffen.Art.SCHWERT:
                # Eine Sichel aus Pixeln, die von hinten nach vorn ueber den
                # Kegel faehrt: aussen Stahl, innen weiss, flach gelegt.
                var halb: float = h.halb
                var lauf := 1.0 - pow(1.0 - t, 2.0)
                var a0 := r.angle() - halb
                var a1 := a0 + halb * 2.0 * lauf
                var mitte := o + Vector2(0.0, -HELD_HOEHE * 0.35)
                var von := lerpf(a0, a1, 0.15 + 0.6 * t)
                Pixel.ring(ci, mitte, weite * 0.86, Palette.STAHL, 0.7, von, a1)
                Pixel.ring(ci, mitte, weite * 0.80, Palette.WEISS, 0.7, von, a1)
                Pixel.ring(ci, mitte, weite * 0.74, Palette.STAHL_HELL, 0.7,
                    lerpf(von, a1, 0.4), a1)
            Waffen.Art.SPEER:
                # Ein Stoss: weiss vorn, Stahl dahinter.
                var fuss := o + Vector2(0.0, -HELD_HOEHE * 0.30) + r * HELD_HOEHE * 0.2
                var spitze := o + Vector2(0.0, -HELD_HOEHE * 0.30) \
                    + r * weite * (0.35 + 0.65 * minf(1.0, t * 2.2))
                if t < 0.8:
                    Pixel.linie(ci, fuss, spitze, Palette.STAHL, 1)
                    Pixel.linie(ci, spitze - r * 26.0, spitze, Palette.WEISS, 2)
            Waffen.Art.HAMMER:
                # Eine Bodenwelle in Erde, nicht in Zinnober - sie trifft
                # Feinde, nicht dich. Dazu Brocken, die aufspritzen.
                var rad := weite * (0.25 + 0.75 * (1.0 - pow(1.0 - t, 2.0)))
                var erde := Palette.ERDE.darkened(0.35)
                Pixel.ring(ci, o, rad, erde, 0.42)
                if t < 0.6:
                    Pixel.ring(ci, o, rad - P, erde.darkened(0.2), 0.42)
                if t < 0.5:
                    for k in 8:
                        var w := TAU * float(k) / 8.0 + 0.4
                        var p := o + Vector2(cos(w) * rad, sin(w) * rad * 0.42)
                        Pixel.punkt(ci, p + Vector2(0.0, -18.0 * (1.0 - t * 2.0)), erde, 2)


## **Ein Geschoss hat eine Form.** Bolzen mit Schaft, Spitze und
## Befiederung, die Axt als drehendes Blatt. Der feindliche Bolzen bleibt in
## Zinnober und zieht seinen Schweif - ihm muss man ausweichen.
func _zeichne_geschoss(ci: RID, g: Gefecht.Geschoss) -> void:
    var r := g.richtung
    if g.feindlich:
        Pixel.linie(ci, g.ort - r * 44.0, g.ort - r * 8.0,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.45), 1)
        Pixel.linie(ci, g.ort - r * 12.0, g.ort + r * 4.0, Palette.HOLZ, 1)
        Pixel.punkt(ci, g.ort + r * 6.0, ZINNOBER, 2)
        return
    if g.waffe == Waffen.Art.AXT:
        var w := g.alter * 16.0 + g.start.x * 0.01
        var d := Vector2(cos(w), sin(w))
        var q := d.orthogonal()
        Pixel.linie(ci, g.ort - d * 12.0, g.ort + d * 10.0, Palette.HOLZ, 1)
        Pixel.linie(ci, g.ort + d * 8.0 - q * 3.0, g.ort + d * 8.0 + q * 10.0,
            Palette.STAHL_HELL, 2)
        return
    Pixel.linie(ci, g.ort - r * 16.0, g.ort + r * 6.0, Palette.HOLZ_HELL, 1)
    Pixel.punkt(ci, g.ort + r * 8.0, Palette.STAHL_HELL, 2)
    Pixel.punkt(ci, g.ort - r * 16.0, Palette.WEISS, 2)


## **Gezeichnet wird, was im Bild steht - nicht ein Quadrat darum.**
## `rand` ist, wie weit ein Ding ueber seinen Ort hinausragt. Figuren stehen
## auf ihren Fuessen und ragen **nach oben**: unten reicht ein kleiner Rand,
## oben braucht es ihre Hoehe.
var _sicht := Vector2(360.0, 800.0)

func _im_bild(ort: Vector2, rand: float) -> bool:
    var d := ort - _kamera_ort
    return absf(d.x) < _sicht.x + rand * 0.6 \
        and d.y > -_sicht.y - 30.0 and d.y < _sicht.y + rand


func _zeichne_feind(ci: RID, f: Gefecht.Feind) -> void:
    var tempo := 12.0 if f.art == Feinde.Art.WOLF else 8.0
    var bild := posmod(int(_zeit * tempo + f.ort.x * 0.013), 4)
    var b := _feind_bild(f.art, bild, f.blick < 0.0, f.zuckt > 0.0)
    var breite := 12 if f.art != Feinde.Art.WARLORD else 24
    if f.art == Feinde.Art.WOLF:
        breite = 14
    _schatten(ci, f.ort, breite)
    # **Bewegung im Bild, ohne die Rechnung anzufassen.** Alles hier verschiebt
    # nur, wo das Sprite steht - der Ort im Gefecht bleibt, wo er ist.
    var fuss := f.ort
    # Im Schritt eine Zeile hoeher: der Gang federt.
    if bild % 2 == 1:
        fuss.y -= P
    # Wer getroffen wird, zuckt einen Bildpunkt zurueck.
    if f.zuckt > 0.07 and f.stoss != Vector2.ZERO:
        fuss += f.stoss.normalized() * P
    # **Wer am Helden steht, holt aus**: in seinem eigenen Takt ein Ruck auf
    # ihn zu und ein heller Punkt, wo die Klinge ist. Der Schaden kommt aus
    # `Gefecht`, nicht von hier - das Bild zeigt nur, wer gerade zuschlaegt.
    var zu := _stand.ort - f.ort
    var nah := f.radius + Gefecht.STREITER_RADIUS + 16.0
    if f.art != Feinde.Art.ARMBRUSTER and zu.length_squared() < nah * nah:
        var takt := fposmod(_zeit * 2.3 + float(f.get_instance_id() % 97) * 0.137, 1.0)
        if takt < 0.2:
            var r := zu.normalized()
            fuss += r * P * 2.0
            if takt < 0.12:
                b = _feind_bild(f.art, Figuren.SCHLAG, f.blick < 0.0, f.zuckt > 0.0)
            if takt < 0.1:
                Pixel.punkt(ci, f.ort + r * (f.radius + 6.0) + Vector2(0.0, -FEIND_HOEHE * 0.35),
                    Palette.WEISS, 2)
    # Der Armbruster nach dem Schuss: Rueckstoss und ein Mundfeuer aus Pixeln.
    var rueck: float = _rueck.get(f.get_instance_id(), 0.0)
    if rueck > 0.0:
        var r := zu.normalized()
        fuss -= r * P
        b = _feind_bild(f.art, Figuren.SCHLAG, f.blick < 0.0, f.zuckt > 0.0)
        if rueck > 0.12:
            Pixel.punkt(ci, f.ort + r * 9.0 * P + Vector2(0.0, -12.0 * P), Palette.WEISS, 2)
    # Der Stuermer zieht Staubstreifen hinter sich her.
    if f.stuermt:
        var erde := Palette.ERDE.darkened(0.15)
        for k in 3:
            var h := Vector2(0.0, -float(2 + k * 5) * P)
            Pixel.linie(ci, f.ort - f.bahn * (20.0 + k * 6.0) + h,
                f.ort - f.bahn * (46.0 + k * 10.0) + h, Color(erde.r, erde.g, erde.b, 0.7), 1)
    _setze(ci, b, fuss)
    # **Ein Treffer splittert**: helle Pixel an der Brust, solange der
    # Getroffene zuckt - kein Zustand, nur was `zuckt` schon weiss.
    if f.zuckt > 0.06:
        var u := (0.14 - f.zuckt) / 0.08
        var p := f.ort + Vector2(0.0, -FEIND_HOEHE * 0.55)
        var l := (2.0 + 3.0 * u) * P
        for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
            Pixel.punkt(ci, p + d * l, Palette.WEISS)
    # **Der Stuermer kuendigt an.**
    if f.stuermt:
        Pixel.linie(ci, f.ort, f.ort + f.bahn * 90.0, ZINNOBER, 2)
    _zeichne_leben(ci, f)


## **Ein Balken nur ueber den Schweren**, und im Gedraenge nur ueber denen,
## die nah sind (siehe die alte Fassung in der Geschichte dieser Datei). Der
## Warlord behaelt seinen immer.
const BALKEN_NAH := 280.0

func _zeichne_leben(ci: RID, f: Gefecht.Feind) -> void:
    if f.art != Feinde.Art.RITTER and f.art != Feinde.Art.WARLORD:
        return
    if f.art == Feinde.Art.RITTER and f.ort.distance_to(_stand.ort) > BALKEN_NAH:
        return
    var teil := clampf(f.leben / maxf(1.0, f.leben_voll), 0.0, 1.0)
    if teil >= 0.999:
        return
    var breit := 12 if f.art == Feinde.Art.RITTER else 26
    var hoch := 26.0 if f.art == Feinde.Art.RITTER else 44.0
    _balken(ci, f.ort + Vector2(-float(breit) * 0.5 * P, -(hoch + 3.0) * P), breit, teil)


## Ein Lebensbalken im Pixelraster: dunkler Grund, gruene Fuellung.
func _balken(ci: RID, oben_links: Vector2, breit: int, teil: float) -> void:
    Pixel.block(ci, oben_links, Vector2i(breit, 2), Palette.LEBEN_LEER.darkened(0.3))
    var voll := int(round(float(breit) * teil))
    if voll > 0:
        Pixel.block(ci, oben_links, Vector2i(voll, 2), Palette.LEBEN_VOLL)


## Ring und Lebensbalken des Helden - **zuletzt und ueber allem**.
func _zeichne_marke(ci: RID) -> void:
    var s := _stand
    var n := Burg.stand.skin(s.held)
    var farbe := Skins.koerper(s.held, n)
    var r := HELD_HOEHE * 0.30
    for bogen in [[PI * 0.62, PI * 1.38], [-PI * 0.38, PI * 0.38]]:
        Pixel.ring(ci, s.ort + Vector2(0.0, 2.0 * P), r, farbe, 0.45, bogen[0], bogen[1])
        Pixel.ring(ci, s.ort + Vector2(0.0, 2.0 * P), r + P, farbe, 0.45, bogen[0], bogen[1])
    # **Sein Leben steht bei ihm, nicht nur oben am Schirm.**
    _balken(ci, s.ort + Vector2(-8.0 * P, 6.0 * P), 16,
        clampf(s.leben / maxf(1.0, s.leben_voll), 0.0, 1.0))


## **Ein Pfeil zeigt, woher der Warlord kommt** - in Zinnober, am Bildrand,
## als Pixelspitze.
const PFEIL_RAND := 56.0

func _zeichne_randpfeil(ci: RID) -> void:
    var warlord: Gefecht.Feind = null
    for f in _stand.feinde:
        if f.lebt and Feinde.ist_warlord(f.art):
            warlord = f
            break
    if warlord == null:
        return
    var halb := _sicht - Vector2(PFEIL_RAND, PFEIL_RAND)
    var d := warlord.ort - _kamera_ort
    if absf(d.x) <= halb.x + PFEIL_RAND and absf(d.y) <= halb.y + PFEIL_RAND:
        return
    var faktor := minf(halb.x / maxf(0.001, absf(d.x)),
        halb.y / maxf(0.001, absf(d.y)))
    var richtung := d.normalized()
    var spitze := _kamera_ort + d * faktor
    var quer := Vector2(-richtung.y, richtung.x)
    var gross := 52.0 * (1.0 + 0.10 * sin(_zeit * 6.0))
    var fuss := spitze - richtung * gross
    for k in 5:
        var u := float(k) / 4.0
        Pixel.linie(ci, fuss + quer * gross * 0.6 * (1.0 - u) + richtung * gross * u * 0.1,
            spitze, ZINNOBER, 2)
        Pixel.linie(ci, fuss - quer * gross * 0.6 * (1.0 - u) + richtung * gross * u * 0.1,
            spitze, ZINNOBER, 2)
    Pixel.linie(ci, fuss - richtung * gross * 0.4, spitze, ZINNOBER, 3)


func _zeichne_gefaehrte(ci: RID, g: Gefecht.Gefaehrte) -> void:
    var n := Burg.stand.skin(_stand.held)
    var kleid := Pixel.kleid(Skins.koerper(_stand.held, n), Skins.glanz(_stand.held, n))
    var bild := posmod(int(_zeit * 6.0 + g.ort.x * 0.02), 2)
    var spiegel := g.blick < 0.0
    var b := _bild("gef%d_%d_%d" % [_stand.held, n, bild], Figuren.gefaehrte(bild), kleid,
        Figuren.GEFAEHRTE_ANKER, spiegel)
    _schatten(ci, g.ort, 8)
    _setze(ci, b, g.ort)
    # Der Speer in der Hand, und er zuckt beim Schlag nach vorn.
    var blick := -1.0 if spiegel else 1.0
    var hand := g.ort + Vector2(float(Figuren.GEFAEHRTE_HAND.x) * blick,
        float(Figuren.GEFAEHRTE_HAND.y)) * P
    var aus := (5.0 + 6.0 * clampf(g.schlag / 0.18, 0.0, 1.0)) * P
    Pixel.linie(ci, hand - Vector2(3.0 * P * blick, 0.0), hand + Vector2(aus * blick, -P),
        Palette.HOLZ_HELL, 1)
    Pixel.punkt(ci, hand + Vector2((aus + P) * blick, -P), Palette.STAHL_HELL, 2)


func _zeichne_held(ci: RID) -> void:
    var s := _stand
    var blick := 1.0 if s.blick.x >= 0.0 else -1.0
    var laeuft := s.lauf.length_squared() > 0.02
    # **Jede Klasse haelt ihre Waffe anders**, und jede schlaegt anders: das
    # Schwert zieht durch, der Speer stoesst, die Armbrust zielt und zuckt
    # zurueck, der Hammer kommt von oben. In Ruhe liegt der Hammer auf der
    # Schulter und der Speer steht schraeg nach oben.
    var klasse := s.held
    var wiege := sin(_zeit * 2.2) * 0.06
    var ruhe := s.blick.angle() + 0.35 * blick + wiege
    var dauer := 0.22
    match klasse:
        KLASSE_BOGEN:
            ruhe = Vector2(blick, 0.15).angle() + wiege * 0.5
            dauer = 0.45
        KLASSE_SPEER:
            ruhe = Vector2(blick, -0.55).angle() + wiege * 0.5
        KLASSE_HAMMER:
            ruhe = Vector2(-0.35 * blick, -1.0).angle() + wiege * 0.5
            dauer = 0.32
    var schlag := 1.0
    if _schlag_alter < dauer:
        var t := _schlag_alter / dauer
        schlag = t
        var ziel := _schlag_richtung.angle()
        var e := 1.0 - pow(1.0 - t, 3.0)
        match klasse:
            KLASSE_BOGEN, KLASSE_SPEER:
                _waffe_winkel = lerp_angle(_waffe_winkel, ziel, 0.6)
            KLASSE_HAMMER:
                var oben := Vector2(-0.35 * blick, -1.0).angle()
                _waffe_winkel = lerp_angle(oben, ziel, e)
            _:
                _waffe_winkel = ziel + lerpf(-1.1, 0.9, e) * blick
    else:
        _waffe_winkel = lerp_angle(_waffe_winkel, ruhe, 0.25)
    # Das Gewand kommt aus dem Spielstand und nicht aus dem Gefecht: eine
    # Skin ist Zierde und darf in `Gefecht.Stand` nichts zu suchen haben.
    var n := Burg.stand.skin(s.held)
    var kleid := Pixel.kleid(Skins.koerper(s.held, n), Skins.glanz(s.held, n))
    _zeichne_druck(ci)
    var bild := posmod(int(_zeit * 9.0), 4) if laeuft else -1
    # Im Lauf weht der Umhang mit, im Stand ruht er; im Stand atmet der Held:
    # alle gut zwei Sekunden hebt er sich um eine Zeile.
    var weht := (posmod(bild, 2) + 1) if laeuft else 0
    var heb := Vector2.ZERO
    if laeuft and bild % 2 == 1:
        heb.y = -P
    elif not laeuft and fmod(_zeit, 2.2) < 0.9:
        heb.y = -P
    var b := _bild("held%d_%d_%d_%d" % [klasse, n, bild, weht],
        Figuren.weht(Figuren.held(klasse, bild), weht), kleid,
        Figuren.BEIN_ANKER + Figuren.WEHT_ANKER, blick < 0.0)
    # Beim Treffer blitzt er in Zinnober - Schaden am Spieler, die eine Stelle,
    # an der die Farbe des Helden kurz nicht seine eigene ist.
    var modul := Color.WHITE.lerp(Color(1.0, 0.42, 0.38), _wunde)
    _schatten(ci, s.ort, 14)
    _setze(ci, b, s.ort + heb, modul)
    _held_waffe(ci, klasse, blick, schlag, kleid, heb)

    # Der Flegel steht dauernd im Feld: Kette aus Gliedern, Kopf mit Stacheln.
    var stufe := s.waffe_stufe(Waffen.Art.FLEGEL)
    if stufe > 0:
        # `bahn_von`, dieselbe Rechnung wie im Gefecht.
        var weite := Gefecht.bahn_von(s, Waffen.Art.FLEGEL)
        var zahl := Waffen.zahl(Waffen.Art.FLEGEL, stufe)
        for i in zahl:
            var w := s.flegel_winkel + TAU * float(i) / float(zahl)
            var ort := s.ort + Vector2(cos(w), sin(w)) * weite
            for k in 4:
                Pixel.punkt(ci, s.ort.lerp(ort, (float(k) + 0.6) / 4.6), Palette.STAHL_TIEF)
            # Die Spur: ein Bogen hinter dem Kopf.
            Pixel.ring(ci, s.ort, weite, Color(Palette.STAHL.r, Palette.STAHL.g,
                Palette.STAHL.b, 0.45), 1.0, w - 0.8, w - 0.1)
            Pixel.scheibe(ci, ort, 2.6 * P, Palette.STAHL)
            Pixel.punkt(ci, ort + Vector2(-P, -P), Palette.STAHL_HELL)
            for k in 4:
                var ws := w * 2.0 + TAU * float(k) / 4.0
                Pixel.punkt(ci, ort + Vector2(cos(ws), sin(ws)) * 4.0 * P, Palette.STAHL_TIEF)


## **Arm und Waffe als Pixellinien**, im Winkel, den das Gefecht gerechnet
## hat. Ein gedrehtes Pixelbild zerfiele; eine gerasterte Linie bleibt scharf.
func _held_waffe(ci: RID, klasse: int, blick: float, schlag: float, kleid: Dictionary,
        heb := Vector2.ZERO) -> void:
    var s := _stand
    var schulter := s.ort + heb + Vector2(float(Figuren.HELD_SCHULTER.x) * blick,
        float(Figuren.HELD_SCHULTER.y)) * P
    var r := Vector2(cos(_waffe_winkel), sin(_waffe_winkel))
    var q := r.orthogonal()
    var reich := 5.0
    if klasse == KLASSE_SPEER:
        reich = 4.0 + 3.0 * sin(clampf(schlag, 0.0, 1.0) * PI)
    elif klasse == KLASSE_BOGEN:
        reich = 5.0 - 1.5 * (1.0 - clampf(schlag * 2.0, 0.0, 1.0))
    var hand := schulter + r * reich * P
    Pixel.linie(ci, schulter, hand, kleid["c"], 2)
    match klasse:
        KLASSE_BOGEN:
            var vorn := hand + r * 6.0 * P
            Pixel.linie(ci, hand - r * 2.0 * P, vorn, Palette.HOLZ, 2)
            Pixel.linie(ci, vorn - q * 4.0 * P - r * P, hand + r * P, Palette.UMRISS, 1)
            Pixel.linie(ci, vorn + q * 4.0 * P - r * P, hand + r * P, Palette.UMRISS, 1)
            Pixel.linie(ci, vorn - q * 4.0 * P - r * P, vorn + q * 4.0 * P - r * P,
                Palette.STAHL, 1)
        KLASSE_SPEER:
            Pixel.linie(ci, hand - r * 6.0 * P, hand + r * 15.0 * P, Palette.HOLZ_HELL, 1)
            Pixel.linie(ci, hand + r * 14.0 * P, hand + r * 18.0 * P, Palette.STAHL_HELL, 2)
        KLASSE_HAMMER:
            var kopf := hand + r * 9.0 * P
            Pixel.linie(ci, hand - r * P, kopf, Palette.HOLZ, 2)
            Pixel.linie(ci, kopf - q * 3.0 * P, kopf + q * 3.0 * P, Palette.STAHL, 3)
            Pixel.punkt(ci, kopf - q * 3.0 * P, Palette.STAHL_HELL)
        _:
            Pixel.linie(ci, hand, hand + r * 10.0 * P, Palette.STAHL_HELL, 2)
            Pixel.linie(ci, hand + r * 2.0 * P, hand + r * 10.0 * P, Palette.WEISS, 1)
            Pixel.linie(ci, hand - q * 2.0 * P, hand + q * 2.0 * P, Palette.STAHL_TIEF, 1)
    Pixel.punkt(ci, hand, Palette.HAUT, 2)


## Der Druckring am Boden: je ein Zinnoberbogen dort, wo ein Fach besetzt
## ist - aus `Stand.umzingelt`, derselben Zahl, aus der der Schaden faellt.
func _zeichne_druck(ci: RID) -> void:
    var s := _stand
    if s.druck_faecher == 0:
        return
    var u := s.umzingelt
    var farbe := Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.55 + 0.45 * u)
    var r := HELD_HOEHE * 0.46
    for i in Gefecht.SEKTOREN:
        if (s.druck_faecher & (1 << i)) == 0:
            continue
        # Mit Luecke zum Nachbarn: ein Reifen sagt nicht, aus welcher Richtung.
        var von := (float(i) + 0.14) * TAU / float(Gefecht.SEKTOREN) - PI
        var bis := (float(i) + 0.86) * TAU / float(Gefecht.SEKTOREN) - PI
        Pixel.ring(ci, s.ort, r, farbe, 0.37, von, bis)
        if u > 0.5:
            Pixel.ring(ci, s.ort, r + P, farbe, 0.37, von, bis)


## --- Was das Bedienbild fragt ---

func stand() -> Gefecht.Stand:
    return _stand


func stick_von() -> Vector2:
    return _von


func stick_jetzt() -> Vector2:
    return _jetzt


func zieht() -> bool:
    return _zieht


## Wie frisch der letzte Treffer am Helden ist - fuer den roten Bildrand.
func wunde() -> float:
    return _wunde


## Deckung des Einstiegshinweises, null bis eins. Er gilt nur, solange
## `einstieg` null ist - bis zum Ende des ersten Laufs -, und geht, sobald
## man sich bewegt hat. Das Feld stand schon im Spielstand und wurde nur
## gesetzt, nie gelesen.
func hinweis() -> float:
    if Burg.stand.einstieg != 0:
        return 0.0
    return clampf(1.0 - _gezogen / HINWEIS_WEG, 0.0, 1.0)


func fund() -> int:
    return _fund


func fund_stufe() -> int:
    return _fund_stufe


func waehle(welches: int) -> void:
    if _stand == null:
        return
    Gefecht.nimm(_stand, welches)
    Klang.spiele(Klang.Ton.TIPP)


## --- Der Messstand ---

func _lies_schalter() -> void:
    var args := OS.get_cmdline_user_args()
    var schuss := ""
    var zeit := 0.0
    var held := -1
    var stufen_n := 0
    var neu := false
    var wahl := false
    var ende := false
    # **Ein Schuss spielt mit leerem Spielstand und schreibt keinen.** Sonst
    # trug er die Funde aller Schuesse davor, und dieselbe Saat gab zwei
    # verschiedene Gefechte.
    if args.has("--schuss"):
        Burg.schreibt = false
        Burg.stand = BurgStand.new()
    for i in args.size():
        match args[i]:
            "--schuss":
                if i + 1 < args.size():
                    schuss = args[i + 1]
            "--zeit":
                if i + 1 < args.size():
                    zeit = float(args[i + 1])
            "--held":
                if i + 1 < args.size():
                    held = int(args[i + 1])
            "--marke":
                marke = true
            "--wahl":
                # Nach dem Vorlauf steht ein Aufstieg offen: der Schirm der
                # einzigen Entscheidung im Lauf, sonst auf keinem Schuss.
                wahl = true
            "--ende":
                # Nach dem Vorlauf endet der Lauf: der Bericht.
                ende = true
            "--saat":
                # **Vorher und nachher zeigen dieselbe Szene.** Ohne feste
                # Saat ist jeder Schuss ein anderer Lauf, und ein Vergleich
                # zweier Zeichnungen wird ein Vergleich zweier Gefechte.
                if i + 1 < args.size():
                    _rng.seed = int(args[i + 1])
            "--neu":
                # Fuer den Schuss des Einstiegshinweises: `--held` setzt
                # `einstieg`, dieser Schalter nimmt es danach zurueck.
                neu = true
            "--lage":
                # Fuer Schuesse von Titel, Burg und Beutel. Was man nicht
                # angesehen hat, ist geraten.
                if i + 1 < args.size():
                    lage = clampi(int(args[i + 1]), 0, Lage.size() - 1)
            "--stufen":
                if i + 1 < args.size():
                    var n := int(args[i + 1])
                    stufen_n = n
                    for b in Halle.NAMEN.size():
                        Burg.stand.stufen[b] = n
                    # **Auch der Beutel.** Ein Schalter, der die halbe
                    # Wahrheit setzt, zeigt ein Spiel, das es nicht gibt.
                    Burg.stand.sold = Halle.kosten(0, n) * 3
                    Burg.stand.beste_zeit = 600.0
                    Burg.stand.meiste_erschlagen = 400
                    Burg.stand.warlord_gefallen = true
    if held >= 0:
        Burg.stand.einstieg = 0 if neu else 1
        _mit_daumen = true
        beginne(held)
        # **Auch die Zuege.** Derselbe Grundsatz wie beim Beutel: ein
        # Schalter, der die halbe Wahrheit setzt, zeigt ein Spiel, das es
        # nicht gibt. Der simulierte Daumen nimmt lieber neue Waffen als
        # neue Zuege - ohne das hier bekaeme man den Gefaehrten auf keinem
        # Schuss zu sehen, obwohl er im Spiel steht.
        if stufen_n > 0 and _stand != null:
            for z in Gunst.Zug.size():
                _stand.zuege[z] = clampi(stufen_n, 1, Gunst.ZUG_HOECHSTSTUFE)
    if schuss != "":
        _hud.ohne_zeit = true
    if zeit > 0.0:
        _treibe_vor(zeit)
    if wahl and _stand != null and not _stand.wartet_auf_wahl:
        _stand.angebote = Gunst.angebote(_stand.waffen, _stand.zuege, _rng)
        _stand.wartet_auf_wahl = not _stand.angebote.is_empty()
    if ende and _stand != null and lage == Lage.LAUF:
        _beende()
    if schuss != "":
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(schuss)
        get_tree().quit()


## Treibt **jeden** Knoten mit eigenem `_process`, nicht nur diesen. Ein
## Vorlauf, in dem der Grund still steht und die Figuren altern, zeigt ein
## Bild, das im Spiel nie vorkommt.
func _treibe_vor(sekunden: float) -> void:
    var takt := 1.0 / 60.0
    _vorlauf = true
    for i in int(sekunden / takt):
        # **Auch die Wahl gehoert dem Daumen.** Hier stand `nimm(_stand, 0)`:
        # der Schuss nahm stets das erste Angebot, der Messstand das, was
        # `Daumen.waehle()` sagt. Gleicher Lauf, zwei Aufstiegsfolgen - und
        # damit zeigte das Bild ein anderes Spiel, als `tools/probe.gd` mass.
        if _stand != null and _stand.wartet_auf_wahl:
            Gefecht.nimm(_stand, Daumen.waehle(_stand))
        _process(takt)
        _hud._process(takt)
    _vorlauf = false
