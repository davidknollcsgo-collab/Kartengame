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
    "_test_schnitte_tabelle_vollstaendig",
    "_test_achsen_trennen_sich_und_lassen_keine_luecke",
    "_test_achse_ist_zweiseitig",
    "_test_gegner_tabelle_vollstaendig",
    "_test_jede_sorte_hat_einen_eigenen_rhythmus",
    "_test_fenster_passt_in_den_ansatz",
    "_test_taeuschung_laesst_zeit_zum_zweiten_lesen",
    "_test_schule_verschlechtert_nichts",
    "_test_einkommen_und_kosten_wachsen_gleich",
    "_test_ronden_sind_reproduzierbar",
    "_test_ronde_ist_nie_leer",
    "_test_ronde_waechst",
    "_test_meister_tritt_zuletzt_an",
    "_test_lesezeit_bleibt_menschlich",
    "_test_fuehrung_und_fenster_teilen_die_zahl",
    "_test_ein_leser_gewinnt",
    "_test_ruehren_verliert",
    "_test_kein_platz_doppelt_besetzt",
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


## Waechter: jede `_test_`-Methode dieses Skripts muss in TESTS stehen.
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


# --- Die Linien ------------------------------------------------------------

func _test_schnitte_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Schnitte.NAMEN.size(),
        "ANTWORTEN": Schnitte.ANTWORTEN.size(),
        "WINKEL": Schnitte.WINKEL.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Schnitte.Linie.size(),
                "%s hat %d Eintraege statt %d"
                % [was, laengen[was], Schnitte.Linie.size()]):
            return false
    for l in Schnitte.Linie.size():
        if not _melde(not Schnitte.name_von(l).is_empty()
                and not Schnitte.antwort_von(l).is_empty(),
                "Linie %d braucht Namen und Antwort" % l):
            return false
    return true


func _test_achsen_trennen_sich_und_lassen_keine_luecke() -> bool:
    # **Es gibt kein totes Band.** Jede Richtung, die ein Daumen ziehen
    # kann, gehoert genau einer Achse - und zwar der, die ihr am naechsten
    # liegt. Frueher stand hier eine Schwelle; sie hatte einen Rand, und ein
    # Rand ist entweder doppeldeutig oder tot.
    #
    # Geprueft wird deshalb zweierlei: dass die gewaehlte Achse wirklich die
    # naechste ist (keine bevorzugt die Reihenfolge der Tabelle), und dass
    # eine Richtung genau auf einer Achse auch diese bekommt.
    var schritte := 720
    for i in schritte:
        var w := TAU * float(i) / float(schritte)
        var r := Vector2(cos(w), sin(w))
        var gewaehlt := Schnitte.naechste_achse(r)
        var d := Schnitte.abstand(gewaehlt, r)
        for l in Schnitte.GEWISCHT:
            if not _melde(Schnitte.abstand(l, r) >= d - 0.0001,
                    "Richtung %.1f Grad bekommt %s statt der naeheren %s"
                    % [rad_to_deg(w), Schnitte.name_von(gewaehlt),
                        Schnitte.name_von(l)]):
                return false
        # Die halbe Luecke zwischen zwei Achsen: weiter kann eine Richtung
        # von ihrer naechsten nie entfernt sein.
        if not _melde(d <= PI / 8.0 + 0.0001,
                "Richtung %.1f Grad liegt %.1f Grad von jeder Achse entfernt"
                % [rad_to_deg(w), rad_to_deg(d)]):
            return false
    for l in Schnitte.GEWISCHT:
        if not _melde(Schnitte.naechste_achse(Schnitte.richtung(l) * 80.0) == l,
                "%s findet sich selbst nicht" % Schnitte.name_von(l)):
            return false
    return true


func _test_achse_ist_zweiseitig() -> bool:
    # Ein Kesa-Schnitt und sein Gegenzug liegen auf derselben Achse. Wer das
    # aufgibt, hat acht Antworten statt vier - und acht Antworten sind auf
    # einem Telefon acht Fehlversuche.
    var schritte := 360
    for i in schritte:
        var w := TAU * float(i) / float(schritte)
        var r := Vector2(cos(w), sin(w))
        if not _melde(Schnitte.naechste_achse(r)
                == Schnitte.naechste_achse(-r),
                "Richtung %.1f Grad und ihre Gegenrichtung landen auf verschiedenen Achsen"
                % rad_to_deg(w)):
            return false
    return true


