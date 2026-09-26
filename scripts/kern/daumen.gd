class_name Daumen
extends RefCounted

## **Der simulierte Daumen.**
##
## Er kann genau eine Sache: dorthin laufen, wo am wenigsten Feinde stehen,
## und dabei Sold mitnehmen. Kein Timing, kein Ausnutzen von Reichweiten,
## kein Vorhalten gegen einen Stuermer. Alles, was ein Mensch zusaetzlich
## kann, geht als **Reserve** in das Ergebnis ein - was er meldet, ist
## deshalb eine *untere* Schranke und keine Vorhersage.
##
## **Er steht hier und nicht im Werkzeug**, weil zwei Stellen zwei Daumen
## waeren: der Messstand wuerde ein anderes Spiel messen als der Schuss
## zeigt, und dann ist die Messung wertlos. Eine Rechnung, ein Daumen.
##
## Rein: kein Szenen-, kein Autoload-Bezug.

## Wie weit er schaut. Weiter gedacht hiesse, er wiche Dingen aus, die er im
## Bild gar nicht saehe - und dann misst man einen Hellseher.
const SICHT := 420.0

## Wie stark ihn Sold anzieht, gemessen an der Flucht. Klein: wer im Gefecht
## Muenzen sammelt statt auszuweichen, stirbt - und genau das soll der
## Messstand nicht tun.
const GIER := 0.35

## **Hier stand ein Heimweh** (`HEIMWEH = 900`): ab dieser Entfernung vom
## Ursprung zog es ihn zurück zur Mitte. Gebaut war es gegen den Marathon -
## ohne es lief er ewig geradeaus und zog eine Schleppe hinter sich her, die
## ihn nie erreichte. Seit die Horde beim Helden bleibt (Zusicherung 23), gibt
## es diese Schleppe nicht mehr, und das Heimweh zog ihn nur noch quer durch
## die Horde zurück. Gemessen verdoppelte es mit mehr Tempo den Schaden durch
## Berührung (78 -> 144), und der Speerträger hielt mit Tempo 1,40 nur 8 von
## 16 Saaten. Ohne es hält er 23 bis 24 von 24, bei jedem Tempo.


## Wohin er im naechsten Schritt laeuft. Laenge hoechstens eins.
static func richtung(s: Gefecht.Stand) -> Vector2:
    var flucht := Vector2.ZERO
    var s2 := SICHT * SICHT
    for f in s.feinde:
        var zu := s.ort - f.ort
        var d2 := zu.length_squared()
        if d2 > s2 or d2 < 0.01:
            continue
        # Naeher heisst staerker, und zwar deutlich: ein linearer Abfall
        # laesst ihn zwischen zwei Gruppen stehenbleiben.
        flucht += zu / d2 * 9000.0

    var gier := Vector2.ZERO
    var nah := 1e20
    for m in s.muenzen:
        var d2 := m.ort.distance_squared_to(s.ort)
        if d2 < nah:
            nah = d2
            gier = (m.ort - s.ort).normalized()

    var summe := flucht.normalized() + gier * GIER
    if summe.length_squared() < 0.0001:
        return Vector2.ZERO
    return summe.limit_length(1.0)


## **Welches der drei Angebote er nimmt.**
##
## Auch das steht hier und nicht im Werkzeug: ein Messstand, der anders
## waehlt als der Schuss, misst ein anderes Spiel.
##
## Seine Regel ist absichtlich stumpf - erst die Plaetze fuellen, dann
## hochstufen. Ein Mensch waehlt besser (er passt die Waffen aneinander an),
## und genau deshalb ist das hier eine **untere** Schranke.
static func waehle(s: Gefecht.Stand) -> int:
    if s.angebote.is_empty():
        return 0
    var bestes := 0
    var beste_note := -1.0
    for i in s.angebote.size():
        var a = s.angebote[i]
        var note := 0.0
        if a.neu:
            # Breite vor Tiefe: vier Waffen, die schlagen, toeten mehr als
            # eine, die gut schlaegt.
            note = 3.0 if a.ist_waffe else 2.0
        else:
            note = 1.0 + 0.1 * float(a.stufe)
        if note > beste_note:
            beste_note = note
            bestes = i
    return bestes
