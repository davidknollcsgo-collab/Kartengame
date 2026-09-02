extends Node

## Beben - die dritte Rueckmeldung neben Bild und Ton.
##
## Auf einem Telefon ist das Beben das Einzige, was den Spieler wirklich
## anfasst. Es kostet nichts, es braucht keine Grafik und keinen Lautsprecher,
## und es wirkt auch dann, wenn jemand ohne Ton im Bus spielt - also in der
## Haelfte aller Sitzungen. Bisher gab es hier nichts davon.
##
## **Sparsam, sonst ist es Laerm.** Ein Beben bei jedem Treffer waere in Welle
## 55 ein Dauerbrummen, das den Akku frisst und nach zwei Minuten nervt.
## Gebebt wird deshalb nur bei Ereignissen, die selten sind und etwas
## bedeuten: ein Verlust an der Brut, ein erlegtes Leitwesen, das Stosslicht,
## das Ende einer Sitzung. Fuer alles andere ist der Ton zustaendig.
##
## Reine Ereignisse, kein Zustand: `Tastsinn.gib(Art.X)` ist der ganze Weg
## hinein.

## Wie lange gebebt wird, in Millisekunden. Die Werte sind kurz gehalten -
## alles ueber etwa 120 ms fuehlt sich nicht mehr nach einem Schlag an,
## sondern nach einem Anruf.
enum Art {
    TREFFER,      ## Die Brut wird getroffen. Das Einzige, was wehtun soll.
    LEITWESEN,    ## Ein Leitwesen faellt - der Hoehepunkt eines Abschnitts.
    STOSS,        ## Das Stosslicht wird abgestossen.
    ENDE,         ## Sitzung gehalten oder Brut gefallen.
}

const DAUER: Dictionary = {
    Art.TREFFER: 90,
    Art.LEITWESEN: 60,
    Art.STOSS: 25,
    Art.ENDE: 120,
}

## **Eine Sperre, sonst summiert sich, was gleichzeitig faellt.** Wenn das
## Stosslicht drei Leitwesen auf einmal nimmt, kommen vier Ereignisse im
## selben Bild an. Vier Beben hintereinander sind kein Schlag mehr, sondern
## ein Brummen - und das Telefon kann sie ohnehin nicht trennen.
const SPERRE := 0.14

## Aus- und einschaltbar, und der Stand merkt es sich. Wer Beben nicht mag,
## mag es sehr entschieden nicht.
var an := true

var _sperre := 0.0


func _process(delta: float) -> void:
    if _sperre > 0.0:
        _sperre -= delta


## Bebt, wenn es eingeschaltet ist, das Geraet eines hat und die Sperre
## abgelaufen ist. Auf dem Schreibtisch ist `vibrate_handheld()` folgenlos -
## abgefragt wird trotzdem, weil ein Aufruf je Treffer auch dort Arbeit ist.
func gib(art: Art) -> void:
    if not an or _sperre > 0.0 or not OS.has_feature("mobile"):
        return
    _sperre = SPERRE
    Input.vibrate_handheld(int(DAUER.get(art, 40)))
