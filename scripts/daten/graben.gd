class_name Graben
extends RefCounted

## Die Masse des Schlunds und die Grundwerte des Waechters.
##
## Alles in Spielkoordinaten mit dem Ursprung in der Bildmitte. Reine Daten -
## keine Szenen-, keine Autoload-Bezuege, damit Testlauf und Wellenpruefer
## dieselben Zahlen sehen wie das Spiel.

## Sichtbarer Ausschnitt. Hochformat, weil das Spiel einhaendig laufen soll.
const FELD := Rect2(-360.0, -640.0, 720.0, 1280.0)

## Die Spitze des Lichtkegels. Sitzt tief, damit der Kegel nach oben in die
## Dunkelheit greift und der Spieler den Daumen unten am Rand halten kann.
const WAECHTER := Vector2(0.0, 392.0)

## Hoehe, auf der die Brut liegt. Wer sie erreicht, richtet Schaden an.
const BRUT_Y := 486.0
const BRUT_BREITE := 300.0

## Raeuber treten weit oberhalb des Bildes ein und sinken in den Kegel hinein.
## Der Abstand ist Absicht: die ersten Sekunden jeder Bahn sieht man nur eine
## Bewegung im Dunkeln, nicht das Tier.
const EINTRITT_Y := -760.0
const EINTRITT_SEITE := 286.0

## --- Grundwerte des Kegels (Stufe 0 des Leuchtorgans) ---

const HALBWINKEL := 0.297          ## Bogenmass, rund 17 Grad
const REICHWEITE := 780.0
const LEISTUNG := 34.0             ## Schaden je Sekunde bei voller Helligkeit
const DREHTEMPO := 7.4             ## Bogenmass je Sekunde

## Wie viele Raeuber der Kegel gleichzeitig verbrennt. Ohne diese Grenze wuchs
## seine Gesamtleistung mit der Zahl der Gegner - siehe `Schlund.brennende()`.
const ZIELE := 3

## --- Brut ---

const BRUT_LEBEN := 12

## --- Wehrpolypen ---

const POLYP_LEISTUNG := 9.0
const POLYP_REICHWEITE := 148.0
const POLYP_KOSTEN := 12
const POLYP_KOSTEN_WACHSTUM := 1.55
const POLYP_RADIUS := 15.0

## Feste Nischen in den Grabenwaenden. Feste Plaetze statt freier Platzierung,
## weil der Spieler zwischen zwei Wellen wenige Sekunden hat - eine Wahl aus
## acht Punkten trifft man in dieser Zeit, eine freie Platzierung nicht.
const NISCHEN: PackedVector2Array = [
    Vector2(-292.0, -196.0), Vector2(292.0, -104.0),
    Vector2(-286.0, -22.0), Vector2(286.0, 64.0),
    Vector2(-296.0, 148.0), Vector2(296.0, 226.0),
    Vector2(-244.0, 306.0), Vector2(244.0, 336.0),
]

## --- Sitzung ---

const WELLEN_JE_SITZUNG := 5
const WELLEN_GESAMT := 60
const WELLEN_JE_ABSCHNITT := 10
const ABSCHNITTE := WELLEN_GESAMT / WELLEN_JE_ABSCHNITT


## Was ein Wehrpolyp als naechstes kostet, wenn schon `gebaut` stehen.
static func polyp_kosten(gebaut: int) -> int:
    return int(round(POLYP_KOSTEN * pow(POLYP_KOSTEN_WACHSTUM, gebaut)))


## Grabenabschnitt einer Welle, ab 0 gezaehlt.
static func abschnitt(nummer: int) -> int:
    return clampi((nummer - 1) / WELLEN_JE_ABSCHNITT, 0, ABSCHNITTE - 1)


## Die letzte Welle eines Abschnitts.
static func letzte_welle(abschnitt_nr: int) -> int:
    return clampi(abschnitt_nr + 1, 1, ABSCHNITTE) * WELLEN_JE_ABSCHNITT
