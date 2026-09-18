extends Node

## **Stahl, gerechnet.**
##
## Es gibt in diesem Spiel keine Tondatei. Jeder Klang entsteht hier aus
## Zahlen - das ist der Urheberrechtsnachweis und nicht nur ein Stil.
##
## **Und der Ton traegt hier Spielinformation, nicht Stimmung.** Der Tick
## beim Ansatz ist der Taktgeber: wer ihn hoert, weiss, dass eine Linie
## angefangen hat, auch wenn er gerade woanders hinsieht. Deshalb ist er
## kurz, trocken und immer gleich - ein Ansatzton, der je nach Gegner anders
## klingt, waere eine zweite Aussage ueber dieselbe Sache.

enum Ton { ANSATZ, PARADE, SCHNITT, WUNDE, GEFALLEN, RONDE, TIPP }

const RATE := 22050
const STIMMEN := 8

var laut := 0.7:
    set(wert):
        laut = clampf(wert, 0.0, 1.0)
        _bus_setzen()

var _stimmen: Array[AudioStreamPlayer] = []
var _naechste := 0
var _vorrat := {}


func _ready() -> void:
    for i in STIMMEN:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _stimmen.append(p)
    _vorrat[Ton.ANSATZ] = _ansatz()
    _vorrat[Ton.PARADE] = _parade()
    _vorrat[Ton.SCHNITT] = _schnitt()
    _vorrat[Ton.WUNDE] = _wunde()
    _vorrat[Ton.GEFALLEN] = _gefallen()
    _vorrat[Ton.RONDE] = _ronde()
    _vorrat[Ton.TIPP] = _tipp()
    _bus_setzen()


func _bus_setzen() -> void:
    for p in _stimmen:
        if is_instance_valid(p):
            p.volume_db = linear_to_db(maxf(0.0001, laut))


func spiele(was: Ton, hoehe := 1.0, staerke := 1.0) -> void:
    if laut <= 0.001 or not _vorrat.has(was):
        return
    var p := _stimmen[_naechste]
    _naechste = (_naechste + 1) % _stimmen.size()
    p.stream = _vorrat[was]
    p.pitch_scale = clampf(hoehe, 0.4, 2.4)
    p.volume_db = linear_to_db(clampf(laut * staerke, 0.0001, 1.0))
    p.play()


# --- Erzeugung -------------------------------------------------------------

static func _stream(m: PackedFloat32Array) -> AudioStreamWAV:
    var daten := PackedByteArray()
    daten.resize(m.size() * 2)
    for i in m.size():
        daten.encode_s16(i * 2, int(clampf(m[i], -1.0, 1.0) * 32767.0))
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = RATE
    s.stereo = false
    s.data = daten
    return s


## **Anfang und Ende stehen auf null.** Ein Puffer, der bei halber Auslenkung
## einsetzt, ist ein Knacks und kein Schlag - dieser Fehler ist hier schon
## einmal gemessen worden und kostet keinen Gedanken mehr, wenn die Huelle
## ihn von selbst verhindert.
static func _huelle(laenge: int, anstieg: float, abfall: float) -> PackedFloat32Array:
    var h := PackedFloat32Array()
    h.resize(laenge)
    var an := maxi(1, int(laenge * anstieg))
    for i in laenge:
        if i < an:
            h[i] = float(i) / float(an)
        else:
            var t := float(i - an) / float(maxi(1, laenge - an))
            h[i] = pow(maxf(0.0, 1.0 - t), abfall)
    return h


## Metall: mehrere unharmonische Teiltoene. Genau das unterscheidet eine
## Glocke von einer Saite - ganzzahlige Vielfache klingen nach Ton, krumme
## nach Blech.
static func _metall(laenge: int, grund: float, teile: PackedFloat32Array,
        abfall: float) -> PackedFloat32Array:
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.004, abfall)
    for i in laenge:
        var t := float(i) / float(RATE)
        var s := 0.0
        for k in teile.size():
            # Hohe Teiltoene verklingen schneller - sonst steht am Ende ein
            # Pfeifen statt eines Nachhalls.
            s += sin(TAU * grund * teile[k] * t) \
                * pow(h[i], 1.0 + float(k) * 0.55) / float(k + 2)
        m[i] = s
    return m


