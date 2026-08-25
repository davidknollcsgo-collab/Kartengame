## Headless-Testlauf: godot --headless --path . --script tests/run_tests.gd
##
## Ohne Test-Framework als Abhaengigkeit. Beendet mit Code 1, sobald etwas
## fehlschlaegt, damit die CI den Lauf als rot erkennt.
extends SceneTree

## Alle Testfunktionen. Wer eine hinzufuegt und hier vergisst, wird von
## _pruefe_vollstaendigkeit erwischt.
const TESTS: PackedStringArray = [
    "_test_strahl_segment",
    "_test_freier_flug",
    "_test_gerader_abprall",
    "_test_schraeger_abprall",
    "_test_kasten",
    "_test_abprallgrenze",
    "_test_kein_kleben",
    "_test_ecke_ohne_haenger",
    "_test_normale",
    "_test_als_waende",
    "_test_vorschau_gleich_flug",
    "_test_kammerdaten",
    "_test_kammer_treffer",
    "_test_kammer_spuren",
    "_test_loesbarkeit",
    "_test_klang",
    "_test_myzel",
    "_test_speicher",
    "_test_fortschritt",
]

var _bestanden := 0
var _fehler: Array[String] = []


func _init() -> void:
    print("── HYPHA Testlauf ─────────────────────────────")
    _pruefe_vollstaendigkeit()
    for name in TESTS:
        if not has_method(name):
            _fehler.append("%s fehlt" % name)
            continue
        # GDScript beendet bei einem Laufzeitfehler nur die betroffene Funktion.
        # Ohne diesen Rueckgabewert meldet ein abgestuerzter Test gruen.
        if call(name) != true:
            _fehler.append("%s wurde abgebrochen (Laufzeitfehler weiter oben)" % name)

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
## Ein Test, der nie aufgerufen wird, kann auch nicht abbrechen - die
## Abbrucherkennung findet ihn also nicht. Nur der Abgleich gegen die
## tatsaechlich vorhandenen Methoden faellt das auf.
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


func _nahe(a: float, b: float, name: String, toleranz := 0.001) -> void:
    _ist(absf(a - b) <= toleranz, "%s (war %f, erwartet %f)" % [name, a, b])


func _punkt_nahe(a: Vector2, b: Vector2, name: String, toleranz := 0.5) -> void:
    _ist(a.distance_to(b) <= toleranz,
        "%s (war %s, erwartet %s)" % [name, str(a), str(b)])


# --- Tests ------------------------------------------------------------------

func _test_strahl_segment() -> bool:
    var a := Vector2(-10.0, 10.0)
    var b := Vector2(10.0, 10.0)

    _nahe(Ballistik._strahl_segment(Vector2.ZERO, Vector2.DOWN, a, b), 10.0,
        "Senkrecht auf die Wand: Entfernung 10")
    _nahe(Ballistik._strahl_segment(Vector2(0.0, 5.0), Vector2.DOWN, a, b), 5.0,
        "Naeher dran: Entfernung 5")

    _gleich(Ballistik._strahl_segment(Vector2.ZERO, Vector2.UP, a, b), -1.0,
        "Wand hinter dem Strahl zaehlt nicht")
    _gleich(Ballistik._strahl_segment(Vector2.ZERO, Vector2.RIGHT, a, b), -1.0,
        "Parallel zur Wand ergibt keinen Schnitt")
    _gleich(Ballistik._strahl_segment(Vector2(50.0, 0.0), Vector2.DOWN, a, b), -1.0,
        "Neben dem Segment vorbei ergibt keinen Schnitt")

    # Genau auf den Endpunkt: muss noch treffen, sonst entstehen Luecken an
    # jeder Ecke der Kammer.
    _nahe(Ballistik._strahl_segment(Vector2(10.0, 0.0), Vector2.DOWN, a, b), 10.0,
        "Treffer genau am Segmentende zaehlt")
    return true


