extends Node

## **Das Beben.**
##
## Vier Ereignisse, mehr nicht - und eine Sperre dazwischen. Ein Beben je
## Parade waere in einer vollen Ronde ein Dauerbrummen und Akkufrass; was
## gleichzeitig faellt, kann ein Telefon ohnehin nicht trennen.
##
## Der Android-Export braucht dafuer `permissions/vibrate=true` in **beiden**
## Ladestaenden. Ohne den Eintrag bleibt `Input.vibrate_handheld()` auf dem
## Geraet folgenlos, und zwar stumm: kein Fehler, kein Hinweis.

enum Art { PARADE, SCHNITT, WUNDE, ENDE }

## In Millisekunden. Alles ueber etwa 120 ms fuehlt sich nicht mehr nach
## einem Schlag an, sondern nach einem Anruf.
const DAUER: Dictionary = {
    Art.PARADE: 28,
    Art.SCHNITT: 55,
    Art.WUNDE: 95,
    Art.ENDE: 120,
}

const SPERRE := 0.12

var an := true
var _sperre := 0.0


func _process(delta: float) -> void:
    _sperre = maxf(0.0, _sperre - delta)


func gib(art: Art) -> void:
    if not an or _sperre > 0.0:
        return
    if not OS.has_feature("mobile"):
        return
    _sperre = SPERRE
    Input.vibrate_handheld(int(DAUER.get(art, 40)))
