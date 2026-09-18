extends Node

## **Der Spielstand, einmal im Spiel.**
##
## Autoload, damit Duell und Schule denselben Stand sehen. Gesichert wird bei
## jeder Aenderung, die etwas wert ist - ein Spielstand, der nur beim sauberen
## Beenden geschrieben wird, ist auf einem Telefon kein Spielstand: dort wird
## nicht beendet, dort wird weggewischt.

const PFAD := "user://hundert_schnitte.json"

var stand := WegStand.new()


func _ready() -> void:
    lade()


func lade() -> void:
    stand = WegStand.new()
    if not FileAccess.file_exists(PFAD):
        return
    var datei := FileAccess.open(PFAD, FileAccess.READ)
    if datei == null:
        return
    var roh: Variant = JSON.parse_string(datei.get_as_text())
    datei.close()
    if roh is Dictionary:
        stand.aus_wort(roh)


func sichere() -> void:
    var datei := FileAccess.open(PFAD, FileAccess.WRITE)
    if datei == null:
        return
    datei.store_string(JSON.stringify(stand.als_wort()))
    datei.close()


## Was eine beendete Ronde im Stand hinterlaesst.
func trage_ein(nummer: int, ehre: int, kette: int, gefaellt: int,
        gewonnen: bool) -> void:
    stand.ehre += ehre
    stand.beste_kette = maxi(stand.beste_kette, kette)
    stand.gefaellt_gesamt += gefaellt
    if gewonnen:
        stand.weiteste_ronde = maxi(stand.weiteste_ronde, nummer + 1)
    sichere()


func baue(h: int) -> bool:
    if not stand.baue(h):
        return false
    sichere()
    return true
