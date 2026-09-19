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
## 2. **Jede Testfunktion steht in `TESTS`.** Ein Waechter vergleicht die
##    Methodenliste mit dieser Tabelle - kein Abbruchschutz der Welt faengt
##    einen Test, der nie aufgerufen wird.

const TESTS: PackedStringArray = [
    "_test_waffen_tabelle_vollstaendig",
    "_test_jede_stufe_gibt_etwas",
    "_test_feinde_tabelle_vollstaendig",
    "_test_jede_sorte_hat_ein_eigenes_verhalten",
    "_test_sorten_treten_gestaffelt_ein",
    "_test_helden_tabelle_vollstaendig",
    "_test_jeder_held_ist_zu_erkennen",
    "_test_ausruestung_tabelle_vollstaendig",
    "_test_ausruestung_verschlechtert_nichts",
    "_test_kein_ausbau_verschlechtert",
    "_test_einkommen_und_kosten_wachsen_gleich",
    "_test_angebote_nie_dreimal_dasselbe",
    "_test_angebote_bleiben_annehmbar",
    "_test_ein_laeufer_haelt_die_ersten_minuten",
    "_test_stehenbleiben_verliert",
    "_test_umzingelung_kostet_mehr_als_eine_flanke",
    "_test_jede_waffe_traegt_allein",
    "_test_keine_waffe_ist_die_beste",
    "_test_flegel_haengt_nicht_an_der_bildrate",
    "_test_sold_kommt_an",
]

var _fehler: Array[String] = []


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
        return
    quit(1)


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


## Ein Lauf mit dem simulierten Daumen. `bis` begrenzt die Spielzeit, damit
## der Testlauf kurz bleibt - die vollen zehn Minuten misst `tools/probe.gd`.
func _laufe(held: int, burgstufe: int, bis: float, saat: int,
        bewegt := true, nur_waffe := -1) -> Gefecht.Stand:
    var stufen := {}
    for b in Halle.NAMEN.size():
        stufen[b] = burgstufe
    var s := Gefecht.baue(stufen, held, {})
    if nur_waffe >= 0:
        s.waffen.clear()
        s.takte.clear()
        s.waffen[nur_waffe] = 1
        s.takte[nur_waffe] = 0.0
    var rng := RandomNumberGenerator.new()
    rng.seed = saat
    var takt := 1.0 / 60.0
    var sicherung := int(bis / takt) + 200
    while not Gefecht.vorbei(s) and s.zeit < bis and sicherung > 0:
        sicherung -= 1
        if s.wartet_auf_wahl:
            # **Bei festgelegter Waffe werden nur Buffs genommen.**
            #
            # Der erste Anlauf nahm gar nichts an - und mass damit eine Lage,
            # in der ein Spieler nie ist: er steigt alle zehn Sekunden auf.
            # Zwei Minuten voellig ohne Aufstieg sind kein Waffentest,
            # sondern ein Haertetest gegen das Spiel selbst.
            #
            # Waffen bleiben trotzdem aussen vor, sonst misst man nicht die
            # Waffe, sondern was der Zufall daneben gelegt hat.
            if nur_waffe >= 0:
                var genommen := false
                for i in s.angebote.size():
                    if not s.angebote[i].ist_waffe:
                        Gefecht.nimm(s, i)
                        genommen = true
                        break
                if not genommen:
                    s.wartet_auf_wahl = false
                    s.angebote = []
                continue
            Gefecht.nimm(s, Daumen.waehle(s))
            continue
        Gefecht.schritt(s, takt, Daumen.richtung(s) if bewegt else Vector2.ZERO, rng)
    return s


# --- Waffen ----------------------------------------------------------------

func _test_waffen_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Waffen.NAMEN.size(), "LEHREN": Waffen.LEHREN.size(),
        "SCHADEN": Waffen.SCHADEN.size(), "TAKT": Waffen.TAKT.size(),
        "WEITE": Waffen.WEITE.size(), "BREITE": Waffen.BREITE.size(),
        "ZAHL": Waffen.ZAHL.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Waffen.Art.size(),
                "%s hat %d Eintraege statt %d"
                % [was, laengen[was], Waffen.Art.size()]):
            return false
    return true


