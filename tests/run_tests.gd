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


func _init() -> void:
    print("── STERNWERFT Testlauf ────────────────────────")
    _test_kostenkurve()
    _test_massenkauf()
    _test_max_kaufbar()
    _test_meilensteine()
    _test_produktion()
    _test_kaltstart()
    _test_prestige()
    _test_offline()
    _test_speicherstand()
    _test_formatter()
    _test_langzeit()

    for st in _staende:
        st.free()
    _staende.clear()

    print("───────────────────────────────────────────────")
    if _fehler.is_empty():
        print("✓ %d Zusicherungen bestanden" % _bestanden)
        quit(0)
    else:
        for f in _fehler:
            printerr("✗ " + f)
        printerr("%d von %d fehlgeschlagen" % [_fehler.size(), _bestanden + _fehler.size()])
        quit(1)


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

func _test_kostenkurve() -> void:
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


func _test_massenkauf() -> void:
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


func _test_max_kaufbar() -> void:
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


func _test_meilensteine() -> void:
    _nahe(Oekonomie.meilenstein_mult(0), 1.0, "Ohne Module kein Meilenstein")
    _nahe(Oekonomie.meilenstein_mult(9), 1.0, "Bei 9 noch kein Meilenstein")
    _nahe(Oekonomie.meilenstein_mult(10), 2.0, "Meilenstein greift exakt bei 10")
    _nahe(Oekonomie.meilenstein_mult(24), 2.0, "Bei 24 weiterhin x2")
    _nahe(Oekonomie.meilenstein_mult(25), 4.0, "Zweiter Meilenstein bei 25")
    _nahe(Oekonomie.meilenstein_mult(50), 8.0, "Dritter bei 50")
    _nahe(Oekonomie.meilenstein_mult(100), 16.0, "Vierter bei 100")
    _nahe(Oekonomie.meilenstein_mult(200), 32.0, "Fuenfter bei 200")
    _nahe(Oekonomie.meilenstein_mult(5000), 32.0, "Danach keine weiteren")


func _test_produktion() -> void:
    _nahe(Oekonomie.modul_rate(0, 0), 0.0, "Kein Modul, keine Produktion")
    _nahe(Oekonomie.modul_rate(0, 1), 0.1, "Ein Solarsegel liefert 0.1/s")
    _nahe(Oekonomie.modul_rate(0, 5), 0.5, "Fuenf Solarsegel liefern 0.5/s")
    # 10 Stueck: 0.1 * 10 * Meilenstein x2 = 2.0
    _nahe(Oekonomie.modul_rate(0, 10), 2.0, "Meilenstein verdoppelt die Produktion")
    _nahe(Oekonomie.modul_rate(1, 3, 2.0), 6.0, "Globaler Multiplikator wirkt")

    var bestand := [10, 3, 0, 0, 0, 0, 0, 0]
    _nahe(Oekonomie.gesamt_rate(bestand), 2.0 + 3.0, "Gesamtrate summiert alle Module")
    _nahe(Oekonomie.gesamt_rate([]), 0.0, "Leerer Bestand liefert 0")


func _test_prestige() -> void:
    _gleich(Oekonomie.prestige_ertrag(0.0), 0, "Ohne Ertrag keine Protokolle")
    _gleich(Oekonomie.prestige_ertrag(-5.0), 0, "Negativer Ertrag ergibt 0")
    # Das erste Protokoll faellt bei Skala / Faktor^2 = 1e12/225 ~ 4.44e9.
    _gleich(Oekonomie.prestige_ertrag(4.4e9), 0, "Knapp vor dem ersten Protokoll noch 0")
    _gleich(Oekonomie.prestige_ertrag(4.5e9), 1, "Erstes Protokoll bei ~4.44e9")
    _gleich(Oekonomie.prestige_ertrag(1e12), 15, "Bei der Bezugsgroesse 15 Protokolle")
    _gleich(Oekonomie.prestige_ertrag(4e12), 30, "Vierfacher Ertrag verdoppelt (Wurzel)")
    _ist(not Oekonomie.prestige_moeglich(1e9), "Prestige ganz frueh noch gesperrt")
    _ist(Oekonomie.prestige_moeglich(1e12), "Prestige spaeter moeglich")

    _nahe(Oekonomie.prestige_mult(0), 1.0, "Ohne Protokolle Multiplikator 1")
    _nahe(Oekonomie.prestige_mult(50), 2.0, "50 Protokolle verdoppeln")
    _nahe(Oekonomie.prestige_mult(-3), 1.0, "Negative Protokolle wirken nicht")


