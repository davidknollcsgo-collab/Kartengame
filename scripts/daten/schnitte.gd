class_name Schnitte
extends RefCounted

## **Die Linien, auf denen ein Hieb laeuft.**
##
## Das ganze Spiel haengt an einer Frage: *welche Linie kommt und wann?* Ein
## Hieb ist keine Richtung, sondern eine **Achse** - ein Kesa-Schnitt von
## oben rechts nach unten links liegt auf derselben Achse wie sein Gegenzug
## von unten links nach oben rechts. Wer pariert, legt seine Klinge in diese
## Achse; ob er dabei von oben oder von unten kommt, ist gleichgueltig.
##
## Das ist nicht Bequemlichkeit, sondern der Grund, warum das Spiel mit einem
## Daumen funktioniert. Acht Richtungen auf einem Telefon sind acht
## Fehlversuche; vier Achsen sind vier Antworten, und der Abstand zwischen
## zwei benachbarten ist fuenfundvierzig Grad - mehr, als ein Daumen je
## danebenwischt.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Linie {
    SENKRECHT,   ## von oben herab - der Scheitelhieb
    KESA,        ## oben rechts nach unten links
    WAAGERECHT,  ## quer durch den Leib
    GYAKU,       ## oben links nach unten rechts
    STOSS,       ## die Spitze, geradeaus - keine Achse, sondern ein Punkt
}

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = [
    "OVERHEAD", "DIAGONAL", "BODY", "REVERSE", "THRUST",
]

## Was ein Spieler tun muss. Steht im Einstieg und im Bestiarium; eine Regel,
## die man sich erspielen muss, ist keine Regel, sondern eine Falle.
const ANTWORTEN: PackedStringArray = [
    "Swipe up or down.",
    "Swipe along the falling diagonal.",
    "Swipe left or right.",
    "Swipe along the rising diagonal.",
    "Tap. A point is beaten down, not swept aside.",
]

## Der Winkel der Achse im Bild, im Bogenmass, gegen die Waagerechte.
##
## Gezaehlt wird wie in Godot: x nach rechts, y nach **unten**. Die Achse ist
## zweiseitig, also genuegt der Bereich von null bis pi; `abstand()` rechnet
## alles Weitere darauf zurueck.
const WINKEL: PackedFloat32Array = [
    PI * 0.5,    ## senkrecht
    PI * 0.25,   ## kesa: von oben rechts nach unten links
    0.0,         ## waagerecht
    PI * 0.75,   ## gyaku: von oben links nach unten rechts
    PI * 0.5,    ## der Stoss hat keine, steht hier nur der Vollstaendigkeit halber
]

## Die vier Achsen, auf denen gewischt wird. Der Stoss steht bewusst nicht
## darin: er wird getippt, nicht gewischt, und wer ihn in dieselbe Liste
## legt, wuerfelt ihn irgendwann als Wischziel aus.
const GEWISCHT: PackedInt32Array = [
    Linie.SENKRECHT, Linie.KESA, Linie.WAAGERECHT, Linie.GYAKU,
]


static func name_von(l: int) -> String:
    return NAMEN[clampi(l, 0, NAMEN.size() - 1)]


static func antwort_von(l: int) -> String:
    return ANTWORTEN[clampi(l, 0, ANTWORTEN.size() - 1)]


static func ist_stoss(l: int) -> bool:
    return l == Linie.STOSS


## Die Richtung der Achse als Einheitsvektor. Zum Zeichnen der Fuehrungslinie
## und der Klinge - beide fragen **diese** Funktion, damit die gezeigte Linie
## und die geforderte dieselbe ist. Eine Fuehrungslinie, die anders liegt als
## die Pruefung, waere unlernbar.
static func richtung(l: int) -> Vector2:
    var w := WINKEL[clampi(l, 0, WINKEL.size() - 1)]
    return Vector2(cos(w), -sin(w))


## Wie weit ein Wisch von einer Achse entfernt ist, im Bogenmass.
##
## Zweiseitig: ein Wisch nach oben und einer nach unten liegen beide auf der
## senkrechten Achse und haben beide Abstand null. Herauskommt nie mehr als
## ein rechter Winkel - zwei Achsen koennen nicht weiter auseinanderliegen.
static func abstand(l: int, wisch: Vector2) -> float:
    if wisch.length_squared() < 0.0001:
        return PI * 0.5
    var soll := richtung(l)
    # Betrag des Skalarprodukts: die Gegenrichtung zaehlt als dieselbe Achse.
    var d := absf(soll.dot(wisch.normalized()))
    return acos(clampf(d, 0.0, 1.0))


## **Welche Achse ein Wisch meint.**
##
## Hier stand einmal eine Toleranz - ein Wisch galt, wenn er naeher als
## zweiundzwanzig Grad an der Achse lag. Das hat einen Rand, und ein Rand
## hat immer einen von zwei Fehlern: ist die Schwelle zu gross, gehoert eine
## Richtung zu **zwei** Achsen; ist sie zu klein, bleibt zwischen ihnen ein
## **totes Band**, in dem ein sauberer Wisch nichts trifft - und dort sucht
## der Spieler den Fehler bei sich.
##
## Beides verschwindet, wenn man nicht nach einer Schwelle fragt, sondern
## nach der **naechsten** Achse. Jede Richtung gehoert dann genau einer, das
## tote Band gibt es nicht, und es ist eine von Hand gesetzte Zahl weniger
## im Spiel. Wer schlampig wischt, pariert weiterhin die falsche Linie -
## bestraft wird also dasselbe wie vorher, nur ohne Rand.
static func naechste_achse(wisch: Vector2) -> int:
    var beste: int = GEWISCHT[0]
    var naechst := PI
    for l in GEWISCHT:
        var d := abstand(l, wisch)
        if d < naechst:
            naechst = d
            beste = l
    return beste
