class_name Helden
extends RefCounted

## **Wen man in die Schlacht schickt.**
##
## Vier Klassen, und jede hat **genau eine** Eigenart neben ihrer Startwaffe.
## Das ist keine Sparsamkeit, sondern die Bedingung dafuer, dass eine Klasse
## etwas bedeutet: was einen Helden ausmacht, muss man in der ersten Minute
## merken. Ein Held mit fuenf kleinen Vorteilen fuehlt sich an wie der
## Grundheld mit Rauschen.
##
## **Freigeschaltet wird an Taten, nicht an Sold.** Wer Abwechslung kaufen
## kann, kauft sie am ersten Tag und hat danach nichts mehr vor sich.
##
## Reine Datenschicht: keine Szenen-, keine Autoload-Bezuege.

enum Held { SCHWERT, BOGEN, SPEER, HAMMER }

## Sichtbar, also englisch.
const NAMEN: PackedStringArray = ["Swordsman", "Archer", "Spearman", "Hammerman"]

const LEHREN: PackedStringArray = [
    "Stands where others fall. Begins with the arming sword.",
    "Reaches further than they can. Begins with the crossbow.",
    "Keeps them at spear's length. Begins with the boar spear.",
    "Slow, and it does not matter. Begins with the war hammer.",
]

## Womit er anfaengt. **Eine** Waffe - ohne eine schlaegt man die erste halbe
## Minute gar nichts, mit zweien hat der erste Aufstieg nichts mehr zu sagen.
const STARTWAFFE: PackedInt32Array = [
    Waffen.Art.SCHWERT, Waffen.Art.ARMBRUST, Waffen.Art.SPEER, Waffen.Art.HAMMER,
]

## Die Eigenart, als fuenf Faktoren - aber je Held ist hoechstens einer davon
## ungleich eins (der Hammertraeger zahlt seinen Schaden mit Tempo, und das
## ist der einzige Handel im Satz).
##
## **Die Weite des Bogenschuetzen stand auf 1,30 und tat nichts.** Seine
## Startwaffe ist die Armbrust, und die reicht ohnehin 520 Punkte weit -
## dreissig Prozent mehr auf eine Weite, die schon ueber das ganze Bild geht,
## sind keine Eigenart, sondern eine Zahl. Gemessen war er der einzige Held,
## der die ersten drei Minuten nicht ueberstand, und zwar schon **bevor** es
## die Umzingelung gab: bei einer von drei Saaten fiel er nach 167 Sekunden.
## Mit 1,60 traegt der Faktor, sobald er die zweite Waffe aufnimmt - gemessen
## stieg er von 425 auf 607 Erschlagene und von 210 auf 234 Sekunden.
##
## Hier stand ein **offener Posten**: eine von drei Saaten fiel er vor der
## dritten Minute, und die Armbrust als einzige Startwaffe ohne Flaeche
## (`Waffen.BREITE` null, `ZAHL` eins) galt als Ursache. **Nachgemessen, und
## er ist geschlossen** - nicht durch eine Aenderung an ihm, sondern weil sich
## die Horde geaendert hat (Zusicherung 23): seit sie einander ausweicht,
## steht nichts mehr gestapelt, und eine Flaechenwaffe hat keinen Klumpen
## mehr, den sie der Armbrust voraushaette. Ueber 24 Saaten (180 s, Burg 0):
##
##                  gehalten   Leben am Ende (Median)   erschlagen nach 60 s
##     Swordsman     24/24           50 %                       33
##     Archer        24/24           95 %                       49
##     Spearman      24/24           70 %                       49
##     Hammerman     24/24           67 %                       36
##
## Der Bogenschuetze ist damit am Anfang der sicherste der vier. Wer an der
## Armbrust dreht, misst das zuerst nach.
const LEBEN_FAKTOR: PackedFloat32Array = [1.25, 1.00, 1.00, 1.00]
const WEITE_FAKTOR: PackedFloat32Array = [1.00, 1.60, 1.00, 1.00]
const TEMPO_FAKTOR: PackedFloat32Array = [1.00, 1.00, 1.00, 0.92]
const SCHADEN_FAKTOR: PackedFloat32Array = [1.00, 1.00, 1.00, 1.20]

