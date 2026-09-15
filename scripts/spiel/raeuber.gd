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

## Aus welcher Welle es kommt. Seit es Mutationen gibt, gehoert eine
## Eigenschaft nicht mehr der Art allein: dieselbe Grabnatter ist in Welle 63
## gepanzert und in Welle 64 nicht. Wer das Tier zeichnet oder ihm Schaden
## zufuegt, braucht deshalb beides - `Wellen.panzer_in(art, welle)`.
var welle: int = 1

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

## Wie hell das Tier gerade im Kegel steht - dieselbe Zahl, aus der auch der
## Schaden faellt. `schwarm.gd` setzt daraus das Randlicht: die dem Waechter
## zugewandte Kante wird hell, die abgewandte bleibt dunkel. Ohne das
## schwimmen flache Scherenschnitte durch das Wasser, egal wie fein sie
## gezeichnet sind.
var licht: float = 0.0

## Restsekunden Nachglut - die Brutlinie, bei der Treffer weiterbrennen.
## Anders als `hitze` macht das echten Schaden.
var glut: float = 0.0

## Von welchem Stosslicht dieses Tier schon getroffen wurde. Der Ring laeuft
## ueber mehrere Bilder nach aussen; ohne diese Marke bekaeme ein Tier, das
## langsamer sinkt als der Ring waechst, den Stoss zweimal.
var stoss_nr: int = -1

## Ob das Tier noch lauert: es liegt still, bis das Boot nah genug kommt.
##
## Nur im Rundumlauf gesetzt. Im Schlund kommt jedes Tier von oben und hat
## keinen Ort, an dem es warten koennte - dort bleibt das Feld aus.
var lauert: bool = false

## Frueherere Orte auf der eigenen Bahn - fuer den Leib der Grabnatter.
var rueckweg: Array[Vector2] = []

## Sekunden seit dem letzten abgesetzten Jungen. Nur beim Brutstock.
var brut_uhr: float = 0.0

## Ab wann dieses Tier wieder beissen darf - Sekunden ab Wellenbeginn.
##
## **Frueher lief die Sperre ueber `eintritt`, und das hatte zwei Folgen,
## die beide niemand wollte.** Nach einem Treffer stand dort
## `_wellenzeit + BISS_SPERRE`, `alter` wurde damit negativ, und die
## Bewegungsschleife ueberspringt alles mit negativem Alter: das Tier hing
## fast eine Sekunde **bewegungslos** hundertneunzig Einheiten vor dem Boot.
## Und danach sah der erste Schritt ein Tier, das eben noch nicht da war,
## und setzte es neu ein - am Feldrand, neunhundertachtzig Einheiten weg.
##
## Aus "prallt ab und kommt wieder" wurde damit "steht still und
## verschwindet". Die Sperre hat jetzt ein eigenes Feld, `eintritt` bleibt
## der Eintritt, und das Tier schwimmt die ganze Zeit.
var biss_frei: float = 0.0

## Ob das Tier schon einmal eingesetzt wurde.
##
## Der erste Schritt setzt ein Tier um das Boot herum - das darf genau
## einmal geschehen. Vorher haing das an `alter`, und jedes Mal, wenn
## `alter` aus irgendeinem Grund wieder bei null anfing, sprang das Tier
## quer ueber das Feld.
var eingetreten: bool = false

## Ob dieses Tier ein abgesetztes Junges ist.
##
## **Es zahlt dann nichts.** Kein Naehrstoff, keine Punkte - es stand in
## keiner `Wellen.auftritte()` und damit in keinem Budget. Dieselbe
## Begruendung wie bei der Funkenbluete (Zusage 18).
var aus_brut: bool = false


func anteil() -> float:
    return clampf(leben / maxf(0.001, leben_voll), 0.0, 1.0)


func verletzt() -> bool:
    return leben < leben_voll - 0.01
