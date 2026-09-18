extends Node2D

## **HUNDRED CUTS - die Schleife.**
##
## Ein Duell besteht aus einer einzigen Frage, immer wieder gestellt:
## *welche Linie kommt, und wann faellt sie?* Der Gegner holt aus, seine
## Haltung sagt die Linie, eine Zinnoberlinie bestaetigt sie, und der Daumen
## muss dieselbe Achse treffen - im Fenster um den Schlag.
##
## **Was dieses Spiel nicht ist:** kein Zielen, kein Ausweichen, kein
## Schaden. Ein Hieb toetet, wenn er sitzt, und das gilt fuer beide Seiten.
## Was der Spieler ueber die Ronden hinweg gewinnt, ist **Nachsicht** -
## laengere Ansaetze, breitere Fenster, mehr Wunden - und nicht Wucht. Eine
## Schule, die den Spieler haerter zuschlagen laesst, macht aus einem Duell
## ein Rechenspiel.
##
## Hier steht kein Spielregelwissen. Was ueber Sieg und Niederlage
## entscheidet, steht in `Duell`; dieser Knoten fragt es und zeichnet es.
## Die Zinnoberlinie nimmt ihre Laenge aus `Duell.fuehrungsanteil()` - aus
## **derselben** Zahl, an der das Fenster haengt. Eine Fuehrungslinie, die
## anders steht als die Pruefung, waere unlernbar.

enum Lage { TITEL, DUELL, ENDE, SCHULE }

const PAPIER := Color(0.937, 0.918, 0.871)
const TINTE := Color(0.09, 0.08, 0.09)
const ZINNOBER := Color(0.78, 0.16, 0.10)
const GRAU := Color(0.44, 0.43, 0.44)

## **Der Spieler steht vorn, und zwar deutlich.**
##
## Der erste Anlauf setzte ihn auf dieselbe Bodenlinie wie die Gegner, nur
## ein Stueck tiefer und etwas groesser. Im Bild war das ein **Knaeuel**:
## vier Koepfe auf derselben Hoehe, acht Beine dazwischen, und in der Mitte
## eine rote Linie, von der man nicht sagen konnte, zu wem sie gehoert.
##
## Eine Buehne braucht Tiefe, und Tiefe heisst hier zweierlei: der Spieler
## steht **tiefer im Bild** (naeher) und ist **deutlich groesser**. Beides
## zusammen, nicht eines davon - ein Fechter, der nur groesser ist, sieht
## aus wie derselbe Fechter weiter vorn im selben Gedraenge.
const SPIELER_ORT := Vector2(360.0, 1168.0)
const SPIELER_HOEHE := 404.0

## Die Plaetze in der Mensur. Zwei flankierend, einer tiefer in der Ferne -
## in dieser Reihenfolge, damit der zweite Gegner immer auf der anderen
## Seite steht als der erste. Zwei nebeneinander waeren eine Reihe, und eine
## Reihe liest man nicht, man zaehlt sie ab.
const PLAETZE: Array[Vector2] = [
    Vector2(138.0, 806.0), Vector2(582.0, 806.0), Vector2(360.0, 712.0),
]
const PLATZ_HOEHE: PackedFloat32Array = [252.0, 252.0, 198.0]

## Wie lange eine Meldung ueber der Buehne steht.
const MELDUNG_DAUER := 1.9

var lage := Lage.TITEL
var _stand: Duell.Stand = null
var _ronde := 1
var _rng := RandomNumberGenerator.new()
var _tu := Tusche.new()
var _atem := 0.0

## Der Spieler: was er gerade tut und wie lange noch.
var _sp_lage := 0          ## 0 ruhe, 1 parade, 2 schnitt, 3 wunde, 4 fehlgriff
var _sp_uhr := 0.0
var _sp_linie := 0
var _blick := 1.0

## Der Finger.
var _zieht := false
var _von := Vector2.ZERO
var _jetzt := Vector2.ZERO
var _spur_alter := 9.0
var _spur_von := Vector2.ZERO
var _spur_bis := Vector2.ZERO

var _spritzer: Array = []
var _gefallene: Array = []
var _ruettel := 0.0
var _meldung := ""
var _meldung_uhr := 9.0
var _einstieg_schritt := 0

