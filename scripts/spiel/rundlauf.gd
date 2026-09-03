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

## Links und rechts. Als Konstante mit Typ, weil GDScript aus einem
## Feldliteral keinen Typ ableitet - siehe die Konventionen.
const SEITEN: PackedFloat32Array = [-1.0, 1.0]

## Wieviele Wellen gleichzeitig laufen. Siehe `_bereite_welle_vor()`.
const DICHTE := 3

const BOOT_TEMPO := 260.0
const BOOT_TRAEGHEIT := 6.0
const BOOT_RADIUS := 32.0
const DREH_TEMPO := 7.0

## Wie traege die Kamera folgt und wie weit sie vorausschaut.
## **Straff, nicht traege.** Beim ersten Versuch lag die Kamera so weit
## zurueck, dass das Boot am Bildrand klebte: bei Tempo 260 und einer
## Traegheit von 3.2 sind das achtzig Einheiten Rueckstand, und der Vorlauf
## kam noch dazu. Auf einem Kreis, den der Vorfuehrdaumen faehrt, setzt sie
## sich nie - der Rueckstand summiert sich in die Kurve hinein.
const KAMERA_TRAEGHEIT := 6.5
const KAMERA_VORAUS := 0.16

const BEGLEITER_ABSTAND := 96.0
const BEGLEITER_TRAEGHEIT := 3.4
const BEGLEITER_REICHWEITE := 210.0
const BEGLEITER_TAKT := 0.9

## Wie lange ein Raeuber braucht, bis er nach einem Treffer wieder beisst.
const BISS_SPERRE := 0.9

## **Nicht jeder Raeuber kommt von aussen auf einen zu.** Jeder vierte liegt
## schon in der Karte und wartet - am Grund, still, blass. Wer geradeaus
## faehrt, trifft irgendwann einen; wer den Kegel voraushaelt, sieht ihn
## vorher.
##
## Das ist der Grund, warum das Aufdecken der Karte etwas kostet: eine
## unbekannte Ecke ist nicht nur dunkel, es kann auch etwas darin liegen.
const LAUER_ANTEIL := 0.25

## Ab welchem Abstand ein Lauerer erwacht. Kleiner als die Sicht: man soll
## ihn sehen koennen, bevor er kommt.
const WECK_RADIUS := 420.0

## Wie weit vom Boot ein Lauerer gelegt wird. Nicht naeher als der
## Weckradius - sonst waere er schon wach, bevor die Welle laeuft.
const LAUER_NAH := 560.0
const LAUER_WEIT := 1400.0

@onready var _schwarm: Node2D = $Schwarm
@onready var _kegel: Node2D = $Kegel
@onready var _funken: Node2D = $Funken
@onready var _kamera: Camera2D = $Kamera
## **Das Boot gehoert ueber den Kegel.** Godot zeichnet erst den
## Elternknoten und dann die Kinder - stand das Boot in `_draw()`
## des Rundlaufs, malte der Kegel seinen Nahbereich darueber, und
## der Rumpf verschwand hinter einer blassen Scheibe. Dieser leere
## Knoten steht in der Szene hinter allen anderen; was auf sein
## `draw` haengt, liegt vorn.
@onready var _vorn: Node2D = $Vorn
@onready var _hud: CanvasLayer = $Hud
@onready var _menue: CanvasLayer = $Menue
@onready var _grund: Node2D = $Grund
@onready var _wild: Node2D = $Wild

## --- Wo wir gerade sind ---
##
## Im Menue laeuft das Spiel weiter, nur steuert es niemand: ein Daumen, der
## im Kreis geht, faehrt das Boot. **Das ist der Titelbildschirm aus dem
## Entwurf** - Logo und Knoepfe vor einer laufenden Szene, nicht vor einem
## Standbild. Ein Standbild sagt "hier waere ein Spiel", eine laufende Szene
## sagt "so sieht es aus".
enum Lage { MENUE, SPIEL, ENDE }

var lage := Lage.MENUE

## Gesetzt, wenn diese Szene sofort wieder verlassen wird.
var _abgetreten := false

var welle_nummer := 1
var huelle := 12
var huelle_voll := 12
var erlegt := 0

## --- Was das HUD anzeigt ---
##
## Punkte und Kette wie im Schlund: die Kette zahlt einen Faktor auf Punkte
## und **niemals** Naehrstoff (Zusage 16). Sie ist eine Bestmarke, keine
## Waehrung - sonst haette wer gut faehrt eine andere Wirtschaft.
var punkte := 0
## Naehrstoff dieser Fahrt - dieselbe Waehrung wie im Schlund, und derselbe
## Weg dorthin (`Fortschritt.aendere`).
var verdient := 0
## Der Bruchteil, der noch nicht ausgezahlt ist. Siehe `_lohne()`.
var _lohn_rest := 0.0
var kette := 0
var kette_hoechste := 0
var _kette_zeit := 0.0

## Das Stosslicht, wie im Schlund: eine zweite Handlung, die sich auflaedt.
var _stoss_kuehl := 0.0
var _stoss_weit := -1.0
var _stoss_nr := 0

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

## Kielwasser: die letzten Orte des Bootes. Ein Schiff ohne Spur sieht aus,
## als stuende das Wasser still.
var _spur: Array[Vector2] = []

## Wie stark das Boot in die Kurve legt. Aus der Drehrate gerechnet, nicht
## gewuerfelt - wer nach rechts zieht, sieht das Boot nach rechts kippen, und
## genau das macht eine Bewegung lesbar, bevor sie stattgefunden hat.
var _neigung := 0.0

## Was vom Graben schon aufgedeckt ist. Oeffentlich, weil das HUD es anzeigt.
var karte: Karte = null

## Fundstellen, die in dieser Sitzung geholt wurden - fuer die Anzeige.
var funde := 0

## Ohne Nebel starten. Nur fuer Werkzeuge (`--offen`): ein Schuss vom Grund
## zeigt sonst schwarze Felder statt des Riffs, das er zeigen soll.
var _offene_karte := false

## Nur fuer Werkzeuge (`--ende`): den Bericht mit Beispielwerten zeigen.
var _zeige_ende := false