func _test_jede_stufe_gibt_etwas() -> bool:
    # **Eine Stufe, die man nicht merkt, ist keine.** Zwischen zwei Stufen
    # muss sich mindestens eine der vier Zahlen aendern - sonst waehlt der
    # Spieler sie und stellt fest, dass nichts passiert ist.
    for w in Waffen.Art.size():
        for s in range(1, Waffen.HOECHSTSTUFE):
            var anders := not is_equal_approx(Waffen.schaden(w, s), Waffen.schaden(w, s + 1)) \
                or not is_equal_approx(Waffen.takt(w, s), Waffen.takt(w, s + 1)) \
                or Waffen.zahl(w, s) != Waffen.zahl(w, s + 1) \
                or not is_equal_approx(Waffen.weite(w, s), Waffen.weite(w, s + 1))
            if not _melde(anders, "%s: Stufe %d aendert nichts gegenueber %d"
                    % [Waffen.name_von(w), s + 1, s]):
                return false
    return true


# --- Feinde ----------------------------------------------------------------

func _test_feinde_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Feinde.NAMEN.size(), "LEBEN": Feinde.LEBEN.size(),
        "TEMPO": Feinde.TEMPO.size(), "SCHADEN": Feinde.SCHADEN.size(),
        "RADIUS": Feinde.RADIUS.size(), "SINN": Feinde.SINN.size(),
        "SOLD": Feinde.SOLD.size(), "AB": Andrang.AB.size(),
        "GEWICHT": Andrang.GEWICHT.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Feinde.Art.size(),
                "%s hat %d Eintraege statt %d"
                % [was, laengen[was], Feinde.Art.size()]):
            return false
    return true


func _test_jede_sorte_hat_ein_eigenes_verhalten() -> bool:
    # **Eine Sorte, die man am Verhalten nicht erkennt, ist keine.** Zwei
    # Sorten mit gleichem Sinn muessen sich wenigstens deutlich in Tempo
    # oder Zaehigkeit unterscheiden - sonst ist die zweite die erste mit
    # einem anderen Namen.
    for a in Feinde.Art.size():
        for b in range(a + 1, Feinde.Art.size()):
            if Feinde.sinn(a) != Feinde.sinn(b):
                continue
            var tempo_weit := absf(Feinde.tempo(a) - Feinde.tempo(b)) \
                / maxf(1.0, minf(Feinde.tempo(a), Feinde.tempo(b))) > 0.25
            var leben_weit := maxf(Feinde.leben(a), Feinde.leben(b)) \
                / maxf(1.0, minf(Feinde.leben(a), Feinde.leben(b))) > 1.6
            if not _melde(tempo_weit or leben_weit,
                    "%s und %s verhalten sich gleich und fuehlen sich gleich an"
                    % [Feinde.name_von(a), Feinde.name_von(b)]):
                return false
    return true


func _test_sorten_treten_gestaffelt_ein() -> bool:
    # Wer in der ersten Minute schon alles trifft, lernt keine Sorte - er
    # lernt nur, dass es voll ist. Zwischen zwei Eintritten liegt deshalb
    # mindestens das Neulingsfenster.
    var zeiten: Array[float] = []
    for a in Feinde.Art.size():
        if Feinde.ist_warlord(a):
            continue
        zeiten.append(Andrang.AB[a])
    zeiten.sort()
    for i in range(1, zeiten.size()):
        if not _melde(zeiten[i] - zeiten[i - 1] >= Andrang.NEULING_FENSTER,
                "zwei Sorten treten nur %.0f s auseinander ein"
                % (zeiten[i] - zeiten[i - 1])):
            return false
    return _melde(Andrang.WARLORD_ZEIT < Andrang.LAUF_SEKUNDEN,
        "der Warlord muss vor dem Ende kommen")


# --- Helden und Ausruestung ------------------------------------------------

func _test_helden_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Helden.NAMEN.size(), "LEHREN": Helden.LEHREN.size(),
        "STARTWAFFE": Helden.STARTWAFFE.size(),
        "LEBEN_FAKTOR": Helden.LEBEN_FAKTOR.size(),
        "WEITE_FAKTOR": Helden.WEITE_FAKTOR.size(),
        "TEMPO_FAKTOR": Helden.TEMPO_FAKTOR.size(),
        "SCHADEN_FAKTOR": Helden.SCHADEN_FAKTOR.size(),
        "BEDINGUNG": Helden.BEDINGUNG.size(),
        "SCHWELLE": Helden.SCHWELLE.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Helden.Held.size(),
                "%s hat %d Eintraege statt %d"
                % [was, laengen[was], Helden.Held.size()]):
            return false
    return _melde(Helden.ist_frei(Helden.Held.SCHWERT, 0.0, 0, false),
        "der erste Held muss von Anfang an frei sein")


