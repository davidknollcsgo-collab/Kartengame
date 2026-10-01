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
var _tu := Tusche.new()
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
const GEFALLEN_DAUER := 0.7
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
    _gefallene = _gefallene.filter(func(g): return g.alter < GEFALLEN_DAUER)
    for s in _staub:
        s.alter += delta
    _staub = _staub.filter(func(s): return s.alter < s.dauer)
    for r in _ringe:
        r.alter += delta
    _ringe = _ringe.filter(func(r): return r.alter < r.dauer)
    _wunde = maxf(0.0, _wunde - delta * 2.5)
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
        Gefecht.schritt(_stand, minf(delta, 1.0 / 30.0), eingabe, _rng)
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
                # **Der Funke traegt die Farbe dessen, der faellt.** Zinnober
                # bleibt dem Schaden am Spieler vorbehalten - darf alles rot
                # spritzen, heisst Rot nichts mehr.
                _spritz(f.ort, Palette.sorte(f.art), 4)
                if _gefallene.size() < GEFALLEN_HOECHSTENS and _im_bild(f.ort, 60.0):
                    _gefallene.append({"ort": f.ort, "art": f.art,
                        "blick": f.blick, "alter": 0.0,
                        "h": FEIND_HOEHE * (f.radius / 17.0)})
                    _staub.append({"ort": f.ort, "alter": 0.0, "dauer": 0.5,
                        "gross": 13.0})
            Gefecht.Vorfall.STREITER_GETROFFEN:
                Klang.spiele(Klang.Ton.WUNDE)
                Tastsinn.gib(Tastsinn.Art.WUNDE)
                _ruettel = 1.0
                _wunde = 1.0
                _spritz(_stand.ort + Vector2(0.0, -HELD_HOEHE * 0.5), ZINNOBER, 6)
            Gefecht.Vorfall.SCHUSS:
                Klang.spiele(Klang.Ton.BOLZEN, 1.0, 0.45)
            Gefecht.Vorfall.MUENZE:
                Klang.spiele(Klang.Ton.MUENZE, 0.95 + randf() * 0.3, 0.35)
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
            Gefecht.Vorfall.WARLORD:
                Klang.spiele(Klang.Ton.HORN)
                Tastsinn.gib(Tastsinn.Art.ENDE)
                _ruettel = 1.4


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

