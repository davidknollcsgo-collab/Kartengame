class_name Schule
extends RefCounted

## **Die Schule hinter dem Duell.**
##
## Vier Hallen, vier Zahlen, und jede davon greift genau eine Stelle des
## Duells an. Das ist die Bedingung, unter der ein Aufbauspiel vor einem
## Koennensspiel ueberhaupt erlaubt ist: **jede Stufe muss sich im Duell
## anfuehlen**, sonst kauft man Zahlen und nicht Koennen.
##
##   * `AUGE` verlaengert den Ansatz - mehr Lesezeit.
##   * `HANDGELENK` verbreitert das Fenster - mehr Nachsicht beim Zeitpunkt.
##   * `ATEM` traegt mehr Wunden.
##   * `SCHNEIDE` haelt den Gegner laenger offen.
##
## **Was es ausdruecklich nicht gibt, ist Schaden.** Ein Hieb toetet, wenn er
## sitzt, und das gilt fuer beide Seiten - vom ersten Duell bis zum letzten.
## Eine Schule, die den Spieler haerter zuschlagen laesst, macht aus einem
## Duell ein Rechenspiel.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Halle { AUGE, HANDGELENK, ATEM, SCHNEIDE }

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = ["Eye", "Wrist", "Breath", "Edge"]

const BESCHREIBUNG: PackedStringArray = [
    "The wind-up lasts longer. You see the line sooner.",
    "The parry window widens. Your timing may err further.",
    "You carry another wound before you fall.",
    "A parried enemy stays open longer.",
]

const HOECHSTSTUFE := 40

## Kosten wachsen geometrisch. Wer das linear macht, hat nach zwanzig Stufen
## ein Spiel, in dem nichts mehr kostet.
const GRUNDKOSTEN: PackedFloat32Array = [12.0, 12.0, 20.0, 14.0]
const WACHSTUM: PackedFloat32Array = [1.42, 1.44, 1.52, 1.46]

## Wie viele Ronden eine volle Runde durch alle vier Hallen kosten darf.
## Aus dieser einen Zahl faellt der ganze Ertrag - siehe `Ronde.ehre()`.
const RONDEN_JE_RUNDE := 9.0


static func name_von(h: int) -> String:
    return NAMEN[clampi(h, 0, NAMEN.size() - 1)]


static func beschreibung_von(h: int) -> String:
    return BESCHREIBUNG[clampi(h, 0, BESCHREIBUNG.size() - 1)]


## Was die naechste Stufe dieser Halle kostet.
static func kosten(h: int, stufe: int) -> int:
    var i := clampi(h, 0, NAMEN.size() - 1)
    return int(ceil(GRUNDKOSTEN[i] * pow(WACHSTUM[i], float(maxi(0, stufe)))))


## Was eine volle Runde durch alle vier Hallen auf dieser Stufe kostet. Der
## Ertrag wird daraus abgeleitet und nicht frei gewaehlt - sonst laufen
## Einkommen und Kosten auseinander, und zwar fuer immer.
static func rundenkosten(stufe: int) -> float:
    var summe := 0.0
    for h in NAMEN.size():
        summe += float(kosten(h, stufe))
    return summe


## --- Was die Stufen im Duell wirklich tun ---
##
## Alle vier laufen ueber dieselbe Form: ein Anteil des Weges vom Grundwert
## zum Deckel, mit abnehmendem Zuwachs. Eine Halle, die linear waechst, ist
## am Ende entweder wirkungslos oder kaputt.

static func _kurve(stufe: int) -> float:
    var t := clampf(float(stufe) / float(HOECHSTSTUFE), 0.0, 1.0)
    return 1.0 - pow(1.0 - t, 1.7)


## Zusaetzliche Lesezeit in Sekunden. Bei voller Stufe knapp eine halbe
## Sekunde - auf einen Ansatz von 0,6 s ist das viel, und genau so soll es
## sich anfuehlen.
const AUGE_HOECHST := 0.46

static func lesezeit(stufe: int) -> float:
    return AUGE_HOECHST * _kurve(stufe)


## Zusaetzliches Fenster in Sekunden, nach **beiden** Seiten.
const HANDGELENK_HOECHST := 0.15

static func fensterzusatz(stufe: int) -> float:
    return HANDGELENK_HOECHST * _kurve(stufe)


## Wunden, die man traegt. Drei zu Beginn, sieben am Ende.
const ATEM_GRUND := 3
const ATEM_HOECHST := 7

static func atem(stufe: int) -> int:
    return ATEM_GRUND + int(round(float(ATEM_HOECHST - ATEM_GRUND) * _kurve(stufe)))


## Faktor auf die Oeffnung nach einer Parade.
const SCHNEIDE_HOECHST := 1.85

static func oeffnungsfaktor(stufe: int) -> float:
    return lerpf(1.0, SCHNEIDE_HOECHST, _kurve(stufe))


## **Die Sollkurve.** Welche Stufe ein Spieler haben sollte, wenn er Ronde
## `nummer` erreicht. Daraus faellt die Staerke der Ronde, genau wie die
## Kosten aus derselben Kurve fallen - eine Kurve, zwei Richtungen.
static func stufe_soll(nummer: int) -> int:
    return clampi(int(floor(float(maxi(1, nummer) - 1) / 2.2)), 0, HOECHSTSTUFE)


## **Die Schule macht die Ronde nicht kleiner, sondern ueberlebbar.**
##
## Hier stand einmal eine `fassung()`, aus der die Rondengroesse fiel - so
## wie in einem Aufbauspiel ueblich. Das war falsch, und zwar aus einem
## Grund, der das ganze Spiel betrifft: die vier Hallen geben **Nachsicht**
## (Lesezeit, Fenster, Wunden, Oeffnung), nicht Durchsatz. Wer daraus eine
## groessere Ronde ableitet, nimmt mit der einen Hand, was er mit der
## anderen gibt - und der Spieler kauft eine Stufe und merkt nichts.
##
## Wie gross eine Ronde ist, sagt deshalb allein die Ronde (`Ronde.druck()`
## und `Ronde.gleichzeitig()`). Wie schwer sie sich anfuehlt, sagt die
## Schule. Zwei Regler, zwei Aussagen.
