extends SceneTree

## Dreissig simulierte Tage Kolonie.
##
## Beantwortet die zwei Fragen, die man einem Aufbauspiel nicht ansieht:
##
##   1. **Erreicht ein normaler Spieler die Sollkurve?** Der Wellenpruefer
##      setzt sie voraus. Wenn die Kolonie sie nicht hergibt, prueft er ein
##      Spiel, das niemand spielen kann.
##   2. **Entsteht eine Wartemauer?** Also ein Tag, an dem der Spieler nichts
##      tun kann ausser auf eine Uhr zu sehen. Das ist die Stelle, an der
##      Leute aufhoeren.
##
##     godot --headless --path . --script tools/kolonielauf.gd
##
## Exitcode 1, wenn die Kolonie hinter der Sollkurve zurueckbleibt.

## Wie ein durchschnittlicher Spieler sich verhaelt.
const TAGE := 30
const SITZUNGEN_JE_TAG := 3
const TAKT := 60.0            ## Sekunden je Rechenschritt

## Was eine Sitzung an Naehrstoff einbringt - gemessen, nicht geraten: der
## Simulator spielt die Wellen wirklich durch.
const WELLEN_JE_SITZUNG := Graben.WELLEN_JE_SITZUNG

## Ab wieviel Leerlauf je Tag von einer Wartemauer die Rede ist.
##
## Zwei Schwellen statt einer, weil zwei verschiedene Dinge gemeint sind. In
## der ersten Woche ist jede echte Wartezeit ein Fehler - dort entscheidet
## sich, ob jemand bleibt. Spaeter ist ein Bau, der ueber Nacht laeuft, kein
## Fehler, sondern der Kern eines Aufbauspiels.
const EINSTIEG_TAGE := 7
const MAUER_EINSTIEG := 0.5
const MAUER_SPAETER := 12.0