func _ready() -> void:
    # Der Gegenweg zu `--rundum`: die Werkzeuge (Ladenbilder, Schuesse,
    # Bildratenmessung) wollen direkt in die Schlundwache.
    if "--schlund" in OS.get_cmdline_user_args():
        _abgetreten = true
        get_tree().change_scene_to_file.call_deferred(
            "res://scenes/schlund.tscn")
        return

    _lies_argumente()
    karte = Karte.new(Rundum.FELD_RADIUS)
    _grund.karte = null if _offene_karte else karte
    karte.decke_auf(_ort)
    _vorn.draw.connect(_zeichne_vorn)
    _schwarm.led = true
    _hud.lauf = self
    _menue.lauf = self
    _kamera.position = _ort
    _kegel.halbwinkel = Graben.HALBWINKEL
    _kegel.reichweite = Graben.REICHWEITE
    for i in 3:
        _begleiter.append(Vector2.ZERO)
        _begleiter_ziel.append(-1)
    _bereite_welle_vor()
    if _zeige_ende:
        starte()
        welle_nummer = 14
        punkte = 128400
        verdient = 9260
        erlegt = 372
        funde = 5
        kette_hoechste = 26
        huelle = 0
        lage = Lage.ENDE
    if not _schuss.is_empty():
        _nimm_auf.call_deferred()


func _bereite_welle_vor() -> void:
    _tiere.clear()
    _wellenzeit = 0.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x52554e44 + welle_nummer
    # **Mehr Tiere als im Schlund, und das ist Absicht.** Dort steht der
    # Waechter fest und der Kegel deckt einen Sektor; hier faehrt man, sieht
    # in alle Richtungen und hat drei Begleiter dabei. Eine Wellenstaerke,
    # die fuer einen festen Posten gerechnet ist, fuehlt sich in Fahrt leer
    # an.
    #
    # Genommen werden deshalb `DICHTE` Wellen auf einmal, ineinander
    # geschoben. Dass das hier gehen darf und im Schlund nicht, hat einen
    # Grund: der Wellenpruefer misst diese Schleife nicht - ein simulierter
    # Daumen ersetzt kein Fahrkoennen -, also haengt an dieser Zahl auch
    # keine Zusage. Sie wird von Hand gesetzt und von Hand nachgesehen.
    var eintraege: Array[Dictionary] = []
    for versatz in DICHTE:
        for e in Wellen.auftritte(welle_nummer + versatz):
            var kopie := e.duplicate()
            # Ineinander statt hintereinander: sonst kaeme Welle zwei erst,
            # wenn Welle eins durch ist, und das waere dreimal so lang statt
            # dreimal so voll.
            kopie[&"zeit"] = float(e[&"zeit"]) \
                + float(versatz) * rng.randf_range(0.4, 1.6)
            eintraege.append(kopie)
    for eintrag in eintraege:
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
        # Der Winkel steht fest, der Ort noch nicht: gesetzt wird er erst,
        # wenn das Tier an der Reihe ist - dann steht das Boot woanders.
        t.start_x = anteil * TAU + rng.randf_range(-0.12, 0.12)
        t.ort = _ort + Rundum.eintritt(t.start_x)
        t.richtung = (_ort - t.ort).normalized()
        # Jeder Vierte lauert - aber **kein Leitwesen**. Ein Hoehepunkt, den
        # man verpassen kann, weil man zufaellig woanders faehrt, ist keiner;
        # und einer, in den man hineinfaehrt, ohne ihn kommen zu sehen, ist
        # kein Kampf, sondern ein Unfall.
        if not Arten.ist_leitwesen(t.art) and rng.randf() < LAUER_ANTEIL:
            t.lauert = true
            # Sofort da, nicht erst zur Eintrittszeit: er liegt ja schon in
            # der Karte, bevor die Welle beginnt.
            t.eintritt = 0.0
            t.ort = Rundum.gehalten(_ort + Vector2.RIGHT.rotated(
                rng.randf_range(0.0, TAU))
                * rng.randf_range(LAUER_NAH, LAUER_WEIT), 60.0)
            t.richtung = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
        _tiere.append(t)
    _offen = _tiere.size()
    _schwarm.tiere = _tiere


func _process(delta: float) -> void:
    if _abgetreten:
        return
    delta = Graben.takt(delta)
    _wellenzeit += delta
    _schuetteln = maxf(0.0, _schuetteln - delta * 4.0)
    # **Die Kamera folgt und schaut voraus.** Nur folgen hiesse, das Boot
    # klebt in der Mitte und man sieht in Fahrtrichtung genauso weit wie
    # nach hinten - dabei ist vorn das, was zaehlt. Der Vorlauf haengt an
    # der Fahrt, nicht am Blick: sonst schwenkt das Bild beim Zielen mit und
    # macht seekrank.
    var voraus := _fahrt * KAMERA_VORAUS
    _kamera.position = _kamera.position.lerp(_ort + voraus,
        clampf(KAMERA_TRAEGHEIT * delta, 0.0, 1.0))
    _kamera.offset = Vector2(randf_range(-1.0, 1.0),
        randf_range(-1.0, 1.0)) * _schuetteln * 7.0

    _stoss_kuehl = maxf(0.0, _stoss_kuehl - delta)
    _kette_zeit = maxf(0.0, _kette_zeit - delta)
    if _kette_zeit <= 0.0 and kette > 0:
        kette = 0
    if lage != Lage.SPIEL:
        # Der Vorfuehrdaumen. Er geht im Kreis und haelt dabei an - so sieht
        # man Fahrt und Drehung, ohne dass jemand tippt.
        var w := _wellenzeit * 0.42
        _finger = Vector2.RIGHT.rotated(w) * (150.0 + 130.0 * sin(w * 0.7))
        _zieht = true

    _fuehre_boot(delta)
    _wild.boot = _ort
    _decke_auf()
    _fuehre_stoss(delta)
    _fuehre_begleiter(delta)
    _bewege(delta)
    _wecke_die_letzten()
    _verbrenne(delta)

    if _offen <= 0 and huelle > 0:
        welle_nummer += 1
        _bereite_welle_vor()
    if huelle <= 0 and lage == Lage.SPIEL:
        _beende()

    _schwarm.queue_redraw()
    _vorn.queue_redraw()
    queue_redraw()


