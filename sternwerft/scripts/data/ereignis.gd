## Treibende Funde und ihre Belohnungen.
##
## Ein Idle-Spiel läuft von allein - genau das ist sein Reiz und zugleich sein
## Problem: es gibt keinen Grund hinzusehen. Ein Fund, der eine Weile durchs
## Bild treibt und beim Antippen etwas abwirft, gibt einen. Wer ihn verpasst,
## verliert nichts; das hält die Mechanik freundlich statt fordernd.
##
## Die Auswahl nimmt eine Zufallszahl als Parameter statt selbst zu würfeln.
## Nur so lässt sich die Verteilung im Testlauf durchrechnen.
class_name Ereignis
extends RefCounted

enum Art { PLASMA, QUANTEN, SCHUB }

## Kürzester und längster Abstand zwischen zwei Funden, in Sekunden.
const ABSTAND_MIN := 180.0
const ABSTAND_MAX := 480.0

## Wie lange ein Fund sichtbar bleibt.
const SICHTBAR := 22.0

## Ein Plasmafund entspricht so vielen Sekunden Förderung.
const PLASMA_SEKUNDEN := 90.0

## Mindestertrag eines Plasmafunds, damit er auch ganz früh etwas taugt.
const PLASMA_MINDEST := 25.0

## Dauer und Stärke des Schubs aus einem Fund.
const SCHUB_DAUER := 120.0
const SCHUB_FAKTOR := 2.0

## art | gewicht | name | text
const TABELLE: Array[Dictionary] = [
    {"art": Art.PLASMA, "gewicht": 60, "name": "Plasmawolke",
     "text": "Eine treibende Wolke wird abgeschöpft."},
    {"art": Art.QUANTEN, "gewicht": 25, "name": "Quantenriss",
     "text": "Ein Riss im Raum gibt Quanten frei."},
    {"art": Art.SCHUB, "gewicht": 15, "name": "Sonnenwind",
     "text": "Die Segel stehen günstig."},
]


## Summe aller Gewichte.
static func gewicht_gesamt() -> int:
    var summe := 0
    for e in TABELLE:
        summe += int(e["gewicht"])
    return summe


## Wählt einen Fund. [param zufall] muss in [0, 1) liegen.
static func waehle(zufall: float) -> Dictionary:
    var ziel := clampf(zufall, 0.0, 0.999999) * float(gewicht_gesamt())
    var lauf := 0.0
    for e in TABELLE:
        lauf += float(e["gewicht"])
        if ziel < lauf:
            return e
    return TABELLE[TABELLE.size() - 1]


## Abstand bis zum nächsten Fund. [param zufall] muss in [0, 1) liegen.
static func abstand(zufall: float) -> float:
    return ABSTAND_MIN + clampf(zufall, 0.0, 1.0) * (ABSTAND_MAX - ABSTAND_MIN)


## Plasmaertrag eines Funds bei der aktuellen Förderung.
static func plasma_belohnung(rate: float) -> float:
    return maxf(rate * PLASMA_SEKUNDEN, PLASMA_MINDEST)


## Quantenertrag eines Funds. [param zufall] muss in [0, 1) liegen.
static func quanten_belohnung(zufall: float) -> int:
    return 1 + int(clampf(zufall, 0.0, 0.999999) * 3.0)
