## Namen und Zeichen der drei Spielwährungen.
##
## Alle drei sind frei erfunden - **kein Zeichen darf an eine echte Währung
## erinnern**. Der ursprüngliche Entwurf verwendete das Cent-Zeichen für die
## Grundwährung; bei einer App mit In-App-Käufen ist das nicht nur unschön,
## sondern verstößt gegen Googles Vorgabe, dass Spielwährung nicht mit echtem
## Geld verwechselbar sein darf.
##
## Die Zeichen werden **gezeichnet, nicht gesetzt**. Der erste Entwurf nutzte
## die Unicode-Zeichen ◆, ✦ und ⬡. Auf dem Entwicklungsrechner sah das richtig
## aus, im Web-Export standen überall Ersatzkästchen: weder Orbitron noch
## Rajdhani enthalten diese Zeichen, und Godots eingebaute Rückfallschrift
## enthält sie im Web-Export ebenfalls nicht (nachgemessen mit
## [method Font.has_char]). Selbst gezeichnete Formen haben dieses Problem
## grundsätzlich nicht und sehen überall gleich aus.
class_name Waehrung
extends RefCounted

enum Art { PLASMA, QUANTEN, PROTOKOLL }

## Ausrichtung eines Betrags relativ zum übergebenen Ankerpunkt.
enum Lage { LINKS, MITTE, RECHTS }

const PLASMA := "Plasma"
const QUANTEN := "Quanten"
const PROTOKOLLE := "Protokolle"

## Abstand zwischen Zahl und Zeichen, als Anteil der Schriftgröße.
const LUECKE := 0.30

## Halbe Höhe des Zeichens, als Anteil der Schriftgröße.
const ZEICHEN := 0.30


## Zeichnet einen Betrag samt Währungszeichen.
##
## [param anker] ist je nach [param lage] die linke Kante, die Mitte oder die
## rechte Kante. Gibt die Gesamtbreite zurück.
static func zeichne(ci: CanvasItem, schrift: Font, anker: Vector2, zahl: String,
        art: Art, groesse: int, farbe: Color, lage: Lage = Lage.LINKS) -> float:
    var breite_zahl := schrift.get_string_size(zahl, HORIZONTAL_ALIGNMENT_LEFT,
        -1, groesse).x
    var r := float(groesse) * ZEICHEN
    var luecke := float(groesse) * LUECKE
    var gesamt := breite_zahl + luecke + r * 2.0

    var x := anker.x
    match lage:
        Lage.MITTE:
            x -= gesamt * 0.5
        Lage.RECHTS:
            x -= gesamt

    ci.draw_string(schrift, Vector2(x, anker.y), zahl,
        HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)
    zeichne_zeichen(ci, art,
        Vector2(x + breite_zahl + luecke + r, anker.y - float(groesse) * 0.32),
        r, farbe)
    return gesamt


## Nur das Zeichen, ohne Zahl.
static func zeichne_zeichen(ci: CanvasItem, art: Art, mitte: Vector2, r: float,
        farbe: Color) -> void:
    match art:
        Art.PLASMA:
            _raute(ci, mitte, r, farbe)
        Art.QUANTEN:
            _stern(ci, mitte, r, farbe)
        Art.PROTOKOLL:
            _sechseck(ci, mitte, r, farbe)


## Raute - kompakt und auch bei zwölf Punkten noch eindeutig.
static func _raute(ci: CanvasItem, m: Vector2, r: float, farbe: Color) -> void:
    ci.draw_colored_polygon(PackedVector2Array([
        m + Vector2(0.0, -r), m + Vector2(r * 0.74, 0.0),
        m + Vector2(0.0, r), m + Vector2(-r * 0.74, 0.0),
    ]), farbe)


## Vierstrahliger Stern mit eingezogenen Flanken.
static func _stern(ci: CanvasItem, m: Vector2, r: float, farbe: Color) -> void:
    var i := r * 0.30
    ci.draw_colored_polygon(PackedVector2Array([
        m + Vector2(0.0, -r), m + Vector2(i, -i), m + Vector2(r, 0.0),
        m + Vector2(i, i), m + Vector2(0.0, r), m + Vector2(-i, i),
        m + Vector2(-r, 0.0), m + Vector2(-i, -i),
    ]), farbe)


## Sechseck als Umriss - hebt sich von den beiden gefüllten Formen ab.
static func _sechseck(ci: CanvasItem, m: Vector2, r: float, farbe: Color) -> void:
    var ecken := PackedVector2Array()
    for i in 6:
        var a := TAU * float(i) / 6.0 - PI * 0.5
        ecken.append(m + Vector2(cos(a), sin(a)) * r)
    ecken.append(ecken[0])
    ci.draw_polyline(ecken, farbe, maxf(r * 0.28, 1.5), true)


# --- Reine Zahlentexte, ohne Zeichen ----------------------------------------

static func plasma_zahl(wert: float) -> String:
    return Zahl.kurz(wert)


static func rate_zahl(wert: float) -> String:
    return "+" + Zahl.kurz(wert)
