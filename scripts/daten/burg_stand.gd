class_name BurgStand
extends RefCounted

## **Was vom Spieler übrig bleibt, wenn er die App schließt.**
##
## Vier Baustufen, der Sold, die weiteste Zeit, ein paar Bestmarken und zwei
## Einstellungen. Mehr gibt es nicht zu sichern, und das ist ein
## Qualitätsmerkmal: was nicht im Spielstand steht, kann auch nicht
## auseinanderlaufen.

var stufen := {}
## Stueck -> Stufe. Was man je gefunden hat.
var besitz := {}
## Platz -> Stueck. Was davon getragen wird.
var angelegt := {}
var held := 0
## Held -> gewaehlte Skin. Fehlt einer, traegt er die erste - die ist immer
## frei, also braucht ein alter Spielstand keine Wanderung.
var skins := {}
var sold := 0
var laeufe := 0
var beste_zeit := 0.0
var meiste_erschlagen := 0
var warlord_gefallen := false
var einstieg := 0
var laut := 0.7
var beben := true


func _init() -> void:
    for b in Halle.NAMEN.size():
        stufen[b] = 0


func stufe(b: int) -> int:
    return int(stufen.get(b, 0))


## Welche Skin dieser Held traegt. **Immer eine freigeschaltete:** wer eine
## Bestmarke zurueckdreht, soll nicht in einem Gewand stehen, das er nicht
## mehr hat - und ein Spielstand aus einer aelteren Fassung kennt das Feld
## gar nicht.
func skin(h: int) -> int:
    var n := int(skins.get(h, 0))
    if n > 0 and not Skins.ist_frei(h, n, beste_zeit, meiste_erschlagen,
            warlord_gefallen):
        return 0
    return clampi(n, 0, Skins.JE_HELD - 1)


func waehle_skin(h: int, n: int) -> bool:
    if not Skins.ist_frei(h, n, beste_zeit, meiste_erschlagen, warlord_gefallen):
        return false
    skins[h] = clampi(n, 0, Skins.JE_HELD - 1)
    return true


func kosten(b: int) -> int:
    if stufe(b) >= Halle.HOECHSTSTUFE:
        return 0
    return Halle.kosten(b, stufe(b))


func kann_bauen(b: int) -> bool:
    return stufe(b) < Halle.HOECHSTSTUFE and sold >= kosten(b)


func baue(b: int) -> bool:
    if not kann_bauen(b):
        return false
    sold -= kosten(b)
    stufen[b] = stufe(b) + 1
    return true


## Liegt in der Burg etwas bereit? Der Punkt am Knopf hängt daran - eine
## Belohnung, die nicht sagt, dass sie dort liegt, holt niemand ab.
## Was `Gefecht.baue()` braucht: Platz -> [Stueck, Stufe].
func getragen() -> Dictionary:
    var d := {}
    for platz in angelegt.keys():
        var stueck := int(angelegt[platz])
        d[int(platz)] = [stueck, int(besitz.get(stueck, 0))]
    return d


## Ein Fund wird eingetragen: neu, oder eine Stufe hoeher.
func finde(stueck: int, stufen_zahl: int) -> int:
    var alt := int(besitz.get(stueck, 0))
    var neu := clampi(alt + stufen_zahl, 1, Ausruestung.HOECHSTSTUFE)
    besitz[stueck] = neu
    # **Wer noch nichts auf diesem Platz traegt, traegt es sofort.** Ein Fund,
    # den man erst in einem Menue anlegen muss, um ihn zu spueren, ist fuer
    # die Haelfte der Spieler kein Fund.
    var platz := Ausruestung.platz_von(stueck)
    if not angelegt.has(platz):
        angelegt[platz] = stueck
    return neu


func lege_an(stueck: int) -> void:
    if int(besitz.get(stueck, 0)) <= 0:
        return
    angelegt[Ausruestung.platz_von(stueck)] = stueck


func etwas_zu_holen() -> bool:
    for b in Halle.NAMEN.size():
        if kann_bauen(b):
            return true
    return false


func als_wort() -> Dictionary:
    return {
        "stufen": stufen.duplicate(),
        "besitz": besitz.duplicate(),
        "angelegt": angelegt.duplicate(),
        "held": held,
        "skins": skins.duplicate(),
        "sold": sold,
        "laeufe": laeufe,
        "beste_zeit": beste_zeit,
        "meiste_erschlagen": meiste_erschlagen,
        "warlord_gefallen": warlord_gefallen,
        "einstieg": einstieg,
        "laut": laut,
        "beben": beben,
    }


## **Das ganze Wort wird gelesen, nicht eine gepflegte Feldliste.** Ein Feld,
## das man beim Laden zu lesen vergisst, fällt einer Liste nicht auf, die man
## ebenso vergisst.
func aus_wort(w: Dictionary) -> void:
    for schluessel in als_wort().keys():
        if not w.has(schluessel):
            continue
        var wert: Variant = w[schluessel]
        match schluessel:
            "stufen":
                for k in wert.keys():
                    stufen[int(k)] = int(wert[k])
            "besitz":
                for k in wert.keys():
                    besitz[int(k)] = int(wert[k])
            "angelegt":
                for k in wert.keys():
                    angelegt[int(k)] = int(wert[k])
            "skins":
                for k in wert.keys():
                    skins[int(k)] = int(wert[k])
            "laut":
                laut = clampf(float(wert), 0.0, 1.0)
            "beste_zeit":
                beste_zeit = float(wert)
            "beben", "warlord_gefallen":
                set(schluessel, bool(wert))
            _:
                set(schluessel, int(wert))
