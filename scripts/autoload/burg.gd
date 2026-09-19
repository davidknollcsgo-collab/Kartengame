extends Node

## **Der Spielstand, einmal im Spiel.**
##
## Gesichert wird bei jeder Änderung, die etwas wert ist - ein Spielstand,
## der nur beim sauberen Beenden geschrieben wird, ist auf einem Telefon
## kein Spielstand: dort wird nicht beendet, dort wird weggewischt.

const PFAD := "user://zehntausend.json"

var stand := BurgStand.new()


func _ready() -> void:
    lade()


func lade() -> void:
    stand = BurgStand.new()
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


func trage_ein(zeit: float, sold: int, erschlagen: int,
        warlord: bool) -> void:
    stand.laeufe += 1
    stand.sold += sold
    stand.beste_zeit = maxf(stand.beste_zeit, zeit)
    stand.meiste_erschlagen = maxi(stand.meiste_erschlagen, erschlagen)
    if warlord:
        stand.warlord_gefallen = true
    sichere()


func baue(b: int) -> bool:
    if not stand.baue(b):
        return false
    sichere()
    return true
