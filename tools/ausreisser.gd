extends SceneTree

## **Was eine einzelne Welle im schlimmsten Fall kostet.**
##
##     godot --headless --path . --script tools/ausreisser.gd
##     godot --headless --path . --script tools/ausreisser.gd -- --saat 1
##
## Der Kolonielauf zaehlt **gefallene Sitzungen**, und das sind ueber 120
## Tage ein knappes Dutzend Ereignisse. Eine Zahl aus einem Dutzend seltener
## Ereignisse streut entsprechend: derselbe Stand meldet unter drei
## Wellensaaten 35, 41 und 144. Damit ist jede Einzelmessung an ihm ein Zug
## aus einer Verteilung mit enormer Streuung - und jede Balance-Aenderung,
## die man daran beurteilt, ein Muenzwurf.
##
## Dieses Werkzeug misst stattdessen **die Verteilung selbst**. Es spielt
## jede Welle von `VON` bis `BIS` einzeln durch, auf der Sollkurve und mit
## voller Huelle, und schreibt auf, welchen Anteil der Huelle sie gekostet
## hat. Das sind rund hundertachtzig Stichproben statt eines Dutzends, und
## sie sagen genau das, was der Kolonielauf nur ahnen laesst:
##
##   * der **Median** - was eine gewoehnliche Welle kostet,
##   * das **obere Zehntel** - was eine unangenehme Welle kostet,
##   * der **Ausreisser** - die wenigen Wellen, die mehr kosten als eine
##     ganze Huelle.
##
## Der Ausreisser ist der Hebel. Eine Sitzung faellt nicht am Mittelwert:
## ueber 96 Sitzungen bleibt im Schnitt die Haelfte der Huelle uebrig, und
## trotzdem stirbt jede zwanzigste. Sie faellt an der einen Welle, die mehr
## kostet als alles, was vorher uebrig war. Wer die kappt, senkt die
## Fallzahl in **jeder** Saat; wer am Mittelwert dreht, verschiebt nur, wie
## sich der Rest anfuehlt.
##
## Gemeldet wird dazu, was die teuersten Wellen **teilen** - Zahl der Tiere
## und Anteil der schnellen -, denn daran hing bisher jede Vermutung, und
## keine war gemessen.

## Das Fenster, in dem die Faelle des Kolonielaufs liegen. Nicht geraten:
## er meldet "von Welle 30 bis 210".
const VON := 30
const BIS := 210

## Ab welchem Tempo ein Tier hier als schnell zaehlt. Der Massstab ist der
## Zahnkiefer (`Fangjaw`) mit 92 - die Art, gegen die jeder Preis in
## `Arten.aufwand()` gemessen ist. Wer deutlich schneller ist, ist frueher
## am Boot, als die Preistabelle annimmt.
const SCHNELL_AB := 120.0

## Wieviele der teuersten Wellen einzeln aufgeschluesselt werden.
const SPITZE := 12


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == "--saat" and i + 1 < args.size():
            Wellen.SAAT = Wellen.SAAT_VORGABE + int(args[i + 1])
            print("Wellensaat um %d verschoben" % int(args[i + 1]))

    var anteile: Array[float] = []
    var zeilen: Array[Dictionary] = []

    for nummer in range(VON, BIS + 1):
        var z := Simulation.Zustand.new()
        Simulation.stelle_ein(z, nummer)
        # **Volle Huelle je Welle.** Gemessen werden soll, was *diese* Welle
        # kostet, nicht wieviel vom Vorgaenger noch uebrig war. Die
        # Zermuerbung ueber eine Sitzung misst der Kolonielauf.
        z.huelle = z.huelle_voll
        var e := Simulation.welle(nummer, z)
        var anteil := float(e.verlust()) / float(maxf(1.0, z.huelle_voll))
        anteile.append(anteil)

        var tiere := 0
        var schnelle := 0
        var leben := 0.0
        # Ein Eintrag ist **ein** Tier - `auftritte()` fuehrt keine Zahl je
        # Gruppe, sie steht schon aufgeloest in der Liste.
        for a in Wellen.auftritte(nummer):
            tiere += 1
            leben += Wellen.leben_in(int(a[&"art"]), nummer)
            if Wellen.tempo_in(int(a[&"art"]), nummer) >= SCHNELL_AB:
                schnelle += 1
        # Wer den Verlust wirklich verursacht hat. `verlust_je_art` gibt es
        # seit dem Spiegler - eine gefallene Sitzung sagt sonst nur, dass
        # sie gefallen ist.
        var schuld := ""
        var sortiert: Array = []
        for k in e.verlust_je_art:
            sortiert.append([int(k), int(e.verlust_je_art[k])])
        sortiert.sort_custom(func(a, b): return a[1] > b[1])
        for i in mini(2, sortiert.size()):
            schuld += "%s %d " % [Arten.name_von(sortiert[i][0]), sortiert[i][1]]
        zeilen.append({
            &"welle": nummer, &"anteil": anteil, &"tiere": tiere,
            &"schnelle": schnelle, &"dauer": e.dauer,
            &"leit": Wellen.hat_leitwesen(nummer),
            &"leben": leben, &"huelle": z.huelle_voll,
            &"umgebung": Wellen.umgebung(nummer), &"schuld": schuld})

    anteile.sort()
    var n := anteile.size()
    print("\n%d Wellen von %d bis %d, Verlust als Anteil der vollen Huelle"
        % [n, VON, BIS])
    print("  Median %.1f %%   oberes Zehntel %.1f %%   Hoechst %.1f %%"
        % [anteile[n / 2] * 100.0, anteile[int(n * 0.9)] * 100.0,
            anteile[n - 1] * 100.0])

    # Wieviel der ganze Verlust aus dem oberen Zehntel kommt. Eine Zahl, die
    # sagt, ob die Kurve ein Schwanzproblem hat oder ein Mittelproblem ist.
    var alles := 0.0
    var oben := 0.0
    for i in n:
        alles += anteile[i]
        if i >= int(n * 0.9):
            oben += anteile[i]
    print("  das obere Zehntel traegt %.0f %% des gesamten Verlusts"
        % [oben / maxf(0.001, alles) * 100.0])
    var ueber_eins := 0
    for a in anteile:
        if a >= 1.0:
            ueber_eins += 1
    print("  Wellen ueber der ganzen Huelle: %d" % ueber_eins)

    zeilen.sort_custom(func(a, b): return a[&"anteil"] > b[&"anteil"])
    print("\nDie %d teuersten Wellen:" % SPITZE)
    _tafel(zeilen, 0, mini(SPITZE, zeilen.size()))
    print("\nZum Vergleich die %d guenstigsten:" % SPITZE)
    _tafel(zeilen, maxi(0, zeilen.size() - SPITZE), zeilen.size())
    quit()


func _tafel(zeilen: Array[Dictionary], von: int, bis: int) -> void:
    print(" Welle | Verlust | Tiere | schnell | Leben | Umgeb | Leit | woran")
    for i in range(von, bis):
        var r := zeilen[i]
        print("%6d | %6.0f %% | %5d | %5.0f %% | %5.0f | %5.2f | %4s | %s" % [
            r[&"welle"], float(r[&"anteil"]) * 100.0, r[&"tiere"],
            float(r[&"schnelle"]) / maxf(1.0, float(r[&"tiere"])) * 100.0,
            r[&"leben"], r[&"umgebung"],
            "ja" if r[&"leit"] else "-", r[&"schuld"]])


