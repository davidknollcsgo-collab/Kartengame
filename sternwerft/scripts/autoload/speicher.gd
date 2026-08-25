## Lesen und Schreiben des Spielstands auf Platte.
##
## Bewusst zustandslos und ohne Bezug auf [code]Spielstand[/code]: so laesst
## sich das Speichern im headless Testlauf gegen echte Dateien pruefen.
##
## Die Verschluesselung haelt Gelegenheits-Editoren ab, nicht mehr. Der
## Schluessel steckt im Programm und ist mit etwas Aufwand auslesbar. Alles,
## wo Betrug wirklich weh taete - Kaeufe, Bestenlisten - gehoert deshalb
## serverseitig geprueft und niemals hierher.
class_name Speicher
extends RefCounted

const PFAD := "user://sternwerft.sav"

## Passphrase der Dateiverschluesselung. Siehe Klassenkommentar zur Reichweite.
const SCHLUESSEL := "sternwerft-orbitalwerft-2026"


## Schreibt [param daten] als verschluesseltes JSON. Gibt Erfolg zurueck.
##
## Erst in eine Nebendatei schreiben und dann umbenennen: wird das Spiel
## mitten im Schreiben abgewuergt - auf Android jederzeit moeglich - bleibt
## sonst ein halber Spielstand zurueck und der Fortschritt ist weg.
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
    if verz.rename(vorlaeufig, pfad) != OK:
        push_warning("Spielstand konnte nicht ersetzt werden.")
        return false
    return true


## Liest den Spielstand. Bei fehlender, beschaedigter oder fremder Datei
## kommt ein leeres Dictionary zurueck - der Aufrufer faellt dann auf die
## Standardwerte, statt dass das Spiel gar nicht erst startet.
static func lies(pfad: String = PFAD) -> Dictionary:
    if not FileAccess.file_exists(pfad):
        return {}
    var datei := FileAccess.open_encrypted_with_pass(
        pfad, FileAccess.READ, SCHLUESSEL)
    if datei == null:
        # Falscher Schluessel oder beschaedigter Kopf.
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


## Entfernt den Spielstand samt etwaiger Nebendatei.
static func loesche(pfad: String = PFAD) -> void:
    for p in [pfad, pfad + ".neu"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(p)
