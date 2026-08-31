extends SceneTree

## Headless-Testlauf.
##
##     godot --headless --path . --script tests/run_tests.gd
##
## Zwei Regeln, beide aus schmerzhafter Erfahrung:
##
## 1. **Jede Testfunktion endet mit `return true`.** GDScript bricht bei einem
##    Laufzeitfehler nur die betroffene Funktion ab, nicht das Programm. Ein
##    Test, der mittendrin stirbt, gaebe sonst `null` zurueck und der Laeufer
##    meldete gruen.
## 2. **Jede Testfunktion steht in `TESTS`.** Ein Wachter vergleicht die
##    Methodenliste mit dieser Tabelle. Bei HYPHA lief ein Test ueber mehrere
##    Commits schlicht nicht mit, weil er beim Eintragen vergessen wurde - und
##    kein Abbruchschutz der Welt faengt einen Test, der nie aufgerufen wird.

const TESTS: PackedStringArray = [
    "_test_beleuchtung_mitte",
    "_test_beleuchtung_ausserhalb",
    "_test_beleuchtung_faellt_zum_rand",
    "_test_beleuchtung_faellt_in_die_tiefe",
    "_test_beleuchtung_entartet",
    "_test_getroffen_stimmt_mit_beleuchtung",
    "_test_brennende_nimmt_die_hellsten",
    "_test_brennende_laesst_dunkles_aus",
    "_test_brennende_entartet",
    "_test_kegel_wird_nicht_staerker_durch_masse",
    "_test_schlieren_bleiben_schmuck",
    "_test_zielrichtung",
    "_test_gelege_bleibt_im_rahmen",
    "_test_takt_deckelt_den_sprung",
    "_test_speichern_ist_unteilbar",
    "_test_kegel_waehlt_nach_wirkung",
    "_test_kurve_haengt_nicht_an_der_abschnittszahl",
    "_test_jeder_abschnitt_ist_vollstaendig",
    "_test_spiegler_brennt_nur_im_randlicht",
    "_test_drehung_begrenzt",
    "_test_drehung_erreicht_ziel",
    "_test_bahn_endet_an_der_brut",
    "_test_laufzeit",
    "_test_arten_tabelle_vollstaendig",
    "_test_arten_erst_ab_ihrer_welle",
    "_test_arten_verhalten_bleibt_im_rahmen",
    "_test_bahn_bleibt_im_bild_und_sinkt",
    "_test_haut_schluckt_schwache_quellen",
    "_test_leitwesen_stehen_an_den_abschnittsenden",
    "_test_mutationen_tabelle_vollstaendig",
    "_test_mutationen_erst_ab_der_zweiten_umdrehung",
    "_test_mutationen_sind_reproduzierbar",
    "_test_mutierte_werte_bleiben_im_rahmen",
    "_test_wellen_wachsen",
    "_test_wellen_sind_reproduzierbar",
    "_test_wellen_bleiben_im_feld",
    "_test_wellen_zeiten_sortiert",
    "_test_wellen_dauer_im_rahmen",
    "_test_wellen_treffen_ihr_budget",
    "_test_zaehigkeit_steigt",
    "_test_druck_steigt_und_bleibt_im_rahmen",
    "_test_ausbau_verschlechtert_nie",
    "_test_kammern_treffen_die_sollkurve",
    "_test_kammern_tabelle_vollstaendig",
    "_test_kammerkosten_und_zeiten_steigen",
    "_test_einkommen_haelt_mit_den_kosten_schritt",
    "_test_bau_passt_zwischen_zwei_besuche",
    "_test_grosse_zahlen_bleiben_lesbar",
    "_test_erste_woche_ohne_wartemauer",
    "_test_schacht_deckelt_die_kolonie",
    "_test_grabentiefe_folgt_der_sollkurve",
    "_test_grabentiefe_deckelt_den_fortschritt",
    "_test_tagesstroemung_ist_je_tag_gedeckelt",
    "_test_stand_uebersteht_das_sichern",
    "_test_zuchtkalender_laeuft_einmal_und_endet_auf_einer_linie",
    "_test_kammerausbau_verschlechtert_nie",
    "_test_jeder_abschnitt_hat_namen_und_hinweis",
    "_test_erster_abschnitt_bleibt_ruhig",
    "_test_regeln_bleiben_in_ihren_grenzen",
    "_test_regeln_sind_reproduzierbar",
    "_test_wirkungsgrad_faellt_mit_den_regeln",
    "_test_wellenstaerke_folgt_dem_wirkungsgrad",
    "_test_geister_stehen_gestaffelt",
    "_test_geisterleiter_beginnt_frueh",
    "_test_eigener_platz_folgt_der_tiefe",
    "_test_polyp_kosten_steigen",
    "_test_abschnitt",
    "_test_erste_wellen_sind_ueberstehbar",
    "_test_polypen_verbessern_nie_nichts",
]

var _fehler: PackedStringArray = []


func _init() -> void:
    var vollstaendig := _pruefe_vollstaendigkeit()

    var gruen := 0
    for name in TESTS:
        var ergebnis: Variant = call(name)
        if ergebnis == true:
            gruen += 1
        elif ergebnis == null:
            _fehler.append("%s: abgebrochen (Laufzeitfehler oder kein return true)" % name)
        else:
            _fehler.append("%s: fehlgeschlagen" % name)

    print("")
    print("%d/%d Tests gruen" % [gruen, TESTS.size()])
    for f in _fehler:
        print("  FEHLER  " + f)

    if _fehler.is_empty() and vollstaendig:
        print("Alles in Ordnung.")
        quit(0)
    else:
        quit(1)


## Wachter: jede `_test_`-Methode dieses Skripts muss in TESTS stehen.
func _pruefe_vollstaendigkeit() -> bool:
    var fehlend := PackedStringArray()
    for m in get_method_list():
        var name: String = m["name"]
        if name.begins_with("_test_") and not TESTS.has(name):
            fehlend.append(name)
    if fehlend.is_empty():
        return true
    for name in fehlend:
        _fehler.append("%s steht nicht in TESTS und wurde nie aufgerufen" % name)
    return false


func _melde(bedingung: bool, was: String) -> bool:
    if not bedingung:
        _fehler.append("  -> " + was)
    return bedingung


# --- Schlund: Lichtkegel ---------------------------------------------------

func _test_beleuchtung_mitte() -> bool:
    var hell := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, 0.3, 500.0,
        Vector2(0.0, -100.0))
    return _melde(is_equal_approx(hell, 1.0),
        "Mitte des Kegels muss voll hell sein, war %f" % hell)


func _test_beleuchtung_ausserhalb() -> bool:
    var spitze := Vector2.ZERO
    var zu_weit := Schlund.beleuchtung(spitze, Vector2.UP, 0.3, 500.0,
        Vector2(0.0, -501.0))
    var daneben := Schlund.beleuchtung(spitze, Vector2.UP, 0.3, 500.0,
        Vector2(400.0, -100.0))
    var dahinter := Schlund.beleuchtung(spitze, Vector2.UP, 0.3, 500.0,
        Vector2(0.0, 100.0))
    return _melde(zu_weit == 0.0, "ausserhalb der Reichweite muss 0 sein") \
        and _melde(daneben == 0.0, "ausserhalb des Winkels muss 0 sein") \
        and _melde(dahinter == 0.0, "hinter dem Waechter muss 0 sein")


func _test_beleuchtung_faellt_zum_rand() -> bool:
    var winkel := 0.4
    var mitte := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, winkel, 500.0,
        Vector2(0.0, -200.0))
    var schraeg := Vector2.UP.rotated(winkel * 0.95) * 200.0
    var rand := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, winkel, 500.0, schraeg)
    return _melde(rand < mitte, "Rand muss dunkler sein als Mitte (%f >= %f)"
        % [rand, mitte]) and _melde(rand >= 0.0, "nie negativ")


func _test_beleuchtung_faellt_in_die_tiefe() -> bool:
    var nah := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, 0.3, 500.0,
        Vector2(0.0, -200.0))
    var fern := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, 0.3, 500.0,
        Vector2(0.0, -480.0))
    return _melde(fern < nah, "fern muss dunkler sein als nah (%f >= %f)" % [fern, nah])


func _test_beleuchtung_entartet() -> bool:
    var ohne_reichweite := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, 0.3, 0.0,
        Vector2(0.0, -10.0))
    var ohne_winkel := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, 0.0, 500.0,
        Vector2(0.0, -100.0))
    var ohne_richtung := Schlund.beleuchtung(Vector2.ZERO, Vector2.ZERO, 0.3, 500.0,
        Vector2(0.0, -100.0))
    var auf_der_spitze := Schlund.beleuchtung(Vector2.ZERO, Vector2.UP, 0.3, 500.0,
        Vector2.ZERO)
    return _melde(ohne_reichweite == 0.0, "Reichweite 0 muss 0 liefern") \
        and _melde(ohne_winkel == 0.0, "Winkel 0 muss 0 liefern") \
        and _melde(ohne_richtung == 0.0, "Richtung 0 muss 0 liefern") \
        and _melde(auf_der_spitze == 1.0, "auf der Spitze muss voll hell sein")


func _test_getroffen_stimmt_mit_beleuchtung() -> bool:
    # Die Zusicherung aus schlund.gd: was leuchtet, trifft. Ohne diesen Test
    # koennten Anzeige und Wirkung auseinanderlaufen.
    var rng := RandomNumberGenerator.new()
    rng.seed = 4711
    for _i in 400:
        var p := Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-800.0, 400.0))
        var richtung := Vector2.UP.rotated(rng.randf_range(-1.2, 1.2))
        var hell := Schlund.beleuchtung(Graben.WAECHTER, richtung,
            Graben.HALBWINKEL, Graben.REICHWEITE, p)
        var trifft := Schlund.getroffen(Graben.WAECHTER, richtung,
            Graben.HALBWINKEL, Graben.REICHWEITE, p)
        if trifft != (hell > 0.02):
            return _melde(false, "getroffen() weicht von beleuchtung() ab bei %s" % p)
    return true


func _test_brennende_nimmt_die_hellsten() -> bool:
    var hell := PackedFloat32Array([0.1, 0.9, 0.5, 0.7, 0.2])
    var treffer := Schlund.brennende(hell, 3)
    if not _melde(treffer.size() == 3, "drei Ziele erwartet, waren %d" % treffer.size()):
        return false
    return _melde(treffer[0] == 1 and treffer[1] == 3 and treffer[2] == 2,
        "absteigend nach Helligkeit erwartet, war %s" % str(treffer))


