class_name Gunst
extends RefCounted

## **Was man bei einem Aufstieg wählt.**
##
## Drei Angebote, eines wird genommen. Das ist die einzige Stelle im Lauf, an
## der der Spieler eine Entscheidung trifft - alles andere ist Aufstellung
## und Reflex. Sie muss deshalb **echte** Entscheidungen enthalten:
##
##   * **Nie drei vom selben Schlag.** Drei Passivwerte nebeneinander sind
##     keine Wahl, sondern eine Formalität.
##   * **Eine Waffe, die man schon führt, steht mit ihrer nächsten Stufe da**
##     und nicht noch einmal als neue. Zwei Wege zu derselben Sache sind
##     einer zu viel.
##   * **Hat man alle Plätze voll, werden nur noch Stufen angeboten.** Ein
##     Angebot, das man nicht annehmen kann, ist ein verschenkter Aufstieg.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezüge.

enum Zug { RUESTUNG, STIEFEL, WETZSTEIN, LATERNE, ZEHRUNG }

## Sichtbar, also englisch.
const ZUG_NAMEN: PackedStringArray = [
    "Mail", "Boots", "Whetstone", "Lantern", "Rations",
]

const ZUG_LEHREN: PackedStringArray = [
    "Blows against you bite less.",
    "You move quicker afoot.",
    "Every edge cuts deeper.",
    "Coin comes to you from further off.",
    "Wounds close, slowly, on their own.",
]

const ZUG_HOECHSTSTUFE := 5

## Wie viele Waffen ein Streiter zugleich führen kann. Wer am Ende alle
## sechs führt, hat nichts gewählt.
const WAFFEN_PLAETZE := 4
const ZUG_PLAETZE := 3

## Wie viele Angebote ein Aufstieg zeigt.
const ANGEBOTE := 3


static func zug_name(z: int) -> String:
    return ZUG_NAMEN[clampi(z, 0, ZUG_NAMEN.size() - 1)]


static func zug_lehre(z: int) -> String:
    return ZUG_LEHREN[clampi(z, 0, ZUG_LEHREN.size() - 1)]


## --- Was ein Zug auf Stufe `s` wirklich tut ---

## Anteil des Schadens, der abprallt. Gedeckelt weit unter eins: eine
## Rüstung, die alles abhält, beendet das Spiel.
static func panzer(stufe: int) -> float:
    return 0.10 * float(clampi(stufe, 0, ZUG_HOECHSTSTUFE))


static func tempo_faktor(stufe: int) -> float:
    return 1.0 + 0.09 * float(clampi(stufe, 0, ZUG_HOECHSTSTUFE))


static func schaden_faktor(stufe: int) -> float:
    return 1.0 + 0.14 * float(clampi(stufe, 0, ZUG_HOECHSTSTUFE))


static func sog(stufe: int) -> float:
    return 72.0 + 46.0 * float(clampi(stufe, 0, ZUG_HOECHSTSTUFE))


## Leben je Sekunde. Klein: Heilung, die den Druck aufhebt, macht aus einem
## Überlebenskampf eine Wartezeit.
static func zehrung(stufe: int) -> float:
    return 0.55 * float(clampi(stufe, 0, ZUG_HOECHSTSTUFE))


## Ein Angebot: entweder eine Waffe oder ein Zug, mit der Stufe, auf die es
## ginge.
class Angebot extends RefCounted:
    var ist_waffe := true
    var was := 0
    var stufe := 1
    var neu := true

    func name() -> String:
        return Waffen.name_von(was) if ist_waffe else Gunst.zug_name(was)

    func lehre() -> String:
        return Waffen.lehre_von(was) if ist_waffe else Gunst.zug_lehre(was)


## Die Angebote für einen Aufstieg.
##
## `waffen` und `zuege` sind Wörterbücher von Art auf Stufe; was nicht darin
## steht, hat man nicht.
static func angebote(waffen: Dictionary, zuege: Dictionary,
        rng: RandomNumberGenerator) -> Array:
    var topf: Array = []

    for w in Waffen.Art.size():
        var stufe := int(waffen.get(w, 0))
        if stufe >= Waffen.HOECHSTSTUFE:
            continue
        if stufe == 0 and waffen.size() >= WAFFEN_PLAETZE:
            continue
        var a := Angebot.new()
        a.ist_waffe = true
        a.was = w
        a.stufe = stufe + 1
        a.neu = stufe == 0
        topf.append(a)

    for z in Zug.size():
        var stufe := int(zuege.get(z, 0))
        if stufe >= ZUG_HOECHSTSTUFE:
            continue
        if stufe == 0 and zuege.size() >= ZUG_PLAETZE:
            continue
        var a := Angebot.new()
        a.ist_waffe = false
        a.was = z
        a.stufe = stufe + 1
        a.neu = stufe == 0
        topf.append(a)

    if topf.is_empty():
        return []

    # Mischen, dann so wählen, dass nicht alle drei vom selben Schlag sind.
    #
    # **Mit dem uebergebenen `rng`, nicht mit `Array.shuffle()`.** Der greift
    # auf Godots globalen Generator zu, und der ist in jedem Prozess anders
    # gesetzt. Damit war kein Lauf wiederholbar: zwei Messungen mit
    # denselben Saaten meldeten fuer dasselbe Stehenbleiben einmal 232 und
    # einmal 300 Sekunden. In einem Repository, dessen ganze Balance auf
    # gesaeten Vergleichen steht, ist das kein Detail - ein Messstand, der
    # bei gleicher Saat andere Zahlen liefert, misst gar nichts.
    for i in range(topf.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var h: Variant = topf[i]
        topf[i] = topf[j]
        topf[j] = h
    var gewaehlt: Array = []
    var waffen_drin := 0
    for a in topf:
        if gewaehlt.size() >= ANGEBOTE:
            break
        # Höchstens zwei Waffen und höchstens zwei Züge unter dreien: so
        # steht in jedem Aufstieg beides zur Wahl, solange es beides gibt.
        if a.ist_waffe and waffen_drin >= 2:
            continue
        if not a.ist_waffe and gewaehlt.size() - waffen_drin >= 2:
            continue
        gewaehlt.append(a)
        if a.ist_waffe:
            waffen_drin += 1
    # Falls die Schranken zu viel ausgesiebt haben: auffüllen, was übrig ist.
    for a in topf:
        if gewaehlt.size() >= ANGEBOTE:
            break
        if not gewaehlt.has(a):
            gewaehlt.append(a)
    return gewaehlt


## **Wieviel Sold der nächste Aufstieg kostet.**
##
## Geometrisch, sonst steigt man in Minute neun im Sekundentakt auf und die
## Wahl wird zur Klickarbeit. Der Faktor ist bewusst klein: die ersten Stufen
## sollen schnell kommen, weil ein Lauf ohne Waffen langweilig ist.
static func stufenkosten(stufe: int) -> int:
    return int(ceil(5.0 * pow(1.32, float(maxi(1, stufe) - 1))))
