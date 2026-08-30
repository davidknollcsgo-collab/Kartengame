extends Node

## Ton, zur Laufzeit erzeugt.
##
## **Keine einzige Audiodatei im Projekt.** Das ist dieselbe Entscheidung wie
## bei der Grafik und aus demselben Grund: was hier klingt, hat genau eine
## Quelle - diesen Quelltext. `ASSETS.md` fuehrt entsprechend keine Tondatei.
##
## Alles entsteht aus `AudioStreamWAV` mit von Hand gefuellten Puffern. Das
## ist weniger Aufwand als es klingt: ein Treffer ist eine gefilterte
## Rauschfahne, ein Blubbern ein Sinus mit fallender Tonhoehe.

const RATE := 22050
const STIMMEN := 10

## Die Tiefsee ist gedaempft. Nichts hier klingt hell oder trocken - alles
## bekommt einen Nachhall aus dem Wasser.
const HALL := 0.28

enum Ton { TREFFER, TOD, BRUT_FAELLT, POLYP, KAMMER, WELLE, TIPP }

var laut := 0.7:
    set(wert):
        laut = clampf(wert, 0.0, 1.0)
        _bus_setzen()

var _stimmen: Array[AudioStreamPlayer] = []
var _naechste := 0
var _vorrat := {}

## --- Grundton des Grabens ---
##
## Zwischen den Wellen war es still, und Stille ist im Wasser das Einzige, was
## es nicht gibt. Ein tiefer, sehr leiser Grundton laeuft deshalb immer - und
## er wechselt mit dem Grabenabschnitt: tiefer, je weiter unten, und rauer,
## wo das Wasser aufgewuehlt ist.
##
## Es ist derselbe Weg wie bei allen anderen Toenen - ein gerechneter Puffer,
## keine Datei. Nur laeuft dieser in Schleife.
const GRUND_LAENGE := 6.0
const GRUND_LAUT := 0.16

var _grundton: AudioStreamPlayer
var _grund_abschnitt := -1


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for _i in STIMMEN:
        var p := AudioStreamPlayer.new()
        p.bus = &"Master"
        add_child(p)
        _stimmen.append(p)

    _vorrat[Ton.TREFFER] = _treffer()
    _vorrat[Ton.TOD] = _tod()
    _vorrat[Ton.BRUT_FAELLT] = _brut_faellt()
    _vorrat[Ton.POLYP] = _polyp()
    _vorrat[Ton.KAMMER] = _kammer()
    _vorrat[Ton.WELLE] = _welle()
    _vorrat[Ton.TIPP] = _tipp()

    _grundton = AudioStreamPlayer.new()
    _grundton.bus = &"Master"
    _grundton.volume_db = linear_to_db(GRUND_LAUT)
    add_child(_grundton)
    setze_abschnitt(0)

    _bus_setzen()


## Stellt den Grundton auf einen Grabenabschnitt um.
##
## Wird beim Wellenstart gerufen. Der Puffer wird nur neu gerechnet, wenn sich
## der Abschnitt wirklich aendert - sechs Sekunden Ton zu erzeugen kostet
## genug, um es nicht je Welle zu tun.
func setze_abschnitt(abschnitt: int) -> void:
    if abschnitt == _grund_abschnitt or _grundton == null:
        return
    _grund_abschnitt = abschnitt
    var strom := _grund(abschnitt)
    strom.loop_mode = AudioStreamWAV.LOOP_FORWARD
    strom.loop_begin = 0
    strom.loop_end = strom.data.size() / 2 - 1
    _grundton.stream = strom
    if laut > 0.001:
        _grundton.play()


func _bus_setzen() -> void:
    var db := -80.0 if laut <= 0.001 else linear_to_db(laut)
    AudioServer.set_bus_volume_db(0, db)
    if _grundton == null:
        return
    # Bei Ton aus wird der Grundton wirklich angehalten, nicht nur leise
    # gedreht: ein Spieler, der den Ton ausschaltet, will keinen Puffer, der
    # im Hintergrund weiterlaeuft und Strom kostet.
    if laut <= 0.001:
        _grundton.stop()
    elif not _grundton.playing and _grundton.stream != null:
        _grundton.play()


