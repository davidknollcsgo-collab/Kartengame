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
## Wieviele Sekunden der Kegel wirklich auf diesem Tier brennt, bis es faellt.
##
## **Nicht dasselbe wie die Zeit bis zum Tod.** Ein langsames Tier, das am
## Feldrand eintritt, schwimmt erst einmal ausserhalb der Reichweite heran -
## dort steht die Uhr, aber der Kegel richtet nichts aus. Fuer die Frage "ist
## sein Leben richtig gerechnet" zaehlt nur die brennende Zeit; fuer die
## Frage "wie lange steht es im Feld" die ganze. Die erste Zahl gehoert zur
## Rechnung, die zweite zum Spielgefuehl, und sie zu verwechseln hat hier
## schon eine Aenderung gerechtfertigt, die nichts half.
static var _brennzeit := 0.0


static func zeit_bis_tot(art: int, welle: int) -> float:
    var z := Simulation.Zustand.new()
    Simulation.stelle_ein(z, welle)
    var rest := Wellen.leben_in(art, welle)
    var ort := Rundum.eintritt(0.0)
    var blick := Vector2.UP
    var zeit := 0.0
    var alter := 0.0
    var a := Arten.art(art)
    _brennzeit = 0.0
    while rest > 0.0 and zeit < HOECHSTDAUER:
        zeit += TAKT
        alter += TAKT
        ort = Rundum.schritt(ort, Vector2.ZERO,
            Wellen.tempo_in(art, welle), a[&"schlaengel"], a[&"takt"],
            0.7, alter, TAKT, Wellen.drift_in(art, welle),
            Arten.umlauf(art), 0.0)
        var soll := Schlund.zielrichtung(Vector2.ZERO, ort, blick)
        blick = Schlund.gedreht(blick, soll, Graben.DREHTEMPO, TAKT)
        # **Ohne Abschnittsregel, aber mit dem echten Kegel.** Hier standen
        # `0.0, 0.0` fuer Kernhaerte und Tiefe - das sind keine Standardwerte,
        # sondern die haertesten, die es gibt: der Kegel faellt dann vom
        # ersten Meter an ab und ist nirgends voll hell. Gemessen wurde damit
        # ein Licht, das im Spiel nicht vorkommt, und zwar fuer jede Art
        # verschieden stark - lange Anmarschwege litten mehr als kurze.
        # Weglassen heisst `Schlund.RAND_KERN`/`TIEFE_KERN`, also ruhiges
        # Wasser; was die Abschnitte davon abziehen, steht in
        # `Regeln.wirkungsgrad()` und gehoert nicht in den Artenvergleich.
        var hell := Schlund.beleuchtung(Vector2.ZERO, blick, z.halbwinkel(),
            z.reichweite(), ort)
        var weh := Schlund.schaden_an(z.leistung(), hell,
            Wellen.panzer_in(art, welle),
            Wellen.mindest_licht_in(art, welle),
            Wellen.hoechst_licht_in(art, welle))
        if weh > 0.0:
            _brennzeit += TAKT
        rest -= weh * TAKT
        if ort.length() < Rundum.BOOT_RADIUS + Wellen.radius_in(art, welle):
            ort = ort.normalized() * (Rundum.BOOT_RADIUS + 190.0)
            alter = 0.0
    return zeit


## Sekunden, bis dieses Leitwesen faellt - und wie lange es dauern sollte.
##
## **Ein Leitwesen wird nicht bepreist, sondern terminiert.**
## `Wellen.leben_in()` rechnet sein Leben aus `LEIT_SEKUNDEN`: "so lange soll
## es dauern", mal dem, was in dieser Sekunde wirklich ankommt. Die Rechnung
## nimmt dabei an, der Kegel liege die ganze Zeit voll darauf - und das
## stimmt am wenigsten dort, wo die geplante Dauer am kuerzesten ist. Bis das
## Tier ueberhaupt in Reichweite ist, vergeht eine feste Zeit, und die faellt
## bei sechs geplanten Sekunden staerker ins Gewicht als bei sechzehn.
##
## Gemessen wird hier gegen dieselbe Zahl, aus der das Leben faellt. Ueber
## eins heisst: es steht laenger, als es soll.
static func leit_faktor(art: int, welle: int) -> float:
    var t := clampf(float(maxi(1, welle) - 1) / float(Graben.ZYKLUS - 1),
        0.0, 1.0)
    var soll := lerpf(Wellen.LEIT_SEKUNDEN_ANFANG, Wellen.LEIT_SEKUNDEN_ENDE, t)
    var _egal := zeit_bis_tot(art, welle)
    return _brennzeit / maxf(0.01, soll)


## Das Leitwesen, das am weitesten ueber seiner geplanten Dauer steht -
## gemessen an der Welle, auf der es wirklich auftritt.
static func schlimmstes_leitwesen() -> Array:
    var schlimmster := 0.0
    var wer := -1
    var wo := 0
    for abschnitt in Arten.LEITFOLGE.size():
        var art := Arten.leitwesen_fuer(abschnitt)
        if art < 0:
            continue
        # Die Mitte des Abschnitts: dort steht das Leitwesen am haeufigsten,
        # und die Raender sind Sonderfaelle.
        var welle := int(Graben.WELLEN_JE_ABSCHNITT * (float(abschnitt) + 0.5)) + 1
        var f := leit_faktor(art, welle)
        if f > schlimmster:
            schlimmster = f
            wer = art
            wo = welle
    return [schlimmster, wer, wo]


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
    print("")
    print("Leitwesen - gemessen gegen die geplante Dauer")
    print("%-16s %6s %10s %10s %10s %8s"
        % ["Leitwesen", "Welle", "geplant", "brennt", "im Feld", "Faktor"])
    for abschnitt in Arten.LEITFOLGE.size():
        var leit := Arten.leitwesen_fuer(abschnitt)
        if leit < 0:
            continue
        var welle := int(Graben.WELLEN_JE_ABSCHNITT * (float(abschnitt) + 0.5)) + 1
        var lt := clampf(float(maxi(1, welle) - 1) / float(Graben.ZYKLUS - 1),
            0.0, 1.0)
        var soll := lerpf(Wellen.LEIT_SEKUNDEN_ANFANG,
            Wellen.LEIT_SEKUNDEN_ENDE, lt)
        var ist := zeit_bis_tot(leit, welle)
        var brennt := _brennzeit
        print("%-16s %6d %10.1f %10.1f %10.1f %8.2f"
            % [Arten.name_von(leit), welle, soll, brennt, ist,
                brennt / maxf(0.01, soll)])
    print("Ein Faktor ueber 1 heisst: die Art kostet mehr, als sie bezahlt -")
    print("das Wellenbudget kauft mehr davon, als es sich leisten kann.")
    quit()
