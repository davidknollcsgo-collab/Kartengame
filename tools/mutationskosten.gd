extends SceneTree

## Was eine Mutation wirklich an Wirkungsgrad kostet - gemessen, nicht
## geschaetzt.
##
##     godot --headless --path . --script tools/mutationskosten.gd
##
## **Warum es das braucht.** `Mutationen.WIRKUNGSGRAD` sagt, wieviel von
## seiner Leistung ein Spieler in einer mutierten Welle noch auf die Raeuber
## bringt, und `Wellen.staerke()` kauft danach ein (Zusage 6). Die sechs
## Zahlen waren von Hand gesetzt. Bei `AUFGEDUNSEN` hat der Wellenpruefer das
## schon einmal widerlegt: dort stand 1.0, und **jede** gefallene Sitzung lag
## auf einer aufgedunsenen Welle.
##
## **Warum nicht am einzelnen Tier.** Der erste Anlauf mass wie
## `tools/artenkosten.gd`: ein Tier, der ganze Kegel darauf, Stoppuhr mit und
## ohne den Zug. Vier der fuenf messbaren Mutationen kamen dabei auf 0,97 bis
## 1,02 heraus - also kostenlos. Das ist kein Ergebnis, sondern der blinde
## Fleck des Aufbaus: liegt der Kegel ohnehin die ganze Zeit auf dem Tier,
## aendert schnelleres oder unsteteres Schwimmen daran nichts. Was diese Zuege
## kosten, kosten sie erst, **wenn der Kegel woanders ist** - und das gibt es
## nur in einer ganzen Welle. Dieselbe Lehre wie beim Spiegler: gemessene
## Artenkosten 1,06, in einer echten Fahrt der teuerste Posten der Huelle.
##
## **Was hier stattdessen gemessen wird.** Achtzig Wellen, einmal ohne jeden
## Zug und einmal mit genau einem - gefahren vom Simulator, mit dem Boot auf
## dem Sollausbau. Verglichen wird der Huellenverlust **je Welle**.
##
## Nicht je Tier: ein Zug, der eingepreist ist, macht die Welle kleiner
## (`Wellen.staerke()` kauft weniger), und die wenigen Tiere sind dafuer
## einzeln schwerer. Je Tier gerechnet kaeme jeder Zug teuer heraus, auch ein
## richtig bepreister.
##
## **Der Nullfall ist trotzdem nicht ganz sauber, und das gehoert hierher.**
## Eine Welle ohne jeden Zug hat das groesste Budget und kauft dafuer viele
## billige Tiere; ein bepreister Zug nimmt Budget weg, und was zuerst
## wegfaellt, sind die billigen. Die teuren bleiben - Gruppenmindestzahlen
## und das Leitwesen stehen ohnehin im Feld. Ein Zug, der gar nichts tut,
## kostet dadurch schon rund ein Sechstel mehr Huelle als gar keiner.
## Gemessen: `Lightshy` 293, `Erratic` 350, `Surging` 337 gegen 287 - und bei
## den letzten beiden liegt das nachweislich **nicht** am Zug, denn ein
## Fuenftel weniger Drift und ein Sechstel weniger Schub aendern die Zahl
## nicht (344/350 und 337/337).
##
## Der Wert dieser Tabelle liegt deshalb im **Vergleich zweier Laeufe**: eine
## Staerke aendern, noch einmal messen, und die beiden Zahlen nebeneinander
## legen. Budget und Zusammensetzung sind dann Wort fuer Wort dieselben, und
## was sich unterscheidet, ist der Zug. So gemessen:
##
##     Plated   PANZER_ANTEIL   0,14 -> 0,045    868 -> 453 Huelle
##     Swift    HAST_FAKTOR     1,22 -> 1,10     621 -> 440
##     Bloated  LEBEN/RADIUS    1,6  -> 1,25     759 -> 420
##     Erratic  DRIFT_ZUSATZ    0,55 -> 0,45     344 -> 350
##     Surging  STOSS_ZUSATZ    0,45 -> 0,38     337 -> 337
##
## Drei Zuege kosten also wirklich etwas, und zwar viel; zwei kosten gar
## nichts. Die Spalte `waere` unten liest die Tabelle wie eine Preisliste und
## ist damit **zu streng** - sie schreibt den Nullfall-Aufschlag jedem Zug
## zu. Als Rangfolge taugt sie, als Zahl zum Abschreiben nicht.
##
## `Mutationen.erzwinge()` ist der Hebel dafuer; er steht ausdruecklich nur
## fuer diesen Messstand da, und ein Waechter im Testlauf haelt ihn dort.