func _test_kaltstart() -> void:
    var st := _neuer_stand()
    _nahe(float(st.credits), 15.0, "Neuer Stand hat Startguthaben")
    _ist(st.kaufe(0, 1), "Startguthaben deckt exakt das erste Solarsegel")
    _nahe(float(st.credits), 0.0, "Danach ist das Guthaben aufgebraucht")
    _ist(st.rate() > 0.0, "Nach dem ersten Kauf laeuft die Produktion")

    # Ohne manuelles Sammeln kaeme ein Stand ohne Module nie in Gang.
    var leer := _neuer_stand()
    leer.credits = 0.0
    _nahe(leer.rate(), 0.0, "Ohne Module ist die Rate 0")
    var ertrag: float = leer.manuell_sammeln()
    _ist(ertrag >= 1.0, "Antippen liefert auch ohne Module mindestens 1")
    _ist(leer.credits > 0.0, "Antippen bringt den Kaltstart in Gang")


func _test_offline() -> void:
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


func _test_speicherstand() -> void:
    var a := _neuer_stand()
    a.credits = 12345.678
    a.kerne = 42
    a.protokolle = 7
    a.lebenszeit_credits = 9.87e15
    a.verstaerker = true
    a.bestand[0] = 13
    a.bestand[5] = 2

    var b := _neuer_stand()
    b.aus_dict(a.als_dict())

    _nahe(b.credits, a.credits, "Speicherstand: Credits")
    _gleich(b.kerne, a.kerne, "Speicherstand: Kerne")
    _gleich(b.protokolle, a.protokolle, "Speicherstand: Protokolle")
    _nahe(b.lebenszeit_credits, a.lebenszeit_credits, "Speicherstand: Lebenszeit")
    _gleich(b.verstaerker, true, "Speicherstand: Verstaerker")
    _gleich(b.bestand[0], 13, "Speicherstand: Bestand 0")
    _gleich(b.bestand[5], 2, "Speicherstand: Bestand 5")

    # Beschaedigter Stand darf nicht blockieren.
    var c := _neuer_stand()
    c.aus_dict({})
    _nahe(float(c.credits), 15.0, "Leeres Dict faellt auf Startguthaben, nicht auf 0")
    _gleich(c.bestand.size(), Modul.ANZAHL, "Bestand hat immer volle Laenge")

    # Migration von Version 0.
    var d := _neuer_stand()
    d.aus_dict({"credits": 500.0, "bestand": [1, 2]})
    _nahe(d.offline_cap, Oekonomie.OFFLINE_CAP_BASIS, "Migration v0 setzt Offline-Cap")
    _gleich(d.bestand[1], 2, "Migration uebernimmt Teilbestand")
    _gleich(d.bestand[7], 0, "Fehlende Bestandsplaetze werden 0")


func _test_formatter() -> void:
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


func _test_langzeit() -> void:
    # 100 Spielstunden mit gieriger Kaufstrategie: teuerstes bezahlbares Modul.
    var st := _neuer_stand()
    var dt := 1.0
    var start_guthaben: float = st.credits
    var schritte := int(100.0 * 3600.0 / dt)

    for schritt in schritte:
        st.gutschrift(st.rate() * dt)
        # Nur gelegentlich einkaufen - haelt den Test schnell.
        if schritt % 10 == 0:
            for i in range(Modul.ANZAHL - 1, -1, -1):
                if st.kaufe(i, 1):
                    break

    _ist(is_finite(st.credits), "Langzeit: Credits bleiben endlich")
    _ist(is_finite(st.lebenszeit_credits), "Langzeit: Lebenszeit bleibt endlich")
    _ist(st.lebenszeit_credits > start_guthaben, "Langzeit: es wurde etwas erwirtschaftet")

    var gekauft := 0
    for n in st.bestand:
        gekauft += n
    _ist(gekauft > 0, "Langzeit: Module wurden gekauft")
    _ist(Oekonomie.prestige_moeglich(st.lebenszeit_credits),
        "Langzeit: nach 100 h ist Prestige erreichbar")

    print("   100 h Simulation: %s Credits gesamt, %d Module, %d Protokolle moeglich"
        % [Zahl.kurz(st.lebenszeit_credits), gekauft,
           Oekonomie.prestige_ertrag(st.lebenszeit_credits)])


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