func _draw() -> void:
    if lage != Lage.LAUF or _stand == null:
        return
    if _ruettel > 0.0:
        draw_set_transform(Vector2(sin(_zeit * 57.0), cos(_zeit * 43.0))
            * _ruettel * 7.0, 0.0, Vector2.ONE)

    _sicht = get_viewport_rect().size * 0.5

    # Was am Boden liegt, zuerst: Staub, Gefallene, Sold.
    for st in _staub:
        var u: float = st.alter / st.dauer
        var erde := Palette.ERDE.darkened(0.15)
        _tu.klecks(st.ort + Vector2(0.0, -u * 8.0), st.gross * (0.6 + u),
            Color(erde.r, erde.g, erde.b, 0.45 * (1.0 - u)), int(st.ort.x))
    for g in _gefallene:
        var u: float = g.alter / GEFALLEN_DAUER
        Streiter.gefallen(_tu, g.ort, g.h, g.blick, g.art,
            1.0 if u < 0.5 else 1.0 - (u - 0.5) * 2.0)
    # **Eine Muenze glaenzt.** Vorher ein blinkender gelber Fleck; jetzt mit
    # dunklerem Rand und einem Lichtpunkt, der ueber sie wandert.
    var gold_rand := GOLD.darkened(0.35)
    for m in _stand.muenzen:
        if not _im_bild(m.ort, 20.0):
            continue
        var schein := 0.5 + 0.5 * sin(_zeit * 5.0 + m.ort.x * 0.05)
        _tu.klecks(m.ort, 7.5, GOLD, int(m.ort.x), gold_rand)
        _tu.klecks(m.ort + Vector2(-2.2, -2.4), 2.4,
            Color(1.0, 0.98, 0.85, 0.5 + 0.5 * schein), int(m.ort.y))

    # **Nach y sortiert, nicht nach Listenplatz.** Ohne das steht ein Feind
    # vor dem Helden, der hinter ihm ist - und in einem Bild ohne Perspektive
    # ist die Zeichenreihenfolge die einzige Tiefe, die es gibt.
    var sichtbar: Array = []
    for f in _stand.feinde:
        if _im_bild(f.ort, FEIND_HOEHE * 1.4):
            sichtbar.append(f)
    sichtbar.sort_custom(func(a, b): return a.ort.y < b.ort.y)
    var knapp := sichtbar.size() > Streiter.DICHT_AB
    # **Die Naechsten voll, der Rest sparsam.** Vorher galt alles oder
    # nichts: bis `DICHT_AB` Figuren jede in voller Fassung, darueber jede
    # sparsam. An dieser Klippe kostete ein Bild mit siebzig Vollfiguren
    # doppelt so viel wie eines mit einundsiebzig sparsamen, und im Gedraenge
    # hatte auch der Feind direkt vor dem Helden keine Haende. Jetzt bekommen
    # die `VOLL_NAH` naechsten die volle Fassung - dort schaut man hin -, und
    # die Kosten sind nach oben begrenzt.
    _voll_bis = INF
    if sichtbar.size() > VOLL_NAH:
        var abstaende := PackedFloat32Array()
        for f in sichtbar:
            abstaende.append(f.ort.distance_squared_to(_stand.ort))
        abstaende.sort()
        _voll_bis = abstaende[VOLL_NAH - 1]

    # **Die Ansage liegt am Boden, unter allen Figuren.** Ein Band in
    # Zinnober entlang der Bahn, das sich bis zum Sturm füllt: so weit trägt
    # er, und so viel Zeit bleibt. Zinnober heißt Schaden am Spieler - und
    # genau den kündigt es an.
    for f in sichtbar:
        if f.angesagt and not f.stuermt:
            var weite: float = Feinde.sturm_weite(f.art)
            var voll: float = clampf(1.0 - f.uhr / Feinde.STURM_ANSAGE, 0.0, 1.0)
            var breite: float = f.radius * 0.9
            _tu.zug(f.ort, f.ort + f.bahn * weite, breite,
                Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.24), 0.2, 0.2, 0.0, 4)
            _tu.zug(f.ort, f.ort + f.bahn * weite * voll, breite * 0.7,
                Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.50), 0.2, 0.4, 0.0, 4)

    # **Die Gefaehrten laufen in derselben Sortierung mit.** In einem Bild
    # ohne Perspektive ist die Zeichenreihenfolge die einzige Tiefe, die es
    # gibt - ein Begleiter, der immer oben liegt, steht vor Feinden, hinter
    # denen er steht.
    var vor_held: Array = []
    for f in sichtbar:
        if f.ort.y > _stand.ort.y:
            vor_held.append(f)
            continue
        _zeichne_feind(f, knapp)
    for g in _stand.gefaehrten:
        if g.ort.y <= _stand.ort.y:
            _zeichne_gefaehrte(g)

    _zeichne_held()

    for f in vor_held:
        _zeichne_feind(f, knapp)
    for g in _stand.gefaehrten:
        if g.ort.y > _stand.ort.y:
            _zeichne_gefaehrte(g)

    _zeichne_hiebe()
    _zeichne_marke()

    for g in _stand.geschosse:
        if not _im_bild(g.ort, 50.0):
            continue
        _zeichne_geschoss(g)

    for f in _funken:
        var t: float = f.alter / 0.55
        var c: Color = f.farbe
        _tu.zug(f.ort, f.ort + f.richtung * t, f.gross * (1.0 - t * 0.6),
            Color(c.r, c.g, c.b, (1.0 - t) * 0.85), 0.0, 0.7, 0.0, 3)

    for r in _ringe:
        var u: float = r.alter / r.dauer
        var rad: float = lerpf(r.von, r.bis, 1.0 - pow(1.0 - u, 2.0))
        var c: Color = r.farbe
        var bahn := PackedVector2Array()
        var breit := PackedFloat32Array()
        for k in 19:
            var w := TAU * float(k) / 18.0
            bahn.append(r.ort + Vector2(cos(w) * rad, sin(w) * rad * 0.5))
            breit.append(lerpf(5.0, 1.5, u))
        _tu.band(bahn, breit, Color(c.r, c.g, c.b, 0.9 * (1.0 - u)),
            PackedFloat32Array())

    _zeichne_randpfeil()
    _tu.spuele(get_canvas_item())