func _test_jeder_held_ist_zu_erkennen() -> bool:
    # **Genau eine Eigenart je Held**, und keine zwei gleich. Ein Held mit
    # fuenf kleinen Vorteilen fuehlt sich an wie der Grundheld mit Rauschen.
    var gesehen := {}
    for h in Helden.Held.size():
        var wort := "%.2f|%.2f|%.2f|%.2f|%d" % [
            Helden.leben_faktor(h), Helden.weite_faktor(h),
            Helden.tempo_faktor(h), Helden.schaden_faktor(h),
            Helden.startwaffe(h)]
        if not _melde(not gesehen.has(wort),
                "%s ist derselbe Held wie %s"
                % [Helden.name_von(h), String(gesehen.get(wort, ""))]):
            return false
        gesehen[wort] = Helden.name_von(h)
        var abweichungen := 0
        for f in [Helden.leben_faktor(h), Helden.weite_faktor(h),
                Helden.schaden_faktor(h)]:
            if not is_equal_approx(f, 1.0):
                abweichungen += 1
        if not _melde(abweichungen <= 1,
                "%s hat %d Vorteile - einer muss genuegen"
                % [Helden.name_von(h), abweichungen]):
            return false
    return true


func _test_ausruestung_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Ausruestung.NAMEN.size(),
        "AUF_PLATZ": Ausruestung.AUF_PLATZ.size(),
        "WIRKT_AUF": Ausruestung.WIRKT_AUF.size(),
        "JE_STUFE": Ausruestung.JE_STUFE.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Ausruestung.Stueck.size(),
                "%s hat %d Eintraege statt %d"
                % [was, laengen[was], Ausruestung.Stueck.size()]):
            return false
    # Jeder Platz muss wenigstens ein Stueck haben, sonst steht er im
    # Bedienbild leer und niemand weiss, warum.
    for p in Ausruestung.Platz.size():
        var zahl := 0
        for st in Ausruestung.Stueck.size():
            if Ausruestung.platz_von(st) == p:
                zahl += 1
        if not _melde(zahl > 0, "Platz %s hat kein einziges Stueck"
                % Ausruestung.platz_name(p)):
            return false
    return true


func _test_ausruestung_verschlechtert_nichts() -> bool:
    for st in Ausruestung.Stueck.size():
        for s in range(0, Ausruestung.HOECHSTSTUFE):
            if not _melde(Ausruestung.anteil(st, s + 1) >= Ausruestung.anteil(st, s),
                    "%s wird auf Stufe %d schlechter"
                    % [Ausruestung.name_von(st), s + 1]):
                return false
    # Und der Gesamtfaktor ist ohne alles genau eins - sonst muesste jede
    # Rechnung, die ihn benutzt, einen Sonderfall kennen.
    for wirkt in Ausruestung.Wirkt.size():
        if not _melde(is_equal_approx(Ausruestung.summe({}, wirkt), 1.0),
                "ohne Ausruestung muss der Faktor eins sein"):
            return false
    return true


func _test_kein_ausbau_verschlechtert() -> bool:
    for s in Halle.HOECHSTSTUFE:
        if not _melde(Halle.leben(s + 1) >= Halle.leben(s)
                and Halle.schaden_faktor(s + 1) >= Halle.schaden_faktor(s)
                and Halle.tempo(s + 1) >= Halle.tempo(s)
                and Halle.sold_faktor(s + 1) >= Halle.sold_faktor(s),
                "Burgstufe %d ist schlechter als %d" % [s + 1, s]):
            return false
    return true


func _test_einkommen_und_kosten_wachsen_gleich() -> bool:
    # **Bauten kosten geometrisch.** Ein Einkommen, das langsamer waechst,
    # holt sie nie wieder ein. Geprueft wird die Ableitung selbst und nicht
    # ein Verhaeltnis: ein Verhaeltnis zu pruefen hiesse, die Rundung bei
    # kleinen Zahlen fuer eine Abweichung zu halten.
    for lauf in range(1, 120):
        var soll := Halle.rundenkosten(Halle.stufe_soll(lauf)) / Halle.LAEUFE_JE_RUNDE
        if not _melde(absf(float(Halle.ertrag(lauf)) - soll) <= 1.0,
                "Lauf %d zahlt %d statt %.2f" % [lauf, Halle.ertrag(lauf), soll]):
            return false
    return _melde(float(Halle.ertrag(60)) > float(Halle.ertrag(1)) * 20.0,
        "das Einkommen haelt mit den geometrischen Kosten nicht mit")


