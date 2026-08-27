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


static func schreibe(stand: KolonieStand, pfad := PFAD) -> bool:
    var datei := FileAccess.open_encrypted_with_pass(pfad, FileAccess.WRITE, SCHLUESSEL)
    if datei == null:
        push_warning("Spielstand nicht schreibbar: %s" % error_string(FileAccess.get_open_error()))
        return false
    datei.store_string(JSON.stringify(stand.zu_wort()))
    datei.close()
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