func _test_brennende_laesst_dunkles_aus() -> bool:
    var hell := PackedFloat32Array([0.0, 0.4, 0.0, 0.0])
    var treffer := Schlund.brennende(hell, 3)
    return _melde(treffer.size() == 1 and treffer[0] == 1,
        "nur der eine beleuchtete Eintrag darf brennen, war %s" % str(treffer))


func _test_brennende_entartet() -> bool:
    var leer := Schlund.brennende(PackedFloat32Array(), 3)
    var ohne_ziele := Schlund.brennende(PackedFloat32Array([0.5, 0.9]), 0)
    var mehr_ziele := Schlund.brennende(PackedFloat32Array([0.5, 0.9]), 9)
    return _melde(leer.is_empty(), "leere Liste muss leer bleiben") \
        and _melde(ohne_ziele.is_empty(), "null Ziele muss leer liefern") \
        and _melde(mehr_ziele.size() == 2,
            "mehr Ziele als Eintraege darf nicht ueberlaufen")


func _test_kegel_wird_nicht_staerker_durch_masse() -> bool:
    # Der Fehler, den der Wellenpruefer aufgedeckt hat: ohne Zielgrenze wuchs
    # die Gesamtleistung des Kegels mit der Zahl der Gegner, und grosse Wellen
    # waren leichter als kleine. Dieser Test haelt die Grenze fest.
    var wenige := PackedFloat32Array([1.0, 1.0])
    var viele := PackedFloat32Array()
    for _i in 200:
        viele.append(1.0)
    var a := Schlund.brennende(wenige, Graben.ZIELE).size()
    var b := Schlund.brennende(viele, Graben.ZIELE).size()
    return _melde(a <= Graben.ZIELE and b <= Graben.ZIELE,
        "nie mehr als %d Ziele, waren %d und %d" % [Graben.ZIELE, a, b]) \
        and _melde(b == Graben.ZIELE,
            "bei Ueberangebot muessen alle Ziele belegt sein, waren %d" % b)


func _test_schlieren_bleiben_schmuck() -> bool:
    # Die zweite Zusicherung des Projekts lautet: was hell gezeichnet wird,
    # macht Schaden. `kegel.gd::_schlieren()` legt ein wanderndes Streiflicht
    # darueber - Wasser vor dem Licht, nicht mehr Licht. Damit das eine
    # Verzierung bleibt und keine zweite Wahrheit, muss es zwei Dinge tun:
    # eng um 1.0 schwanken und sich ueber die Flaeche zu null mitteln.
    #
    # Geprueft wird an den Konstanten, nicht am Bild: der Kegel ist ein
    # Szenenknoten und laeuft im Testlauf nicht.
    var kegel := load("res://scripts/spiel/kegel.gd")
    var tiefe: float = kegel.SCHLIEREN_TIEFE + kegel.SCHLIEREN_TIEFE_FEIN
    if not _melde(tiefe <= 0.20,
            "die Schlieren aendern die Deckung um %.0f %% - ueber 20 %% ist "
            % (tiefe * 100.0) + "das keine Verzierung mehr"):
        return false

    # Und der Umlauf muss nahtlos sein. `flackern` laeuft mit fmod(..., TAU)
    # um; bei einem krummen Vielfachen springt das Argument bei jedem Umlauf
    # um einen Bruchteil der Periode, und ein Riss laeuft durch den Kegel.
    #
    # Geprueft wird die **Eigenschaft**, nicht der Wortlaut: hier stand
    # zuerst eine Liste erwarteter Zeichenketten, und die schlug fehl, sobald
    # jemand einen Faktor von 2.0 auf 1.0 setzte - also bei einer Aenderung,
    # die genau nichts kaputtmacht. Ein Test, der beim Aufraeumen rot wird,
    # wird beim naechsten Mal abgeschaltet statt gelesen.
    var quelle := FileAccess.get_file_as_string("res://scripts/spiel/kegel.gd")
    var suche := RegEx.new()
    suche.compile("flackern\\s*\\*\\s*([0-9]+\\.?[0-9]*)")
    var treffer := suche.search_all(quelle)
    if not _melde(treffer.size() >= 2,
            "in kegel.gd steht kein Vielfaches von flackern mehr - dann "
            + "prueft dieser Test nichts"):
        return false
    for t in treffer:
        var faktor := float(t.get_string(1))
        if not _melde(is_equal_approx(faktor, roundf(faktor)),
                "flackern * %s ist kein ganzes Vielfaches - der Umlauf springt"
                % t.get_string(1)):
            return false
    return true


func _test_zielrichtung() -> bool:
    var r := Schlund.zielrichtung(Vector2.ZERO, Vector2(0.0, -50.0))
    var ersatz := Schlund.zielrichtung(Vector2.ZERO, Vector2(0.0, 0.5), Vector2.RIGHT)
    return _melde(r.is_equal_approx(Vector2.UP), "gerade nach oben erwartet, war %s" % r) \
        and _melde(ersatz == Vector2.RIGHT, "Ersatzrichtung bei Finger auf der Spitze")


func _test_drehung_begrenzt() -> bool:
    # Eine halbe Umdrehung in einem Bildschritt darf nicht durchgehen.
    var neu := Schlund.gedreht(Vector2.UP, Vector2.DOWN, 4.0, 1.0 / 60.0)
    var winkel := absf(angle_difference(Vector2.UP.angle(), neu.angle()))
    return _melde(winkel <= 4.0 / 60.0 + 0.001,
        "Drehung ueberschreitet das Tempo: %f" % winkel)


func _test_drehung_erreicht_ziel() -> bool:
    var r := Vector2.UP
    for _i in 200:
        r = Schlund.gedreht(r, Vector2.RIGHT, 7.0, 1.0 / 30.0)
    return _melde(r.is_equal_approx(Vector2.RIGHT),
        "Drehung muss das Ziel erreichen und dort bleiben, war %s" % r)


# --- Schlund: Bahnen -------------------------------------------------------

func _test_bahn_endet_an_der_brut() -> bool:
    var start := Vector2(100.0, Graben.EINTRITT_Y)
    var spaet := Schlund.bahn(start, Graben.BRUT_Y, 90.0, 20.0, 2.0, 0.0, 999.0)
    return _melde(is_equal_approx(spaet.y, Graben.BRUT_Y),
        "Bahn darf die Brut nicht durchsinken, war y=%f" % spaet.y)


func _test_laufzeit() -> bool:
    var t := Schlund.laufzeit(-100.0, 100.0, 50.0)
    var stillstand := Schlund.laufzeit(-100.0, 100.0, 0.0)
    return _melde(is_equal_approx(t, 4.0), "4 Sekunden erwartet, waren %f" % t) \
        and _melde(stillstand == INF, "Tempo 0 muss unendlich liefern")


# --- Arten -----------------------------------------------------------------

func _test_arten_tabelle_vollstaendig() -> bool:
    var felder: PackedStringArray = ["name", "leben", "tempo", "radius",
        "wucht", "schlaengel", "takt", "farbe", "ab_welle", "regel", "kennung"]
    if not _melde(Arten.TABELLE.size() == Arten.Art.size(),
            "TABELLE und enum Art muessen gleich gross sein"):
        return false

    # Und in derselben **Reihenfolge**. Gleiche Groesse allein hat nicht
    # gereicht: die Schlundmutter stand in der Tabelle vor dem Sprungaal und
    # im enum dahinter. Jeder Zugriff ueber `Arten.Art.SPRUNGAAL` traf danach
    # die Schlundmutter - im Bestiarium ein leeres Zeichen, im Spiel das
    # falsche Tier.
    #
    # Verglichen wird die Kennung, nicht der angezeigte Name: der steht in
    # der Sprache des Spielers, die Bezeichner bleiben deutsch.
    var schluessel := Arten.Art.keys()
    for i in Arten.zahl():
        var erwartet := String(schluessel[i])
        var kennung := String(Arten.art(i)[&"kennung"])
        if not _melde(kennung == erwartet,
                "Platz %d traegt die Kennung %s, das enum sagt %s"
                % [i, kennung, erwartet]):
            return false
    for i in Arten.TABELLE.size():
        for f in felder:
            if not Arten.TABELLE[i].has(StringName(f)):
                return _melde(false, "Art %d fehlt das Feld %s" % [i, f])
        if not _melde(Arten.leben(i) > 0.0, "Art %d braucht Leben > 0" % i):
            return false
        if not _melde(Arten.tempo(i) > 0.0, "Art %d braucht Tempo > 0" % i):
            return false
        if not _melde(Arten.wucht(i) > 0, "Art %d braucht Wucht > 0" % i):
            return false
    return true


func _test_arten_erst_ab_ihrer_welle() -> bool:
    var erste := Arten.verfuegbar(1)
    if not _melde(erste.size() >= 1, "Welle 1 braucht mindestens eine Art"):
        return false
    for i in erste:
        if not _melde(int(Arten.art(i)[&"ab_welle"]) <= 1,
                "Art %d darf in Welle 1 nicht vorkommen" % i):
            return false
    # Alle Arten ausser dem Leitwesen - das wird nie gewuerfelt, sondern von
    # `Wellen.auftritte()` an die Abschnittsenden gesetzt.
    var leitwesen := 0
    for i in Arten.zahl():
        if Arten.ist_leitwesen(i):
            leitwesen += 1
    if not _melde(leitwesen == 1, "es muss genau ein Leitwesen geben, nicht %d" % leitwesen):
        return false

    var spaet := Arten.verfuegbar(Graben.ZYKLUS)
    return _melde(spaet.size() == Arten.zahl() - leitwesen,
        "in der letzten Welle muessen alle wuerfelbaren Arten verfuegbar sein")


# --- Wellen ----------------------------------------------------------------

