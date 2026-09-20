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
##
## **Der Speer stand auf 0,58 und war damit die schwaechste Waffe im Spiel.**
## Gemessen ueber acht Saaten, und zwar ueber Kreuz: der Speertraeger stand
## mit seinem eigenen Speer 5 von 8 Laeufen durch und mit dem Schwert 7 von
## 8; der Schwertkaempfer umgekehrt 8 von 8 mit seinem Schwert und 5 von 8
## mit dem Speer. **Die Schwaeche folgt der Waffe, nicht dem Helden** - und
## ueber Kreuz messen ist der einzige Weg, die beiden auseinanderzuhalten.
##
## Er stoesst nach hinten und trifft damit nur, was in der Fluchtachse
## liegt; bei 0,58 ist das ein Keil von dreiunddreissig Grad, gegen
## neunundachtzig beim Schwert. **Und er ist der einzige, der blind zielt** -
## jede andere Nahkampfwaffe nimmt den naechsten Feind, ihr Kegel enthaelt
## also immer ein Ziel. Beim Speer ist es Gluecksache.
##
## Das ist ein echter Mangel und **er ist trotzdem nicht behoben.** Vier
## Fassungen wurden ueber je acht Saaten gemessen - `Speertraeger` ist die
## Quote aus `_test_ein_laeufer_haelt_die_ersten_minuten` (gefordert 7/8),
## `Verhaeltnis` das aus `_test_stehenbleiben_verliert` (gefordert < 0,60):
##
##     Fassung                  Speertraeger   steht  laeuft  Verhaeltnis
##     blind,  BREITE 0,58          5/8         323     552      0,585  ok
##     blind,  BREITE 1,10          6/8          -       -         -
##     naechster dahinter, 0,58     8/8         323     428      0,754
##     naechster dahinter, 1,10     7/8         382     461      0,829
##
## **Jede Fassung, die den Speertraeger hebt, verschlechtert das
## Verhaeltnis** - und die letzte Zeile sagt, warum: dort steigt auch
## `steht`, von 323 auf 382. Der Stehende fuehrt den Speer ja auch, und er
## ist **rundum** von Zielen umgeben. Eine bessere Waffe nuetzt ihm deshalb
## *mehr* als dem Fliehenden, der nur nach hinten trifft.
##
## Das ist keine Eigenheit des Speers: **dieser Waechter steht jeder
## Waffenverbesserung im Weg.** Wer ihn anfasst, sollte das zuerst
## auseinandernehmen - zwei Erklaerungen sind dabei bereits gemessen und
## **widerlegt** worden:
##
##   * *Der bessere Speer reisst die Luecke auf, durch die sich der Ring
##     schliesst.* Waere das der Kanal, muesste eine halbierte Umzingelung
##     (`UMZINGELT_VOLL` 4,0 -> 2,5) den Laufenden zurueckholen. Sie gibt ihm
##     zehn Sekunden von hundertvierundzwanzig, und sie schenkt dem
##     Stehenden siebzig - das Verhaeltnis wird schlechter, nicht besser.
##   * *Mehr Erschlagene heisst mehr Aufstiege, und `Daumen` verzettelt sich
##     in neuen Waffen.* Gemessen bei 300 s traegt er mit und ohne Griff
##     genau 4,00 Waffen auf mittlerer Stufe 1,50 - und er erschlaegt mit
##     dem klugen Speer **weniger** (697 gegen 758) und ist **weniger**
##     umzingelt (0,090 gegen 0,115).
##
## **Offener Posten.** Der Speer traegt seine ersten drei Minuten schlechter
## als jede andere Waffe. Wer ihn angeht, misst ueber acht Saaten und prueft
## **beide** Schranken - drei Saaten melden hier den Wurf und nicht die
## Regel.
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