@onready var _buehne: Node2D = $Buehne
@onready var _hud: Control = $Oberflaeche/Hud


func _ready() -> void:
    _rng.randomize()
    RenderingServer.set_default_clear_color(PAPIER)
    Stahl.laut = Weg.stand.laut
    _ronde = Weg.stand.naechste_ronde()
    _buehne.setze_kapitel(Ronde.kapitel(_ronde))
    set_process(true)
    _lies_schalter()


## --- Der Messstand ---
##
## **Wer eine Form beurteilt, sieht sie an.** Ohne diesen Weg ist jede
## Optikfrage geraten, und jede Antwort darauf eine Vermutung, die man vier
## Durchgaenge lang fuer die Wahrheit haelt.
##
##     xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --resolution 720x1600 -- --schuss /pfad/bild.png --ronde 8 --zeit 2.4
##
## `--zeit` rechnet die Fahrt mit festem Takt vor, damit ein Schuss
## wiederholbar ist. Er treibt dabei **jeden** Knoten mit eigenem `_process`
## und nicht nur diesen einen: ein Vorlauf, in dem der Hintergrund still
## steht und die Figuren altern, zeigt ein Bild, das es im Spiel nicht gibt.
var _schuss_pfad := ""

func _lies_schalter() -> void:
    var args := OS.get_cmdline_user_args()
    var zeit := 0.0
    var ronde := 0
    var lage_wunsch := -1
    for i in args.size():
        match args[i]:
            "--schuss":
                if i + 1 < args.size():
                    _schuss_pfad = args[i + 1]
            "--ronde":
                if i + 1 < args.size():
                    ronde = int(args[i + 1])
            "--zeit":
                if i + 1 < args.size():
                    zeit = float(args[i + 1])
            "--schule":
                lage_wunsch = Lage.SCHULE
            "--ende":
                lage_wunsch = Lage.ENDE
            "--stufen":
                if i + 1 < args.size():
                    for h in Schule.NAMEN.size():
                        Weg.stand.stufen[h] = int(args[i + 1])
                    # **Auch der Kontostand.** Ein Schalter, der die halbe
                    # Wahrheit setzt, zeigt ein Spiel, das es nicht gibt:
                    # eine Schule auf Stufe vierzehn neben null Ehre.
                    Weg.stand.ehre = Schule.kosten(0, int(args[i + 1])) * 2
    if ronde > 0:
        Weg.stand.weiteste_ronde = maxi(Weg.stand.weiteste_ronde, ronde)
        Weg.stand.einstieg = 1
        beginne_ronde(ronde)
        _meldung_uhr = 9.0
    if lage_wunsch >= 0:
        lage = lage_wunsch
    if zeit > 0.0:
        _treibe_vor(zeit)
    if _schuss_pfad != "":
        await RenderingServer.frame_post_draw
        var bild := get_viewport().get_texture().get_image()
        bild.save_png(_schuss_pfad)
        get_tree().quit()


func _treibe_vor(sekunden: float) -> void:
    var takt := 1.0 / 60.0
    var n := int(sekunden / takt)
    for i in n:
        _process(takt)
        for kind in get_children():
            if kind.has_method("_process"):
                kind._process(takt)


## --- Die Schleife ---

func beginne_ronde(nummer: int) -> void:
    _ronde = maxi(1, nummer)
    var stufen := {}
    for h in Schule.NAMEN.size():
        stufen[h] = Weg.stand.stufe(h)
    _stand = Duell.baue(_ronde, stufen)
    _spritzer.clear()
    _gefallene.clear()
    _sp_lage = 0
    _sp_uhr = 0.0
    _einstieg_schritt = 0 if Weg.stand.einstieg == 0 else 99
    lage = Lage.DUELL
    _buehne.setze_kapitel(Ronde.kapitel(_ronde))
    _melde("ROUND %d" % _ronde)
    Stahl.spiele(Stahl.Ton.RONDE)


func _melde(text: String) -> void:
    _meldung = text
    _meldung_uhr = 0.0