func _test_arten_verhalten_bleibt_im_rahmen() -> bool:
    # Die vier Eigenschaften der spaeten Arten haben Grenzen, hinter denen sie
    # nicht mehr Entwurf, sondern Fehler sind.
    for i in Arten.zahl():
        var name := Arten.name_von(i)
        if not _melde(Arten.stoss(i) <= Schlund.STOSS_DECKEL,
                "%s: ein Schub ueber %.2f liesse sie rueckwaerts schwimmen"
                % [name, Schlund.STOSS_DECKEL]):
            return false
        if not _melde(Arten.mindest_licht(i) >= 0.0 and Arten.mindest_licht(i) < 1.0,
                "%s: eine Mindesthelligkeit ab 1.0 waere unverwundbar" % name):
            return false
        if not _melde(Arten.drift(i) >= 0.0, "%s: negative Drift" % name):
            return false
        if not _melde(Arten.panzer(i) >= 0.0, "%s: negativer Panzer" % name):
            return false
        if not _melde(Arten.aufwand(i) >= 1.0,
                "%s: eine Art darf nie weniger kosten als ihr Leben" % name):
            return false

        # Und keine Art darf gegen den vollen Kegel unverwundbar sein - sonst
        # steht der Spieler vor einem Gegner, den er nicht toeten kann.
        var voll := Schlund.schaden_an(Graben.LEISTUNG, 1.0,
            Arten.panzer(i), Arten.mindest_licht(i))
        if not _melde(voll > 0.0, "%s: der Grundkegel kommt gar nicht durch" % name):
            return false
    return true


func _test_mutationen_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Mutationen.NAMEN.size(),
        "HINWEISE": Mutationen.HINWEISE.size(),
        "WIRKUNGSGRAD": Mutationen.WIRKUNGSGRAD.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Mutationen.Mutation.size(),
                "%s hat %d Eintraege, das enum %d"
                % [was, laengen[was], Mutationen.Mutation.size()]):
            return false
    for m in Mutationen.Mutation.size():
        if not _melde(not Mutationen.name_von(m).is_empty()
                and not Mutationen.hinweis(m).is_empty(),
                "Mutation %d braucht Namen und Hinweis" % m):
            return false
        # Ohne Kopplung an die Wellenstaerke ist jede Mutation eine Wand -
        # dieselbe Lehre wie bei den Abschnittsregeln, wo genau dieses
        # Versaeumnis fuenf gefallene Sitzungen ab Welle 36 gekostet hat.
        var w := Mutationen.WIRKUNGSGRAD[m]
        if not _melde(w > 0.5 and w <= 1.0,
                "%s hat einen Wirkungsgrad von %.2f - das ist keine Kurve mehr"
                % [Mutationen.name_von(m), w]):
            return false
    return true


func _test_mutationen_erst_ab_der_zweiten_umdrehung() -> bool:
    # Wer die Arten noch nicht kennt, kann nicht sehen, was an ihnen anders
    # ist. Eine Mutation in der Lernphase waere keine Abwechslung, sondern
    # eine unerklaerliche Niederlage.
    for n in range(1, Graben.ZYKLUS + 1):
        if not _melde(Mutationen.in_welle(n).is_empty(),
                "Welle %d traegt schon eine Mutation" % n):
            return false
    if not _melde(not Mutationen.in_welle(Graben.ZYKLUS + 1).is_empty(),
            "die zweite Umdrehung muss mutieren, sonst aendert sich nie etwas"):
        return false
    return _melde(Mutationen.zahl_in(Graben.ZYKLUS * 9) == Mutationen.HOECHSTENS,
        "tief unten muessen es %d Zuege sein" % Mutationen.HOECHSTENS)


func _test_mutationen_sind_reproduzierbar() -> bool:
    # Derselbe Grund wie bei der Zusammensetzung der Welle: der Wellenpruefer
    # muss dieselbe Welle durchrechnen koennen, die beim Spieler ankommt, und
    # alle Spieler sollen dieselbe Welle 137 sehen.
    for n in range(Graben.ZYKLUS, Graben.ZYKLUS * 4, 7):
        var a := Mutationen.in_welle(n)
        var b := Mutationen.in_welle(n)
        if not _melde(a == b, "Welle %d mutiert zweimal verschieden" % n):
            return false
        if not _melde(a.size() <= Mutationen.HOECHSTENS,
                "Welle %d traegt %d Zuege" % [n, a.size()]):
            return false
        var gesehen := PackedInt32Array()
        for m in a:
            if not _melde(not gesehen.has(m),
                    "Welle %d traegt %s doppelt" % [n, Mutationen.name_von(m)]):
                return false
            gesehen.append(m)
    return true


func _test_mutierte_werte_bleiben_im_rahmen() -> bool:
    # Eine Mutation, die den Panzer ueber die Leistung des Kegels hebt, macht
    # die Welle unbesiegbar - und zwar lautlos: `Schlund.schaden_an` gibt
    # dann einfach null zurueck.
    for n in range(Graben.ZYKLUS + 1, Graben.ZYKLUS * 5, 13):
        var kegel := Graben.LEISTUNG * Ausbau.leistung_faktor(n)
        for i in Arten.zahl():
            var name := Arten.name_von(i)
            if not _melde(Wellen.panzer_in(i, n) < kegel * 0.6,
                    "%s in Welle %d: Panzer %.1f gegen Kegel %.1f"
                    % [name, n, Wellen.panzer_in(i, n), kegel]):
                return false
            if not _melde(Wellen.mindest_licht_in(i, n) < 1.0,
                    "%s in Welle %d braucht Helligkeit %.2f - die gibt es nicht"
                    % [name, n, Wellen.mindest_licht_in(i, n)]):
                return false
            if not _melde(Wellen.stoss_in(i, n) <= Schlund.STOSS_DECKEL,
                    "%s in Welle %d stoesst ueber den Deckel" % [name, n]):
                return false
            if not _melde(Wellen.tempo_in(i, n) > 0.0
                    and Wellen.radius_in(i, n) > 0.0,
                    "%s in Welle %d hat Tempo oder Radius <= 0" % [name, n]):
                return false
    return true


func _test_bahn_bleibt_im_bild_und_sinkt() -> bool:
    # Zwei Zusicherungen an einem Weg: er verlaesst das Bild nicht, und er
    # geht nie rueckwaerts. Der Schub war genau dafuer der Verdachtsfall.
    var halb := Graben.FELD.size.x * 0.5
    for i in Arten.zahl():
        var a := Arten.art(i)
        for phase: float in [0.0, 1.4, 3.1, 4.8]:
            for start: float in [-Graben.EINTRITT_SEITE, 0.0, Graben.EINTRITT_SEITE]:
                var vorher := -INF
                var t := 0.0
                while t < 40.0:
                    var p := Schlund.bahn(Vector2(start, Graben.EINTRITT_Y),
                        Graben.BRUT_Y, a[&"tempo"], a[&"schlaengel"], a[&"takt"],
                        phase, t, Arten.drift(i), Arten.stoss(i))
                    if not _melde(absf(p.x) <= halb,
                            "%s verlaesst das Bild bei %.1f s: x=%.1f"
                            % [Arten.name_von(i), t, p.x]):
                        return false
                    if not _melde(p.y >= vorher - 0.001,
                            "%s schwimmt bei %.1f s rueckwaerts" % [Arten.name_von(i), t]):
                        return false
                    vorher = p.y
                    t += 0.05
    return true


func _test_haut_schluckt_schwache_quellen() -> bool:
    # Panzer: ein fester Betrag je Sekunde geht ab. Genau das macht einen
    # Wehrpolypen gegen eine Schildkoralle stumpf.
    if not _melde(is_equal_approx(Schlund.schaden_an(30.0, 1.0, 0.0, 0.0), 30.0),
            "ohne Haut muss der volle Schaden ankommen"):
        return false
    if not _melde(is_equal_approx(Schlund.schaden_an(30.0, 1.0, 12.0, 0.0), 18.0),
            "der Panzer muss genau seinen Betrag abziehen"):
        return false
    if not _melde(is_equal_approx(Schlund.schaden_an(8.0, 1.0, 12.0, 0.0), 0.0),
            "eine Quelle unter dem Panzer darf nichts ausrichten"):
        return false

    # Mindesthelligkeit: am Rand des Kegels passiert nichts, im Kern alles.
    if not _melde(is_equal_approx(Schlund.schaden_an(30.0, 0.4, 0.0, 0.5), 0.0),
            "unter der Mindesthelligkeit darf kein Schaden entstehen"):
        return false
    return _melde(Schlund.schaden_an(30.0, 0.6, 0.0, 0.5) > 0.0,
        "ueber der Mindesthelligkeit muss Schaden entstehen")


func _test_leitwesen_stehen_an_den_abschnittsenden() -> bool:
    # Genau eines je Abschnittsende, sonst keines. Waeren sie Teil der
    # normalen Auswahl, kaeme irgendwann eine Welle aus lauter Leitwesen - und
    # aus sechs Hoehepunkten wuerde Rauschen.
    var leit := Arten.leitwesen()
    if not _melde(leit >= 0, "es gibt kein Leitwesen"):
        return false

    for n in range(1, Graben.ZYKLUS + 1):
        var zahl := 0
        for a in Wellen.auftritte(n):
            if int(a[&"art"]) == leit:
                zahl += 1
        var soll := 1 if Wellen.hat_leitwesen(n) else 0
        if not _melde(zahl == soll,
                "Welle %d hat %d Leitwesen statt %d" % [n, zahl, soll]):
            return false

    # Und es waechst mit der Welle, statt spaeter zur Randnotiz zu werden.
    var frueh := Wellen.leben_in(leit, Graben.WELLEN_JE_ABSCHNITT)
    var spaet := Wellen.leben_in(leit, Graben.ZYKLUS)
    if not _melde(spaet > frueh * 2.0,
            "das Leitwesen muss ueber 60 Wellen deutlich zulegen"):
        return false
    return _melde(Arten.wucht(leit) > Arten.wucht(Arten.Art.PANZERKREBS),
        "das Leitwesen muss haerter zuschlagen als jeder gewoehnliche Raeuber")


func _test_wellen_wachsen() -> bool:
    # Nicht die rohe Lebenspunktzahl waechst, sondern der **Anspruch**.
    #
    # An jeder Abschnittsgrenze faellt die Zahl der Raeuber, weil die neue
    # Regel dem Spieler Leistung abzieht - Welle 21 hat weniger Leben als
    # Welle 20 und ist trotzdem schwerer. Wer hier die rohe Staerke prueft,
    # zwingt die Wellen dazu, die Regeln zu ignorieren.
    for n in range(1, Graben.ZYKLUS):
        var jetzt := Wellen.staerke(n) / maxf(0.0001, Regeln.wirkungsgrad(n))
        var danach := Wellen.staerke(n + 1) / maxf(0.0001, Regeln.wirkungsgrad(n + 1))
        if not _melde(danach > jetzt,
                "Welle %d verlangt nicht mehr als %d" % [n + 1, n]):
            return false

    # Ueber die ganze Strecke muss auch die rohe Zahl deutlich steigen -
    # sonst waeren die Abschnitte das einzige Wachstum.
    return _melde(Wellen.staerke(Graben.ZYKLUS) > Wellen.staerke(1) * 8.0,
        "die letzte Welle muss um ein Vielfaches groesser sein als die erste")