func _init() -> void:
    var stand := KolonieStand.new()
    var zeit := 0.0
    var welle := 1

    # Reihenfolge, in der ein vernuenftiger Spieler ausbaut: erst der Schacht,
    # wenn er bremst, sonst die Kammer mit dem groessten Nutzen je Naehrstoff.
    var mauer := 0.0
    var groesste_mauer := 0.0
    var mauer_tag := 0
    var rueckstand := 0

    print("Kolonielauf - %d Tage, %d Sitzungen je Tag" % [TAGE, SITZUNGEN_JE_TAG])
    print("")
    print("  Tag | Welle | Leucht Zucht Brut Filter Schacht | Vorrat | Soll | Leerlauf")
    print("  ----+-------+----------------------------------+--------+------+---------")

    for tag in TAGE:
        var tages_leerlauf := 0.0

        for _s in SITZUNGEN_JE_TAG:
            # 1. Spielen: die naechsten Wellen mit dem *tatsaechlichen*
            #    Koloniestand, nicht mit der Sollkurve.
            var z := Simulation.Zustand.new()
            z.leistung_faktor = stand.leistung_faktor()
            z.reichweite_faktor = stand.reichweite_faktor()
            z.winkel_faktor = stand.winkel_faktor()
            z.ziele_zusatz = stand.ziele() - Graben.ZIELE
            z.brut = stand.brut_leben()

            for i in WELLEN_JE_SITZUNG:
                var nummer := mini(welle + i, Graben.WELLEN_GESAMT)
                Simulation.baue_polypen(z)
                var e := Simulation.welle(nummer, z)
                zeit += Wellen.dauer(nummer)
                if not e.ueberstanden:
                    break
                welle = mini(welle + 1, Graben.WELLEN_GESAMT)

            stand.naehrstoffe += z.naehrstoffe

            # 2. Bauen, solange etwas geht.
            while _baue_etwas(stand, zeit):
                pass

            # 3. Warten, bis der Bau fertig ist - hoechstens bis zum naechsten
            #    Spielabschnitt. Genau hier entsteht die Wartemauer.
            var wartete := 0.0
            while stand.baut() and wartete < 8.0 * 3600.0:
                zeit += TAKT
                wartete += TAKT
                stand.hole_bau_ab(zeit)
            tages_leerlauf += wartete
            zeit += 600.0

        # 4. Der Rest des Tages: Filterbecken sammelt, Bau laeuft weiter.
        var rest := 86400.0 - fmod(zeit, 86400.0)
        stand.naehrstoffe += int(stand.je_stunde() * rest / 3600.0)
        zeit += rest
        stand.hole_bau_ab(zeit)

        var schwelle := MAUER_EINSTIEG if tag < EINSTIEG_TAGE else MAUER_SPAETER
        if tages_leerlauf / 3600.0 > schwelle and tages_leerlauf > groesste_mauer:
            groesste_mauer = tages_leerlauf
            mauer_tag = tag + 1
        mauer = maxf(mauer, tages_leerlauf)

        var soll := Ausbau.stufe_soll(welle)
        if stand.stufe(Kammern.Kammer.LEUCHTORGAN) < soll:
            rueckstand += 1

        print("  %3d | %5d | %6d %5d %4d %6d %7d | %6d | %4d | %.1f h" % [
            tag + 1, welle,
            stand.stufe(Kammern.Kammer.LEUCHTORGAN),
            stand.stufe(Kammern.Kammer.ZUCHTKAMMER),
            stand.stufe(Kammern.Kammer.BRUTKAMMER),
            stand.stufe(Kammern.Kammer.FILTERBECKEN),
            stand.stufe(Kammern.Kammer.TIEFENSCHACHT),
            stand.naehrstoffe, soll, tages_leerlauf / 3600.0])

    print("")
    var soll_ende := Ausbau.stufe_soll(welle)
    var ist := stand.stufe(Kammern.Kammer.LEUCHTORGAN)
    print("Nach %d Tagen: Welle %d, Leuchtorgan Stufe %d (Soll %d)"
        % [TAGE, welle, ist, soll_ende])
    if mauer_tag > 0:
        print("Groesste Wartemauer ueber der Schwelle: %.1f h an Tag %d"
            % [groesste_mauer / 3600.0, mauer_tag])
    else:
        print("Groesster Leerlauf: %.1f h - unter der Schwelle" % [mauer / 3600.0])
    print("Tage hinter der Sollkurve: %d von %d" % [rueckstand, TAGE])

    var fehler := PackedStringArray()
    if ist < soll_ende:
        fehler.append("Die Kolonie bleibt hinter der Sollkurve zurueck - der "
            + "Wellenpruefer prueft dann ein Spiel, das niemand spielen kann.")
    if mauer_tag > 0:
        var welche := "in der ersten Woche" if mauer_tag <= EINSTIEG_TAGE else "im Aufbau"
        fehler.append("Wartemauer von %.1f h an Tag %d %s - das ist die Stelle, an "
            % [groesste_mauer / 3600.0, mauer_tag, welche] + "der Spieler aufhoeren.")

    print("")
    if fehler.is_empty():
        print("Die Kolonie traegt die Sollkurve ohne Wartemauer.")
        quit(0)
    for f in fehler:
        print("FEHLER: " + f)
    quit(1)


## Ein Ausbauschritt nach der Regel, die ein vernuenftiger Spieler anwendet.
## Gibt zurueck, ob gebaut wurde.
func _baue_etwas(stand: KolonieStand, jetzt: float) -> bool:
    if stand.baut():
        return false

    # Der Schacht zuerst, sobald er die anderen Kammern ausbremst - er ist die
    # einzige Kammer, die andere freischaltet.
    var schacht: int = Kammern.Kammer.TIEFENSCHACHT
    var gebremst := 0
    for k in Kammern.zahl():
        if k != schacht and stand.am_deckel(k):
            gebremst += 1
    if gebremst >= 2 and stand.kann_bauen(schacht):
        return stand.starte_bau(schacht, jetzt)

    # Sonst: das Leuchtorgan hat Vorrang, danach was am billigsten ist. Das
    # Filterbecken zieht frueh mit, weil es sich selbst bezahlt.
    var reihe: PackedInt32Array = [
        Kammern.Kammer.LEUCHTORGAN,
        Kammern.Kammer.FILTERBECKEN,
        Kammern.Kammer.ZUCHTKAMMER,
        Kammern.Kammer.BRUTKAMMER,
        schacht,
    ]
    for k in reihe:
        if stand.kann_bauen(k):
            return stand.starte_bau(k, jetzt)
    return false
