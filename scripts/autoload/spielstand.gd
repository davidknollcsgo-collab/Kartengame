## Zentraler Spielzustand. Autoload, erreichbar als [code]Spielstand[/code].
##
## Haelt Werte und meldet Aenderungen ueber Signale. Die UI verbindet sich
## darauf und fragt nie aktiv ab - so bleibt Darstellung und Logik getrennt und
## die Rechenkerne in [Oekonomie] bleiben headless testbar.
extends Node

## Format des Speicherstands. Bei jeder inkompatiblen Aenderung erhoehen und
## in [method _migriere] einen Pfad ergaenzen. Von Anfang an mitgefuehrt, weil
## eine nachtraeglich eingefuehrte Migration alte Spielstaende bricht.
const SPEICHER_VERSION := 4

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

## Verfuegbare Protokolle, die fuer Ausbauten ausgegeben werden koennen.
var protokolle := 0

## Jemals verdiente Protokolle.
##
## Der passive Multiplikator haengt hieran, nicht am Guthaben: sonst wuerde
## jeder Ausbaukauf den Multiplikator senken und sich wie eine Strafe
## anfuehlen. Ausgeben und Belohnung duerfen sich nicht widersprechen.
var protokolle_gesamt := 0

## Stufe je Protokoll-Ausbau, nach Kennung.
var p_stufe: Dictionary = {}

## Summe aller je erwirtschafteten Plasma - Basis der Prestige-Ausbeute.
var lebenszeit_plasma := 0.0

## Stueckzahl je Modultyp.
var bestand: Array[int] = []

## Ausbaustufe je Modultyp.
var modul_stufe: Array[int] = []

## Dauerhafter Multiplikator aus dem Kauf "Orbital-Verstaerker".
var verstaerker := false

signal ausbau_geaendert
signal errungen_freigeschaltet(id: String, quanten: int)

## Ein Fund ist aufgetaucht und kann angetippt werden.
signal fund_erschienen(art: int)

## Ein Fund wurde eingelöst; [param text] beschreibt, was er gebracht hat.
signal fund_eingeloest(text: String)

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

## Ob Rueckmeldungstoene ausgegeben werden.
var ton := true

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

## Unix-Zeit, zu der der nächste Fund auftaucht.
var _naechster_fund := 0.0


func _ready() -> void:
    bestand.resize(Modul.ANZAHL)
    bestand.fill(0)
    modul_stufe.resize(Modul.ANZAHL)
    modul_stufe.fill(0)
    plasma = START_PLASMA
    zeitstempel = Time.get_unix_time_from_system()
    _plane_fund()


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
        _pruefe_fund()


## Aktueller Gesamtertrag in Plasma pro Sekunde.
func rate() -> float:
    return Oekonomie.gesamt_rate(bestand, global_mult(), modul_stufe)


## Produktmultiplikator aus Prestige, Kauf-Verstaerker und laufendem Boost.
func global_mult() -> float:
    var m := Oekonomie.prestige_mult(protokolle_gesamt)
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


# --- Funde ------------------------------------------------------------------

## Legt den Zeitpunkt des nächsten Funds fest.
func _plane_fund() -> void:
    _naechster_fund = Time.get_unix_time_from_system() + Ereignis.abstand(randf())


## Meldet einen Fund, sobald es Zeit dafür ist.
##
## Läuft nur, während die App offen ist - Funde während der Abwesenheit
## nachzuholen wäre sinnlos, weil niemand sie antippen könnte.
func _pruefe_fund() -> void:
    if Time.get_unix_time_from_system() < _naechster_fund:
        return
    _plane_fund()
    var eintrag := Ereignis.waehle(randf())
    fund_erschienen.emit(int(eintrag["art"]))


## Löst einen angetippten Fund ein und gibt zurück, was er gebracht hat.
func loese_fund_ein(art: int) -> String:
    match art:
        Ereignis.Art.PLASMA:
            var betrag := Ereignis.plasma_belohnung(rate())
            gutschrift(betrag)
            return "+" + Zahl.kurz(betrag) + " Plasma"
        Ereignis.Art.QUANTEN:
            var anzahl := Ereignis.quanten_belohnung(randf())
            gutschrift_quanten(anzahl)
            return "+%d Quanten" % anzahl
        Ereignis.Art.SCHUB:
            var jetzt := Time.get_unix_time_from_system()
            boost_bis = maxf(boost_bis, jetzt) + Ereignis.SCHUB_DAUER
            boost_faktor = Ereignis.SCHUB_FAKTOR
            ausbau_geaendert.emit()
            return "x%d für %s" % [int(Ereignis.SCHUB_FAKTOR),
                Zahl.zeit(Ereignis.SCHUB_DAUER)]
    return ""


# --- Protokoll-Ausbauten ----------------------------------------------------

## Stufe eines Protokoll-Ausbaus.
func stufe_von(id: String) -> int:
    return int(p_stufe.get(id, 0))


## Rabattfaktor auf Baugruppen-Ausbaustufen.
func ausbau_rabatt() -> float:
    return ProtokollAusbau.ausbau_rabatt(stufe_von("feinbau"))