## Was befahren wurde, ist bekannt - und was dabei gefunden wird, wird geholt.
##
## **Beides an einer Stelle**, weil ein Fund nur zu sehen ist, wo schon
## aufgedeckt wurde: erst der Kegel, dann der Griff.
func _decke_auf() -> void:
    karte.decke_auf(_ort)
    if lage != Lage.SPIEL:
        return
    var fund: Dictionary = _grund.hole_fund(_ort)
    if fund.is_empty():
        return
    funde += 1
    # Punkte, kein Naehrstoff - siehe `grund_rundum.gd::FUND_PUNKTE`.
    punkte += int(fund[&"punkte"])
    _funken.platzen(Vector2(fund[&"ort"]), Color(1.0, 0.84, 0.52), 34.0)
    _schuetteln = maxf(_schuetteln, 0.35)
    Klang.spiele(Klang.Ton.KAMMER, 0.8, 0.5)
    Tastsinn.gib(Tastsinn.Art.STOSS)


## Ein Finger, zwei Aufgaben: Blickrichtung immer, Fahrt ab der Totzone.
func _fuehre_boot(delta: float) -> void:
    var soll := Schlund.zielrichtung(_ort, _finger, _blick)
    var vorher := _blick
    _blick = Schlund.gedreht(_blick, soll, DREH_TEMPO, delta)

    # Neigung aus der tatsaechlichen Drehung, gedaempft. Ein Sprung waere ein
    # Zucken; die Daempfung macht daraus ein Einlegen und Aufrichten.
    var gedreht := angle_difference(vorher.angle(), _blick.angle())
    var ziel_neigung := clampf(gedreht / maxf(0.0001, DREH_TEMPO * delta),
        -1.0, 1.0)
    _neigung = lerpf(_neigung, ziel_neigung, clampf(6.0 * delta, 0.0, 1.0))

    var wunsch := Vector2.ZERO
    if _zieht:
        wunsch = Rundum.fahrt(_ort, _finger, BOOT_TEMPO)
    _fahrt = _fahrt.lerp(wunsch, clampf(BOOT_TRAEGHEIT * delta, 0.0, 1.0))
    _ort = Rundum.gehalten(_ort + _fahrt * delta, BOOT_RADIUS)
    # **Die Felsen sind fest.** Herausgeschoben statt angehalten: wer
    # anhaelt, klebt am Stein und ist trivial zu treffen; wer
    # herausgeschoben wird, gleitet daran entlang.
    var vor_stein := _ort
    _ort = _grund.abgestossen(_ort, BOOT_RADIUS)
    if _ort != vor_stein:
        # Die Fahrt entlang der Kante behalten, den Anteil in den Stein
        # hinein wegnehmen. Ohne das drueckt man sich am Stein fest.
        var raus := (_ort - vor_stein).normalized()
        _fahrt -= raus * minf(0.0, _fahrt.dot(raus)) * 2.0
        _fahrt = _fahrt.limit_length(BOOT_TEMPO)

    # Die Spur wird nur gesetzt, wenn sich wirklich etwas bewegt - sonst
    # sammelt ein stehendes Boot hundert Punkte an derselben Stelle.
    if _spur.is_empty() or _spur[_spur.size() - 1].distance_to(_ort) > 7.0:
        _spur.append(_ort)
        if _spur.size() > SPUR_LAENGE:
            _spur.remove_at(0)

    _kegel.spitze = _ort
    _kegel.richtung = _blick
    _kegel.queue_redraw()


## Vom Menue aus: los.
func starte() -> void:
    lage = Lage.SPIEL
    _zieht = false
    huelle = huelle_voll
    punkte = 0
    kette = 0
    erlegt = 0
    funde = 0
    verdient = 0
    _lohn_rest = 0.0
    welle_nummer = 1
    # **Ein neuer Tauchgang faengt im Dunkeln an.** Die Karte laeuft sonst
    # aus dem Menue heraus voll - der Vorfuehrdaumen faehrt dort im Kreis -,
    # und das erste Bild des Spiels waere ein aufgedeckter Graben.
    karte = Karte.new(Rundum.FELD_RADIUS)
    _grund.karte = null if _offene_karte else karte
    karte.decke_auf(_ort)
    _grund.setze_funde_zurueck()
    _bereite_welle_vor()


## Die Fahrt ist vorbei: die Huelle ist durch.
##
## **Der Koloniefortschritt bleibt.** Verloren ist die Fahrt, nicht die
## Arbeit - das ist dieselbe Zusage wie im Schlund, und der Naehrstoff ist
## laengst ausgezahlt, weil er je erlegtem Tier faellt und nicht am Ende.
func _beende() -> void:
    lage = Lage.ENDE
    _zieht = false
    Klang.spiele(Klang.Ton.BRUT_FAELLT, 1.0, 0.55)
    Tastsinn.gib(Tastsinn.Art.ENDE)
    Fortschritt.sichere()


## Wieviele Raeuber noch offen sind - das HUD zeigt es an.
func offen() -> int:
    return _offen


## Ob gerade ein Leitwesen im Feld steht.
func leitwesen_da() -> bool:
    for t in _tiere:
        if t.lebendig and t.alter >= 0.0 and Arten.ist_leitwesen(t.art):
            return true
    return false


## Ob das Stosslicht bereit ist, und wie weit es geladen hat.
func stoss_bereit() -> bool:
    return _stoss_kuehl <= 0.0


func stoss_ladung() -> float:
    return clampf(1.0 - _stoss_kuehl / Graben.STOSS_ABKUEHLUNG, 0.0, 1.0)


## Ein Ring, der vom Boot nach aussen laeuft und trifft, was er kreuzt -
## auch ausserhalb des Kegels. Dieselbe Rechnung wie im Schlund, nur dass
## die Spitze mitfaehrt.
func stosslicht() -> bool:
    if not stoss_bereit():
        return false
    _stoss_kuehl = Graben.STOSS_ABKUEHLUNG
    _stoss_weit = 0.0
    _stoss_nr += 1
    _schuetteln = maxf(_schuetteln, 0.7)
    Klang.spiele(Klang.Ton.WELLE, 0.7, 0.9)
    Tastsinn.gib(Tastsinn.Art.STOSS)
    return true


