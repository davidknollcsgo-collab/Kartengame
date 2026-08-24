## Headless-Testlauf: godot --headless --path . --script tests/run_tests.gd
##
## Bewusst ohne Test-Framework als Abhaengigkeit - ein paar Zusicherungen und
## ein Zaehler genuegen. Beendet mit Code 1, sobald etwas fehlschlaegt, damit
## die CI den Lauf als rot erkennt.
extends SceneTree

var _bestanden := 0
var _fehler: Array[String] = []

## Ausserhalb des Szenenbaums erzeugte Nodes muessen von Hand freigegeben
## werden - sonst meldet Godot beim Beenden geleakte Objekte.
var _staende: Array[Node] = []


## Alle Testfunktionen. Der Laeufer ruft sie ueber den Namen auf, damit ein
## Abbruch mitten in einem Test auffaellt.
const TESTS: PackedStringArray = [
    "_test_kostenkurve", "_test_massenkauf", "_test_max_kaufbar",
    "_test_meilensteine", "_test_produktion", "_test_prestige", "_test_kaltstart",
    "_test_offline", "_test_speicherstand", "_test_formatter",
    "_test_ausbauten", "_test_modul_ausbau", "_test_protokoll_ausbau", "_test_errungenschaften", "_test_layout", "_test_speicher_platte", "_test_langzeit",
]


func _init() -> void:
    print("── STERNWERFT Testlauf ────────────────────────")
    _pruefe_vollstaendigkeit()
    for name in TESTS:
        # Ein Laufzeitfehler in GDScript bricht nur die betroffene Funktion ab
        # und liefert null zurueck. Ohne diese Pruefung meldete der Lauf gruen,
        # obwohl ein ganzer Test nie zu Ende lief.
        if call(name) != true:
            _fehler.append("%s wurde abgebrochen (Laufzeitfehler weiter oben)" % name)

    for st in _staende:
        st.free()
    _staende.clear()

    print("───────────────────────────────────────────────")
    if _fehler.is_empty():
        print("✓ %d Zusicherungen in %d Tests bestanden" % [_bestanden, TESTS.size()])
        quit(0)
    else:
        for f in _fehler:
            printerr("✗ " + f)
        printerr("%d Fehler bei %d Zusicherungen" % [_fehler.size(), _bestanden])
        quit(1)


## Stellt sicher, dass jede vorhandene Testfunktion auch aufgerufen wird.
##
## Entstanden aus einem echten Fehler: beim Umbau des Laeufers fiel
## _test_prestige aus der Liste und lief mehrere Commits lang nicht mit. Die
## Abbrucherkennung half nicht - ein Test, der nie aufgerufen wird, kann auch
## nicht abbrechen. Nur ein Abgleich gegen die tatsaechlich vorhandenen
## Methoden faellt das auf.
func _pruefe_vollstaendigkeit() -> void:
    for eintrag in get_method_list():
        var name: String = eintrag["name"]
        if name.begins_with("_test_") and not TESTS.has(name):
            _fehler.append("%s ist vorhanden, steht aber nicht in TESTS" % name)


# --- Zusicherungen ----------------------------------------------------------

func _ist(bedingung: bool, name: String) -> void:
    if bedingung:
        _bestanden += 1
    else:
        _fehler.append(name)


func _gleich(a, b, name: String) -> void:
    _ist(a == b, "%s (war %s, erwartet %s)" % [name, str(a), str(b)])


## Relativer Vergleich - bei Werten um 1e20 ist ein absolutes Epsilon sinnlos.
func _nahe(a: float, b: float, name: String, toleranz := 1e-9) -> void:
    var abweichung := absf(a - b) / maxf(absf(b), 1.0)
    _ist(abweichung <= toleranz, "%s (war %f, erwartet %f)" % [name, a, b])


# --- Tests ------------------------------------------------------------------

func _test_kostenkurve() -> bool:
    _nahe(Oekonomie.kosten(0, 0), 15.0, "Erstkauf Solarsegel kostet Basispreis")
    _nahe(Oekonomie.kosten(0, 10), 15.0 * pow(1.12, 10), "Kosten nach 10 Stueck")

    # Ueber die gesamte Spannweite streng steigend und endlich.
    var vorher := 0.0
    var alles_gut := true
    for n in range(0, 201):
        var k := Oekonomie.kosten(7, n)
        if not is_finite(k) or k <= vorher:
            alles_gut = false
            break
        vorher = k
    _ist(alles_gut, "Kostenkurve streng steigend und endlich bis n=200")
    return true


func _test_massenkauf() -> bool:
    # Gegenprobe: geschlossene Formel gegen stumpfe Aufsummierung.
    for index in [0, 3, 7]:
        for besessen in [0, 17, 60]:
            var schleife := 0.0
            for i in range(besessen, besessen + 25):
                schleife += Oekonomie.kosten(index, i)
            var formel := Oekonomie.kosten_summe(index, besessen, 25)
            _nahe(formel, schleife, "Massenkauf-Formel == Schleife (m%d, n%d)" % [index, besessen], 1e-6)

    _gleich(Oekonomie.kosten_summe(0, 0, 0), 0.0, "Menge 0 kostet nichts")
    _gleich(Oekonomie.kosten_summe(0, 0, -5), 0.0, "Negative Menge kostet nichts")
    _nahe(Oekonomie.kosten_summe(0, 0, 1), Oekonomie.kosten(0, 0), "Summe fuer 1 == Einzelpreis")
    return true