func _process(delta: float) -> void:
    _atem += delta
    _ruettel = maxf(0.0, _ruettel - delta * 3.4)
    _meldung_uhr += delta
    _spur_alter += delta
    _sp_uhr += delta
    if _sp_lage != 0 and _sp_uhr > 0.26:
        _sp_lage = 0

    for s in _spritzer:
        s.alter += delta
    _spritzer = _spritzer.filter(func(s): return s.alter < 0.9)
    for g in _gefallene:
        g.alter += delta
    _gefallene = _gefallene.filter(func(g): return g.alter < 2.4)

    if lage == Lage.DUELL and _stand != null:
        Duell.schritt(_stand, delta, _rng)
        _werte_vorfaelle_aus()
        if not _stand.lebt():
            _beende(false)
        elif Duell.geraeumt(_stand):
            _beende(true)
    queue_redraw()


func _werte_vorfaelle_aus() -> void:
    for v in _stand.vorfaelle:
        var art: int = v[0]
        var k: Duell.Klinge = v[1]
        match art:
            Duell.Vorfall.PARIERT:
                Stahl.spiele(Stahl.Ton.PARADE, 0.9 + randf() * 0.25)
                Tastsinn.gib(Tastsinn.Art.PARADE)
                _ruettel = 0.5
                _sp_lage = 1
                _sp_uhr = 0.0
                _sp_linie = k.wahre_linie
                _funken(_ort_von(k) + Vector2(0.0, -_hoehe_von(k) * 0.62),
                    ZINNOBER, 7)
            Duell.Vorfall.GEFAELLT:
                Stahl.spiele(Stahl.Ton.SCHNITT)
                Stahl.spiele(Stahl.Ton.GEFALLEN, 1.0, 0.7)
                Tastsinn.gib(Tastsinn.Art.SCHNITT)
                _sp_lage = 2
                _sp_uhr = 0.0
                _gefallene.append({
                    "art": k.art, "ort": _ort_von(k),
                    "hoehe": _hoehe_von(k), "blick": _blick_von(k),
                    "alter": 0.0})
                _funken(_ort_von(k) + Vector2(0.0, -_hoehe_von(k) * 0.6),
                    TINTE, 11)
            Duell.Vorfall.GETROFFEN:
                Stahl.spiele(Stahl.Ton.WUNDE)
                Tastsinn.gib(Tastsinn.Art.WUNDE)
                _ruettel = 1.0
                _sp_lage = 3
                _sp_uhr = 0.0
                _funken(SPIELER_ORT + Vector2(0.0, -SPIELER_HOEHE * 0.6),
                    ZINNOBER, 9)
            Duell.Vorfall.FEHLGRIFF:
                Stahl.spiele(Stahl.Ton.TIPP, 0.7, 0.6)
                _sp_lage = 4
                _sp_uhr = 0.0
            Duell.Vorfall.TAEUSCHUNG:
                Stahl.spiele(Stahl.Ton.ANSATZ, 1.35, 0.8)


func _funken(ort: Vector2, farbe: Color, zahl: int) -> void:
    for i in zahl:
        var w := _rng.randf() * TAU
        _spritzer.append({
            "ort": ort,
            "richtung": Vector2(cos(w), sin(w)) * (90.0 + _rng.randf() * 230.0),
            "farbe": farbe, "alter": 0.0,
            "gross": 2.4 + _rng.randf() * 5.0})


func _beende(gewonnen: bool) -> void:
    lage = Lage.ENDE
    Weg.trage_ein(_ronde, _stand.ehre, _stand.beste_kette,
        _stand.gefaellt, gewonnen)
    if Weg.stand.einstieg == 0:
        Weg.stand.einstieg = 1
        Weg.sichere()


## --- Wo einer steht ---

func _ort_von(k: Duell.Klinge) -> Vector2:
    var i := clampi(k.stelle, 0, PLAETZE.size() - 1)
    var o: Vector2 = PLAETZE[i]
    # **Er tritt im Ansatz vor.** Die Mensur ist kein fester Abstand: wer
    # ausholt, kommt herein, und genau das macht den Ansatz auch dann
    # sichtbar, wenn man gerade auf die andere Seite sieht.
    if k.lage == Duell.Lage.ANSATZ:
        var t := Duell.fuehrungsanteil(k)
        o = o.lerp(Vector2(SPIELER_ORT.x, o.y), 0.16 * t)
    elif k.lage == Duell.Lage.OFFEN:
        o.x += (o.x - SPIELER_ORT.x) * 0.05
    return o


