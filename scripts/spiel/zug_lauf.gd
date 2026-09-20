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
var _tu := Tusche.new()
var _zeit := 0.0
var _kamera_ort := Vector2.ZERO
var _ruettel := 0.0
var _tod_sperre := 0.0
var _hieb_sperre := 0.0
var _waffe_winkel := 0.0

var _zieht := false
var _von := Vector2.ZERO
var _jetzt := Vector2.ZERO

var _funken: Array = []
var _fund := -1
var _fund_stufe := 0

@onready var _kamera: Camera2D = $Kamera
@onready var _feld: Node2D = $Feld
@onready var _hud: Control = $Oberflaeche/Hud


func _ready() -> void:
    _rng.randomize()
    RenderingServer.set_default_clear_color(PERGAMENT)
    Klang.laut = Burg.stand.laut
    Tastsinn.an = Burg.stand.beben
    _kamera.make_current()
    set_process(true)
    _lies_schalter()


## --- Die Schleife ---

func beginne(held: int) -> void:
    Burg.stand.held = held
    _stand = Gefecht.baue(Burg.stand.stufen, held, Burg.stand.getragen())
    _funken.clear()
    _fund = -1
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

    if lage == Lage.LAUF and _stand != null:
        Gefecht.schritt(_stand, minf(delta, 1.0 / 30.0), _eingabe(), _rng)
        _werte_aus()
        _kamera_ort = _kamera_ort.lerp(_stand.ort, clampf(delta * 7.0, 0.0, 1.0))
        _kamera.position = _kamera_ort
        _feld.setze_mitte(_kamera_ort)
        if Gefecht.vorbei(_stand):
            _beende()
    queue_redraw()


## Der Stick: relativ zum Aufsetzpunkt, nicht an einer festen Ecke. Auf einem
## Telefon haelt niemand den Daumen dort, wo ein Entwerfer ihn hingelegt hat.
var _mit_daumen := false

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
            Gefecht.Vorfall.FEIND_FAELLT:
                if _tod_sperre <= 0.0:
                    _tod_sperre = TOD_SPERRE
                    Klang.spiele(Klang.Ton.TREFFER, 0.85 + randf() * 0.4, 0.7)
                var f: Gefecht.Feind = v[1]
                # **Der Funke traegt die Farbe dessen, der faellt.** Zinnober
                # bleibt dem Schaden am Spieler vorbehalten - darf alles rot
                # spritzen, heisst Rot nichts mehr.
                _spritz(f.ort, Palette.sorte(f.art), 4)
            Gefecht.Vorfall.STREITER_GETROFFEN:
                Klang.spiele(Klang.Ton.WUNDE)
                Tastsinn.gib(Tastsinn.Art.WUNDE)
                _ruettel = 1.0
                _spritz(_stand.ort + Vector2(0.0, -HELD_HOEHE * 0.5), ZINNOBER, 6)
            Gefecht.Vorfall.SCHUSS:
                Klang.spiele(Klang.Ton.BOLZEN, 1.0, 0.45)
            Gefecht.Vorfall.MUENZE:
                Klang.spiele(Klang.Ton.MUENZE, 0.95 + randf() * 0.3, 0.35)
            Gefecht.Vorfall.AUFSTIEG:
                Klang.spiele(Klang.Ton.AUFSTIEG)
                Tastsinn.gib(Tastsinn.Art.SCHNITT)
            Gefecht.Vorfall.WARLORD:
                Klang.spiele(Klang.Ton.HORN)
                Tastsinn.gib(Tastsinn.Art.ENDE)
                _ruettel = 1.4


func _spritz(ort: Vector2, farbe: Color, zahl: int) -> void:
    for i in zahl:
        var w := _rng.randf() * TAU
        _funken.append({"ort": ort, "farbe": farbe, "alter": 0.0,
            "richtung": Vector2(cos(w), sin(w)) * (70.0 + _rng.randf() * 150.0),
            "gross": 2.0 + _rng.randf() * 3.4})


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