func _test_max_kaufbar() -> bool:
    _gleich(Oekonomie.max_kaufbar(0, 0, 0.0), 0, "Ohne Guthaben nichts kaufbar")
    _gleich(Oekonomie.max_kaufbar(0, 0, -100.0), 0, "Negatives Guthaben ergibt 0")
    _gleich(Oekonomie.max_kaufbar(0, 0, 14.0), 0, "Knapp unter Erstpreis ergibt 0")
    _gleich(Oekonomie.max_kaufbar(0, 0, 15.0), 1, "Exakt der Erstpreis ergibt 1")

    # Was als kaufbar gemeldet wird, muss auch bezahlbar sein - und eines mehr nicht.
    for guthaben in [100.0, 5000.0, 1.0e9]:
        var n := Oekonomie.max_kaufbar(1, 4, guthaben)
        _ist(Oekonomie.kosten_summe(1, 4, n) <= guthaben + 1e-6,
            "max_kaufbar(%f) ist bezahlbar" % guthaben)
        _ist(Oekonomie.kosten_summe(1, 4, n + 1) > guthaben,
            "max_kaufbar(%f) ist maximal" % guthaben)
    return true


func _test_meilensteine() -> bool:
    _nahe(Oekonomie.meilenstein_mult(0), 1.0, "Ohne Module kein Meilenstein")
    _nahe(Oekonomie.meilenstein_mult(9), 1.0, "Bei 9 noch kein Meilenstein")
    _nahe(Oekonomie.meilenstein_mult(10), 2.0, "Meilenstein greift exakt bei 10")
    _nahe(Oekonomie.meilenstein_mult(24), 2.0, "Bei 24 weiterhin x2")
    _nahe(Oekonomie.meilenstein_mult(25), 4.0, "Zweiter Meilenstein bei 25")
    _nahe(Oekonomie.meilenstein_mult(50), 8.0, "Dritter bei 50")
    _nahe(Oekonomie.meilenstein_mult(100), 16.0, "Vierter bei 100")
    _nahe(Oekonomie.meilenstein_mult(200), 32.0, "Fuenfter bei 200")
    _nahe(Oekonomie.meilenstein_mult(5000), 32.0, "Danach keine weiteren")
    return true


func _test_produktion() -> bool:
    _nahe(Oekonomie.modul_rate(0, 0), 0.0, "Kein Modul, keine Produktion")
    _nahe(Oekonomie.modul_rate(0, 1), 0.1, "Ein Solarsegel liefert 0.1/s")
    _nahe(Oekonomie.modul_rate(0, 5), 0.5, "Fuenf Solarsegel liefern 0.5/s")
    # 10 Stueck: 0.1 * 10 * Meilenstein x2 = 2.0
    _nahe(Oekonomie.modul_rate(0, 10), 2.0, "Meilenstein verdoppelt die Produktion")
    _nahe(Oekonomie.modul_rate(1, 3, 2.0), 6.0, "Globaler Multiplikator wirkt")

    var bestand := [10, 3, 0, 0, 0, 0, 0, 0]
    _nahe(Oekonomie.gesamt_rate(bestand), 2.0 + 3.0, "Gesamtrate summiert alle Module")
    _nahe(Oekonomie.gesamt_rate([]), 0.0, "Leerer Bestand liefert 0")
    return true


func _test_prestige() -> bool:
    _gleich(Oekonomie.prestige_ertrag(0.0), 0, "Ohne Ertrag keine Protokolle")
    _gleich(Oekonomie.prestige_ertrag(-5.0), 0, "Negativer Ertrag ergibt 0")
    # Das erste Protokoll faellt bei Skala / Faktor^2.
    _gleich(Oekonomie.prestige_ertrag(5.3e5), 0, "Knapp vor dem ersten Protokoll noch 0")
    _gleich(Oekonomie.prestige_ertrag(5.4e5), 1, "Erstes Protokoll bei ~5.33e5")
    _gleich(Oekonomie.prestige_ertrag(1.2e8), 15, "Bei der Bezugsgroesse 15 Protokolle")
    _gleich(Oekonomie.prestige_ertrag(4.8e8), 30, "Vierfacher Ertrag verdoppelt (Wurzel)")

    # Unterhalb der Mindestausbeute bleibt der Reset gesperrt, obwohl die
    # Formel bereits Protokolle ausweisen wuerde.
    _ist(Oekonomie.prestige_ertrag(1e7) > 0, "Formel liefert frueh schon Protokolle")
    _ist(not Oekonomie.prestige_moeglich(1e7),
        "Prestige bleibt unter der Mindestausbeute gesperrt")
    _ist(Oekonomie.prestige_moeglich(1e8), "Prestige ab zehn Protokollen moeglich")

    # Der Spielstand muss die Sperre ebenfalls achten, nicht nur die Leiste.
    var zu_frueh := _neuer_stand()
    zu_frueh.lebenszeit_plasma = 1e7
    zu_frueh.bestand[0] = 5
    _gleich(zu_frueh.prestige(), 0, "Spielstand verweigert zu fruehen Reset")
    _gleich(zu_frueh.bestand[0], 5, "Bei verweigertem Reset bleibt die Station stehen")

    _nahe(Oekonomie.prestige_mult(0), 1.0, "Ohne Protokolle Multiplikator 1")
    _nahe(Oekonomie.prestige_mult(50), 2.0, "50 Protokolle verdoppeln")
    _nahe(Oekonomie.prestige_mult(-3), 1.0, "Negative Protokolle wirken nicht")
    return true


