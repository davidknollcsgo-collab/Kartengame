## Aufbau und Darstellung der Station.
##
## Ordnet die acht Baugruppen in zwei Spalten um den Kern an. Das Layout ist
## fest von Hand gesetzt statt gewuerfelt: eine Station, die immer gleich
## aussieht, wird zur vertrauten Umgebung, und der Spieler findet die Baugruppe,
## die er sucht, ohne zu suchen.
class_name Station
extends Node2D

## Anzahl Energiepulse je Leitung.
const PULSE := 3

## Wie lange ein Puls von der Baugruppe bis zum Kern braucht, in Sekunden.
const PULS_DAUER := 2.4

## Mehr Drohnen als das gleichzeitig sind Zierrat ohne Mehrwert und kosten
## auf schwachen Geraeten Bildrate.
const MAX_DROHNEN := 10

signal modul_angetippt(index: int)
signal kern_angetippt

var _module: Array[ModulKnoten] = []
var _kern: Kern
var _fund: Fund
var _hinweis: Hinweis
var _drohnen: Array[Drohne] = []

## Läuft für die Energiepulse auf den Versorgungsleitungen.
var _zeit := 0.0


func _ready() -> void:
    _baue_module()
    _baue_kern()
    _baue_drohnen()
    _hinweis = Hinweis.new()
    add_child(_hinweis)

    Spielstand.fund_erschienen.connect(zeige_fund)
    Spielstand.bestand_geaendert.connect(_bei_bestand)
    Spielstand.plasma_geaendert.connect(_bei_credits)
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


func _process(delta: float) -> void:
    _zeit += delta
    queue_redraw()


## Lässt eine aufsteigende Zahl an [param ort] erscheinen.
func zeige_gutschrift(ort: Vector2, text: String, farbe: Color,
        art: Waehrung.Art = Waehrung.Art.PLASMA) -> void:
    var z := SchwebeZahl.new()
    z.position = ort
    add_child(z)
    z.starte(text, farbe, art)


func _bei_bestand(_index: int, _anzahl: int) -> void:
    aktualisiere()
    _verteile_drohnen()
    _aktualisiere_hinweis()


## Kauft an der gewaehlten Baugruppe die eingestellte Menge.
func kaufe_an(index: int) -> bool:
    return Spielstand.kaufe(index, _menge_fuer(index))


func _bei_credits(_wert: float) -> void:
    aktualisiere()


## Tatsaechliche Stueckzahl fuer die gewaehlte Kaufmenge.
##
## Bei "MAX" und leerer Kasse wird 1 zurueckgegeben: der Spieler soll den
## Preis des naechsten Stuecks sehen, nicht eine Null.
func _menge_fuer(index: int) -> int:
    if Spielstand.kaufmenge >= 1:
        return Spielstand.kaufmenge
    return maxi(Oekonomie.max_kaufbar(index, Spielstand.bestand[index],
        Spielstand.plasma), 1)


## Zeigt den Einstiegshinweis an der passenden Stelle oder blendet ihn aus.
func _aktualisiere_hinweis() -> void:
    if _hinweis == null:
        return
    var summe := 0
    for n in Spielstand.bestand:
        summe += n
    var erstpreis := Oekonomie.kosten(0, Spielstand.bestand[0])
    var schritt := Einstieg.naechster(summe, Spielstand.plasma, erstpreis,
        Spielstand.prestige_anzahl)

    match schritt:
        Einstieg.Schritt.KERN:
            _hinweis.setze(Einstieg.text(schritt), Vector2.ZERO, Kern.RADIUS + 14.0)
        Einstieg.Schritt.KAUFEN:
            # Auf die guenstigste Baugruppe zeigen, die gerade bezahlbar ist.
            var ziel := 0
            for k in _module:
                if Oekonomie.kosten(k.index, Spielstand.bestand[k.index]) <= Spielstand.plasma:
                    ziel = k.index
            _hinweis.setze(Einstieg.text(schritt), _module[ziel].position,
                ModulKnoten.GROESSE.x * 0.56)
        _:
            _hinweis.setze("", Vector2.ZERO, 0.0)


func aktualisiere() -> void:
    for k in _module:
        var m := _menge_fuer(k.index)
        var preis := Oekonomie.kosten_summe(k.index, Spielstand.bestand[k.index], m)
        k.aktualisiere(Spielstand.bestand[k.index], m, preis,
            preis <= Spielstand.plasma, Spielstand.modul_stufe[k.index])
    _aktualisiere_hinweis()
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


## Laesst einen Fund quer durchs Bild treiben.
##
## Immer nur einer gleichzeitig: zwei blinkende Ziele wuerden die Station
## selbst in den Hintergrund draengen.
func zeige_fund(art: int) -> void:
    if is_instance_valid(_fund):
        return
    # Knapp ausserhalb der Baugruppenspalten starten und quer hinueber ziehen -
    # so ist der Fund fast seine gesamte Lebensdauer ueber erreichbar.
    var breite := Raster.SPALTE_X * 1.35
    var von_links := randf() < 0.5
    var y := randf_range(Raster.REIHEN_Y[0], Raster.REIHEN_Y[Raster.REIHEN_Y.size() - 1])
    var von := Vector2(-breite if von_links else breite, y)
    var nach := Vector2(breite if von_links else -breite, y)

    _fund = Fund.new()
    add_child(_fund)
    _fund.starte(art, von, nach)
    _fund.angetippt.connect(_bei_fund)


func _bei_fund(art: int) -> void:
    var text := Spielstand.loese_fund_ein(art)
    var ort: Vector2 = _fund.position if is_instance_valid(_fund) else Vector2.ZERO
    zeige_gutschrift(ort, text, Color(0.95, 0.92, 0.60))
    Spielstand.fund_eingeloest.emit(text)


## Prueft, ob [param punkt] einen Fund trifft.
func fund_bei(punkt: Vector2) -> bool:
    return is_instance_valid(_fund) and _fund.tippe(punkt)


## Index der Baugruppe, deren Detailflaeche unter [param punkt] liegt, sonst -1.
##
## Wird vor [method modul_bei] geprueft, weil die Detailflaeche innerhalb der
## Karte liegt.
func detail_bei(punkt: Vector2) -> int:
    for k in _module:
        if k.detail_flaeche().has_point(punkt):
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


## Wandernde Lichtpunkte auf einer Versorgungsleitung.
##
## Sie erklären wortlos, dass etwas fließt - anders als die Drohnen, die man
## erst nach einer Weile als Transport erkennt.
func _zeichne_pulse(von: Vector2, farbe: Color) -> void:
    for i in PULSE:
        var t := fmod(_zeit / PULS_DAUER + float(i) / float(PULSE), 1.0)
        var ort := von.lerp(Vector2.ZERO, t)
        # Am Anfang und Ende ausblenden, damit die Punkte nicht aufploppen.
        var staerke := sin(t * PI)
        var f := farbe
        f.a = 0.85 * staerke
        draw_circle(ort, 2.6 + 1.4 * staerke, f)