# --- Die Gegner ------------------------------------------------------------

func _test_gegner_tabelle_vollstaendig() -> bool:
    var laengen := {
        "NAMEN": Gegner.NAMEN.size(),
        "LEHREN": Gegner.LEHREN.size(),
        "ANSATZ": Gegner.ANSATZ.size(),
        "FENSTER": Gegner.FENSTER.size(),
        "OEFFNUNG": Gegner.OEFFNUNG.size(),
        "PARADEN": Gegner.PARADEN.size(),
        "TAEUSCHT": Gegner.TAEUSCHT.size(),
    }
    for was in laengen:
        if not _melde(laengen[was] == Gegner.Art.size(),
                "%s hat %d Eintraege statt %d"
                % [was, laengen[was], Gegner.Art.size()]):
            return false
    for a in Gegner.Art.size():
        if not _melde(not Gegner.linien_von(a).is_empty(),
                "%s fuehrt keine einzige Linie" % Gegner.name_von(a)):
            return false
    return true


func _test_jede_sorte_hat_einen_eigenen_rhythmus() -> bool:
    # **Eine Sorte, die man am Rhythmus nicht erkennt, ist keine.** Zwei
    # Gegner mit denselben vier Zahlen sind derselbe Gegner unter zwei
    # Namen, und der Spieler lernt an ihnen nichts Neues.
    for a in Gegner.Art.size():
        for b in range(a + 1, Gegner.Art.size()):
            var gleich := is_equal_approx(Gegner.ansatz(a), Gegner.ansatz(b)) \
                and is_equal_approx(Gegner.fenster(a), Gegner.fenster(b)) \
                and is_equal_approx(Gegner.oeffnung(a), Gegner.oeffnung(b)) \
                and Gegner.paraden(a) == Gegner.paraden(b) \
                and Gegner.taeuscht(a) == Gegner.taeuscht(b) \
                and Gegner.linien_von(a) == Gegner.linien_von(b)
            if not _melde(not gleich,
                    "%s und %s haben denselben Rhythmus"
                    % [Gegner.name_von(a), Gegner.name_von(b)]):
                return false
    return true


func _test_fenster_passt_in_den_ansatz() -> bool:
    # Das Fenster liegt beidseitig um den Schlag. Waere es breiter als der
    # halbe Ansatz, begaenne es, bevor die Fuehrungslinie ueberhaupt
    # gewachsen ist - dann pariert man, bevor man gelesen hat, und das Lesen
    # ist der ganze Inhalt dieses Spiels.
    # **Auf jeder Schulstufe, nicht nur auf der nullten.** Beide Zahlen
    # wachsen mit der Schule; wer nur eine davon prueft, prueft eine
    # Kombination, die es im Spiel nicht gibt.
    for s in range(0, Schule.HOECHSTSTUFE + 1):
        for a in Gegner.Art.size():
            var f := Duell.fensterbreite(a, Schule.fensterzusatz(s))
            var d := Duell.ansatzdauer(a, Schule.lesezeit(s))
            if not _melde(f < d * 0.5,
                    "%s auf Stufe %d: Fenster %.2f passt nicht in den Ansatz %.2f"
                    % [Gegner.name_von(a), s, f, d]):
                return false
    return true


func _test_taeuschung_laesst_zeit_zum_zweiten_lesen() -> bool:
    # Nach dem Wechsel muss genug Zeit bleiben, um die wahre Linie noch zu
    # lesen. Bleibt weniger als eine Reaktionszeit, ist die Taeuschung keine
    # Taeuschung mehr, sondern ein Wuerfel.
    const REAKTION := 0.25
    for a in Gegner.Art.size():
        if not Gegner.taeuscht(a):
            continue
        var rest := Gegner.ansatz(a) * (1.0 - Gegner.TAEUSCH_LAGE)
        if not _melde(rest >= REAKTION,
                "%s laesst nach der Taeuschung nur %.2f s"
                % [Gegner.name_von(a), rest]):
            return false
    return true