func _test_kaltstart() -> bool:
    var st := _neuer_stand()
    _nahe(float(st.plasma), 15.0, "Neuer Stand hat Startguthaben")
    _ist(st.kaufe(0, 1), "Startguthaben deckt exakt das erste Solarsegel")
    _nahe(float(st.plasma), 0.0, "Danach ist das Guthaben aufgebraucht")
    _ist(st.rate() > 0.0, "Nach dem ersten Kauf laeuft die Produktion")

    # Ohne manuelles Sammeln kaeme ein Stand ohne Module nie in Gang.
    var leer := _neuer_stand()
    leer.plasma = 0.0
    _nahe(leer.rate(), 0.0, "Ohne Module ist die Rate 0")
    var ertrag: float = leer.manuell_sammeln()
    _ist(ertrag >= 1.0, "Antippen liefert auch ohne Module mindestens 1")
    _ist(leer.plasma > 0.0, "Antippen bringt den Kaltstart in Gang")
    return true


func _test_offline() -> bool:
    # 100/s ueber eine Stunde, zu 50 Prozent gutgeschrieben.
    _nahe(Oekonomie.offline_ertrag(100.0, 3600.0), 100.0 * 3600.0 * 0.5, "Offline zu 50 Prozent")
    # Ueber der Obergrenze wird gekappt.
    _nahe(Oekonomie.offline_ertrag(100.0, 99999.0, 3600.0), 100.0 * 3600.0 * 0.5,
        "Offline-Ertrag wird bei Cap gekappt")
    _gleich(Oekonomie.offline_ertrag(100.0, 0.0), 0.0, "Keine Zeit, kein Ertrag")
    _gleich(Oekonomie.offline_ertrag(100.0, -500.0), 0.0, "Zeitruecksprung ergibt 0")
    _gleich(Oekonomie.offline_ertrag(0.0, 3600.0), 0.0, "Ohne Produktion kein Ertrag")

    # Gegen den echten Spielstand: Uhr rueckwaerts darf nichts einbringen.
    var st := _neuer_stand()
    st.bestand[1] = 10
    st.zeitstempel = 10000.0
    _gleich(st.verbuche_offline(9000.0), 0.0, "Spielstand: Ruecksprung bringt nichts")
    _nahe(float(st.zeitstempel), 9000.0, "Spielstand: Zeitstempel wird neu gesetzt")

    var ertrag: float = st.verbuche_offline(9000.0 + 3600.0)
    _ist(ertrag > 0.0, "Spielstand: normale Abwesenheit bringt Ertrag")
    # Die Dauer muss festgehalten werden, weil der Zeitstempel danach neu ist.
    _nahe(float(st.letzte_offline_dauer), 3600.0,
        "Spielstand: angerechnete Dauer wird festgehalten")

    var lang := _neuer_stand()
    lang.bestand[1] = 10
    lang.zeitstempel = 0.0
    lang.verbuche_offline(99999.0)
    _nahe(float(lang.letzte_offline_dauer), Ausbau.offline_grenze(0),
        "Spielstand: festgehaltene Dauer wird auf die Grenze begrenzt")

    var rueck := _neuer_stand()
    rueck.bestand[1] = 10
    rueck.zeitstempel = 5000.0
    rueck.verbuche_offline(4000.0)
    _gleich(rueck.letzte_offline_dauer, 0.0,
        "Spielstand: Zeitruecksprung ergibt auch keine Dauer")
    return true


func _test_ausbauten() -> bool:
    # --- Schub ---
    var a := _neuer_stand()
    _ist(not a.kaufe_schub(), "Schub ohne Quanten nicht kaufbar")
    a.gutschrift_quanten(10)
    _gleich(int(a.quanten), 10, "Gutschrift schreibt Quanten")
    _ist(a.kaufe_schub(), "Schub mit Quanten kaufbar")
    _gleich(int(a.quanten), 10 - Ausbau.SCHUB_KOSTEN, "Schub kostet Quanten")
    _ist(a.boost_aktiv(), "Schub laeuft nach dem Kauf")
    _nahe(float(a.boost_faktor), Ausbau.SCHUB_FAKTOR, "Schubfaktor gesetzt")
    _ist(a.boost_rest() > Ausbau.SCHUB_DAUER - 5.0, "Schub laeuft nahezu die volle Dauer")
    _nahe(a.global_mult(), Ausbau.SCHUB_FAKTOR, "Schub wirkt auf den Multiplikator")

    # Ein zweiter Kauf muss verlaengern, nicht ersetzen - sonst verschenkt ein
    # zu frueher Kauf die gesamte Restzeit.
    var vorher: float = a.boost_rest()
    a.kaufe_schub()
    _ist(a.boost_rest() > vorher + Ausbau.SCHUB_DAUER - 5.0,
        "Zweiter Schub verlaengert statt zu ersetzen")

    # --- Langzeitspeicher ---
    var b := _neuer_stand()
    _nahe(b.offline_grenze(), Ausbau.SPEICHER_GRENZEN[0], "Grundzustand: 4 Stunden")
    _ist(not b.kaufe_speicher(), "Speicherausbau ohne Quanten nicht moeglich")
    b.gutschrift_quanten(200)
    for stufe in Ausbau.SPEICHER_MAX:
        _ist(b.kaufe_speicher(), "Speicherstufe %d kaufbar" % (stufe + 1))
        _gleich(int(b.speicher_stufe), stufe + 1, "Speicherstufe steigt auf %d" % (stufe + 1))
        _nahe(b.offline_grenze(), Ausbau.SPEICHER_GRENZEN[stufe + 1],
            "Offline-Grenze folgt der Stufe %d" % (stufe + 1))
    _ist(Ausbau.speicher_voll(b.speicher_stufe), "Speicher ist voll ausgebaut")
    _ist(not b.kaufe_speicher(), "Voll ausgebauter Speicher nicht weiter kaufbar")
    _gleich(Ausbau.speicher_preis(Ausbau.SPEICHER_MAX), 0, "Voll ausgebaut kostet nichts mehr")

    # --- Orbital-Verstaerker ---
    var c := _neuer_stand()
    c.gutschrift_quanten(Ausbau.VERSTAERKER_KOSTEN)
    _nahe(c.global_mult(), 1.0, "Ohne Verstaerker Multiplikator 1")
    _ist(c.kaufe_verstaerker(), "Verstaerker kaufbar")
    _nahe(c.global_mult(), Ausbau.VERSTAERKER_FAKTOR, "Verstaerker verdoppelt")
    _gleich(int(c.quanten), 0, "Verstaerker kostet alle Quanten")
    c.gutschrift_quanten(500)
    _ist(not c.kaufe_verstaerker(), "Verstaerker nur einmal kaufbar")
    _gleich(int(c.quanten), 500, "Abgelehnter Kauf kostet nichts")

    # Ausbauten muessen den Neustart ueberstehen.
    var d := _neuer_stand()
    d.aus_dict(b.als_dict())
    _gleich(int(d.speicher_stufe), Ausbau.SPEICHER_MAX, "Speicherstufe wird gespeichert")
    var e := _neuer_stand()
    e.aus_dict(c.als_dict())
    _gleich(bool(e.verstaerker), true, "Verstaerker wird gespeichert")
    return true


