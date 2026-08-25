## Dauerhafter Spielfortschritt. Autoload, erreichbar als [code]Fortschritt[/code].
##
## Haelt nur Werte und meldet Aenderungen ueber Signale. Die Rechenkerne -
## [Ballistik] allen voran - bleiben davon unberuehrt, damit sie im headless
## Testlauf ohne Szenenbaum ladbar sind.
extends Node

## Format des Speicherstands. Bei jeder inkompatiblen Aenderung erhoehen und in
## [method _migriere] einen Pfad ergaenzen. Von Anfang an mitgefuehrt, weil eine
## nachtraeglich eingefuehrte Migration alte Staende bricht.
const SPEICHER_VERSION := 1

signal biomasse_geaendert(wert: float)
signal proben_geaendert(wert: int)
signal kammer_geschafft(nummer: int)
signal myzel_geaendert

## Weiche Waehrung aus jeder Kammer.
var biomasse := 0.0

## Sporenproben fuer die Stammzucht.
var proben := 0

## Hoechste geschaffte Kammer; bestimmt, was freigeschaltet ist.
var fortschrittstiefe := 0

## Ob Toene ausgegeben werden.
var ton := true


func schreibe_gut(menge: float) -> void:
    if menge <= 0.0:
        return
    biomasse += menge
    biomasse_geaendert.emit(biomasse)


func schreibe_proben(anzahl: int) -> void:
    if anzahl <= 0:
        return
    proben += anzahl
    proben_geaendert.emit(proben)


## Vermerkt eine geschaffte Kammer.
func vermerke_kammer(nummer: int) -> void:
    if nummer > fortschrittstiefe:
        fortschrittstiefe = nummer
    kammer_geschafft.emit(nummer)
    sichere()
    sichere()


func als_dict() -> Dictionary:
    return {
        "version": SPEICHER_VERSION,
        "biomasse": biomasse,
        "proben": proben,
        "tiefe": fortschrittstiefe,
        "ton": ton,
        "myzel": myzel.duplicate(),
    }


func aus_dict(d: Dictionary) -> void:
    d = _migriere(d)
    biomasse = maxf(float(d.get("biomasse", 0.0)), 0.0)
    proben = maxi(int(d.get("proben", 0)), 0)
    fortschrittstiefe = maxi(int(d.get("tiefe", 0)), 0)
    ton = bool(d.get("ton", true))
    myzel = {}
    for id in d.get("myzel", {}):
        var kennung := String(id)
        myzel[kennung] = clampi(int(d["myzel"][id]), 0, Myzel.max_stufe(kennung))
    myzel = {}
    for id in d.get("myzel", {}):
        var kennung := String(id)
        myzel[kennung] = clampi(int(d["myzel"][id]), 0, Myzel.max_stufe(kennung))
    biomasse_geaendert.emit(biomasse)
    proben_geaendert.emit(proben)


func _migriere(d: Dictionary) -> Dictionary:
    d["version"] = int(d.get("version", SPEICHER_VERSION))
    return d


## Stufe je Myzel-Knoten, nach Kennung.
var myzel: Dictionary = {}


func _ready() -> void:
    lade()


## Stufe eines Myzel-Knotens.
func stufe_von(id: String) -> int:
    return int(myzel.get(id, 0))


## Kauft die nächste Stufe eines Knotens.
func kaufe_knoten(id: String) -> bool:
    var stufe := stufe_von(id)
    if Myzel.voll(id, stufe):
        return false
    var preis := Myzel.kosten(id, stufe)
    if preis <= 0.0 or biomasse < preis:
        return false
    biomasse -= preis
    myzel[id] = stufe + 1
    biomasse_geaendert.emit(biomasse)
    myzel_geaendert.emit()
    sichere()
    return true


# --- Wirkungen, gebündelt für das Spiel -------------------------------------

func vorschau_abpraller() -> int:
    return Myzel.vorschau_abpraller(stufe_von("wurf"))


func mehr_abpraller() -> int:
    return Myzel.mehr_abpraller(stufe_von("wucht"))


func spore_radius() -> float:
    return Myzel.spore_radius(stufe_von("zerfall"))


func mehr_sporen() -> int:
    return Myzel.mehr_sporen(stufe_von("vorrat"))


func ertrag_faktor() -> float:
    return Myzel.ertrag_faktor(stufe_von("ernte"))


# --- Platte -----------------------------------------------------------------

func sichere() -> bool:
    return Speicher.schreibe(als_dict())


func lade() -> bool:
    var d := Speicher.lies()
    if d.is_empty():
        return false
    aus_dict(d)
    return true


func loesche_alles() -> void:
    Speicher.loesche()
    biomasse = 0.0
    proben = 0
    fortschrittstiefe = 0
    myzel = {}
    biomasse_geaendert.emit(biomasse)
    proben_geaendert.emit(proben)
    myzel_geaendert.emit()


func _notification(was: int) -> void:
    # Auf Android ist PAUSED der letzte verlaessliche Moment vor dem Abschuss
    # durch das System - danach kommt oft nichts mehr.
    if was == NOTIFICATION_APPLICATION_PAUSED \
            or was == NOTIFICATION_WM_CLOSE_REQUEST \
            or was == NOTIFICATION_WM_GO_BACK_REQUEST:
        if is_inside_tree():
            sichere()
