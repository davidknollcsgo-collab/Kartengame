# ARKANWETT – Regeln der digitalen Umsetzung

Diese Datei beschreibt die Regeln so, wie die App sie tatsächlich rechnet. Das
Spieldesign in der [README](../README.md) bleibt die Vorlage; wo eine Regel für
eine spielbare 1-gegen-1-App präzisiert oder angepasst werden musste, steht das
hier ausdrücklich unter [Abweichungen](#abweichungen-vom-design-dokument).

---

## Startwerte

| Wert | Betrag |
|---|---|
| Lebenspunkte | 20 |
| Energie-Chips | 20 |
| Deck | 40 Karten (22 Wesen, 10 Zauber, 6 Fallen, 2 Schicksalskarten) |
| Starthand | 5 Karten, Handlimit 7 |
| Nachschub je Runde (ab Runde 2) | +2 Chips, +1 Karte |
| Wesen-Zone | 3 Plätze |
| Fallen-Zone | 2 Plätze |

Beschworene Wesen bleiben über Runden hinweg im Feld, bis sie zerstört werden.
Ist das Deck leer, wird die Ablage neu gemischt.

---

## Rundenablauf

### 1. Einsatzphase

Beide Spieler handeln abwechselnd, Startspieler wechselt jede Runde:

- **Schieben** – nur wenn kein Einsatz offensteht
- **Setzen / Erhöhen** – Chips wandern in den Pot
- **Mitgehen** – gleicht den Einsatz aus; reichen die Chips nicht, gilt es als All-in
  (nicht gedeckte Chips gehen an den Erhöher zurück)
- **Aussteigen** – der Gegner erhält den Pot, der Aussteiger verliert 2 LP

Der finale Einsatz bestimmt den **Kampf-Multiplikator**:

```
Multiplikator = 1 + (Einsatz ÷ 3), abgerundet, höchstens ×4
```

Einsatz 0–2 → ×1 · 3–5 → ×2 · 6–8 → ×3 · ab 9 → ×4

### 2. Beschwörungsphase

Erst der Startspieler, dann der Gegner. Alles wird aus demselben Chip-Pool
bezahlt, mit dem auch gesetzt wird:

- **Wesen** – Kosten = Stufe ÷ 2, aufgerundet
- **Zauber** – sofortiger, offener Effekt
- **Fallen** – verdeckt gelegt
- **Schicksalskarten** – teuer, stark, mit Preis

### 3. Schicksalsphase

Die offenen Wesen beider Felder werden auf Schicksalshände geprüft. Die Boni
wirken auf die unmittelbar folgende Kampfphase.

### 4. Kampfphase

Zuerst lösen alle gelegten Fallen aus, danach treffen die Wesen **spaltenweise**
aufeinander (Platz 1 gegen Platz 1 usw.). Beide Seiten schlagen gleichzeitig.

**Effektiver ANG** eines Wesens:

```
ANG + Zaubereffekte + Schicksalshand-Boni + Fähigkeitsboni + Elementvorteil (+400)
```

**Effektiver VER**: `VER + Zaubereffekte + Fähigkeitsboni`

Ein Wesen wird zerstört, wenn der gegnerische ANG seinen VER übersteigt — auch
dann, wenn der Überschuss für keinen Lebenspunkt reicht.

**Schaden auf Lebenspunkte**:

```
Rohschaden  = Summe über alle Spalten:
                besetzte Spalte  → ANG − VER (mindestens 0)
                leere Gegenspalte → ANG ÷ 2 (Direktangriff)

LP-Schaden  = (Rohschaden ÷ 400, abgerundet) × Multiplikator
              ×2 bei Schattenlicht
              halbiert (aufgerundet) bei gegnerischem Spiegelschild
```

Die Zeitfalle senkt den Multiplikator des Gegners für diese Runde um 1
(mindestens ×1).

### 5. Auswertung

- Kosten von Schicksalskarten werden fällig (z. B. Pakt des Abgrunds: 3 LP)
- Der Pot geht an den Spieler mit dem höheren LP-Schaden; bei Gleichstand
  bekommt jeder seinen Einsatz zurück
- Temporäre Kampfwerte verfallen, überlebende Wesen bleiben im Feld

---

## Elementsystem

```
🔥 Feuer → 🪨 Erde → 🌪️ Luft → 💧 Wasser → 🔥 Feuer      (jedes schlägt das nächste)
☀️ Licht ⇄ 🌙 Schatten                                   (neutral zueinander, überlegen allen anderen)
```

Ein Elementvorteil gibt **+400 ANG** im Schlagabtausch.

---

## Schicksalshände

| Hand | Bedingung | Effekt |
|---|---|---|
| Elementar-Paar | 2 Wesen gleichen Elements | +200 ANG auf die Wesen dieses Elements |
| Stufen-Straße | 3 Wesen mit lückenlos aufsteigenden Stufen | nächste Wesen-Beschwörung kostenlos |
| Element-Flush | alle 3 Feldwesen teilen ein Element | gegnerische Fallen diese Runde deaktiviert |
| Vollbund | Drilling gleicher Stufe mit mindestens einem Elementpaar | 5 Chips vom Gegner-Pool |
| Schattenlicht | Licht- und Schattenwesen gleichzeitig im Feld | doppelter Kampfschaden |

---

## Wesen-Fähigkeiten

| Fähigkeit | Wirkung |
|---|---|
| Bei Beschwörung: ziehe 1 Karte | Funkengeist, Quellnymphe, Windläufer, Lichtherold |
| Bei Beschwörung: +2 Chips | Nebelkoi, Lehmspäher, Wolkenschmied |
| Bei Beschwörung: 1 LP Schaden | Magmatitan, Nachtmahr, Aurorafürst |
| Bollwerk: +200 VER je weiterem eigenen Wesen | Wurzelgolem, Erzkoloss |
| Jäger: +300 ANG gegen niedrigere Stufen | Aschewolf, Abyssalschlange, Orkanserpent, Schattenpirscher |
| Zoll: Gegner zahlt 1 Chip extra je Beschwörung | Bergvogt, Leerenfürst |

---

## Gewinnbedingungen

Ein Spieler gewinnt, sobald **eine** davon eintritt:

1. Die Lebenspunkte des Gegners erreichen 0.
2. Der Gegner startet eine Runde ohne Chips und kann die Einsatzphase nicht
   mehr bestreiten. Geprüft wird **vor** dem Nachschub — sonst könnte niemand
   je ausbluten.

Fallen beide gleichzeitig auf 0 LP, endet das Duell unentschieden.

---

## Abweichungen vom Design-Dokument

| Punkt | Design-Dokument | Umsetzung und Grund |
|---|---|---|
| Reihenfolge Schicksal/Kampf | Schicksalsphase nach der Kampfphase | Schicksalshände werden **vor** dem Kampf ermittelt. Ihre Effekte („+2 ANG", „doppelter Schaden in der Kampfphase") wirken auf den Kampf und wären danach wirkungslos. |
| Vollbund | Paar + Drilling (5 Karten) | Die Wesen-Zone hat 3 Plätze, ein 5-Karten-Blatt ist unmöglich. Ersatz: Drilling gleicher Stufe, in dem mindestens zwei Wesen ein Element teilen. |
| Elementar-Paar-Bonus | „+2 ANG" | +200 ANG — die Kartenwerte liegen im Tausenderbereich (ANG 1600 im Beispiel), „+2" wäre wirkungslos. |
| Anzahl Elemente | „Fünf Elemente in einem Kreislauf" | Der Kreislauf im Dokument nennt vier (Feuer, Erde, Luft, Wasser); umgesetzt sind diese vier plus Licht und Schatten. |
| Schadensumrechnung | „Schaden = (ANG − VER) × Multiplikator" | Zusätzlich geteilt durch 400, sonst würde ein einziger Treffer bei 20 LP alles beenden. Direktangriffe zählen nur zur Hälfte. |
| Fallen-Auslösung | „lösen bei einer Bedingung aus" | Alle gelegten Fallen lösen zu Beginn der Kampfphase aus. Individuelle Auslösebedingungen wären in einer Ein-Knopf-Oberfläche kaum vermittelbar. |
| Chip-Nachschub | nicht spezifiziert | +2 Chips pro Runde. Ohne Nachschub endet jedes Duell in wenigen Runden an leeren Pools. |
| Spieleranzahl | 2, erweiterbar auf 4 („Arena-Modus") | Umgesetzt ist 1 gegen 1 gegen die KI. |
