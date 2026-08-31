extends SceneTree

## Prueft, dass jede Datei im Projekt eine belegte Herkunft hat.
##
##     godot --headless --path . --script tools/lizenzcheck.gd
##
## Der Plan sagt es so: der Unterschied zwischen "wir haben nichts kopiert" und
## "wir koennen beweisen, dass wir nichts kopiert haben" ist dieses Werkzeug.
## Bei einer Copyright-Beschwerde gegen eine Play-Store-App zaehlt nur das
## Zweite - bis dahin ist die App offline.
##
## Geprueft wird: jede Datei, die kein selbst geschriebener Quelltext ist, muss
## in `ASSETS.md` stehen. Exitcode 1, sobald eine fehlt.

## Was als eigener Quelltext gilt und deshalb keinen Eintrag braucht.
const QUELLTEXT: PackedStringArray = [
    ".gd", ".gdshader", ".tscn", ".tres", ".godot", ".cfg", ".md", ".py",
    ".yml", ".yaml", ".json", ".gitignore", ".uid", ".txt", ".mjs", ".js",
    # Ein Schalenskript ist Quelltext wie jedes andere. Es fehlte hier nur,
    # weil es bis `tools/ladenbilder.sh` keines gab - und der Pruefer hat das
    # zu Recht gemeldet, statt still durchzuwinken.
    ".sh",
    # `.import` erzeugt Godot selbst aus der Datei daneben. Sie traegt keinen
    # fremden Inhalt, und der Eintrag der Datei daneben deckt sie mit ab.
    ".import",
]

## Verzeichnisse, die nicht zum ausgelieferten Projekt gehoeren - Ergebnisse
## des Baus und Entwicklungswerkzeug.
const AUSSEN: PackedStringArray = [
    "res://.git", "res://.godot", "res://docs", "res://build", "res://android",
]

## Verzeichnisnamen, die auf jeder Ebene uebersprungen werden. `node_modules`
## steht hier, weil es zum Browsertest gehoert und nie mit ausgeliefert wird -
## an der Wurzel zu suchen reichte nicht, es liegt unter tools/browsertest/.
const AUSSEN_NAMEN: PackedStringArray = ["node_modules"]

## Lizenztexte muessen mitgeliefert werden, stehen aber als Text neben der
## Datei, auf die sie sich beziehen - der Eintrag dort deckt beide ab.
const LIZENZDATEIEN: PackedStringArray = ["OFL.txt", "LICENSE", "LICENSE.txt"]


func _init() -> void:
    var register := FileAccess.get_file_as_string("res://ASSETS.md")
    if register.is_empty():
        print("FEHLER: ASSETS.md fehlt oder ist leer.")
        quit(1)
        return

    var gefunden := PackedStringArray()
    _sammle("res://", gefunden)

    var fehlend := PackedStringArray()
    for pfad in gefunden:
        var name := pfad.get_file()
        if LIZENZDATEIEN.has(name):
            continue
        # Der Eintrag darf den vollen Pfad oder den Dateinamen nennen.
        var kurz := pfad.trim_prefix("res://")
        if register.contains(kurz) or register.contains(name):
            continue
        fehlend.append(kurz)

    print("Lizenzcheck: %d Dateien geprueft, die kein Quelltext sind"
        % gefunden.size())
    for pfad in gefunden:
        print("  " + pfad.trim_prefix("res://"))

    if fehlend.is_empty():
        print("")
        print("Alle Herkuenfte belegt.")
        quit(0)
        return

    print("")
    for pfad in fehlend:
        print("FEHLER: %s steht nicht in ASSETS.md" % pfad)
    print("")
    print("Jede Datei, die kein selbst geschriebener Quelltext ist, braucht")
    print("dort einen Eintrag mit Herkunft, Autor, Lizenz und Datum.")
    quit(1)


func _sammle(verzeichnis: String, hinein: PackedStringArray) -> void:
    for aussen in AUSSEN:
        if verzeichnis.begins_with(aussen):
            return

    var d := DirAccess.open(verzeichnis)
    if d == null:
        return

    d.list_dir_begin()
    var name := d.get_next()
    while name != "":
        if name.begins_with("."):
            name = d.get_next()
            continue
        var pfad := verzeichnis.path_join(name)
        if d.current_is_dir():
            if not AUSSEN_NAMEN.has(name):
                _sammle(pfad, hinein)
        elif not QUELLTEXT.has("." + pfad.get_extension()):
            hinein.append(pfad)
        name = d.get_next()
    d.list_dir_end()
