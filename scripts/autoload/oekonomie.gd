## Reine Spielmathematik: Kosten, Produktion, Prestige, Offline-Ertrag.
##
## Diese Klasse kennt weder Szenenbaum noch UI und haelt keinen Zustand. Alles
## sind statische Funktionen ueber uebergebene Werte. Genau deshalb laesst sich
## das gesamte Balancing headless testen, ohne das Spiel zu starten.
class_name Oekonomie
extends RefCounted

## Anteil der Produktion, der waehrend Abwesenheit gutgeschrieben wird.
const OFFLINE_ANTEIL := 0.5

## Standard-Obergrenze fuer Offline-Ertrag (4 Stunden).
const OFFLINE_CAP_BASIS := 4.0 * 3600.0

## Hoechstmoegliche Obergrenze nach Vollausbau (24 Stunden).
const OFFLINE_CAP_MAX := 24.0 * 3600.0

## Bezugsgroesse der Prestige-Kurve.
##
## Aus dem Balancing-Durchlauf hergeleitet, nicht geraten: mit dem
## urspruenglichen Wert 1e12 war das erste Prestige erst nach 7,5 Stunden
## moeglich. Wer so lange spielt, ohne die Kernmechanik zu sehen, hoert
## vorher auf. Dieser Wert bringt es auf gut zwei Stunden.
const PRESTIGE_SKALA := 1.2e8

## Skalierung der Prestige-Ausbeute.
const PRESTIGE_FAKTOR := 15.0

## Mindestausbeute, ab der ein Reset ueberhaupt angeboten wird.
##
## Ohne diese Sperre waere der erste Reset ein Protokoll wert - also plus zwei
## Prozent fuer den Verlust der gesamten Station. Ein Spieler, der das einmal
## macht, macht es nie wieder. Erst ab zehn Protokollen lohnt der Schnitt
## sichtbar.
const MIN_PROTOKOLLE := 10

## Dauerhafter Produktionsbonus je Protokoll (2 Prozent).
const PROTOKOLL_BONUS := 0.02

## Obergrenze fuer [method max_kaufbar]; verhindert absurde Werte bei Overflow.
const KAUF_LIMIT := 1000


# --- Kosten -----------------------------------------------------------------

## Kosten des naechsten Exemplars, wenn bereits [param besessen] Stueck stehen.
static func kosten(index: int, besessen: int) -> float:
    return Modul.basiskosten(index) * pow(Modul.WACHSTUM, besessen)


## Gesamtkosten fuer [param menge] weitere Exemplare am Stueck.
##
## Geschlossene Form der geometrischen Reihe statt Schleife - bei einem
## "x100 kaufen"-Knopf ist das der Unterschied zwischen sofort und spuerbar.
static func kosten_summe(index: int, besessen: int, menge: int) -> float:
    if menge <= 0:
        return 0.0
    var g := Modul.WACHSTUM
    return Modul.basiskosten(index) * pow(g, besessen) * (pow(g, menge) - 1.0) / (g - 1.0)


## Wie viele Exemplare [param guthaben] am Stueck deckt.
##
## Umkehrung von [method kosten_summe] nach der Menge aufgeloest.
static func max_kaufbar(index: int, besessen: int, guthaben: float) -> int:
    if guthaben <= 0.0 or is_nan(guthaben):
        return 0
    var g := Modul.WACHSTUM
    var start := Modul.basiskosten(index) * pow(g, besessen)
    if start <= 0.0 or is_inf(start):
        return 0
    var verhaeltnis := 1.0 + guthaben * (g - 1.0) / start
    if verhaeltnis <= 1.0:
        return 0
    var menge := int(floor(log(verhaeltnis) / log(g)))
    return clampi(menge, 0, KAUF_LIMIT)


# --- Produktion -------------------------------------------------------------

## Multiplikator aus erreichten Stueckzahl-Meilensteinen (verdoppelt je Stufe).
static func meilenstein_mult(besessen: int) -> float:
    var erreicht := 0
    for schwelle in Modul.MEILENSTEINE:
        if besessen >= schwelle:
            erreicht += 1
    return pow(2.0, erreicht)


## Produktion eines Modultyps in Plasma pro Sekunde.
static func modul_rate(index: int, besessen: int, global_mult: float = 1.0) -> float:
    if besessen <= 0:
        return 0.0
    return Modul.basisrate(index) * besessen * meilenstein_mult(besessen) * global_mult


## Produktion aller Module zusammen in Plasma pro Sekunde.
static func gesamt_rate(bestand: Array, global_mult: float = 1.0) -> float:
    var summe := 0.0
    for i in mini(bestand.size(), Modul.ANZAHL):
        summe += modul_rate(i, int(bestand[i]), global_mult)
    return summe


# --- Prestige ---------------------------------------------------------------

## Protokolle, die ein Reset beim aktuellen Lebenszeit-Ertrag einbringt.
static func prestige_ertrag(lebenszeit_plasma: float) -> int:
    if lebenszeit_plasma <= 0.0 or is_nan(lebenszeit_plasma):
        return 0
    return int(floor(PRESTIGE_FAKTOR * sqrt(lebenszeit_plasma / PRESTIGE_SKALA)))


## Ob sich ein Reset lohnt - siehe [constant MIN_PROTOKOLLE].
static func prestige_moeglich(lebenszeit_plasma: float) -> bool:
    return prestige_ertrag(lebenszeit_plasma) >= MIN_PROTOKOLLE


## Dauerhafter Produktionsmultiplikator aus gesammelten Protokollen.
static func prestige_mult(protokolle: int) -> float:
    return 1.0 + PROTOKOLL_BONUS * maxi(protokolle, 0)


# --- Offline ----------------------------------------------------------------

## Gutschrift fuer Abwesenheit.
##
## Ein Rueckwaertssprung der Systemuhr ergibt bewusst 0: sonst liesse sich das
## Spiel durch Zeitverstellen beliebig ausbeuten. Der Aufrufer stempelt den
## Zeitstempel danach neu.
static func offline_ertrag(rate: float, verstrichen: float, cap: float = OFFLINE_CAP_BASIS) -> float:
    if verstrichen <= 0.0 or rate <= 0.0 or is_nan(verstrichen):
        return 0.0
    return rate * minf(verstrichen, cap) * OFFLINE_ANTEIL
