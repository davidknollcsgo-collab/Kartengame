## Stammdaten der Ausbauten, die mit Quanten bezahlt werden.
##
## Drei bewusst unterschiedliche Arten von Kauf, damit die Premiumwährung nicht
## nur eine Zahl ist:
## [br]· [b]Schub[/b] wirkt kurz und ist beliebig oft kaufbar
## [br]· [b]Langzeitspeicher[/b] hat feste Stufen mit steigendem Preis
## [br]· [b]Orbital-Verstärker[/b] gibt es genau einmal
##
## Wie [Modul] eine reine Tabelle: Balancing ändert man hier und nirgends sonst.
class_name Ausbau
extends RefCounted

# --- Schub ------------------------------------------------------------------

const SCHUB_KOSTEN := 3
const SCHUB_DAUER := 15.0 * 60.0
const SCHUB_FAKTOR := 3.0

# --- Langzeitspeicher -------------------------------------------------------

## Offline-Grenze je Ausbaustufe. Stufe 0 ist der Grundzustand.
const SPEICHER_GRENZEN: PackedFloat32Array = [
    4.0 * 3600.0, 8.0 * 3600.0, 16.0 * 3600.0, 24.0 * 3600.0,
]

## Preis für den Sprung von Stufe i auf i+1.
const SPEICHER_KOSTEN: PackedInt32Array = [10, 25, 50]

## Höchste erreichbare Stufe.
const SPEICHER_MAX := 3

# --- Orbital-Verstärker -----------------------------------------------------

const VERSTAERKER_KOSTEN := 100
const VERSTAERKER_FAKTOR := 2.0


## Offline-Grenze für eine Speicherstufe, in Sekunden.
static func offline_grenze(stufe: int) -> float:
    return SPEICHER_GRENZEN[clampi(stufe, 0, SPEICHER_MAX)]


## Preis der nächsten Speicherstufe; 0 bedeutet voll ausgebaut.
static func speicher_preis(stufe: int) -> int:
    if stufe >= SPEICHER_MAX:
        return 0
    return SPEICHER_KOSTEN[stufe]


static func speicher_voll(stufe: int) -> bool:
    return stufe >= SPEICHER_MAX
