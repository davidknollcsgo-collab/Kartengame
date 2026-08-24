## Stammdaten der acht Stationsmodule.
##
## Bewusst als eine zentrale Tabelle gehalten: Balancing aendert man hier und
## nirgends sonst. Jede Stufe kostet grob das Zehnfache der vorherigen und
## produziert grob das Achtfache - die klassische Idle-Kurve, bei der jedes
## neue Modul erst unerreichbar wirkt und kurz darauf selbstverstaendlich ist.
class_name Modul
extends RefCounted

## Kostenwachstum je gekauftem Exemplar. 1.12 ist bewusst milder als die in
## Idle-Spielen uebliche 1.15 - der Aufstieg soll sich nicht zaeh anfuehlen.
const WACHSTUM := 1.12

## Stueckzahlen, bei denen sich die Produktion des Moduls verdoppelt.
const MEILENSTEINE: PackedInt32Array = [10, 25, 50, 100, 200]

## name: Anzeigename | basis: Kosten des ersten Exemplars | rate: Credits/s pro Stueck
const TABELLE: Array[Dictionary] = [
    {"name": "Solarsegel",     "basis": 15.0,        "rate": 0.1},
    {"name": "Bergbaudrohne",  "basis": 100.0,       "rate": 1.0},
    {"name": "Schmelzofen",    "basis": 1100.0,      "rate": 8.0},
    {"name": "Hydroponik",     "basis": 12000.0,     "rate": 47.0},
    {"name": "Werkstatt",      "basis": 130000.0,    "rate": 260.0},
    {"name": "Fusionsreaktor", "basis": 1400000.0,   "rate": 1400.0},
    {"name": "Frachtdock",     "basis": 20000000.0,  "rate": 7800.0},
    {"name": "Forschungslabor","basis": 330000000.0, "rate": 44000.0},
]

## Anzahl der Modultypen.
const ANZAHL := 8


static func name_von(index: int) -> String:
    return TABELLE[index]["name"]


static func basiskosten(index: int) -> float:
    return TABELLE[index]["basis"]


static func basisrate(index: int) -> float:
    return TABELLE[index]["rate"]
