extends Node

## **Der Klang, gerechnet.**
##
## Es gibt in diesem Spiel keine Tondatei. Jeder Laut entsteht hier aus
## Zahlen - das ist der Urheberrechtsnachweis und nicht nur ein Stil.
##
## **Und er wird gemessen, nicht gehoert.** Es gibt in diesem Behaelter kein
## Audiogeraet und in CI erst recht keines; die Puffer entstehen ins Blinde.
## Anfang und Ende stehen deshalb konstruktionsbedingt auf null (`_huelle`):
## ein Puffer, der bei halber Auslenkung einsetzt, ist ein Knacks und kein
## Schlag.
##
## **Sparsam ist hier Pflicht.** In Minute neun fallen dreissig Feinde je
## Sekunde. Wer jeden Tod klingen laesst, hat kein Gefecht mehr, sondern ein
## Rauschen - `Lauf` drosselt deshalb, und die Toene sind kurz.

enum Ton { HIEB, TREFFER, BOLZEN, WUNDE, MUENZE, AUFSTIEG, HORN, TIPP }

const RATE := 22050
const STIMMEN := 12

var laut := 0.7:
    set(wert):
        laut = clampf(wert, 0.0, 1.0)

var _stimmen: Array[AudioStreamPlayer] = []
var _naechste := 0
var _vorrat := {}


func _ready() -> void:
    for i in STIMMEN:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _stimmen.append(p)
    _vorrat[Ton.HIEB] = _hieb()
    _vorrat[Ton.TREFFER] = _treffer()
    _vorrat[Ton.BOLZEN] = _bolzen()
    _vorrat[Ton.WUNDE] = _wunde()
    _vorrat[Ton.MUENZE] = _muenze()
    _vorrat[Ton.AUFSTIEG] = _aufstieg()
    _vorrat[Ton.HORN] = _horn()
    _vorrat[Ton.TIPP] = _tipp()


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


## Metall: unharmonische Teiltoene. Genau das unterscheidet eine Glocke von
## einer Saite - ganzzahlige Vielfache klingen nach Ton, krumme nach Blech.
static func _metall(laenge: int, grund: float, teile: PackedFloat32Array,
        abfall: float) -> PackedFloat32Array:
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.004, abfall)
    for i in laenge:
        var t := float(i) / float(RATE)
        var s := 0.0
        for k in teile.size():
            s += sin(TAU * grund * teile[k] * t) \
                * pow(h[i], 1.0 + float(k) * 0.55) / float(k + 2)
        m[i] = s
    return m


## Der Hieb: Luft, die anschwillt und abreisst. Kein Ton, nur Zischen.
static func _hieb() -> AudioStreamWAV:
    var laenge := int(RATE * 0.16)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var letzte := 0.0
    for i in laenge:
        var t := float(i) / float(laenge)
        letzte = lerpf(letzte, randf() * 2.0 - 1.0, 1.0 - lerpf(0.74, 0.20, t))
        m[i] = letzte * sin(t * PI) * 0.55
    return _stream(m)


## Der Treffer: ein kurzer, stumpfer Schlag. Nicht metallisch - getroffen
## wird Leder und Fleisch, nicht Blech.
static func _treffer() -> AudioStreamWAV:
    var laenge := int(RATE * 0.085)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.003, 5.0)
    for i in laenge:
        var t := float(i) / float(RATE)
        var f := lerpf(210.0, 90.0, clampf(float(i) / float(laenge), 0.0, 1.0))
        m[i] = (sin(TAU * f * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * h[i] * 0.5
    return _stream(m)


static func _bolzen() -> AudioStreamWAV:
    var laenge := int(RATE * 0.10)
    var m := _metall(laenge, 1420.0, PackedFloat32Array([1.0, 2.9]), 8.0)
    var h := _huelle(laenge, 0.002, 9.0)
    for i in laenge:
        m[i] = m[i] * 0.35 + (randf() * 2.0 - 1.0) * h[i] * 0.22
    return _stream(m)


static func _wunde() -> AudioStreamWAV:
    var laenge := int(RATE * 0.30)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.004, 3.6)
    for i in laenge:
        var t := float(i) / float(RATE)
        var f := lerpf(160.0, 52.0, clampf(float(i) / float(laenge), 0.0, 1.0))
        m[i] = (sin(TAU * f * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.28) * h[i]
    return _stream(m)


## Die Muenze: hell, kurz, zwei Teiltoene - man muss sie dreissigmal in einer
## Minute hoeren koennen, ohne dass es weh tut.
static func _muenze() -> AudioStreamWAV:
    var laenge := int(RATE * 0.11)
    var m := _metall(laenge, 2050.0, PackedFloat32Array([1.0, 2.41]), 7.0)
    for i in laenge:
        m[i] *= 0.28
    return _stream(m)


## Der Aufstieg: ein aufsteigender Dreiklang. Der einzige Laut im Spiel, der
## eine Melodie hat - und er faellt genau dann, wenn alles stehenbleibt.
static func _aufstieg() -> AudioStreamWAV:
    var laenge := int(RATE * 0.55)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var stufen := PackedFloat32Array([392.0, 523.0, 659.0])
    for k in stufen.size():
        var von := int(float(k) * 0.12 * RATE)
        var h := _huelle(laenge - von, 0.01, 4.0)
        for i in range(von, laenge):
            var t := float(i - von) / float(RATE)
            m[i] += sin(TAU * stufen[k] * t) * h[i - von] * 0.26
    return _stream(m)


## Das Horn des Warlords: tief, lang, zwei Quinten. Es kuendigt an und
## unterbricht nicht - deshalb schwillt es an, statt zu knallen.
static func _horn() -> AudioStreamWAV:
    var laenge := int(RATE * 1.4)
    var m := PackedFloat32Array()
    m.resize(laenge)
    var h := _huelle(laenge, 0.18, 1.6)
    for i in laenge:
        var t := float(i) / float(RATE)
        m[i] = (sin(TAU * 98.0 * t) * 0.5 + sin(TAU * 147.0 * t) * 0.3
            + sin(TAU * 196.0 * t) * 0.15) * h[i] * 0.7
    return _stream(m)


static func _tipp() -> AudioStreamWAV:
    var laenge := int(RATE * 0.04)
    var m := _metall(laenge, 900.0, PackedFloat32Array([1.0, 3.3]), 7.0)
    for i in laenge:
        m[i] *= 0.3
    return _stream(m)
