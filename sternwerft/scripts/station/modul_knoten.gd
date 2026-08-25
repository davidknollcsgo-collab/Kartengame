## Eine Versorgungsstation der Formation.
##
## Oben die Silhouette aus [Bauform], darunter ein knappes Schild mit Name,
## Stückzahl und Preis. Früher war das eine Karte mit Rahmen - die las sich wie
## eine Schaltfläche in einer Liste, nicht wie ein Bauwerk im Raum. Die Form
## trägt jetzt die Erkennung, die Schrift nur noch die Zahlen.
class_name ModulKnoten
extends Node2D

## Gesamter Platzbedarf einschließlich Schild.
const GROESSE := Vector2(164.0, 168.0)

## Mitte der Silhouette, relativ zum Knoten.
const FORM_Y := -34.0

## Kantenlänge der Fläche, die das Detailfenster öffnet.
const DETAIL := 44.0

## Höhe des Schilds unter der Station.
const SCHILD_H := 52.0

var index := 0
var anzahl := 0
var bezahlbar := false

## Tatsächlich zu kaufende Stückzahl - bei "MAX" bereits aufgelöst.
var menge := 1

## Preis für [member menge] Stück.
var preis := 0.0

## Ausbaustufe, nur zur Anzeige.
var stufe := 0

var _zeit := 0.0


func _ready() -> void:
    # Ein zufälliger Startwert entkoppelt die Takte der acht Stationen; sonst
    # pulsieren alle im Gleichschritt und das Bild wirkt mechanisch.
    _zeit = randf() * 10.0
    set_process(true)


func _process(delta: float) -> void:
    # Nur Stationen in Betrieb bewegen sich. Stillstehende sollen ruhig wirken.
    if anzahl > 0:
        _zeit += delta
        queue_redraw()


## Rechteck der Station in lokalen Koordinaten des Elternknotens.
func trefferflaeche() -> Rect2:
    return Rect2(position - GROESSE * 0.5, GROESSE)


## Ecke oben rechts, die das Detailfenster öffnet.
##
## Bewusst getrennt vom Rest: Antippen kauft, und das muss schnell gehen. Wäre
## die ganze Station ein Fenster-Öffner, bräuchte jeder Kauf zwei Griffe.
func detail_flaeche() -> Rect2:
    var r := trefferflaeche()
    return Rect2(r.end.x - DETAIL, r.position.y, DETAIL, DETAIL)


## Bewusst ohne Zugriff auf den Autoload: die Werte kommen von außen herein,
## damit diese Datei im headless Testlauf ladbar bleibt.
func aktualisiere(neue_anzahl: int, neue_menge: int, neuer_preis: float,
        ist_bezahlbar: bool, neue_stufe: int = 0) -> void:
    if neue_anzahl == anzahl and neue_menge == menge and neue_stufe == stufe \
            and is_equal_approx(neuer_preis, preis) and ist_bezahlbar == bezahlbar:
        return
    stufe = neue_stufe
    anzahl = neue_anzahl
    menge = neue_menge
    preis = neuer_preis
    bezahlbar = ist_bezahlbar
    queue_redraw()


func _draw() -> void:
    var leit := Modul.farbe(index)
    var aktiv := anzahl > 0

    if aktiv:
        _schein(leit)

    # Die Silhouette trägt die Erkennung.
    draw_set_transform(Vector2(0.0, FORM_Y), 0.0, Vector2.ONE)
    Bauform.zeichne(self, index, leit, stufe, aktiv, _zeit)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    _schild(leit, aktiv)
    _griff()


## Weicher Schein um Stationen in Betrieb.
##
## Godots Nachleuchten braucht die Forward+-Anzeige; Handys und der Web-Export
## laufen im Kompatibilitätsmodus, wo es das nicht gibt. Von Hand gezeichnet
## sieht es fast gleich aus und läuft überall.
func _schein(leit: Color) -> void:
    var mitte := Vector2(0.0, FORM_Y)
    # Sehr zurueckhaltend: der erste Versuch legte farbige Scheiben hinter jede
    # Station, die kraeftiger wirkten als die Stationen selbst.
    for i in range(2, 0, -1):
        var f := leit
        f.a = 0.020 + 0.014 * float(3 - i)
        draw_circle(mitte, Bauform.MASS * (0.80 + 0.16 * float(i)), f)


