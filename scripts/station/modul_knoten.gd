## Eine Baugruppe der Station, prozedural gezeichnet.
##
## Zeigt Name, Stueckzahl und Preis und leuchtet auf, sobald mindestens ein
## Exemplar steht. Die Statusleiste am unteren Rand fuellt sich bis zum
## naechsten Meilenstein - das macht den Sprung sichtbar, bevor er eintritt.
class_name ModulKnoten
extends Node2D

const GROESSE := Vector2(196, 132)
const SCHRAEGE := 14.0

## Kantenlaenge der Flaeche, die das Detailfenster oeffnet.
const DETAIL := 44.0

var index := 0
var anzahl := 0

## Ausbaustufe, nur zur Anzeige.
var stufe := 0
var bezahlbar := false

## Tatsaechlich zu kaufende Stueckzahl - bei "MAX" bereits aufgeloest.
var menge := 1

## Preis fuer [member menge] Stueck.
var preis := 0.0

var _puls := 0.0


func _ready() -> void:
    set_process(true)


func _process(delta: float) -> void:
    # Nur aktive Baugruppen pulsieren - stillstehende sollen ruhig wirken.
    if anzahl > 0:
        _puls = fmod(_puls + delta, TAU)
        queue_redraw()


## Rechteck der Baugruppe in lokalen Koordinaten des Elternknotens.
func trefferflaeche() -> Rect2:
    return Rect2(position - GROESSE * 0.5, GROESSE)


## Ecke oben rechts, die das Detailfenster oeffnet.
##
## Bewusst getrennt vom Rest der Karte: Antippen kauft, und das muss schnell
## gehen. Waere die ganze Karte ein Fenster-Oeffner, braeuchte jeder Kauf zwei
## Griffe - bei einem Idle-Spiel der sichere Weg zu wunden Daumen.
func detail_flaeche() -> Rect2:
    var r := trefferflaeche()
    return Rect2(r.end.x - DETAIL, r.position.y, DETAIL, DETAIL)


## Bewusst ohne Zugriff auf den Autoload: die Werte kommen von aussen herein,
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
    var r := Rect2(-GROESSE * 0.5, GROESSE)
    var leit := Modul.farbe(index)
    var aktiv := anzahl > 0

    # Schein nach aussen: mehrere Umrisse mit wachsendem Abstand und
    # fallender Deckkraft. Godots Nachleuchten braucht die Forward+-Anzeige;
    # im Kompatibilitaetsmodus, den Handys und der Web-Export verwenden, gibt
    # es das nicht - von Hand gezeichnet sieht es fast gleich aus und laeuft
    # ueberall.
    if aktiv:
        for i in range(3, 0, -1):
            var weite := float(i) * 3.0
            var schein := leit
            schein.a = 0.05 + 0.03 * float(4 - i)
            draw_polyline(Formen.kante_umriss(r.grow(weite), SCHRAEGE + weite),
                schein, 2.0 + weite * 0.5, true)

    # Rumpf: dunkel, damit die Leitfarbe traegt.
    var rumpf := Color(0.11, 0.13, 0.17) if aktiv else Color(0.08, 0.09, 0.11)
    draw_colored_polygon(Formen.kante(r, SCHRAEGE), rumpf)

    # Kontur - bei bezahlbaren Baugruppen deutlich heller als Kaufhinweis.
    var kontur := leit if aktiv else Color(0.22, 0.25, 0.30)
    var breite := 2.0
    if bezahlbar:
        kontur = leit.lightened(0.35)
        breite = 3.0
    draw_polyline(Formen.kante_umriss(r, SCHRAEGE), kontur, breite, true)

    # Leitstreifen links, Helligkeit atmet mit dem Puls.
    var glut := leit
    if aktiv:
        glut = leit.lightened(0.12 + 0.10 * sin(_puls * 2.0))
    else:
        glut = leit.darkened(0.65)
    draw_rect(Rect2(r.position.x + 8.0, r.position.y + 16.0, 6.0, r.size.y - 32.0), glut)

    var schrift := Schrift.text()
    var hell := Color(0.92, 0.94, 0.97) if aktiv else Color(0.45, 0.48, 0.53)

    draw_string(schrift, Vector2(r.position.x + 24.0, r.position.y + 34.0),
        # Breite begrenzen, sonst laeuft "Forschungslabor" in den Griff oben rechts.
        Modul.name_von(index), HORIZONTAL_ALIGNMENT_LEFT,
        GROESSE.x - 24.0 - DETAIL, 21, hell)

    draw_string(schrift, Vector2(r.position.x + 24.0, r.position.y + 60.0),
        "x%d" % anzahl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
        leit if aktiv else Color(0.40, 0.43, 0.48))

    var preisfarbe := Color(0.55, 0.95, 0.65) if bezahlbar else Color(0.48, 0.51, 0.56)
    var px := r.position.x + 24.0
    var py := r.position.y + 84.0
    if menge > 1:
        # Die Menge steht vor dem Betrag, damit klar ist, wofuer der Preis gilt.
        var vorsatz := "x%d  " % menge
        draw_string(schrift, Vector2(px, py), vorsatz,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 16, preisfarbe)
        px += schrift.get_string_size(vorsatz, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    Waehrung.zeichne(self, schrift, Vector2(px, py), Zahl.kurz(preis),
        Waehrung.Art.PLASMA, 16, preisfarbe)

    _zeichne_stufe(r, leit)
    _zeichne_griff(r)
    _zeichne_meilenstein(r, leit)


## Ausbaustufe als Abzeichen. Nur sichtbar, wenn ueberhaupt ausgebaut wurde -
## eine Null bei jeder Baugruppe waere nur Rauschen.
func _zeichne_stufe(r: Rect2, leit: Color) -> void:
    if stufe <= 0:
        return
    var mitte := Vector2(r.end.x - 34.0, r.end.y - 34.0)
    draw_circle(mitte, 15.0, Color(leit.r, leit.g, leit.b, 0.20))
    draw_arc(mitte, 15.0, 0.0, TAU, 20, leit, 1.6, true)
    draw_string(Schrift.titel(), Vector2(mitte.x - 15.0, mitte.y + 6.0),
        "+%d" % stufe, HORIZONTAL_ALIGNMENT_CENTER, 30.0, 14, leit.lightened(0.3))


## Drei Punkte oben rechts als Hinweis auf das Detailfenster.
func _zeichne_griff(r: Rect2) -> void:
    var m := Vector2(r.end.x - DETAIL * 0.5, r.position.y + DETAIL * 0.5)
    var f := Color(0.55, 0.60, 0.68)
    for i in 3:
        draw_circle(m + Vector2(float(i - 1) * 7.0, 0.0), 2.0, f)


## Fortschrittsleiste bis zum naechsten Stueckzahl-Meilenstein.
func _zeichne_meilenstein(r: Rect2, leit: Color) -> void:
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

    var bahn := Rect2(r.position.x + 22.0, r.end.y - 18.0, r.size.x - 44.0, 4.0)
    draw_rect(bahn, Color(0.20, 0.22, 0.27))
    if anteil > 0.0:
        draw_rect(Rect2(bahn.position, Vector2(bahn.size.x * anteil, bahn.size.y)),
            leit.lightened(0.15))