# --- Die Schule ------------------------------------------------------------

func _test_schule_verschlechtert_nichts() -> bool:
    # Kein Ausbau darf etwas verschlechtern. Das klingt selbstverstaendlich
    # und ist es nicht: eine Kurve mit einem Exponenten ueber eins kippt am
    # Ende, und niemand sieht es, weil niemand die vierzigste Stufe spielt.
    for s in Schule.HOECHSTSTUFE:
        if not _melde(Schule.lesezeit(s + 1) >= Schule.lesezeit(s)
                and Schule.fensterzusatz(s + 1) >= Schule.fensterzusatz(s)
                and Schule.atem(s + 1) >= Schule.atem(s)
                and Schule.oeffnungsfaktor(s + 1) >= Schule.oeffnungsfaktor(s),
                "Stufe %d ist schlechter als %d" % [s + 1, s]):
            return false
    return true


func _test_einkommen_und_kosten_wachsen_gleich() -> bool:
    # **Kammern kosten geometrisch.** Ein Einkommen, das linear oder auch nur
    # langsamer geometrisch waechst, holt das nie wieder ein - der Spieler
    # baut die ersten zehn Stufen und danach nie wieder eine. Beide Seiten
    # fallen deshalb aus derselben Kostenzahl; geprueft wird, dass ihr
    # Verhaeltnis ueber die ganze Strecke stehen bleibt.
    # Geprueft wird die Ableitung selbst und nicht ein Verhaeltnis: die Ehre
    # **ist** die Rundenkosten geteilt durch `RONDEN_JE_RUNDE`, auf ganze
    # Zahlen gerundet. Ein Verhaeltnis zu pruefen hiesse, die Rundung bei
    # kleinen Zahlen fuer eine Abweichung zu halten.
    for n in range(1, 260):
        var soll := Schule.rundenkosten(Schule.stufe_soll(n)) \
            / Schule.RONDEN_JE_RUNDE
        var ist := float(Ronde.ehre(n))
        if not _melde(absf(ist - soll) <= 1.0,
                "Ronde %d zahlt %.0f statt %.2f" % [n, ist, soll]):
            return false
    # Und dass beide Seiten wirklich geometrisch mitwachsen: nach zwanzig
    # Sollstufen muss eine Ronde ein Vielfaches einbringen.
    return _melde(float(Ronde.ehre(120)) > float(Ronde.ehre(1)) * 50.0,
        "das Einkommen haelt mit den geometrischen Kosten nicht mit")


# --- Die Ronden ------------------------------------------------------------

func _test_ronden_sind_reproduzierbar() -> bool:
    # Dieselbe Ronde muss bei jedem Spieler dieselbe sein, sonst laesst sich
    # nichts nachmessen und niemand kann ueber eine Stelle reden.
    for n in [1, 4, 6, 13, 29]:
        var a := Ronde.gegner(n)
        var b := Ronde.gegner(n)
        if not _melde(a == b, "Ronde %d wechselt ihre Besetzung" % n):
            return false
    return true


func _test_ronde_ist_nie_leer() -> bool:
    for n in range(1, 120):
        if not _melde(Ronde.gegner(n).size() > 0,
                "Ronde %d hat keinen einzigen Gegner" % n):
            return false
    return true


func _test_ronde_waechst() -> bool:
    # Nicht die rohe Zahl waechst, sondern der Anspruch: eine Ronde mit dem
    # Meister ist kuerzer und trotzdem schwerer. Geprueft wird deshalb das
    # Budget und nicht die Kopfzahl.
    for n in range(1, 60):
        var jetzt := Ronde.staerke(n) / float(Ronde.gleichzeitig(n))
        var danach := Ronde.staerke(n + 1) / float(Ronde.gleichzeitig(n + 1))
        if not _melde(danach >= jetzt - 0.001,
                "Ronde %d verlangt weniger als %d" % [n + 1, n]):
            return false
    return _melde(Ronde.staerke(60) > Ronde.staerke(1) * 1.8,
        "ueber sechzig Ronden muss das Budget deutlich steigen")


