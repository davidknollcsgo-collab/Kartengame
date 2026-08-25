extends SceneTree

## Prueft jede Welle mit den Grundwerten durch.
##
## Der Satz aus dem Plan, den dieses Werkzeug durchsetzt: *jede Welle muss mit
## den Grundwerten ueberstehbar sein - sonst steckt jemand fest, der nicht
## bezahlt hat.* Eine Wand im Fortschritt ist in einem Spiel mit Werbung und
## Kaeufen kein Balance-Fehler, sondern ein Vertrauensbruch.
##
##     godot --headless --path . --script tools/wellenpruefer.gd
##
## Exitcode 1, sobald eine Sitzung mit den Grundwerten faellt.

## Wie weit ein Spieler unter dem Sollausbau bleiben darf. `--spielraum`
## probiert diese Leiter von oben nach unten durch und meldet je Sitzung den
## niedrigsten Stand, der noch traegt.
##
## Das ist die eigentlich interessante Zahl. Ob eine Welle *mit* Sollausbau
## faellt, sagt nur ja oder nein; wieviel Luft darunter liegt, sagt, ob die
## Kurve anzieht oder ob 60 Wellen lang nichts passiert.
const LEITER: PackedFloat32Array = [1.0, 0.85, 0.7, 0.55, 0.45, 0.35, 0.25]


func _init() -> void:
    var verstaerkung := 1.0
    var spielraum := false
    var argumente := OS.get_cmdline_user_args()
    for i in argumente.size():
        if argumente[i] == "--verstaerkung" and i + 1 < argumente.size():
            verstaerkung = float(argumente[i + 1])
        elif argumente[i] == "--spielraum":
            spielraum = true

    if spielraum:
        _spielraum()
        return

    print("Wellenpruefer - Verstaerkung %.2f gegenueber dem Sollausbau, %d Wellen"
        % [verstaerkung, Graben.WELLEN_GESAMT])
    print("")

    var gefallen := 0
    var erste_wand := 0
    var knappste := 999
    var knappste_welle := 0

    var start := 1
    while start <= Graben.WELLEN_GESAMT:
        var lauf := Simulation.sitzung(start, verstaerkung)
        var zeile := "Sitzung %2d (Welle %2d-%2d) " % [
            (start - 1) / Graben.WELLEN_JE_SITZUNG + 1,
            start, start + Graben.WELLEN_JE_SITZUNG - 1]

        var ok := true
        for e in lauf:
            zeile += "| W%2d Brut %2d/%2d durch %2d " % [
                e.welle, e.brut_nachher, Graben.BRUT_LEBEN, e.durchgelassen]
            if e.brut_nachher < knappste and e.ueberstanden:
                knappste = e.brut_nachher
                knappste_welle = e.welle
            if not e.ueberstanden:
                ok = false

        if ok:
            print("  OK   " + zeile)
        else:
            print("  FALL " + zeile)
            gefallen += 1
            if erste_wand == 0:
                erste_wand = lauf[lauf.size() - 1].welle

        start += Graben.WELLEN_JE_SITZUNG

    print("")
    if gefallen == 0:
        print("Alle %d Wellen mit Grundwerten ueberstanden." % Graben.WELLEN_GESAMT)
        print("Knappster Ausgang: Welle %d mit %d/%d Brut."
            % [knappste_welle, knappste, Graben.BRUT_LEBEN])
        quit(0)
    else:
        print("%d Sitzungen gefallen. Erste Wand bei Welle %d."
            % [gefallen, erste_wand])
        quit(1)


## Je Sitzung: wie weit darf der Ausbau zurueckliegen, bevor sie faellt?
func _spielraum() -> void:
    print("Spielraum je Sitzung - niedrigster Ausbaustand, der noch traegt")
    print("")
    var start := 1
    while start <= Graben.WELLEN_GESAMT:
        var tiefster := 0.0
        for stufe in LEITER:
            var lauf := Simulation.sitzung(start, stufe)
            var ok := lauf.size() == Graben.WELLEN_JE_SITZUNG
            for e in lauf:
                if not e.ueberstanden:
                    ok = false
            if ok:
                tiefster = stufe
            else:
                break
        var balken := "#".repeat(int(round(tiefster * 20.0)))
        print("  Welle %2d-%2d  %.2f  %s" % [
            start, start + Graben.WELLEN_JE_SITZUNG - 1, tiefster, balken])
        start += Graben.WELLEN_JE_SITZUNG
    print("")
    print("Faellt die Zahl von vorn nach hinten, zieht die Kurve an.")
    print("Bleibt sie gleich, passiert ueber 60 Wellen nichts.")
    quit(0)
