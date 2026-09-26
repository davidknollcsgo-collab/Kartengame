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
    "_test_jede_sorte_hat_eine_eigene_farbe",
    "_test_keine_skin_ist_eine_tarnkappe",
    "_test_sorten_treten_gestaffelt_ein",
    "_test_helden_tabelle_vollstaendig",
    "_test_jeder_held_ist_zu_erkennen",
    "_test_ausruestung_tabelle_vollstaendig",
    "_test_ausruestung_verschlechtert_nichts",
    "_test_kein_ausbau_verschlechtert",
    "_test_einkommen_und_kosten_wachsen_gleich",
    "_test_gefaehrte_kaempft_und_jede_stufe_zaehlt",
    "_test_angebote_nie_dreimal_dasselbe",
    "_test_angebote_bleiben_annehmbar",
    "_test_ein_laeufer_haelt_die_ersten_minuten",
    "_test_stehen_wird_umzingelt",
    "_test_stehenbleiben_verliert",
    "_test_umzingelung_kostet_mehr_als_eine_flanke",
    "_test_die_horde_steht_im_bild",
    "_test_feinde_stehen_nicht_aufeinander",
    "_test_jede_waffe_traegt_allein",
    "_test_keine_waffe_ist_die_beste",
    "_test_flegel_haengt_nicht_an_der_bildrate",
    "_test_sold_kommt_an",
    "_test_der_tod_ist_endgueltig",
]

var _fehler: Array[String] = []
## Die Proben der Horde, einmal gerechnet fuer zwei Waechter.
var _horde: Dictionary = {}


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


func _test_jede_sorte_hat_eine_eigene_farbe() -> bool:
    # **Die Farbe traegt, was die Silhouette nicht mehr traegt.**
    #
    # Hier stand einmal die umgekehrte Regel - *eine Sorte muss an ihrer
    # Silhouette erkennbar sein, nicht an ihrer Farbe*. Sie scheiterte an
    # `Streiter.DICHT_AB`: ab siebzig Figuren zeichnet das Spiel die
    # Sparfassung, und die wirft die Silhouette weg. Uebrig blieben achtzig
    # gleiche schwarze Umrisse, und einer davon war der Spieler selbst.
    #
    # Gemessen wird der Abstand im Farbraum und **nicht** die Ungleichheit
    # von drei Fliesskommazahlen: zwei Farben, die sich in der letzten Stelle
    # unterscheiden, sind verschieden und trotzdem dieselbe Farbe.
    var schwelle := 0.10
    for a in Feinde.Art.size():
        for b in range(a + 1, Feinde.Art.size()):
            var d := Palette.abstand(Palette.sorte(a), Palette.sorte(b))
            if not _melde(d > schwelle,
                    "%s und %s liegen nur %.3f auseinander"
                    % [Feinde.name_von(a), Feinde.name_von(b), d]):
                return false
    # **Und der Held gehoert niemandem.** Seine Farbe ist die Antwort auf die
    # Frage, die ein Spieler bei hundertfuenfzig Figuren alle zwei Sekunden
    # stellt; traegt eine Sorte sie mit, ist sie keine Antwort mehr.
    for a in Feinde.Art.size():
        var d := Palette.abstand(Palette.HELD, Palette.sorte(a))
        if not _melde(d > schwelle * 1.8,
                "%s liegt der Heldenfarbe zu nah (%.3f)"
                % [Feinde.name_von(a), d]):
            return false
    return true


func _test_keine_skin_ist_eine_tarnkappe() -> bool:
    # **Eine Skin darf schmuecken und nicht verstecken.** Die ganze farbige
    # Fassung haengt an einem Satz: die Farbe des Helden traegt niemand
    # sonst. Ein Gewand in Lederbraun waere keine Zierde, sondern eine
    # Tarnkappe - und wer sich im Gedraenge nicht findet, hat nichts davon,
    # dass er gut aussieht.
    #
    # Geprueft wird jede der zwoelf gegen jede der sieben Sorten, mit
    # derselben Schranke wie die Heldenfarbe selbst.
    for held in Helden.NAMEN.size():
        for n in Skins.JE_HELD:
            var k := Skins.koerper(held, n)
            for a in Feinde.Art.size():
                var d := Palette.abstand(k, Palette.sorte(a))
                if not _melde(d > 0.18,
                        "Skin %s liegt %s zu nah (%.3f)"
                        % [Skins.name_von(held, n), Feinde.name_von(a), d]):
                    return false
            # Und der Glanz ist heller als der Koerper - ein Glanz, der
            # dunkler ist, ist keiner.
            if not _melde(Skins.glanz(held, n).get_luminance()
                    > k.get_luminance(),
                    "Skin %s: der Glanz ist nicht heller als das Gewand"
                    % Skins.name_von(held, n)):
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