func _test_freier_flug() -> bool:
    var e := Ballistik.flug(Vector2.ZERO, Vector2.RIGHT, PackedVector2Array(), 3, 500.0)
    _gleich(e.punkte.size(), 2, "Ohne Waende gibt es nur Start und Ende")
    _punkt_nahe(e.punkte[0], Vector2.ZERO, "Start bleibt der Start")
    _punkt_nahe(e.punkte[1], Vector2(500.0, 0.0), "Ende liegt am Ende der Reststrecke")
    _gleich(e.waende.size(), 0, "Ohne Waende keine Treffer")
    _ist(not e.abpraller_erschoepft, "Ohne Treffer sind die Abpraller nicht erschoepft")
    return true


func _test_gerader_abprall() -> bool:
    # Waagerechte Wand bei y = 100, Schuss senkrecht darauf.
    var waende := PackedVector2Array([Vector2(-100.0, 100.0), Vector2(100.0, 100.0)])
    var e := Ballistik.flug(Vector2.ZERO, Vector2.DOWN, waende, 1, 300.0)

    _gleich(e.punkte.size(), 3, "Start, Auftreffpunkt, Ende")
    _punkt_nahe(e.punkte[1], Vector2(0.0, 100.0), "Auftreffpunkt liegt auf der Wand")
    # Senkrecht auftreffen heisst senkrecht zurueck.
    _ist(e.punkte[2].y < e.punkte[1].y, "Nach dem Abprall geht es zurueck nach oben")
    _nahe(e.punkte[2].x, 0.0, "Senkrechter Abprall bleibt in der Spur", 0.5)
    _gleich(e.waende[0], 0, "Die getroffene Wand wird gemeldet")
    return true


func _test_schraeger_abprall() -> bool:
    # 45 Grad auf eine waagerechte Wand: die x-Richtung bleibt, y kehrt sich um.
    var waende := PackedVector2Array([Vector2(-500.0, 100.0), Vector2(500.0, 100.0)])
    var e := Ballistik.flug(Vector2.ZERO, Vector2(1.0, 1.0), waende, 1, 400.0)

    _punkt_nahe(e.punkte[1], Vector2(100.0, 100.0), "Auftreffpunkt bei 45 Grad")
    var nach := (e.punkte[2] - e.punkte[1]).normalized()
    _nahe(nach.x, 0.7071, "Waagerechte Richtung bleibt erhalten", 0.01)
    _nahe(nach.y, -0.7071, "Senkrechte Richtung kehrt sich um", 0.01)
    return true


func _test_kasten() -> bool:
    var kasten := Ballistik.rechteck(Rect2(-200.0, -200.0, 400.0, 400.0))
    _gleich(kasten.size(), 8, "Ein Rechteck ergibt vier Segmente")

    # Reichlich Abpraller, damit hier wirklich die Strecke der begrenzende
    # Faktor ist und nicht die Abprallzahl.
    var e := Ballistik.flug(Vector2.ZERO, Vector2(1.0, 0.6), kasten, 60, 3000.0)
    _ist(e.punkte.size() >= 3, "Im Kasten wird mehrfach abgeprallt")

    # Alle Punkte muessen innerhalb des Kastens bleiben. Ein Punkt ausserhalb
    # heisst, dass die Spore durch eine Wand gerutscht ist.
    var drin := true
    for p in e.punkte:
        if absf(p.x) > 201.0 or absf(p.y) > 201.0:
            drin = false
    _ist(drin, "Die Spore bleibt im Kasten")

    # Die Gesamtstrecke darf die Vorgabe nicht ueberschreiten.
    var laenge := 0.0
    for i in range(e.punkte.size() - 1):
        laenge += e.punkte[i].distance_to(e.punkte[i + 1])
    _ist(laenge <= 3000.0 + 5.0, "Die Flugstrecke ueberschreitet die Vorgabe nicht")
    _ist(laenge > 2900.0, "Die Flugstrecke wird auch ausgeschoepft")
    return true