func _test_wellen_sind_reproduzierbar() -> bool:
    # Der Wellenpruefer rechnet nur dann das Spiel durch, wenn zweimal
    # dieselbe Welle herauskommt.
    for n in [1, 7, 23, 60]:
        var a := Wellen.auftritte(n)
        var b := Wellen.auftritte(n)
        if not _melde(a.size() == b.size(), "Welle %d hat wechselnde Groesse" % n):
            return false
        for i in a.size():
            if a[i] != b[i]:
                return _melde(false, "Welle %d weicht bei Eintrag %d ab" % [n, i])
    return true


func _test_wellen_bleiben_im_feld() -> bool:
    for n in range(1, Graben.ZYKLUS + 1):
        for a in Wellen.auftritte(n):
            var x: float = a[&"x"]
            if absf(x) > Graben.EINTRITT_SEITE + 0.001:
                return _melde(false, "Welle %d tritt bei x=%f ausserhalb ein" % [n, x])
            var art: int = a[&"art"]
            if art < 0 or art >= Arten.zahl():
                return _melde(false, "Welle %d nennt Art %d" % [n, art])
    return true


func _test_wellen_zeiten_sortiert() -> bool:
    for n in range(1, Graben.ZYKLUS + 1):
        var liste := Wellen.auftritte(n)
        for i in range(1, liste.size()):
            if liste[i][&"zeit"] < liste[i - 1][&"zeit"]:
                return _melde(false, "Welle %d ist nicht nach Zeit sortiert" % n)
    return true


func _test_wellen_dauer_im_rahmen() -> bool:
    # Im Konzept steht: 40 bis 70 Sekunden je Welle. Steht es nur dort und
    # nicht im Code, weicht es irgendwann ab.
    for n in range(1, Graben.ZYKLUS + 1):
        var d := Wellen.dauer(n)
        if d < 40.0 or d > 70.0:
            return _melde(false, "Welle %d dauert %.1f s, erlaubt sind 40-70" % [n, d])
    return true


func _test_wellen_treffen_ihr_budget() -> bool:
    for n in range(1, Graben.ZYKLUS + 1):
        var summe := Wellen.lebenssumme(n)
        var soll := Wellen.staerke(n)
        if not _melde(summe > 0.0, "Welle %d ist leer" % n):
            return false
        # Nach unten darf das Budget aufgehen, nach oben nie ueberzogen werden.
        if summe > soll + 0.001:
            return _melde(false, "Welle %d ueberzieht ihr Budget: %.1f > %.1f"
                % [n, summe, soll])
        if summe < soll * 0.65:
            return _melde(false, "Welle %d schoepft ihr Budget kaum aus: %.1f von %.1f"
                % [n, summe, soll])
    return true


func _test_zaehigkeit_steigt() -> bool:
    for n in range(1, Graben.ZYKLUS):
        if not _melde(Wellen.zaehigkeit(n + 1) > Wellen.zaehigkeit(n),
                "Zaehigkeit faellt zwischen Welle %d und %d" % [n, n + 1]):
            return false
    return _melde(is_equal_approx(Wellen.zaehigkeit(1), 1.0),
        "Welle 1 muss die Grundwerte der Arten benutzen")


func _test_druck_steigt_und_bleibt_im_rahmen() -> bool:
    for n in range(1, Graben.ZYKLUS + 1):
        var d := Wellen.druck(n)
        if d <= 0.0 or d > 1.0:
            return _melde(false, "Druck in Welle %d liegt bei %.2f" % [n, d])
    return _melde(Wellen.druck(Graben.ZYKLUS) > Wellen.druck(1) * 2.0,
        "der Druck muss ueber 60 Wellen deutlich anziehen")


func _test_ausbau_verschlechtert_nie() -> bool:
    # Dieselbe Zusicherung wie bei den HYPHA-Myzelknoten, nur eine Ebene
    # hoeher: kein Wert der Sollkurve darf mit der Wellennummer fallen. Sonst
    # waere die geprueft Ueberstehbarkeit spaeterer Wellen wertlos.
    for n in range(1, Graben.ZYKLUS):
        var paare := {
            "Leistung": [Ausbau.leistung_faktor(n), Ausbau.leistung_faktor(n + 1)],
            "Ziele": [float(Ausbau.ziele(n)), float(Ausbau.ziele(n + 1))],
            "Reichweite": [Ausbau.reichweite_faktor(n), Ausbau.reichweite_faktor(n + 1)],
            "Winkel": [Ausbau.winkel_faktor(n), Ausbau.winkel_faktor(n + 1)],
            "Polypen": [float(Ausbau.polypen(n)), float(Ausbau.polypen(n + 1))],
            "Durchsatz": [Ausbau.durchsatz(n), Ausbau.durchsatz(n + 1)],
        }
        for was in paare:
            var werte: Array = paare[was]
            if werte[1] < werte[0]:
                return _melde(false, "%s faellt zwischen Welle %d und %d"
                    % [was, n, n + 1])
    return true


# --- Graben ----------------------------------------------------------------

func _test_polyp_kosten_steigen() -> bool:
    for i in range(Graben.NISCHEN.size() - 1):
        if not _melde(Graben.polyp_kosten(i + 1) > Graben.polyp_kosten(i),
                "Polyp %d kostet nicht mehr als %d" % [i + 1, i]):
            return false
    return true


func _test_abschnitt() -> bool:
    return _melde(Graben.abschnitt(1) == 0, "Welle 1 gehoert in Abschnitt 0") \
        and _melde(Graben.abschnitt(Graben.WELLEN_JE_ABSCHNITT) == 0,
            "letzte Welle des ersten Abschnitts gehoert noch in Abschnitt 0") \
        and _melde(Graben.abschnitt(Graben.WELLEN_JE_ABSCHNITT + 1) == 1,
            "danach beginnt Abschnitt 1") \
        and _melde(Graben.abschnitt(Graben.ZYKLUS) == 5,
            "die letzte Welle gehoert in Abschnitt 5")


# --- Balance ---------------------------------------------------------------

func _test_erste_wellen_sind_ueberstehbar() -> bool:
    # Kurze Fassung des Wellenpruefers, damit ein grober Balance-Bruch schon
    # im Testlauf auffaellt und nicht erst im eigenen Werkzeug.
    var lauf := Simulation.sitzung(1)
    if not _melde(lauf.size() == Graben.WELLEN_JE_SITZUNG,
            "die erste Sitzung muss vollstaendig durchlaufen"):
        return false
    for e in lauf:
        if not _melde(e.ueberstanden, "Welle %d faellt mit Grundwerten" % e.welle):
            return false
    return _melde(lauf[0].durchgelassen == 0,
        "in Welle 1 darf mit vernuenftigem Spiel nichts durchkommen, es waren %d"
        % lauf[0].durchgelassen)


func _test_polypen_verbessern_nie_nichts() -> bool:
    # Dasselbe Versprechen wie bei HYPHA fuer die Myzel-Knoten: kein Ausbau
    # darf etwas verschlechtern. Sonst waere die geprueft Lösbarkeit wertlos.
    var ohne := Simulation.Zustand.new()
    var e_ohne := Simulation.welle(4, ohne)

    var mit := Simulation.Zustand.new()
    mit.polypen.append(Graben.NISCHEN[0])
    mit.polypen.append(Graben.NISCHEN[1])
    var e_mit := Simulation.welle(4, mit)

    return _melde(e_mit.brut_nachher >= e_ohne.brut_nachher,
        "Polypen duerfen die Brut nie schlechter stellen (%d < %d)"
        % [e_mit.brut_nachher, e_ohne.brut_nachher])

# --- Kammern ---------------------------------------------------------------

func _test_kammern_treffen_die_sollkurve() -> bool:
    # Die wichtigste Verbindung im Projekt: die Sollkurve sagt, wie stark der
    # Waechter bei Welle n sein soll; die Kammern sagen, wie er dorthin kommt.
    # Laufen beide auseinander, prueft der Wellenpruefer ein Spiel, das
    # niemand spielen kann.
    for n in range(1, Graben.ZYKLUS + 1):
        var stufe := Ausbau.stufe_soll(n)

        # Rundung auf ganze Stufen erlaubt hoechstens einen halben Schritt
        # Abweichung - mehr waere ein echtes Auseinanderlaufen.
        var toleranz_leistung := Kammern.LEISTUNG_JE_STUFE * 0.55
        if absf(Kammern.leistung_faktor(stufe) - Ausbau.leistung_faktor(n)) > toleranz_leistung:
            return _melde(false, "Leistung weicht bei Welle %d ab: Kammer %.3f, Soll %.3f"
                % [n, Kammern.leistung_faktor(stufe), Ausbau.leistung_faktor(n)])

        if absf(Kammern.reichweite_faktor(stufe) - Ausbau.reichweite_faktor(n)) > 0.02:
            return _melde(false, "Reichweite weicht bei Welle %d ab" % n)

        if absf(Kammern.winkel_faktor(stufe) - Ausbau.winkel_faktor(n)) > 0.02:
            return _melde(false, "Winkel weicht bei Welle %d ab" % n)

        # Hier stand einmal eine Toleranz von einem Ziel. Sie hat den Fehler
        # durchgelassen, der die Wellen 37 bis 48 unspielbar machte: die
        # Sollkurve verlangte dort sieben gleichzeitige Ziele, die Sollstufe
        # gab sechs her. Ein Ziel mehr oder weniger ist der spuerbarste
        # Unterschied im ganzen Spiel - dafuer gibt es keine Toleranz.
        if Kammern.ziele(stufe) != Ausbau.ziele(n):
            return _melde(false, "Ziele weichen bei Welle %d ab: Kammer %d, Soll %d"
                % [n, Kammern.ziele(stufe), Ausbau.ziele(n)])

    # Und an den Enden einer Umdrehung muss es exakt aufgehen. Frueher stand
    # hier die Hoechststufe; seit der Graben keinen Boden hat, ist die
    # Hoechststufe nur noch ein Deckel und `STUFEN_JE_ZYKLUS` das Tempo.
    return _melde(is_equal_approx(Kammern.leistung_faktor(0), Ausbau.leistung_faktor(1)),
            "Stufe 0 muss den Grundwerten entsprechen") \
        and _melde(Ausbau.stufe_soll(Graben.ZYKLUS) == Ausbau.STUFEN_JE_ZYKLUS,
            "eine volle Umdrehung muss genau STUFEN_JE_ZYKLUS Stufen verlangen") \
        and _melde(Kammern.HOECHSTSTUFE > Ausbau.STUFEN_JE_ZYKLUS,
            "der Kammerdeckel muss ueber eine Umdrehung hinausreichen")