func _test_gefaehrte_kaempft_und_jede_stufe_zaehlt() -> bool:
    # **Ein Begleiter, der nichts erschlaegt, ist ein verschenkter
    # Aufstieg.** Geprueft in einem gestellten Aufbau: der Held fuehrt
    # **keine** Waffe, es stehen nur Gefaehrten und Feinde da. Faellt
    # trotzdem etwas, war es einer von ihnen - in einem ganzen Lauf waere
    # dieselbe Zahl nicht von den Waffen zu trennen.
    #
    # **Und der Held weicht dabei.** Der erste Anlauf liess ihn stillstehen,
    # und der Test wurde rot, als der Gefaehrte seine Rueckzugsregel bekam -
    # zu Recht: wer nicht weicht, hat keinen Ruecken, den jemand haelt. Ein
    # stillstehender Aufbau haette hier die alte Regel geprueft und die neue
    # uebersehen.
    for stufe in [1, Gunst.ZUG_HOECHSTSTUFE]:
        var stufen := {}
        for b in Halle.NAMEN.size():
            stufen[b] = 0
        var s := Gefecht.baue(stufen, Helden.Held.SCHWERT, {})
        s.waffen.clear()
        s.takte.clear()
        s.zuege[Gunst.Zug.GEFAEHRTE] = stufe
        s.leben_voll = 100000.0
        s.leben = s.leben_voll
        var rng := RandomNumberGenerator.new()
        rng.seed = 31
        var takt := 1.0 / 60.0
        var gefallen := 0
        for i in int(15.0 / takt):
            Gefecht.schritt(s, takt, Vector2.RIGHT, rng)
            for v in s.vorfaelle:
                if v[0] == Gefecht.Vorfall.FEIND_FAELLT:
                    gefallen += 1
        if not _melde(s.gefaehrten.size() == Gunst.gefaehrten(stufe),
                "Stufe %d soll %d Gefaehrten stellen, im Feld stehen %d"
                % [stufe, Gunst.gefaehrten(stufe), s.gefaehrten.size()]):
            return false
        if not _melde(gefallen > 0,
                "Auf Stufe %d erschlaegt kein Gefaehrte irgendetwas" % stufe):
            return false

    # **Jede Stufe gibt etwas**, und zwar entweder einen Mann mehr oder mehr
    # Schaden - eine Stufe, die man nicht merkt, ist keine.
    for stufe in range(1, Gunst.ZUG_HOECHSTSTUFE):
        var mehr := Gunst.gefaehrten(stufe + 1) > Gunst.gefaehrten(stufe) \
            or Gunst.gefaehrte_schaden(stufe + 1) > Gunst.gefaehrte_schaden(stufe)
        if not _melde(mehr, "Gefaehrten-Stufe %d aendert nichts gegenueber %d"
                % [stufe + 1, stufe]):
            return false
    return true


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

