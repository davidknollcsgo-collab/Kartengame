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
##
## Der Horizont ist laenger als die dreissig Tage, mit denen dieses Werkzeug
## begann. Grund: seit der Graben an den Tiefenschacht gekoppelt ist, reicht
## der Inhalt ueber einen Monat hinaus - und ein Werkzeug, das vor dem Ende
## des Spiels aufhoert zu messen, prueft die letzten zehn Wellen nie.
const TAGE := 50
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

## Der Tagesdeckel fuer die erste Woche stand einmal bei einer halben Stunde.
## Er ist gestiegen, und zwar nicht, damit die Messung durchgeht: seit der
## Graben an den Tiefenschacht gekoppelt ist, steht der Spieler an Tag 7 bei
## Kammerstufe 12 statt bei 6. Der Plan verspricht "Stunden erst ab
## Kammerstufe 8" - eine Dreiviertelstunde Bauzeit, verteilt auf drei
## Sitzungen, haelt dieses Versprechen. Was es nicht halten wuerde, faengt die
## schaerfere Zusage darunter ab.
const MAUER_EINSTIEG := 1.5
const MAUER_SPAETER := 12.0

## Die eigentliche Zusage fuer die erste Woche: **kein einzelner Bau laenger
## als eine Stunde**. Ein Tagesdeckel allein wuerde einen Sechs-Stunden-Bau
## durchgehen lassen, solange der Rest des Tages still ist - und genau der
## eine Bau ist es, der jemanden vertreibt.
const EINSTIEG_BAU_DECKEL := 3600.0

## Ab so vielen Tagen ohne eine einzige gewonnene Welle ist von einer
## Fortschrittsmauer die Rede. Das ist die zweite Art zu stecken: nicht auf
## eine Uhr sehen, sondern immer wieder verlieren.
const FORTSCHRITTSMAUER := 4

## Wie oft eine Sitzung in fuenfzig Tagen fallen darf. Null waere falsch - eine
## Kurve, die nie jemanden umwirft, zieht nicht an. Aber wer dreimal am Tag
## verliert, spielt kein Spiel mehr, sondern eine Wand.
const TRAGBARE_FAELLE := 12


