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
    "_test_zielrichtung",
    "_test_drehung_begrenzt",
    "_test_drehung_erreicht_ziel",
    "_test_bahn_endet_an_der_brut",
    "_test_laufzeit",
    "_test_arten_tabelle_vollstaendig",
    "_test_arten_erst_ab_ihrer_welle",
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
    "_test_erste_woche_ohne_wartemauer",
    "_test_schacht_deckelt_die_kolonie",
    "_test_kammerausbau_verschlechtert_nie",
    "_test_jeder_abschnitt_hat_namen_und_hinweis",
    "_test_erster_abschnitt_bleibt_ruhig",
    "_test_regeln_bleiben_in_ihren_grenzen",
    "_test_regeln_sind_reproduzierbar",
    "_test_wirkungsgrad_faellt_mit_den_regeln",
    "_test_wellenstaerke_folgt_dem_wirkungsgrad",
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
    var felder: PackedStringArray = ["name", "leben", "tempo", "radius", "wert",
        "wucht", "schlaengel", "takt", "farbe", "ab_welle"]
    if not _melde(Arten.TABELLE.size() == Arten.Art.size(),
            "TABELLE und enum Art muessen gleich gross sein"):
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
    var spaet := Arten.verfuegbar(Graben.WELLEN_GESAMT)
    return _melde(spaet.size() == Arten.zahl(),
        "in der letzten Welle muessen alle Arten verfuegbar sein")


# --- Wellen ----------------------------------------------------------------