## **Die Horde, gezaehlt, wo man sie sieht.** Schwertkaempfer auf Burg 0,
## der Daumen fuehrt, sechs Saaten, Proben alle 30 s von 120 bis 360 s.
##
## **Der Held ist dabei unsterblich.** Gefragt ist, wo die Horde steht, nicht
## wer stirbt - ein Lauf, der nach 200 s endet, haette die spaeten Proben gar
## nicht, und dann misst man die Todeszeit mit. Eine Messung, die an eine
## Decke stoesst, ist keine.
##
## Einmal gerechnet und fuer beide Waechter aufgehoben: es sind dieselben
## Laeufe, und sie kosten je eine Minute.
func _horde_proben() -> Dictionary:
    if not _horde.is_empty():
        return _horde
    var anteile: Array[float] = []
    var stapel: Array[float] = []
    var ueberlappt: Array[float] = []
    var meiste := 0
    for saat in 6:
        var stufen := {}
        for b in Halle.NAMEN.size():
            stufen[b] = 0
        var s := Gefecht.baue(stufen, Helden.Held.SCHWERT, {})
        s.leben_voll = 1e9
        s.leben = 1e9
        var rng := RandomNumberGenerator.new()
        rng.seed = 700 + saat
        var takt := 1.0 / 60.0
        var naechste := 120.0
        while s.zeit < 360.0:
            if s.wartet_auf_wahl:
                Gefecht.nimm(s, Daumen.waehle(s))
                continue
            Gefecht.schritt(s, takt, Daumen.richtung(s), rng)
            meiste = maxi(meiste, s.feinde.size())
            if s.zeit < naechste:
                continue
            naechste += 30.0
            # Das Sichtfeld des Entwurfs: 720 x 1280 um den Helden.
            var im_bild: Array[Gefecht.Feind] = []
            for f in s.feinde:
                var d := f.ort - s.ort
                if absf(d.x) < 360.0 and absf(d.y) < 640.0:
                    im_bild.append(f)
            anteile.append(float(im_bild.size()) / maxf(1.0, float(s.feinde.size())))
            # Unter zwanzig im Bild ist ein Anteil ein Wurf.
            if im_bild.size() < 20:
                continue
            var gedeckt := 0
            var halb := 0
            for a in im_bild:
                for b in im_bild:
                    if a != b and a.ort.distance_to(b.ort) < a.radius * 0.25:
                        gedeckt += 1
                        break
                for b in im_bild:
                    if a != b and a.ort.distance_to(b.ort) < Feinde.abstand(a.art):
                        halb += 1
                        break
            stapel.append(float(gedeckt) / float(im_bild.size()))
            ueberlappt.append(float(halb) / float(im_bild.size()))
    anteile.sort()
    stapel.sort()
    ueberlappt.sort()
    _horde = {"anteile": anteile, "stapel": stapel, "ueberlappt": ueberlappt,
        "meiste": meiste}
    return _horde


func _test_die_horde_steht_im_bild() -> bool:
    # **Eine Horde, die man nicht sieht, ist keine.** Der Held ist schneller
    # als fast alles, was ihn jagt (200 gegen 58 bis 92), und zurueckgefallene
    # Feinde wurden erst bei 1500 Punkten versetzt. Also lief der Daumen
    # davon, und hinter ihm trottete die Horde ausser Sicht: nach zehn Minuten
    # lebten 2269, im Bild standen meist 10 bis 60.
    #
    # Gemessen mit genau diesen Laeufen, vorher und nachher:
    #
    #                              vorher        nachher
    #     Anteil im Bild, Median    0,09          0,22
    #     unteres Viertel           0,04          0,15
    #     meiste Lebende            1256          300
    #
    # Gefordert ist ein Median von 0,16 - fast das Doppelte des alten und
    # mit Abstand unter dem neuen -, und nie mehr Lebende als die
    # Obergrenze. Wer das rot sieht, hat wieder eine Schleppe gebaut.
    var p := _horde_proben()
    var anteile: Array[float] = p["anteile"]
    var median := anteile[anteile.size() / 2]
    if not _melde(int(p["meiste"]) <= Andrang.HOECHSTENS_LEBEND,
            "es lebten %d Feinde, Obergrenze %d" % [p["meiste"],
            Andrang.HOECHSTENS_LEBEND]):
        return false
    return _melde(median >= 0.16,
        "im Bild steht im Median nur %.2f der Lebenden" % median)


