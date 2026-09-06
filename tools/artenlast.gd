extends SceneTree

## Was eine Art in einer **ganzen Welle** an Huelle kostet - gemessen, nicht
## behauptet.
##
##     godot --headless --path . --script tools/artenlast.gd
##     godot --headless --path . --script tools/artenlast.gd -- --art Shellback
##
## **Warum es das braucht.** `Arten.aufwand` ist der Preis, zu dem
## `Wellen.auftritte()` eine Art einkauft, und er ist der Preis **je
## Lebenspunkt**. Er sagt damit, wieviel Kegelzeit ein Lebenspunkt dieser Art
## bindet - und sonst nichts. Was eine Art ausserdem kostet, naemlich was ein
## Durchkommen an Huelle abzieht (`Arten.wucht`), steht in keinem Preis. Zwei
## Arten mit gleicher Kegelzeit und Wucht 1 gegen 4 zahlen dasselbe und
## kosten das Vierfache.
##
## Der Kolonielauf sagt es seit Monaten und konnte nicht sagen, woran es
## liegt: oben in seiner Trefferliste stehen durchweg Arten mit hoher Wucht -
## Chalk Ray 4, Shellback 3, Shieldcoral 3, Mirrorshell 3.
##
## **Warum nicht am einzelnen Tier.** `tools/artenkosten.gd` haelt den Kegel
## durchgehend auf ein Tier. Tempo, Drift, Schub und Wucht kosten dort
## nichts - sie kosten, **weil der Kegel bei jemand anderem ist**, und das
## gibt es nur in einer ganzen Welle. Genau diese Lehre steht seit den
## Mutationen in CLAUDE.md; dort hat sie drei falsch bepreiste Zuege
## gefunden, nachdem die Ein-Tier-Messung vier davon fuer kostenlos erklaert
## hatte.
##
## **Was hier gemessen wird.** Achtzig Wellen, gefahren vom Simulator mit dem
## Boot auf dem Sollausbau, einmal mit allen Arten und einmal mit genau einer
## **ausgesperrt**. Verglichen wird der Huellenverlust je Welle.
##
## Die ausgesperrte Art faellt nicht ersatzlos weg: ihr Budget kauft andere
## Raeuber. Gefragt ist also nicht "wieviel Schaden macht sie", sondern die
## einzige Frage, auf die ein Preis antworten kann - **kostet sie mehr Huelle
## als das, was man fuer ihr Geld sonst bekaeme?** Eine richtig bepreiste Art
## laesst die Zahl stehen, wenn man sie aussperrt. Wer sie deutlich senkt,
## ist zu billig eingetragen.
##
## **Der Nullfall ist auch hier nicht ganz sauber**, und das gehoert
## hierher - dieselbe Einschraenkung wie bei `tools/mutationskosten.gd`. Wer
## eine Art aussperrt, aendert die Zusammensetzung, und die Ersatztiere sind
## nicht ihresgleichen. Der Wert dieser Tabelle liegt deshalb in der
## **Rangfolge** und im Vergleich zweier Laeufe, nicht in der einzelnen Zahl.

## Ueber welche Wellen gemessen wird. Zyklus 2 und 3 - dort steht die
## Kolonielauf-Trefferliste, und breit genug, dass ein Wurf nichts
## entscheidet.
const VON := 161
const BIS := 240

## Wieviel Huelle der Messstand mitgibt. Gemessen wird der Verlust, nicht das
## Ueberleben: eine Welle, die bei Huelle null abbricht, meldet zu wenig
## Schaden und sieht dadurch billiger aus, je haerter sie ist.
const HUELLE := 99999


class Befund extends RefCounted:
    var verlust := 0.0
    var tiere := 0.0
    var wie_oft := 0


static func messe(gesperrt: PackedInt32Array) -> Befund:
    Arten.sperre(gesperrt)
    Wellen.vergiss_umgebung()
    var b := Befund.new()
    for w in range(VON, BIS + 1):
        Wellen.vergiss_umgebung()
        var z := Simulation.Zustand.new()
        Simulation.stelle_ein(z, w)
        z.huelle = HUELLE
        z.huelle_voll = HUELLE
        Simulation.welle(w, z)
        b.verlust += float(HUELLE - z.huelle)
        var liste := Wellen.auftritte(w)
        b.tiere += float(liste.size())
        for a in liste:
            if gesperrt.has(int(a[&"art"])):
                b.wie_oft += 1
    Arten.sperre(PackedInt32Array())
    Wellen.vergiss_umgebung()
    return b


## Wie oft eine Art in den gemessenen Wellen ueberhaupt vorkommt. Ohne diese
## Spalte liest man eine Art, die dreimal auftritt, wie eine, die zweihundert
## Mal auftritt - und schiebt einer Zahl aus dem Rauschen einen Preis zu.
static func zaehle(art: int) -> int:
    Arten.sperre(PackedInt32Array())
    Wellen.vergiss_umgebung()
    var n := 0
    for w in range(VON, BIS + 1):
        for a in Wellen.auftritte(w):
            if int(a[&"art"]) == art:
                n += 1
    return n


func _init() -> void:
    print("Artenlast - Huellenverlust ueber die Wellen %d bis %d" % [VON, BIS])
    print("")
    var wellen := float(BIS - VON + 1)
    var voll := messe(PackedInt32Array())
    var grund := voll.verlust / wellen
    print("mit allen Arten: %.0f Huelle in %d Wellen (%.2f je Welle), %.0f Tiere"
        % [voll.verlust, int(wellen), grund, voll.tiere])
    print("")
    print("Eine Art wird ausgesperrt; ihr Budget kauft andere Raeuber.")
    print("Faellt der Verlust dabei deutlich, war sie zu billig eingetragen.")
    print("")
    print("%-14s %5s %6s %10s %10s %9s %8s %8s"
        % ["Art", "wucht", "kommt", "Huelle", "je Welle", "Anteil",
            "aufwand", "waere"])

    var nur := ""
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == "--art" and i + 1 < args.size():
            nur = args[i + 1]

    var schlimmste := 0.0
    var wer := "keine"
    for a in Arten.zahl():
        if nur != "" and Arten.name_von(a) != nur:
            continue
        var kommt := zaehle(a)
        if kommt <= 0:
            continue
        var b := messe(PackedInt32Array([a]))
        var je := b.verlust / wellen
        # Wieviel Huelle je Welle an dieser Art haengt - und wieviel das vom
        # Ganzen ist.
        var last := grund - je
        var anteil := last / maxf(0.001, grund)
        var preis := Arten.aufwand(a)
        # Was sie kosten muesste, damit ihr Anteil an der Huelle ihrem Anteil
        # am Budget entspricht. Die Spalte ist eine Rangfolge und keine Zahl
        # zum Abschreiben - siehe oben.
        var budget := float(kommt) / maxf(1.0, voll.tiere)
        var waere := preis * (anteil / maxf(0.001, budget))
        if anteil > schlimmste:
            schlimmste = anteil
            wer = Arten.name_von(a)
        print("%-14s %5d %6d %10.0f %10.2f %8.1f%% %8.2f %8.2f"
            % [Arten.name_von(a), Arten.wucht(a), kommt, b.verlust, je,
                anteil * 100.0, preis, waere])

    print("")
    print("Am teuersten: %s mit %.1f%% der Huelle." % [wer, schlimmste * 100.0])
    print("Eine Art, die richtig bepreist ist, traegt soviel von der Huelle")
    print("wie sie vom Budget hat. Die Spalte `waere` sagt, wie weit sie")
    print("davon weg ist - als Rangfolge, nicht als Zahl zum Abschreiben.")
    quit()