## Der Taktgeber: ein trockener Holzschlag.
static func _ansatz() -> AudioStreamWAV:
    var laenge := int(RATE * 0.055)
    var m := _metall(laenge, 640.0, PackedFloat32Array([1.0, 2.7]), 5.5)
    var h := _huelle(laenge, 0.005, 6.0)
    for i in laenge:
        m[i] = m[i] * 0.55 + (randf() * 2.0 - 1.0) * h[i] * 0.10
        m[i] *= 0.5
    return _stream(m)


## Die Parade: Stahl auf Stahl. Hell, kurz, mit einer langen duennen Fahne.
static func _parade() -> AudioStreamWAV:
    var laenge := int(RATE * 0.42)
    var m := _metall(laenge, 1180.0,
        PackedFloat32Array([1.0, 2.37, 3.81, 5.43, 7.11]), 3.2)
    var h := _huelle(laenge, 0.002, 9.0)
    for i in laenge:
        m[i] = m[i] * 0.62 + (randf() * 2.0 - 1.0) * h[i] * 0.30
    return _stream(m)


## Der Schnitt: ein Zischen, das anschwillt und abreisst. Kein Ton, nur Luft.
static func _schnitt() -> AudioStreamWAV:
    var laenge := int(RATE * 0.20)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var letzte := 0.0
    for i in laenge:
        var t := float(i) / float(laenge)
        # Das Rauschen wird zur Mitte hin heller: erst Luft, dann Kante.
        var roh := randf() * 2.0 - 1.0
        var glaette := lerpf(0.72, 0.18, t)
        letzte = lerpf(letzte, roh, 1.0 - glaette)
        m[i] = letzte * sin(t * PI) * 0.75
    return _stream(m)


## Die Wunde: ein dumpfer Schlag in den Leib, kein Klang.
static func _wunde() -> AudioStreamWAV:
    var laenge := int(RATE * 0.28)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.004, 4.0)
    for i in laenge:
        var t := float(i) / float(RATE)
        # Die Tonhoehe faellt - das ist es, was einen Schlag von einem Ton
        # unterscheidet.
        var f := lerpf(148.0, 58.0, clampf(float(i) / float(laenge), 0.0, 1.0))
        m[i] = (sin(TAU * f * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.25) * h[i]
    return _stream(m)


static func _gefallen() -> AudioStreamWAV:
    var laenge := int(RATE * 0.50)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.01, 2.6)
    for i in laenge:
        var t := float(i) / float(RATE)
        var f := lerpf(96.0, 42.0, clampf(float(i) / float(laenge), 0.0, 1.0))
        m[i] = (sin(TAU * f * t) * 0.75 + (randf() * 2.0 - 1.0) * 0.16) * h[i]
    return _stream(m)


## Der Rondenbeginn: ein tiefer Trommelschlag mit Nachhall.
static func _ronde() -> AudioStreamWAV:
    var laenge := int(RATE * 0.9)
    var m := _metall(laenge, 88.0, PackedFloat32Array([1.0, 2.1, 3.4]), 2.0)
    for i in laenge:
        m[i] *= 0.9
    var versatz := int(RATE * 0.09)
    for i in range(versatz, laenge):
        m[i] += m[i - versatz] * 0.30
    return _stream(m)


static func _tipp() -> AudioStreamWAV:
    var laenge := int(RATE * 0.04)
    var m := _metall(laenge, 880.0, PackedFloat32Array([1.0, 3.3]), 7.0)
    for i in laenge:
        m[i] *= 0.35
    return _stream(m)