func _test_kammern_tabelle_vollstaendig() -> bool:
    var felder: PackedStringArray = ["name", "zweck", "kosten", "wachstum", "zeit_faktor"]
    if not _melde(Kammern.TABELLE.size() == Kammern.Kammer.size(),
            "TABELLE und enum Kammer muessen gleich gross sein"):
        return false
    for i in Kammern.TABELLE.size():
        for f in felder:
            if not Kammern.TABELLE[i].has(StringName(f)):
                return _melde(false, "Kammer %d fehlt das Feld %s" % [i, f])
        if not _melde(not Kammern.zweck(i).is_empty(),
                "Kammer %d braucht einen erklaerten Zweck" % i):
            return false
    return true


func _test_kammerkosten_und_zeiten_steigen() -> bool:
    for i in Kammern.zahl():
        for stufe in range(Kammern.HOECHSTSTUFE - 1):
            if Kammern.kosten(i, stufe + 1) <= Kammern.kosten(i, stufe):
                return _melde(false, "%s wird auf Stufe %d nicht teurer"
                    % [Kammern.name_von(i), stufe + 1])
            if Kammern.bauzeit(i, stufe + 1) < Kammern.bauzeit(i, stufe):
                return _melde(false, "%s baut auf Stufe %d kuerzer als davor"
                    % [Kammern.name_von(i), stufe + 1])
    return true


func _test_einkommen_haelt_mit_den_kosten_schritt() -> bool:
    # **Der Fehler, an dem der endlose Graben zuerst gescheitert ist.**
    #
    # Kammern kosten geometrisch, das Filterbecken lieferte aber nur 1.26 je
    # Stufe und der Wellenertrag wuchs bloss linear. Zwei Kurven, von denen
    # eine geometrisch und die andere linear waechst, holen einander nie
    # wieder ein: bei Welle 45 kostete eine volle Kammerrunde fuenf Tage
    # Ertrag, bei Welle 120 dreitausend. Der Kolonielauf meldete dazu
    # sechs neue Kammerstufen zwischen Tag 40 und Tag 120 - ein Spiel, das
    # stehenbleibt.
    #
    # Geprueft wird deshalb nicht eine Zahl, sondern ihr Verhaeltnis: wie
    # viele Tage ein voller Kammerschritt kostet. Die Zahl darf sich ueber
    # hunderte Wellen nicht davonmachen.
    var kleinster := 99.0
    var groesster := 0.0
    for n in range(10, 400, 10):
        var stufe := Ausbau.stufe_soll(n)
        var aus_wellen := Wellen.ertrag(n) * float(Graben.WELLEN_JE_TAG)
        var aus_filter := Kammern.filter_je_stunde(stufe) * 24.0
        var tage := Kammern.rundenkosten(stufe) / maxf(1.0, aus_wellen + aus_filter)
        kleinster = minf(kleinster, tage)
        groesster = maxf(groesster, tage)
        if not _melde(tage < 4.0,
                "Welle %d: eine Kammerrunde kostet %.1f Tage Ertrag" % [n, tage]):
            return false
    return _melde(groesster / maxf(0.01, kleinster) < 5.0,
        "die Kurve laeuft auseinander: zwischen %.2f und %.2f Tagen je Runde"
        % [kleinster, groesster])


func _test_bau_passt_zwischen_zwei_besuche() -> bool:
    # Ein Bau, der laenger dauert als der Abstand zwischen zwei Besuchen,
    # verschiebt sich um eine ganze Sitzung: der Spieler kommt, es ist nichts
    # fertig, und er geht wieder. Bei genau acht Stunden Deckel und acht
    # Stunden Abstand meldete der Kolonielauf dafuer bis zu sechzehn Stunden
    # leere Sitzungen am Tag - bei voll laufender Kolonie.
    var abstand := 86400.0 / float(Graben.SITZUNGEN_JE_TAG)
    if not _melde(Kammern.ZEIT_DECKEL < abstand,
            "der Bauzeitdeckel (%.0f s) muss unter dem Sitzungsabstand (%.0f s) liegen"
            % [Kammern.ZEIT_DECKEL, abstand]):
        return false
    for i in Kammern.zahl():
        var z := Kammern.bauzeit(i, Kammern.HOECHSTSTUFE - 1)
        if not _melde(z < abstand,
                "%s baut auf der hoechsten Stufe %.0f s - laenger als eine Sitzung"
                % [Kammern.name_von(i), z]):
            return false
    return true


func _test_grosse_zahlen_bleiben_lesbar() -> bool:
    var paare := {
        0: "0", 42: "42", 9999: "9999",
        10000: "10.0K", 123456: "123K", 1234567: "1.23M",
        -2500000: "-2.50M",
    }
    for wert in paare:
        var soll: String = paare[wert]
        if not _melde(Zahl.kurz(wert) == soll,
                "Zahl.kurz(%d) ergab \"%s\", erwartet \"%s\""
                % [wert, Zahl.kurz(wert), soll]):
            return false
    # Und keine Zahl des Spiels darf die Anzeige sprengen: acht Zeichen sind
    # die Breite, die im Kopf des Koloniebildschirms Platz hat.
    var hoechste := int(Kammern.rundenkosten(Kammern.HOECHSTSTUFE))
    return _melde(Zahl.kurz(hoechste).length() <= 8,
        "die groesste Zahl des Spiels wird %d Zeichen breit: %s"
        % [Zahl.kurz(hoechste).length(), Zahl.kurz(hoechste)])


func _test_erste_woche_ohne_wartemauer() -> bool:
    # Aus dem Plan: die erste Woche fast ohne echte Wartezeit. Bauzeiten sind
    # der Grund, warum Spieler aufhoeren - wer in den ersten Stunden auf eine
    # Uhr starrt, kommt nicht wieder.
    for i in Kammern.zahl():
        for stufe in Kammern.ZEIT_SANFT_BIS:
            var z := Kammern.bauzeit(i, stufe)
            if z > Kammern.ZEIT_SANFT + 0.001:
                return _melde(false, "%s Stufe %d baut %.0f s - zu lang fuer den Einstieg"
                    % [Kammern.name_von(i), stufe + 1, z])
    var spaet := Kammern.bauzeit(Kammern.Kammer.LEUCHTORGAN, Kammern.HOECHSTSTUFE - 1)
    return _melde(spaet > Kammern.ZEIT_SANFT * 4.0,
        "spaete Stufen muessen echte Wartezeit kosten, waren %.0f s" % spaet)


func _test_schacht_deckelt_die_kolonie() -> bool:
    # Ohne Deckel liesse sich das Leuchtorgan allein hochziehen und alles
    # andere ignorieren - eine Kolonie mit einem einzigen sinnvollen Knopf.
    var ohne_schacht := Kammern.deckel(Kammern.Kammer.LEUCHTORGAN, 0)
    if not _melde(ohne_schacht < Kammern.HOECHSTSTUFE,
            "ohne Tiefenschacht darf keine Kammer voll ausbaubar sein"):
        return false
    if not _melde(Kammern.deckel(Kammern.Kammer.TIEFENSCHACHT, 0) == Kammern.HOECHSTSTUFE,
            "der Tiefenschacht selbst darf nicht von sich abhaengen"):
        return false
    if not _melde(not Kammern.ausbaubar(Kammern.Kammer.LEUCHTORGAN, ohne_schacht, 0),
            "am Deckel muss der Ausbau gesperrt sein"):
        return false
    return _melde(Kammern.deckel(Kammern.Kammer.LEUCHTORGAN, Kammern.HOECHSTSTUFE)
            == Kammern.HOECHSTSTUFE,
        "mit vollem Schacht muss jede Kammer die Hoechststufe erreichen")


func _test_grabentiefe_folgt_der_sollkurve() -> bool:
    # Der Tiefenschacht oeffnet den Graben, und zwar genau so weit, dass die
    # Sollstufe der letzten Welle des Abschnitts noch unter den Deckel passt.
    # Waere das Tor niedriger, liefe der Spieler in Wellen hinein, fuer die es
    # seine Kolonie nicht geben kann - genau der Fehler, den der Kolonielauf
    # als gefallene Sitzungen ab Welle 36 gemeldet hat.
    if not _melde(Ausbau.schacht_fuer_abschnitt(0) == 0,
            "der erste Abschnitt darf nichts verlangen"):
        return false

    var vorher := -1
    for a in Graben.ABSCHNITTE:
        var tor := Ausbau.schacht_fuer_abschnitt(a)
        if not _melde(tor > vorher or a == 0,
                "Abschnitt %d verlangt nicht mehr als der davor" % (a + 1)):
            return false
        vorher = tor
        if not _melde(tor <= Kammern.HOECHSTSTUFE,
                "Abschnitt %d verlangt eine Stufe, die es nicht gibt" % (a + 1)):
            return false

        var deckel := Kammern.deckel(Kammern.Kammer.LEUCHTORGAN, tor)
        var soll := Ausbau.stufe_soll(Graben.letzte_welle(a))
        if not _melde(deckel >= soll,
                "Abschnitt %d oeffnet bei Schacht %d, aber Welle %d verlangt Stufe %d"
                % [a + 1, tor, Graben.letzte_welle(a), soll]):
            return false

    # Und die Leiter darf nirgends zurueckfallen.
    var offen := 0
    for schacht in range(0, Kammern.HOECHSTSTUFE + 1):
        var jetzt := Ausbau.offene_welle(schacht)
        if not _melde(jetzt >= offen,
                "Schacht %d oeffnet weniger als %d" % [schacht, schacht - 1]):
            return false
        offen = jetzt
    # Der volle Schacht muss ueber die erste Umdrehung hinaus oeffnen - sonst
    # waere der Graben doch wieder zu Ende.
    return _melde(Ausbau.offene_welle(Kammern.HOECHSTSTUFE) > Graben.ZYKLUS,
        "der volle Schacht muss tiefer reichen als eine Umdrehung")


