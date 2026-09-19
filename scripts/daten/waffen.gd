class_name Waffen
extends RefCounted

## **Was der Streiter führt.**
##
## Eine Waffe schlägt **von selbst**. Der Finger führt nur den Mann; was
## trifft, entscheidet die Aufstellung — wohin man läuft, wen man vor sich
## lässt, wann man durch eine Lücke geht. Das ist der Kern dieses Genres, und
## jede Waffe hier muss deshalb eine *Frage an die Aufstellung* stellen:
##
##   * das **Schwert** fragt, wohin du siehst,
##   * der **Speer** fragt, wohin du läufst — und stößt nach hinten,
##   * der **Flegel** fragt, wie nah du sie heranlässt,
##   * die **Armbrust** fragt gar nichts — dafür trifft sie am wenigsten,
##   * der **Hammer** fragt, wie viele gleichzeitig um dich stehen,
##   * die **Axt** fragt, ob du stehen bleibst, wenn sie zurückkommt.
##
## Eine siebte Waffe, die dieselbe Frage stellt wie eine vorhandene, ist
## keine Waffe, sondern ein zweiter Name.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezüge.

enum Art { SCHWERT, SPEER, FLEGEL, ARMBRUST, HAMMER, AXT }

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "Arming Sword", "Boar Spear", "Flail", "Crossbow", "War Hammer", "Throwing Axe",
]

const LEHREN: PackedStringArray = [
    "Cuts an arc before you. Face the press.",
    "Thrusts behind you. It answers the ones at your heels.",
    "Heads swing about you. Let them come close.",
    "Looses at the nearest. Asks nothing of you.",
    "Strikes the ground. Pays when they crowd.",
    "Flies out and comes back. Stand your ground.",
]

const HOECHSTSTUFE := 5

## **Grundschaden je Treffer** auf Stufe eins.
## Gemessen und nachgezogen, nicht geschaetzt: `tools/probe.gd` und ein
## Wegwerf-Messstand gaben je Waffe allein ueber zwei Minuten 151 / 99 / 37 /
## 138 / 231 / 268 Erschlagene. Faktor sieben zwischen der besten und der
## schlechtesten heisst, dass es keine Wahl gibt, sondern eine richtige
## Antwort - und alle anderen Angebote waeren Fuellung.
const SCHADEN: PackedFloat32Array = [16.0, 21.0, 13.0, 11.0, 24.0, 12.0]

## **Sekunden zwischen zwei Schlägen** auf Stufe eins.
const TAKT: PackedFloat32Array = [0.66, 0.78, 0.42, 0.80, 1.90, 1.45]

## **Reichweite** in Weltpunkten. Der Flegel führt hier den Bahnradius.
##
## **Seiner lag bei 96 und damit im Leeren.** Die Feinde draengen sich am
## Beruehrungsring, also bei rund vierzig Punkten; seine Koepfe kreisten weit
## darueber hinaus und trafen fast nie - siebenunddreissig Erschlagene gegen
## zweihundertachtundsechzig bei der Axt. Er kreist jetzt dort, wo das
## Gedraenge wirklich steht, und das ist zugleich seine Aussage: *lass sie
## nah heran.*
const WEITE: PackedFloat32Array = [132.0, 168.0, 70.0, 520.0, 138.0, 460.0]

## **Wie breit der Schlag streut**, im Bogenmaß. Null heißt: ein Punkt oder
## eine Bahn, kein Kegel.
const BREITE: PackedFloat32Array = [1.55, 0.58, 0.0, 0.0, TAU, 0.0]

## Wie viele Geschosse oder Köpfe auf Stufe eins.
const ZAHL: PackedInt32Array = [1, 1, 3, 1, 1, 1]


static func name_von(w: int) -> String:
    return NAMEN[clampi(w, 0, NAMEN.size() - 1)]


static func lehre_von(w: int) -> String:
    return LEHREN[clampi(w, 0, LEHREN.size() - 1)]


## --- Wie eine Stufe wirkt ---
##
## **Jede Stufe gibt genau eine spürbare Sache**, und zwar der Reihe nach.
## Eine Stufe, die alles ein bisschen hebt, fühlt sich nach nichts an: der
## Spieler wählt sie und merkt keinen Unterschied. Deshalb wächst hier je
## Stufe abwechselnd Schaden, Zahl und Takt — und die Zahl ist die, die man
## am deutlichsten sieht.

static func schaden(w: int, stufe: int) -> float:
    var s := clampi(stufe, 1, HOECHSTSTUFE)
    return SCHADEN[clampi(w, 0, SCHADEN.size() - 1)] * (1.0 + 0.34 * float(s - 1))


static func takt(w: int, stufe: int) -> float:
    var s := clampi(stufe, 1, HOECHSTSTUFE)
    # Stufe 3 und 5 beschleunigen.
    var schneller := 1.0
    if s >= 3:
        schneller *= 0.82
    if s >= 5:
        schneller *= 0.80
    return TAKT[clampi(w, 0, TAKT.size() - 1)] * schneller


static func zahl(w: int, stufe: int) -> int:
    var s := clampi(stufe, 1, HOECHSTSTUFE)
    var grund := ZAHL[clampi(w, 0, ZAHL.size() - 1)]
    # Stufe 2 und 4 geben ein Stück mehr.
    var mehr := 0
    if s >= 2:
        mehr += 1
    if s >= 4:
        mehr += 1
    return grund + mehr


static func weite(w: int, stufe: int) -> float:
    var s := clampi(stufe, 1, HOECHSTSTUFE)
    return WEITE[clampi(w, 0, WEITE.size() - 1)] * (1.0 + 0.09 * float(s - 1))


static func breite(w: int, stufe: int) -> float:
    var s := clampi(stufe, 1, HOECHSTSTUFE)
    var b := BREITE[clampi(w, 0, BREITE.size() - 1)]
    if b <= 0.0 or b >= TAU:
        return b
    return minf(TAU, b * (1.0 + 0.10 * float(s - 1)))


## Fliegt sie, oder trifft sie sofort? Das trennt die beiden Arten, wie ein
## Schlag aufgelöst wird - und es steht hier und nicht im Gefecht, damit
## niemand es an zwei Stellen entscheidet.
static func fliegt(w: int) -> bool:
    return w == Art.ARMBRUST or w == Art.AXT


## Steht sie dauernd im Feld, statt zu schlagen? Der Flegel kreist; er hat
## keinen Schlag, sondern eine Anwesenheit.
static func kreist(w: int) -> bool:
    return w == Art.FLEGEL
