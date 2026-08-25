## Lösbarkeitsprüfung: godot --headless --path . --script tools/loesbarkeit.gd
##
## Kein Test, sondern eine Messung. Spielt jede Kammer mit [Sucher] durch und
## meldet, ob sie mit dem vorgesehenen Sporenvorrat zu räumen ist.
##
## Der Grund: die Wurzelspur wird zur Wand. Ein Spieler kann sich damit den Weg
## zu den letzten Knoten verbauen - die riskanteste Annahme im ganzen Entwurf.
extends SceneTree

const BIS := 30


func _init() -> void:
    print("── Lösbarkeit Biom 1 ──────────────────────────")
    var ungeloest: Array[int] = []
    var summe := 0
    var geloest := 0

    for nummer in range(1, BIS + 1):
        var e := Sucher.spiele(nummer)
        print("   %s Kammer %-3d  %2d Knoten  %2d Sporen  →  %d übrig, %d Schüsse"
            % ["✓" if e["geschafft"] else "✗", nummer, e["knoten"], e["sporen"],
               e["uebrig"], e["schuesse"]])
        if e["geschafft"]:
            geloest += 1
            summe += int(e["uebrig"])
        else:
            ungeloest.append(nummer)

    print("───────────────────────────────────────────────")
    print("   %d von %d Kammern lösbar" % [geloest, BIS])
    if geloest > 0:
        print("   Durchschnittlich %.1f Sporen übrig" % (float(summe) / float(geloest)))
    if not ungeloest.is_empty():
        printerr("   NICHT lösbar: %s" % str(ungeloest))
    quit(0 if ungeloest.is_empty() else 1)
