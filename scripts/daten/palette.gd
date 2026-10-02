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

## **Warmer Sand, nicht graues Papier.** Bis Oktober 2026 stand hier ein
## entsaettigtes Beige mit der Begruendung, ein satter Grund mache jede Figur
## derselben Farbe unsichtbar. Das stimmte, solange die Kante ein Bruchteil
## des Strichs war; seit jede Figur im Pixelbild einen ganzen Bildpunkt
## Umriss traegt (`umriss.gdshader`), trennt der Umriss und nicht der
## Abstand der Farben. Die Vorlage des Nutzers zeigte eine Landkarte: Sand,
## Wiesen, Baeume, Wasser.
const BODEN := Color(0.847, 0.757, 0.553)
## Was auf dem Boden liegt - Kiesel, Faser.
const GRUND_ZIER := Color(0.722, 0.631, 0.447)
## Wege und Erde: dunkler und roetlicher als der Sand.
const ERDE := Color(0.737, 0.616, 0.427)
## Wiese: gedaempftes Salbeigruen, heller als jede gruene Sorte und weit weg
## vom Giftgruen der Armbruster.
const WIESE := Color(0.553, 0.620, 0.392)
const WIESE_TIEF := Color(0.459, 0.533, 0.318)
## Aelter, aber noch gebraucht: der Grasgrund eines Flecks.
const GRASGRUND := Color(0.620, 0.667, 0.443)
const HALM := Color(0.380, 0.467, 0.255)
## Seltene kleine Blueten. Nicht Gold (Sold), nicht Zinnober (Gefahr).
const BLUETE := Color(0.957, 0.937, 0.871)
## Baumkronen und Buesche: dunkler als die Wiese, damit ein Baum auf ihr steht.
const LAUB := Color(0.341, 0.494, 0.271)
const LAUB_TIEF := Color(0.220, 0.353, 0.192)
const STEIN := Color(0.671, 0.651, 0.608)
const HOLZ := Color(0.502, 0.365, 0.231)
## **Wasser ist kein Blau.** Blau traegt der Held und sonst niemand; ein
## Teich in seiner Farbe waere eine zweite Antwort auf *wo bin ich*.
const WASSER := Color(0.373, 0.580, 0.592)
const WASSER_HELL := Color(0.635, 0.788, 0.769)

## --- Die Pixel-Figuren ---
##
## Feste Rollen der Sprites (`Pixel`, `Figuren`): was nicht die Farbe der
## Sorte traegt. Gesicht, Stahl, Holz, Leder, Stiefel - die Farbzonen, an
## denen man im Pixelbild einen Soldaten von einer Silhouette unterscheidet.
const HAUT := Color(0.890, 0.729, 0.592)
const HAUT_TIEF := Color(0.710, 0.529, 0.420)
const STAHL_HELL := Color(0.902, 0.914, 0.925)
const STAHL := Color(0.659, 0.682, 0.722)
const STAHL_TIEF := Color(0.408, 0.431, 0.486)
const HOLZ_HELL := Color(0.667, 0.490, 0.290)
const LEDER := Color(0.502, 0.341, 0.212)
const LEDER_TIEF := Color(0.333, 0.220, 0.141)
const STIEFEL := Color(0.290, 0.212, 0.161)
const STIEFEL_TIEF := Color(0.188, 0.137, 0.110)
const WEISS := Color(0.976, 0.965, 0.918)

## --- Die Kante ---

## Der Umriss, den jede Figur bekommt. Nicht reines Schwarz: ein Umriss in
## Schwarz schneidet die Figur aus dem Bild heraus, statt sie hineinzusetzen.
const UMRISS := Color(0.129, 0.114, 0.149)
## Der Schlagschatten am Boden. In einem Bild ohne Perspektive ist er das
## Einzige, was eine Figur auf den Boden stellt statt sie schweben zu lassen.
const SCHATTEN := Color(0.129, 0.114, 0.149, 0.22)

## --- Das Licht ---
##
## **Jede Figur hat eine Licht- und eine Schattenseite.** Vorher hatte jede
## genau eine flache Farbe, und hundert flache Farben lasen sich als
## Skizze. Das Licht kommt von links oben; die abgewandte Seite eines
## Strichs wird um `SCHATTEN_TIEFE` dunkler, die zugewandte um `LICHT_HOEHE`
## heller. Es kostet **keinen Eckpunkt**: `Tusche` faerbt ohnehin je Reihe,
## und die Reihen gibt es schon.
const LICHT := Vector2(-0.6, -0.8)
## Erster Anlauf 0,30 / 0,18: beim Warlord sichtbar, bei einer Figur von
## sechzig Punkten kaum - der Koerper hat nur drei Farbreihen, und die
## mittlere bleibt, wie sie ist.
const SCHATTEN_TIEFE := 0.42
const LICHT_HOEHE := 0.26

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
    Color(0.612, 0.431, 0.278),   # Strolch  - Leder, stumpf
    Color(0.525, 0.553, 0.604),   # Wolf     - Fellgrau, kalt
    Color(0.259, 0.537, 0.310),   # Spiesser - Waldgruen
    Color(0.682, 0.761, 0.188),   # Armbruster - Giftgruen, hell
    Color(0.584, 0.329, 0.737),   # Treiber  - Violett
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