func _hoehe_von(k: Duell.Klinge) -> float:
    return PLATZ_HOEHE[clampi(k.stelle, 0, PLATZ_HOEHE.size() - 1)]


## Ein Gegner sieht immer den Spieler an.
func _blick_von(k: Duell.Klinge) -> float:
    return -1.0 if _ort_von(k).x > SPIELER_ORT.x else 1.0


## Wen der Spieler ansieht: den, der zuerst faellt. Dieselbe Rangfolge, nach
## der `Duell.antworte()` auswaehlt - der Blick darf nicht woanders liegen
## als die Klinge.
func _draengendster() -> Duell.Klinge:
    if _stand == null:
        return null
    var ziel: Duell.Klinge = null
    var frist := 9999.0
    for k in _stand.klingen:
        if not k.lebt() or not k.in_mensur:
            continue
        var f := 9999.0
        if k.lage == Duell.Lage.ANSATZ:
            f = k.dauer - k.uhr
        elif k.lage == Duell.Lage.OFFEN:
            f = 50.0 + (k.dauer - k.uhr)
        else:
            f = 100.0
        if f < frist:
            frist = f
            ziel = k
    return ziel


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
        _zieht = true
        _von = ort
        _jetzt = ort
        return
    if not hoch or not _zieht:
        return
    _zieht = false
    var wisch := ort - _von
    _spur_von = _von
    _spur_bis = ort
    _spur_alter = 0.0

    match lage:
        Lage.TITEL:
            beginne_ronde(Weg.stand.naechste_ronde())
        Lage.DUELL:
            Duell.antworte(_stand, wisch)
            if _einstieg_schritt < 3:
                _einstieg_schritt += 1
        Lage.ENDE:
            pass
        Lage.SCHULE:
            pass


## --- Das Bild ---

func _draw() -> void:
    var versatz := Vector2.ZERO
    if _ruettel > 0.0:
        versatz = Vector2(sin(_atem * 61.0), cos(_atem * 47.0)) \
            * _ruettel * 9.0
    draw_set_transform(versatz, 0.0, Vector2.ONE)

    if lage == Lage.TITEL:
        _zeichne_titelfigur()
        _tu.spuele(get_canvas_item())
        return

    if _stand == null:
        return

    # **Die Gefallenen zuerst**, damit die Lebenden ueber ihnen stehen. Was
    # von einem Gefallenen uebrig ist, gehoert hinter den, der noch kommt.
    for g in _gefallene:
        var t: float = g.alter / 2.4
        var h := Fechter.gefallen(minf(1.0, g.alter * 2.2))
        var farbe := Color(TINTE.r, TINTE.g, TINTE.b,
            clampf(1.0 - pow(t, 2.5), 0.0, 1.0))
        Fechter.schatten(_tu, g.ort, g.hoehe, 1.0 - t)
        Fechter.figur(_tu, g.ort, g.hoehe, g.blick, h, farbe, farbe)

    for k in _stand.klingen:
        if not k.lebt() or not k.in_mensur:
            continue
        _zeichne_gegner(k)

    _zeichne_spieler()

    # **Die Fuehrungslinien liegen ueber allem.** Sie sind die Antwort auf
    # die einzige Frage, die dieses Spiel stellt; alles, was sie verdeckt,
    # ist ein Fehler - auch eine Figur.
    for k in _stand.klingen:
        if not k.lebt() or not k.in_mensur:
            continue
        _zeichne_fuehrung(k)

    _zeichne_spritzer()
    _zeichne_spur()
    _tu.spuele(get_canvas_item())


