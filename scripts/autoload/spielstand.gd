## Zentraler Spielzustand. Autoload, erreichbar als [code]Spielstand[/code].
##
## Haelt Werte und meldet Aenderungen ueber Signale. Die UI verbindet sich
## darauf und fragt nie aktiv ab - so bleibt Darstellung und Logik getrennt und
## die Rechenkerne in [Oekonomie] bleiben headless testbar.
extends Node

## Format des Speicherstands. Bei jeder inkompatiblen Aenderung erhoehen und
## in [method _migriere] einen Pfad ergaenzen. Von Anfang an mitgefuehrt, weil
## eine nachtraeglich eingefuehrte Migration alte Spielstaende bricht.
const SPEICHER_VERSION := 2

## Logikschritte pro Sekunde, bewusst entkoppelt von der Bildrate.
const TICKS_PRO_SEKUNDE := 10.0

## Startguthaben - exakt der Preis des ersten Solarsegels.
##
## Ohne das steht das Spiel still: keine Module heisst Rate 0, und aus Rate 0
## waechst nie genug fuer den ersten Kauf. Der erste Handgriff des Spielers ist
## damit zugleich der erste Baukauf.
const START_PLASMA := 15.0

## Mindestertrag eines manuellen Antippens.
const MANUELL_MINDEST := 1.0

## Ein Antippen entspricht so vielen Sekunden Produktion.
const MANUELL_SEKUNDEN := 1.0

signal plasma_geaendert(wert: float)
signal bestand_geaendert(index: int, anzahl: int)
signal protokolle_geaendert(wert: int)
signal quanten_geaendert(wert: int)

## Aktuell verfuegbare Plasma.
var plasma := 0.0

## Premiumwaehrung aus Kaeufen und Rewarded Ads.
var quanten := 0

## Prestige-Waehrung; ueberlebt jeden Reset.
var protokolle := 0

## Summe aller je erwirtschafteten Plasma - Basis der Prestige-Ausbeute.
var lebenszeit_plasma := 0.0

## Stueckzahl je Modultyp.
var bestand: Array[int] = []

## Dauerhafter Multiplikator aus dem Kauf "Orbital-Verstaerker".
var verstaerker := false

signal ausbau_geaendert
signal errungen_freigeschaltet(id: String, quanten: int)

## Unix-Zeit, bis zu der ein Werbe-Boost laeuft (0 = keiner aktiv).
var boost_bis := 0.0

## Faktor des laufenden Boosts.
var boost_faktor := 1.0

## Ausbaustufe des Langzeitspeichers; bestimmt die Offline-Grenze.
var speicher_stufe := 0

## Kennungen bereits freigeschalteter Errungenschaften.
##
## Bewusst Kennungen statt Indizes: so verschiebt eine spaeter eingefuegte
## Errungenschaft nicht alles Nachfolgende in bestehenden Spielstaenden.
var errungen: PackedStringArray = []

## Anzahl bisheriger Zuruecksetzungen.
var prestige_anzahl := 0

## Gewaehlte Kaufmenge; -1 bedeutet "so viele wie bezahlbar".
var kaufmenge := 1

## Aufsummierte Spielzeit in Sekunden, nur waehrend die App laeuft.
var spielzeit := 0.0

## Unix-Zeit des letzten Speicherns; Grundlage der Offline-Berechnung.
var zeitstempel := 0.0

## Angerechnete Dauer der letzten Abwesenheit, in Sekunden.
##
## Muss festgehalten werden: [method verbuche_offline] stempelt den Zeitpunkt
## neu, sodass der Abstand danach nicht mehr rekonstruierbar ist. Der Dialog
## zeigte deshalb "0s" bei vierstelliger Gutschrift.
var letzte_offline_dauer := 0.0

## Abstand zwischen zwei automatischen Sicherungen.
const AUTOSAVE_SEKUNDEN := 30.0

signal gespeichert

var _rest := 0.0
var _seit_speichern := 0.0
var _seit_pruefung := 0.0


func _ready() -> void:
    bestand.resize(Modul.ANZAHL)
    bestand.fill(0)
    plasma = START_PLASMA
    zeitstempel = Time.get_unix_time_from_system()