func _test_speicherstand() -> bool:
    var a := _neuer_stand()
    a.plasma = 12345.678
    a.quanten = 42
    a.protokolle = 7
    a.lebenszeit_plasma = 9.87e15
    a.verstaerker = true
    a.bestand[0] = 13
    a.bestand[5] = 2

    var b := _neuer_stand()
    b.aus_dict(a.als_dict())

    _nahe(b.plasma, a.plasma, "Speicherstand: Plasma")
    _gleich(b.quanten, a.quanten, "Speicherstand: Quanten")
    _gleich(b.protokolle, a.protokolle, "Speicherstand: Protokolle")
    _nahe(b.lebenszeit_plasma, a.lebenszeit_plasma, "Speicherstand: Lebenszeit")
    _gleich(b.verstaerker, true, "Speicherstand: Verstaerker")
    _gleich(b.bestand[0], 13, "Speicherstand: Bestand 0")
    _gleich(b.bestand[5], 2, "Speicherstand: Bestand 5")

    # Beschaedigter Stand darf nicht blockieren.
    var c := _neuer_stand()
    c.aus_dict({})
    _nahe(float(c.plasma), 15.0, "Leeres Dict faellt auf Startguthaben, nicht auf 0")
    _gleich(c.bestand.size(), Modul.ANZAHL, "Bestand hat immer volle Laenge")

    # Migration von Version 1: alte Waehrungsnamen muessen uebernommen werden,
    # sonst verliert jeder bestehende Spieler beim Update seinen Fortschritt.
    var alt := _neuer_stand()
    alt.aus_dict({
        "version": 1, "credits": 777.0, "lebenszeit_credits": 5.5e9,
        "quanten": 0, "kerne": 23, "bestand": [4, 9],
    })
    _nahe(float(alt.plasma), 777.0, "Migration v1: credits werden zu plasma")
    _nahe(float(alt.lebenszeit_plasma), 5.5e9, "Migration v1: Lebenszeit uebernommen")
    _gleich(int(alt.quanten), 23, "Migration v1: kerne werden zu quanten")
    _gleich(int(alt.bestand[1]), 9, "Migration v1: Bestand bleibt erhalten")

    # Migration von Version 0.
    var d := _neuer_stand()
    d.aus_dict({"plasma": 500.0, "bestand": [1, 2]})
    _gleich(int(d.speicher_stufe), 0, "Migration v0 setzt die Speicherstufe")
    _gleich(d.bestand[1], 2, "Migration uebernimmt Teilbestand")
    _gleich(d.bestand[7], 0, "Fehlende Bestandsplaetze werden 0")
    return true


func _test_speicher_platte() -> bool:
    # Eigener Pfad, damit der Testlauf nie den echten Spielstand anfasst.
    var pfad := "user://test_sternwerft.sav"
    Speicher.loesche(pfad)

    _ist(not Speicher.existiert(pfad), "Speicher: vorher keine Datei da")
    _ist(Speicher.lies(pfad).is_empty(), "Speicher: fehlende Datei ergibt leeres Dict")

    var daten := {"version": 1, "plasma": 1234.5, "bestand": [3, 0, 7], "quanten": 9}
    _ist(Speicher.schreibe(daten, pfad), "Speicher: schreiben gelingt")
    _ist(Speicher.existiert(pfad), "Speicher: Datei liegt danach vor")
    _ist(not FileAccess.file_exists(pfad + ".neu"),
        "Speicher: Nebendatei wird nach dem Umbenennen nicht zurueckgelassen")

    var zurueck := Speicher.lies(pfad)
    _nahe(float(zurueck.get("plasma", 0.0)), 1234.5, "Speicher: Plasma kommen zurueck")
    _gleich(int(zurueck.get("quanten", 0)), 9, "Speicher: Quanten kommen zurueck")
    _gleich((zurueck.get("bestand", []) as Array).size(), 3, "Speicher: Bestand kommt zurueck")

    # Unverschluesselter Muell an derselben Stelle darf das Spiel nicht aufhalten.
    print("   (die folgenden Fehlermeldungen sind beabsichtigt: beschaedigte Datei)")
    var kaputt := FileAccess.open(pfad, FileAccess.WRITE)
    kaputt.store_string("das ist kein gueltiger Spielstand")
    kaputt.close()
    _ist(Speicher.lies(pfad).is_empty(), "Speicher: beschaedigte Datei ergibt leeres Dict")

    # Ein voller Spielstand muss den Weg ueber die Platte unveraendert ueberstehen.
    var a := _neuer_stand()
    a.plasma = 8.75e14
    a.quanten = 31
    a.protokolle = 6
    a.bestand[2] = 44
    a.verstaerker = true
    _ist(Speicher.schreibe(a.als_dict(), pfad), "Speicher: Spielstand schreiben gelingt")

    var b := _neuer_stand()
    b.aus_dict(Speicher.lies(pfad))
    _nahe(float(b.plasma), float(a.plasma), "Speicher: Plasma ueber Platte")
    _gleich(int(b.quanten), 31, "Speicher: Quanten ueber Platte")
    _gleich(int(b.protokolle), 6, "Speicher: Protokolle ueber Platte")
    _gleich(int(b.bestand[2]), 44, "Speicher: Bestand ueber Platte")
    _gleich(bool(b.verstaerker), true, "Speicher: Verstaerker ueber Platte")

    Speicher.loesche(pfad)
    _ist(not Speicher.existiert(pfad), "Speicher: loeschen raeumt auf")
    return true


