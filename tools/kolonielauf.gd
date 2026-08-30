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
const TAGE := 120

## Nicht mehr die eigene Zahl des Werkzeugs: sie steht jetzt in `Graben`, weil
## die Wirtschaft mit ihr rechnet. Ein Messwerkzeug, das von drei Sitzungen am
## Tag ausgeht, waehrend der Ertrag fuer vier ausgelegt ist, misst ein anderes
## Spiel als das gespielte.
const SITZUNGEN_JE_TAG := Graben.SITZUNGEN_JE_TAG

## Abstand zwischen zwei Besuchen.
const SITZUNGSABSTAND := 86400.0 / float(SITZUNGEN_JE_TAG)

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
## Gemessen wird jetzt in ganzen Sitzungen, nicht in Wartesekunden. Grund: das
## Werkzeug liess den simulierten Spieler frueher bis zu acht Stunden vor
## einem laufenden Bau sitzen und zaehlte das als Leerlauf - so kam die
## gemeldete Wartemauer von vierundzwanzig Stunden zustande, obwohl im
## Hintergrund die ganze Zeit gebaut wurde. Kein Mensch tut das. Er schaut
## herein, und entweder ist etwas zu tun oder nicht.
##
## Leer ist eine Sitzung, in der **nichts** geschah: keine neue Welle, kein Bau
## fertig, kein Bau begonnen. Eine solche Sitzung ist die Stelle, an der
## jemand das Spiel zumacht - eine, in der ein Bau laeuft, ist es nicht.
const MAUER_EINSTIEG := 8.0
const MAUER_SPAETER := 16.0

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

    var letzte_gutschrift := 0.0

    for tag in TAGE:
        # Der Tageswechsel von Hand - `pruefe_tag()` fragt die Systemuhr, und
        # die laeuft hier nicht mit.
        stand.stroemung_offen = Tagesstroemung.JE_TAG
        var tages_leerlauf := 0.0
        var tages_faelle := 0
        var welle_am_morgen := stand.hoechste_welle
        var stufen_am_morgen := stand.stufen.duplicate()

        for sitzung in SITZUNGEN_JE_TAG:
            # Morgens, mittags, abends - nicht dreimal hintereinander. Der
            # Abstand zwischen zwei Besuchen ist der einzige Grund, warum ein
            # Bau ueberhaupt Zeit hat, fertig zu werden.
            zeit = maxf(zeit, float(tag) * 86400.0 + float(sitzung) * SITZUNGSABSTAND)
            stand.naehrstoffe += int(stand.je_stunde()
                * maxf(0.0, zeit - letzte_gutschrift) / 3600.0)
            letzte_gutschrift = zeit

            var baute_vorher := stand.baut()
            stand.hole_bau_ab(zeit)
            var wurde_fertig := baute_vorher and not stand.baut()
            var welle_vor_sitzung := stand.hoechste_welle

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
                    1, Graben.TIEFSTE)

            stand.naehrstoffe += z.naehrstoffe

            # 2. Bauen, solange etwas geht.
            var begann := false
            while _baue_etwas(stand, zeit):
                begann = true
                if tag < EINSTIEG_TAGE and stand.restzeit(zeit) > laengster_bau:
                    laengster_bau = stand.restzeit(zeit)
                    laengster_bau_kammer = stand.bau_kammer

            # 3. War diese Sitzung leer? Dann zaehlt sie ganz.
            if not (wurde_fertig or begann
                    or stand.hoechste_welle > welle_vor_sitzung):
                tages_leerlauf += SITZUNGSABSTAND

        # 4. Tagesende: Naehrstoff bis Mitternacht gutschreiben.
        var mitternacht := float(tag + 1) * 86400.0
        zeit = maxf(zeit, mitternacht)
        stand.naehrstoffe += int(stand.je_stunde()
            * maxf(0.0, zeit - letzte_gutschrift) / 3600.0)
        letzte_gutschrift = zeit
        stand.hole_bau_ab(zeit)

        var schwelle := MAUER_EINSTIEG if tag < EINSTIEG_TAGE else MAUER_SPAETER
        if tages_leerlauf / 3600.0 > schwelle and tages_leerlauf > groesste_mauer:
            groesste_mauer = tages_leerlauf
            mauer_tag = tag + 1
        mauer = maxf(mauer, tages_leerlauf)
        faelle += tages_faelle

        # Am Ende angekommen zaehlt kein Stillstand mehr - dort ist der Inhalt
        # zu Ende, nicht der Fortschritt versperrt.
        var am_ende := false
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

        var gespielt := stand.hoechste_welle
        if tag % 5 == 4 or tag == TAGE - 1:
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
    var gespielt := stand.hoechste_welle
    var soll_ende := Ausbau.stufe_soll(gespielt)
    var ist := stand.stufe(Kammern.Kammer.LEUCHTORGAN)
    print("Nach %d Tagen: Welle %d, Leuchtorgan Stufe %d (Soll %d)"
        % [TAGE, gespielt, ist, soll_ende])
    print("Volle Umdrehungen durch den Graben: %d" % Graben.zyklus(gespielt))
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
    #
    # Gemessen wird an der **ersten** Welle hinter dem heutigen Ende, nicht am
    # heutigen Ende selbst: wer graebt, spielt als naechstes dort weiter. Die
    # letzte Welle des neuen Abschnitts zu verlangen waere zu viel - ein
    # Abschnitt ist zehn Wellen lang und damit gut drei Kammerstufen, in die
    # man waehrend des Spielens hineinwaechst. Der Versuch stand hier: die
    # Kolonie blieb bei Welle 21 stehen und grub zehn Tage lang nicht.
    var schacht: int = Kammern.Kammer.TIEFENSCHACHT
    var stark_genug := stand.stufe(Kammern.Kammer.LEUCHTORGAN) \
        >= Ausbau.stufe_soll(stand.offene_welle() + 1)
    if stand.graben_haelt() and stark_genug and stand.kann_bauen(schacht):
        return stand.starte_bau(schacht, jetzt)
    var gebremst := 0
    for k in Kammern.zahl():
        if k != schacht and stand.am_deckel(k):
            gebremst += 1
    if gebremst >= 2 and stand.kann_bauen(schacht):
        return stand.starte_bau(schacht, jetzt)

    # Sonst: die Kammer, die am weitesten zurueckliegt.
    #
    # Hier stand eine feste Reihenfolge mit dem Leuchtorgan an erster Stelle -
    # und die war richtig, solange Naehrstoff knapp war: dann kam ohnehin
    # jeder mal dran. Seit das Einkommen mit den Kosten mitwaechst, ist immer
    # genug fuer die erste Kammer der Liste da, und der simulierte Spieler
    # baute hundertzwanzig Tage lang nichts als Leuchtorgan, Filterbecken und
    # Schacht. Zuchtkammer und Brutkammer standen am Ende des Laufs noch auf
    # Stufe 0 - gemessen wurde eine Kolonie, die niemand so spielen wuerde.
    #
    # Die niedrigste zuerst, bei Gleichstand nach Wichtigkeit. Damit bleiben
    # die Kammern beieinander, und das ist auch die Runde, aus der das
    # Einkommen abgeleitet ist.
    var reihe: PackedInt32Array = [
        Kammern.Kammer.LEUCHTORGAN,
        Kammern.Kammer.FILTERBECKEN,
        Kammern.Kammer.BRUTKAMMER,
        Kammern.Kammer.ZUCHTKAMMER,
        schacht,
    ]
    # Das Leuchtorgan zuerst, und zwar **bis an seinen Deckel**.
    #
    # Ein fester Vorsprung von zwei oder vier Stufen reichte nicht: der
    # Tiefenschacht oeffnet einen Abschnitt, wenn er `SCHACHT_VORSPRUNG` unter
    # dessen letzter Sollstufe steht, und deckelt die anderen Kammern zugleich
    # auf `Schacht + SCHACHT_VORSPRUNG`. Wer den Abschnitt betritt, *kann*
    # also genau auf der Sollkurve stehen - aber nur, wenn er das Leuchtorgan
    # bis an den Deckel zieht. Tat der simulierte Spieler das nicht, spielte
    # er jeden neuen Abschnitt zwei bis vier Stufen zu schwach, und der
    # Kolonielauf meldete zweiundzwanzig gefallene Sitzungen.
    #
    # Am Deckel angekommen faellt er von selbst auf die uebrigen Kammern
    # zurueck - dafuer ist der Deckel da.
    var leucht: int = Kammern.Kammer.LEUCHTORGAN
    if stand.kann_bauen(leucht):
        return stand.starte_bau(leucht, jetzt)

    var beste := -1
    var beste_stufe := Kammern.HOECHSTSTUFE + 1
    for k in reihe:
        if stand.kann_bauen(k) and stand.stufe(k) < beste_stufe:
            beste = k
            beste_stufe = stand.stufe(k)
    if beste >= 0:
        return stand.starte_bau(beste, jetzt)
    return false