func _process(delta: float) -> void:
    # Auf feste Logikschritte herunterbrechen, damit ein 120-Hz-Geraet nicht
    # anders rechnet als ein 60-Hz-Geraet.
    _rest += delta
    var schritt := 1.0 / TICKS_PRO_SEKUNDE
    while _rest >= schritt:
        _rest -= schritt
        _tick(schritt)

    spielzeit += delta
    _seit_speichern += delta
    if _seit_speichern >= AUTOSAVE_SEKUNDEN:
        _seit_speichern = 0.0
        speichere()


func _tick(dt: float) -> void:
    var ertrag := rate() * dt
    if ertrag > 0.0:
        gutschrift(ertrag)

    # Einmal je Sekunde genuegt; bei zehn Ticks je Sekunde waere die Pruefung
    # aller Bedingungen reine Verschwendung.
    _seit_pruefung += dt
    if _seit_pruefung >= 1.0:
        _seit_pruefung = 0.0
        pruefe_errungenschaften()


## Aktueller Gesamtertrag in Plasma pro Sekunde.
func rate() -> float:
    return Oekonomie.gesamt_rate(bestand, global_mult())


## Produktmultiplikator aus Prestige, Kauf-Verstaerker und laufendem Boost.
func global_mult() -> float:
    var m := Oekonomie.prestige_mult(protokolle)
    if verstaerker:
        m *= Ausbau.VERSTAERKER_FAKTOR
    if boost_aktiv():
        m *= boost_faktor
    return m


func boost_aktiv() -> bool:
    return boost_bis > Time.get_unix_time_from_system()


## Verbleibende Schubdauer in Sekunden; 0 wenn keiner laeuft.
func boost_rest() -> float:
    return maxf(boost_bis - Time.get_unix_time_from_system(), 0.0)


## Aktuelle Offline-Grenze, abgeleitet aus der Speicherstufe.
##
## Bewusst berechnet statt gespeichert: zwei Felder, die dasselbe aussagen,
## laufen frueher oder spaeter auseinander.
func offline_grenze() -> float:
    return Ausbau.offline_grenze(speicher_stufe)


# --- Ausbauten --------------------------------------------------------------

## Loest einen Schub aus. Ein laufender Schub wird verlaengert, nicht ersetzt -
## sonst verschenkt ein zu frueher Kauf die Restzeit.
func kaufe_schub() -> bool:
    if quanten < Ausbau.SCHUB_KOSTEN:
        return false
    quanten -= Ausbau.SCHUB_KOSTEN
    var jetzt := Time.get_unix_time_from_system()
    boost_bis = maxf(boost_bis, jetzt) + Ausbau.SCHUB_DAUER
    boost_faktor = Ausbau.SCHUB_FAKTOR
    quanten_geaendert.emit(quanten)
    ausbau_geaendert.emit()
    return true


## Baut den Langzeitspeicher eine Stufe aus.
func kaufe_speicher() -> bool:
    if Ausbau.speicher_voll(speicher_stufe):
        return false
    var preis := Ausbau.speicher_preis(speicher_stufe)
    if quanten < preis:
        return false
    quanten -= preis
    speicher_stufe += 1
    quanten_geaendert.emit(quanten)
    ausbau_geaendert.emit()
    return true


## Kauft den dauerhaften Verstaerker. Nur einmal moeglich.
func kaufe_verstaerker() -> bool:
    if verstaerker or quanten < Ausbau.VERSTAERKER_KOSTEN:
        return false
    quanten -= Ausbau.VERSTAERKER_KOSTEN
    verstaerker = true
    quanten_geaendert.emit(quanten)
    ausbau_geaendert.emit()
    return true


# --- Errungenschaften -------------------------------------------------------

## Messwerte fuer die Bedingungspruefung.
func _messwerte() -> Dictionary:
    return {
        "bestand": Array(bestand),
        "lebenszeit": lebenszeit_plasma,
        "rate": rate(),
        "prestige": prestige_anzahl,
    }


## Schaltet alle inzwischen erfuellten Errungenschaften frei und schreibt die
## Belohnung gut. Gibt die neu freigeschalteten Kennungen zurueck.
func pruefe_errungenschaften() -> PackedStringArray:
    var neu := PackedStringArray()
    var werte := _messwerte()
    for eintrag in Errungenschaft.TABELLE:
        var id := String(eintrag["id"])
        if errungen.has(id):
            continue
        if not Errungenschaft.erfuellt(eintrag, werte):
            continue
        errungen.append(id)
        neu.append(id)
        gutschrift_quanten(int(eintrag["quanten"]))
        errungen_freigeschaltet.emit(id, int(eintrag["quanten"]))
    return neu