func _test_formatter() -> bool:
    _gleich(Zahl.kurz(0.0), "0", "Formatter: 0")
    _gleich(Zahl.kurz(999.0), "999", "Formatter: 999")
    _gleich(Zahl.kurz(1000.0), "1.00 K", "Formatter: 1000")
    _gleich(Zahl.kurz(15400.0), "15.4 K", "Formatter: 15.4 K")
    _gleich(Zahl.kurz(1.0e6), "1.00 M", "Formatter: Million")
    _gleich(Zahl.kurz(1.0e9), "1.00 B", "Formatter: Milliarde")
    _gleich(Zahl.kurz(1.0e12), "1.00 T", "Formatter: Billion")
    _gleich(Zahl.kurz(1.0e15), "1.00 aa", "Formatter: Wechsel auf Buchstaben")
    _gleich(Zahl.kurz(1.0e18), "1.00 ab", "Formatter: ab")
    _gleich(Zahl.kurz(-2500.0), "-2.50 K", "Formatter: negativ")
    _ist(Zahl.kurz(1.0e100).length() > 0, "Formatter: 1e100 liefert etwas")
    _gleich(Zahl.kurz(NAN), "?", "Formatter: NaN")
    _gleich(Zahl.kurz(INF), "∞", "Formatter: Unendlich")

    _gleich(Zahl.zeit(45.0), "45s", "Zeit: Sekunden")
    _gleich(Zahl.zeit(725.0), "12m 05s", "Zeit: Minuten")
    _gleich(Zahl.zeit(11520.0), "3h 12m", "Zeit: Stunden")
    _gleich(Zahl.zeit(-5.0), "0s", "Zeit: negativ")
    return true


func _test_langzeit() -> bool:
    # 100 Spielstunden mit gieriger Kaufstrategie: teuerstes bezahlbares Modul.
    var st := _neuer_stand()
    var dt := 1.0
    var start_guthaben: float = st.plasma
    var schritte := int(100.0 * 3600.0 / dt)

    for schritt in schritte:
        st.gutschrift(st.rate() * dt)
        # Nur gelegentlich einkaufen - haelt den Test schnell.
        if schritt % 10 == 0:
            for i in range(Modul.ANZAHL - 1, -1, -1):
                if st.kaufe(i, 1):
                    break

    _ist(is_finite(st.plasma), "Langzeit: Plasma bleiben endlich")
    _ist(is_finite(st.lebenszeit_plasma), "Langzeit: Lebenszeit bleibt endlich")
    _ist(st.lebenszeit_plasma > start_guthaben, "Langzeit: es wurde etwas erwirtschaftet")

    var gekauft := 0
    for n in st.bestand:
        gekauft += n
    _ist(gekauft > 0, "Langzeit: Module wurden gekauft")
    _ist(Oekonomie.prestige_moeglich(st.lebenszeit_plasma),
        "Langzeit: nach 100 h ist Prestige erreichbar")

    print("   100 h Simulation: %s Plasma gesamt, %d Module, %d Protokolle moeglich"
        % [Zahl.kurz(st.lebenszeit_plasma), gekauft,
           Oekonomie.prestige_ertrag(st.lebenszeit_plasma)])
    return true