func _test_abprallgrenze() -> bool:
    var kasten := Ballistik.rechteck(Rect2(-100.0, -100.0, 200.0, 200.0))

    for grenze in [0, 1, 3, 5]:
        var e := Ballistik.flug(Vector2.ZERO, Vector2(0.8, 1.0), kasten,
            grenze, 100000.0)
        _ist(e.waende.size() <= grenze + 1,
            "Bei Grenze %d gibt es hoechstens %d Treffer" % [grenze, grenze + 1])

    # Mit reichlich Strecke muss die Grenze auch wirklich erreicht werden.
    var voll := Ballistik.flug(Vector2.ZERO, Vector2(0.8, 1.0), kasten, 4, 100000.0)
    _ist(voll.abpraller_erschoepft, "Bei viel Strecke sind die Abpraller erschoepft")
    return true


func _test_kein_kleben() -> bool:
    # Der klassische Fehler: nach dem Abprall liegt der Startpunkt rechnerisch
    # auf der Wand, und der naechste Schritt trifft sie sofort wieder. Die
    # Spore bleibt dann in der Wand haengen und der Flug endet nach null Weg.
    var waende := PackedVector2Array([Vector2(-500.0, 100.0), Vector2(500.0, 100.0)])
    var e := Ballistik.flug(Vector2(0.0, 90.0), Vector2(0.05, 1.0).normalized(),
        waende, 5, 2000.0)

    _gleich(e.waende.size(), 1, "Eine einzelne Wand wird genau einmal getroffen")
    var nach_laenge := e.punkte[1].distance_to(e.punkte[2])
    _ist(nach_laenge > 100.0, "Nach dem Abprall wird echte Strecke zurueckgelegt")

    # Sehr flacher Winkel - hier versagt ein reiner Abstandstrick.
    var flach := Ballistik.flug(Vector2(-400.0, 99.0), Vector2(1.0, 0.02).normalized(),
        waende, 5, 2000.0)
    var doppelt := false
    for i in range(flach.waende.size() - 1):
        if flach.waende[i] == flach.waende[i + 1]:
            doppelt = true
    _ist(not doppelt, "Auch bei flachem Winkel wird keine Wand zweimal nacheinander getroffen")
    return true


func _test_ecke_ohne_haenger() -> bool:
    # Zwei Waende, die sich in einer Ecke beruehren. Ohne Mindeststrecke kann
    # die Spore dazwischen hin und her springen, ohne voranzukommen - der Flug
    # laeuft dann in eine Endlosschleife.
    var waende := PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(200.0, 0.0),
        Vector2(0.0, 0.0), Vector2(0.0, 200.0),
    ])
    var e := Ballistik.flug(Vector2(60.0, 60.0), Vector2(-1.0, -1.0), waende, 8, 4000.0)
    _ist(e.punkte.size() <= 12, "Der Flug endet in der Ecke, statt zu haengen")
    _ist(e.punkte.size() >= 2, "Es entsteht trotzdem ein Streckenzug")
    return true


func _test_normale() -> bool:
    var waende := PackedVector2Array([Vector2(-10.0, 0.0), Vector2(10.0, 0.0)])

    # Von oben kommend muss die Normale nach oben zeigen.
    var n1 := Ballistik._normale(waende, 0, Vector2.DOWN)
    _nahe(n1.y, -1.0, "Von oben: Normale zeigt nach oben")
    # Von unten kommend nach unten - sonst prallt die Spore in die Wand hinein.
    var n2 := Ballistik._normale(waende, 0, Vector2.UP)
    _nahe(n2.y, 1.0, "Von unten: Normale zeigt nach unten")
    return true