func _init() -> void:
    var stand := KolonieStand.new()
    var zeit := 0.0

    var mauer := 0.0
    var groesste_mauer := 0.0
    var mauer_tag := 0
    var rueckstand := 0

    # Die zweite Art zu stecken: nicht warten, sondern verlieren. Der
    # Simulator spielt die Wellen wirklich - also weiss er es auch, wenn eine
    # Sitzung faellt. Frueher hat er es bloss verschwiegen.
    var faelle := 0
    var bewaeltigt := 0
    var stillstand := 0
    var laengster_stillstand := 0
    var stillstand_welle := 0
    var tag_am_ende := 0

    # Die laengste Strecke ohne neue Welle wird berichtet, aber sie ist kein
    # Fehler fuer sich. In einem Aufbauspiel ist die Wellenzahl nur eine von
    # zwei Fortschrittsachsen; wer heute keine neue Welle sieht, aber seine
    # Kolonie um eine Stufe hebt, steckt nicht fest. Steckengeblieben ist,
    # wer **beides** nicht schafft - und genau das zaehlt `stillstand`.
    var ohne_welle := 0
    var laengste_ohne_welle := 0
    var welle_der_strecke := 0

    var laengster_bau := 0.0
    var laengster_bau_kammer := -1

    print("Kolonielauf - %d Tage, %d Sitzungen je Tag" % [TAGE, SITZUNGEN_JE_TAG])
    print("")
    print("  Tag | Welle | offen | Leucht Zucht Brut Filter Schacht | Vorrat | Soll | Faelle | Leerlauf")
    print("  ----+-------+-------+----------------------------------+--------+------+--------+---------")

    for tag in TAGE:
        # Der Tageswechsel von Hand - `pruefe_tag()` fragt die Systemuhr, und
        # die laeuft hier nicht mit.
        stand.stroemung_offen = Tagesstroemung.JE_TAG
        var tages_leerlauf := 0.0
        var tages_faelle := 0
        var welle_am_morgen := stand.hoechste_welle
        var stufen_am_morgen := stand.stufen.duplicate()

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
                # Der Graben gibt nur her, was der Tiefenschacht geoeffnet
                # hat. Wer weiter ist, spielt seine tiefste offene Welle noch
                # einmal - das bringt Naehrstoff, aber keinen Fortschritt.
                var nummer := mini(stand.hoechste_welle + i, stand.offene_welle())
                Simulation.baue_polypen(z)
                var vorher := z.naehrstoffe
                var e := Simulation.welle(nummer, z)
                zeit += Wellen.dauer(nummer)

                # Die Tagesstroemung gehoert in die Messung, sonst misst das
                # Werkzeug ein anderes Spiel als das, das gespielt wird.
                var roh := z.naehrstoffe - vorher
                if stand.nutze_stroemung():
                    z.naehrstoffe += Tagesstroemung.ausbeute(roh, true) - roh
                if not e.ueberstanden:
                    tages_faelle += 1
                    break
                bewaeltigt = maxi(bewaeltigt, nummer)
                stand.hoechste_welle = clampi(maxi(stand.hoechste_welle, nummer + 1),
                    1, Graben.WELLEN_GESAMT)

            stand.naehrstoffe += z.naehrstoffe

            # 2. Bauen, solange etwas geht.
            while _baue_etwas(stand, zeit):
                if tag < EINSTIEG_TAGE and stand.restzeit(zeit) > laengster_bau:
                    laengster_bau = stand.restzeit(zeit)
                    laengster_bau_kammer = stand.bau_kammer

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
        faelle += tages_faelle

        # Am Ende angekommen zaehlt kein Stillstand mehr - dort ist der Inhalt
        # zu Ende, nicht der Fortschritt versperrt.
        var am_ende := bewaeltigt >= Graben.WELLEN_GESAMT
        if am_ende and tag_am_ende == 0:
            tag_am_ende = tag + 1

        var neue_welle: bool = stand.hoechste_welle > welle_am_morgen or am_ende
        var neue_stufe := false
        for k in Kammern.zahl():
            if stand.stufe(k) > stufen_am_morgen[k]:
                neue_stufe = true
                break

        if neue_welle:
            ohne_welle = 0
        else:
            ohne_welle += 1
            if ohne_welle > laengste_ohne_welle:
                laengste_ohne_welle = ohne_welle
                welle_der_strecke = stand.hoechste_welle

        if neue_welle or neue_stufe:
            stillstand = 0
        else:
            stillstand += 1
            if stillstand > laengster_stillstand:
                laengster_stillstand = stillstand
                stillstand_welle = stand.hoechste_welle

        var gespielt := mini(stand.hoechste_welle, Graben.WELLEN_GESAMT)
        print("  %3d | %5d | %5d | %6d %5d %4d %6d %7d | %6d | %4d | %6d | %.1f h" % [
            tag + 1, gespielt, stand.offene_welle(),
            stand.stufe(Kammern.Kammer.LEUCHTORGAN),
            stand.stufe(Kammern.Kammer.ZUCHTKAMMER),
            stand.stufe(Kammern.Kammer.BRUTKAMMER),
            stand.stufe(Kammern.Kammer.FILTERBECKEN),
            stand.stufe(Kammern.Kammer.TIEFENSCHACHT),
            stand.naehrstoffe, Ausbau.stufe_soll(gespielt),
            tages_faelle, tages_leerlauf / 3600.0])

        if stand.stufe(Kammern.Kammer.LEUCHTORGAN) < Ausbau.stufe_soll(gespielt):
            rueckstand += 1

    print("")
    var gespielt := mini(stand.hoechste_welle, Graben.WELLEN_GESAMT)
    var soll_ende := Ausbau.stufe_soll(gespielt)
    var ist := stand.stufe(Kammern.Kammer.LEUCHTORGAN)
    print("Nach %d Tagen: Welle %d, Leuchtorgan Stufe %d (Soll %d)"
        % [TAGE, gespielt, ist, soll_ende])
    if tag_am_ende > 0:
        print("Welle %d erreicht an Tag %d" % [Graben.WELLEN_GESAMT, tag_am_ende])
    else:
        print("Welle %d in %d Tagen nicht erreicht" % [Graben.WELLEN_GESAMT, TAGE])
    if mauer_tag > 0:
        print("Groesste Wartemauer ueber der Schwelle: %.1f h an Tag %d"
            % [groesste_mauer / 3600.0, mauer_tag])
    else:
        print("Groesster Leerlauf: %.1f h - unter der Schwelle" % [mauer / 3600.0])
    print("Gefallene Sitzungen: %d" % faelle)
    print("Laengste Strecke ohne neue Welle: %d Tage%s" % [laengste_ohne_welle,
        " bei Welle %d" % welle_der_strecke if laengste_ohne_welle > 0 else ""])
    print("Laengster Stillstand (weder Welle noch Kammer): %d Tage%s"
        % [laengster_stillstand,
        " bei Welle %d" % stillstand_welle if laengster_stillstand > 0 else ""])
    print("Laengster Bau der ersten Woche: %.0f min (%s)" % [laengster_bau / 60.0,
        Kammern.name_von(laengster_bau_kammer) if laengster_bau_kammer >= 0 else "keiner"])
    print("Tage hinter der Sollkurve: %d von %d" % [rueckstand, TAGE])

    var fehler := PackedStringArray()
    if ist < soll_ende:
        fehler.append("Die Kolonie bleibt hinter der Sollkurve zurueck - der "
            + "Wellenpruefer prueft dann ein Spiel, das niemand spielen kann.")
    if mauer_tag > 0:
        var welche := "in der ersten Woche" if mauer_tag <= EINSTIEG_TAGE else "im Aufbau"
        fehler.append("Wartemauer von %.1f h an Tag %d %s - das ist die Stelle, an "
            % [groesste_mauer / 3600.0, mauer_tag, welche] + "der Spieler aufhoeren.")
    if laengster_bau > EINSTIEG_BAU_DECKEL:
        fehler.append("Ein Bau der ersten Woche dauert %.0f min (%s) - der Plan "
            % [laengster_bau / 60.0, Kammern.name_von(laengster_bau_kammer)]
            + "verspricht die erste Woche fast ohne echte Wartezeit.")
    if laengster_stillstand >= FORTSCHRITTSMAUER:
        fehler.append("Fortschrittsmauer: %d Tage lang weder eine neue Welle noch "
            % laengster_stillstand + "eine Kammerstufe bei Welle %d." % stillstand_welle)
    if faelle > TRAGBARE_FAELLE:
        fehler.append("%d gefallene Sitzungen in %d Tagen - der Spieler verliert "
            % [faelle, TAGE] + "haeufiger, als eine Kurve das darf.")

    print("")
    if fehler.is_empty():
        print("Die Kolonie traegt die Sollkurve ohne Warte- und ohne Fortschrittsmauer.")
        quit(0)
    for f in fehler:
        print("FEHLER: " + f)
    quit(1)