func _draw() -> void:
    if lage != Lage.LAUF or _stand == null:
        return
    if _ruettel > 0.0:
        draw_set_transform(Vector2(sin(_zeit * 57.0), cos(_zeit * 43.0))
            * _ruettel * 7.0, 0.0, Vector2.ONE)

    # Sold zuerst: er liegt am Boden, also unter allem.
    for m in _stand.muenzen:
        var blinkt := 0.75 + 0.25 * sin(_zeit * 7.0 + m.ort.x * 0.05)
        _tu.klecks(m.ort, 7.0, Color(GOLD.r, GOLD.g, GOLD.b, blinkt), int(m.ort.x))

    # **Nach y sortiert, nicht nach Listenplatz.** Ohne das steht ein Feind
    # vor dem Helden, der hinter ihm ist - und in einem Bild ohne Perspektive
    # ist die Zeichenreihenfolge die einzige Tiefe, die es gibt.
    var sichtbar: Array = []
    var rand := 720.0
    for f in _stand.feinde:
        if absf(f.ort.x - _kamera_ort.x) < rand and absf(f.ort.y - _kamera_ort.y) < rand:
            sichtbar.append(f)
    sichtbar.sort_custom(func(a, b): return a.ort.y < b.ort.y)
    var knapp := sichtbar.size() > Streiter.DICHT_AB

    var vor_held: Array = []
    for f in sichtbar:
        if f.ort.y > _stand.ort.y:
            vor_held.append(f)
            continue
        _zeichne_feind(f, knapp)

    _zeichne_held()

    for f in vor_held:
        _zeichne_feind(f, knapp)

    for g in _stand.geschosse:
        var farbe := ZINNOBER if g.feindlich else TINTE
        _tu.zug(g.ort - g.richtung * 18.0, g.ort + g.richtung * 12.0, 5.0,
            farbe, 0.6, 0.3, 0.0, 4)

    for f in _funken:
        var t: float = f.alter / 0.55
        var c: Color = f.farbe
        _tu.zug(f.ort, f.ort + f.richtung * t, f.gross * (1.0 - t * 0.6),
            Color(c.r, c.g, c.b, (1.0 - t) * 0.85), 0.0, 0.7, 0.0, 3)

    _tu.spuele(get_canvas_item())


func _zeichne_feind(f: Gefecht.Feind, knapp: bool) -> void:
    var h := FEIND_HOEHE * (f.radius / 17.0)
    var phase := _zeit * 7.0 + f.ort.x * 0.05
    Streiter.feind(_tu, f.ort, h, f.blick, f.art, phase, f.zuckt, knapp)
    # **Der Stuermer kuendigt an.** Ein Angriff, den man nicht kommen sieht,
    # ist kein Angriff, sondern eine Steuer - dieselbe Regel wie im vorigen
    # Spiel, nur mit einem anderen Zeichen.
    if f.stuermt:
        _tu.zug(f.ort, f.ort + f.stoss * 90.0, 6.0,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.7), 0.7, 0.4, 0.0, 4)
    _zeichne_leben(f, h)


## **Ein Balken nur ueber den Schweren.** Der Ritter und der Warlord sind die
## beiden, bei denen die Frage *wie lange noch* ueberhaupt auftaucht; ein
## Strolch faellt beim ersten oder zweiten Schlag. Hundertfuenfzig Balken
## waeren hundertfuenfzig Dinge im Bild, die kein Feind sind - und was einen
## Hintergrund laut macht, ist die Zahl der getrennten Dinge darin.
func _zeichne_leben(f: Gefecht.Feind, h: float) -> void:
    if f.art != Feinde.Art.RITTER and f.art != Feinde.Art.WARLORD:
        return
    var teil := clampf(f.leben / maxf(1.0, f.leben_voll), 0.0, 1.0)
    if teil >= 0.999:
        return
    var breit := h * 0.34
    var oben := f.ort + Vector2(0.0, -h * 1.10)
    _riegel(oben, breit, h * 0.035, teil, Palette.LEBEN_VOLL)


