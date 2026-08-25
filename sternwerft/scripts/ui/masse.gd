## Maße, die sich an die Bildschirmgröße anpassen.
##
## Handys reichen von 360 bis über 500 Punkte Breite und von 16:9 bis 21:9.
## Fest verdrahtete Breiten gehen auf dem Entwicklungsgerät auf und laufen auf
## dem nächsten über den Rand. Alle Flächen leiten sich deshalb hier ab.
class_name Masse
extends RefCounted

## Größte sinnvolle Breite eines Fensters - darüber wirkt es auf Tablets verloren.
const FENSTER_MAX := 640.0

## Kleinste Breite, unter der Text umbricht statt zu passen.
const FENSTER_MIN := 300.0

## Abstand zum Bildschirmrand.
const RAND := 24.0

## Kleinste Kantenlänge einer Trefferfläche.
##
## Unterhalb von etwa 48 Punkten trifft ein Daumen nicht mehr zuverlässig -
## das ist der Wert, den sowohl Google als auch Apple in ihren Richtlinien
## nennen.
const TIPPFLAECHE := 48.0


## Breite eines mittigen Fensters auf einem Bildschirm der Breite [param breite].
static func fenster_breite(breite: float) -> float:
    return clampf(breite - RAND * 2.0, FENSTER_MIN, FENSTER_MAX)


## Mittig gesetztes Fenster mit der gewünschten Höhe.
static func fenster(sicht: Vector2, hoehe: float) -> Rect2:
    var b := fenster_breite(sicht.x)
    var h := minf(hoehe, sicht.y - RAND * 2.0)
    return Rect2((sicht.x - b) * 0.5, (sicht.y - h) * 0.5, b, h)