func _test_als_waende() -> bool:
    var bahn := PackedVector2Array([
        Vector2.ZERO, Vector2(100.0, 0.0), Vector2(100.0, 100.0)])
    var w := Ballistik.als_waende(bahn)
    _gleich(w.size(), 4, "Drei Punkte ergeben zwei Wandsegmente")
    _punkt_nahe(w[0], Vector2.ZERO, "Erstes Segment beginnt am Anfang")
    _punkt_nahe(w[3], Vector2(100.0, 100.0), "Letztes Segment endet am Ende")

    # Entartete Abschnitte muessen wegfallen; sie haetten keine brauchbare Normale.
    var kurz := Ballistik.als_waende(PackedVector2Array([
        Vector2.ZERO, Vector2(0.1, 0.0), Vector2(100.0, 0.0)]))
    _gleich(kurz.size(), 2, "Ein zu kurzer Abschnitt wird uebersprungen")

    _gleich(Ballistik.als_waende(PackedVector2Array([Vector2.ZERO])).size(), 0,
        "Ein einzelner Punkt ergibt keine Wand")
    _gleich(Ballistik.als_waende(PackedVector2Array()).size(), 0,
        "Ohne Punkte keine Waende")
    return true


func _test_vorschau_gleich_flug() -> bool:
    # Die zentrale Zusicherung des Spiels: was die Zielhilfe zeigt, ist genau
    # das, was passiert. Beide rufen dieselbe Funktion - dieser Test haelt fest,
    # dass das so bleibt, falls jemand spaeter eine zweite Rechnung einbaut.
    var kasten := Ballistik.rechteck(Rect2(-180.0, -300.0, 360.0, 600.0))
    var start := Vector2(0.0, 280.0)
    var richtung := Vector2(0.42, -1.0).normalized()

    var vorschau := Ballistik.flug(start, richtung, kasten, 2, 4000.0)
    var echt := Ballistik.flug(start, richtung, kasten, 8, 4000.0)

    _ist(vorschau.punkte.size() >= 2, "Die Vorschau liefert einen Streckenzug")
    # Der gezeigte Anfang muss Punkt fuer Punkt zum echten Flug passen.
    for i in vorschau.punkte.size() - 1:
        _punkt_nahe(vorschau.punkte[i], echt.punkte[i],
            "Vorschaupunkt %d deckt sich mit dem Flug" % i, 0.01)
    return true


func _test_kammerdaten() -> bool:
    # Derselbe Aufbau fuer jeden Spieler: darauf beruht, dass man ueber eine
    # Kammer sprechen und sie nachrechnen kann.
    var a := KammerDaten.baue(7)
    var b := KammerDaten.baue(7)
    _gleich(a.knoten.size(), b.knoten.size(), "Gleiche Nummer, gleiche Knotenzahl")
    for i in a.knoten.size():
        _punkt_nahe(a.knoten[i], b.knoten[i], "Knoten %d liegt gleich" % i, 0.001)

    _ist(KammerDaten.baue(1).knoten.size() < KammerDaten.baue(28).knoten.size(),
        "Spaetere Kammern haben mehr Knoten")

    for nummer in [1, 5, 12, 30]:
        var plan := KammerDaten.baue(nummer)
        _ist(plan.knoten.size() >= 3, "Kammer %d hat Knoten" % nummer)
        _ist(plan.sporen >= 4, "Kammer %d hat genug Sporen" % nummer)
        _ist(plan.abpraller >= 3, "Kammer %d erlaubt Abpraller" % nummer)

        # Kein Knoten darf ausserhalb des Feldes oder im unteren Drittel liegen.
        var drin := true
        var oben := true
        for k in plan.knoten:
            if not KammerDaten.FELD.has_point(k):
                drin = false
            if k.y > KammerDaten.FELD.position.y + KammerDaten.FELD.size.y * 0.6:
                oben = false
        _ist(drin, "Kammer %d: alle Knoten liegen im Feld" % nummer)
        _ist(oben, "Kammer %d: kein Knoten direkt vor dem Werfer" % nummer)

        # Knoten duerfen sich nicht ueberlappen.
        var frei := true
        for i in plan.knoten.size():
            for j in range(i + 1, plan.knoten.size()):
                if plan.knoten[i].distance_to(plan.knoten[j]) < KammerDaten.KNOTEN_ABSTAND - 0.5:
                    frei = false
        _ist(frei, "Kammer %d: Knoten ueberlappen nicht" % nummer)

    _ist(KammerDaten.ertrag(10, 3) > KammerDaten.ertrag(10, 0),
        "Uebrige Sporen erhoehen den Ertrag")
    _ist(KammerDaten.ertrag(20, 0) > KammerDaten.ertrag(5, 0),
        "Spaetere Kammern werfen mehr ab")
    return true


