## Zentraler Spielzustand. Autoload, erreichbar als [code]Spielstand[/code].
##
## Haelt Werte und meldet Aenderungen ueber Signale. Die UI verbindet sich
## darauf und fragt nie aktiv ab - so bleibt Darstellung und Logik getrennt und
## die Rechenkerne in [Oekonomie] bleiben headless testbar.
extends Node

## Format des Speicherstands. Bei jeder inkompatiblen Aenderung erhoehen und
## in [method _migriere] einen Pfad ergaenzen. Von Anfang an mitgefuehrt, weil
## eine nachtraeglich eingefuehrte Migration alte Spielstaende bricht.
const SPEICHER_VERSION := 1

## Logikschritte pro Sekunde, bewusst entkoppelt von der Bildrate.
const TICKS_PRO_SEKUNDE := 10.0

## Startguthaben - exakt der Preis des ersten Solarsegels.
##
## Ohne das steht das Spiel still: keine Module heisst Rate 0, und aus Rate 0
## waechst nie genug fuer den ersten Kauf. Der erste Handgriff des Spielers ist
## damit zugleich der erste Baukauf.
const START_CREDITS := 15.0

## Mindestertrag eines manuellen Antippens.
const MANUELL_MINDEST := 1.0

## Ein Antippen entspricht so vielen Sekunden Produktion.
const MANUELL_SEKUNDEN := 1.0

signal credits_geaendert(wert: float)
signal bestand_geaendert(index: int, anzahl: int)
signal protokolle_geaendert(wert: int)
signal kerne_geaendert(wert: int)

## Aktuell verfuegbare Credits.
var credits := 0.0

## Premiumwaehrung aus Kaeufen und Rewarded Ads.
var kerne := 0

## Prestige-Waehrung; ueberlebt jeden Reset.
var protokolle := 0

## Summe aller je erwirtschafteten Credits - Basis der Prestige-Ausbeute.
var lebenszeit_credits := 0.0

## Stueckzahl je Modultyp.
var bestand: Array[int] = []

## Dauerhafter x2-Multiplikator aus dem Kauf "Orbital-Verstaerker".
var verstaerker := false

## Unix-Zeit, bis zu der ein Werbe-Boost laeuft (0 = keiner aktiv).
var boost_bis := 0.0

## Faktor des laufenden Boosts.
var boost_faktor := 1.0

## Obergrenze fuer Offline-Ertrag in Sekunden.
var offline_cap := Oekonomie.OFFLINE_CAP_BASIS

## Gewaehlte Kaufmenge; -1 bedeutet "so viele wie bezahlbar".
var kaufmenge := 1

## Unix-Zeit des letzten Speicherns; Grundlage der Offline-Berechnung.
var zeitstempel := 0.0

## Abstand zwischen zwei automatischen Sicherungen.
const AUTOSAVE_SEKUNDEN := 30.0

signal gespeichert

var _rest := 0.0
var _seit_speichern := 0.0


func _ready() -> void:
    bestand.resize(Modul.ANZAHL)
    bestand.fill(0)
    credits = START_CREDITS
    zeitstempel = Time.get_unix_time_from_system()


func _process(delta: float) -> void:
    # Auf feste Logikschritte herunterbrechen, damit ein 120-Hz-Geraet nicht
    # anders rechnet als ein 60-Hz-Geraet.
    _rest += delta
    var schritt := 1.0 / TICKS_PRO_SEKUNDE
    while _rest >= schritt:
        _rest -= schritt
        _tick(schritt)

    _seit_speichern += delta
    if _seit_speichern >= AUTOSAVE_SEKUNDEN:
        _seit_speichern = 0.0
        speichere()


func _tick(dt: float) -> void:
    var ertrag := rate() * dt
    if ertrag > 0.0:
        gutschrift(ertrag)


## Aktueller Gesamtertrag in Credits pro Sekunde.
func rate() -> float:
    return Oekonomie.gesamt_rate(bestand, global_mult())