## Ein liegender Balken: **ueberall dieselbe Hoehe**. Als `zug()` gebaut
## schwillt er zur Mitte an, und ueber dem Kopf stuende eine Linse mit
## spitzen Enden - man liest einen Balken an seiner Laenge, und eine Laenge
## mit spitzen Enden laesst sich nicht ablesen.
func _riegel(mitte: Vector2, breit: float, hoch: float, teil: float,
        farbe: Color) -> void:
    var links := mitte - Vector2(breit, 0.0)
    var rechts := mitte + Vector2(breit, 0.0)
    _tu.band(PackedVector2Array([links, rechts]),
        PackedFloat32Array([hoch, hoch]), Palette.LEBEN_LEER,
        PackedFloat32Array([1.0, 1.0]), Palette.UMRISS)
    if teil <= 0.0:
        return
    var ende := links.lerp(rechts, teil)
    _tu.band(PackedVector2Array([links, ende]),
        PackedFloat32Array([hoch * 0.62, hoch * 0.62]), farbe,
        PackedFloat32Array([1.0, 1.0]))


func _zeichne_held() -> void:
    var s := _stand
    var blick := 1.0 if s.blick.x >= 0.0 else -1.0
    var laeuft := s.lauf.length_squared() > 0.02
    var phase := _zeit * 9.0 if laeuft else 0.0
    # Die Waffe zeigt dorthin, wo der Schlag gerechnet wurde - sie schwingt
    # mit dem Takt der schnellsten Waffe.
    _waffe_winkel = s.blick.angle() + sin(_zeit * 6.0) * 0.45
    # Das Gewand kommt aus dem Spielstand und nicht aus dem Gefecht: eine
    # Skin ist Zierde und darf in `Gefecht.Stand` nichts zu suchen haben.
    var n := Burg.stand.skin(s.held)
    var kleid := Skins.koerper(s.held, n)
    var glanz := Skins.glanz(s.held, n)
    Streiter.frei_gestellt(_tu, s.ort, HELD_HOEHE, Palette.BODEN, kleid)
    _zeichne_druck()
    Streiter.held(_tu, s.ort, HELD_HOEHE, blick, phase, _waffe_winkel,
        kleid, glanz)
    # **Sein Leben steht bei ihm, nicht nur oben am Schirm.** Der Balken oben
    # sagt, wie es steht; dieser sagt es dort, wo der Blick ohnehin liegt -
    # und im Gedraenge schaut niemand an den Bildrand.
    _riegel(s.ort + Vector2(0.0, HELD_HOEHE * 0.17), HELD_HOEHE * 0.26,
        HELD_HOEHE * 0.024,
        clampf(s.leben / maxf(1.0, s.leben_voll), 0.0, 1.0),
        Palette.LEBEN_VOLL)

    # Der Flegel steht dauernd im Feld, also gehoert er ins Bild und nicht in
    # eine Wirkung: was Schaden macht, muss man sehen.
    var stufe := s.waffe_stufe(Waffen.Art.FLEGEL)
    if stufe > 0:
        # `bahn_von`, dieselbe Rechnung wie im Gefecht. Zwei Rechnungen
        # waeren zwei Wahrheiten, und dann schlaegt der Flegel woanders zu,
        # als er im Bild steht.
        var weite := Gefecht.bahn_von(s, Waffen.Art.FLEGEL)
        var zahl := Waffen.zahl(Waffen.Art.FLEGEL, stufe)
        for i in zahl:
            var w := s.flegel_winkel + TAU * float(i) / float(zahl)
            var ort := s.ort + Vector2(cos(w), sin(w)) * weite
            _tu.zug(s.ort, ort, 3.0, Color(TINTE.r, TINTE.g, TINTE.b, 0.5),
                0.5, 0.2, 0.0, 3)
            # Stahl, nicht der helle Glanz des Helden: als HELD_GLANZ waren
            # die Koepfe drei helle Scheiben und lasen sich als Blasen.
            _tu.klecks(ort, 12.0, Color(0.60, 0.63, 0.67), i, Palette.UMRISS)



