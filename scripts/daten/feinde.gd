class_name Feinde
extends RefCounted

## **Wer kommt.**
##
## Die Regel für jede Sorte lautet wie schon beim vorigen Spiel: **eine
## Sorte, die man am Verhalten nicht erkennt, ist keine.** Ein Feind mit mehr
## Leben ist derselbe Feind mit mehr Wartezeit.
##
## Hier sind es vier Verhalten, und jedes stellt eine eigene Frage:
##
##   * `LAEUFT` rennt geradeaus - die Masse, gegen die man sich aufstellt.
##   * `HAELT_ABSTAND` bleibt draußen und schießt - man muss zu ihm.
##   * `STUERMT` sammelt sich und prescht dann - man muss ausweichen.
##   * `TREIBT` macht die Nachbarn schneller - man muss ihn zuerst nehmen.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezüge.

enum Art { STROLCH, WOLF, SPIESSER, ARMBRUSTER, TREIBER, RITTER, WARLORD }

enum Sinn { LAEUFT, HAELT_ABSTAND, STUERMT, TREIBT }

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "Brigand", "Wolf", "Pikeman", "Crossbowman", "Standard Bearer",
    "Knight", "The Warlord",
]

## **Der Warlord: 8000, fest und ohne `Andrang.zaehigkeit`.** Sein Leben ist
## eine Kampfdauer. Gemessen (Daumen, Held unsterblich, 96 Laeufe) nimmt er im
## Median 120 Schaden je Sekunde, im unteren Viertel 60; 8000 sind damit gut
## eine Minute im Median. Vorher 2600 x Zaehigkeit, bei 570 s rund 8870 -
## fast dieselbe Zahl, aber er stand die Haelfte der Zeit ausserhalb des Bildes.
const LEBEN: PackedFloat32Array = [11.0, 8.0, 30.0, 16.0, 44.0, 85.0, 8000.0]
const TEMPO: PackedFloat32Array = [92.0, 172.0, 70.0, 58.0, 76.0, 88.0, 74.0]
## Was ein Treffer kostet. Feinde schlagen im Nahkampf dauernd zu, solange
## sie anliegen - `Gefecht.BISS_TAKT` sagt, wie oft.
const SCHADEN: PackedFloat32Array = [6.0, 5.0, 12.0, 9.0, 7.0, 17.0, 26.0]
const RADIUS: PackedFloat32Array = [17.0, 15.0, 20.0, 17.0, 20.0, 24.0, 52.0]
## **Wie weit einer den anderen fernhaelt** - nicht dasselbe wie `RADIUS`.
## `RADIUS` sagt, wer getroffen wird und wer anliegt; dieser hier, wie breit
## eine Figur im Bild steht. Fuer Aufrechte ist beides gleich, der Wolf aber
## liegt quer (`Streiter.WOLF_MASS`). Mit dem Trefferradius lagen 551 von 812
## Woelfen im Bild zu mehr als der Haelfte auf einem anderen.
##
## **22 und nicht die vollen 40 der alten Zeichnung.** Mit 28 wich das Rudel
## so weit aus, dass es auch den Laufenden umstellte: die Umzingelung stehend
## gegen laufend fiel auf Faktor 1,84, und die Wurfaxt trug allein 6 von 8.
## Also wurde der Wolf kleiner gezeichnet statt die Horde breiter gemacht.
const ABSTAND: PackedFloat32Array = [17.0, 22.0, 20.0, 17.0, 20.0, 24.0, 52.0]
const SINN: PackedInt32Array = [
    Sinn.LAEUFT, Sinn.LAEUFT, Sinn.LAEUFT, Sinn.HAELT_ABSTAND,
    Sinn.TREIBT, Sinn.STUERMT, Sinn.STUERMT,
]
## Was ein Erschlagener an Sold hergibt. Der Warlord zahlt einen Batzen.
const SOLD: PackedInt32Array = [1, 1, 2, 2, 4, 6, 120]


static func name_von(a: int) -> String:
    return NAMEN[clampi(a, 0, NAMEN.size() - 1)]


static func leben(a: int) -> float:
    return LEBEN[clampi(a, 0, LEBEN.size() - 1)]


static func tempo(a: int) -> float:
    return TEMPO[clampi(a, 0, TEMPO.size() - 1)]


static func schaden(a: int) -> float:
    return SCHADEN[clampi(a, 0, SCHADEN.size() - 1)]


static func radius(a: int) -> float:
    return RADIUS[clampi(a, 0, RADIUS.size() - 1)]


static func abstand(a: int) -> float:
    return ABSTAND[clampi(a, 0, ABSTAND.size() - 1)]


static func sinn(a: int) -> int:
    return SINN[clampi(a, 0, SINN.size() - 1)]


static func sold(a: int) -> int:
    return SOLD[clampi(a, 0, SOLD.size() - 1)]


static func ist_warlord(a: int) -> bool:
    return a == Art.WARLORD


## Auf welche Entfernung ein Schütze stehen bleibt. Näher kommt er nicht,
## weiter geht er nicht - genau das macht ihn zu einer Aufgabe und nicht zu
## einem Strolch mit Bogen.
const SCHUSS_WEITE := 330.0
const SCHUSS_TAKT := 2.3
const BOLZEN_TEMPO := 340.0
## Wie schwer ein Bolzen wiegt, als Vielfaches des Schadens des Schützen.
## Ein Bolzen fliegt sichtbar und geradeaus - wer quer geht, bleibt heil.
## Was man meiden kann, darf wehtun.
const BOLZEN_WUCHT := 2.0

## Der Stürmer: sammelt, prescht, ruht.
const STURM_SAMMELN := 0.9
const STURM_DAUER := 0.55
const STURM_TEMPO := 3.4

## **Ein harter Treffer ist angesagt.** So lange vor dem Sturm legt der
## Stürmer seine Bahn fest - auf den Ort, an dem der Held in diesem
## Augenblick steht - und sie liegt als Band am Boden. Wer in dieser Zeit
## aus der Bahn tritt, bleibt heil. Das ist der Zweck von Tempo: bis hierher
## brachte es gepaart gemessen keinen Vorteil (4 von 8 Saaten).
const STURM_ANSAGE := 0.6
## Wie hart der Sturm trifft, als Vielfaches des Schadens der Sorte. Er
## trifft **einmal je Sturm**, wie ein Geschoss, und nicht über die
## Berührung - Zusicherung 1 bleibt, wie sie ist.
const STURM_WUCHT := 3.0
## Wie weit ein Sturm trägt - für das Band am Boden.
static func sturm_weite(a: int) -> float:
    return tempo(a) * STURM_TEMPO * STURM_DAUER

## Der Treiber macht alles in seinem Umkreis schneller. Er ist damit die
## einzige Sorte, die **andere** gefährlich macht - wer ihn stehen lässt,
## kämpft gegen eine schnellere Horde.
const TREIB_WEITE := 260.0
const TREIB_SCHUB := 1.35