func _test_meister_tritt_zuletzt_an() -> bool:
    # Eine Ronde, die mit ihrem groessten Gegner anfaengt, hat keinen Bogen,
    # sondern ein Nachspiel.
    for n in range(1, 120):
        var liste := Ronde.gegner(n)
        for i in liste.size():
            if not Gegner.ist_meister(liste[i]):
                continue
            if not _melde(i == liste.size() - 1,
                    "Ronde %d hat den Meister an Platz %d von %d"
                    % [n, i, liste.size()]):
                return false
    return true


# --- Das Duell -------------------------------------------------------------

func _test_lesezeit_bleibt_menschlich() -> bool:
    # Der Ansatz ist die Lesezeit, und sie darf nie unter eine
    # Reaktionszeit fallen - auch nicht fuer den schnellsten Gegner auf
    # einer Schule ohne jede Stufe.
    const REAKTION := 0.25
    for a in Gegner.Art.size():
        var d := Duell.ansatzdauer(a, Schule.lesezeit(0))
        if not _melde(d >= REAKTION * 2.0,
                "%s holt nur %.2f s aus" % [Gegner.name_von(a), d]):
            return false
    return true


func _test_fuehrung_und_fenster_teilen_die_zahl() -> bool:
    # **Was gezeigt wird, muss gelten.** Die Zinnoberlinie nimmt ihre Laenge
    # aus `fuehrungsanteil()`; das Fenster liegt um den Punkt, an dem dieser
    # Anteil eins erreicht. Liefen beide auseinander, waere die Linie eine
    # Luege - und das Spiel unlernbar.
    var k := Duell.Klinge.new()
    var s := Duell.Stand.new()
    k.lage = Duell.Lage.ANSATZ
    k.art = Gegner.Art.RONIN
    k.dauer = Duell.ansatzdauer(k.art, 0.0)
    k.in_mensur = true
    var f := Duell.fensterbreite(k.art, 0.0)

    k.uhr = k.dauer
    if not _melde(is_equal_approx(Duell.fuehrungsanteil(k), 1.0)
            and Duell.im_fenster(k, s),
            "im Augenblick des Schlags muss die Linie voll und das Fenster offen sein"):
        return false
    k.uhr = k.dauer - f * 1.2
    if not _melde(not Duell.im_fenster(k, s),
            "vor dem Fenster darf nichts treffen"):
        return false
    k.uhr = k.dauer + f * 1.2
    return _melde(not Duell.im_fenster(k, s),
        "nach dem Fenster darf nichts mehr treffen")


## Ein Spieler, der liest: er antwortet genau dann, wenn ein Gegner im
## Fenster steht, und faellt Offene, wenn nichts draengt.
func _spiele(nummer: int, stufe: int, ruehrt: bool, saat: int) -> Duell.Stand:
    var stufen := {}
    for h in Schule.NAMEN.size():
        stufen[h] = stufe
    var s := Duell.baue(nummer, stufen)
    var rng := RandomNumberGenerator.new()
    rng.seed = saat
    var takt := 1.0 / 60.0
    var t := 0.0
    var ruehr_uhr := 0.0
    while s.lebt() and not Duell.geraeumt(s) and t < 400.0:
        Duell.schritt(s, takt, rng)
        t += takt
        if ruehrt:
            # Der Ruehrer wischt blind, so schnell er darf.
            ruehr_uhr -= takt
            if ruehr_uhr <= 0.0:
                ruehr_uhr = 0.09
                var l: int = Schnitte.GEWISCHT[rng.randi_range(
                    0, Schnitte.GEWISCHT.size() - 1)]
                Duell.antworte(s, Schnitte.richtung(l) * 120.0)
            continue
        for k in s.klingen:
            if not k.lebt() or not k.in_mensur:
                continue
            if Duell.im_fenster(k, s):
                if Schnitte.ist_stoss(k.wahre_linie):
                    Duell.antworte(s, Vector2(3.0, 0.0))
                else:
                    Duell.antworte(s, Schnitte.richtung(k.wahre_linie) * 130.0)
                break
            if k.lage == Duell.Lage.OFFEN:
                Duell.antworte(s, Vector2(130.0, 0.0))
                break
    return s