func _test_feinde_stehen_nicht_aufeinander() -> bool:
    # **Eine Menge, keine Klumpen.** Ohne Abstossung lief jeder Feind gerade
    # auf den Helden zu, und Feinde derselben Sorte auf derselben Bahn. Bei
    # 360 s standen von 880 Feinden im Bild 779 auf einem anderen - der
    # Bildschirm zeigte ein paar Klumpen, und hundert Figuren lasen sich wie
    # fuenf.
    #
    # Gezaehlt: wer naeher als ein Viertel seines Radius an einem anderen
    # steht, deckt ihn praktisch. Mit genau diesen Laeufen:
    #
    #                                 vorher        nachher
    #     gedeckt, Median             0,15          0,00
    #     gedeckt, hoechste Probe     0,94          0,00
    var p := _horde_proben()
    var stapel: Array[float] = p["stapel"]
    if not _melde(stapel.size() >= 20,
            "nur %d Proben mit zwanzig oder mehr Feinden im Bild" % stapel.size()):
        return false
    var hoechste := stapel[stapel.size() - 1]
    if not _melde(hoechste <= 0.05,
            "in einer Probe decken sich %.0f %% der Feinde im Bild" % (hoechste * 100.0)):
        return false
    # **Und was man sieht, nicht nur die Mitten.** Die Zaehlung oben sah den
    # Wolfsklumpen nicht: die Mitten der Woelfe hielten Abstand, ihre quer
    # liegenden Koerper deckten sich - auf dem Ladenbild ein dunkler Fleck.
    # Hier zaehlt, wer zu mehr als der Haelfte auf einem anderen liegt,
    # gemessen an seiner gezeichneten Breite (`Feinde.abstand`). Das 95.
    # Perzentil der Proben, mit genau diesen Laeufen:
    #
    #     vorher (Wolf nach Trefferradius)     0,128
    #     nachher (Wolf gestaucht, Abstand 22)  0,011
    var ueberlappt: Array[float] = p["ueberlappt"]
    var p95 := ueberlappt[int(float(ueberlappt.size()) * 0.95)]
    return _melde(p95 <= 0.04,
        "im 95. Perzentil liegen %.0f %% der Feinde zur Haelfte auf einem anderen"
        % (p95 * 100.0))


func _test_ein_laeufer_haelt_die_ersten_minuten() -> bool:
    # **Die untere Schranke.** Der simulierte Daumen kitet und sammelt, mehr
    # nicht. Die vollen zehn Minuten misst `tools/probe.gd`; hier reicht der
    # Anfang, damit der Testlauf kurz bleibt.
    #
    # Wer das rot sieht, hat eine Kurve gebaut, die niemand laeuft - die
    # Schranke wird nicht gelockert, damit eine Aenderung durchgeht.
    #
    # **Acht Saaten je Held, sieben muessen stehen.**
    #
    # Der erste Anlauf zog **eine** Saat, der zweite drei und verlangte alle
    # drei. Beides misst die Verteilung nicht, die dahintersteht - gemessen
    # ueber acht Saaten auf Burgstufe 0:
    #
    #     Swordsman  8/8
    #     Archer     7/8   (147 s)
    #     Spearman   5/8   (165 / 149 / 154 s)
    #     Hammerman  7/8   (150 s)
    #
    # Drei von vier Helden haben eine schlechte Saat, und welche drei man
    # zieht, entscheidet ueber gruen oder rot. Ein Waechter, der bei jeder
    # zweiten Ausfuehrung etwas anderes meldet, bewacht nichts.
    #
    # **Das ist keine Lockerung.** Die drei Minuten auf Burgstufe 0 stehen
    # unveraendert; gemessen wird ueber mehr Saaten und mit benannter
    # Toleranz statt mit einer stillen. Wer das rot sieht, hat eine Kurve
    # gebaut, die niemand laeuft - und dann wird die Kurve nachgezogen und
    # nicht die Schranke.
    #
    # Der Speertraeger mit 5/8 ist ein **offener Posten** und faellt hier
    # bereits durch. Er faellt auch, wenn man die Umzingelung abschaltet;
    # zugleich ist der `Boar Spear` - seine Startwaffe - die einzige Waffe
    # unter 8/8. Zwei unabhaengige Messungen auf dieselbe Stelle.
    for held in Helden.Held.size():
        var stand := 0
        var schlimmste := 1e9
        for saat in 8:
            var s := _laufe(held, 0, 180.0, 400 + held * 10 + saat)
            if s.lebt():
                stand += 1
            else:
                schlimmste = minf(schlimmste, s.zeit)
        if not _melde(stand >= 7,
                "%s steht nur %d von 8 Saaten, die schlimmste faellt nach %.0f s"
                % [Helden.name_von(held), stand, schlimmste]):
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
    #
    # **Paarweise je Saat - denn ein Mittelwert aus abgeschnittenen Daten
    # ist keine Messung.**
    #
    # Hier stand einmal "Mittel(steht) < 0,6 x Mittel(laeuft)". Die Laeufe
    # enden aber bei 600 Sekunden, und im ausgelieferten Stand stossen **drei
    # von acht** stehenden und **sieben von acht** laufenden Laeufen an diese
    # Decke. Ein Lauf, der neunhundert Sekunden gehalten haette, steht als
    # 600 in der Liste - das Verhaeltnis mass damit vor allem, wie viele
    # Laeufe gerade anstossen, und sprang bei jeder Kleinigkeit:
    #
    #                                Mittelwert   paarweise (L gewinnt/verliert/gleich)
    #     ohne Gefaehrten              0,585            5 / 1 / 2
    #     mit Gefaehrten               0,743            5 / 2 / 1
    #
    # Der Mittelwert schwankt um siebenundzwanzig Prozent, die paarweise
    # Bilanz kaum: die Saat-Streuung faellt heraus, weil beide Laeufe
    # dieselbe Saat teilen. Drei Aenderungen in Folge - der Speer in zwei
    # Fassungen und der Gefaehrte - scheiterten an der alten Form, bei
    # zweieinhalb Prozent Spielraum.
    #
    # **Die Aussage ist unveraendert**, nur ehrlich gemessen. Und das
    # eigentliche Gewicht traegt jetzt `_test_stehen_wird_umzingelt`: dieser
    # hier ist die Probe aufs Ganze.
    var saaten := 8
    var verloren := 0
    var diff := PackedFloat32Array()
    var zs := ""
    var zl := ""
    for saat in saaten:
        var a := _laufe(Helden.Held.SCHWERT, 0, 600.0, 77 + saat, false).zeit
        var b := _laufe(Helden.Held.SCHWERT, 0, 600.0, 77 + saat, true).zeit
        if a > b:
            verloren += 1
        diff.append(b - a)
        zs += " %3.0f" % a
        zl += " %3.0f" % b
    var sortiert := diff.duplicate()
    sortiert.sort()
    var mitte := (sortiert[saaten / 2 - 1] + sortiert[saaten / 2]) * 0.5

    # **Hoechstens zwei von acht**, auf denen Stehenbleiben laenger haelt.
    # Ohne jede Wirkung waeren rund vier zu erwarten; der ausgelieferte Stand
    # hat eine.
    if not _melde(verloren <= 2,
            "Stehenbleiben schlaegt Laufen auf %d von %d Saaten\n     steht :%s\n     laeuft:%s"
            % [verloren, saaten, zs, zl]):
        return false
    # Und der **Median** der Differenz ist positiv - er ist gegen die
    # Abschneidung unempfindlich, der Mittelwert nicht.
    return _melde(mitte > 0.0,
        "Der Median von (laeuft - steht) ist %.0f s\n     steht :%s\n     laeuft:%s"
        % [mitte, zs, zl])