## Stahl fuer alles, was der Held schwingt und wirft. Hell und kalt, aber nicht
## sein Blau - das traegt niemand sonst.
const STAHL := Color(0.86, 0.87, 0.85)
const HOLZ := Color(0.47, 0.35, 0.22)

## **Die Schlagbilder.** Jedes in der Richtung, Weite und Breite, mit der das
## Gefecht gerechnet hat - zwei Rechnungen waeren zwei Wahrheiten, und dann
## saehe man den Schwerthieb dort, wo er nicht traf.
func _zeichne_hiebe() -> void:
    var o := _stand.ort
    for h in _hiebe:
        var t: float = h.alter / h.dauer
        var r: Vector2 = h.richtung
        var weite: float = h.weite
        match int(h.waffe):
            Waffen.Art.SCHWERT:
                # Eine Sichel, die von hinten nach vorn ueber den Kegel faehrt:
                # vorn breit und hell, hinten duenn und ausgelaufen. Flach
                # gelegt (y x 0,7), weil das Feld von oben gesehen ist.
                var halb: float = h.halb
                var lauf := 1.0 - pow(1.0 - t, 2.0)
                var a0 := r.angle() - halb
                var spanne := halb * 2.0 * lauf
                var mitte := PackedVector2Array()
                var breit := PackedFloat32Array()
                var deck := PackedFloat32Array()
                var n := 9
                for k in n:
                    var u := float(k) / float(n - 1)
                    var w := a0 + spanne * u
                    var rad := weite * (0.60 + 0.30 * u)
                    mitte.append(o + Vector2(cos(w) * rad, sin(w) * rad * 0.7)
                        + Vector2(0.0, -HELD_HOEHE * 0.40))
                    breit.append(HELD_HOEHE * (0.03 + 0.16 * u))
                    deck.append((0.15 + 0.85 * u) * (1.0 - t * t))
                # **Kraeftig genug, um es zu sehen.** Der erste Anlauf lief bis
                # zur Haelfte durchsichtig aus und war im Schuss ein Splitter.
                _tu.band(mitte, breit, Color(STAHL.r, STAHL.g, STAHL.b, 0.9), deck)
                var innen := PackedFloat32Array()
                for k in n:
                    innen.append(breit[k] * 0.35)
                _tu.band(mitte, innen, Color(1.0, 1.0, 1.0, 0.95), deck)
            Waffen.Art.SPEER:
                # Ein Stoss: der Strich schiesst hinaus und laeuft hinten aus.
                var spitze := o + Vector2(0.0, -HELD_HOEHE * 0.35) \
                    + r * weite * (0.35 + 0.65 * minf(1.0, t * 2.2))
                var fuss := o + Vector2(0.0, -HELD_HOEHE * 0.35) + r * HELD_HOEHE * 0.2
                _tu.zug(fuss, spitze, HELD_HOEHE * 0.10,
                    Color(STAHL.r, STAHL.g, STAHL.b, 0.9 * (1.0 - t * t)), 0.9, 0.0, 0.0, 6)
                _tu.zug(spitze - r * 26.0, spitze + r * 12.0, HELD_HOEHE * 0.09,
                    Color(1.0, 1.0, 1.0, 0.95 * (1.0 - t * t)), 0.75, 0.0, 0.0, 4)
            Waffen.Art.HAMMER:
                # Eine Bodenwelle: ein flacher Ring, der aufgeht und verblasst,
                # in Erde und nicht in Zinnober - er trifft Feinde, nicht dich.
                var rad := weite * (0.25 + 0.75 * (1.0 - pow(1.0 - t, 2.0)))
                var mitte := PackedVector2Array()
                var breit := PackedFloat32Array()
                var n := 20
                for k in n + 1:
                    var w := TAU * float(k) / float(n)
                    mitte.append(o + Vector2(cos(w) * rad, sin(w) * rad * 0.42))
                    breit.append(HELD_HOEHE * 0.11 * (1.0 - t * 0.6))
                var erde := Palette.ERDE.darkened(0.40)
                _tu.band(mitte, breit, Color(erde.r, erde.g, erde.b, 0.85 * (1.0 - t)),
                    PackedFloat32Array())
                # Dazu Splitter im Ring - Erde, die aufspritzt.
                if t < 0.5:
                    for k in 6:
                        var w := TAU * float(k) / 6.0 + 0.4
                        var p := o + Vector2(cos(w) * rad, sin(w) * rad * 0.42)
                        _tu.klecks(p + Vector2(0.0, -14.0 * (1.0 - t * 2.0)), 4.0,
                            Color(erde.r, erde.g, erde.b, 0.8 * (1.0 - t * 2.0)), k)