# --- Die Aufstiege ---------------------------------------------------------

func _test_angebote_nie_dreimal_dasselbe() -> bool:
    # Drei Buffs nebeneinander sind keine Wahl, sondern eine Formalitaet.
    var rng := RandomNumberGenerator.new()
    for saat in 60:
        rng.seed = saat
        var a := Gunst.angebote({Waffen.Art.SCHWERT: 1}, {}, rng)
        if a.size() < Gunst.ANGEBOTE:
            continue
        var waffen := 0
        for x in a:
            if x.ist_waffe:
                waffen += 1
        if not _melde(waffen >= 1 and waffen <= 2,
                "Saat %d bietet %d Waffen von %d an" % [saat, waffen, a.size()]):
            return false
    return true


func _test_angebote_bleiben_annehmbar() -> bool:
    # **Ein Angebot, das man nicht annehmen kann, ist ein verschenkter
    # Aufstieg.** Sind alle Plaetze voll, duerfen nur noch Stufen kommen.
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var waffen := {}
    for i in Gunst.WAFFEN_PLAETZE:
        waffen[i] = 1
    var zuege := {}
    for i in Gunst.ZUG_PLAETZE:
        zuege[i] = 1
    for versuch in 40:
        for a in Gunst.angebote(waffen, zuege, rng):
            if not _melde(not a.neu,
                    "bei vollen Plaetzen wurde %s als neu angeboten" % a.name()):
                return false
    return true


# --- Das Gefecht ------------------------------------------------------------

func _test_ein_laeufer_haelt_die_ersten_minuten() -> bool:
    # **Die untere Schranke.** Der simulierte Daumen kitet und sammelt, mehr
    # nicht. Die vollen zehn Minuten misst `tools/probe.gd`; hier reicht der
    # Anfang, damit der Testlauf kurz bleibt.
    #
    # Wer das rot sieht, hat eine Kurve gebaut, die niemand laeuft - die
    # Schranke wird nicht gelockert, damit eine Aenderung durchgeht.
    #
    # **Drei Saaten, und alle drei muessen stehen.** Der erste Anlauf zog
    # **eine** - und dieses Genre streut so stark, dass eine Einzelmessung
    # ein Wurf ist und kein Befund. Gemessen fiel der Spearman bei einer Saat
    # nach 134 s und hielt bei zwei anderen die vollen drei Minuten. Das ist
    # keine Lockerung, sondern die Regel dieses Repositories: ein Waechter,
    # der bei jeder zweiten Ausfuehrung etwas anderes meldet, bewacht nichts.
    for held in Helden.Held.size():
        for saat in 3:
            var s := _laufe(held, 0, 180.0, 400 + held * 10 + saat)
            if not _melde(s.lebt(),
                    "%s faellt bei Saat %d schon nach %.0f s (erschlagen %d, Stufe %d)"
                    % [Helden.name_von(held), saat, s.zeit, s.erschlagen, s.stufe]):
                return false
    return true


func _test_stehenbleiben_verliert() -> bool:
    # **Wer sich nicht bewegt, stirbt** - sonst waere Bewegung Zierde, und
    # das Spiel haette keine Eingabe, die etwas bedeutet.
    #
    # Geprueft wird **vergleichend und ueber mehrere Saaten**, nicht als
    # einzelner Todesfall. Gemessen ueber drei Saaten faellt der Stehende
    # zweimal nach gut drei Minuten und ueberlebt einmal die vollen zehn -
    # er hatte sich in eine Lawine hineingespielt. Ein Test auf "stirbt
    # binnen x Sekunden" meldet bei dieser Streuung den Wurf und nicht die
    # Regel; ein Test auf "haelt deutlich kuerzer durch" meldet die Regel.
    var steht := 0.0
    var laeuft := 0.0
    for saat in 3:
        steht += _laufe(Helden.Held.SCHWERT, 0, 600.0, 77 + saat, false).zeit
        laeuft += _laufe(Helden.Held.SCHWERT, 0, 600.0, 77 + saat, true).zeit
    return _melde(steht < laeuft * 0.6,
        "Stehenbleiben haelt im Schnitt %.0f s, Laufen nur %.0f s"
        % [steht / 3.0, laeuft / 3.0])


