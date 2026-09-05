extends SceneTree

## Was eine Art wirklich vom Wellenbudget kostet - gemessen, nicht geschaetzt.
##
##     godot --headless --path . --script tools/artenkosten.gd
##
## **Warum es das braucht.** `Arten.aufwand()` sagt, wieviel Budget ein Tier
## kostet, und `Wellen.auftritte()` kauft danach ein. Die Zahl war von Hand
## gesetzt, und von Hand gesetzte Zahlen laufen der Wirklichkeit davon: der
## Kreiser stand auf 1,24 und brauchte gemessen das 3,3fache der Zeit, die
## der Zahnkiefer je Lebenspunkt braucht. Das Wellenbudget kaufte damit
## dreimal soviel Kreiser, wie es bezahlte - und der Wellenpruefer meldete
## eine Wand, deren Ursache nirgends stand.
##
## **Was hier gemessen wird.** Ein einzelnes Tier gegen denselben Kegel, mit
## demselben naiven Daumen: `Schlund.zielrichtung()` und `gedreht()` halten
## darauf, `Schlund.schaden_an()` brennt. Herauskommt die Zeit bis zum Tod,
## geteilt durch die Lebenspunkte - also das, was eine Sekunde Kegel an
## dieser Art ausrichtet. Der Zahnkiefer ist der Massstab und steht auf 1,00;
## er ist es auch im Bestiarium ("the yardstick for everything else").
##
## **Und was hier nicht gemessen wird.** Ein Tier, allein, ohne Zieldeckel
## und ohne Nachbarn. Das trifft die Kosten aus Bewegung und Haut genau und
## verfehlt alles, was aus der **Auswahl** kommt: `Schlund.brennende()` nimmt
## die Tiere mit der groessten Wirkung zuerst, und der Spiegler steht im Kern
## des Kegels, wo er fast nichts abbekommt - also wird er nie gewaehlt und
## laeuft in Ruhe heran. Gemessen kostet er 0,94, in einer echten Fahrt ist
## er der teuerste Posten der Huelle. Deshalb ist die Schranke unten locker
## und faengt nur, was um ein Vielfaches danebenliegt.

## Bei welcher Welle gemessen wird. Tief genug, dass alle Arten offen sind
## und die Kolonie ausgebaut ist; flach genug, dass keine Mutation das Bild
## verzerrt.
const WELLE := 90

const TAKT := 1.0 / 30.0
const HOECHSTDAUER := 400.0


## Sekunden, bis dieses eine Tier faellt.
##
## Wer ankommt, wird zurueckgeworfen statt gezaehlt - genau wie im Spiel.
## Der erste Anlauf brach hier ab, und dann mass er bei allen ausser dem
## Kreiser die Anmarschzeit statt der Zeit bis zum Tod.
static func zeit_bis_tot(art: int, welle: int) -> float:
    var z := Simulation.Zustand.new()
    Simulation.stelle_ein(z, welle)
    var rest := Wellen.leben_in(art, welle)
    var ort := Rundum.eintritt(0.0)
    var blick := Vector2.UP
    var zeit := 0.0
    var alter := 0.0
    var a := Arten.art(art)
    while rest > 0.0 and zeit < HOECHSTDAUER:
        zeit += TAKT
        alter += TAKT
        ort = Rundum.schritt(ort, Vector2.ZERO,
            Wellen.tempo_in(art, welle), a[&"schlaengel"], a[&"takt"],
            0.7, alter, TAKT, Wellen.drift_in(art, welle),
            Arten.umlauf(art), 0.0)
        var soll := Schlund.zielrichtung(Vector2.ZERO, ort, blick)
        blick = Schlund.gedreht(blick, soll, Graben.DREHTEMPO, TAKT)
        var hell := Schlund.beleuchtung(Vector2.ZERO, blick, z.halbwinkel(),
            z.reichweite(), ort, 0.0, 0.0)
        rest -= Schlund.schaden_an(z.leistung(), hell,
            Wellen.panzer_in(art, welle),
            Wellen.mindest_licht_in(art, welle),
            Wellen.hoechst_licht_in(art, welle)) * TAKT
        if ort.length() < Rundum.BOOT_RADIUS + Wellen.radius_in(art, welle):
            ort = ort.normalized() * (Rundum.BOOT_RADIUS + 190.0)
            alter = 0.0
    return zeit


## Wie weit die eingetragene Zahl danebenliegt, ueber alle Arten.
##
## Groesser als eins heisst: die Art kostet mehr, als sie bezahlt - das
## Wellenbudget kauft mehr davon, als es sich leisten kann. Der Testlauf
## fragt genau das ab; deshalb steht die Schleife hier und nicht nur in
## `_init()`.
static func schlimmster_faktor() -> Array:
    var grund := zeit_bis_tot(Arten.Art.ZAHNKIEFER, WELLE) \
        / maxf(1.0, Wellen.leben_in(Arten.Art.ZAHNKIEFER, WELLE))
    var schlimmster := 0.0
    var wer := -1
    for a in Arten.zahl():
        if Arten.ist_leitwesen(a):
            continue
        var g := (zeit_bis_tot(a, WELLE)
            / maxf(1.0, Wellen.leben_in(a, WELLE))) / maxf(0.000001, grund)
        var f := g / maxf(0.001, Arten.aufwand(a))
        if f > schlimmster:
            schlimmster = f
            wer = a
    return [schlimmster, wer]


func _init() -> void:
    print("Artenkosten bei Welle %d - Zahnkiefer ist der Massstab" % WELLE)
    print("")
    print("Art                  Leben  Sekunden  gemessen  eingetragen  Faktor")
    var grund := zeit_bis_tot(Arten.Art.ZAHNKIEFER, WELLE) \
        / maxf(1.0, Wellen.leben_in(Arten.Art.ZAHNKIEFER, WELLE))
    var schlimmster := 0.0
    var schlimmste_art := ""
    for a in Arten.zahl():
        if Arten.ist_leitwesen(a):
            continue
        var leben := Wellen.leben_in(a, WELLE)
        var t := zeit_bis_tot(a, WELLE)
        var g := (t / maxf(1.0, leben)) / maxf(0.000001, grund)
        var e := Arten.aufwand(a)
        var f := g / maxf(0.001, e)
        if f > schlimmster:
            schlimmster = f
            schlimmste_art = Arten.name_von(a)
        print("%-18s %7.0f  %8.1f  %8.2f  %11.2f  %6.2f"
            % [Arten.name_von(a), leben, t, g, e, f])
    print("")
    print("Am weitesten daneben: %s mit dem %.2ffachen."
        % [schlimmste_art, schlimmster])
    print("Ein Faktor ueber 1 heisst: die Art kostet mehr, als sie bezahlt -")
    print("das Wellenbudget kauft mehr davon, als es sich leisten kann.")
    quit()
