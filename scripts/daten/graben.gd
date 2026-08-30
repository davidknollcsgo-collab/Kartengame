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

## Wie gross der Waechter und sein Kalkwulst gezeichnet werden.
##
## Steht hier und nicht in einer der beiden Zeichendateien, weil **beide** sie
## brauchen: das Tier zeichnet `waechter.gd`, den Sockel darunter
## `kolonie.gd`, und die zwei muessen zusammenpassen. Zwei Zahlen, die
## dasselbe bedeuten, laufen auseinander.
const WAECHTER_GROESSE := 1.45

## --- Sitzung ---

const WELLEN_JE_SITZUNG := 5
const WELLEN_JE_ABSCHNITT := 10

## Wie oft am Tag jemand hereinschaut. Morgens, mittags, abends - das ist die
## Annahme, auf der die ganze Wirtschaft steht, und deshalb steht sie hier und
## nicht im Messwerkzeug. Aus ihr faellt zweierlei ab: wie viel Naehrstoff ein
## Tag bringt (`Wellen.ertrag`) und wie lang ein Bau hoechstens dauern darf
## (`Kammern.ZEIT_DECKEL`) - laenger als der Abstand zwischen zwei Besuchen,
## und der Spieler findet nichts vor.
const SITZUNGEN_JE_TAG := 3

## Wellen, die ein Tag hergibt. Der Nenner der Ertragsrechnung.
const WELLEN_JE_TAG := SITZUNGEN_JE_TAG * WELLEN_JE_SITZUNG

## --- Der Graben hat keinen Boden ---
##
## Frueher stand hier `WELLEN_GESAMT := 60`, und bei Welle 60 war Schluss.
## Ein Spiel, das man durchspielt, ist danach fertig; dieses soll weiterlaufen.
##
## Deshalb gibt es jetzt einen **Zyklus**: sechs Abschnitte mit ihren sechs
## Regeln, danach faengt die Folge von vorn an - eine Umdrehung tiefer, und
## jede Umdrehung zieht die Regeln straffer an. Die Wellenstaerke waechst
## dabei durchgehend weiter, weil sie aus der Sollkurve faellt und die kein
## Ende hat.
##
## Was ein Spieler tatsaechlich erreicht, ist damit keine Zahl im Quelltext
## mehr, sondern das, was seine Kolonie hergibt.
const ABSCHNITTE := 6
const ZYKLUS := ABSCHNITTE * WELLEN_JE_ABSCHNITT

## Eine Schranke fuer Schleifen, Speicherwerte und Anzeigen - kein Spielende.
## Wer hier ankommt, hat zehntausend Wellen gespielt; die Zahl ist da, damit
## nichts unbegrenzt laeuft, nicht als Ziel.
const TIEFSTE := 9999


## Was ein Wehrpolyp als naechstes kostet, wenn schon `gebaut` stehen.
static func polyp_kosten(gebaut: int) -> int:
    return int(round(POLYP_KOSTEN * pow(POLYP_KOSTEN_WACHSTUM, gebaut)))


## Welche der sechs Abschnittsregeln in dieser Welle gilt, ab 0 gezaehlt.
## Sie wiederholt sich alle `ZYKLUS` Wellen.
static func abschnitt(nummer: int) -> int:
    return posmod((maxi(1, nummer) - 1) / WELLEN_JE_ABSCHNITT, ABSCHNITTE)


## Die wievielte Umdrehung durch den Graben das ist, ab 0 gezaehlt. Welle 1
## bis 60 ist Umdrehung 0, 61 bis 120 ist Umdrehung 1.
static func zyklus(nummer: int) -> int:
    return (maxi(1, nummer) - 1) / ZYKLUS


## Der laufende Abschnitt, ueber alle Umdrehungen durchgezaehlt.
static func abschnitt_gesamt(nummer: int) -> int:
    return (maxi(1, nummer) - 1) / WELLEN_JE_ABSCHNITT


## Die letzte Welle des durchgezaehlten Abschnitts `nr`.
## Die Umdrehung als roemische Ziffer - leer fuer die erste.
##
## Ohne das heisst der Abschnitt in Welle 7 genauso wie in Welle 367, und der
## Spieler sieht nicht, wie weit er ist. Roemisch, weil daneben schon eine
## arabische Zahl steht: "WAVE 367" und "Rim Gorge VII" sind auseinander-
## zuhalten, "367" und "7" nicht.
const ZIFFERN: PackedStringArray = [
    "", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X",
]


static func tiefe_zeichen(nummer: int) -> String:
    var z := zyklus(nummer)
    if z <= 0:
        return ""
    if z < ZIFFERN.size():
        return ZIFFERN[z]
    return " x%d" % (z + 1)


static func letzte_welle(nr: int) -> int:
    return (maxi(0, nr) + 1) * WELLEN_JE_ABSCHNITT