func _test_modul_ausbau() -> bool:
    _nahe(ModulAusbau.faktor(0), 1.0, "Stufe 0 aendert nichts")
    _nahe(ModulAusbau.faktor(1), 2.0, "Eine Stufe verdoppelt")
    _nahe(ModulAusbau.faktor(5), 32.0, "Fuenf Stufen verzweiunddreissigfachen")
    _nahe(ModulAusbau.faktor(-3), 1.0, "Negative Stufe wirkt nicht")

    _nahe(ModulAusbau.kosten(0, 0), Modul.basiskosten(0) * ModulAusbau.ERSTE_STUFE,
        "Erste Stufe kostet das Vielfache der Basiskosten")
    _ist(ModulAusbau.kosten(0, 1) > ModulAusbau.kosten(0, 0),
        "Jede weitere Stufe kostet mehr")
    _gleich(ModulAusbau.kosten(0, ModulAusbau.MAX_STUFE), 0.0,
        "Voll ausgebaut kostet nichts mehr")
    _ist(ModulAusbau.voll(ModulAusbau.MAX_STUFE), "Hoechststufe gilt als voll")
    _ist(not ModulAusbau.voll(ModulAusbau.MAX_STUFE - 1), "Eine darunter noch nicht")

    # Die Stufe muss in die Foerderung eingehen.
    _nahe(Oekonomie.modul_rate(1, 10, 1.0, 0), Oekonomie.modul_rate(1, 10, 1.0, 1) * 0.5,
        "Eine Stufe verdoppelt die Foerderung der Baugruppe")
    _nahe(Oekonomie.gesamt_rate([0, 10], 1.0, [0, 2]),
        Oekonomie.gesamt_rate([0, 10], 1.0, []) * 4.0,
        "Gesamtrate rechnet die Stufen mit")
    _nahe(Oekonomie.gesamt_rate([0, 10], 1.0), Oekonomie.gesamt_rate([0, 10], 1.0, []),
        "Ohne Stufenangabe bleibt es beim alten Ergebnis")

    # --- Im Spielstand ---
    var st := _neuer_stand()
    st.bestand[0] = 20
    _gleich(int(st.modul_stufe[0]), 0, "Neuer Stand hat Stufe 0")
    _ist(not st.kaufe_modul_ausbau(0), "Ohne Plasma kein Ausbau")

    var preis := ModulAusbau.kosten(0, 0)
    st.plasma = preis
    var vorher: float = st.rate()
    _ist(st.kaufe_modul_ausbau(0), "Mit genug Plasma ist der Ausbau kaufbar")
    _gleich(int(st.modul_stufe[0]), 1, "Stufe steigt auf 1")
    _nahe(float(st.plasma), 0.0, "Ausbau kostet Plasma")
    _nahe(st.rate(), vorher * 2.0, "Foerderung verdoppelt sich")

    _ist(not st.kaufe_modul_ausbau(-1), "Ungueltiger Index wird abgewiesen")
    _ist(not st.kaufe_modul_ausbau(Modul.ANZAHL), "Index ausserhalb wird abgewiesen")

    # Hoechststufe sperrt weitere Kaeufe.
    var voll := _neuer_stand()
    voll.modul_stufe[3] = ModulAusbau.MAX_STUFE
    voll.plasma = 1e300
    _ist(not voll.kaufe_modul_ausbau(3), "Voll ausgebaut nicht weiter kaufbar")
    _nahe(float(voll.plasma), 1e300, "Abgelehnter Ausbau kostet nichts")

    # Ein Reset muss die Stufen mitnehmen - sonst waere der zweite Durchlauf
    # trivial und Prestige verloere seinen Sinn.
    var r := _neuer_stand()
    r.modul_stufe[2] = 4
    r.bestand[2] = 30
    r.lebenszeit_plasma = 1e9
    r.prestige()
    _gleich(int(r.modul_stufe[2]), 0, "Prestige setzt die Ausbaustufen zurueck")

    # Speichern und Migration.
    var a := _neuer_stand()
    a.modul_stufe[1] = 3
    a.modul_stufe[6] = 1
    var b := _neuer_stand()
    b.aus_dict(a.als_dict())
    _gleich(int(b.modul_stufe[1]), 3, "Ausbaustufen werden gespeichert")
    _gleich(int(b.modul_stufe[6]), 1, "auch fuer spaetere Baugruppen")

    var alt := _neuer_stand()
    alt.aus_dict({"version": 2, "plasma": 100.0, "bestand": [5]})
    _gleich(int(alt.modul_stufe[0]), 0, "Migration v2 setzt Stufe 0")
    _gleich(int(alt.modul_stufe.size()), Modul.ANZAHL,
        "Stufenfeld hat immer volle Laenge")

    # Beschaedigte Werte duerfen nicht durchschlagen.
    var kaputt := _neuer_stand()
    kaputt.aus_dict({"version": 3, "modul_stufe": [99, -5]})
    _gleich(int(kaputt.modul_stufe[0]), ModulAusbau.MAX_STUFE,
        "Zu hohe Stufe wird gekappt")
    _gleich(int(kaputt.modul_stufe[1]), 0, "Negative Stufe wird auf 0 gehoben")
    return true


