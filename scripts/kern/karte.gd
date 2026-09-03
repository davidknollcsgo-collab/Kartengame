class_name Karte
extends RefCounted

## Was der Spieler von der Karte schon gesehen hat.
##
## **Der Graben liegt im Dunkeln, bis jemand hinfaehrt.** Das ist nicht bloss
## ein Effekt: ohne ihn ist eine grosse Karte nur eine grosse Flaeche, auf der
## ueberall dasselbe steht. Mit ihm ist jede Fahrt in eine Richtung eine
## Entscheidung, und der Grund, ueberhaupt vom Fleck zu kommen.
##
## Gerastert, nicht als Bild. Ein Nebelbild waere eine Textur von tausend mal
## tausend Punkten, die jedes Bild neu hochgeladen wird; ein Raster aus
## `ZELLE` grossen Feldern ist ein Byte je Feld und wird nur gelesen. Bei
## 1500 Einheiten Feldradius sind das gut zweitausend Bytes.
##
## Reine Rechnung, keine Szenen- und keine Autoload-Bezuege.

## Kantenlaenge eines Rasterfeldes.
##
## **Gross genug, dass es billig bleibt, klein genug, dass die Kante nicht
## auffaellt.** Bei 90 Einheiten ist ein Feld auf dem Schirm etwa ein
## Zehntel der Breite - Bewuchs wird darin nicht einzeln sichtbar, sondern
## fleckweise, und genau so soll sich ein Lichtkegel im Dunkeln anfuehlen.
const ZELLE := 90.0

## Wie weit die Fahrt aufdeckt. **Kleiner als die Sicht** (`Rundum.SICHT`,
## 900): sonst waere alles, was man sehen kann, schon bekannt, und das
## Aufdecken haette keinen Ort. So bleibt am Rand des Bildes Dunkelheit, in
## die man hineinfaehrt.
const AUFDECK_RADIUS := 380.0

var seite := 0
var bekannt := PackedByteArray()
var _weite := 0.0

## Wieviele Felder ueberhaupt aufzudecken sind, und wieviele es schon sind.
##
## **Mitgezaehlt, nicht nachgezaehlt.** `anteil()` wird je Bild vom HUD
## gefragt; ein Durchlauf ueber zwoelfhundert Felder mit einer Wurzel je Feld
## ist dafuer kein Preis, den man zahlen muss, wenn zwei Zaehler dasselbe
## sagen.
var _moeglich := 0
var _offen := 0


func _init(weite := 0.0) -> void:
    _weite = maxf(1.0, weite)
    seite = int(ceil(_weite * 2.0 / ZELLE)) + 1
    bekannt.resize(seite * seite)
    bekannt.fill(0)
    for i in bekannt.size():
        if mitte(i).length() <= _weite:
            _moeglich += 1


## Die Rasterkoordinaten zu einem Ort. Kann ausserhalb liegen - wer sie
## weiterreicht, fragt `index()`.
func raster(ort: Vector2) -> Vector2i:
    return Vector2i(int(floor((ort.x + _weite) / ZELLE)),
        int(floor((ort.y + _weite) / ZELLE)))


## Der Feldindex zu Rasterkoordinaten - oder -1, wenn sie ausserhalb liegen.
func index(zelle: Vector2i) -> int:
    if zelle.x < 0 or zelle.y < 0 or zelle.x >= seite or zelle.y >= seite:
        return -1
    return zelle.y * seite + zelle.x


## Das Rasterfeld zu einem Ort - oder -1, wenn er ausserhalb liegt.
func feld(ort: Vector2) -> int:
    return index(raster(ort))


## Die Mitte eines Rasterfeldes in Weltkoordinaten.
func mitte(i: int) -> Vector2:
    return mitte_von(Vector2i(i % seite, i / seite))


func mitte_von(zelle: Vector2i) -> Vector2:
    return Vector2((float(zelle.x) + 0.5) * ZELLE - _weite,
        (float(zelle.y) + 0.5) * ZELLE - _weite)


func ist_bekannt(ort: Vector2) -> bool:
    var i := feld(ort)
    return i >= 0 and bekannt[i] != 0


## Ob ein Rasterfeld bekannt ist. Ausserhalb gilt als unbekannt - der Rand
## der Welt bleibt schwarz, und das ist richtig so.
func zelle_bekannt(zelle: Vector2i) -> bool:
    var i := index(zelle)
    return i >= 0 and bekannt[i] != 0


## Deckt alles im Umkreis auf. Gibt zurueck, wieviele Felder **neu** waren -
## daran haengt, ob es sich lohnt, etwas dafuer zu geben.
func decke_auf(ort: Vector2, radius := AUFDECK_RADIUS) -> int:
    var neu := 0
    var r2 := radius * radius
    var von := raster(ort - Vector2.ONE * radius)
    var bis := raster(ort + Vector2.ONE * radius)
    for sy in range(maxi(0, von.y), mini(seite - 1, bis.y) + 1):
        for sx in range(maxi(0, von.x), mini(seite - 1, bis.x) + 1):
            var i := sy * seite + sx
            if bekannt[i] != 0:
                continue
            # Gegen die Mitte des Feldes messen, nicht gegen die Ecke: sonst
            # wird ein Feld schon bekannt, wenn nur seine Ecke im Umkreis
            # liegt, und der aufgedeckte Fleck ist eckiger als der Kegel.
            var m := mitte(i)
            if m.distance_squared_to(ort) <= r2:
                bekannt[i] = 1
                neu += 1
                if m.length() <= _weite:
                    _offen += 1
    return neu


## Wieviel der Karte bekannt ist, von 0 bis 1.
##
## Gezaehlt werden nur Felder **im Feld** - die Ecken des Rasters liegen
## ausserhalb der Kreisscheibe und koennen nie aufgedeckt werden. Ohne diese
## Unterscheidung stuende die Anzeige bei vollstaendig erkundeter Karte bei
## achtundsiebzig Prozent, und der Spieler suchte den Rest.
func anteil() -> float:
    return float(_offen) / float(maxi(1, _moeglich))
