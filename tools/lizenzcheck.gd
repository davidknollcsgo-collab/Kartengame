extends SceneTree

## **Der Unterschied zwischen „wir haben nichts kopiert" und „wir koennen
## beweisen, dass wir nichts kopiert haben".**
##
##     godot --headless --path . --script tools/lizenzcheck.gd
##
## Bei einer Copyright-Beschwerde gegen eine Ladenanwendung zaehlt nur das
## Zweite. Dieses Werkzeug geht das Projekt durch und verlangt fuer **jede**
## Datei, die kein selbst geschriebener Quelltext ist, einen Eintrag in
## `ASSETS.md`. Es prueft nicht, ob der Eintrag stimmt - das kann kein
## Programm -, sondern dass keiner fehlt.
##
## Der eigentliche Wert liegt im Zeitpunkt: er faellt auf, wenn jemand eine
## Datei hinzufuegt, und nicht Monate spaeter, wenn die App offline ist.

## Was als Quelltext gilt und deshalb keinen Eintrag braucht.
const QUELLTEXT: PackedStringArray = [
    "gd", "tscn", "godot", "uid", "md", "cfg", "sh", "py", "yml", "yaml",
    "gitignore", "gdshader", "json", "txt", "import", "mjs", "js",
]

## Ordner, die nicht zum Projekt gehoeren - und **warum**, denn eine
## Ausnahmeliste ohne Begruendung waechst, bis der Pruefer nichts mehr
## prueft:
##
##   * `node_modules` ist eine Entwicklungsabhaengigkeit und wird nie
##     ausgeliefert. Ihre Lizenzen stehen in `THIRD_PARTY_LICENSES.md`.
##   * `docs` ist der **gebaute** Web-Export. Er enthaelt nichts, was nicht
##     aus diesem Projekt kaeme; ihn zu registrieren hiesse, das Ergebnis
##     als seine eigene Herkunft zu fuehren.
##   * `build` und `.godot` sind Zwischenstaende.
const AUSSEN: PackedStringArray = [
    ".git", ".github", ".godot", "build", "docs", "node_modules",
]


func _init() -> void:
    var register := ""
    var datei := FileAccess.open("res://ASSETS.md", FileAccess.READ)
    if datei == null:
        print("ASSETS.md fehlt - ohne Register gibt es keinen Nachweis.")
        quit(1)
        return
    register = datei.get_as_text()
    datei.close()

    var fehlend := PackedStringArray()
    var geprueft := 0
    for pfad in _alle_dateien("res://"):
        var endung := pfad.get_extension().to_lower()
        if QUELLTEXT.has(endung):
            continue
        geprueft += 1
        # Der Dateiname genuegt: das Register fuehrt Pfade, aber ein
        # verschobener Eintrag ist kein fehlender.
        if not register.contains(pfad.get_file()):
            fehlend.append(pfad)

    print("%d Dateien ohne Quelltext-Endung geprueft." % geprueft)
    if fehlend.is_empty():
        print("Jede davon steht in ASSETS.md.")
        quit(0)
        return
    for p in fehlend:
        print("  FEHLT im Register: %s" % p)
    quit(1)


func _alle_dateien(wurzel: String) -> PackedStringArray:
    var liste := PackedStringArray()
    var d := DirAccess.open(wurzel)
    if d == null:
        return liste
    d.list_dir_begin()
    var name := d.get_next()
    while name != "":
        if name.begins_with("."):
            name = d.get_next()
            continue
        var voll := wurzel.path_join(name)
        if d.current_is_dir():
            if not AUSSEN.has(name):
                liste.append_array(_alle_dateien(voll))
        else:
            liste.append(voll)
        name = d.get_next()
    d.list_dir_end()
    return liste
