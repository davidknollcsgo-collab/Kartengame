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


func als_dict() -> Dictionary:
    return {
        "version": SPEICHER_VERSION,
        "biomasse": biomasse,
        "proben": proben,
        "tiefe": fortschrittstiefe,
        "ton": ton,
    }


func aus_dict(d: Dictionary) -> void:
    d = _migriere(d)
    biomasse = maxf(float(d.get("biomasse", 0.0)), 0.0)
    proben = maxi(int(d.get("proben", 0)), 0)
    fortschrittstiefe = maxi(int(d.get("tiefe", 0)), 0)
    ton = bool(d.get("ton", true))
    biomasse_geaendert.emit(biomasse)
    proben_geaendert.emit(proben)


func _migriere(d: Dictionary) -> Dictionary:
    d["version"] = int(d.get("version", SPEICHER_VERSION))
    return d
