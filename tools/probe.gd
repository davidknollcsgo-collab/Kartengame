extends SceneTree

## **Die untere Schranke.**
##
##     godot --headless --path . --script tools/probe.gd
##     godot --headless --path . --script tools/probe.gd -- --held 1 --stufen 8
##
## Spielt ganze Laeufe mit `Daumen` durch - demselben Daumen, den auch der
## Schuss benutzt. Er kann nur kiten und Sold mitnehmen; kein Timing, kein
## Ausnutzen von Reichweiten, kein Vorhalten. Alles, was ein Mensch
## zusaetzlich kann, geht als Reserve in das Ergebnis ein.
##
## **Eine Zeile hier ist ein Wurf und kein Befund.** Jede Zelle ist *ein*
## Lauf mit *einer* Saat, und dieses Genre streut enorm - gemessen im
## September 2026, derselbe Stand:
##
##     Archer    Burgstufe  0   haelt 10:09
##     Archer    Burgstufe 14   faellt nach 8:56
##     Spearman  Burgstufe  0   haelt 10:09
##     Spearman  Burgstufe 14   faellt nach 4:52
##
## Jede Zelle hat ihre eigene Saat, und die Aufstiegsfolge haengt an ihr. Ob
## die Burg traegt, fragt man deshalb gepaart ueber viele Saaten - nicht an
## einer Tabelle, in der jede Zeile einmal gewuerfelt hat.
##
## **Deshalb faellt das Werkzeug nicht ueber Balance.** Bis dahin brach es
## mit Exitcode 1 ab, sobald *ein* Lauf fiel - waehrend der CI-Schritt, der
## es aufruft, seit seinem ersten Tag das Gegenteil zusagte: *er faellt nicht
## ueber Balance, er faellt darueber, dass ein voller Lauf ueberhaupt
## durchrechnet*. Bemerkt hat das niemand, weil der Schritt hinter den Tests
## steht und die Tests seit dem ersten Commit von TEN THOUSAND rot waren;
## er ist in CI kein einziges Mal gelaufen. Als sie gruen wurden, fielen hier
## 5 von 12 Laeufen, ohne Ordnung nach Burgstufe.
##
## Die Balance-Schranken stehen in `tests/run_tests.gd`, ueber **acht Saaten**
## je Held und mit benannter Quote. Hier bleibt die Zusage des CI-Schritts:
## jeder Lauf rechnet bis zu seinem Ende - Tod, Warlord oder zehn Minuten -,
## und zwar mit Zahlen, die Zahlen sind. Ein Laufzeitfehler in `schritt()`
## bricht in einem `--script`-Lauf nur den Aufruf ab und nicht das Programm;
## dann steht die Uhr, und genau daran erkennt man ihn hier. Die Zahlen stehen
## im Protokoll, wenn jemand eine Aenderung nachschlagen will.

const TAKT := 1.0 / 60.0


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var nur_held := -1
    var stufe := -1
    for i in args.size():
        if args[i] == "--held" and i + 1 < args.size():
            nur_held = int(args[i + 1])
        if args[i] == "--stufen" and i + 1 < args.size():
            stufe = int(args[i + 1])

    print("Held        | Burgstufe | haelt    | erschlagen | Stufe | Waffen")
    var gefallen := 0
    var gesamt := 0
    var haengt := 0
    for held in Helden.NAMEN.size():
        if nur_held >= 0 and held != nur_held:
            continue
        for s in ([stufe] if stufe >= 0 else [0, 6, 14]):
            var e := spiele(held, s, 7000 + held * 13 + s)
            gesamt += 1
            var zeit: float = e["zeit"]
            var heil: bool = zeit >= Andrang.LAUF_SEKUNDEN - 1.0 or bool(e["warlord"])
            if not heil:
                gefallen += 1
            if not bool(e["zu_ende"]):
                haengt += 1
            print("%-11s | %9d | %s %3d:%02d | %10d | %5d | %s" % [
                Helden.name_von(held), s, " " if heil else "!",
                int(zeit) / 60, int(zeit) % 60,
                e["erschlagen"], e["stufe"], e["waffen"]])
    print("")
    print("%d von %d Laeufen durchgestanden, %d gefallen - je eine Saat, also"
        % [gesamt - gefallen, gesamt, gefallen])
    print("Auskunft und keine Schranke. Die Schranken stehen in tests/run_tests.gd.")
    if haengt > 0:
        print("FEHLER: %d von %d Laeufen sind nicht zu Ende gekommen - weder"
            % [haengt, gesamt])
        print("        gefallen noch durch. Die Uhr stand oder rechnete ins Leere.")
        quit(1)
        return
    quit(0)


static func spiele(held: int, burgstufe: int, saat: int) -> Dictionary:
    var stufen := {}
    for b in Halle.NAMEN.size():
        stufen[b] = burgstufe
    var s := Gefecht.baue(stufen, held, {})
    var rng := RandomNumberGenerator.new()
    rng.seed = saat
    var sicherung := int(Andrang.LAUF_SEKUNDEN / TAKT) + 600
    while not Gefecht.vorbei(s) and sicherung > 0:
        sicherung -= 1
        if s.wartet_auf_wahl:
            Gefecht.nimm(s, Daumen.waehle(s))
            continue
        Gefecht.schritt(s, TAKT, Daumen.richtung(s), rng)
    var liste := ""
    for w in s.waffen.keys():
        liste += "%s %d  " % [Waffen.name_von(w), s.waffe_stufe(w)]
    return {"zeit": s.zeit, "erschlagen": s.erschlagen, "stufe": s.stufe,
        "waffen": liste, "warlord": s.warlord_gefallen, "leben": s.leben,
        "zu_ende": is_finite(s.zeit) and is_finite(s.leben)
            and (Gefecht.vorbei(s) or s.zeit >= Andrang.LAUF_SEKUNDEN)}