## Ueber welche Wellen gemessen wird. Zyklus 2 und 3, wo Mutationen ueberhaupt
## vorkommen, und breit genug, dass ein einzelner Wurf nichts entscheidet.
const VON := 161
const BIS := 240


class Befund extends RefCounted:
    var verlust := 0.0
    var tiere := 0.0
    var gefallen := 0


static func messe(zug: PackedInt32Array) -> Befund:
    Mutationen.erzwinge(zug)
    Wellen.vergiss_umgebung()
    var b := Befund.new()
    for w in range(VON, BIS + 1):
        Wellen.vergiss_umgebung()
        var z := Simulation.Zustand.new()
        Simulation.stelle_ein(z, w)
        # Reichlich Huelle: gemessen wird der Verlust, nicht das Ueberleben -
        # eine Welle, die bei Huelle null abbricht, meldet zu wenig Schaden
        # und sieht dadurch billiger aus, je haerter sie ist.
        z.huelle = 99999
        z.huelle_voll = 99999
        var e := Simulation.welle(w, z)
        b.verlust += float(99999 - z.huelle)
        b.tiere += float(Wellen.auftritte(w).size())
        if e.treffer > 0:
            b.gefallen += 1
    Mutationen.frei()
    Wellen.vergiss_umgebung()
    return b


func _init() -> void:
    print("Mutationskosten - Huellenverlust ueber die Wellen %d bis %d"
        % [VON, BIS])
    print("")
    var wellen := float(BIS - VON + 1)
    var ohne := messe(PackedInt32Array())
    var grund := ohne.verlust / wellen
    print("ohne jeden Zug: %.0f Huelle in %d Wellen (%.2f je Welle), %.0f Tiere"
        % [ohne.verlust, int(wellen), grund, ohne.tiere])
    print("")
    print("%-12s %10s %10s %10s %10s %10s"
        % ["Mutation", "Huelle", "je Welle", "Tiere", "eingetragen", "waere"])

    # `-- --zug Plated` misst nur diesen einen. Ein voller Lauf dauert eine
    # knappe halbe Stunde; wer an einer Zahl dreht, will nicht auf die
    # anderen fuenf warten.
    var nur := ""
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == "--zug" and i + 1 < args.size():
            nur = args[i + 1]

    var schlimmster := 1.0
    var wer := "keine"
    for m in Mutationen.Mutation.size():
        if nur != "" and Mutationen.name_von(m) != nur:
            continue
        var b := messe(PackedInt32Array([m]))
        var je := b.verlust / wellen
        var f := je / maxf(0.001, grund)
        var e: float = Mutationen.WIRKUNGSGRAD[m]
        if f > schlimmster:
            schlimmster = f
            wer = Mutationen.name_von(m)
        print("%-12s %10.0f %10.2f %10.0f %10.2f %10.2f"
            % [Mutationen.name_von(m), b.verlust, je, b.tiere, e,
                clampf(e / maxf(0.001, f), 0.0, 1.0)])

    print("")
    print("Am weitesten daneben: %s mit dem %.2ffachen." % [wer, schlimmster])
    print("Ein Zug, der richtig bepreist ist, kostet je Welle genausoviel")
    print("Huelle wie gar keiner. Wer mehr kostet, gehoert billiger")
    print("eingetragen - die Spalte `waere` sagt, wie viel.")
    quit()
