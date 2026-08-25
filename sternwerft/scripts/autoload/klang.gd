## Kurze Rückmeldungstöne, zur Laufzeit berechnet.
##
## Keine Audiodateien: die Rechtelage bleibt damit so eindeutig wie bei der
## Grafik, und das Paket wächst um kein einziges Byte. Die Töne sind bewusst
## knapp und leise - ein Idle-Spiel läuft nebenbei, und was nebenbei läuft,
## darf nicht nerven.
##
## Erreichbar als Autoload [code]Klang[/code].
extends Node

enum Art { KAUF, AUSBAU, FUND, PRESTIGE, TIPP }

const ABTASTRATE := 22050

## Gleichzeitig spielbare Töne. Mehr braucht es nicht; bei schnellem Tippen
## soll der vorige Ton abgelöst werden statt sich zu stapeln.
const STIMMEN := 4

## Ob Töne ausgegeben werden. Wird über den Spielstand gesichert.
var an := true

var _stimmen: Array[AudioStreamPlayer] = []
var _naechste := 0
var _vorrat: Dictionary = {}


func _ready() -> void:
    for i in STIMMEN:
        var p := AudioStreamPlayer.new()
        p.bus = "Master"
        add_child(p)
        _stimmen.append(p)


## Spielt einen Ton, sofern der Ton eingeschaltet ist.
func spiele(art: Art) -> void:
    if not an or _stimmen.is_empty():
        return
    if not _vorrat.has(art):
        _vorrat[art] = _erzeuge(art)
    var p := _stimmen[_naechste]
    _naechste = (_naechste + 1) % _stimmen.size()
    p.stream = _vorrat[art]
    p.volume_db = -14.0
    p.play()


## Baut den Ton einmalig und hebt ihn auf.
func _erzeuge(art: Art) -> AudioStreamWAV:
    match art:
        Art.KAUF:
            return _ton(0.09, 780.0, 780.0, 0.55, 2.0)
        Art.AUSBAU:
            return _ton(0.20, 620.0, 990.0, 0.55, 1.5)
        Art.FUND:
            return _ton(0.34, 1180.0, 1320.0, 0.45, 1.2)
        Art.PRESTIGE:
            return _ton(0.60, 900.0, 240.0, 0.50, 1.0)
        Art.TIPP:
            return _ton(0.05, 460.0, 520.0, 0.35, 3.0)
    return _ton(0.08, 600.0, 600.0, 0.4, 2.0)


## Erzeugt einen Ton mit gleitender Tonhöhe und abklingender Lautstärke.
##
## [param abfall] steuert, wie schnell der Ton ausklingt - hohe Werte machen
## ihn perkussiv, niedrige lassen ihn nachhallen.
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

        # Grundton plus leise Oktave darüber: allein klingt eine Sinuswelle
        # dumpf und geht auf Handylautsprechern unter.
        var welle := sin(phase) * 0.8 + sin(phase * 2.0) * 0.2

        # Kurzer Einsatz, damit es nicht knackt, danach exponentielles Abklingen.
        var huelle := minf(t / 0.02, 1.0) * exp(-abfall * t * 3.0)

        var wert := int(clampf(welle * huelle * staerke, -1.0, 1.0) * 32767.0)
        daten.encode_s16(i * 2, wert)

    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = ABTASTRATE
    s.stereo = false
    s.data = daten
    return s
