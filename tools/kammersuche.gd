## Sucht für jede Kammer einen Aufbau, der lösbar ist und zur Kurve passt.
##
##   godot --headless --path . --script tools/kammersuche.gd
##
## Gibt eine fertige STREUUNG-Tabelle aus, die in kammer_daten.gd gehört.
##
## Warum vorab suchen und nicht zur Laufzeit prüfen: die Prüfung braucht
## hunderte Flugberechnungen je Schuss. Auf einem Handy wäre das beim Laden
## einer Kammer sekundenlang spürbar. Einmal hier gerechnet, kostet es im Spiel
## nichts.
extends SceneTree

const BIS := 30

## Wie viele Streuwerte je Kammer geprüft werden, bevor aufgegeben wird.
const VERSUCHE := 120



## Wie viele Sporen übrig bleiben sollen - die Schwierigkeitskurve.
##
## Am Anfang großzügig, damit die ersten Kammern gelingen und nicht abschrecken.
## Später knapper, aber nie auf null: eine Kammer, die nur mit dem letzten
## Schuss aufgeht, fühlt sich nach Glück an, nicht nach Können.
static func _ziel_uebrig(nummer: int) -> Vector2i:
    if nummer <= 3:
        return Vector2i(3, 6)
    if nummer <= 10:
        return Vector2i(2, 5)
    if nummer <= 20:
        return Vector2i(1, 4)
    return Vector2i(1, 3)


func _init() -> void:
    print("── Kammersuche ────────────────────────────────")
    var gefunden := PackedInt32Array()
    var fehlend: Array[int] = []

    for nummer in range(1, BIS + 1):
        var ziel := _ziel_uebrig(nummer)
        var treffer := -1
        var bester_versatz := 0
        var bestes_uebrig := -1

        for versatz in VERSUCHE:
            var uebrig := _spiele(nummer, versatz)
            if uebrig < 0:
                continue
            # Bester Notnagel, falls kein Wert ins Zielband fällt.
            if uebrig > bestes_uebrig:
                bestes_uebrig = uebrig
                bester_versatz = versatz
            if uebrig >= ziel.x and uebrig <= ziel.y:
                treffer = versatz
                break

        if treffer >= 0:
            gefunden.append(treffer)
            print("   Kammer %-3d Streuung %-4d im Zielband %d..%d"
                % [nummer, treffer, ziel.x, ziel.y])
        elif bestes_uebrig >= 0:
            gefunden.append(bester_versatz)
            print("   Kammer %-3d Streuung %-4d nur lösbar, %d übrig (Ziel %d..%d)"
                % [nummer, bester_versatz, bestes_uebrig, ziel.x, ziel.y])
        else:
            gefunden.append(0)
            fehlend.append(nummer)
            print("   Kammer %-3d KEIN lösbarer Aufbau gefunden" % nummer)

    print("───────────────────────────────────────────────")
    print("const STREUUNG: PackedInt32Array = [")
    for i in range(0, gefunden.size(), 10):
        var zeile := ""
        for k in range(i, mini(i + 10, gefunden.size())):
            zeile += "%d, " % gefunden[k]
        print("    " + zeile)
    print("]")
    if not fehlend.is_empty():
        printerr("Ohne Lösung: %s" % str(fehlend))
    quit(0)


## Spielt eine Kammer durch. Gibt die übrigen Sporen zurück, oder -1.
func _spiele(nummer: int, versatz: int) -> int:
    var e := Sucher.spiele(nummer, versatz)
    return int(e["uebrig"]) if e["geschafft"] else -1