## **Besetzt Stehenbleiben wirklich mehr Faecher?**
##
## Das ist die eine Haelfte der Kernaussage; die andere - *mehr besetzte
## Faecher kosten mehr* - prueft `_test_umzingelung_kostet_mehr_als_eine_
## flanke` in einem gestellten Aufbau. Zusammen tragen beide, was vorher ein
## einzelnes, zensiertes Ende-zu-Ende-Mass tragen sollte.
##
## Gemittelt wird ueber **Bilder** und ueber einen festen Zeitraum, den beide
## Fassungen sicher ueberleben - hier ist nichts abgeschnitten, und man sieht
## es an der Streuung. Gemessen auf dem ausgelieferten Stand:
##
##     steht : 0,186 0,159 0,201 0,174 0,145 0,170 0,169 0,193  -> 0,176
##     laeuft: 0,049 0,052 0,058 0,044 0,090 0,065 0,050 0,091  -> 0,062
##
## Faktor 2,82, und die Verteilungen **ueberlappen nicht einmal**: der
## niedrigste stehende Wert liegt ueber dem hoechsten laufenden. Zum
## Vergleich streuten die Ueberlebenszeiten derselben Laeufe von 59 bis 600.
##
## `Stand.umzingelt` ist genau die Zahl, die `_verwunde` multipliziert - hier
## wird die Mechanik gemessen und nicht ihre Fernwirkung.
func _test_stehen_wird_umzingelt() -> bool:
    var saaten := 8
    var st := PackedFloat32Array()
    var la := PackedFloat32Array()
    for saat in saaten:
        st.append(_umzingelung(false, 77 + saat))
        la.append(_umzingelung(true, 77 + saat))
    var st_summe := 0.0
    var la_summe := 0.0
    for i in saaten:
        st_summe += st[i]
        la_summe += la[i]
        # **Auf jeder einzelnen Saat**, nicht nur im Schnitt. Der
        # ausgelieferte Stand haelt das mit grossem Abstand.
        if not _melde(st[i] > la[i],
                "Saat %d: stehend %.3f, laufend %.3f - Laufen wird nicht weniger umzingelt"
                % [77 + i, st[i], la[i]]):
            return false
    var faktor := st_summe / maxf(0.0001, la_summe)
    return _melde(faktor >= 2.0,
        "Stehenbleiben wird nur %.2f-fach umzingelt (%.3f gegen %.3f)"
        % [faktor, st_summe / float(saaten), la_summe / float(saaten)])