func _test_kammer_treffer() -> bool:
    var k: Node = load("res://scripts/spiel/kammer.gd").new()
    var plan := KammerDaten.baue(4)
    k.setze(plan)
    var vorher: int = k.knoten_uebrig()
    _ist(vorher > 0, "Die Kammer hat Knoten")

    var ziel: Vector2 = plan.knoten[0]

    # Weit daneben darf nichts ausloesen.
    _ist(not k.pruefe_treffer(ziel + Vector2(400.0, 400.0), 7.0),
        "Weit daneben trifft nicht")
    _gleich(k.knoten_uebrig(), vorher, "Danebenschuss entfernt keinen Knoten")

    # Genau am Rand der Reichweite muss noch treffen.
    var rand := ziel + Vector2(KammerDaten.KNOTEN_R + 7.0 - 0.5, 0.0)
    _ist(k.pruefe_treffer(rand, 7.0), "Am Rand der Reichweite wird getroffen")
    _gleich(k.knoten_uebrig(), vorher - 1, "Der Knoten verschwindet")

    # Derselbe Ort darf nicht doppelt zaehlen.
    _ist(not k.pruefe_treffer(rand, 7.0), "Ein zerstoerter Knoten trifft nicht erneut")
    _gleich(k.knoten_uebrig(), vorher - 1, "Die Zahl bleibt stehen")

    # Knapp ausserhalb der Reichweite darf nicht treffen.
    var knapp: Vector2 = k.bauplan.knoten[1] if k.knoten_uebrig() > 1 else Vector2.ZERO
    if k.knoten_uebrig() > 1:
        _ist(not k.pruefe_treffer(knapp + Vector2(KammerDaten.KNOTEN_R + 7.0 + 3.0, 0.0), 7.0),
            "Knapp ausserhalb trifft nicht")

    # Alles abraeumen muss das Signal ausloesen.
    var geraeumt := [false]
    k.geraeumt.connect(func(): geraeumt[0] = true)
    for p in PackedVector2Array(plan.knoten):
        k.pruefe_treffer(p, 7.0)
    _gleich(k.knoten_uebrig(), 0, "Am Ende ist die Kammer leer")
    _ist(geraeumt[0], "Das Raeumsignal wird gemeldet")

    k.free()
    return true


func _test_kammer_spuren() -> bool:
    var k: Node = load("res://scripts/spiel/kammer.gd").new()
    k.setze(KammerDaten.baue(2))
    var fest: int = k.alle_waende().size()

    var bahn := PackedVector2Array([
        Vector2(0.0, 300.0), Vector2(100.0, 0.0), Vector2(-100.0, -200.0)])
    k.lege_spur(bahn)
    _gleich(k.alle_waende().size(), fest + 4,
        "Eine Spur aus drei Punkten ergibt zwei zusaetzliche Waende")

    # Nach SPUR_LEBEN weiteren Schuessen muss die Spur verschwunden sein -
    # sonst baut sich der Spieler die Kammer zu, bis nichts mehr geht.
    for i in k.SPUR_LEBEN:
        k.lege_spur(PackedVector2Array([Vector2(0.0, 300.0), Vector2(10.0, 0.0)]))
    var offen: int = k.alle_waende().size()
    k.lege_spur(PackedVector2Array([Vector2(0.0, 300.0), Vector2(20.0, 0.0)]))
    _ist(k.alle_waende().size() <= offen,
        "Alte Spuren verfallen, statt sich unbegrenzt zu haeufen")

    # Eine entartete Spur darf keine Wand erzeugen. Auf einer frischen Kammer
    # gepruefet, weil lege_spur zugleich die vorhandenen Spuren altern laesst -
    # sonst misst der Test zwei Wirkungen auf einmal.
    var frisch: Node = load("res://scripts/spiel/kammer.gd").new()
    frisch.setze(KammerDaten.baue(2))
    var leer: int = frisch.alle_waende().size()
    frisch.lege_spur(PackedVector2Array([Vector2.ZERO]))
    _gleich(frisch.alle_waende().size(), leer, "Ein einzelner Punkt ergibt keine Wand")
    frisch.lege_spur(PackedVector2Array())
    _gleich(frisch.alle_waende().size(), leer, "Eine leere Spur ergibt keine Wand")
    frisch.free()

    k.free()
    return true