func _test_ein_leser_gewinnt() -> bool:
    # **Die untere Schranke.** Der simulierte Daumen kann genau eine Sache:
    # die wahre Linie treffen, sobald das Fenster offen ist. Er weicht nicht
    # aus, priorisiert nicht und sieht keine Taeuschung kommen - alles, was
    # ein Mensch zusaetzlich kann, geht als Reserve in das Ergebnis ein.
    #
    # Wer das hier rot sieht, hat eine Ronde gebaut, die niemand raeumen
    # kann; die Schranke wird nicht gelockert, damit eine Aenderung durchgeht.
    var gefallen := 0
    for n in range(1, 41):
        var s := _spiele(n, Schule.stufe_soll(n), false, 1000 + n)
        if not Duell.geraeumt(s):
            gefallen += 1
            _melde(false, "Ronde %d nicht geraeumt (Atem %d/%d, offen %d)"
                % [n, s.atem, s.atem_voll, s.offen()])
    return _melde(gefallen == 0,
        "%d von 40 Ronden sind fuer einen Leser nicht zu raeumen" % gefallen)


func _test_ruehren_verliert() -> bool:
    # **Die Zusage, an der das ganze Spiel haengt.** Ohne die Sperre nach
    # einem Fehlgriff waere die beste Strategie, alle vier Achsen dauernd
    # durchzuwischen, bis eine passt - und dann waere es kein Lesen mehr,
    # sondern Ruehren. Geprueft wird nicht, dass Ruehren *schlechter* ist,
    # sondern dass es **verliert**: ein Vorteil, den man sich erruehren
    # kann, ist ein Fehler und kein Schwierigkeitsgrad.
    var geraeumt := 0
    for n in [4, 8, 12, 16, 20]:
        var s := _spiele(n, Schule.stufe_soll(n), true, 2000 + n)
        if Duell.geraeumt(s):
            geraeumt += 1
            _melde(false, "Ronde %d liess sich erruehren" % n)
    return _melde(geraeumt == 0,
        "%d Ronden liessen sich blind erruehren" % geraeumt)


func _test_kein_platz_doppelt_besetzt() -> bool:
    # Zwei Gegner auf derselben Stelle stehen im Bild ineinander. Der Kern
    # weiss nicht, wo eine Stelle liegt - aber er weiss, dass zwei nicht
    # dieselbe haben duerfen.
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    for n in [7, 11, 18, 26]:
        var stufen := {}
        for h in Schule.NAMEN.size():
            stufen[h] = Schule.stufe_soll(n)
        var s := Duell.baue(n, stufen)
        var t := 0.0
        while s.lebt() and not Duell.geraeumt(s) and t < 60.0:
            Duell.schritt(s, 1.0 / 60.0, rng)
            t += 1.0 / 60.0
            var belegt := {}
            for k in s.klingen:
                if not k.lebt() or not k.in_mensur:
                    continue
                if not _melde(not belegt.has(k.stelle),
                        "Ronde %d: zwei Gegner auf Stelle %d" % [n, k.stelle]):
                    return false
                belegt[k.stelle] = true
                if not _melde(k.stelle < s.gleichzeitig,
                        "Ronde %d: Stelle %d ausserhalb der Mensur"
                        % [n, k.stelle]):
                    return false
            # Damit die Schleife nicht an einem perfekten Spieler haengt:
            for k in s.klingen:
                if k.lebt() and k.in_mensur and Duell.im_fenster(k, s):
                    if Schnitte.ist_stoss(k.wahre_linie):
                        Duell.antworte(s, Vector2(3.0, 0.0))
                    else:
                        Duell.antworte(s,
                            Schnitte.richtung(k.wahre_linie) * 130.0)
                    break
                if k.lebt() and k.in_mensur and k.lage == Duell.Lage.OFFEN:
                    Duell.antworte(s, Vector2(130.0, 0.0))
                    break
    return true