func _test_grabentiefe_deckelt_den_fortschritt() -> bool:
    # Der Fortschritt darf ueber den offenen Graben hinauszeigen - gespielt
    # wird trotzdem nur, was offen ist.
    var stand := KolonieStand.new()
    stand.hoechste_welle = Graben.ZYKLUS
    if not _melde(stand.naechste_welle() == Graben.WELLEN_JE_ABSCHNITT,
            "ohne Schacht darf nur der erste Abschnitt offen sein"):
        return false
    if not _melde(stand.graben_haelt(), "der Graben muesste hier halten"):
        return false
    if not _melde(stand.naechste_tiefe() == Ausbau.schacht_fuer_abschnitt(1),
            "die naechste Tiefe muss den zweiten Abschnitt nennen"):
        return false

    stand.stufen[Kammern.Kammer.TIEFENSCHACHT] = Kammern.HOECHSTSTUFE
    if not _melde(stand.naechste_welle() == Graben.ZYKLUS,
            "der Fortschritt darf nie ueber das Erreichte hinausgehen"):
        return false
    if not _melde(not stand.graben_haelt(), "der volle Schacht darf hier nichts halten"):
        return false
    # Und es gibt immer eine naechste Tiefe: der Graben hat keinen Boden.
    return _melde(stand.naechste_tiefe() > 0,
        "unter jedem Abschnitt muss ein weiterer liegen")


func _test_tagesstroemung_ist_je_tag_gedeckelt() -> bool:
    # Der Sinn der Tagesstroemung ist Wiederkommen, nicht Dauerspielen. Waere
    # sie je Sitzung gedeckelt statt je Tag, belohnte sie Sitzen.
    var stand := KolonieStand.new()
    stand.pruefe_tag()
    if not _melde(stand.stroemung_offen == Tagesstroemung.JE_TAG,
            "ein neuer Tag muss die Stroemung auffuellen"):
        return false

    var genutzt := 0
    while stand.nutze_stroemung():
        genutzt += 1
        if genutzt > Tagesstroemung.JE_TAG:
            return _melde(false, "die Stroemung geht nie aus")
    if not _melde(genutzt == Tagesstroemung.JE_TAG,
            "die Stroemung gab %d statt %d Wellen her" % [genutzt, Tagesstroemung.JE_TAG]):
        return false
    if not _melde(not stand.hat_stroemung(), "aufgebraucht heisst aufgebraucht"):
        return false

    # Und sie darf eine Ausbeute nie kleiner machen.
    for grund in [0, 1, 7, 250]:
        var mit := Tagesstroemung.ausbeute(grund, true)
        var ohne := Tagesstroemung.ausbeute(grund, false)
        if not _melde(ohne == grund and mit >= grund,
                "Ausbeute %d wird durch die Stroemung nicht besser" % grund):
            return false
    return _melde(Tagesstroemung.hinweis(0).is_empty(),
        "ohne offene Stroemung darf kein Hinweis stehen")


func _test_zuchtkalender_laeuft_einmal_und_endet_auf_einer_linie() -> bool:
    var stand := KolonieStand.new()
    stand.pruefe_tag()
    var vorher_linien := stand.linien.size()

    # Sieben Tage, sieben Abholungen - und je Tag genau eine.
    var geholt := 0
    var linien_geschenke := 0
    for durchlauf in Zuchtkalender.TAGE + 3:
        if not stand.kalender_offen():
            break
        var lohn := stand.hole_kalender()
        if not _melde(not lohn.is_empty(),
                "Tag %d gibt nichts her" % (durchlauf + 1)):
            return false
        if not _melde(stand.hole_kalender().is_empty(),
                "Tag %d liesse sich zweimal abholen" % (durchlauf + 1)):
            return false
        if lohn.has(&"linie"):
            linien_geschenke += 1
        geholt += 1
        # Der naechste Tag - sonst bleibt der Kalender heute zu.
        stand.tag += 1

    if not _melde(geholt == Zuchtkalender.TAGE,
            "der Kalender gab %d statt %d Tage her" % [geholt, Zuchtkalender.TAGE]):
        return false
    if not _melde(linien_geschenke == 1,
            "genau ein Tag muss eine Brutlinie geben, nicht %d" % linien_geschenke):
        return false
    if not _melde(stand.linien.size() == vorher_linien + 1,
            "die geschenkte Linie fehlt im Bestand"):
        return false
    if not _melde(stand.linie != Brutlinien.Linie.KEINE,
            "die geschenkte Linie muss auch die Wache uebernehmen"):
        return false

    # Und danach ist Schluss. Ein Kalender, der sich auffuellt, verschenkt
    # Brutlinien am laufenden Band.
    stand.tag += 1
    return _melde(not stand.kalender_offen(),
        "der Kalender laeuft ein zweites Mal")


func _test_stand_uebersteht_das_sichern() -> bool:
    # Ein Feld, das jemand einzubauen vergisst, faellt sonst erst dem Spieler
    # auf - und zwar daran, dass sein Fortschritt weg ist.
    var stand := KolonieStand.new()
    stand.stufen[Kammern.Kammer.LEUCHTORGAN] = 7
    stand.stufen[Kammern.Kammer.TIEFENSCHACHT] = 5
    stand.naehrstoffe = 4321
    stand.hoechste_welle = 33
    stand.linien.append(Brutlinien.Linie.STROMSINN)
    stand.linie = Brutlinien.Linie.STROMSINN
    stand.bau_kammer = Kammern.Kammer.FILTERBECKEN
    stand.bau_fertig_um = 12345.5
    stand.zuletzt_gesehen = 999.25
    stand.tag = 20260829
    stand.strecke = 6
    stand.stroemung_offen = 1
    stand.kalender = 3
    stand.kalender_tag = 20260828
    stand.einstieg = 4
    stand.ziel_fortschritt[0] = 2
    stand.ziel_geholt[0] = 1
    stand.merke_art(Arten.Art.SCHILDKORALLE)
    stand.merke_mutation(Mutationen.Mutation.LICHTSCHEU)

    var zurueck := KolonieStand.aus_wort(stand.zu_wort())
    var paare := {
        "Stufen": [Array(stand.stufen), Array(zurueck.stufen)],
        "Naehrstoffe": [stand.naehrstoffe, zurueck.naehrstoffe],
        "Hoechste Welle": [stand.hoechste_welle, zurueck.hoechste_welle],
        "Linien": [Array(stand.linien), Array(zurueck.linien)],
        "Linie": [stand.linie, zurueck.linie],
        "Baukammer": [stand.bau_kammer, zurueck.bau_kammer],
        "Bauende": [stand.bau_fertig_um, zurueck.bau_fertig_um],
        "Zuletzt gesehen": [stand.zuletzt_gesehen, zurueck.zuletzt_gesehen],
        "Tag": [stand.tag, zurueck.tag],
        "Strecke": [stand.strecke, zurueck.strecke],
        "Stroemung": [stand.stroemung_offen, zurueck.stroemung_offen],
        "Kalender": [stand.kalender, zurueck.kalender],
        "Kalendertag": [stand.kalender_tag, zurueck.kalender_tag],
        "Einstieg": [stand.einstieg, zurueck.einstieg],
        "Zielfortschritt": [Array(stand.ziel_fortschritt), Array(zurueck.ziel_fortschritt)],
        "Zielgeholt": [Array(stand.ziel_geholt), Array(zurueck.ziel_geholt)],
        "Gesehene Arten": [Array(stand.gesehen), Array(zurueck.gesehen)],
        "Gesehene Mutationen": [Array(stand.mutationen_gesehen),
            Array(zurueck.mutationen_gesehen)],
    }
    for was in paare:
        var werte: Array = paare[was]
        if not _melde(werte[0] == werte[1],
                "%s ueberlebt das Sichern nicht: %s statt %s"
                % [was, str(werte[1]), str(werte[0])]):
            return false

    # Und ein veraenderter Stand darf keine unmoeglichen Werte einspeisen.
    var boese := KolonieStand.aus_wort({
        &"stufen": [999, -5],
        &"naehrstoffe": -100,
        &"hoechste_welle": 9999,
        &"linien": [42],
        &"linie": 42,
        &"bau_kammer": 77,
        &"stroemung_offen": 99,
    })
    return _melde(boese.stufe(0) == Kammern.HOECHSTSTUFE
            and boese.stufe(1) == 0
            and boese.naehrstoffe == 0
            and boese.hoechste_welle == Graben.TIEFSTE
            and boese.linie == Brutlinien.Linie.KEINE
            and boese.bau_kammer == -1
            and boese.stroemung_offen == Tagesstroemung.JE_TAG,
        "ein veraenderter Stand muss zurechtgebogen werden")


func _test_kammerausbau_verschlechtert_nie() -> bool:
    # Dieselbe Zusicherung wie fuer die Sollkurve, jetzt fuer die Kammern
    # selbst: keine Wirkung darf mit der Stufe fallen.
    for stufe in Kammern.HOECHSTSTUFE:
        var paare := {
            "Leistung": [Kammern.leistung_faktor(stufe), Kammern.leistung_faktor(stufe + 1)],
            "Ziele": [float(Kammern.ziele(stufe)), float(Kammern.ziele(stufe + 1))],
            "Reichweite": [Kammern.reichweite_faktor(stufe), Kammern.reichweite_faktor(stufe + 1)],
            "Winkel": [Kammern.winkel_faktor(stufe), Kammern.winkel_faktor(stufe + 1)],
            "Polypleistung": [Kammern.polyp_leistung(stufe), Kammern.polyp_leistung(stufe + 1)],
            "Brut": [float(Kammern.brut_leben(stufe)), float(Kammern.brut_leben(stufe + 1))],
            "Filter": [Kammern.filter_je_stunde(stufe), Kammern.filter_je_stunde(stufe + 1)],
        }
        for was in paare:
            var werte: Array = paare[was]
            if werte[1] < werte[0]:
                return _melde(false, "%s faellt von Stufe %d auf %d"
                    % [was, stufe, stufe + 1])
        # Der Polypenpreis ist der eine Wert, der fallen *soll*.
        if Kammern.polyp_kosten(stufe + 1, 3) > Kammern.polyp_kosten(stufe, 3):
            return _melde(false, "Polypen werden auf Stufe %d teurer statt billiger"
                % [stufe + 1])
    return true


# --- Grabenabschnitte ------------------------------------------------------

func _test_jeder_abschnitt_hat_namen_und_hinweis() -> bool:
    var abschnitte := Graben.ABSCHNITTE
    if not _melde(Regeln.NAMEN.size() == abschnitte,
            "%d Abschnitte, aber %d Namen" % [abschnitte, Regeln.NAMEN.size()]):
        return false
    if not _melde(Regeln.HINWEISE.size() == abschnitte,
            "%d Abschnitte, aber %d Hinweise" % [abschnitte, Regeln.HINWEISE.size()]):
        return false
    for i in abschnitte:
        if not _melde(not Regeln.name_von(i).is_empty(), "Abschnitt %d ohne Namen" % i):
            return false
        if not _melde(not Regeln.hinweis(i).is_empty(), "Abschnitt %d ohne Hinweis" % i):
            return false
    return true