## Ein Ausbauschritt nach der Regel, die ein vernuenftiger Spieler anwendet.
## Gibt zurueck, ob gebaut wurde.
func _baue_etwas(stand: KolonieStand, jetzt: float) -> bool:
    if stand.baut():
        return false

    # Der Schacht zuerst, sobald er bremst - er ist die einzige Kammer, die
    # andere freischaltet, und seit der Kopplung auch die, die den Graben
    # oeffnet. Wer vor einem verschlossenen Abschnitt steht, gräbt.
    #
    # Aber erst, wenn der Waechter dem gewachsen ist, was schon offen steht.
    # Andersherum grub der simulierte Spieler an Tag 1 drei Stufen tief und
    # stand mit Leuchtorgan 0 in Welle 21 - drei gefallene Sitzungen am
    # Stueck. Wer den Graben aufmacht, ohne stark genug zu sein, macht sich
    # bloss ein Loch auf.
    var schacht: int = Kammern.Kammer.TIEFENSCHACHT
    var stark_genug := stand.stufe(Kammern.Kammer.LEUCHTORGAN) \
        >= Ausbau.stufe_soll(stand.offene_welle())
    if stand.graben_haelt() and stark_genug and stand.kann_bauen(schacht):
        return stand.starte_bau(schacht, jetzt)
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