func _fuehre_stoss(delta: float) -> void:
    if _stoss_weit < 0.0:
        return
    var vorher := _stoss_weit
    _stoss_weit += Graben.STOSS_TEMPO * delta
    if _stoss_weit > Rundum.FELD_RADIUS * 2.2:
        _stoss_weit = -1.0
        return
    for t in _tiere:
        if not t.lebendig or t.alter < 0.0 or t.stoss_nr == _stoss_nr:
            continue
        var d := t.ort.distance_to(_ort)
        if d >= vorher and d < _stoss_weit:
            t.stoss_nr = _stoss_nr
            _wecke(t)
            t.leben -= Schlund.schaden_an(
                Graben.LEISTUNG * Ausbau.leistung_faktor(welle_nummer),
                1.0, Wellen.panzer_in(t.art, t.welle),
                Wellen.mindest_licht_in(t.art, t.welle), 1.0) \
                * Graben.STOSS_WERT
            t.hitze = 1.0


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
        var vorher_alter := t.alter
        t.alter = _wellenzeit - t.eintritt
        if t.alter < 0.0:
            continue
        if t.lauert:
            # Er liegt still. Erst der Abstand weckt ihn - und dann bleibt er
            # wach, auch wenn man wieder wegfaehrt.
            if t.ort.distance_to(_ort) > WECK_RADIUS:
                continue
            _wecke(t)
            continue
        if vorher_alter < 0.0:
            # Erster Schritt: jetzt einsetzen, um das Boot herum.
            t.ort = _ort + Rundum.eintritt(t.start_x)
            t.richtung = (_ort - t.ort).normalized()
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
            if lage == Lage.SPIEL:
                huelle = maxi(0, huelle - Arten.wucht(t.art))
            # Ein Treffer bricht die Kette. Das ist der Preis, der sie zur
            # Spannung macht - sonst waere sie eine Zahl, die nur steigt.
            kette = 0
            _kette_zeit = 0.0
            _schuetteln = maxf(_schuetteln, 1.0)
            Klang.spiele(Klang.Ton.BRUT_FAELLT, 1.0, 0.8)
            Tastsinn.gib(Tastsinn.Art.TREFFER)
            _funken.platzen(t.ort, Color(1.0, 0.42, 0.34), 22.0)
            # Zurueckwerfen statt entfernen.
            t.ort = _ort + (t.ort - _ort).normalized() * (BOOT_RADIUS + 190.0)
            t.eintritt = _wellenzeit + BISS_SPERRE


## Einen Lauerer wecken. Eine Stelle, weil es drei Anlaesse gibt: Naehe, ein
## Treffer, und das Ende der uebrigen Welle.
func _wecke(t: Raeuber) -> void:
    if not t.lauert:
        return
    t.lauert = false
    _funken.platzen(t.ort, Arten.farbe(t.art), 12.0)
    Klang.spiele(Klang.Ton.WELLE, 0.5, 1.35)


## **Wenn sonst nichts mehr steht, kommen die Uebrigen.**
##
## Ohne das haengt die Welle an einem Lauerer, der vierzehnhundert Einheiten
## entfernt im Dunkeln liegt: die Anzeige sagt "1 LEFT", und der Spieler
## faehrt die Karte ab, um ihn zu suchen. Ein Hinterhalt soll ueberraschen
## und nicht die Sitzung aufhalten.
func _wecke_die_letzten() -> void:
    for t in _tiere:
        # **Ohne `alter` gefragt.** Der erste Anlauf zaehlte nur, was schon
        # im Feld steht - und zu Wellenbeginn steht noch nichts da, weil
        # jeder Auftritt seine Zeit hat. Damit erwachten alle Lauerer in der
        # ersten Sekunde, und der Hinterhalt war eine Ankuendigung.
        if t.lebendig and not t.lauert:
            return
    for t in _tiere:
        if t.lebendig:
            _wecke(t)


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
        _wecke(t)
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
            kette += 1
            kette_hoechste = maxi(kette_hoechste, kette)
            _kette_zeit = Graben.KETTE_FENSTER
            punkte += int(round(float(Wellen.wert_in(t.art, t.welle))
                * Graben.kette_faktor(kette)))
            _lohne(t)
            if Arten.ist_leitwesen(t.art):
                Tastsinn.gib(Tastsinn.Art.LEITWESEN)
            _funken.platzen(t.ort, Arten.farbe(t.art), 20.0)
            Klang.spiele(Klang.Ton.TOD, 0.9, 0.45)


## Naehrstoff fuer ein erlegtes Tier - **geteilt durch `DICHTE`**.
##
## Im Schlund summiert sich `Wellen.wert_in()` ueber eine Welle genau zu
## `Wellen.ertrag()`. Hier laufen `DICHTE` Wellen ineinander, also liegen
## dreimal so viele Koerper im Feld; wer jeden voll bezahlte, zahlte fuer
## eine Welle den dreifachen Ertrag. Einkommen und Kosten sind aneinander
## gekoppelt (Zusage 10) - eine Schleife, die dasselbe Spiel dreimal so
## schnell bezahlt, ist eine zweite Wirtschaft.
##
## Der Bruchteil wird mitgenommen und nicht weggerundet: bei kleinen Wellen
## ist `wert_in` einstellig, und ein Drittel davon waere sonst je nach
## Rundung null oder das Doppelte des Richtigen.
func _lohne(t: Raeuber) -> void:
    # **Nur im Spiel.** Hinter dem Titelbild und hinter dem Bericht laeuft
    # die Szene weiter, und der Vorfuehrdaumen erlegt dabei Tiere. Ohne
    # diese Zeile verdient ein Telefon, das auf dem Titelbild liegen bleibt,
    # echten Naehrstoff - im Schuss des Berichts standen 9261 statt der 9260,
    # die ich hineingeschrieben hatte.
    if lage != Lage.SPIEL:
        return
    _lohn_rest += float(Wellen.wert_in(t.art, t.welle)) / float(DICHTE)
    var lohn := int(floor(_lohn_rest))
    if lohn <= 0:
        return
    _lohn_rest -= float(lohn)
    verdient += lohn
    Fortschritt.aendere(lohn)


func _unhandled_input(ereignis: InputEvent) -> void:
    if _finger_fest or lage != Lage.SPIEL:
        return
    if ereignis is InputEventScreenTouch:
        if ereignis.pressed and _hud.stossknopf.has_point(ereignis.position):
            stosslicht()
            return
        _zieht = ereignis.pressed
        _finger = _welt(ereignis.position)
    elif ereignis is InputEventScreenDrag:
        _finger = _welt(ereignis.position)
    elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
        if ereignis.pressed and _hud.stossknopf.has_point(ereignis.position):
            stosslicht()
            return
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
const HAUT_TIEF := Color(0.055, 0.135, 0.170)
const GLUT := Color(1.0, 0.86, 0.58)
const SPUR_LAENGE := 26


