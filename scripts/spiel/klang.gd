## Rückmeldungstöne, zur Laufzeit berechnet.
##
## Keine Audiodateien: die Rechtelage bleibt so eindeutig wie bei der Grafik,
## und das Paket wächst um kein Byte.
##
## Der wichtigste Einzeleffekt ist die **steigende Tonhöhe je Abprall**. Sie
## macht eine lange Kette hörbar zum Erfolg, bevor irgendeine Zahl erscheint -
## und sie ist der Grund, warum Spieler von selbst anfangen, auf Ketten zu
## spielen, ohne dass es ihnen jemand sagt.
class_name Klang
extends Node

enum Art { WURF, PRALL, TREFFER, GERAEUMT, LEER }

const ABTASTRATE := 22050

## Gleichzeitig spielbare Töne. Bei schnellen Ketten soll der vorige abgelöst
## werden, statt sich zu stapeln.
const STIMMEN := 6

## Halbtonschritt. Zwölf davon sind eine Oktave.
const HALBTON := 1.059463

var an := true

var _stimmen: Array[AudioStreamPlayer] = []
var _naechste := 0
var _vorrat: Dictionary = {}


func _ready() -> void:
    for i in STIMMEN:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _stimmen.append(p)


## Spielt einen Ton. [param kette] hebt die Tonhöhe je Halbton an.
func spiele(art: Art, kette: int = 0) -> void:
    if not an or _stimmen.is_empty():
        return
    if not _vorrat.has(art):
        _vorrat[art] = _erzeuge(art)

    var p := _stimmen[_naechste]
    _naechste = (_naechste + 1) % _stimmen.size()
    p.stream = _vorrat[art]
    # Nach oben begrenzt: jenseits von zwei Oktaven wird es schrill statt
    # belohnend.
    p.pitch_scale = pow(HALBTON, float(clampi(kette, 0, 24)))
    p.volume_db = _lautstaerke(art)
    p.play()


static func _lautstaerke(art: Art) -> float:
    match art:
        Art.WURF: return -12.0
        Art.PRALL: return -15.0
        Art.TREFFER: return -9.0
        Art.GERAEUMT: return -7.0
    return -13.0


func _erzeuge(art: Art) -> AudioStreamWAV:
    match art:
        Art.WURF:
            return _ton(0.10, 320.0, 210.0, 0.60, 2.4)
        Art.PRALL:
            return _ton(0.075, 640.0, 700.0, 0.50, 3.6)
        Art.TREFFER:
            return _ton(0.24, 480.0, 180.0, 0.60, 1.6)
        Art.GERAEUMT:
            return _ton(0.70, 300.0, 900.0, 0.55, 0.7)
        Art.LEER:
            return _ton(0.34, 220.0, 120.0, 0.45, 1.4)
    return _ton(0.08, 400.0, 400.0, 0.4, 2.0)


## Erzeugt einen Ton mit gleitender Tonhöhe und abklingender Lautstärke.
func _ton(dauer: float, von_hz: float, nach_hz: float, staerke: float,
        abfall: float) -> AudioStreamWAV:
    var anzahl := int(dauer * float(ABTASTRATE))
    var daten := PackedByteArray()
    daten.resize(anzahl * 2)

    var phase := 0.0
    for i in anzahl:
        var t := float(i) / float(anzahl)
        var hz := lerpf(von_hz, nach_hz, t)
        phase += TAU * hz / float(ABTASTRATE)

        # Grundton plus leise Oktave: eine reine Sinuswelle klingt dumpf und
        # geht auf Handylautsprechern unter.
        var welle := sin(phase) * 0.78 + sin(phase * 2.0) * 0.22

        # Kurzer Einsatz, sonst knackt es hörbar.
        var huelle := minf(t / 0.02, 1.0) * exp(-abfall * t * 3.0)

        daten.encode_s16(i * 2,
            int(clampf(welle * huelle * staerke, -1.0, 1.0) * 32767.0))

    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = ABTASTRATE
    s.stereo = false
    s.data = daten
    return s