func _test_wellen_wachsen() -> bool:
    # Nicht die rohe Lebenspunktzahl waechst, sondern der **Anspruch**.
    #
    # An jeder Abschnittsgrenze faellt die Zahl der Raeuber, weil die neue
    # Regel dem Spieler Leistung abzieht - Welle 21 hat weniger Leben als
    # Welle 20 und ist trotzdem schwerer. Wer hier die rohe Staerke prueft,
    # zwingt die Wellen dazu, die Regeln zu ignorieren.
    for n in range(1, Graben.WELLEN_GESAMT):
        var jetzt := Wellen.staerke(n) / maxf(0.0001, Regeln.wirkungsgrad(n))
        var danach := Wellen.staerke(n + 1) / maxf(0.0001, Regeln.wirkungsgrad(n + 1))
        if not _melde(danach > jetzt,
                "Welle %d verlangt nicht mehr als %d" % [n + 1, n]):
            return false

    # Ueber die ganze Strecke muss auch die rohe Zahl deutlich steigen -
    # sonst waeren die Abschnitte das einzige Wachstum.
    return _melde(Wellen.staerke(Graben.WELLEN_GESAMT) > Wellen.staerke(1) * 8.0,
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
    for n in range(1, Graben.WELLEN_GESAMT + 1):
        for a in Wellen.auftritte(n):
            var x: float = a[&"x"]
            if absf(x) > Graben.EINTRITT_SEITE + 0.001:
                return _melde(false, "Welle %d tritt bei x=%f ausserhalb ein" % [n, x])
            var art: int = a[&"art"]
            if art < 0 or art >= Arten.zahl():
                return _melde(false, "Welle %d nennt Art %d" % [n, art])
    return true


func _test_wellen_zeiten_sortiert() -> bool:
    for n in range(1, Graben.WELLEN_GESAMT + 1):
        var liste := Wellen.auftritte(n)
        for i in range(1, liste.size()):
            if liste[i][&"zeit"] < liste[i - 1][&"zeit"]:
                return _melde(false, "Welle %d ist nicht nach Zeit sortiert" % n)
    return true


func _test_wellen_dauer_im_rahmen() -> bool:
    # Im Konzept steht: 40 bis 70 Sekunden je Welle. Steht es nur dort und
    # nicht im Code, weicht es irgendwann ab.
    for n in range(1, Graben.WELLEN_GESAMT + 1):
        var d := Wellen.dauer(n)
        if d < 40.0 or d > 70.0:
            return _melde(false, "Welle %d dauert %.1f s, erlaubt sind 40-70" % [n, d])
    return true


func _test_wellen_treffen_ihr_budget() -> bool:
    for n in range(1, Graben.WELLEN_GESAMT + 1):
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
    for n in range(1, Graben.WELLEN_GESAMT):
        if not _melde(Wellen.zaehigkeit(n + 1) > Wellen.zaehigkeit(n),
                "Zaehigkeit faellt zwischen Welle %d und %d" % [n, n + 1]):
            return false
    return _melde(is_equal_approx(Wellen.zaehigkeit(1), 1.0),
        "Welle 1 muss die Grundwerte der Arten benutzen")


func _test_druck_steigt_und_bleibt_im_rahmen() -> bool:
    for n in range(1, Graben.WELLEN_GESAMT + 1):
        var d := Wellen.druck(n)
        if d <= 0.0 or d > 1.0:
            return _melde(false, "Druck in Welle %d liegt bei %.2f" % [n, d])
    return _melde(Wellen.druck(Graben.WELLEN_GESAMT) > Wellen.druck(1) * 2.0,
        "der Druck muss ueber 60 Wellen deutlich anziehen")


func _test_ausbau_verschlechtert_nie() -> bool:
    # Dieselbe Zusicherung wie bei den HYPHA-Myzelknoten, nur eine Ebene
    # hoeher: kein Wert der Sollkurve darf mit der Wellennummer fallen. Sonst
    # waere die geprueft Ueberstehbarkeit spaeterer Wellen wertlos.
    for n in range(1, Graben.WELLEN_GESAMT):
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
        and _melde(Graben.abschnitt(Graben.WELLEN_GESAMT) == 5,
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
    for n in range(1, Graben.WELLEN_GESAMT + 1):
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

        if absi(Kammern.ziele(stufe) - Ausbau.ziele(n)) > 1:
            return _melde(false, "Ziele weichen bei Welle %d ab: Kammer %d, Soll %d"
                % [n, Kammern.ziele(stufe), Ausbau.ziele(n)])

    # An den Enden muss es exakt aufgehen, nicht nur ungefaehr.
    return _melde(is_equal_approx(Kammern.leistung_faktor(0), Ausbau.leistung_faktor(1)),
            "Stufe 0 muss den Grundwerten entsprechen") \
        and _melde(is_equal_approx(Kammern.leistung_faktor(Kammern.HOECHSTSTUFE),
                Ausbau.leistung_faktor(Graben.WELLEN_GESAMT)),
            "Hoechststufe muss das Ende der Sollkurve treffen") \
        and _melde(Kammern.ziele(Kammern.HOECHSTSTUFE) == Ausbau.ziele(Graben.WELLEN_GESAMT),
            "Zielzahl muss am Ende uebereinstimmen")


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
    var abschnitte := Graben.abschnitt(Graben.WELLEN_GESAMT) + 1
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
    for n in range(1, Graben.WELLEN_GESAMT + 1):
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
    return _melde(Regeln.wirkungsgrad(Graben.WELLEN_GESAMT) < 0.75,
        "der letzte Abschnitt muss spuerbar kosten, war %.3f"
        % Regeln.wirkungsgrad(Graben.WELLEN_GESAMT))


func _test_wellenstaerke_folgt_dem_wirkungsgrad() -> bool:
    # Ohne diese Kopplung wurde jeder neue Abschnitt zur Wand: der
    # Wellenpruefer meldete nach Einfuehrung der Regeln fuenf gefallene
    # Sitzungen ab Welle 36.
    for n in range(1, Graben.WELLEN_GESAMT + 1):
        var erwartet := Ausbau.durchsatz(n) * Wellen.WIRKUNGSGRAD \
            * Regeln.wirkungsgrad(n) * Wellen.fenster(n) * Wellen.druck(n)
        if not is_equal_approx(Wellen.staerke(n), erwartet):
            return _melde(false, "Welle %d rechnet den Wirkungsgrad nicht ein" % n)
    return true