func _test_loesbarkeit() -> bool:
    # Stichprobe statt aller dreissig: der Sucher braucht je Kammer spuerbar
    # Zeit, und der schnelle Testlauf soll schnell bleiben. Die vollstaendige
    # Pruefung macht tools/loesbarkeit.gd.
    #
    # Kammer 17 und 27 stehen bewusst in der Liste: sie waren im ersten Anlauf
    # unloesbar, weil Suche und Pruefer verschiedene Winkelaufloesungen
    # benutzten.
    for nummer in [1, 8, 17, 27, 30]:
        var e := Sucher.spiele(nummer)
        _ist(e["geschafft"], "Kammer %d ist loesbar" % nummer)
        _ist(int(e["uebrig"]) >= 1,
            "Kammer %d laesst mindestens eine Spore uebrig" % nummer)

    # Die erste Kammer muss deutlich Luft lassen - sie ist der erste Eindruck.
    var erste := Sucher.spiele(1)
    _ist(int(erste["uebrig"]) >= 3,
        "Kammer 1 ist gutmuetig (mindestens drei Sporen uebrig)")

    # Spaetere Kammern duerfen nicht leichter sein als fruehe.
    var spaet := Sucher.spiele(30)
    _ist(int(spaet["schuesse"]) >= int(erste["schuesse"]),
        "Kammer 30 verlangt nicht weniger Schuesse als Kammer 1")
    return true


func _test_klang() -> bool:
    # Toene kann der Testlauf nicht hoeren - aber nachrechnen, dass ein
    # brauchbarer Puffer entsteht. Ein stiller oder leerer Ton faellt sonst erst
    # auf dem Geraet auf, wo ihn niemand einer Ursache zuordnet.
    var k: Node = load("res://scripts/spiel/klang.gd").new()

    for art in [k.Art.WURF, k.Art.PRALL, k.Art.TREFFER, k.Art.GERAEUMT, k.Art.LEER]:
        var s: AudioStreamWAV = k._erzeuge(art)
        _ist(s != null, "Ton %d entsteht" % art)
        _gleich(s.format, AudioStreamWAV.FORMAT_16_BITS, "Ton %d ist 16 Bit" % art)
        _gleich(s.mix_rate, k.ABTASTRATE, "Ton %d hat die richtige Abtastrate" % art)
        _ist(s.data.size() > 400, "Ton %d hat einen Puffer" % art)
        _gleich(s.data.size() % 2, 0, "Ton %d hat vollstaendige Abtastwerte" % art)

        var spitze := 0
        for i in range(0, mini(s.data.size(), 8000), 2):
            spitze = maxi(spitze, absi(s.data.decode_s16(i)))
        _ist(spitze > 1000, "Ton %d ist hoerbar laut" % art)
        _ist(spitze <= 32767, "Ton %d uebersteuert nicht" % art)

    var prall: AudioStreamWAV = k._erzeuge(k.Art.PRALL)
    _ist(absi(prall.data.decode_s16(0)) < 2000, "Ton setzt weich ein statt zu knacken")

    # Zwoelf Halbtoene sind genau eine Oktave - darauf beruht die Tonkette.
    _nahe(pow(k.HALBTON, 12.0), 2.0, "Zwoelf Halbtoene ergeben eine Oktave", 0.01)

    # Abgeschaltet darf nichts passieren.
    k.an = false
    k.spiele(k.Art.PRALL, 5)
    _ist(true, "Abgeschalteter Ton wirft keinen Fehler")

    k.free()
    return true