## **Ein Geschoss hat eine Form.** Bolzen und Axt waren derselbe Strich mit
## Schweif. Jetzt: der Bolzen mit Schaft, Spitze und Befiederung, die Axt als
## Blatt am Stiel, das sich dreht. Der feindliche Bolzen bleibt in Zinnober
## und zieht seinen langen Schweif - ihm muss man ausweichen.
func _zeichne_geschoss(g: Gefecht.Geschoss) -> void:
    var r := g.richtung
    if g.feindlich:
        _tu.zug(g.ort - r * 40.0, g.ort + r * 4.0, 4.0,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.5), 0.9, 0.0, 0.0, 4)
        _bolzen(g.ort, r, ZINNOBER.darkened(0.3), ZINNOBER)
        return
    if g.waffe == Waffen.Art.AXT:
        var w := g.alter * 16.0 + g.start.x * 0.01
        var d := Vector2(cos(w), sin(w))
        var q := d.orthogonal()
        _tu.zug(g.ort - d * 13.0, g.ort + d * 11.0, 4.5, HOLZ, 0.5, 0.0, 0.0, 3,
            Palette.UMRISS)
        _tu.strang(PackedVector2Array([g.ort + d * 6.0 - q * 2.0,
            g.ort + d * 11.0 + q * 9.0, g.ort + d * 15.0 + q * 2.0]),
            PackedFloat32Array([5.0, 12.0, 4.0]), STAHL, 4, Palette.UMRISS)
        # Ein blasser Wirbel um die drehende Axt.
        _tu.zug(g.ort - q * 16.0, g.ort + q * 16.0, 2.0,
            Color(STAHL.r, STAHL.g, STAHL.b, 0.25), 0.5, 0.0, 14.0, 5)
        return
    _tu.zug(g.ort - r * 26.0, g.ort - r * 6.0, 3.0,
        Color(STAHL.r, STAHL.g, STAHL.b, 0.35), 0.9, 0.0, 0.0, 3)
    _bolzen(g.ort, r, HOLZ, STAHL)


