class_name Palette
extends RefCounted

## **Jede Farbe des Spiels, an einer Stelle.**
##
## Bis September 2026 war hier nichts zu entscheiden: alles war schwarze
## Tusche, Zinnober hiess Gefahr und Gold hiess Sold. Das las sich gut und
## war im Gedraenge unbrauchbar - bei achtzig Figuren schaltet
## `Streiter.DICHT_AB` jede davon auf die Sparfassung, und die wirft genau
## das weg, woran eine Sorte zu erkennen war: ihre Silhouette. Uebrig blieben
## achtzig gleiche schwarze Umrisse, und einer davon war man selbst.
##
## **Also traegt jetzt die Farbe, was die Silhouette nicht mehr traegt.** Das
## ist der Handel, und er geht nur deshalb auf, weil `Tusche` ohnehin je
## Eckpunkt faerbt: Farbe kostet hier **keinen einzigen zusaetzlichen
## Zeichenaufruf**.
##
## Drei Regeln, die geblieben sind:
##
##   * **Die Farbe des Helden traegt nichts sonst.** Man muss sich in einem
##     Bild mit hundertfuenfzig Figuren in einem Wimpernschlag finden.
##   * **Zinnober bleibt dem Schaden am Spieler vorbehalten.** Wenn alles rot
##     blinken darf, heisst Rot nichts mehr.
##   * **Gold bleibt dem Sold vorbehalten**, aus demselben Grund.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## --- Der Grund ---

## Entsaettigt und mittelhell. Farbige Figuren brauchen einen Grund, der
## selbst keine Farbe sein will; ein sattes Gruen macht jede gruene Figur
## unsichtbar und jede rote laut.
const BODEN := Color(0.804, 0.776, 0.694)
## Was auf dem Boden liegt - Graeser, Steine, Faser.
const GRUND_ZIER := Color(0.686, 0.663, 0.584)

## --- Die Kante ---

## Der Umriss, den jede Figur bekommt. Nicht reines Schwarz: ein Umriss in
## Schwarz schneidet die Figur aus dem Bild heraus, statt sie hineinzusetzen.
const UMRISS := Color(0.129, 0.114, 0.149)
## Der Schlagschatten am Boden. In einem Bild ohne Perspektive ist er das
## Einzige, was eine Figur auf den Boden stellt statt sie schweben zu lassen.
const SCHATTEN := Color(0.129, 0.114, 0.149, 0.22)

## --- Die zwei Bedeutungen, die geblieben sind ---

const GEFAHR := Color(0.831, 0.184, 0.161)
const SOLD := Color(0.949, 0.749, 0.180)

## --- Der Held ---

## **Diese Farbe traegt nichts sonst.** Ein warmes, helles Blau - der einzige
## kalte Ton im Bild, und damit derjenige, den das Auge in einem Feld aus
## Braun, Gruen und Rot zuerst findet.
const HELD := Color(0.310, 0.655, 0.925)
## Der helle Saum auf seiner Figur: er hebt ihn noch einmal heraus, ohne
## seine Farbe zu verwaessern.
const HELD_GLANZ := Color(0.694, 0.867, 1.0)

## --- Die Sorten ---
##
## In der Reihenfolge von `Feinde.Art`: STROLCH, WOLF, SPIESSER, ARMBRUSTER,
## TREIBER, RITTER, WARLORD.
##
## Geordnet nach dem, was sie bedeuten, nicht nach Geschmack: das Fussvolk
## ist stumpf und erdig, was schiesst ist giftgruen, was treibt ist violett,
## und die beiden Schweren sind die einzigen, die Rot tragen duerfen - denn
## Rot heisst hier Gefahr, und sie sind es.
const SORTE: PackedColorArray = [
    Color(0.545, 0.427, 0.310),   # Strolch  - Leder, stumpf
    Color(0.427, 0.451, 0.482),   # Wolf     - Fellgrau, kalt
    Color(0.325, 0.518, 0.345),   # Spiesser - Waldgruen
    Color(0.608, 0.690, 0.235),   # Armbruster - Giftgruen, hell
    Color(0.541, 0.361, 0.647),   # Treiber  - Violett
    Color(0.722, 0.271, 0.231),   # Ritter   - Gebranntes Rot
    Color(0.490, 0.110, 0.180),   # Warlord  - Dunkles Blutrot
]

## Womit ein Getroffener kurz aufblitzt. **Hell, nicht blass**: der erste
## Anlauf senkte die Deckung, und ein Treffer, den man nur am Verblassen
## erkennt, sieht aus wie ein Zeichenfehler und nicht wie ein Schlag.
const BLITZ := Color(1.0, 0.937, 0.839)

## --- Die Balken ---

const LEBEN_VOLL := Color(0.353, 0.769, 0.333)
const LEBEN_LEER := Color(0.208, 0.196, 0.204, 0.75)
const ERFAHRUNG := Color(0.361, 0.706, 0.918)


static func sorte(a: int) -> Color:
    return SORTE[clampi(a, 0, SORTE.size() - 1)]


## Wie weit zwei Farben auseinanderliegen - fuer den Waechter, der prueft,
## dass keine zwei Sorten sich eine teilen.
##
## **Nicht als Ungleichheit von drei Fliesskommazahlen.** Zwei Farben, die
## sich in der letzten Stelle unterscheiden, sind verschieden und trotzdem
## dieselbe Farbe. Gewichtet wird nach dem, was das Auge wirklich trennt:
## Helligkeit staerker als Farbton, denn eine Figur ist zwanzig Bildpunkte
## gross und steht neben achtzig anderen.
static func abstand(a: Color, b: Color) -> float:
    var dh := absf(a.r - b.r) * 0.30 + absf(a.g - b.g) * 0.59 \
        + absf(a.b - b.b) * 0.11
    var dr := absf((a.r - a.b) - (b.r - b.b))
    var dg := absf((a.g - a.b) - (b.g - b.b))
    return dh * 1.6 + dr * 0.7 + dg * 0.7
