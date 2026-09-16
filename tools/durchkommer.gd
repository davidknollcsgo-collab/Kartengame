extends SceneTree

## **Warum kommt ein Raeuber durch?**
##
##     godot --headless --path . --script tools/durchkommer.gd
##
## `tools/ausreisser.gd` sagt, *welche* Wellen teuer sind, und hat drei
## Erklaerungen dafuer widerlegt - Tempo, Panzerklippe, Andrang. Alle drei
## waren Eigenschaften, aus denen auf einen Mechanismus geschlossen werden
## sollte. Dieses Werkzeug fragt den Mechanismus direkt: es schaltet
## `Simulation.buchfuehrung` an und liest aus, womit die Tiere, die das
## Boot erreicht haben, ihre Zeit verbracht haben.
##
##   * **fern** - ausser Reichweite. Daran kann kein Daumen etwas aendern,
##     ohne hinzufahren: das ist die Groesse des Feldes.
##   * **uebersehen** - **in** Reichweite und trotzdem dunkel. Der Kegel
##     haette es fassen koennen und stand woanders. Der einzige Posten, der
##     an der Zielpolitik haengt.
##   * **zaeh** - es stand **im Licht** und nahm trotzdem null, weil
##     Mindesthelligkeit, Panzer oder Obergrenze alles wegnahmen.
##   * **wartend** - waere zu treffen gewesen, aber der Kegel fasst nur
##     `ziele` Stueck und andere waren wirksamer.
##   * **brennt** - gewaehlt und beschossen, nur nicht genug.
##
## Welcher Posten ueberwiegt, sagt, welcher Hebel greifen kann. Gemessen
## wird die Spitze der Verteilung gegen ihren Median, weil nur der
## Unterschied etwas aussagt: wenn teure und billige Wellen dieselbe
## Aufteilung haben, ist keiner der drei der Grund.

const TEUER := [176, 210, 161, 77, 191, 164, 100, 97, 137, 116, 98, 179]
const BILLIG := [122, 121, 114, 113, 112, 111, 109, 55, 56, 57, 58, 59]


func _init() -> void:
    Simulation.buchfuehrung = true
    print("Welle | Verlust | durch |  fern | uebersehen | zaeh | wartend | brennt")
    _gruppe("teuer", TEUER)
    _gruppe("billig", BILLIG)
    quit()


func _gruppe(name: String, wellen: Array) -> void:
    print("\n--- %s ---" % name)
    var fe := 0.0
    var ue := 0.0
    var za := 0.0
    var wa := 0.0
    var br := 0.0
    var dk := 0
    for nummer: int in wellen:
        var z := Simulation.Zustand.new()
        Simulation.stelle_ein(z, nummer)
        z.huelle = z.huelle_voll
        var e := Simulation.welle(nummer, z)
        var d := maxi(1, e.durchkommer)
        print("%5d | %6.0f %% | %5d | %5.1f | %10.1f | %4.1f | %7.1f | %6.1f" % [
            nummer, float(e.verlust()) / float(maxi(1, z.huelle_voll)) * 100.0,
            e.durchkommer, e.sek_fern / float(d), e.sek_uebersehen / float(d),
            e.sek_zaeh / float(d), e.sek_wartend / float(d),
            e.sek_brennt / float(d)])
        fe += e.sek_fern
        ue += e.sek_uebersehen
        za += e.sek_zaeh
        wa += e.sek_wartend
        br += e.sek_brennt
        dk += e.durchkommer
    var g := maxf(0.001, fe + ue + za + wa + br)
    print("zusammen: %d Durchkommer, fern %.0f %%, uebersehen %.0f %%, zaeh %.0f %%, wartend %.0f %%, brennt %.0f %%"
        % [dk, fe / g * 100.0, ue / g * 100.0, za / g * 100.0,
            wa / g * 100.0, br / g * 100.0])