## Schreibt Quanten gut, etwa aus einer Errungenschaft.
func gutschrift_quanten(anzahl: int) -> void:
    if anzahl <= 0:
        return
    quanten += anzahl
    quanten_geaendert.emit(quanten)


## Schreibt Plasma gut und fuehrt die Lebenszeitsumme mit.
func gutschrift(betrag: float) -> void:
    if betrag <= 0.0:
        return
    plasma += betrag
    lebenszeit_plasma += betrag
    plasma_geaendert.emit(plasma)


## Manuelles Anzapfen des Stationskerns.
##
## Gibt dem Spieler in der Anfangsphase etwas zu tun und traegt spaeter nichts
## mehr bei, weil die Automatik die Handarbeit um Groessenordnungen ueberholt.
func manuell_sammeln() -> float:
    var betrag := maxf(MANUELL_MINDEST, rate() * MANUELL_SEKUNDEN)
    gutschrift(betrag)
    return betrag


## Kauft [param menge] Exemplare eines Modultyps, sofern bezahlbar.
## Gibt zurueck, ob der Kauf zustande kam.
func kaufe(index: int, menge: int = 1) -> bool:
    if index < 0 or index >= Modul.ANZAHL or menge <= 0:
        return false
    var preis := Oekonomie.kosten_summe(index, bestand[index], menge)
    if preis > plasma:
        return false
    plasma -= preis
    bestand[index] += menge
    plasma_geaendert.emit(plasma)
    bestand_geaendert.emit(index, bestand[index])
    return true


## Setzt die Station zurueck und wandelt den Lebenszeitertrag in Protokolle.
## Gibt die gewonnenen Protokolle zurueck; 0 bedeutet, es wurde nichts getan.
func prestige() -> int:
    if not Oekonomie.prestige_moeglich(lebenszeit_plasma):
        return 0
    var gewinn := Oekonomie.prestige_ertrag(lebenszeit_plasma)
    protokolle += gewinn
    prestige_anzahl += 1
    # Auf das Startguthaben, nicht auf 0: sonst steht die Station nach jedem
    # Reset genauso still wie beim allerersten Start.
    plasma = START_PLASMA
    lebenszeit_plasma = 0.0
    bestand.fill(0)
    boost_bis = 0.0
    plasma_geaendert.emit(plasma)
    protokolle_geaendert.emit(protokolle)
    for i in Modul.ANZAHL:
        bestand_geaendert.emit(i, 0)
    return gewinn


## Berechnet die Abwesenheitsgutschrift und stempelt den Zeitpunkt neu.
##
## Bei rueckwaerts gestellter Uhr gibt es bewusst nichts - sonst waere das
## Spiel durch Zeitverstellen trivial ausbeutbar.
func verbuche_offline(jetzt: float = -1.0) -> float:
    if jetzt < 0.0:
        jetzt = Time.get_unix_time_from_system()
    var verstrichen := jetzt - zeitstempel
    zeitstempel = jetzt
    letzte_offline_dauer = 0.0
    if verstrichen <= 0.0:
        return 0.0
    letzte_offline_dauer = minf(verstrichen, offline_grenze())
    var ertrag := Oekonomie.offline_ertrag(rate(), verstrichen, offline_grenze())
    gutschrift(ertrag)
    return ertrag


# --- Platte -----------------------------------------------------------------

## Schreibt den Spielstand. Gibt Erfolg zurueck.
func speichere() -> bool:
    var ok := Speicher.schreibe(als_dict())
    if ok:
        gespeichert.emit()
    return ok


## Laedt einen vorhandenen Spielstand. Gibt zurueck, ob einer gefunden wurde.
##
## Bewusst nicht in [method _ready]: der Testlauf erzeugt Spielstaende von Hand
## und darf dabei nicht die echte Datei des Entwicklers lesen oder ueberschreiben.
func lade_von_platte() -> bool:
    var d := Speicher.lies()
    if d.is_empty():
        return false
    aus_dict(d)
    return true


func _notification(was: int) -> void:
    # Auf Android ist PAUSED der letzte verlaessliche Moment vor dem Abschuss
    # durch das System - danach kommt oft nichts mehr.
    if was == NOTIFICATION_APPLICATION_PAUSED \
            or was == NOTIFICATION_WM_CLOSE_REQUEST \
            or was == NOTIFICATION_WM_GO_BACK_REQUEST:
        if is_inside_tree():
            speichere()


