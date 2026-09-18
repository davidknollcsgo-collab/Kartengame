class_name WegStand
extends RefCounted

## **Was vom Spieler uebrig bleibt, wenn er die App schliesst.**
##
## Vier Hallenstufen, die Ehre, die weiteste Ronde, die beste Kette - und
## zwei Einstellungen. Mehr gibt es nicht zu sichern, und das ist ein
## Qualitaetsmerkmal: was nicht im Spielstand steht, kann auch nicht
## auseinanderlaufen.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

var stufen := {}
var ehre := 0
var weiteste_ronde := 1
var beste_kette := 0
var gefaellt_gesamt := 0
var einstieg := 0        ## 0 = noch nie gespielt
var laut := 0.7
var beben := true


func _init() -> void:
    for h in Schule.NAMEN.size():
        stufen[h] = 0


func stufe(h: int) -> int:
    return int(stufen.get(h, 0))


func naechste_ronde() -> int:
    return weiteste_ronde


## **Was eine Stufe kostet und ob sie bezahlbar ist.** Eine Halle auf
## Hoechststufe kostet nichts mehr - sie ist fertig, nicht unendlich teuer.
func kosten(h: int) -> int:
    if stufe(h) >= Schule.HOECHSTSTUFE:
        return 0
    return Schule.kosten(h, stufe(h))


func kann_bauen(h: int) -> bool:
    return stufe(h) < Schule.HOECHSTSTUFE and ehre >= kosten(h)


func baue(h: int) -> bool:
    if not kann_bauen(h):
        return false
    ehre -= kosten(h)
    stufen[h] = stufe(h) + 1
    return true


## Liegt in der Schule etwas bereit? Der Punkt am Knopf haengt daran - und
## eine Belohnung, die nicht sagt, dass sie dort liegt, holt niemand ab.
func etwas_zu_holen() -> bool:
    for h in Schule.NAMEN.size():
        if kann_bauen(h):
            return true
    return false


func als_wort() -> Dictionary:
    return {
        "stufen": stufen.duplicate(),
        "ehre": ehre,
        "weiteste_ronde": weiteste_ronde,
        "beste_kette": beste_kette,
        "gefaellt_gesamt": gefaellt_gesamt,
        "einstieg": einstieg,
        "laut": laut,
        "beben": beben,
    }


## **Das ganze Wort wird gelesen, nicht eine gepflegte Feldliste.** Ein Feld,
## das man beim Laden zu lesen vergisst, faellt einer Liste nicht auf, die
## man ebenso vergisst.
func aus_wort(w: Dictionary) -> void:
    for schluessel in als_wort().keys():
        if not w.has(schluessel):
            continue
        var wert = w[schluessel]
        match schluessel:
            "stufen":
                for k in wert.keys():
                    stufen[int(k)] = int(wert[k])
            "laut":
                laut = clampf(float(wert), 0.0, 1.0)
            "beben":
                beben = bool(wert)
            _:
                set(schluessel, int(wert))