## Produktmultiplikator aus Prestige, Kauf-Verstaerker und laufendem Boost.
func global_mult() -> float:
    var m := Oekonomie.prestige_mult(protokolle)
    if verstaerker:
        m *= 2.0
    if boost_aktiv():
        m *= boost_faktor
    return m


func boost_aktiv() -> bool:
    return boost_bis > Time.get_unix_time_from_system()


## Schreibt Credits gut und fuehrt die Lebenszeitsumme mit.
func gutschrift(betrag: float) -> void:
    if betrag <= 0.0:
        return
    credits += betrag
    lebenszeit_credits += betrag
    credits_geaendert.emit(credits)


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
    if preis > credits:
        return false
    credits -= preis
    bestand[index] += menge
    credits_geaendert.emit(credits)
    bestand_geaendert.emit(index, bestand[index])
    return true


## Setzt die Station zurueck und wandelt den Lebenszeitertrag in Protokolle.
## Gibt die gewonnenen Protokolle zurueck; 0 bedeutet, es wurde nichts getan.
func prestige() -> int:
    var gewinn := Oekonomie.prestige_ertrag(lebenszeit_credits)
    if gewinn <= 0:
        return 0
    protokolle += gewinn
    # Auf das Startguthaben, nicht auf 0: sonst steht die Station nach jedem
    # Reset genauso still wie beim allerersten Start.
    credits = START_CREDITS
    lebenszeit_credits = 0.0
    bestand.fill(0)
    boost_bis = 0.0
    credits_geaendert.emit(credits)
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
    if verstrichen <= 0.0:
        return 0.0
    var ertrag := Oekonomie.offline_ertrag(rate(), verstrichen, offline_cap)
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


# --- Serialisierung ---------------------------------------------------------

## Zustand als reines Dictionary, bereit zum Speichern.
func als_dict() -> Dictionary:
    return {
        "version": SPEICHER_VERSION,
        "credits": credits,
        "kerne": kerne,
        "protokolle": protokolle,
        "lebenszeit_credits": lebenszeit_credits,
        "bestand": Array(bestand),
        "verstaerker": verstaerker,
        "offline_cap": offline_cap,
        "kaufmenge": kaufmenge,
        "zeitstempel": Time.get_unix_time_from_system(),
    }


## Laedt einen Zustand zurueck. Unbekannte oder fehlende Felder fallen auf
## Standardwerte, damit ein beschaedigter Stand das Spiel nicht blockiert.
func aus_dict(d: Dictionary) -> void:
    d = _migriere(d)
    # Standard ist das Startguthaben, nicht 0: ein beschaedigter Stand soll
    # spielbar bleiben statt in der Kaltstart-Falle zu landen.
    credits = float(d.get("credits", START_CREDITS))
    kerne = int(d.get("kerne", 0))
    protokolle = int(d.get("protokolle", 0))
    lebenszeit_credits = float(d.get("lebenszeit_credits", 0.0))
    verstaerker = bool(d.get("verstaerker", false))
    offline_cap = float(d.get("offline_cap", Oekonomie.OFFLINE_CAP_BASIS))
    kaufmenge = int(d.get("kaufmenge", 1))
    zeitstempel = float(d.get("zeitstempel", Time.get_unix_time_from_system()))

    bestand.resize(Modul.ANZAHL)
    bestand.fill(0)
    var geladen: Array = d.get("bestand", [])
    for i in mini(geladen.size(), Modul.ANZAHL):
        bestand[i] = maxi(int(geladen[i]), 0)

    credits_geaendert.emit(credits)
    protokolle_geaendert.emit(protokolle)
    kerne_geaendert.emit(kerne)
    for i in Modul.ANZAHL:
        bestand_geaendert.emit(i, bestand[i])


## Hebt aeltere Speicherstaende auf das aktuelle Format.
func _migriere(d: Dictionary) -> Dictionary:
    var v := int(d.get("version", 0))
    if v < 1:
        # Version 0 kannte noch keine Offline-Obergrenze.
        d["offline_cap"] = Oekonomie.OFFLINE_CAP_BASIS
        v = 1
    d["version"] = v
    return d
