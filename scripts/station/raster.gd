## Geometrie des Stationslayouts - ohne Szene, ohne Autoload.
##
## Bewusst von [Station] getrennt: der Stationsknoten haengt am Autoload
## [code]Spielstand[/code] und laesst sich deshalb im headless Testlauf nicht
## laden. Die reine Geometrie hier schon. Gleiches Prinzip wie bei
## [Oekonomie]: rechnende Teile bleiben frei von Szenenabhaengigkeiten.
class_name Raster
extends RefCounted

## Waagerechter Abstand der Spalten von der Mitte.
##
## Weit genug, dass der Rumpf des Mutterschiffs dazwischen Platz hat, und eng
## genug, dass beide Spalten im Hochformat ohne Schieben sichtbar bleiben.
const SPALTE_X := 238.0

## Senkrechte Mittelpunkte der vier Reihen.
##
## Weit auseinander gezogen: ein Handybildschirm ist hoch, und eine Station,
## die nur das mittlere Drittel fuellt, wirkt verloren.
const REIHEN_Y: PackedFloat32Array = [-400.0, -135.0, 135.0, 400.0]


## Platz einer Baugruppe im Stationsraster.
static func modul_position(index: int) -> Vector2:
    # Erste vier links, letzte vier rechts - die Reihenfolge folgt der
    # Freischaltung, damit der Blick beim Fortschritt nach unten wandert.
    var links := index < 4
    return Vector2(-SPALTE_X if links else SPALTE_X, REIHEN_Y[index % 4])


## Rechteck einer Baugruppe, ohne dass sie gebaut sein muss.
static func modul_flaeche(index: int) -> Rect2:
    var mitte := modul_position(index)
    return Rect2(mitte - ModulKnoten.GROESSE * 0.5, ModulKnoten.GROESSE)
