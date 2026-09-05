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

## Wie weit das Leuchtorgan hinter der Sollkurve liegen darf.
##
## Hier stand einmal ein Vergleich am letzten Tag: `ist < soll`, also null
## Toleranz. Das misst aber nicht den Fortschritt, sondern die Rundung -
## der Lauf meldete Fehler bei Stufe 74 gegen Soll 75, waehrend derselbe Lauf
## drei gefallene Sitzungen in dreihundertsechzig hatte. Gemessen wird jetzt
## der **groesste** Abstand ueber alle Tage.
##
## Und die Schwelle ist abgeleitet, nicht gewaehlt: **ein Abschnitt geht als
## Block auf.** Der Tiefenschacht oeffnet zehn Wellen auf einmal, und ueber
## zehn Wellen verlangt die Sollkurve gut drei Stufen mehr. Wer eintritt,
## steht also zwangslaeufig unter der Sollstufe der letzten Welle des
## Abschnitts und waechst waehrend des Spielens hinein - so ist es gedacht.
## Was daran gemessen gehoert, ist nicht der Abstand, sondern ob dabei
## Sitzungen fallen, und das zaehlt `TRAGBARE_FAELLE`.
static func tragbarer_rueckstand() -> int:
    return Ausbau.stufe_soll(Graben.WELLEN_JE_ABSCHNITT * 2) \
        - Ausbau.stufe_soll(Graben.WELLEN_JE_ABSCHNITT + 1)



func _init() -> void:
    var stand := KolonieStand.new()
    var zeit := 0.0

    var mauer := 0.0
    var groesste_mauer := 0.0
    var mauer_tag := 0
    var rueckstand := 0
    var groesster_rueckstand := 0

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
            z.begleiter_zahl = stand.begleiter()
            # **Die Huelle ist die Brut.** Die Brutkammer hebt weiter die
            # Zahl der Fehler, die man uebersteht - nur haengt sie jetzt am
            # Boot und nicht an einem Gelege.
            z.huelle_voll = stand.brut_leben()
            z.huelle = z.huelle_voll

            for i in WELLEN_JE_SITZUNG:
                # Der Graben gibt nur her, was der Tiefenschacht geoeffnet
                # hat. Wer weiter ist, spielt seine tiefste offene Welle noch
                # einmal - das bringt Naehrstoff, aber keinen Fortschritt.
                var nummer := mini(stand.hoechste_welle + i, stand.offene_welle())
                var vorher := z.naehrstoffe
                var e := Simulation.welle(nummer, z)
                # **Die Dauer einer Runde, nicht einer Welle.** Gespielt
                # werden `Rundum.DICHTE` Wellen auf einmal; wer mit
                # `Wellen.dauer()` rechnet, macht die Sitzung um ein
                # Mehrfaches zu kurz - und findet dann keine Wartemauer,
                # weil er den Tag nicht vollbekommt.
                zeit += Wellen.rundendauer(nummer)

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

        var abstand := Ausbau.stufe_soll(gespielt) \
            - stand.stufe(Kammern.Kammer.LEUCHTORGAN)
        if abstand > 0:
            rueckstand += 1
        groesster_rueckstand = maxi(groesster_rueckstand, abstand)

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
    print("Tage hinter der Sollkurve: %d von %d, hoechstens %d Stufen (tragbar %d)"
        % [rueckstand, TAGE, groesster_rueckstand, tragbarer_rueckstand()])

    var fehler := PackedStringArray()
    if groesster_rueckstand > tragbarer_rueckstand():
        fehler.append("Die Kolonie faellt bis zu %d Stufen hinter die "
            % groesster_rueckstand + "Sollkurve zurueck, tragbar sind %d - "
            % tragbarer_rueckstand() + "der Wellenpruefer prueft dann ein "
            + "Spiel, das niemand spielen kann.")
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
        # **`quit()` kehrt zurueck.** Es meldet der Hauptschleife nur an, dass
        # sie aufhoeren soll - der Rest der Funktion laeuft weiter. Ohne das
        # `return` fiel der gute Ausgang unten in `quit(1)` hinein und
        # ueberschrieb seinen eigenen Exitcode: der Lauf meldete auf dem Bild
        # "Die Kolonie traegt die Sollkurve" und in der Schale einen Fehler.
        # In CI stand deshalb ein rotes Kreuz an einem Schritt, der gruen war.
        quit(0)
        return
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
    # Das Leuchtorgan zuerst, aber nur **bis zur Sollstufe des offenen
    # Grabens**.
    #
    # Zwei Fassungen davor waren falsch, jede auf ihre Art. Ein fester
    # Vorsprung von zwei oder vier Stufen liess es dauerhaft unter der
    # Sollkurve liegen - der Tiefenschacht oeffnet einen Abschnitt bei
    # `stufe_soll(letzte Welle) - SCHACHT_VORSPRUNG`, und wer im Gleichschritt
    # mit ihm baut, betritt jeden Abschnitt genau diese vier Stufen zu
    # schwach: zweiundzwanzig gefallene Sitzungen. Es dagegen bis an den
    # Kammerdeckel zu ziehen war das andere Extrem: der Deckel steigt mit dem
    # Schacht, der Schacht steigt mit dem Leuchtorgan, und der simulierte
    # Spieler stand an Tag 75 bei Leuchtorgan 57 und Brutkammer 38. Eine
    # Kolonie mit einem einzigen sinnvollen Knopf - genau das, was der
    # Schachtdeckel verhindern soll.
    #
    # Die Sollkurve ist die richtige Grenze: bis dorthin zahlt sich Schaden
    # aus, darueber liegt er brach, solange der Graben nicht tiefer ist.
    var leucht: int = Kammern.Kammer.LEUCHTORGAN
    if stand.kann_bauen(leucht) \
            and stand.stufe(leucht) < Ausbau.stufe_soll(stand.offene_welle()):
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
