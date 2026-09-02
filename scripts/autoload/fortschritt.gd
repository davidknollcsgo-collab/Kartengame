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


## Ob beim Start ein Tageswechsel stattgefunden hat. Die Rueckkehrtafel
## braucht es, und `pruefe_tag()` laeuft, bevor die Wache ueberhaupt da ist.
var tag_gewechselt := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    stand = Speicher.lies()
    tag_gewechselt = pruefe_tag()
    uebernimm_einstellungen()


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


## Rechnet die Abwesenheit ab und sagt, was dabei herauskam.
##
## **Auch der fertige Bau gehoert hierher.** Er wurde bisher erst im ersten
## `_process()` eingesammelt und als Dreisekundenmeldung durchgereicht - die
## Kammer, auf die jemand einen halben Tag gewartet hat, meldete sich also
## als Toast, der vorbei war, bevor man hinsah. Wer zurueckkommt, soll in
## einem Bild sehen, was in seiner Abwesenheit geschehen ist.
func begruesse() -> Dictionary:
    var jetzt := Time.get_unix_time_from_system()
    var stunden := stand.abwesend(jetzt)
    var ertrag := stand.ernte_offline(jetzt)
    var kammer := -1
    if stand.baut() and stand.restzeit(jetzt) <= 0.0:
        kammer = stand.hole_bau_ab(jetzt)
        if kammer >= 0:
            bau_fertig.emit(kammer)
    if ertrag > 0 or kammer >= 0:
        stand_geaendert.emit()
        sichere()
    return {
        &"ertrag": ertrag, &"stunden": stunden, &"kammer": kammer,
        &"tag": tag_gewechselt,
    }


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


func setze_ziel(index: int, wert: int) -> void:
    stand.setze_ziel(index, wert)


func aendere(betrag: int) -> void:
    stand.naehrstoffe = maxi(0, stand.naehrstoffe + betrag)
    stand_geaendert.emit()


func merke_welle(nummer: int) -> void:
    if nummer > stand.hoechste_welle:
        stand.hoechste_welle = clampi(nummer, 1, Graben.TIEFSTE)
        stand_geaendert.emit()
        sichere()


func von_vorn() -> void:
    stand = KolonieStand.new()
    stand.zuletzt_gesehen = Time.get_unix_time_from_system()
    uebernimm_einstellungen()
    stand_geaendert.emit()
    sichere()


## Traegt Lautstaerke und Beben aus dem Stand in die beiden Autoloads, die
## sie tatsaechlich benutzen.
##
## Der Stand ist die eine Quelle - `Klang.laut` und `Tastsinn.an` sind nur
## das, womit gerade gearbeitet wird. Sie stehen dort und nicht hier, weil
## `klang.gd` in jedem Bild darauf schaut und ein Umweg ueber den Stand
## sechzigmal je Sekunde ein Woerterbuch abfragen wuerde.
func uebernimm_einstellungen() -> void:
    Klang.laut = stand.laut
    Tastsinn.an = stand.beben


## Der Weg zurueck: was der Spieler am Regler geaendert hat, gehoert in den
## Stand und auf die Platte. Ohne diesen Weg ueberlebte keine Einstellung
## den naechsten Start - genau das war der Fehler.
func merke_einstellungen() -> void:
    stand.laut = Klang.laut
    stand.beben = Tastsinn.an
    sichere()
