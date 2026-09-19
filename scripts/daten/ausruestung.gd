class_name Ausruestung
extends RefCounted

## **Was man behaelt.**
##
## Vier Plaetze, acht Stuecke, fuenf Stufen. Ein Stueck faellt am Ende eines
## Laufs; faellt es ein zweites Mal, hebt es seine Stufe. Damit ist **jeder
## Lauf etwas wert**, auch ein kurzer - und genau das ist die Aufgabe dieser
## Ebene: die Burg gibt die stetige Kurve, der Held die Abwechslung, die
## Ausruestung die Fundfreude.
##
## **Jedes Stueck wirkt auf genau einen Wert.** Dieselbe Regel wie beim
## Helden, und aus demselben Grund: ein Ring, der fuenf Dinge ein bisschen
## hebt, ist im Spiel nicht zu bemerken und in der Anzeige nicht zu erklaeren.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Platz { HELM, HARNISCH, RING, UMHANG }
enum Wirkt { LEBEN, SCHADEN, TEMPO, SOG, PANZER }

enum Stueck {
    KESSELHAUBE, VISIERHELM,
    KETTENHEMD, PLATTENROCK,
    SIEGELRING, BLUTSTEIN,
    REISEMANTEL, BANNERTUCH,
}

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "Kettle Helm", "Visored Helm",
    "Hauberk", "Plated Coat",
    "Signet Ring", "Bloodstone",
    "Travelling Cloak", "Banner Cloth",
]

const PLATZ_NAMEN: PackedStringArray = ["Head", "Body", "Hand", "Back"]

const AUF_PLATZ: PackedInt32Array = [
    Platz.HELM, Platz.HELM,
    Platz.HARNISCH, Platz.HARNISCH,
    Platz.RING, Platz.RING,
    Platz.UMHANG, Platz.UMHANG,
]

const WIRKT_AUF: PackedInt32Array = [
    Wirkt.LEBEN, Wirkt.PANZER,
    Wirkt.LEBEN, Wirkt.PANZER,
    Wirkt.SOG, Wirkt.SCHADEN,
    Wirkt.TEMPO, Wirkt.SCHADEN,
]

## Was eine Stufe zulegt, als Anteil. Der Panzer ist bewusst der kleinste:
## er multipliziert sich mit der Ruestung aus dem Lauf, und zwei Quellen
## desselben Abzugs summieren sich schneller, als man denkt.
const JE_STUFE: PackedFloat32Array = [
    0.07, 0.025,
    0.09, 0.030,
    0.12, 0.05,
    0.05, 0.06,
]

const HOECHSTSTUFE := 5


static func name_von(s: int) -> String:
    return NAMEN[clampi(s, 0, NAMEN.size() - 1)]


static func platz_name(p: int) -> String:
    return PLATZ_NAMEN[clampi(p, 0, PLATZ_NAMEN.size() - 1)]


static func platz_von(s: int) -> int:
    return AUF_PLATZ[clampi(s, 0, AUF_PLATZ.size() - 1)]


static func wirkt_auf(s: int) -> int:
    return WIRKT_AUF[clampi(s, 0, WIRKT_AUF.size() - 1)]


## Ein Satz, der sagt, was es tut. Gerechnet und nicht getippt: eine
## Beschreibung, die von Hand neben einer Zahl steht, laeuft ihr davon.
static func lehre_von(s: int, stufe: int) -> String:
    var v := int(round(anteil(s, stufe) * 100.0))
    match wirkt_auf(s):
        Wirkt.LEBEN:
            return "+%d%% life" % v
        Wirkt.SCHADEN:
            return "+%d%% damage" % v
        Wirkt.TEMPO:
            return "+%d%% speed" % v
        Wirkt.SOG:
            return "+%d%% pickup range" % v
        _:
            return "+%d%% armour" % v


static func anteil(s: int, stufe: int) -> float:
    return JE_STUFE[clampi(s, 0, JE_STUFE.size() - 1)] \
        * float(clampi(stufe, 0, HOECHSTSTUFE))


## **Der Gesamtfaktor eines Wertes.** `angelegt` bildet Platz auf Stueck ab,
## `besitz` Stueck auf Stufe - beide stehen im Spielstand.
##
## Herauskommt immer ein Faktor um eins herum, auch wenn nichts angelegt ist:
## so kann `Gefecht.baue()` ihn bedingungslos multiplizieren, und es gibt
## keine Stelle, an der jemand ein `if` vergisst.
static func summe(angelegt: Dictionary, wirkt: int) -> float:
    var f := 1.0
    for platz in angelegt.keys():
        var eintrag: Variant = angelegt[platz]
        if not (eintrag is Array) or eintrag.size() < 2:
            continue
        var stueck := int(eintrag[0])
        var stufe := int(eintrag[1])
        if stufe <= 0 or wirkt_auf(stueck) != wirkt:
            continue
        f += anteil(stueck, stufe)
    return f


## **Was am Ende eines Laufs faellt.** Die Guete haengt an der erreichten
## Zeit: wer lange steht, findet Besseres. Gezogen wird aus allen Stuecken,
## damit kein Platz austrocknet.
static func fund(zeit: float, rng: RandomNumberGenerator) -> int:
    return rng.randi_range(0, Stueck.size() - 1)


## Wie viele Stufen ein Fund auf einmal bringt. Ein langer Lauf soll sich
## lohnen, ohne dass ein kurzer leer ausgeht.
static func fund_stufen(zeit: float) -> int:
    return clampi(1 + int(zeit / 180.0), 1, 3)