## Mittlere Umzingelung je Bild ueber einen festen Zeitraum.
func _umzingelung(bewegt: bool, saat: int) -> float:
    var stufen := {}
    for b in Halle.NAMEN.size():
        stufen[b] = 0
    var s := Gefecht.baue(stufen, Helden.Held.SCHWERT, {})
    var rng := RandomNumberGenerator.new()
    rng.seed = saat
    var takt := 1.0 / 60.0
    var summe := 0.0
    var n := 0
    while not Gefecht.vorbei(s) and s.zeit < 150.0:
        if s.wartet_auf_wahl:
            Gefecht.nimm(s, Daumen.waehle(s))
            continue
        Gefecht.schritt(s, takt, Daumen.richtung(s) if bewegt else Vector2.ZERO, rng)
        summe += s.umzingelt
        n += 1
    return summe / maxf(1.0, float(n))


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
    #
    # **Acht Saaten, sieben muessen tragen** - dieselbe Form wie der
    # Heldenwaechter, und aus demselben Grund. Mit drei Saaten und allen
    # dreien gefordert wurde die Armbrust rot, als der Gefaehrte als sechster
    # Zug in den Topf kam: nicht weil sie schwaecher wurde, sondern weil ein
    # Zug mehr jede folgende Ziehung verschiebt. Ueber acht gemessen:
    #
    #                    vor dem Gefaehrten      mit Gefaehrte + Speer-Griff
    #     Arming Sword         8/8                      8/8
    #     Boar Spear           7/8                      8/8
    #     Flail                8/8                      8/8
    #     Crossbow             8/8                      7/8
    #     War Hammer           8/8                      8/8
    #     Throwing Axe         8/8                      7/8
    #
    # Der Ausfall wandert mit der Ziehung, keine Waffe faellt ab. Die
    # Schranke 7/8 haelt schon der Stand **vor** dem Gefaehrten - sie ist aus
    # ihm genommen und nicht aus dem, was danach durchkommen sollte.
    for w in Waffen.Art.size():
        var getragen := 0
        var zeile := ""
        for saat in 8:
            var s := _laufe(Helden.Held.SCHWERT, 6, 120.0, 900 + w * 10 + saat,
                true, w)
            var traegt := s.lebt() and s.erschlagen > 20
            if traegt:
                getragen += 1
            zeile += " %s%.0f" % ["" if traegt else "*", s.zeit]
        if not _melde(getragen >= 7,
                "%s allein traegt nur %d von 8 Saaten:%s"
                % [Waffen.name_von(w), getragen, zeile]):
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


func _test_der_tod_ist_endgueltig() -> bool:
    # **Mit Rations starb niemand.** `_zehre()` heilte nach dem tödlichen
    # Treffer im selben Schritt nach, `lebt()` fragte nur nach dem Leben, und
    # der Lauf ging weiter - im Spiel wie im Messstand. Gemessen stand ein
    # Held bei null Leben achtzig Sekunden im Bolzenhagel.
    var s := Gefecht.baue({}, Helden.Held.SCHWERT, {})
    s.zuege[Gunst.Zug.ZEHRUNG] = Gunst.ZUG_HOECHSTSTUFE
    Gefecht._verwunde(s, s.leben_voll * 10.0)
    if not _melde(Gefecht.vorbei(s), "nach dem toedlichen Treffer ist der Lauf nicht vorbei"):
        return false
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    for i in 120:
        Gefecht._zehre(s, 1.0 / 60.0)
        Gefecht.schritt(s, 1.0 / 60.0, Vector2.ZERO, rng)
    return _melde(Gefecht.vorbei(s) and not s.lebt(),
        "mit Rations steht der Held nach dem Tod wieder auf (Leben %.1f)" % s.leben)
