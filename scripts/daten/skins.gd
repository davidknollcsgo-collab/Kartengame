class_name Skins
extends RefCounted

## Wie das Boot aussieht - und sonst nichts.
##
## **Ein Skin ist eine Farbe, keine Eigenschaft.** Er aendert Rumpffarbe,
## Antriebsglut und die Toenung des Strahls; er aendert **nicht** Reichweite,
## Oeffnungswinkel, Deckung oder Leistung. Zusage 2 sagt, dass hell
## Gezeichnetes Schaden macht - waere ein Skin heller, waere er ein Ausbau,
## und dann waere die Wahl keine Frage des Geschmacks mehr, sondern eine
## Frage der Stufe. Genau das soll er nicht sein.
##
## **Verdient wird er durch Tiefe, nicht durch Naehrstoff.** Einkommen und
## Kosten sind aneinander gekoppelt (Zusage 10); ein Kaufgegenstand daneben
## verschoebe die Wirtschaft. Und eine Kiste kommt nicht in Frage - der Plan
## sagt: gezuechtet statt gezogen. Also die einfachste ehrliche Regel: eine
## Wellenzahl, die man erreicht haben muss. Wer tiefer faehrt, sieht anders
## aus, und man sieht es ihm an.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Je Skin: Kennung (deutsch, fest - der Waechter vergleicht sie mit dem
## Enum), Name und Beschreibung englisch, weil sichtbar.
##
##   * `haut`   - die Linien des Rumpfes
##   * `glut`   - der Antrieb hinten
##   * `strahl` - der Saum des Lichtkegels
##   * `kern`   - seine Mitte
##   * `ab_welle` - ab welcher tiefsten Welle er offen steht
## **`Anstrich` und nicht `Skin`:** `Skin` ist in Godot eine eingebaute
## Klasse (die Knochenbindung eines Meshes), und ein Enum dieses Namens
## verschattet sie. Der Fehler heisst dann "shadows a native class" und
## nimmt die ganze Datei mit - samt allem, was sie braucht.
enum Anstrich { TIEFENBLAU, BERNSTEIN, VIOLETT, SCHWEFEL, KNOCHEN, RIFT }

const TABELLE: Array[Dictionary] = [
    {
        &"kennung": &"TIEFENBLAU",
        &"name": "Deepwater",
        &"regel": "The colony's own light. What every hull starts as.",
        &"haut": Color(0.62, 0.88, 0.94),
        &"glut": Color(1.00, 0.86, 0.58),
        &"strahl": Color(0.24, 0.86, 1.00),
        &"kern": Color(0.82, 1.00, 0.96),
        &"ab_welle": 0,
    },
    {
        &"kennung": &"BERNSTEIN",
        &"name": "Vent Amber",
        &"regel": "Warmed at a hydrothermal vent. Runs hot and shows it.",
        &"haut": Color(0.96, 0.78, 0.46),
        &"glut": Color(1.00, 0.62, 0.30),
        &"strahl": Color(1.00, 0.72, 0.30),
        &"kern": Color(1.00, 0.95, 0.80),
        &"ab_welle": 20,
    },
    {
        &"kennung": &"VIOLETT",
        &"name": "Abyss Violet",
        &"regel": "The colour nothing down here can see. It still burns.",
        &"haut": Color(0.80, 0.66, 1.00),
        &"glut": Color(0.86, 0.52, 1.00),
        &"strahl": Color(0.62, 0.44, 1.00),
        &"kern": Color(0.94, 0.88, 1.00),
        &"ab_welle": 45,
    },
    {
        &"kennung": &"SCHWEFEL",
        &"name": "Sulphur Bloom",
        &"regel": "Grown over in chemosynthetic film. It is alive, and it glows.",
        &"haut": Color(0.72, 1.00, 0.52),
        &"glut": Color(0.90, 1.00, 0.36),
        &"strahl": Color(0.56, 1.00, 0.46),
        &"kern": Color(0.92, 1.00, 0.82),
        &"ab_welle": 80,
    },
    {
        &"kennung": &"KNOCHEN",
        &"name": "Whalefall",
        &"regel": "Bleached on a carcass for a hundred years. Nothing left to stain.",
        &"haut": Color(0.94, 0.94, 0.90),
        &"glut": Color(0.86, 0.90, 0.96),
        &"strahl": Color(0.86, 0.90, 0.94),
        &"kern": Color(1.00, 1.00, 1.00),
        &"ab_welle": 130,
    },
    {
        &"kennung": &"RIFT",
        &"name": "Rift Ember",
        &"regel": "Taken from the deepest section anyone has come back from.",
        &"haut": Color(1.00, 0.56, 0.50),
        &"glut": Color(1.00, 0.34, 0.24),
        &"strahl": Color(1.00, 0.40, 0.36),
        &"kern": Color(1.00, 0.88, 0.80),
        &"ab_welle": 190,
    },
]


static func zahl() -> int:
    return TABELLE.size()


static func anstrich(index: int) -> Dictionary:
    return TABELLE[clampi(index, 0, TABELLE.size() - 1)]


static func name_von(index: int) -> String:
    return String(anstrich(index)[&"name"])


static func regel(index: int) -> String:
    return String(anstrich(index)[&"regel"])


static func haut(index: int) -> Color:
    return anstrich(index)[&"haut"]


static func glut(index: int) -> Color:
    return anstrich(index)[&"glut"]


static func strahl(index: int) -> Color:
    return anstrich(index)[&"strahl"]


static func kern(index: int) -> Color:
    return anstrich(index)[&"kern"]


static func ab_welle(index: int) -> int:
    return int(anstrich(index)[&"ab_welle"])


## Ob dieser Skin bei dieser Tiefe offen steht.
static func frei(index: int, tiefste_welle: int) -> bool:
    return tiefste_welle >= ab_welle(index)


## Der naechste, der noch aussteht - oder -1, wenn alle offen sind. Der
## Bildschirm sagt damit, wofuer sich das Weiterfahren lohnt; ein gesperrtes
## Feld ohne Ziel daneben ist nur eine Absage.
static func naechster_gesperrt(tiefste_welle: int) -> int:
    var beste := -1
    for i in zahl():
        if frei(i, tiefste_welle):
            continue
        if beste < 0 or ab_welle(i) < ab_welle(beste):
            beste = i
    return beste