## Hinter allem: nur der Rand des Feldes.
func _draw() -> void:
    _zeichne_rand()


## Vor allem: Spur, Begleiter, Boot.
func _zeichne_vorn() -> void:
    _zeichne_spur()
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


## Kielwasser: aufgewirbeltes Wasser hinter dem Boot, das ausblendet.
##
## Es wird **von hinten nach vorn** gezeichnet und dabei breiter und heller,
## damit die Spur zum Boot hin anwaechst statt gleichmaessig zu liegen. Eine
## Spur von gleicher Dicke ist ein Strich, keine Bewegung.
func _zeichne_spur() -> void:
    if _spur.size() < 3:
        return
    var tempo := clampf(_fahrt.length() / BOOT_TEMPO, 0.0, 1.0)
    for i in range(1, _spur.size()):
        var t := float(i) / float(_spur.size())
        var a := 0.10 * t * t * (0.25 + 0.75 * tempo)
        _vorn.draw_line(_spur[i - 1], _spur[i],
            Color(0.56, 0.86, 0.92, a), 1.0 + 7.0 * t * t, true)


## --- Das Boot ---
##
## **Drei Anlaeufe, und die ersten beiden waren derselbe Fehler.** Erst ein
## Sechseck, dann ein Klotz mit acht Ecken und einer Kanzel, die halb so gross
## war wie der Rumpf. Beide Male eine **Flaeche mit Umriss darauf** - und
## damit an der Sprache des Spiels vorbei.
##
## Alles andere hier - die zwoelf Arten, die Ranken, der Waechter - ist aus
## **Linien** gebaut: ein weiter, blasser Zug als Hof und ein schmaler,
## heller darauf. Die Flaeche ist nur dazu da, das Dahinter abzudecken. Das
## hat zwei Gruende, und der zweite ist technisch:
##
##   1. In der Tiefsee traegt die Kante die Form, nicht der Koerper. Ein
##      Rumpf, der als Flaeche erzaehlt wird, sieht aus wie ausgeschnittenes
##      Papier.
##   2. **`draw_polygon` ist in Godot nicht kantengeglaettet, `draw_polyline`
##      schon.** Ein Umriss aus Polygonkanten ist auf einem Telefon eine
##      Treppe. Genau das war mit "zu pixelig" gemeint.
##
## Und der Umriss ist jetzt eine **Kurve**, keine Kette aus acht Geraden: die
## Halbbreite kommt aus einer glatten Funktion, abgetastet in 64 Schritten.
##
## Alles relativ zu `_blick` und dessen Senkrechten, wie die Tierkunst auch -
## deshalb sieht das Boot in jeder Fahrtrichtung richtig aus.

## Wie fein der Rumpf abgetastet wird. 64 ist der Punkt, ab dem man auf einem
## Telefon keine Ecke mehr sieht; darueber kostet es nur noch.
const RUMPF_STUFEN := 64

## Die Form: `(1 - u)^NASE * (1 + u)^HECK`, mit `u` von -1 am Heck bis 1 an
## der Nase. Der groessere Wert am Heck macht es schlank, der kleinere an der
## Nase rund - ein Tauchboot ist vorn stumpf und hinten spitz, nicht
## umgekehrt. Die breiteste Stelle liegt damit bei `(HECK - NASE) /
## (HECK + NASE)`, also gut ein Drittel vor der Mitte.
const FORM_NASE := 0.52
const FORM_HECK := 1.30
const RUMPF_LANG := 1.85
const RUMPF_BREIT := 0.50

var _profil: PackedVector2Array = []


## Einmal rechnen, nicht je Bild: `pow()` 64-mal je Bild waere fuer eine
## Form, die sich nie aendert, verschenkt.
func _baue_profil() -> void:
    _profil.resize(RUMPF_STUFEN)
    var groesste := 0.0
    for i in RUMPF_STUFEN:
        var u := lerpf(-1.0, 1.0, float(i) / float(RUMPF_STUFEN - 1))
        var b := pow(1.0 - u, FORM_NASE) * pow(1.0 + u, FORM_HECK)
        groesste = maxf(groesste, b)
        _profil[i] = Vector2(u, b)
    for i in RUMPF_STUFEN:
        _profil[i].y /= maxf(0.0001, groesste)


func _zeichne_boot() -> void:
    var k := _blick
    var quer := k.orthogonal()
    var r := BOOT_RADIUS
    var tempo := clampf(_fahrt.length() / BOOT_TEMPO, 0.0, 1.0)
    # Die Neigung staucht die Silhouette auf der Innenseite der Kurve. Ein
    # gekipptes Boot zeigt weniger Breite - mehr Perspektive braucht es
    # nicht, um "es legt sich in die Kurve" zu erzaehlen.
    var eng := Vector2(1.0 - 0.30 * maxf(0.0, _neigung),
        1.0 - 0.30 * maxf(0.0, -_neigung))

    var umriss := _boot_umriss(k, quer, r, eng)
    _zeichne_antrieb(k, quer, r, tempo)
    _zeichne_flossen(k, quer, r, eng)
    _zeichne_rumpf(umriss, k, r)
    _zeichne_spanten(k, quer, r, eng)
    _zeichne_turm(k, quer, r)
    _zeichne_kanzel(k, quer, r)
    _zeichne_scheinwerfer(k, quer, r)
    _zeichne_huellring(r)


## Der geschlossene Umriss: einmal die eine Flanke entlang, dann die andere
## zurueck. In dieser Reihenfolge, damit er sich nicht selbst kreuzt.
func _boot_umriss(k: Vector2, quer: Vector2, r: float,
        eng: Vector2) -> PackedVector2Array:
    if _profil.is_empty():
        _baue_profil()
    var punkte := PackedVector2Array()
    for i in RUMPF_STUFEN:
        var pr := _profil[i]
        punkte.append(_ort + k * pr.x * r * RUMPF_LANG
            + quer * pr.y * r * RUMPF_BREIT * eng.y)
    for j in RUMPF_STUFEN:
        var pr := _profil[RUMPF_STUFEN - 1 - j]
        punkte.append(_ort + k * pr.x * r * RUMPF_LANG
            - quer * pr.y * r * RUMPF_BREIT * eng.x)
    return punkte


