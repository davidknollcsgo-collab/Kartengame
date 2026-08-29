class_name Raeuber
extends RefCounted

## Ein Tier im Schlund.
##
## Eigene Datei mit `class_name`, damit `wache.gd` (fuehrt sie) und
## `schwarm.gd` (zeichnet sie) denselben Typ sehen. Als verschachtelte Klasse
## kam beim Zeichnen nur `Variant` an, und jeder Feldzugriff verlor seinen Typ.
##
## Bewusst nur Daten, kein Verhalten: wohin das Tier sinkt, rechnet
## `Schlund.bahn()` - und zwar fuer Spiel und Pruefer dieselbe Funktion.

var art: int = 0

## Sekunden ab Wellenbeginn, zu denen das Tier eintritt.
var eintritt: float = 0.0
var start_x: float = 0.0

## Versatz des Schlaengelns, damit nicht alle im Gleichschritt schwimmen.
var phase: float = 0.0

var leben: float = 0.0
var leben_voll: float = 1.0
var lebendig: bool = true

## Sekunden seit dem Eintritt. Negativ, solange das Tier noch nicht da ist.
var alter: float = 0.0

var ort := Vector2.ZERO
var richtung := Vector2.DOWN

## 0 bis 1: wie frisch der letzte Treffer ist. Steuert nur die Anzeige.
var hitze: float = 0.0

## Restsekunden Nachglut - die Brutlinie, bei der Treffer weiterbrennen.
## Anders als `hitze` macht das echten Schaden.
var glut: float = 0.0

## Frueherere Orte auf der eigenen Bahn - fuer den Leib der Grabnatter.
var rueckweg: Array[Vector2] = []


func anteil() -> float:
    return clampf(leben / maxf(0.001, leben_voll), 0.0, 1.0)


func verletzt() -> bool:
    return leben < leben_voll - 0.01