func _bolzen(ort: Vector2, r: Vector2, schaft: Color, spitze: Color) -> void:
    var q := r.orthogonal()
    _tu.zug(ort - r * 14.0, ort + r * 8.0, 3.0, schaft, 0.5, 0.0, 0.0, 3,
        Palette.UMRISS)
    _tu.zug(ort + r * 6.0, ort + r * 15.0, 5.0, spitze, 0.1, 0.0, 0.0, 3,
        Palette.UMRISS)
    for s in [-1.0, 1.0]:
        _tu.zug(ort - r * 10.0, ort - r * 16.0 + q * 5.0 * s, 2.6,
            Color(0.93, 0.91, 0.85), 0.2, 0.0, 0.0, 3)


## **Gezeichnet wird, was im Bild steht - nicht ein Quadrat darum.** Hier
## stand ein Rand von 720 Punkten in beide Richtungen: 1440 breit fuer ein
## Bild, das 720 breit ist. Jede Figur links und rechts ausserhalb wurde
## gebaut, sortiert und weggeworfen, und `DICHT_AB` zaehlte sie mit.
##
## `rand` ist, wie weit ein Ding ueber seinen Ort hinausragt. Figuren stehen
## auf ihren Fuessen und ragen **nach oben**: unten reicht ein kleiner Rand,
## oben braucht es ihre Hoehe.
var _sicht := Vector2(360.0, 800.0)

func _im_bild(ort: Vector2, rand: float) -> bool:
    var d := ort - _kamera_ort
    return absf(d.x) < _sicht.x + rand * 0.6 \
        and d.y > -_sicht.y - 30.0 and d.y < _sicht.y + rand


const VOLL_NAH := 40
var _voll_bis := INF

## Die Sparfassung je Sorte und Blickrichtung, einmal gezeichnet
## (`Tusche.vorlage`). Sie hat keinen Schritt und keinen Schwung - nur wer
## gerade getroffen aufblitzt, wird frisch gezeichnet.
var _vorlagen := {}

func _vorlage(art: int, blick: float, h: float) -> Array:
    var schluessel := art * 2 + (1 if blick > 0.0 else 0)
    var v: Variant = _vorlagen.get(schluessel)
    if v == null:
        var tu := Tusche.new()
        Streiter.feind(tu, Vector2.ZERO, h, blick, art, 0.0, 0.0, true)
        v = tu.vorlage()
        _vorlagen[schluessel] = v
    return v

func _zeichne_feind(f: Gefecht.Feind, knapp: bool) -> void:
    var h := FEIND_HOEHE * (f.radius / 17.0)
    var phase := _zeit * 7.0 + f.ort.x * 0.05
    var spar := f.ort.distance_squared_to(_stand.ort) > _voll_bis
    if spar and f.zuckt <= 0.0:
        _tu.setze(_vorlage(f.art, f.blick, h), f.ort)
    else:
        Streiter.feind(_tu, f.ort, h, f.blick, f.art, phase, f.zuckt, spar)
    # **Ein Treffer splittert.** Zwei helle Kreuzstriche an der Brust, solange
    # der Getroffene noch zuckt - kein Zustand, nur was `zuckt` schon weiss.
    if f.zuckt > 0.06:
        var u := (0.14 - f.zuckt) / 0.08
        var p := f.ort + Vector2(0.0, -h * 0.6)
        var l := h * (0.10 + 0.12 * u)
        var c := Color(1.0, 0.98, 0.9, 1.0 - u)
        _tu.zug(p + Vector2(-l, -l * 0.6), p + Vector2(l, l * 0.6), 3.0, c, 0.5, 0.0, 0.0, 3)
        _tu.zug(p + Vector2(-l, l * 0.6), p + Vector2(l, -l * 0.6), 3.0, c, 0.5, 0.0, 0.0, 3)
    # **Der Stuermer kuendigt an.** Ein Angriff, den man nicht kommen sieht,
    # ist kein Angriff, sondern eine Steuer - dieselbe Regel wie im vorigen
    # Spiel, nur mit einem anderen Zeichen.
    if f.stuermt:
        _tu.zug(f.ort, f.ort + f.bahn * 90.0, 6.0,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.7), 0.7, 0.4, 0.0, 4)
    _zeichne_leben(f, h, knapp)