## Der Grundton eines Abschnitts.
##
## Zwei tiefe Sinuswellen mit leicht unreinem Verhaeltnis - dadurch schwebt
## der Ton, statt zu stehen - und darueber gefiltertes Rauschen als Stroemung.
## Anfang und Ende werden ineinandergeblendet, sonst knackt die Schleife an
## der Nahtstelle.
static func _grund(abschnitt: int) -> AudioStreamWAV:
    var laenge := int(RATE * GRUND_LAENGE)
    var m := PackedFloat32Array()
    m.resize(laenge)

    # Je tiefer der Abschnitt, desto tiefer der Ton und desto mehr Stroemung.
    var t_ab := float(clampi(abschnitt, 0, 5)) / 5.0
    var f0 := lerpf(48.0, 31.0, t_ab)
    var f1 := f0 * 1.503
    var rauschen_anteil := lerpf(0.16, 0.42, t_ab)

    var rng := RandomNumberGenerator.new()
    rng.seed = 0x4e454b40 + abschnitt
    var glatt := 0.0
    var p0 := 0.0
    var p1 := 0.0

    for i in laenge:
        var t := float(i) / float(laenge)
        p0 += TAU * f0 / float(RATE)
        p1 += TAU * f1 / float(RATE)
        glatt = lerpf(glatt, rng.randf_range(-1.0, 1.0), 0.012)
        # Ein langsames Atmen ueber die ganze Schleife, damit sie sich nicht
        # als Schleife anhoert.
        var atem := 0.72 + 0.28 * sin(t * TAU)
        m[i] = (sin(p0) * 0.62 + sin(p1) * 0.24
            + glatt * rauschen_anteil) * atem * 0.5

    # Naht schliessen: die letzten Zehntel ueber den Anfang blenden.
    var blende := int(RATE * 0.25)
    for i in blende:
        var f := float(i) / float(blende)
        var j := laenge - blende + i
        m[j] = lerpf(m[j], m[i], f)

    return _stream(m)


## Spielt einen Ton. `hoehe` verschiebt die Tonhoehe - damit klingt der
## zwanzigste Treffer einer Welle nicht wie der erste.
func spiele(was: Ton, hoehe := 1.0, staerke := 1.0) -> void:
    if laut <= 0.001 or not _vorrat.has(was):
        return
    var p := _stimmen[_naechste]
    _naechste = (_naechste + 1) % _stimmen.size()
    p.stream = _vorrat[was]
    p.pitch_scale = clampf(hoehe, 0.4, 2.4)
    p.volume_db = linear_to_db(clampf(staerke, 0.05, 1.0))
    p.play()


# --- Erzeugung -------------------------------------------------------------

static func _stream(muster: PackedFloat32Array) -> AudioStreamWAV:
    var daten := PackedByteArray()
    daten.resize(muster.size() * 2)
    for i in muster.size():
        var wert := int(clampf(muster[i], -1.0, 1.0) * 32767.0)
        daten.encode_s16(i * 2, wert)
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = RATE
    s.stereo = false
    s.data = daten
    return s


## Haengt eine kurze Fahne an, damit nichts trocken abbricht. Im Wasser hoert
## nichts sofort auf.
static func _nachhall(muster: PackedFloat32Array, staerke: float) -> PackedFloat32Array:
    var versatz := int(RATE * 0.035)
    for i in range(versatz, muster.size()):
        muster[i] += muster[i - versatz] * staerke
    return muster


## Weiches Ausklingen ueber den ganzen Puffer.
static func _huelle(laenge: int, anstieg: float, abfall: float) -> PackedFloat32Array:
    var h := PackedFloat32Array()
    h.resize(laenge)
    var an := maxi(1, int(laenge * anstieg))
    for i in laenge:
        var wert := 1.0
        if i < an:
            wert = float(i) / float(an)
        else:
            var t := float(i - an) / float(maxi(1, laenge - an))
            wert = pow(1.0 - t, abfall)
        h[i] = wert
    return h