## Der Druckring am Boden: je ein Zinnoberbogen dort, wo ein Fach besetzt
## ist. Eine Strafe, die man nicht kommen sieht, ist keine Regel, sondern
## ein Unfall - und die Zahl kommt aus `Stand.umzingelt`, derselben, aus
## der der Schaden faellt. Zwei Rechnungen waeren zwei Wahrheiten.
func _zeichne_druck() -> void:
    var s := _stand
    if s.druck_faecher == 0:
        return
    var u := s.umzingelt
    # Flach gelegt: das Feld ist von oben gesehen, die Figuren stehen
    # aufrecht. Ein runder Ring laege senkrecht in der Luft.
    var rx := HELD_HOEHE * 0.46
    var ry := HELD_HOEHE * 0.17
    var hoch := HELD_HOEHE * 0.04
    # **Kraeftig genug, um es zu sehen.** Der erste Anlauf zeichnete
    # Haarstriche von knapp vier Punkten Breite bei dreissig Prozent Deckung:
    # im Schuss war neben dem Helden nichts zu erkennen, obwohl der Ring
    # gerechnet wurde. Ein Zeichen, das man suchen muss, zeigt nichts an.
    var farbe := Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.50 + 0.45 * u)
    var dick := HELD_HOEHE * (0.030 + 0.045 * u)
    var stuecke := 6
    for i in Gefecht.SEKTOREN:
        if (s.druck_faecher & (1 << i)) == 0:
            continue
        var mitte := PackedVector2Array()
        var halb := PackedFloat32Array()
        var deck := PackedFloat32Array()
        for k in stuecke:
            var t := float(k) / float(stuecke - 1)
            # Mit Luecke zum Nachbarn. Acht Striche ohne Luecke sind ein
            # Reifen, und ein Reifen sagt nicht, aus welcher Richtung.
            var w := (float(i) + 0.14 + 0.72 * t) * TAU / float(Gefecht.SEKTOREN) - PI
            mitte.append(s.ort + Vector2(cos(w) * rx, sin(w) * ry - hoch))
            halb.append(dick * (0.18 + 0.82 * sin(t * PI)))
            deck.append(1.0)
        _tu.band(mitte, halb, farbe, deck)


## --- Was das Bedienbild fragt ---

func stand() -> Gefecht.Stand:
    return _stand


func stick_von() -> Vector2:
    return _von


func stick_jetzt() -> Vector2:
    return _jetzt


func zieht() -> bool:
    return _zieht


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
            "--lage":
                # Fuer Schuesse von Titel, Burg und Beutel. Was man nicht
                # angesehen hat, ist geraten.
                if i + 1 < args.size():
                    lage = clampi(int(args[i + 1]), 0, Lage.size() - 1)
            "--stufen":
                if i + 1 < args.size():
                    var n := int(args[i + 1])
                    for b in Halle.NAMEN.size():
                        Burg.stand.stufen[b] = n
                    # **Auch der Beutel.** Ein Schalter, der die halbe
                    # Wahrheit setzt, zeigt ein Spiel, das es nicht gibt.
                    Burg.stand.sold = Halle.kosten(0, n) * 3
                    Burg.stand.beste_zeit = 600.0
                    Burg.stand.meiste_erschlagen = 400
                    Burg.stand.warlord_gefallen = true
    if held >= 0:
        Burg.stand.einstieg = 1
        _mit_daumen = true
        beginne(held)
    if zeit > 0.0:
        _treibe_vor(zeit)
    if schuss != "":
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(schuss)
        get_tree().quit()


## Treibt **jeden** Knoten mit eigenem `_process`, nicht nur diesen. Ein
## Vorlauf, in dem der Grund still steht und die Figuren altern, zeigt ein
## Bild, das im Spiel nie vorkommt.
func _treibe_vor(sekunden: float) -> void:
    var takt := 1.0 / 60.0
    for i in int(sekunden / takt):
        if _stand != null and _stand.wartet_auf_wahl:
            Gefecht.nimm(_stand, 0)
        _process(takt)
        for kind in get_children():
            if kind.has_method("_process"):
                kind._process(takt)