## **Ein Balken nur ueber den Schweren.** Der Ritter und der Warlord sind die
## beiden, bei denen die Frage *wie lange noch* ueberhaupt auftaucht; ein
## Strolch faellt beim ersten oder zweiten Schlag. Hundertfuenfzig Balken
## waeren hundertfuenfzig Dinge im Bild, die kein Feind sind - und was einen
## Hintergrund laut macht, ist die Zahl der getrennten Dinge darin.
##
## **Und im Gedraenge nur ueber denen, die nah sind.** Die Ritter sind zaeh
## und bleiben uebrig, waehrend das Fussvolk faellt; in Minute acht stand ein
## Block aus zwanzig Rittern im Bild, fast alle angeschlagen, und darueber
## zwanzig Balken. Wie lange einer noch steht, fragt man bei dem, der gleich
## zuschlaegt - nicht bei dem am Bildrand. Der Warlord behaelt seinen immer.
const BALKEN_NAH := 280.0

func _zeichne_leben(f: Gefecht.Feind, h: float, knapp := false) -> void:
    if f.art != Feinde.Art.RITTER and f.art != Feinde.Art.WARLORD:
        return
    if knapp and f.art == Feinde.Art.RITTER \
            and f.ort.distance_to(_stand.ort) > BALKEN_NAH:
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


## Ring und Lebensbalken des Helden - **zuletzt und ueber allem**. Beides
## beantwortet *wo bin ich und wie steht es*, und beides darf kein Feind und
## kein Gefaehrte verdecken.
func _zeichne_marke() -> void:
    var s := _stand
    var n := Burg.stand.skin(s.held)
    Streiter.standring(_tu, s.ort, HELD_HOEHE, Skins.koerper(s.held, n))
    # **Sein Leben steht bei ihm, nicht nur oben am Schirm.** Der Balken oben
    # sagt, wie es steht; dieser sagt es dort, wo der Blick ohnehin liegt -
    # und im Gedraenge schaut niemand an den Bildrand.
    _riegel(s.ort + Vector2(0.0, HELD_HOEHE * 0.17), HELD_HOEHE * 0.26,
        HELD_HOEHE * 0.024,
        clampf(s.leben / maxf(1.0, s.leben_voll), 0.0, 1.0),
        Palette.LEBEN_VOLL)


## **Ein Pfeil zeigt, woher der Warlord kommt.** Er tritt wie alle auf dem
## Eintrittsring ein, ausserhalb des Bildes, und braucht Sekunden bis zur
## Leine; man hoert sein Horn und sieht nichts. Eine Ansage, die man nicht
## orten kann, ist nur ein Geraeusch. Der Pfeil sitzt am Bildrand, dort wo die
## Linie von der Mitte zu ihm hinausgeht, in Zinnober wie das Sturmband - er
## kuendigt Schaden am Spieler an. Wie Ring und Lebensbalken eine Marke und
## keine Figur, also ueber allem. Kein Text: er beantwortet *woher*, und naeher
## kommt der Warlord ohnehin.
const PFEIL_RAND := 56.0

func _zeichne_randpfeil() -> void:
    var warlord: Gefecht.Feind = null
    for f in _stand.feinde:
        if f.lebt and Feinde.ist_warlord(f.art):
            warlord = f
            break
    if warlord == null:
        return
    var halb := get_viewport_rect().size * 0.5 - Vector2(PFEIL_RAND, PFEIL_RAND)
    var d := warlord.ort - _kamera_ort
    if absf(d.x) <= halb.x + PFEIL_RAND and absf(d.y) <= halb.y + PFEIL_RAND:
        return
    var faktor := minf(halb.x / maxf(0.001, absf(d.x)),
        halb.y / maxf(0.001, absf(d.y)))
    var richtung := d.normalized()
    var spitze := _kamera_ort + d * faktor
    var quer := Vector2(-richtung.y, richtung.x)
    # Gross genug, dass er nicht wie ein Spritzer aussieht: der erste Schuss
    # mit 34 Punkten las sich als Blut am Bildrand.
    var gross := 52.0 * (1.0 + 0.10 * sin(_zeit * 6.0))
    var farbe := Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, 0.95)
    var fuss := spitze - richtung * gross
    _tu.zug(fuss + quer * gross * 0.62, spitze, 11.0, farbe, 0.5, 0.2, 0.0, 5,
        TINTE)
    _tu.zug(fuss - quer * gross * 0.62, spitze, 11.0, farbe, 0.5, 0.2, 0.0, 5,
        TINTE)
    _tu.klecks(fuss - richtung * gross * 0.30, 8.0, farbe, 3, TINTE)