## Treffer: kurze, helle Rauschfahne. Der Kegel verbrennt etwas.
static func _treffer() -> AudioStreamWAV:
    var laenge := int(RATE * 0.09)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.02, 2.6)
    var rng := RandomNumberGenerator.new()
    rng.seed = 8811
    var glatt := 0.0
    for i in laenge:
        # Tiefpass ueber weissem Rauschen: ein Zischen statt eines Knackens.
        glatt = lerpf(glatt, rng.randf_range(-1.0, 1.0), 0.42)
        m[i] = glatt * h[i] * 0.5
    return _stream(_nachhall(m, HALL))


## Tod eines Raeubers: ein Platzen mit fallender Tonhoehe.
static func _tod() -> AudioStreamWAV:
    var laenge := int(RATE * 0.22)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.01, 2.2)
    var phase := 0.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 2277
    for i in laenge:
        var t := float(i) / float(laenge)
        var f := lerpf(420.0, 96.0, pow(t, 0.55))
        phase += TAU * f / float(RATE)
        m[i] = (sin(phase) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.18) * h[i] * 0.55
    return _stream(_nachhall(m, HALL))


## Die Brut wird getroffen: tief, hart, unangenehm. Das soll wehtun.
static func _brut_faellt() -> AudioStreamWAV:
    var laenge := int(RATE * 0.55)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.004, 1.5)
    var phase := 0.0
    var phase2 := 0.0
    for i in laenge:
        var t := float(i) / float(laenge)
        var f := lerpf(150.0, 44.0, pow(t, 0.4))
        phase += TAU * f / float(RATE)
        phase2 += TAU * (f * 1.51) / float(RATE)
        # Zwei Toene in unrundem Verhaeltnis: das schwebt und klingt falsch,
        # genau richtig fuer einen Verlust.
        m[i] = (sin(phase) * 0.66 + sin(phase2) * 0.3) * h[i] * 0.7
    return _stream(_nachhall(m, 0.4))


## Ein Wehrpolyp wird gesetzt: ein steigendes Blubbern.
static func _polyp() -> AudioStreamWAV:
    var laenge := int(RATE * 0.26)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.06, 2.0)
    var phase := 0.0
    for i in laenge:
        var t := float(i) / float(laenge)
        var f := lerpf(180.0, 540.0, pow(t, 0.7)) + sin(t * 42.0) * 22.0
        phase += TAU * f / float(RATE)
        m[i] = sin(phase) * h[i] * 0.4
    return _stream(_nachhall(m, HALL))


## Eine Kammer ist fertig: drei aufsteigende Toene.
static func _kammer() -> AudioStreamWAV:
    var laenge := int(RATE * 0.7)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var stufen: PackedFloat32Array = [294.0, 392.0, 587.0]
    for k in stufen.size():
        var beginn := int(float(k) * RATE * 0.13)
        var dauer := int(RATE * 0.3)
        var h := _huelle(dauer, 0.02, 2.4)
        var phase := 0.0
        for i in dauer:
            var j := beginn + i
            if j >= laenge:
                break
            phase += TAU * stufen[k] / float(RATE)
            m[j] += (sin(phase) * 0.7 + sin(phase * 2.0) * 0.16) * h[i] * 0.34
    return _stream(_nachhall(m, 0.34))


## Eine Welle beginnt: ein tiefes Anschwellen aus der Dunkelheit.
static func _welle() -> AudioStreamWAV:
    var laenge := int(RATE * 1.1)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var phase := 0.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 5150
    var glatt := 0.0
    for i in laenge:
        var t := float(i) / float(laenge)
        var h := sin(t * PI)
        var f := lerpf(38.0, 82.0, t)
        phase += TAU * f / float(RATE)
        glatt = lerpf(glatt, rng.randf_range(-1.0, 1.0), 0.06)
        m[i] = (sin(phase) * 0.7 + glatt * 0.4) * h * 0.6
    return _stream(m)


## Ein Tippen auf die Bedienung. Kurz und leise - es passiert oft.
static func _tipp() -> AudioStreamWAV:
    var laenge := int(RATE * 0.06)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.03, 3.0)
    var phase := 0.0
    for i in laenge:
        phase += TAU * 660.0 / float(RATE)
        m[i] = sin(phase) * h[i] * 0.24
    return _stream(m)
