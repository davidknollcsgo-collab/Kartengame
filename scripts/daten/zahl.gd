class_name Zahl
extends RefCounted

## Grosse Zahlen lesbar machen.
##
## Seit die Kolonie kein Ende mehr hat, wachsen Naehrstoff und Kammerkosten
## geometrisch weiter - auf Stufe 40 kostet eine volle Runde bereits knapp
## fuenf Milliarden. Sechzehn Ziffern nebeneinander sind auf einem Telefon
## keine Zahl mehr, sondern ein Streifen: niemand sieht, ob dort 4807679356
## oder 480767935 steht, und genau diesen Unterschied muss man sehen, um zu
## entscheiden, ob man kaufen kann.
##
## Drei bedeutsame Stellen und ein Kuerzel. Kleine Zahlen bleiben, wie sie
## sind - unter zehntausend liest man sie ohnehin auf einen Blick, und die
## ersten Stunden des Spiels sollen keine Kuerzel zeigen.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

## Ab hier wird gekuerzt.
const AB := 10000

## Tausend, Million, Milliarde, Billion und weiter. Englisch, weil alles
## Sichtbare englisch ist - "B" ist dort die Milliarde.
const KUERZEL: PackedStringArray = [
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
]


static func kurz(wert: int) -> String:
    var negativ := wert < 0
    var rest := absf(float(wert))
    if rest < float(AB):
        return str(wert)

    var stufe := 0
    while rest >= 1000.0 and stufe < KUERZEL.size() - 1:
        rest /= 1000.0
        stufe += 1

    # Drei bedeutsame Stellen: 1.23M, 12.3M, 123M. Damit ist jede Zahl gleich
    # breit, und eine Spalte im Koloniebildschirm bleibt eine Spalte.
    var text := ""
    if rest < 10.0:
        text = "%.2f" % rest
    elif rest < 100.0:
        text = "%.1f" % rest
    else:
        text = "%.0f" % rest
    return ("-" if negativ else "") + text + KUERZEL[stufe]