func _zeichne_gegner(k: Duell.Klinge) -> void:
    var ort := _ort_von(k)
    var hoehe := _hoehe_von(k)
    var blick := _blick_von(k)
    var h: Fechter.Haltung

    match k.lage:
        Duell.Lage.ANSATZ:
            var t := Duell.fuehrungsanteil(k)
            var f := fensterlage(k)
            if f > 0.0:
                # Im Fenster schlaegt er wirklich zu: von der Ansatzhaltung
                # in den Durchschlag.
                h = Fechter.ansatz(k.linie).blende(
                    Fechter.schlag(k.linie), clampf(f, 0.0, 1.0))
            else:
                # Aus der Ruhe in den Ansatz - mit Beschleunigung zum Ende:
                # ein Ansatz mit gleichmaessigem Tempo hat keinen Moment,
                # an dem er kippt, und genau den liest der Spieler.
                h = Fechter.ruhe(_atem * 2.0 + float(k.stelle)).blende(
                    Fechter.ansatz(k.linie), pow(clampf(t * 1.25, 0.0, 1.0), 0.6))
        Duell.Lage.OFFEN:
            h = Fechter.offen(_atem)
        _:
            h = Fechter.ruhe(_atem * 2.0 + float(k.stelle) * 1.7)

    var farbe := TINTE
    # Der Getroffene zuckt: kurz blasser, als haette der Pinsel abgesetzt.
    if k.zuckt > 0.0:
        farbe = Color(TINTE.r, TINTE.g, TINTE.b, 1.0 - k.zuckt * 0.7)
    Fechter.schatten(_tu, ort, hoehe)
    Fechter.figur(_tu, ort, hoehe, blick, h, farbe, farbe)


## Wie weit der Schlag selbst fortgeschritten ist: null, solange er noch
## ausholt, dann von null auf eins durch das Fenster.
func fensterlage(k: Duell.Klinge) -> float:
    if k.lage != Duell.Lage.ANSATZ:
        return 0.0
    var f := Duell.fensterbreite(k.art, _stand.fensterzusatz)
    if k.uhr < k.dauer - f:
        return 0.0
    return clampf((k.uhr - (k.dauer - f)) / maxf(0.001, f * 2.0), 0.0, 1.0)


func _zeichne_fuehrung(k: Duell.Klinge) -> void:
    if k.lage != Duell.Lage.ANSATZ:
        return
    var t := Duell.fuehrungsanteil(k)
    if t <= 0.01:
        return
    var ort := _ort_von(k)
    var hoehe := _hoehe_von(k)
    var mitte := ort + Vector2(0.0, -hoehe * 0.66)
    var im_fenster := Duell.im_fenster(k, _stand)
    # **Sie waechst und wird satt** - beides zugleich, weil beides dasselbe
    # sagt: es wird ernst. Eine Linie, die nur waechst, uebersieht man am
    # Rand des Blicks; eine, die nur dunkler wird, hat keinen Ort.
    var deckung := 0.16 + 0.62 * pow(t, 1.6)
    var breite := hoehe * (0.016 + 0.020 * t)
    if im_fenster:
        deckung = 0.95
        breite *= 1.5

    if Schnitte.ist_stoss(k.wahre_linie):
        # Der Stoss hat keine Achse, sondern ein Ziel. Er waechst auf den
        # Spieler zu, und das ist die Ansage: hier hilft kein Wischen.
        # **Er waechst auf den Spieler zu, aber nicht bis zu ihm.** Eine
        # Linie, die den ganzen Schirm quert, gehoert optisch niemandem mehr
        # - man sieht einen Strahl und sucht seinen Absender. Ein Drittel
        # des Weges sagt dasselbe und bleibt beim Gegner.
        var ziel := SPIELER_ORT + Vector2(0.0, -SPIELER_HOEHE * 0.62)
        var bis := mitte.lerp(ziel, 0.10 + 0.26 * t)
        _tu.zug(mitte, bis, breite * 0.9,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, deckung),
            0.9, 0.0, 0.0, 6)
        _tu.klecks(bis, breite * 0.9,
            Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, deckung), k.stelle)
        return

    # **Die Linie liegt auf dem Gegner, nicht auf dem Schirm.** Sie sagt,
    # welche Achse *sein* Hieb nimmt; wer sie ueber die halbe Buehne zieht,
    # hat einen Strahl gezeichnet und keine Klingenlage.
    var r := Schnitte.richtung(k.wahre_linie)
    # Sie bleibt **innerhalb** der Figur, die sie meint. Mit 0,66 Radien je
    # Seite ragte sie weiter als der Fechter hoch ist, und dann liest man
    # sie als Gegenstand im Bild statt als seine Klingenlage.
    var l := hoehe * (0.19 + 0.27 * t)
    _tu.zug(mitte - r * l, mitte + r * l, breite,
        Color(ZINNOBER.r, ZINNOBER.g, ZINNOBER.b, deckung), 0.5, 0.0,
        hoehe * 0.012, 7)


