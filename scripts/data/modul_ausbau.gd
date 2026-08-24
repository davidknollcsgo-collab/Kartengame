## Ausbaustufen je Baugruppe, bezahlt mit Plasma.
##
## Der Grund für dieses System: ohne es kauft man immer nur weitere Stück, und
## die einzige Entscheidung ist "welche Art als nächstes". Mit Ausbaustufen
## steht die Frage im Raum, ob das nächste Plasma in Menge oder in Stärke
## fließt - und weil eine Stufe *alle* Exemplare einer Art verdoppelt, lohnt
## sie sich umso mehr, je mehr davon schon stehen.
class_name ModulAusbau
extends RefCounted

## Höchste erreichbare Stufe. Bei zwölf steht der Faktor bei 4096 - genug für
## einen langen Lauf, ohne dass die Zahlen unbedienbar werden.
const MAX_STUFE := 12

## Preis der ersten Stufe, als Vielfaches der Basiskosten der Baugruppe.
const ERSTE_STUFE := 40.0

## Preissteigerung je weiterer Stufe.
const STEIGERUNG := 7.5


## Preis für den Sprung von [param stufe] auf die nächste.
## Gibt 0 zurück, wenn bereits voll ausgebaut.
static func kosten(index: int, stufe: int) -> float:
    if stufe >= MAX_STUFE:
        return 0.0
    return Modul.basiskosten(index) * ERSTE_STUFE * pow(STEIGERUNG, stufe)


## Förderungsfaktor, den eine Ausbaustufe bewirkt.
static func faktor(stufe: int) -> float:
    return pow(2.0, maxi(stufe, 0))


static func voll(stufe: int) -> bool:
    return stufe >= MAX_STUFE
