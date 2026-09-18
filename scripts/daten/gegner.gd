class_name Gegner
extends RefCounted

## **Wer dir gegenuebersteht.**
##
## Ein Gegner ist in diesem Spiel kein Sack Lebenspunkte - er ist ein
## **Rhythmus**. Alles, was ihn ausmacht, steht in vier Zahlen: wie lange er
## ausholt, wie eng das Fenster ist, wie lange er nach einer Parade offen
## steht, und ob er dabei luegt.
##
## Daraus folgt die Regel, an der sich jede neue Sorte messen lassen muss:
## **eine Sorte, die man am Rhythmus nicht erkennt, ist keine.** Ein Gegner,
## der nur mehr Leben hat, ist derselbe Gegner mit mehr Wartezeit.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Art {
    RONIN,       ## der Massstab - alles mittel, nichts besonders
    SCHNELL,     ## kurzer Ansatz, dafuer weit offen nach der Parade
    FEINT,       ## die Linie wechselt einmal mitten im Ansatz
    SCHWER,      ## langer Ansatz, enges Fenster, zwei Paraden
    STOSSER,     ## tippen statt wischen
    MEISTER,     ## der Hoehepunkt: taeuscht, stoesst und ist schnell
}

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "Ronin", "Quickblade", "Feintmaster", "Ironarm", "Lancer", "The Master",
]

## Ein Satz im Bestiarium. Er sagt, was zu tun ist - nicht, was das Tier ist.
const LEHREN: PackedStringArray = [
    "The measure of every blade. Read the line, meet the line.",
    "Barely winds up. Stop watching, start answering.",
    "The line you see is not always the line that falls. Read it twice.",
    "Slow, and it does not care. Two parries, and the window is narrow.",
    "No sweep will save you. A point is beaten down with a tap.",
    "Everything the others do, in one body. Breathe.",
]

## **Wie lange der Ansatz dauert**, in Sekunden - die Zeit, in der die
## Fuehrungslinie im Bild steht und waechst. Das ist die eigentliche
## Schwierigkeitszahl des Spiels: sie ist die Lesezeit.
const ANSATZ: PackedFloat32Array = [1.05, 0.62, 1.20, 1.55, 0.95, 0.78]

## **Das Fenster um den Schlag**, in Sekunden nach beiden Seiten. Wer
## frueher oder spaeter wischt, trifft Luft.
##
## Es ist bewusst nicht als Anteil des Ansatzes gerechnet: eine Parade ist
## eine Reaktion, und eine Reaktion misst sich in Sekunden und nicht in
## Anteilen. Sonst waere ein langsamer Gegner automatisch auch der mit dem
## bequemsten Fenster, und "langsam" hiesse zweimal dasselbe.
const FENSTER: PackedFloat32Array = [0.30, 0.26, 0.28, 0.17, 0.27, 0.20]

## **Wie lange er nach einer Parade offen steht.** Das ist der Lohn: die
## Sekunden, in denen ein Wisch toetet statt nur abzuwehren.
const OEFFNUNG: PackedFloat32Array = [0.95, 1.30, 0.90, 0.70, 0.95, 0.62]

## **Wie viele Paraden es braucht**, bevor eine Oeffnung entsteht.
const PARADEN: PackedInt32Array = [1, 1, 1, 2, 1, 2]

## **Taeuscht er?** Der Feint wechselt einmal mitten im Ansatz die Linie -
## und zwar so spaet, dass die erste Lesung nicht mehr traegt.
const TAEUSCHT: PackedByteArray = [0, 0, 1, 0, 0, 1]

## Wann im Ansatz die Taeuschung faellt, als Anteil. Bei 0.55 bleibt gut die
## Haelfte der Lesezeit fuer die wahre Linie - weniger waere kein Lesen mehr,
## sondern Raten.
const TAEUSCH_LAGE := 0.55

## **Welche Linien er ueberhaupt fuehrt.** Der Stosser kennt nur die Spitze,
## der Meister alles. Leer heisst: die vier gewischten Achsen.
static func linien_von(art: int) -> PackedInt32Array:
    match art:
        Art.STOSSER:
            return PackedInt32Array([Schnitte.Linie.STOSS])
        Art.MEISTER:
            return PackedInt32Array([
                Schnitte.Linie.SENKRECHT, Schnitte.Linie.KESA,
                Schnitte.Linie.WAAGERECHT, Schnitte.Linie.GYAKU,
                Schnitte.Linie.STOSS])
        _:
            return Schnitte.GEWISCHT


## **Was er einbringt.** Ehre ist die einzige Waehrung, und sie faellt aus
## dem, was ein Gegner an Zeit und Nerven gekostet hat: der Kehrwert seines
## Fensters, mal der Zahl seiner Paraden. Eine frei gewaehlte Zahl je Sorte
## waere eine zweite Meinung ueber dieselbe Schwierigkeit.
static func ehre(art: int) -> int:
    var a := clampi(art, 0, NAMEN.size() - 1)
    var eng := FENSTER[Art.RONIN] / maxf(0.01, FENSTER[a])
    return maxi(1, int(round(4.0 * eng * float(PARADEN[a]))))


static func name_von(art: int) -> String:
    return NAMEN[clampi(art, 0, NAMEN.size() - 1)]


static func lehre_von(art: int) -> String:
    return LEHREN[clampi(art, 0, LEHREN.size() - 1)]


static func ansatz(art: int) -> float:
    return ANSATZ[clampi(art, 0, ANSATZ.size() - 1)]


static func fenster(art: int) -> float:
    return FENSTER[clampi(art, 0, FENSTER.size() - 1)]


static func oeffnung(art: int) -> float:
    return OEFFNUNG[clampi(art, 0, OEFFNUNG.size() - 1)]


static func paraden(art: int) -> int:
    return PARADEN[clampi(art, 0, PARADEN.size() - 1)]


static func taeuscht(art: int) -> bool:
    return TAEUSCHT[clampi(art, 0, TAEUSCHT.size() - 1)] != 0


## Ist das der Hoehepunkt einer Ronde? Wie beim Leitwesen: er kommt zuletzt,
## und er kommt allein.
static func ist_meister(art: int) -> bool:
    return art == Art.MEISTER