func _zeichne_spieler() -> void:
    var ziel := _draengendster()
    if ziel != null:
        _blick = lerpf(_blick, _blick_von(ziel) * -1.0, 0.18)
    var blick := 1.0 if _blick >= 0.0 else -1.0
    var h: Fechter.Haltung
    match _sp_lage:
        1:
            h = Fechter.parade(_sp_linie)
        2:
            h = Fechter.schnitt_aus()
        3:
            h = Fechter.offen(_atem)
        4:
            # Fehlgriff: die Klinge steht daneben, und man sieht es.
            h = Fechter.ruhe(_atem * 2.0).blende(Fechter.schnitt_aus(), 0.35)
        _:
            h = Fechter.ruhe(_atem * 1.7)
    # Die Sperre nach einem Fehlgriff faerbt die Figur - sie ist die einzige
    # Zeit, in der ein Wisch nichts tut, und das muss man sehen koennen.
    var farbe := TINTE
    if _stand != null and _stand.sperre > 0.0:
        farbe = Color(GRAU.r, GRAU.g, GRAU.b, 0.55 + 0.45 * (1.0 - _stand.sperre / Duell.SPERRE))
    Fechter.schatten(_tu, SPIELER_ORT, SPIELER_HOEHE)
    Fechter.figur(_tu, SPIELER_ORT, SPIELER_HOEHE, blick, h, farbe, farbe)


func _zeichne_spritzer() -> void:
    for s in _spritzer:
        var t: float = s.alter / 0.9
        var von: Vector2 = s.ort
        var bis: Vector2 = s.ort + s.richtung * (t * 0.9)
        var f: Color = s.farbe
        _tu.zug(von, bis, s.gross * (1.0 - t * 0.6),
            Color(f.r, f.g, f.b, (1.0 - t) * 0.8), 0.0, 0.8, 0.0, 4)


func _zeichne_spur() -> void:
    # Der eigene Wisch bleibt einen Augenblick stehen. Ohne ihn weiss man
    # nach einem Fehlgriff nicht, ob man die falsche Achse getroffen hat
    # oder den falschen Augenblick - und das ist genau die Frage, aus der
    # man lernt.
    if _zieht and _von.distance_to(_jetzt) > 8.0:
        _tu.zug(_von, _jetzt, 9.0,
            Color(TINTE.r, TINTE.g, TINTE.b, 0.30), 0.2, 0.5, 0.0, 5)
        return
    if _spur_alter > 0.42:
        return
    var t := _spur_alter / 0.42
    _tu.zug(_spur_von, _spur_bis, 11.0 * (1.0 - t * 0.5),
        Color(TINTE.r, TINTE.g, TINTE.b, (1.0 - t) * 0.42), 0.2, 0.6, 0.0, 5)


func _zeichne_titelfigur() -> void:
    # Auf dem Titelblatt steht eine einzige Figur in Ruhe. Kein Kampf, kein
    # Gegner: das Bild soll sagen, worum es geht, und nicht schon spielen.
    var h := Fechter.ruhe(_atem * 1.3)
    Fechter.schatten(_tu, Vector2(360.0, 880.0), 330.0)
    Fechter.figur(_tu, Vector2(360.0, 880.0), 330.0, 1.0, h, TINTE, TINTE)


## --- Was das Bedienbild fragt ---

func meldung() -> String:
    if _meldung_uhr > MELDUNG_DAUER:
        return ""
    return _meldung


func stand() -> Duell.Stand:
    return _stand


func ronde() -> int:
    return _ronde


## Der Einstieg: drei Saetze, und jeder wartet auf die Handlung, von der er
## redet - nicht auf eine Uhr. Wer liest, soll nicht ueberholt werden.
func einstieg_satz() -> String:
    if Weg.stand.einstieg != 0 or lage != Lage.DUELL or _stand == null:
        return ""
    match _einstieg_schritt:
        0:
            return "A red line shows where his cut will fall."
        1:
            return "Swipe along that same line. Not before it fills."
        2:
            return "Now he is open. Swipe again to finish him."
    return ""