## Stellt einen Aufbau hin und misst **nur**, was der Held verliert.
##
## Jeden Schritt wird neu gestellt: nachgespeiste Feinde fliegen raus, die
## gestellten stehen fest. Sonst misst man ihre Wanderung und nicht die
## Aufstellung. Waffen hat der Held keine - was stirbt, drueckt nicht mehr.
func _druckprobe(winkel: PackedFloat32Array, dauer: float) -> float:
    var stufen := {}
    for b in Halle.NAMEN.size():
        stufen[b] = 0
    var s := Gefecht.baue(stufen, Helden.Held.SCHWERT, {})
    s.waffen.clear()
    s.takte.clear()
    # **Genug Leben, dass nichts anschlaegt.** Der erste Anlauf liess den
    # Helden mit hundert Leben antreten: rundum war er nach der halben Zeit
    # tot, danach fiel kein Schaden mehr, und beide Aufstellungen meldeten
    # dieselben 125 - eine Decke, keine Messung.
    s.leben_voll = 100000.0
    s.leben = s.leben_voll
    var rng := RandomNumberGenerator.new()
    rng.seed = 4711
    var vorher := s.leben
    var takt := 1.0 / 60.0
    for i in int(dauer / takt):
        s.feinde.clear()
        s.geschosse.clear()
        # **Um den Helden, wo er jetzt steht.** Der erste Anlauf rechnete die
        # Plaetze einmal aus: sobald der Held ein Stueck abtrieb, lag der
        # ganze Kranz auf einer Seite von ihm, und rundum mass sich wie eine
        # Flanke - gemeldet wurden 3,5 Faecher statt acht.
        for w in winkel:
            var o := s.ort + Vector2(cos(w), sin(w)) * 26.0
            var f := Gefecht.Feind.new()
            f.art = Feinde.Art.STROLCH
            f.leben_voll = 9999.0
            f.leben = 9999.0
            f.radius = Feinde.radius(Feinde.Art.STROLCH)
            f.ort = o
            s.feinde.append(f)
        Gefecht.schritt(s, takt, Vector2.ZERO, rng)
    return vorher - s.leben


func _test_umzingelung_kostet_mehr_als_eine_flanke() -> bool:
    # **Nicht wie viele anliegen zaehlt, sondern aus wie vielen Richtungen.**
    # Das ist die ganze Aussage der Mechanik, und sie gehoert in einen
    # gestellten Aufbau statt in einen ganzen Lauf: in einem Lauf haengt
    # dieselbe Zahl an Andrang, Waffen und Wurf.
    #
    # Acht Strolche auf **einer** Flanke gegen acht **rundum**, gleiche Zeit,
    # gleiche Zahl, gleiche Sorte. Nur die Aufstellung ist anders.
    var eine := PackedFloat32Array()
    var rund := PackedFloat32Array()
    for i in 8:
        eine.append(-0.4 + 0.8 * float(i) / 7.0)
        rund.append(TAU * float(i) / 8.0)
    var schaden_flanke := _druckprobe(eine, 6.0)
    var schaden_rund := _druckprobe(rund, 6.0)
    if not _melde(schaden_flanke > 0.0, "Eine Flanke tut gar nicht weh"):
        return false
    # Zwei Faecher (der Faecher ist 45 Grad breit, die Flanke spannt 46) gegen
    # acht: rechnerisch Faktor 2,58. Gefordert sind zwei - mit Luft, aber
    # weit weg von "kein Unterschied".
    return _melde(schaden_rund > schaden_flanke * 2.0,
        "Rundum kostet %.1f, eine Flanke %.1f - das ist nur Faktor %.2f"
        % [schaden_rund, schaden_flanke, schaden_rund / maxf(0.01, schaden_flanke)])


func _test_jede_waffe_traegt_allein() -> bool:
    # **Keine tote Waffe.** Jede muss die ersten zwei Minuten allein tragen -
    # sonst ist sie ein Angebot, das den Aufstieg verschenkt.
    #
    # Auch hier drei Saaten. Die Armbrust meldete bei einer Saat einen Tod
    # nach achtzig Sekunden und trug bei zwei anderen die vollen zwei
    # Minuten; welche der drei man zieht, darf ueber eine Waffe nicht
    # entscheiden.
    for w in Waffen.Art.size():
        for saat in 3:
            var s := _laufe(Helden.Held.SCHWERT, 6, 120.0, 900 + w * 10 + saat,
                true, w)
            if not _melde(s.lebt() and s.erschlagen > 20,
                    "%s allein bei Saat %d: %d erschlagen, Leben %.0f nach %.0f s"
                    % [Waffen.name_von(w), saat, s.erschlagen, s.leben, s.zeit]):
                return false
    return true