## Schild mit Name, Stückzahl und Preis.
func _schild(leit: Color, aktiv: bool) -> void:
    var r := Rect2(-GROESSE.x * 0.5 + 6.0, GROESSE.y * 0.5 - SCHILD_H - 4.0,
        GROESSE.x - 12.0, SCHILD_H)

    draw_colored_polygon(Formen.kante(r, 8.0), Color(0.07, 0.08, 0.11, 0.82))
    var rahmen := leit if bezahlbar else Color(0.24, 0.27, 0.33)
    draw_polyline(Formen.kante_umriss(r, 8.0), rahmen,
        2.0 if bezahlbar else 1.2, true)

    var titel := Schrift.titel()
    var text := Schrift.text()
    var hell := Color(0.90, 0.93, 0.97) if aktiv else Color(0.48, 0.52, 0.58)

    draw_string(text, Vector2(r.position.x + 10.0, r.position.y + 20.0),
        Modul.name_von(index), HORIZONTAL_ALIGNMENT_LEFT,
        r.size.x - 46.0, _namensgroesse(text, r.size.x - 46.0), hell)

    draw_string(titel, Vector2(r.position.x, r.position.y + 20.0),
        "x%d" % anzahl, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10.0, 15,
        leit if aktiv else Color(0.42, 0.45, 0.51))

    var preisfarbe := Color(0.55, 0.95, 0.65) if bezahlbar else Color(0.46, 0.49, 0.55)
    var px := r.position.x + 10.0
    var py := r.position.y + 41.0
    if menge > 1:
        var vorsatz := "x%d " % menge
        draw_string(text, Vector2(px, py), vorsatz,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 14, preisfarbe)
        px += text.get_string_size(vorsatz, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
    Waehrung.zeichne(self, text, Vector2(px, py), Zahl.kurz(preis),
        Waehrung.Art.PLASMA, 14, preisfarbe)

    if stufe > 0:
        _stufenabzeichen(Vector2(r.end.x - 16.0, r.position.y + 38.0), leit)
    _meilenstein(r, leit)


## Größte Schriftgröße, bei der der Name noch ganz hineinpasst.
##
## Abschneiden wäre einfacher, macht aber aus "Forschungslabor" ein
## "Forschungslab" - und das hält der Spieler für einen Darstellungsfehler.
func _namensgroesse(schrift: Font, platz: float) -> int:
    var name := Modul.name_von(index)
    for groesse in [16, 15, 14, 13]:
        if schrift.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x <= platz:
            return groesse
    return 13


## Ausbaustufe als kleines Abzeichen. Nur sichtbar, wenn ausgebaut wurde -
## eine Null an jeder Station wäre nur Rauschen.
func _stufenabzeichen(mitte: Vector2, leit: Color) -> void:
    draw_circle(mitte, 11.0, Color(leit.r, leit.g, leit.b, 0.22))
    draw_arc(mitte, 11.0, 0.0, TAU, 18, leit, 1.4, true)
    draw_string(Schrift.titel(), Vector2(mitte.x - 11.0, mitte.y + 5.0),
        "+%d" % stufe, HORIZONTAL_ALIGNMENT_CENTER, 22.0, 12, leit.lightened(0.3))


## Fortschrittsleiste bis zum nächsten Stückzahl-Meilenstein.
func _meilenstein(r: Rect2, leit: Color) -> void:
    var naechster := 0
    for schwelle in Modul.MEILENSTEINE:
        if anzahl < schwelle:
            naechster = schwelle
            break
    if naechster == 0:
        return

    var vorheriger := 0
    for schwelle in Modul.MEILENSTEINE:
        if schwelle <= anzahl:
            vorheriger = schwelle
    var anteil := float(anzahl - vorheriger) / float(naechster - vorheriger)

    var bahn := Rect2(r.position.x + 10.0, r.end.y - 8.0, r.size.x - 20.0, 3.0)
    draw_rect(bahn, Color(0.20, 0.22, 0.27))
    if anteil > 0.0:
        draw_rect(Rect2(bahn.position, Vector2(bahn.size.x * anteil, bahn.size.y)),
            leit.lightened(0.15))


## Drei Punkte oben rechts als Hinweis auf das Detailfenster.
func _griff() -> void:
    var m := Vector2(GROESSE.x * 0.5 - DETAIL * 0.5, -GROESSE.y * 0.5 + DETAIL * 0.5)
    var f := Color(0.50, 0.55, 0.63)
    for i in 3:
        draw_circle(m + Vector2(float(i - 1) * 7.0, 0.0), 2.0, f)