## Der Rumpf: dunkle Flaeche zum Abdecken, darauf Linienzuege.
##
## **In einem Stueck, nicht abschnittsweise.** Der Anlauf davor zog jede
## Kante einzeln, um den Saum vorn hell und hinten dunkel zu bekommen. Bei
## 128 Abschnitten auf hundert Pixeln ist jeder zwei Pixel lang - und
## `draw_line` setzt an jedes Ende eine runde Kappe. Die Kappen ueberlappten
## sich zu einer Perlenkette; im Bild sah der Saum gepunktet aus. Ein
## `draw_polyline` zieht den ganzen Zug mit einer Kappe.
##
## Vorn hell und hinten dunkel kommt jetzt daher, dass der helle Zug **nur
## ueber die vordere Haelfte** laeuft - zwei Zuege statt hundert Abschnitten.
func _zeichne_rumpf(umriss: PackedVector2Array, k: Vector2, r: float) -> void:
    _vorn.draw_colored_polygon(umriss, Color(0.020, 0.052, 0.068))
    var ring := umriss + PackedVector2Array([umriss[0]])
    _vorn.draw_polyline(ring, Color(HAUT.r, HAUT.g, HAUT.b, 0.09), 5.0, true)
    _vorn.draw_polyline(ring, Color(HAUT.r, HAUT.g, HAUT.b, 0.30), 1.5, true)

    # Der vordere Bogen noch einmal, heller. Wo "vorn" ist, sagt das Profil
    # und nicht eine zweite Zahl.
    var vorne := PackedVector2Array()
    for punkt in ring:
        if (punkt - _ort).dot(k) > 0.0:
            vorne.append(punkt)
    if vorne.size() > 2:
        _vorn.draw_polyline(vorne, Color(HAUT.r, HAUT.g, HAUT.b, 0.52),
            1.5, true)


## Spanten und Kiellinie - die Linien, die aus einem Umriss einen Koerper
## machen. Sie folgen der Rumpfbreite an ihrer Stelle, laufen also nie ueber
## die Kante hinaus.
func _zeichne_spanten(k: Vector2, quer: Vector2, r: float,
        eng: Vector2) -> void:
    _vorn.draw_line(_ort - k * r * RUMPF_LANG * 0.72,
        _ort + k * r * RUMPF_LANG * 0.86,
        Color(HAUT.r, HAUT.g, HAUT.b, 0.16), 1.0, true)

    for anteil: float in [-0.30, 0.10, 0.48]:
        var i := int(clampf((anteil + 1.0) * 0.5, 0.0, 1.0)
            * float(RUMPF_STUFEN - 1))
        var breit: float = _profil[i].y * r * RUMPF_BREIT
        var mitte := _ort + k * _profil[i].x * r * RUMPF_LANG
        var bogen := PackedVector2Array()
        for j in 9:
            var t := lerpf(-1.0, 1.0, float(j) / 8.0)
            var seit: float = eng.x if t < 0.0 else eng.y
            # Ein leichter Bogen statt einer Geraden: ein Spant liegt auf
            # einem runden Rumpf und ist deshalb im Bild gekruemmt.
            bogen.append(mitte + quer * t * breit * seit
                + k * (1.0 - t * t) * r * 0.09)
        _vorn.draw_polyline(bogen, Color(HAUT.r, HAUT.g, HAUT.b, 0.17),
            1.0, true)


## Die Tiefenruder am Heck.
##
## **Sie sassen erst mittschiffs und waren zu gross** - 1.34 Rumpfradien nach
## aussen bei 0.66 Rumpfbreite, also viermal so breit wie das Boot, und sie
## legten sich als zwei grosse Boegen quer darueber. Ein Ruder ist ein
## Anhang, kein zweiter Rumpf, und es sitzt hinten: dort, wo es lenkt.
##
## **Und es ist ein Blatt mit vier Ecken, keine zwei Kurven auf eine Spitze
## zu.** Der Anlauf davor zog zwei Bezier von den beiden Wurzeln auf denselben
## Punkt, mit Kontrollpunkten, die gegeneinander liefen - bei schmalem Heck
## kreuzten sie sich, und Godot meldete "triangulation failed" und zeichnete
## gar nichts. Vier Ecken, aussen herum in einer Richtung, koennen das nicht.
func _zeichne_flossen(k: Vector2, quer: Vector2, r: float,
        eng: Vector2) -> void:
    if _profil.is_empty():
        _baue_profil()
    for seite: float in SEITEN:
        var s: float = eng.x if seite < 0.0 else eng.y
        var i_vorn := int(0.32 * float(RUMPF_STUFEN - 1))
        var i_hinten := int(0.10 * float(RUMPF_STUFEN - 1))
        var wurzel_vorn := _ort + k * _profil[i_vorn].x * r * RUMPF_LANG \
            + quer * seite * _profil[i_vorn].y * r * RUMPF_BREIT * s
        var wurzel_hinten := _ort + k * _profil[i_hinten].x * r * RUMPF_LANG \
            + quer * seite * _profil[i_hinten].y * r * RUMPF_BREIT * s
        var spitze_vorn := _ort - k * r * 1.02 + quer * seite * r * 0.76 * s
        var spitze_hinten := _ort - k * r * 1.46 + quer * seite * r * 0.60 * s

        var kante := PackedVector2Array()
        # Vorderkante: leicht gewoelbt nach vorn, damit das Blatt nicht wie
        # ein Dreieck aus dem Bausatz aussieht.
        for j in 9:
            var t := float(j) / 8.0
            var g := 1.0 - t
            kante.append(wurzel_vorn * (g * g)
                + (wurzel_vorn + quer * seite * r * 0.30 * s) * (2.0 * g * t)
                + spitze_vorn * (t * t))
        kante.append(spitze_hinten)
        kante.append(wurzel_hinten)

        _vorn.draw_colored_polygon(kante, Color(0.016, 0.042, 0.058))
        var zu := kante + PackedVector2Array([kante[0]])
        _vorn.draw_polyline(zu, Color(HAUT.r, HAUT.g, HAUT.b, 0.07), 3.2, true)
        _vorn.draw_polyline(zu, Color(HAUT.r, HAUT.g, HAUT.b, 0.34), 1.1, true)
        _vorn.draw_circle(spitze_vorn, 1.6, Color(0.52, 0.96, 0.86, 0.75))