func _test_erster_abschnitt_bleibt_ruhig() -> bool:
    # Die ersten zehn Wellen sind der Einstieg. Wer hier schon gegen eine
    # Stroemung kaempft, lernt die Grundhandlung nicht.
    for n in range(1, Graben.WELLEN_JE_ABSCHNITT + 1):
        for i in 20:
            var t := float(i) * 1.7
            if not is_equal_approx(Regeln.stroemung(n, t), 0.0):
                return _melde(false, "Welle %d hat Stroemung" % n)
            if not is_equal_approx(Regeln.helligkeit(n, t), 1.0):
                return _melde(false, "Welle %d hat Dunkelphasen" % n)
        if not is_equal_approx(Regeln.rand_kern(n), Schlund.RAND_KERN):
            return _melde(false, "Welle %d hat Streulicht" % n)
        if not is_equal_approx(Regeln.tiefe_kern(n), Schlund.TIEFE_KERN):
            return _melde(false, "Welle %d hat truebes Wasser" % n)
    return _melde(is_equal_approx(Regeln.wirkungsgrad(1), 1.0),
        "der erste Abschnitt darf keinen Wirkungsgrad kosten, war %.3f"
        % Regeln.wirkungsgrad(1))


func _test_regeln_bleiben_in_ihren_grenzen() -> bool:
    for n in range(1, Graben.ZYKLUS + 1):
        for i in 60:
            var t := float(i) * 0.83
            var s := Regeln.stroemung(n, t)
            if absf(s) > Regeln.STROM_WEITE_STURM + 0.001:
                return _melde(false, "Stroemung %.3f in Welle %d ist zu stark" % [s, n])
            var h := Regeln.helligkeit(n, t)
            if h < Regeln.DUNKEL_TIEFE - 0.001 or h > 1.001:
                return _melde(false, "Helligkeit %.3f in Welle %d liegt ausserhalb" % [h, n])
        var w := Regeln.wirkungsgrad(n)
        if w <= 0.0 or w > 1.001:
            return _melde(false, "Wirkungsgrad %.3f in Welle %d liegt ausserhalb" % [w, n])
    return true


func _test_regeln_sind_reproduzierbar() -> bool:
    # Der Wellenpruefer rechnet dieselben Funktionen wie das Spiel. Waeren sie
    # nicht reproduzierbar, prueft er etwas anderes, als gespielt wird.
    for n in [12, 34, 57]:
        for i in 30:
            var t := float(i) * 0.41
            if not is_equal_approx(Regeln.stroemung(n, t), Regeln.stroemung(n, t)):
                return _melde(false, "Stroemung schwankt bei gleicher Eingabe")
            if not is_equal_approx(Regeln.helligkeit(n, t), Regeln.helligkeit(n, t)):
                return _melde(false, "Helligkeit schwankt bei gleicher Eingabe")
    return true


func _test_wirkungsgrad_faellt_mit_den_regeln() -> bool:
    # Jeder neue Abschnitt muss den Spieler etwas kosten - sonst waere er eine
    # Farbe, keine Regel.
    var vorher := 2.0
    for a in Regeln.NAMEN.size():
        var n := a * Graben.WELLEN_JE_ABSCHNITT + 1
        var w := Regeln.wirkungsgrad(n)
        if w > vorher + 0.001:
            return _melde(false, "Abschnitt %d ist leichter als der davor" % (a + 1))
        vorher = w
    return _melde(Regeln.wirkungsgrad(Graben.ZYKLUS) < 0.75,
        "der letzte Abschnitt muss spuerbar kosten, war %.3f"
        % Regeln.wirkungsgrad(Graben.ZYKLUS))


func _test_wellenstaerke_folgt_dem_wirkungsgrad() -> bool:
    # Ohne diese Kopplung wurde jeder neue Abschnitt zur Wand: der
    # Wellenpruefer meldete nach Einfuehrung der Regeln fuenf gefallene
    # Sitzungen ab Welle 36.
    for n in range(1, Graben.ZYKLUS + 1):
        var erwartet := Ausbau.durchsatz(n) * Wellen.WIRKUNGSGRAD \
            * Regeln.wirkungsgrad(n) * Wellen.fenster(n) * Wellen.druck(n)
        if not is_equal_approx(Wellen.staerke(n), erwartet):
            return _melde(false, "Welle %d rechnet den Wirkungsgrad nicht ein" % n)
    return true


# --- Geisterdaten ----------------------------------------------------------

func _test_geister_stehen_gestaffelt() -> bool:
    if not _melde(Geister.NAMEN.size() == Geister.STAERKEN.size(),
            "jeder Nachbar braucht Namen und Staerke"):
        return false
    for i in range(Geister.zahl() - 1):
        if not _melde(Geister.staerke(i + 1) > Geister.staerke(i),
                "Nachbar %d ist nicht staerker als %d" % [i + 1, i]):
            return false
        if not _melde(Geister.tiefe(i + 1) > Geister.tiefe(i),
                "Nachbar %d kommt nicht tiefer als %d" % [i + 1, i]):
            return false
    return _melde(Geister.tiefe(Geister.zahl() - 1) >= Graben.ZYKLUS,
        "der staerkste Nachbar muss den ganzen Graben schaffen")


func _test_geisterleiter_beginnt_frueh() -> bool:
    # Im ersten Entwurf lag der schwaechste Nachbar bei Welle 23 - ein neuer
    # Spieler stand abgeschlagen Letzter, mit zweiundzwanzig Wellen bis zum
    # naechsten Namen. Es muss immer jemand in Reichweite stehen.
    if not _melde(Geister.tiefe(0) <= 6,
            "der schwaechste Nachbar steht bei Welle %d - zu tief fuer den Einstieg"
            % Geister.tiefe(0)):
        return false
    for i in range(Geister.zahl() - 1):
        var luecke := Geister.tiefe(i + 1) - Geister.tiefe(i)
        if luecke > 10:
            return _melde(false, "Luecke von %d Wellen zwischen %s und %s"
                % [luecke, Geister.name_von(i), Geister.name_von(i + 1)])
    return true


func _test_eigener_platz_folgt_der_tiefe() -> bool:
    var vorher := Geister.zahl() + 2
    for tiefe in [1, 5, 12, 25, 40, 55, Graben.ZYKLUS]:
        var platz := Geister.platz(tiefe)
        if not _melde(platz >= 1 and platz <= Geister.zahl() + 1,
                "Platz %d bei Tiefe %d liegt ausserhalb" % [platz, tiefe]):
            return false
        if not _melde(platz <= vorher,
                "tiefer gekommen, aber schlechter platziert (%d nach %d)"
                % [platz, vorher]):
            return false
        vorher = platz
    return _melde(Geister.platz(Graben.TIEFSTE) == 1,
        "wer den ganzen Graben schafft, steht oben")


## Das Gelege wird an zwei Stellen gebraucht - `kolonie.gd` zeichnet es,
## `wache.gd` setzt die Bruchstuecke eines getroffenen Eis dorthin. Deshalb
## liegt die Rechnung in `Graben`, und deshalb wird sie hier festgehalten:
## jedes Ei muss im Feld liegen, die Mitte muss frei bleiben (dort steht der
## Waechter), und zwei Eier duerfen nicht aufeinanderliegen.
func _test_gelege_bleibt_im_rahmen() -> bool:
    for voll in [1, 6, 12, 24, 44, 63, 64, 65, 128, 400]:
        var radius := Graben.ei_radius(voll)
        if not _melde(radius > 0.6, "Eier bei %d Stueck nur %.2f gross"
                % [voll, radius]):
            return false
        var orte: Array[Vector2] = []
        for i in voll:
            var o := Graben.ei_ort(i, voll)
            if not _melde(absf(o.x) <= Graben.BRUT_BREITE * 0.5 + 0.01,
                    "Ei %d von %d liegt bei x=%.1f ausserhalb der Brutbreite"
                    % [i, voll, o.x]):
                return false
            if not _melde(absf(o.x) >= Graben.BRUT_MITTE_FREI - 0.01,
                    "Ei %d von %d liegt bei x=%.1f hinter dem Waechter"
                    % [i, voll, o.x]):
                return false
            orte.append(o)
        # Kein Paar naeher beieinander als ein Eidurchmesser. Genau das war
        # der Fehler des alten Aufbaus: vierundvierzig Eier mit sieben Pixeln
        # Radius auf sieben Pixeln Abstand ergaben einen Balken.
        for a in orte.size():
            for b in range(a + 1, orte.size()):
                var d: float = orte[a].distance_to(orte[b])
                if not _melde(d >= radius * 1.5,
                        "Ei %d und %d bei %d Stueck nur %.1f auseinander (Radius %.1f)"
                        % [a, b, voll, d, radius]):
                    return false
    return true


## Der Rechenschritt darf kein Tier weiter tragen als den Durchmesser des
## kleinsten Tieres - sonst springt es zwischen zwei Bildern ueber den Kegel
## hinweg, ohne je darin gestanden zu haben.
##
## Das ist der Fehler, den kein Bild und kein anderer Test zeigt: er tritt nur
## auf, wenn Android die App pausiert und das erste Bild danach die volle
## verstrichene Zeit mitbringt.
func _test_takt_deckelt_den_sprung() -> bool:
    for roh: float in [0.016, 0.1, 1.0, 12.0, 300.0]:
        var t := Graben.takt(roh)
        if not _melde(t <= Graben.TAKT_DECKEL + 0.0001,
                "Takt %.3f aus delta %.3f ueber dem Deckel" % [t, roh]):
            return false
        if not _melde(t <= roh + 0.0001,
                "Takt %.3f groesser als delta %.3f" % [t, roh]):
            return false

    # Und der Deckel selbst muss die Zusicherung einhalten, aus der er kommt.
    var kleinster := 1e9
    var schnellster := 0.0
    for a in Arten.zahl():
        if Arten.ist_leitwesen(a):
            continue
        kleinster = minf(kleinster, Arten.radius(a))
        schnellster = maxf(schnellster, Arten.tempo(a))
    var weg := schnellster * Graben.TAKT_DECKEL
    return _melde(weg <= kleinster * 2.0,
        "ein Schritt traegt %.1f, der kleinste Durchmesser ist %.1f"
        % [weg, kleinster * 2.0])


