class_name Speicher
extends RefCounted

## Spielstand schreiben und lesen.
##
## Verschluesselt, aber ohne Illusionen: der Schluessel steckt im Programm und
## laesst sich herausloesen. Er haelt Gelegenheitsaenderungen ab, mehr nicht.
## Der Schutz gegen unmoegliche Werte steckt deshalb nicht hier, sondern in
## `KolonieStand.aus_wort()`, wo jeder Wert geprueft wird.
##
## Reine Datenschicht: kein Szenen-, kein Autoload-Bezug, damit der Testlauf
## sie headless anfassen kann.

const PFAD := "user://nekton.stand"
const SCHLUESSEL := "nekton-graben-2026"

## Endung der Zwischendatei. Siehe `schreibe()`.
const ROHLING := ".neu"


## Schreibt den Stand - erst daneben, dann an seinen Platz.
##
## **Ein halb geschriebener Spielstand ist schlimmer als gar keiner.** Vorher
## wurde die Datei geoeffnet, ueberschrieben und geschlossen. Genau dazwischen
## darf Android eine App jederzeit abschiessen, und zwar bevorzugt dann, wenn
## sie gerade in den Hintergrund geht - also genau in dem Augenblick, in dem
## hier gesichert wird. Was liegen bleibt, ist eine abgeschnittene Datei:
## `lies()` faengt das ab und faengt von vorn an, aber der Fortschritt von
## Wochen ist weg. Bei einer Kaufversion ist das kein Fehlerbericht, sondern
## eine Rueckerstattung.
##
## Das Umbenennen einer Datei ist auf jedem gaengigen Dateisystem unteilbar:
## entweder es gab die alte Datei oder die neue, nie etwas dazwischen. Also
## erst vollstaendig daneben schreiben, dann an den richtigen Platz schieben.
static func schreibe(stand: KolonieStand, pfad := PFAD) -> bool:
    var roh := pfad + ROHLING
    var datei := FileAccess.open_encrypted_with_pass(roh, FileAccess.WRITE, SCHLUESSEL)
    if datei == null:
        push_warning("Spielstand nicht schreibbar: %s" % error_string(FileAccess.get_open_error()))
        return false
    datei.store_string(JSON.stringify(stand.zu_wort()))
    datei.close()

    # Erst jetzt ist die Zwischendatei vollstaendig. `rename_absolute`
    # ersetzt ein vorhandenes Ziel auf allen hier unterstuetzten Systemen.
    var fehler := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(roh),
        ProjectSettings.globalize_path(pfad))
    if fehler != OK:
        push_warning("Spielstand nicht umbenennbar: %s" % error_string(fehler))
        return false
    return true


## Liest den Stand. Gibt bei jedem Fehler einen frischen zurueck - ein Spiel,
## das wegen einer kaputten Datei nicht startet, ist schlimmer als eines, das
## von vorn beginnt.
static func lies(pfad := PFAD) -> KolonieStand:
    if not FileAccess.file_exists(pfad):
        return KolonieStand.new()

    var datei := FileAccess.open_encrypted_with_pass(pfad, FileAccess.READ, SCHLUESSEL)
    if datei == null:
        push_warning("Spielstand nicht lesbar, beginne neu")
        return KolonieStand.new()

    var roh := datei.get_as_text()
    datei.close()

    var wort: Variant = JSON.parse_string(roh)
    if typeof(wort) != TYPE_DICTIONARY:
        push_warning("Spielstand beschaedigt, beginne neu")
        return KolonieStand.new()

    return KolonieStand.aus_wort(wort)


static func loesche(pfad := PFAD) -> void:
    if FileAccess.file_exists(pfad):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
