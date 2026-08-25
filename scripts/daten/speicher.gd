## Lesen und Schreiben des Spielstands.
##
## Zustandslos und ohne Bezug auf den Autoload, damit sich das Speichern im
## headless Testlauf gegen echte Dateien prüfen lässt.
##
## Die Verschlüsselung hält Gelegenheits-Editoren ab, nicht mehr. Der Schlüssel
## steckt im Programm und ist auslesbar. Alles, wo Betrug wirklich weh täte -
## Käufe, Bestenlisten - gehört serverseitig geprüft und niemals hierher.
class_name Speicher
extends RefCounted

const PFAD := "user://hypha.sav"
const SCHLUESSEL := "hypha-myzel-2026"


## Schreibt [param daten] als verschlüsseltes JSON.
##
## Erst in eine Nebendatei, dann umbenennen: wird das Spiel mitten im Schreiben
## abgewürgt - auf Android jederzeit möglich - bleibt sonst ein halber Stand
## zurück und der Fortschritt ist weg.
static func schreibe(daten: Dictionary, pfad: String = PFAD) -> bool:
    var vorlaeufig := pfad + ".neu"
    var datei := FileAccess.open_encrypted_with_pass(
        vorlaeufig, FileAccess.WRITE, SCHLUESSEL)
    if datei == null:
        push_warning("Spielstand nicht schreibbar: %s" % FileAccess.get_open_error())
        return false
    datei.store_string(JSON.stringify(daten))
    datei.close()

    var verz := DirAccess.open(pfad.get_base_dir())
    if verz == null:
        return false
    return verz.rename(vorlaeufig, pfad) == OK


## Liest den Spielstand. Bei fehlender oder beschädigter Datei ein leeres
## Dictionary - der Aufrufer fällt dann auf die Standardwerte, statt dass das
## Spiel gar nicht erst startet.
static func lies(pfad: String = PFAD) -> Dictionary:
    if not FileAccess.file_exists(pfad):
        return {}
    var datei := FileAccess.open_encrypted_with_pass(
        pfad, FileAccess.READ, SCHLUESSEL)
    if datei == null:
        push_warning("Spielstand nicht lesbar - beginne von vorn.")
        return {}
    var text := datei.get_as_text()
    datei.close()

    var ergebnis: Variant = JSON.parse_string(text)
    if typeof(ergebnis) != TYPE_DICTIONARY:
        push_warning("Spielstand ist kein gueltiges JSON - beginne von vorn.")
        return {}
    return ergebnis


static func existiert(pfad: String = PFAD) -> bool:
    return FileAccess.file_exists(pfad)


static func loesche(pfad: String = PFAD) -> void:
    for p in [pfad, pfad + ".neu"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(p)