func _test_keine_waffe_ist_die_beste() -> bool:
    # Wenn eine Waffe um ein Vielfaches besser ist, gibt es keine Wahl mehr,
    # sondern eine richtige Antwort - und alle anderen Angebote sind Fuellung.
    #
    # **Ueber drei Saaten gemittelt, nicht eine.** Der erste Anlauf mass je
    # Waffe einen Lauf und meldete den Flegel mit 298 gegen 108; derselbe
    # Stand ueber drei Saaten gab 169 gegen 134. Eine Einzelmessung aus einer
    # streuenden Verteilung ist ein Zug und kein Befund.
    var wenigste := 1e9
    var meiste := 0.0
    var bester := ""
    for w in Waffen.Art.size():
        var summe := 0.0
        for saat in 3:
            summe += float(_laufe(Helden.Held.SCHWERT, 6, 120.0,
                900 + w + saat * 31, true, w).erschlagen)
        var zahl := summe / 3.0
        if zahl < wenigste:
            wenigste = zahl
        if zahl > meiste:
            meiste = zahl
            bester = Waffen.name_von(w)
    return _melde(meiste <= wenigste * 2.2,
        "%s erschlaegt %.0f, die schwaechste nur %.0f" % [bester, meiste, wenigste])


func _test_flegel_haengt_nicht_an_der_bildrate() -> bool:
    # **Schaden je Zeit, nicht je Bild.** Haengt eine Dauerwaffe am Takt, ist
    # sie auf einem 120-Hz-Telefon doppelt so stark - und eine Einstellung im
    # Anzeigemenue verstellte den Schwierigkeitsgrad.
    #
    # Gemessen wird an einem **stillstehenden Aufbau** und nicht an einem
    # ganzen Lauf: bei zwei verschiedenen Takten laeuft die ganze Welle
    # auseinander, und dann vergleicht man zwei Laeufe statt einer Waffe.
    # Der erste Anlauf tat genau das und meldete 48 gegen 31 - ein
    # Unterschied, der nichts ueber den Flegel sagte.
    var ergebnisse: Array[float] = []
    for takt in [1.0 / 30.0, 1.0 / 120.0]:
        var s := Gefecht.baue({}, Helden.Held.SCHWERT, {})
        s.waffen.clear()
        s.takte.clear()
        s.waffen[Waffen.Art.FLEGEL] = 3
        var weite := Gefecht.weite_von(s, Waffen.Art.FLEGEL)
        # Zwoelf unbewegliche Ziele auf dem Bahnradius, unendlich zaeh:
        # gemessen wird der ausgeteilte Schaden, nicht wer stirbt.
        var summe_vorher := 0.0
        for i in 12:
            var f := Gefecht.Feind.new()
            f.art = Feinde.Art.STROLCH
            f.leben = 1e9
            f.leben_voll = 1e9
            f.radius = 17.0
            f.ort = s.ort + Vector2(cos(TAU * float(i) / 12.0),
                sin(TAU * float(i) / 12.0)) * weite
            s.feinde.append(f)
            summe_vorher += f.leben
        var rng := RandomNumberGenerator.new()
        rng.seed = 5
        var zeit := 0.0
        while zeit < 10.0:
            zeit += takt
            # Nur die Waffen treiben, sonst laufen die Ziele weg.
            Gefecht._fuehre_waffen(s, takt, rng)
        var summe_nachher := 0.0
        for f in s.feinde:
            summe_nachher += f.leben
        ergebnisse.append(summe_vorher - summe_nachher)
    var a := ergebnisse[0]
    var b := ergebnisse[1]
    return _melde(absf(a - b) <= maxf(1.0, maxf(a, b) * 0.12),
        "der Flegel teilt bei 30 Hz %.0f und bei 120 Hz %.0f aus" % [a, b])


func _test_sold_kommt_an() -> bool:
    # Wer erschlaegt, muss auch bezahlt werden - sonst fuehrt die Schleife
    # ins Leere und keine Burgstufe wird je bezahlbar.
    var s := _laufe(Helden.Held.SCHWERT, 0, 90.0, 33)
    if not _melde(s.erschlagen > 0, "in 90 s faellt kein einziger Feind"):
        return false
    return _melde(s.sold > 0 and s.stufe > 1,
        "%d erschlagen, aber nur %d Sold und Stufe %d"
        % [s.erschlagen, s.sold, s.stufe])