## Setzt das Spiel vollstaendig zurueck und entfernt die Datei.
##
## Anders als [method prestige]: hier bleibt nichts erhalten, auch nicht
## Protokolle, Quanten oder Errungenschaften.
func loesche_alles() -> void:
    Speicher.loesche()
    plasma = START_PLASMA
    quanten = 0
    protokolle = 0
    prestige_anzahl = 0
    lebenszeit_plasma = 0.0
    spielzeit = 0.0
    bestand.fill(0)
    errungen = PackedStringArray()
    verstaerker = false
    speicher_stufe = 0
    boost_bis = 0.0
    kaufmenge = 1
    zeitstempel = Time.get_unix_time_from_system()

    plasma_geaendert.emit(plasma)
    quanten_geaendert.emit(quanten)
    protokolle_geaendert.emit(protokolle)
    ausbau_geaendert.emit()
    for i in Modul.ANZAHL:
        bestand_geaendert.emit(i, 0)


# --- Serialisierung ---------------------------------------------------------

## Zustand als reines Dictionary, bereit zum Speichern.
func als_dict() -> Dictionary:
    return {
        "version": SPEICHER_VERSION,
        "plasma": plasma,
        "quanten": quanten,
        "protokolle": protokolle,
        "lebenszeit_plasma": lebenszeit_plasma,
        "bestand": Array(bestand),
        "verstaerker": verstaerker,
        "speicher_stufe": speicher_stufe,
        "kaufmenge": kaufmenge,
        "errungen": Array(errungen),
        "prestige_anzahl": prestige_anzahl,
        "spielzeit": spielzeit,
        "zeitstempel": Time.get_unix_time_from_system(),
    }


## Laedt einen Zustand zurueck. Unbekannte oder fehlende Felder fallen auf
## Standardwerte, damit ein beschaedigter Stand das Spiel nicht blockiert.
func aus_dict(d: Dictionary) -> void:
    d = _migriere(d)
    # Standard ist das Startguthaben, nicht 0: ein beschaedigter Stand soll
    # spielbar bleiben statt in der Kaltstart-Falle zu landen.
    plasma = float(d.get("plasma", START_PLASMA))
    quanten = int(d.get("quanten", 0))
    protokolle = int(d.get("protokolle", 0))
    lebenszeit_plasma = float(d.get("lebenszeit_plasma", 0.0))
    verstaerker = bool(d.get("verstaerker", false))
    speicher_stufe = clampi(int(d.get("speicher_stufe", 0)), 0, Ausbau.SPEICHER_MAX)
    kaufmenge = int(d.get("kaufmenge", 1))
    prestige_anzahl = int(d.get("prestige_anzahl", 0))
    spielzeit = float(d.get("spielzeit", 0.0))
    errungen = PackedStringArray()
    for id in d.get("errungen", []):
        errungen.append(String(id))
    zeitstempel = float(d.get("zeitstempel", Time.get_unix_time_from_system()))

    bestand.resize(Modul.ANZAHL)
    bestand.fill(0)
    var geladen: Array = d.get("bestand", [])
    for i in mini(geladen.size(), Modul.ANZAHL):
        bestand[i] = maxi(int(geladen[i]), 0)

    plasma_geaendert.emit(plasma)
    protokolle_geaendert.emit(protokolle)
    quanten_geaendert.emit(quanten)
    for i in Modul.ANZAHL:
        bestand_geaendert.emit(i, bestand[i])


## Hebt aeltere Speicherstaende auf das aktuelle Format.
func _migriere(d: Dictionary) -> Dictionary:
    var v := int(d.get("version", 0))
    if v < 1:
        # Version 0 kannte noch keinen Langzeitspeicher.
        d["speicher_stufe"] = 0
        v = 1
    if v < 2:
        # Version 1 hiess die Grundwaehrung "credits" und die Premiumwaehrung
        # "kerne". Umbenannt, weil das Cent-Zeichen eine echte Waehrung ist und
        # "Kerne" mit dem Stationskern kollidierte.
        if d.has("credits"):
            d["plasma"] = d["credits"]
        if d.has("lebenszeit_credits"):
            d["lebenszeit_plasma"] = d["lebenszeit_credits"]
        if d.has("kerne"):
            d["quanten"] = d["kerne"]
        v = 2
    d["version"] = v
    return d