## Kauft die naechste Stufe eines Protokoll-Ausbaus.
func kaufe_protokoll_ausbau(id: String) -> bool:
    var stufe := stufe_von(id)
    if ProtokollAusbau.voll(id, stufe):
        return false
    var preis := ProtokollAusbau.kosten(id, stufe)
    if preis <= 0 or protokolle < preis:
        return false
    protokolle -= preis
    p_stufe[id] = stufe + 1
    protokolle_geaendert.emit(protokolle)
    ausbau_geaendert.emit()
    return true


## Setzt die Station auf den Zustand nach einem Reset - einschliesslich der
## Starthilfen aus den Protokoll-Ausbauten.
func _setze_startzustand() -> void:
    plasma = START_PLASMA + ProtokollAusbau.startkapital(stufe_von("startkapital"))
    bestand.fill(0)
    modul_stufe.fill(0)
    var arten := ProtokollAusbau.anlauf_arten(stufe_von("anlauf"))
    var stueck := ProtokollAusbau.anlauf_stueck(stufe_von("anlauf"))
    for i in mini(arten, Modul.ANZAHL):
        bestand[i] = stueck


# --- Errungenschaften -------------------------------------------------------

## Messwerte fuer die Bedingungspruefung.
func _messwerte() -> Dictionary:
    return {
        "bestand": Array(bestand),
        "modul_stufe": Array(modul_stufe),
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
    var betrag := maxf(MANUELL_MINDEST, rate() * MANUELL_SEKUNDEN) \
        * ProtokollAusbau.hand_faktor(stufe_von("hand"))
    gutschrift(betrag)
    return betrag


## Kauft die naechste Ausbaustufe einer Baugruppe.
##
## Anders als beim Stueckkauf gibt es hier keine Menge: eine Stufe auf einmal
## haelt die Entscheidung ueberschaubar.
func kaufe_modul_ausbau(index: int) -> bool:
    if index < 0 or index >= Modul.ANZAHL:
        return false
    if ModulAusbau.voll(modul_stufe[index]):
        return false
    var preis := ModulAusbau.kosten(index, modul_stufe[index], ausbau_rabatt())
    if preis > plasma:
        return false
    plasma -= preis
    modul_stufe[index] += 1
    plasma_geaendert.emit(plasma)
    bestand_geaendert.emit(index, bestand[index])
    return true


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
    protokolle_gesamt += gewinn
    prestige_anzahl += 1
    # Auf den Startzustand, nicht auf 0: sonst steht die Station nach jedem
    # Reset genauso still wie beim allerersten Start. Ausbaustufen der
    # Baugruppen gehen dabei verloren - sonst waere der zweite Durchlauf
    # trivial und Prestige verloere seinen Sinn.
    lebenszeit_plasma = 0.0
    _setze_startzustand()
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
    var ertrag := Oekonomie.offline_ertrag(rate(), verstrichen, offline_grenze(),
        ProtokollAusbau.offline_anteil(stufe_von("speicher")))
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
    protokolle_gesamt = 0
    p_stufe = {}
    prestige_anzahl = 0
    lebenszeit_plasma = 0.0
    spielzeit = 0.0
    bestand.fill(0)
    modul_stufe.fill(0)
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
        "protokolle_gesamt": protokolle_gesamt,
        "p_stufe": p_stufe.duplicate(),
        "lebenszeit_plasma": lebenszeit_plasma,
        "bestand": Array(bestand),
        "modul_stufe": Array(modul_stufe),
        "verstaerker": verstaerker,
        "speicher_stufe": speicher_stufe,
        "kaufmenge": kaufmenge,
        "ton": ton,
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
    # Aeltere Staende kannten nur eine Zahl; dort ist Guthaben gleich Gesamt.
    protokolle_gesamt = int(d.get("protokolle_gesamt", protokolle))
    p_stufe = {}
    for id in d.get("p_stufe", {}):
        p_stufe[String(id)] = clampi(int(d["p_stufe"][id]), 0,
            ProtokollAusbau.max_stufe(String(id)))
    lebenszeit_plasma = float(d.get("lebenszeit_plasma", 0.0))
    verstaerker = bool(d.get("verstaerker", false))
    speicher_stufe = clampi(int(d.get("speicher_stufe", 0)), 0, Ausbau.SPEICHER_MAX)
    kaufmenge = int(d.get("kaufmenge", 1))
    ton = bool(d.get("ton", true))
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

    modul_stufe.resize(Modul.ANZAHL)
    modul_stufe.fill(0)
    var stufen: Array = d.get("modul_stufe", [])
    for i in mini(stufen.size(), Modul.ANZAHL):
        modul_stufe[i] = clampi(int(stufen[i]), 0, ModulAusbau.MAX_STUFE)

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
    if v < 4:
        # Version 3 kannte weder das Gesamtkonto noch Protokoll-Ausbauten.
        d["protokolle_gesamt"] = int(d.get("protokolle", 0))
        d["p_stufe"] = {}
    if v < 3:
        # Version 2 kannte noch keine Ausbaustufen je Baugruppe.
        d["modul_stufe"] = []
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
    v = 4
    d["version"] = v
    return d