func _test_myzel() -> bool:
    for e in Myzel.TABELLE:
        var id := String(e["id"])
        _ist(Myzel.kosten(id, 0) > 0.0, "%s: erste Stufe kostet etwas" % id)
        _ist(Myzel.kosten(id, 1) > Myzel.kosten(id, 0),
            "%s: jede Stufe kostet mehr" % id)
        _gleich(Myzel.kosten(id, Myzel.max_stufe(id)), 0.0,
            "%s: voll ausgebaut kostet nichts" % id)
        _ist(Myzel.voll(id, Myzel.max_stufe(id)), "%s: Hoechststufe gilt als voll" % id)
        _ist(not Myzel.voll(id, Myzel.max_stufe(id) - 1), "%s: eine darunter nicht" % id)

    _gleich(Myzel.kosten("gibtsnicht", 0), 0.0, "Unbekannte Kennung kostet nichts")
    _gleich(Myzel.max_stufe("gibtsnicht"), 0, "Unbekannte Kennung hat keine Stufen")

    # Die wichtigste Zusicherung des Baums: **kein Knoten verschlechtert etwas.**
    # Die Loesbarkeit aller dreissig Kammern wurde mit den Grundwerten geprueft.
    # Ein Knoten, der etwas erschwert, koennte eine geprueft loesbare Kammer
    # unloesbar machen - und niemand wuerde es merken, bis jemand feststeckt.
    for stufe in range(0, 6):
        _ist(Myzel.vorschau_abpraller(stufe + 1) >= Myzel.vorschau_abpraller(stufe),
            "Weitsicht wird nie schlechter (Stufe %d)" % stufe)
        _ist(Myzel.mehr_abpraller(stufe + 1) >= Myzel.mehr_abpraller(stufe),
            "Nachdruck wird nie schlechter (Stufe %d)" % stufe)
        _ist(Myzel.spore_radius(stufe + 1) >= Myzel.spore_radius(stufe),
            "Streuflug wird nie schlechter (Stufe %d)" % stufe)
        _ist(Myzel.mehr_sporen(stufe + 1) >= Myzel.mehr_sporen(stufe),
            "Sporenlager wird nie schlechter (Stufe %d)" % stufe)
        _ist(Myzel.ertrag_faktor(stufe + 1) >= Myzel.ertrag_faktor(stufe),
            "Zersetzung wird nie schlechter (Stufe %d)" % stufe)

    # Stufe 0 muss genau den Grundwerten entsprechen, mit denen geprueft wurde.
    _gleich(Myzel.vorschau_abpraller(0), Werfer.VORSCHAU_ABPRALLER,
        "Ohne Ausbau zeigt die Zielhilfe den Grundwert")
    _gleich(Myzel.mehr_abpraller(0), 0, "Ohne Ausbau keine zusaetzlichen Abpraller")
    _nahe(Myzel.spore_radius(0), Spore.RADIUS, "Ohne Ausbau der Grundradius")
    _gleich(Myzel.mehr_sporen(0), 0, "Ohne Ausbau keine zusaetzlichen Sporen")
    _nahe(Myzel.ertrag_faktor(0), 1.0, "Ohne Ausbau unveraenderter Ertrag")

    # Negative Stufen duerfen nicht durchschlagen.
    _gleich(Myzel.mehr_sporen(-3), 0, "Negative Stufe wirkt nicht")
    _nahe(Myzel.ertrag_faktor(-3), 1.0, "Negative Stufe senkt den Ertrag nicht")
    return true