## Ein halb geschriebener Spielstand darf den alten nicht vernichten.
##
## Geprueft wird die Eigenschaft, aus der das folgt: waehrend geschrieben
## wird, steht die Zwischendatei daneben, und erst das Umbenennen macht sie
## zum Spielstand. Danach gibt es die Zwischendatei nicht mehr.
func _test_speichern_ist_unteilbar() -> bool:
    var pfad := "user://pruefstand.stand"
    var roh := pfad + Speicher.ROHLING
    Speicher.loesche(pfad)
    if FileAccess.file_exists(roh):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(roh))

    var stand := KolonieStand.new()
    stand.naehrstoffe = 12345
    stand.hoechste_welle = 42
    if not _melde(Speicher.schreibe(stand, pfad), "Schreiben fehlgeschlagen"):
        return false
    if not _melde(not FileAccess.file_exists(roh),
            "die Zwischendatei liegt nach dem Schreiben noch da"):
        return false

    var zurueck := Speicher.lies(pfad)
    if not _melde(zurueck.naehrstoffe == 12345 and zurueck.hoechste_welle == 42,
            "gelesener Stand stimmt nicht: %d / %d"
            % [zurueck.naehrstoffe, zurueck.hoechste_welle]):
        return false

    # Eine abgeschnittene Zwischendatei darf den gueltigen Stand nicht
    # anfassen - genau das war der Fehler, gegen den das Umbenennen steht.
    var kaputt := FileAccess.open(roh, FileAccess.WRITE)
    if kaputt != null:
        kaputt.store_string("halb")
        kaputt.close()
    var immer_noch := Speicher.lies(pfad)
    Speicher.loesche(pfad)
    if FileAccess.file_exists(roh):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(roh))
    return _melde(immer_noch.naehrstoffe == 12345,
        "der Stand hat eine kaputte Zwischendatei nicht ueberlebt")


## Der Kegel darf keinen Zielplatz an ein Tier verschenken, das gerade gar
## nicht brennen kann.
##
## **Das war ein echter Fehler.** `brennende()` waehlte nach Helligkeit, den
## Schaden rechnete `schaden_an()` - und die gibt fuer eine Glutqualle
## unterhalb ihrer Mindesthelligkeit null zurueck. Eine Glutqualle im
## Randlicht belegte damit einen der wenigen Zielplaetze, ohne Schaden zu
## nehmen: der Ausbau "ein Ziel mehr" verpuffte. Sichtbar wird das nur beim
## Spielen, und auch dort nur als "der Kegel tut nichts".
func _test_kegel_waehlt_nach_wirkung() -> bool:
    var leistung := 40.0
    # Zwei Tiere: eine Glutqualle im Randlicht (hell, aber unverwundbar) und
    # ein Zahnkiefer im schwaecheren Licht (dunkler, aber verwundbar).
    var hell := PackedFloat32Array([0.50, 0.30])
    var mindest := PackedFloat32Array([0.52, 0.0])
    var wirkung := PackedFloat32Array()
    for i in hell.size():
        wirkung.append(Schlund.schaden_an(leistung, hell[i], 0.0, mindest[i]))

    if not _melde(wirkung[0] == 0.0,
            "die Glutqualle im Randlicht nimmt %.2f Schaden" % wirkung[0]):
        return false
    if not _melde(wirkung[1] > 0.0, "der Zahnkiefer nimmt gar nichts"):
        return false

    # Mit nur einem Zielplatz muss der Zahnkiefer gewaehlt werden, obwohl die
    # Glutqualle heller steht.
    var treffer := Schlund.brennende(wirkung, 1)
    if not _melde(treffer.size() == 1 and treffer[0] == 1,
            "der Kegel nimmt das Tier, das er nicht verletzen kann"):
        return false

    # Und die alte Auswahl nach Helligkeit haette genau andersherum gewaehlt -
    # sonst wuerde dieser Test nichts belegen.
    var frueher := Schlund.brennende(hell, 1)
    return _melde(frueher.size() == 1 and frueher[0] == 0,
        "die Helligkeitsauswahl haette dasselbe getan - der Test ist blind")


## Der Spiegler ist das Gegenstueck zur Glutqualle: er brennt nur unterhalb
## seiner Obergrenze. Wer ihn in den Kern nimmt, tut ihm nichts.
func _test_spiegler_brennt_nur_im_randlicht() -> bool:
    var art := Arten.Art.SPIEGLER
    var grenze := Arten.hoechst_licht(art)
    if not _melde(grenze > 0.0, "der Spiegler hat keine Obergrenze"):
        return false

    var leistung := 40.0
    # **Beide Messungen dicht an der Grenze.** Der erste Anlauf verglich
    # Randlicht mit vollem Kern - also zwei verschiedene Helligkeiten, und
    # damit steckte im Ergebnis auch der gewoehnliche Helligkeitsverlauf. Was
    # diese Art ausmacht, ist aber der **Sprung an der Grenze**: eine
    # Handbreit daneben, und derselbe Strahl wirkt doppelt.
    var hell_rand := grenze * 0.99
    var hell_kern := minf(1.0, grenze * 1.01)
    var im_rand := Schlund.schaden_an(leistung, hell_rand, 0.0, 0.0, grenze)
    var im_kern := Schlund.schaden_an(leistung, hell_kern, 0.0, 0.0, grenze)
    if not _melde(im_rand > 0.0, "im Randlicht nimmt der Spiegler nichts"):
        return false

    # **Nicht null, aber deutlich weniger.** Volle Unverwundbarkeit im Kern
    # war der erste Entwurf und ergab eine Wand: achtunddreissig gefallene
    # Sitzungen im Wellenpruefer, beginnend genau bei seiner ersten Welle.
    # Wer ihn falsch haelt, soll langsamer vorankommen, nicht gar nicht.
    if not _melde(im_kern > 0.0,
            "im Kern ist der Spiegler unverwundbar - das war die Wand"):
        return false
    if not _melde(im_kern < im_rand * 0.6,
            "der Sprung an der Grenze ist zu klein: Rand %.2f, Kern %.2f"
            % [im_rand, im_kern]):
        return false

    # Und keine andere Art darf versehentlich eine Obergrenze haben - sonst
    # waere die Regel nicht mehr das Besondere dieser einen.
    for a in Arten.zahl():
        if a == art:
            continue
        if not _melde(Arten.hoechst_licht(a) == 0.0,
                "%s hat auch eine Obergrenze" % Arten.art(a)[&"kennung"]):
            return false

    # **Keine zweite Schranke von unten.** Lichtscheu auf einem Spiegler
    # liesse nur ein Band uebrig, in dem er ueberhaupt brennt - das ist kein
    # schwierigeres Tier mehr, sondern ein unzielbares. Der Wellenpruefer hat
    # das mit einer gefallenen Sitzung bei Welle 224 belegt.
    for n in range(1, Graben.ZYKLUS * 4):
        if not Mutationen.hat(n, Mutationen.Mutation.LICHTSCHEU):
            continue
        if not _melde(Wellen.mindest_licht_in(art, n) == Arten.mindest_licht(art),
                "Welle %d gibt dem Spiegler zusaetzlich eine Untergrenze" % n):
            return false
    return true


## Die Fortschrittskurve darf sich nicht aendern, wenn der Graben einen
## Abschnitt mehr bekommt.
##
## Sie stand als `(nummer - 1) / (ZYKLUS - 1) * STUFEN_JE_ZYKLUS` da und hing
## damit an `Graben.ABSCHNITTE`. Ein siebter Abschnitt haette die ganze Kurve
## gestreckt und mit ihr `Wellen.staerke()`, den Wellenpruefer und den
## Kolonielauf - obwohl "ein Abschnitt mehr" eine Inhaltsentscheidung ist und
## keine ueber das Tempo.
##
## Geprueft wird beides: dass die neue Rechnung die alte trifft, und dass sie
## `Graben.ZYKLUS` nicht mehr braucht.
func _test_kurve_haengt_nicht_an_der_abschnittszahl() -> bool:
    for n in [1, 2, 17, 60, 61, 120, 241, 400]:
        var frueher := minf(float(Kammern.HOECHSTSTUFE),
            float(maxi(1, n) - 1) / 59.0 * float(Ausbau.STUFEN_JE_ZYKLUS))
        var jetzt := Ausbau.stufe_kurve(n)
        if not _melde(is_equal_approx(frueher, jetzt),
                "Welle %d: Kurve war %.4f, ist %.4f" % [n, frueher, jetzt]):
            return false

    # Und die Kurve muss aus der Wellenzahl allein folgen: zwei Wellen mit
    # demselben Abstand muessen denselben Zuwachs haben, egal wo im Zyklus.
    var a := Ausbau.stufe_kurve(11) - Ausbau.stufe_kurve(1)
    var b := Ausbau.stufe_kurve(71) - Ausbau.stufe_kurve(61)
    return _melde(is_equal_approx(a, b),
        "zehn Wellen bringen mal %.4f und mal %.4f Stufen" % [a, b])


## Jeder Abschnitt braucht **jeden** seiner Werte.
##
## `Regeln` fuehrt neun Felder je Abschnitt in getrennten Feldern - Namen,
## Hinweise, drei Farbsaetze, Schnee, Fels, Saeulen, Enge. Geprueft wurden
## bisher zwei davon. Wer einen Abschnitt hinzufuegt und ein Feld vergisst,
## bekommt entweder einen Absturz beim Betreten oder, schlimmer, still die
## Farbe des Nachbarn - und beides faellt erst dem Spieler auf.
func _test_jeder_abschnitt_ist_vollstaendig() -> bool:
    var n := Graben.ABSCHNITTE
    var felder := {
        "NAMEN": Regeln.NAMEN.size(),
        "HINWEISE": Regeln.HINWEISE.size(),
        "TIEF_FARBEN": Regeln.TIEF_FARBEN.size(),
        "GRUND_FARBEN": Regeln.GRUND_FARBEN.size(),
        "SCHEIN_FARBEN": Regeln.SCHEIN_FARBEN.size(),
        "SCHNEE_DICHTE": Regeln.SCHNEE_DICHTE.size(),
        "FELS_FARBEN": Regeln.FELS_FARBEN.size(),
        "SAEULEN": Regeln.SAEULEN.size(),
        "ENGE": Regeln.ENGE.size(),
    }
    for name in felder:
        if not _melde(int(felder[name]) == n,
                "%d Abschnitte, aber %d Eintraege in %s"
                % [n, int(felder[name]), name]):
            return false
    return true