## Zwei Duesen hinten. Ein Strahl, der schmaler wird - kein Balken.
func _zeichne_antrieb(k: Vector2, quer: Vector2, r: float,
        tempo: float) -> void:
    for seite: float in SEITEN:
        var duese := _ort - k * r * 1.28 + quer * seite * r * 0.28
        var laenge := r * (0.30 + 2.2 * tempo)
        var glut := 0.14 + 0.70 * tempo
        # In Abschnitten, jeder duenner und blasser als der davor. Ein
        # `draw_line` hat ueberall dieselbe Dicke und endet als Klotz;
        # genau so sah es aus.
        var stufen := 7
        for i in stufen:
            var t0 := float(i) / float(stufen)
            var t1 := float(i + 1) / float(stufen)
            var a := duese - k * laenge * t0
            var b := duese - k * laenge * t1
            var dick := r * 0.26 * (1.0 - t0) * (1.0 - t0)
            _vorn.draw_line(a, b, Color(0.44, 0.82, 1.0,
                0.30 * glut * (1.0 - t0)), maxf(0.6, dick), true)
        _vorn.draw_circle(duese, r * 0.10,
            Color(0.72, 0.94, 1.0, 0.30 + 0.5 * glut))


## Der Turm.
##
## **Das ist das eine Merkmal, an dem man ein Tauchboot von oben erkennt.**
## Ohne ihn war der Rumpf ein Blatt mit Streben darauf - laenglich, spitz,
## symmetrisch, und man haette ebenso gut einen Fisch darin sehen koennen.
## Ein Turm bricht die Symmetrie in der Laengsachse und sagt in einer Form,
## wo vorn ist und dass jemand darin sitzt.
##
## Er steht ein Drittel hinter dem Bug, wie bei einem echten Boot auch, und
## er ist schmal: er soll den Rumpf gliedern, nicht ihn ersetzen.
func _zeichne_turm(k: Vector2, quer: Vector2, r: float) -> void:
    var mitte := _ort + k * r * 0.42
    var lang := r * 0.52
    var breit := r * 0.21

    var umriss := PackedVector2Array()
    var stufen := 22
    for i in stufen:
        var w := TAU * float(i) / float(stufen)
        # Vorn spitzer als hinten - auch der Turm zeigt, wohin es geht.
        var laengs := cos(w)
        var voll := 1.0 + 0.18 * laengs
        umriss.append(mitte + k * laengs * lang
            + quer * sin(w) * breit * voll)
    _vorn.draw_colored_polygon(umriss, Color(0.030, 0.078, 0.098))
    var zu := umriss + PackedVector2Array([umriss[0]])
    _vorn.draw_polyline(zu, Color(HAUT.r, HAUT.g, HAUT.b, 0.10), 4.0, true)
    _vorn.draw_polyline(zu, Color(HAUT.r, HAUT.g, HAUT.b, 0.62), 1.4, true)

    # Zwei Vorflossen am Turm - die Ruder, mit denen ein Boot steigt und
    # sinkt. Zwei kurze Striche, mehr braucht es bei dieser Groesse nicht.
    for seite: float in SEITEN:
        var wurzel := mitte + quer * seite * breit * 0.9
        _vorn.draw_line(wurzel, wurzel + quer * seite * r * 0.40
            - k * r * 0.06, Color(HAUT.r, HAUT.g, HAUT.b, 0.38), 2.2, true)


## Die Druckkanzel. Der einzige warme Punkt am ganzen Boot - alles andere ist
## kalt und blau, und deshalb sieht man sofort, wo jemand sitzt.
##
## **Klein und leise.** Im zweiten Anlauf hatte sie einen halben Rumpf
## Durchmesser und drei Lagen Glut darin; im Bild war das ein weisser Fleck,
## der den Rumpf verschluckte. Ein Fenster ist kein Scheinwerfer.
func _zeichne_kanzel(k: Vector2, quer: Vector2, r: float) -> void:
    var mitte := _ort + k * r * 0.54
    _vorn.draw_circle(mitte, r * 0.17, Color(0.014, 0.040, 0.056))
    _vorn.draw_circle(mitte, r * 0.105, Color(GLUT.r, GLUT.g, GLUT.b, 0.42))
    _vorn.draw_arc(mitte, r * 0.17, 0.0, TAU, 20,
        Color(HAUT.r, HAUT.g, HAUT.b, 0.55), 1.1, true)
    # Zwei Streben ueber die Kuppel: das ist der Unterschied zwischen einem
    # Fenster und einem Fleck.
    for versatz: float in SEITEN:
        var m := (k * 0.4 + quer * versatz).normalized()
        _vorn.draw_line(mitte - m * r * 0.16, mitte + m * r * 0.16,
            Color(HAUT.r, HAUT.g, HAUT.b, 0.26), 0.9, true)
    _vorn.draw_circle(mitte + (k + quer).normalized() * r * 0.08, r * 0.035,
        Color(1.0, 0.98, 0.92, 0.55))


## Das Scheinwerfergehaeuse. Es sitzt dort, wo `Schlund.beleuchtung()` ihre
## Spitze hat - was leuchtet, macht Schaden, also soll man sehen, woher es
## kommt.
func _zeichne_scheinwerfer(k: Vector2, quer: Vector2, r: float) -> void:
    var nase := _ort + k * r * 1.42
    var buegel := PackedVector2Array()
    for j in 11:
        var t := lerpf(-1.0, 1.0, float(j) / 10.0)
        buegel.append(nase + quer * t * r * 0.30 - k * (t * t) * r * 0.26)
    _vorn.draw_polyline(buegel, Color(HAUT.r, HAUT.g, HAUT.b, 0.10), 3.0, true)
    _vorn.draw_polyline(buegel, Color(HAUT.r, HAUT.g, HAUT.b, 0.62), 1.3, true)
    _vorn.draw_circle(nase, r * 0.17, Color(0.80, 1.0, 0.96, 0.14))
    _vorn.draw_circle(nase, r * 0.075, Color(1.0, 1.0, 0.96, 0.92))