func _test_speicher() -> bool:
    var pfad := "user://test_hypha.sav"
    Speicher.loesche(pfad)

    _ist(not Speicher.existiert(pfad), "Vorher liegt keine Datei")
    _ist(Speicher.lies(pfad).is_empty(), "Fehlende Datei ergibt leeres Dict")

    var daten := {"version": 1, "biomasse": 1234.5, "myzel": {"wurf": 2}}
    _ist(Speicher.schreibe(daten, pfad), "Schreiben gelingt")
    _ist(Speicher.existiert(pfad), "Datei liegt danach vor")
    _ist(not FileAccess.file_exists(pfad + ".neu"),
        "Die Nebendatei wird nach dem Umbenennen nicht zurueckgelassen")

    var zurueck := Speicher.lies(pfad)
    _nahe(float(zurueck.get("biomasse", 0.0)), 1234.5, "Biomasse kommt zurueck")
    _gleich(int((zurueck.get("myzel", {}) as Dictionary).get("wurf", 0)), 2,
        "Myzelstufen kommen zurueck")

    # Unverschluesselter Muell darf das Spiel nicht aufhalten.
    print("   (die folgenden Fehlermeldungen sind beabsichtigt: beschaedigte Datei)")
    var kaputt := FileAccess.open(pfad, FileAccess.WRITE)
    kaputt.store_string("das ist kein gueltiger Spielstand")
    kaputt.close()
    _ist(Speicher.lies(pfad).is_empty(), "Beschaedigte Datei ergibt leeres Dict")

    Speicher.loesche(pfad)
    _ist(not Speicher.existiert(pfad), "Loeschen raeumt auf")
    return true


func _test_fortschritt() -> bool:
    # Ohne _ready(), damit der Testlauf nicht den echten Spielstand liest.
    var f: Node = load("res://scripts/daten/fortschritt.gd").new()

    _gleich(f.stufe_von("wurf"), 0, "Neuer Fortschritt hat Stufe 0")
    _ist(not f.kaufe_knoten("wurf"), "Ohne Biomasse kein Kauf")

    var preis: float = Myzel.kosten("wurf", 0)
    f.biomasse = preis
    _ist(f.kaufe_knoten("wurf"), "Mit genug Biomasse kaufbar")
    _gleich(f.stufe_von("wurf"), 1, "Stufe steigt")
    _nahe(float(f.biomasse), 0.0, "Der Preis wird abgezogen")
    _gleich(f.vorschau_abpraller(), Werfer.VORSCHAU_ABPRALLER + 1,
        "Der Kauf wirkt sofort auf die Zielhilfe")

    _ist(not f.kaufe_knoten("gibtsnicht"), "Unbekannte Kennung wird abgewiesen")

    # Hoechststufe sperrt.
    f.biomasse = 1e12
    for i in Myzel.max_stufe("wurf"):
        f.kaufe_knoten("wurf")
    _gleich(f.stufe_von("wurf"), Myzel.max_stufe("wurf"), "Hoechststufe wird erreicht")
    var vor: float = f.biomasse
    _ist(not f.kaufe_knoten("wurf"), "Voll ausgebaut nicht weiter kaufbar")
    _nahe(float(f.biomasse), vor, "Abgelehnter Kauf kostet nichts")

    # Speichern und Laden ueber ein Dictionary.
    f.fortschrittstiefe = 12
    f.proben = 7
    var g: Node = load("res://scripts/daten/fortschritt.gd").new()
    g.aus_dict(f.als_dict())
    _gleich(g.stufe_von("wurf"), Myzel.max_stufe("wurf"), "Myzelstufen ueberstehen das Speichern")
    _gleich(int(g.fortschrittstiefe), 12, "Die Tiefe uebersteht das Speichern")
    _gleich(int(g.proben), 7, "Proben ueberstehen das Speichern")

    # Beschaedigte Werte duerfen nicht durchschlagen.
    var h: Node = load("res://scripts/daten/fortschritt.gd").new()
    h.aus_dict({"myzel": {"wurf": 99, "gibtsnicht": 4}, "biomasse": -50.0})
    _gleich(h.stufe_von("wurf"), Myzel.max_stufe("wurf"), "Zu hohe Stufe wird gekappt")
    _gleich(h.stufe_von("gibtsnicht"), 0, "Unbekannte Kennung bleibt wirkungslos")
    _nahe(float(h.biomasse), 0.0, "Negative Biomasse wird auf 0 gehoben")

    f.free()
    g.free()
    h.free()
    return true