func _zeichne_gefaehrte(g: Gefecht.Gefaehrte) -> void:
    var n := Burg.stand.skin(_stand.held)
    # **Deutlich kleiner als der Held.** Bei 0,78 standen drei blaue Maenner
    # nebeneinander und man musste suchen, welcher man selbst ist.
    Streiter.gefaehrte(_tu, g.ort, HELD_HOEHE * 0.62, g.blick,
        _zeit * 8.0 + g.ort.x * 0.05, g.schlag,
        Skins.koerper(_stand.held, n), Skins.glanz(_stand.held, n))


func _zeichne_held() -> void:
    var s := _stand
    var blick := 1.0 if s.blick.x >= 0.0 else -1.0
    var laeuft := s.lauf.length_squared() > 0.02
    var phase := _zeit * 9.0 if laeuft else 0.0
    # **Die Waffe schlaegt, wenn geschlagen wird.** Vorher wackelte sie
    # dauernd im Takt einer Sinuskurve, unabhaengig von jedem Schlag. Jetzt
    # zieht sie beim Schlag einmal durch - von hinten nach vorn ueber die
    # Schlagrichtung - und haengt dazwischen ruhig in Blickrichtung.
    # **Jede Klasse haelt ihre Waffe anders**, und jede schlaegt anders: das
    # Schwert zieht durch, der Speer stoesst, die Armbrust zielt und zuckt
    # zurueck, der Hammer kommt von oben. In Ruhe liegt der Hammer auf der
    # Schulter und der Speer steht schraeg nach oben.
    var klasse := s.held
    var wiege := sin(_zeit * 2.2) * 0.06
    var ruhe := s.blick.angle() + 0.35 * blick + wiege
    var dauer := 0.22
    match klasse:
        Streiter.KLASSE_BOGEN:
            ruhe = Vector2(blick, 0.15).angle() + wiege * 0.5
            dauer = 0.45
        Streiter.KLASSE_SPEER:
            ruhe = Vector2(blick, -0.55).angle() + wiege * 0.5
        Streiter.KLASSE_HAMMER:
            ruhe = Vector2(-0.35 * blick, -1.0).angle() + wiege * 0.5
            dauer = 0.32
    var schlag := 1.0
    if _schlag_alter < dauer:
        var t := _schlag_alter / dauer
        schlag = t
        var ziel := _schlag_richtung.angle()
        var e := 1.0 - pow(1.0 - t, 3.0)
        match klasse:
            Streiter.KLASSE_BOGEN, Streiter.KLASSE_SPEER:
                _waffe_winkel = lerp_angle(_waffe_winkel, ziel, 0.6)
            Streiter.KLASSE_HAMMER:
                # Von hinten oben ueber den Kopf auf das Ziel.
                var oben := Vector2(-0.35 * blick, -1.0).angle()
                _waffe_winkel = lerp_angle(oben, ziel, e)
            _:
                _waffe_winkel = ziel + lerpf(-1.1, 0.9, e) * blick
    else:
        _waffe_winkel = lerp_angle(_waffe_winkel, ruhe, 0.25)
    # Das Gewand kommt aus dem Spielstand und nicht aus dem Gefecht: eine
    # Skin ist Zierde und darf in `Gefecht.Stand` nichts zu suchen haben.
    var n := Burg.stand.skin(s.held)
    var kleid := Skins.koerper(s.held, n)
    var glanz := Skins.glanz(s.held, n)
    Streiter.frei_gestellt(_tu, s.ort, HELD_HOEHE, Palette.BODEN)
    _zeichne_druck()
    # Beim Treffer blitzt er in Zinnober - Schaden am Spieler, die eine Stelle,
    # an der die Farbe des Helden kurz nicht seine eigene ist.
    if _wunde > 0.0:
        kleid = kleid.lerp(ZINNOBER, _wunde * 0.7)
    Streiter.held(_tu, s.ort, HELD_HOEHE, blick, phase, _waffe_winkel,
        kleid, glanz, klasse, schlag)

    # Der Flegel steht dauernd im Feld, also gehoert er ins Bild und nicht in
    # eine Wirkung: was Schaden macht, muss man sehen.
    var stufe := s.waffe_stufe(Waffen.Art.FLEGEL)
    if stufe > 0:
        # `bahn_von`, dieselbe Rechnung wie im Gefecht. Zwei Rechnungen
        # waeren zwei Wahrheiten, und dann schlaegt der Flegel woanders zu,
        # als er im Bild steht.
        var weite := Gefecht.bahn_von(s, Waffen.Art.FLEGEL)
        var zahl := Waffen.zahl(Waffen.Art.FLEGEL, stufe)
        var eisen := Color(0.60, 0.63, 0.67)
        for i in zahl:
            var w := s.flegel_winkel + TAU * float(i) / float(zahl)
            var ort := s.ort + Vector2(cos(w), sin(w)) * weite
            # **Eine Kette ist Glieder, kein Faden.** Vier kleine Ringe auf
            # dem Weg zum Kopf statt eines blassen Strichs.
            for k in 4:
                var p := s.ort.lerp(ort, (float(k) + 0.6) / 4.6)
                _tu.klecks(p, 2.6, Color(eisen.r, eisen.g, eisen.b, 0.9), k)
            # Die Spur: ein blasser Bogen hinter dem Kopf - er kreist, und das
            # muss man sehen, ohne auf die Zeit zu achten.
            var spur := PackedVector2Array()
            var breit := PackedFloat32Array()
            var deck := PackedFloat32Array()
            for k in 6:
                var u := float(k) / 5.0
                var wk := w - 0.9 * (1.0 - u)
                spur.append(s.ort + Vector2(cos(wk), sin(wk)) * weite)
                breit.append(9.0 * u)
                deck.append(0.35 * u)
            _tu.band(spur, breit, eisen, deck)
            # Stahl, nicht der helle Glanz des Helden: als HELD_GLANZ waren
            # die Koepfe drei helle Scheiben und lasen sich als Blasen. Dazu
            # Stacheln, sonst ist es eine Kugel.
            for k in 5:
                var ws := w * 2.0 + TAU * float(k) / 5.0
                _tu.zug(ort, ort + Vector2(cos(ws), sin(ws)) * 17.0, 4.0, eisen,
                    0.1, 0.0, 0.0, 3, Palette.UMRISS)
            _tu.klecks(ort, 12.0, eisen, i, Palette.UMRISS)



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
        # **Auch die Wahl gehoert dem Daumen.** Hier stand `nimm(_stand, 0)`:
        # der Schuss nahm stets das erste Angebot, der Messstand das, was
        # `Daumen.waehle()` sagt. Gleicher Lauf, zwei Aufstiegsfolgen - und
        # damit zeigte das Bild ein anderes Spiel, als `tools/probe.gd` mass.
        if _stand != null and _stand.wartet_auf_wahl:
            Gefecht.nimm(_stand, Daumen.waehle(_stand))
        _process(takt)
        for kind in get_children():
            if kind.has_method("_process"):
                kind._process(takt)