func _test_protokoll_ausbau() -> bool:
    # --- Tabelle ---
    for e in ProtokollAusbau.TABELLE:
        var id := String(e["id"])
        _ist(ProtokollAusbau.kosten(id, 0) > 0, "%s: erste Stufe kostet etwas" % id)
        _ist(ProtokollAusbau.kosten(id, 1) > ProtokollAusbau.kosten(id, 0),
            "%s: jede Stufe kostet mehr" % id)
        _gleich(ProtokollAusbau.kosten(id, ProtokollAusbau.max_stufe(id)), 0,
            "%s: voll ausgebaut kostet nichts" % id)
        _ist(ProtokollAusbau.voll(id, ProtokollAusbau.max_stufe(id)),
            "%s: Hoechststufe gilt als voll" % id)
    _gleich(ProtokollAusbau.kosten("gibtsnicht", 0), 0, "Unbekannte Kennung kostet 0")

    # --- Wirkungen ---
    _gleich(ProtokollAusbau.startkapital(0), 0.0, "Ohne Notreserve kein Zuschuss")
    _ist(ProtokollAusbau.startkapital(2) > ProtokollAusbau.startkapital(1),
        "Notreserve steigt je Stufe")
    _nahe(ProtokollAusbau.hand_faktor(0), 1.0, "Ohne Handfoerderung Faktor 1")
    _nahe(ProtokollAusbau.hand_faktor(2), 9.0, "Handfoerderung Stufe 2 gibt Faktor 9")
    _nahe(ProtokollAusbau.offline_anteil(0), Oekonomie.OFFLINE_ANTEIL,
        "Ohne Pufferzellen bleibt es beim Grundanteil")
    _ist(ProtokollAusbau.offline_anteil(4) <= 0.90, "Offline-Anteil ist gedeckelt")
    _nahe(ProtokollAusbau.ausbau_rabatt(0), 1.0, "Ohne Feinbau kein Rabatt")
    _ist(ProtokollAusbau.ausbau_rabatt(3) < 1.0, "Feinbau verbilligt")

    # --- Kauf ---
    var st := _neuer_stand()
    _gleich(st.stufe_von("hand"), 0, "Neuer Stand hat Stufe 0")
    _ist(not st.kaufe_protokoll_ausbau("hand"), "Ohne Protokolle kein Ausbau")

    st.protokolle = 100
    st.protokolle_gesamt = 100
    var preis := ProtokollAusbau.kosten("hand", 0)
    _ist(st.kaufe_protokoll_ausbau("hand"), "Mit Protokollen kaufbar")
    _gleich(st.stufe_von("hand"), 1, "Stufe steigt")
    _gleich(int(st.protokolle), 100 - preis, "Guthaben sinkt um den Preis")

    # Der entscheidende Punkt: Ausgeben darf den Multiplikator nicht senken.
    _gleich(int(st.protokolle_gesamt), 100, "Gesamtkonto bleibt beim Kauf unberuehrt")
    _nahe(st.global_mult(), Oekonomie.prestige_mult(100),
        "Multiplikator haengt am Gesamtkonto, nicht am Guthaben")

    _ist(not st.kaufe_protokoll_ausbau("gibtsnicht"), "Unbekannte Kennung wird abgewiesen")

    # Hoechststufe sperrt.
    var voll := _neuer_stand()
    voll.protokolle = 100000
    var id0 := String(ProtokollAusbau.TABELLE[0]["id"])
    for i in ProtokollAusbau.max_stufe(id0):
        _ist(voll.kaufe_protokoll_ausbau(id0), "%s Stufe %d kaufbar" % [id0, i + 1])
    _ist(not voll.kaufe_protokoll_ausbau(id0), "Voll ausgebaut nicht weiter kaufbar")

    # --- Wirkung im Spielstand ---
    var h := _neuer_stand()
    var ohne: float = h.manuell_sammeln()
    h.p_stufe["hand"] = 1
    var mit: float = h.manuell_sammeln()
    _nahe(mit, ohne * ProtokollAusbau.hand_faktor(1), "Handfoerderung wirkt beim Antippen")

    var f := _neuer_stand()
    f.bestand[0] = 10
    var voll_preis := ModulAusbau.kosten(0, 0, 1.0)
    f.p_stufe["feinbau"] = 3
    _ist(ModulAusbau.kosten(0, 0, f.ausbau_rabatt()) < voll_preis,
        "Feinbau verbilligt den Baugruppen-Ausbau im Spielstand")

    # --- Startzustand nach einem Reset ---
    var r := _neuer_stand()
    r.p_stufe["startkapital"] = 2
    r.p_stufe["anlauf"] = 2
    r.lebenszeit_plasma = 1e9
    r.bestand[0] = 40
    r.modul_stufe[0] = 3
    r.prestige()
    _ist(r.plasma > 15.0, "Notreserve wirkt nach dem Reset")
    _gleich(int(r.bestand[0]), ProtokollAusbau.anlauf_stueck(2),
        "Anlaufhilfe stellt Baugruppen bereit")
    _gleich(int(r.modul_stufe[0]), 0, "Baugruppen-Ausbaustufen gehen trotzdem verloren")

    # --- Speichern und Migration ---
    var a := _neuer_stand()
    a.protokolle = 42
    a.protokolle_gesamt = 77
    a.p_stufe["speicher"] = 2
    var b := _neuer_stand()
    b.aus_dict(a.als_dict())
    _gleich(int(b.protokolle), 42, "Guthaben wird gespeichert")
    _gleich(int(b.protokolle_gesamt), 77, "Gesamtkonto wird gespeichert")
    _gleich(b.stufe_von("speicher"), 2, "Ausbaustufen werden gespeichert")

    # Aeltere Staende kannten nur eine Zahl - dort ist Guthaben gleich Gesamt,
    # sonst verloere ein bestehender Spieler beim Update seinen Multiplikator.
    var alt := _neuer_stand()
    alt.aus_dict({"version": 3, "protokolle": 60})
    _gleich(int(alt.protokolle_gesamt), 60, "Migration v3 uebernimmt das Gesamtkonto")
    _nahe(alt.global_mult(), Oekonomie.prestige_mult(60),
        "Migration erhaelt den Multiplikator")

    var kaputt := _neuer_stand()
    kaputt.aus_dict({"version": 4, "p_stufe": {"hand": 999, "gibtsnicht": 3}})
    _gleich(kaputt.stufe_von("hand"), ProtokollAusbau.max_stufe("hand"),
        "Zu hohe Stufe wird gekappt")
    _gleich(kaputt.stufe_von("gibtsnicht"), 0, "Unbekannte Kennung bleibt wirkungslos")
    return true


