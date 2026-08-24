## Aufbau und Darstellung der Station.
##
## Ordnet die acht Baugruppen in zwei Spalten um den Kern an. Das Layout ist
## fest von Hand gesetzt statt gewuerfelt: eine Station, die immer gleich
## aussieht, wird zur vertrauten Umgebung, und der Spieler findet die Baugruppe,
## die er sucht, ohne zu suchen.
class_name Station
extends Node2D

## Mehr Drohnen als das gleichzeitig sind Zierrat ohne Mehrwert und kosten
## auf schwachen Geraeten Bildrate.
const MAX_DROHNEN := 10

signal modul_angetippt(index: int)
signal kern_angetippt

var _module: Array[ModulKnoten] = []
var _kern: Kern
var _drohnen: Array[Drohne] = []


func _ready() -> void:
    _baue_module()
    _baue_kern()
    _baue_drohnen()

    Spielstand.bestand_geaendert.connect(_bei_bestand)
    Spielstand.credits_geaendert.connect(_bei_credits)
    aktualisiere()


func _baue_module() -> void:
    for i in Modul.ANZAHL:
        var k := ModulKnoten.new()
        k.index = i
        k.position = Raster.modul_position(i)
        add_child(k)
        _module.append(k)


func _baue_kern() -> void:
    _kern = Kern.new()
    _kern.position = Vector2.ZERO
    add_child(_kern)


func _baue_drohnen() -> void:
    for i in MAX_DROHNEN:
        var d := Drohne.new()
        d.visible = false
        add_child(d)
        _drohnen.append(d)


func _bei_bestand(_index: int, _anzahl: int) -> void:
    aktualisiere()
    _verteile_drohnen()


func _bei_credits(_wert: float) -> void:
    # Nur die Bezahlbarkeit anpassen; das ist billig und haelt die
    # Kaufhinweise aktuell.
    for k in _module:
        k.aktualisiere(Spielstand.bestand[k.index],
            Oekonomie.kosten(k.index, Spielstand.bestand[k.index]) <= Spielstand.credits)


func aktualisiere() -> void:
    for k in _module:
        k.aktualisiere(Spielstand.bestand[k.index],
            Oekonomie.kosten(k.index, Spielstand.bestand[k.index]) <= Spielstand.credits)
    queue_redraw()


## Verteilt die Drohnen gleichmaessig auf die Baugruppen, die etwas leisten.
func _verteile_drohnen() -> void:
    var aktive: Array[int] = []
    for i in Modul.ANZAHL:
        if Spielstand.bestand[i] > 0:
            aktive.append(i)

    for n in _drohnen.size():
        var d := _drohnen[n]
        if aktive.is_empty():
            d.visible = false
            continue
        var index: int = aktive[n % aktive.size()]
        d.visible = true
        # Versatz auf der Strecke, damit sie nicht im Pulk fliegen.
        d.starte(_module[index].position, kern_andockpunkt(_module[index].position),
            Modul.farbe(index),
            float(n) / float(_drohnen.size()))


# --- Treffererkennung -------------------------------------------------------

## Index der Baugruppe unter [param punkt], sonst -1.
func modul_bei(punkt: Vector2) -> int:
    for k in _module:
        if k.trefferflaeche().has_point(punkt):
            return k.index
    return -1


func kern_bei(punkt: Vector2) -> bool:
    return _kern.trefferflaeche().has_point(punkt)


## Rueckmeldung nach erfolgreichem Antippen des Kerns.
func kern_blitzen() -> void:
    _kern.aufblitzen()


## Punkt auf dem Kernrand, der [param von] zugewandt ist.
func kern_andockpunkt(von: Vector2) -> Vector2:
    var richtung := (von - _kern.position).normalized()
    return _kern.position + richtung * (Kern.RADIUS + 4.0)


## Umschliessendes Rechteck der Station - die Kamera begrenzt sich daran.
func ausmasse() -> Rect2:
    var r := Rect2(_module[0].trefferflaeche())
    for k in _module:
        r = r.merge(k.trefferflaeche())
    return r


func _draw() -> void:
    # Versorgungsleitungen von jeder Baugruppe zum Kern. Sie erklaeren
    # wortlos, warum die Drohnen genau diese Wege fliegen.
    for k in _module:
        var aktiv := Spielstand.bestand[k.index] > 0
        var farbe := Modul.farbe(k.index)
        farbe.a = 0.55 if aktiv else 0.12
        var ansatz := k.position + Vector2(
            ModulKnoten.GROESSE.x * 0.5 * (1.0 if k.position.x < 0.0 else -1.0), 0.0)
        # Am Rand des Kerns enden, nicht im Mittelpunkt: sonst treffen sich alle
        # acht Leitungen in einem Punkt und der Kern verschwindet im Geknaeuel.
        draw_line(ansatz, kern_andockpunkt(k.position), farbe, 3.0 if aktiv else 2.0, true)
