extends Node

## Haelt den Koloniestand und sichert ihn.
##
## Der einzige Autoload des Projekts. Alles hier ist Verwaltung - die Regeln
## stehen in `KolonieStand` und `Kammern`, damit sie ohne laufendes Spiel
## pruefbar bleiben.

## Wie oft von selbst gesichert wird. Haeufiger waere auf einem Telefon
## verschwendete Schreiblast, seltener verliert bei einem Absturz zu viel.
const SICHERN_ALLE := 20.0

signal bau_fertig(kammer: int)
signal stand_geaendert

var stand: KolonieStand
var _bis_zum_sichern := SICHERN_ALLE


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    stand = Speicher.lies()
    pruefe_tag()


func _process(delta: float) -> void:
    var jetzt := Time.get_unix_time_from_system()

    if stand.baut() and stand.restzeit(jetzt) <= 0.0:
        var kammer := stand.hole_bau_ab(jetzt)
        if kammer >= 0:
            bau_fertig.emit(kammer)
            stand_geaendert.emit()
            sichere()

    _bis_zum_sichern -= delta
    if _bis_zum_sichern <= 0.0:
        _bis_zum_sichern = SICHERN_ALLE
        sichere()


func _notification(was: int) -> void:
    # Auf dem Telefon ist das der einzige verlaessliche Zeitpunkt: eine App,
    # die in den Hintergrund geht, wird oft nicht mehr gefragt, bevor sie
    # beendet wird.
    if was == NOTIFICATION_WM_CLOSE_REQUEST \
            or was == NOTIFICATION_APPLICATION_PAUSED \
            or was == NOTIFICATION_WM_GO_BACK_REQUEST:
        sichere()


func sichere() -> void:
    if stand != null:
        Speicher.schreibe(stand)


## Rechnet die Abwesenheit ab. Gibt zurueck, was dabei herauskam.
func begruesse() -> int:
    var ertrag := stand.ernte_offline(Time.get_unix_time_from_system())
    if ertrag > 0:
        stand_geaendert.emit()
        sichere()
    return ertrag


## Prueft den Tageswechsel und sichert, wenn einer stattfand.
func pruefe_tag() -> bool:
    if stand == null:
        return false
    if not stand.pruefe_tag():
        return false
    stand_geaendert.emit()
    sichere()
    return true


func melde_ziel(index: int, menge := 1) -> void:
    stand.melde_ziel(index, menge)


func aendere(betrag: int) -> void:
    stand.naehrstoffe = maxi(0, stand.naehrstoffe + betrag)
    stand_geaendert.emit()


func merke_welle(nummer: int) -> void:
    if nummer > stand.hoechste_welle:
        stand.hoechste_welle = clampi(nummer, 1, Graben.WELLEN_GESAMT)
        stand_geaendert.emit()
        sichere()


func von_vorn() -> void:
    stand = KolonieStand.new()
    stand.zuletzt_gesehen = Time.get_unix_time_from_system()
    stand_geaendert.emit()
    sichere()
