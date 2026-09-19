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
## **Deshalb ist eine rote Zahl hier eine Aussage und eine gruene keine
## Garantie.** Haelt der Daumen die zehn Minuten nicht, haelt sie kaum
## jemand; haelt er sie, heisst das nur, dass es moeglich ist.

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
            print("%-11s | %9d | %s %3d:%02d | %10d | %5d | %s" % [
                Helden.name_von(held), s, " " if heil else "!",
                int(zeit) / 60, int(zeit) % 60,
                e["erschlagen"], e["stufe"], e["waffen"]])
    print("")
    if gefallen == 0:
        print("Alle %d Laeufe durchgestanden." % gesamt)
        quit(0)
        return
    print("FEHLER: %d von %d Laeufen fallen - ein Daumen, der nur kitet, muss"
        % [gefallen, gesamt])
    print("        die zehn Minuten schaffen, sonst schafft sie kaum jemand.")
    quit(1)


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
        "waffen": liste, "warlord": s.warlord_gefallen, "leben": s.leben}
