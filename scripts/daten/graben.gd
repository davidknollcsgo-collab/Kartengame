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
const BRUT_BREITE := 400.0

## --- Wie das Gelege liegt ---
##
## **Hier, weil es zwei Aufrufer gibt.** `kolonie.gd` zeichnet die Eier,
## `wache.gd` braucht denselben Ort fuer die Bruchstuecke eines getroffenen
## Eis. Die Rechnung stand doppelt da, mit einem Kommentar "dieselbe Rechnung
## wie in kolonie.gd" - und genau so ein Kommentar ist der Beweis, dass es
## zwei Beschreibungen derselben Sache sind. Sobald eine davon sich aendert,
## springen die Scherben woanders hin als das Ei lag.
##
## **Ein Gelege, keine Reihe.** Vierundvierzig Eier auf dreihundert Pixeln
## lagen zur Haelfte uebereinander und verschmolzen zu einem goldenen Balken -
## im Bild ein Laib. Und die Zahl waechst mit der Brutkammer weiter, die
## Breite nicht. Also gestaffelte Reihen, und erst wenn vier davon nicht mehr
## reichen, werden die Eier kleiner.
##
## **Die Mitte bleibt frei.** Dort steht der Waechter; Eier hinter seinem Leib
## sind Lebenspunkte, die man nicht sehen kann. Gefuellt wird abwechselnd
## links und rechts von innen nach aussen - was verloren geht, ist damit immer
## das aeusserste, und das Gelege schrumpft sichtbar zur Mitte hin.
const BRUT_JE_REIHE := 16
const BRUT_REIHEN_HOECHSTENS := 4
const BRUT_REIHENHOEHE := 13.5
const BRUT_EI_RADIUS := 7.0
const BRUT_MITTE_FREI := 66.0


static func brut_reihen(voll: int) -> int:
    return clampi(int(ceil(float(maxi(1, voll)) / float(BRUT_JE_REIHE))),
        1, BRUT_REIHEN_HOECHSTENS)


static func brut_je_reihe(voll: int) -> int:
    return maxi(1, int(ceil(float(maxi(1, voll)) / float(brut_reihen(voll)))))


## Abstand zweier Eier innerhalb einer Reihenhaelfte.
static func brut_schritt(voll: int) -> float:
    var je_seite := (brut_je_reihe(voll) + 1) / 2
    return (BRUT_BREITE * 0.5 - BRUT_MITTE_FREI) / float(maxi(1, je_seite))


static func ei_radius(voll: int) -> float:
    return minf(BRUT_EI_RADIUS, brut_schritt(voll) * 0.46)


## In welcher Reihe das Ei liegt. 0 ist die vorderste.
static func ei_reihe(index: int, voll: int) -> int:
    return index / brut_je_reihe(voll)


static func ei_ort(index: int, voll: int) -> Vector2:
    var je := brut_je_reihe(voll)
    var reihe := index / je
    var k := index % je
    # Gerade Plaetze nach links, ungerade nach rechts - beide von innen nach
    # aussen. Damit ist der hoechste Index immer der aeusserste.
    var seite := -1.0 if k % 2 == 0 else 1.0
    var schritt := brut_schritt(voll)
    var x := seite * (BRUT_MITTE_FREI + schritt * (float(k / 2) + 0.5))
    if reihe % 2 == 1:
        # Versetzt nach innen, damit die hintere Reihe in den Luecken der
        # vorderen liegt statt genau dahinter.
        x -= seite * schritt * 0.5
    # Eine schnurgerade Reihe ist eine Anzeige, eine leicht unruhige ein Gelege.
    var hub := sin(float(index) * 2.4) * 2.0
    return Vector2(x, BRUT_Y + hub - BRUT_REIHENHOEHE * float(reihe))

## --- Wie gross ein Rechenschritt hoechstens sein darf ---
##
## **Ohne Deckel kostet ein Anruf die Sitzung.** Die Welle rechnet mit dem
## `delta`, das die Bildwiederholung liefert. Auf einem Telefon ist das
## normalerweise ein Sechzigstel - aber wenn die App in den Hintergrund geht
## und drei Minuten spaeter zurueckkommt, liefert das erste Bild danach die
## volle verstrichene Zeit. Ein einziger Schritt bewegt dann jeden Raeuber um
## hunderte Bildhoehen: die Brut faellt, waehrend das Telefon in der Tasche
## steckt. Das ist der Fehler, der eine Kaufversion in Erstattungen umsetzt,
## und er zeigt sich in keinem Test und in keinem Bild.
##
## Der Deckel ist **abgeleitet, nicht geraten**: in einem Schritt darf sich
## kein Tier weiter bewegen als der Durchmesser des kleinsten Tieres. Sonst
## springt es zwischen zwei Bildern ueber den Kegel hinweg, ohne je darin
## gestanden zu haben - der Spieler zielt richtig und trifft trotzdem nicht.
## Das schnellste Tier ist der Schleier mit 168 Einheiten je Sekunde, das
## kleinste ebenfalls der Schleier mit Radius 12.
##
## Die Folge bei einer schlechten Bildrate ist Zeitlupe statt Sprung. Das ist
## die richtige Wahl: der Kegel haengt am Finger, und ein Spiel, das
## Zwischenbilder ueberspringt, wird unsteuerbar, lange bevor es langsam wird.
const TAKT_DECKEL := 0.14


## Der Rechenschritt fuer dieses Bild.
static func takt(delta: float) -> float:
    return minf(delta, TAKT_DECKEL)


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
const WAECHTER_GROESSE := 1.70

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