## Die Huelle als Ring um das Boot - keine Leiste am Bildrand, sondern dort,
## wo der Daumen ohnehin hinsieht.
##
## Gezeichnet werden **Striche je Punkt Huelle**, nicht ein Bogen: bei einem
## Bogen sieht man, dass etwas fehlt, aber nicht wieviel, und "wieviele Fehler
## habe ich noch" ist die einzige Zahl, die waehrend der Fahrt zaehlt.
## Eng am Rumpf und duenn - ein Messgeraet, kein Schmuck.
func _zeichne_huellring(r: float) -> void:
    if huelle_voll <= 0:
        return
    var radius := r * 1.72
    var luecke := TAU / float(huelle_voll)
    for i in huelle_voll:
        var von := -PI * 0.5 + luecke * float(i) + luecke * 0.24
        var bis := von + luecke * 0.52
        var voll := i < huelle
        _vorn.draw_arc(_ort, radius, von, bis, 5,
            Color(0.50, 0.90, 0.88, 0.26) if voll
            else Color(0.90, 0.36, 0.28, 0.18), 1.4, true)


## --- Die Begleiter ---
##
## Wehrpolypen, die mitfahren. Vorher drei Kreise; das sagte weder, was sie
## sind, noch dass sie zur Kolonie gehoeren. Ein Polyp ist ein Kelch auf einem
## Stiel mit Fangarmen - und weil er mitschwimmt, stehen die Arme nach hinten,
## in die Stroemung.
func _zeichne_begleiter() -> void:
    for i in _begleiter.size():
        var p: Vector2 = _begleiter[i]
        var atem := 0.5 + 0.5 * sin(_wellenzeit * BEGLEITER_TAKT
            + float(i) * 2.1)
        var k := (p - _ort)
        if k.length_squared() < 1.0:
            k = -_blick
        k = k.normalized()
        var quer := k.orthogonal()
        var gr := 13.0
        var grund := Color(0.34, 0.94, 0.76)

        # Fangarme nach hinten, in die Stroemung. Jeder ist ein Zug mit Hof -
        # dieselbe Machart wie beim Boot, damit Begleiter und Boot als
        # dieselbe Kolonie lesbar sind.
        for a in 5:
            var t := float(a) / 4.0
            var w := lerpf(-0.9, 0.9, t)
            var arm := PackedVector2Array()
            for j in 5:
                var u := float(j) / 4.0
                var wiege := sin(_wellenzeit * 2.1 + float(a) + float(i)) \
                    * 0.30 * u * u
                arm.append(p + (k * gr * (0.5 + 1.9 * u)).rotated(
                    w * 0.55 + wiege))
            _leitzug(arm, grund, 0.30 + 0.10 * atem, 1.2)

        # Der Kelch: zwei Ringe statt einer Scheibe. Eine Scheibe wird vom
        # Gluehen milchig, ein Ring wird davon zu einer Roehre.
        _vorn.draw_arc(p, gr * 0.74, 0.0, TAU, 22,
            Color(grund.r, grund.g, grund.b, 0.16), 4.2, true)
        _vorn.draw_arc(p, gr * 0.74, 0.0, TAU, 22,
            Color(0.66, 1.0, 0.90, 0.75), 1.5, true)
        _vorn.draw_arc(p, gr * 0.40, 0.0, TAU, 16,
            Color(0.52, 0.98, 0.84, 0.42), 1.1, true)
        # Der Kern - der einzige gefuellte Fleck, und er ist winzig.
        _vorn.draw_circle(p, gr * (0.17 + 0.05 * atem),
            Color(0.86, 1.0, 0.94, 0.95))

        # Der Strahl auf sein Ziel.
        var n: int = _begleiter_ziel[i]
        if n >= 0 and n < _tiere.size() and _tiere[n].lebendig:
            var ziel: Vector2 = _tiere[n].ort
            _vorn.draw_line(p, ziel, Color(grund.r, grund.g, grund.b, 0.12),
                4.0, true)
            _vorn.draw_line(p, ziel, Color(0.80, 1.0, 0.92,
                0.42 + 0.18 * atem), 1.3, true)


## Ein Leuchtzug: weiter blasser Hof, schmaler heller Kern.
func _leitzug(punkte: PackedVector2Array, farbe: Color, deckung: float,
        dicke: float) -> void:
    if punkte.size() < 2:
        return
    _vorn.draw_polyline(punkte, Color(farbe.r, farbe.g, farbe.b,
        deckung * 0.30), dicke * 3.4, true)
    _vorn.draw_polyline(punkte, Color(minf(1.0, farbe.r * 1.4),
        minf(1.0, farbe.g * 1.4), minf(1.0, farbe.b * 1.4), deckung * 1.9),
        dicke, true)


# --- Aufnahme ---------------------------------------------------------------
#
# Dieselben Schalter wie im Schlund, damit man den Versuch mit denselben
# Befehlen ansehen kann: `--welle`, `--zeit`, `--schuss`. Ohne sie laeuft die
# Szene ganz normal.

var _schuss := ""
var _vorlauf := 0.0
var _finger_fest := false
var _sofort := false


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
            "--ende":
                # Den Bericht ansehen, ohne erst zu sterben.
                _zeige_ende = true
            "--offen":
                # Kein Nebel - fuer Schuesse, die den Grund zeigen sollen.
                _offene_karte = true
            "--spiel":
                # Nicht im Menue aufnehmen, sondern im Spiel.
                _sofort = true


func _spiele_vor() -> void:
    if _sofort:
        starte()
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
    # Wo das Boot steht, damit man den Ausschnitt nicht im Bild suchen muss.
    print("BOOT %.1f %.1f  KAMERA %.1f %.1f  strom=%s"
        % [_ort.x, _ort.y, _kamera.position.x, _kamera.position.y,
        str(_kamera.is_current())])
    # **Zwei Bilder warten, nicht eins.** Die Kamera traegt ihren Ort nicht
    # selbst ins Bild ein - das tut sie in ihrer eigenen Verarbeitung, und
    # die laeuft im Vorlauf nicht mit, weil dort nur `_process()` dieses
    # Knotens gerufen wird. Nach einem einzigen `frame_post_draw` zeichnete
    # der Schuss deshalb noch mit der Verschiebung vom Anfang: das Boot stand
    # am Bildrand, obwohl Kamera und Boot am selben Ort standen.
    await get_tree().process_frame
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var bild := get_viewport().get_texture().get_image()
    bild.save_png(_schuss)
    get_tree().quit()