func _test_errungenschaften() -> bool:
    # Erreichbare Belohnung muss den Verstaerker decken, sonst ist der ohne
    # Kauf oder Werbung unerreichbar - genau das soll er nicht sein.
    _ist(Errungenschaft.quanten_gesamt() >= Ausbau.VERSTAERKER_KOSTEN,
        "Errungenschaften decken den Preis des Verstaerkers")

    var voll: Array[int] = []
    voll.resize(Modul.ANZAHL)
    voll.fill(1)

    # "alle_arten" hatte einen Abbruch nach dem ersten Element und meldete
    # Erfolg, sobald eine einzige Art vorhanden war.
    var alle := _eintrag("alle_arten")
    _ist(Errungenschaft.erfuellt(alle, {"bestand": voll}),
        "alle_arten greift, wenn jede Art vorhanden ist")
    var fehlt := voll.duplicate()
    fehlt[Modul.ANZAHL - 1] = 0
    _ist(not Errungenschaft.erfuellt(alle, {"bestand": fehlt}),
        "alle_arten greift NICHT, wenn eine Art fehlt")
    var nur_erste := voll.duplicate()
    for i in range(1, Modul.ANZAHL):
        nur_erste[i] = 0
    _ist(not Errungenschaft.erfuellt(alle, {"bestand": nur_erste}),
        "alle_arten greift NICHT bei nur einer Art")

    _ist(Errungenschaft.erfuellt(_eintrag("zehn"), {"bestand": [4, 6]}),
        "bestand zaehlt ueber alle Arten zusammen")
    _ist(not Errungenschaft.erfuellt(_eintrag("zehn"), {"bestand": [4, 5]}),
        "bestand knapp darunter greift nicht")
    _ist(Errungenschaft.erfuellt(_eintrag("segel_zehn"), {"bestand": [10, 0]}),
        "modul prueft die richtige Art")
    _ist(not Errungenschaft.erfuellt(_eintrag("segel_zehn"), {"bestand": [0, 99]}),
        "modul zaehlt nicht die falsche Art")
    _ist(Errungenschaft.erfuellt(_eintrag("ertrag_m"), {"lebenszeit": 1.0e6}),
        "lebenszeit greift genau an der Schwelle")
    _ist(Errungenschaft.erfuellt(_eintrag("rate_k"), {"rate": 1500.0}), "rate greift")
    _ist(Errungenschaft.erfuellt(_eintrag("reset_eins"), {"prestige": 1}), "prestige greift")

    # --- Im Spielstand ---
    var st := _neuer_stand()
    _gleich(st.quanten, 0, "Neuer Stand hat keine Quanten")
    st.bestand[0] = 1
    var neu: PackedStringArray = st.pruefe_errungenschaften()
    _ist(neu.has("start"), "Erste Baugruppe schaltet frei")
    _gleich(int(st.quanten), 2, "Freischaltung schreibt Quanten gut")

    # Zweiter Durchlauf darf nicht noch einmal zahlen.
    var wieder: PackedStringArray = st.pruefe_errungenschaften()
    _ist(not wieder.has("start"), "Bereits Freigeschaltetes wird nicht wiederholt")
    _gleich(int(st.quanten), 2, "Keine doppelte Belohnung")

    # Zuruecksetzungen werden gezaehlt und schalten frei.
    var r := _neuer_stand()
    r.lebenszeit_plasma = 1e9
    _gleich(int(r.prestige_anzahl), 0, "Anfangs keine Zuruecksetzung")
    r.prestige()
    _gleich(int(r.prestige_anzahl), 1, "Zuruecksetzung wird gezaehlt")
    _ist(r.pruefe_errungenschaften().has("reset_eins"), "Erster Reset schaltet frei")

    # Fortschritt muss den Neustart ueberstehen.
    var b := _neuer_stand()
    b.aus_dict(st.als_dict())
    _ist(b.errungen.has("start"), "Errungenschaften werden gespeichert")
    _gleich(int(b.pruefe_errungenschaften().size()), 0,
        "Nach dem Laden wird nichts erneut ausgeschuettet")
    return true


## Sucht einen Tabelleneintrag anhand seiner Kennung.
func _eintrag(id: String) -> Dictionary:
    for e in Errungenschaft.TABELLE:
        if String(e["id"]) == id:
            return e
    _fehler.append("Errungenschaft %s fehlt in der Tabelle" % id)
    return {"art": "", "wert": 0.0}


func _test_layout() -> bool:
    # Ueberlappende Baugruppen wuerden Fehlkaeufe ausloesen: die
    # Treffererkennung nimmt die erste passende Flaeche und liefert dann die
    # falsche. Beim Verschieben des Layouts faellt das sonst niemandem auf.
    for a in Modul.ANZAHL:
        for b in range(a + 1, Modul.ANZAHL):
            _ist(not Raster.modul_flaeche(a).intersects(Raster.modul_flaeche(b)),
                "Layout: Baugruppe %d und %d ueberlappen nicht" % [a, b])

    # Der Kern liegt mittig und muss frei bleiben, sonst laesst er sich nicht
    # antippen.
    var kern := Rect2(-Vector2(Kern.RADIUS, Kern.RADIUS),
        Vector2(Kern.RADIUS, Kern.RADIUS) * 2.0)
    for i in Modul.ANZAHL:
        _ist(not Raster.modul_flaeche(i).intersects(kern),
            "Layout: Baugruppe %d ueberlappt den Kern nicht" % i)

    _gleich(Formen.kante(Rect2(0, 0, 100, 60), 10.0).size(), 8,
        "Abgeschraegtes Rechteck hat acht Ecken")
    _gleich(Formen.kante_umriss(Rect2(0, 0, 100, 60), 10.0).size(), 9,
        "Umriss schliesst sich")
    # Eine zu grosse Schraege darf die Form nicht umstuelpen.
    var entartet := Formen.kante(Rect2(0, 0, 40, 20), 999.0)
    _gleich(entartet.size(), 8, "Uebergrosse Schraege bleibt achteckig")
    return true


# --- Hilfen -----------------------------------------------------------------

## Erzeugt einen Spielstand ausserhalb des Szenenbaums.
##
## Bewusst nicht ueber das Autoload: ohne Baum laeuft kein _process, damit
## tickt nichts nebenher und die Tests bleiben deterministisch.
func _neuer_stand() -> Node:
    var st: Node = load("res://scripts/autoload/spielstand.gd").new()
    st._ready()
    _staende.append(st)
    return st