## **Der Speertraeger haelt sie auf Speereslaenge** - seine Eigenart wirkt auf
## genau einen Wert: die Weite des Speers, und nur des Speers.
##
## Vorher hiess sie "Outpaces the press" und war Tempo (1,12). Gemessen bringt
## Tempo dem Daumen nichts: gepaart bis 300 s gewinnt 1,25 gegen 1,0 genau 2
## bis 4 von 8 Saaten, und mehr Tempo heisst im Gedraenge nur, schneller in die
## Horde zu laufen. Getragen wurde er in Wahrheit von `Waffen.WEITE[SPEER]` =
## 310 - einem Notbehelf, der den Speer fuer **jeden** Helden so lang machte.
## Jetzt steht die Laenge dort, wo sie hingehoert: bei ihm.
##
## Gemessen (Grundweite x Faktor, Speertraeger 24 Saaten / Schwertkaempfer
## 16 / Schwertkaempfer mit Speer allein 8, je 180 bzw. 120 s):
##
##     vorher 310 x 1,00, Tempo 1,12    23-24/24   -       8/8
##     168 x 1,85                       23/24      15/16   4/8
##     210 x 1,50                       23/24      14/16   8/8
##     250 x 1,25                       24/24      16/16   8/8
##
## Nicht `WEITE_FAKTOR`: das ist die Eigenart des Bogenschuetzen, und zwei
## Helden mit derselben Eigenart waeren einer.
const SPEER_FAKTOR: PackedFloat32Array = [1.00, 1.00, 1.25, 1.00]

## Was er tun muss, damit er frei wird. Der erste ist von Anfang an da.
enum Tat { KEINE, ZEIT, ERSCHLAGEN, WARLORD }

const BEDINGUNG: PackedInt32Array = [Tat.KEINE, Tat.ZEIT, Tat.ERSCHLAGEN, Tat.WARLORD]
const SCHWELLE: PackedFloat32Array = [0.0, 240.0, 100.0, 1.0]

const BEDINGUNG_TEXT: PackedStringArray = [
    "",
    "Survive four minutes.",
    "Fell a hundred in one run.",
    "Bring down the Warlord.",
]


static func name_von(h: int) -> String:
    return NAMEN[clampi(h, 0, NAMEN.size() - 1)]


static func lehre_von(h: int) -> String:
    return LEHREN[clampi(h, 0, LEHREN.size() - 1)]


static func startwaffe(h: int) -> int:
    return STARTWAFFE[clampi(h, 0, STARTWAFFE.size() - 1)]


static func leben_faktor(h: int) -> float:
    return LEBEN_FAKTOR[clampi(h, 0, LEBEN_FAKTOR.size() - 1)]


static func weite_faktor(h: int) -> float:
    return WEITE_FAKTOR[clampi(h, 0, WEITE_FAKTOR.size() - 1)]


static func tempo_faktor(h: int) -> float:
    return TEMPO_FAKTOR[clampi(h, 0, TEMPO_FAKTOR.size() - 1)]


static func speer_faktor(h: int) -> float:
    return SPEER_FAKTOR[clampi(h, 0, SPEER_FAKTOR.size() - 1)]


static func schaden_faktor(h: int) -> float:
    return SCHADEN_FAKTOR[clampi(h, 0, SCHADEN_FAKTOR.size() - 1)]


static func bedingung_text(h: int) -> String:
    return BEDINGUNG_TEXT[clampi(h, 0, BEDINGUNG_TEXT.size() - 1)]


## Ist er nach diesen Bestmarken frei?
static func ist_frei(h: int, beste_zeit: float, meiste: int,
        warlord: bool) -> bool:
    var i := clampi(h, 0, BEDINGUNG.size() - 1)
    match BEDINGUNG[i]:
        Tat.ZEIT:
            return beste_zeit >= SCHWELLE[i]
        Tat.ERSCHLAGEN:
            return float(meiste) >= SCHWELLE[i]
        Tat.WARLORD:
            return warlord
        _:
            return true
