# Lizenzlotse

Findet ungenutzte und zu große Microsoft-365-Lizenzen und beziffert sie in Euro.

Das Problem ist unspektakulär und teuer: In Microsoft 365 stehen die
Lizenzzuweisung und die tatsächliche Nutzung in zwei getrennten Listen, und es
gibt keine eingebaute Warnung, wenn ein lizenziertes Konto verwaist. Wer es
trotzdem wissen will, exportiert zwei Listen und führt sie in Excel zusammen.
Der Lotse macht genau das — nur jeden Monat und mit einem Betrag am Ende.

## Was er findet

| Befund | Beispiel |
|---|---|
| Gesperrtes Konto mit Lizenz | Ausgeschieden, Anmeldung blockiert, Lizenz läuft weiter |
| Nie genutzte Lizenz | Konto vor Monaten angelegt, nie eine Aktivität |
| Seit Langem inaktiv | Letzte Aktivität vor über 90 Tagen |
| Gekauft, nicht zugewiesen | Sieben Plätze im Regal, niemand hat sie |
| Doppelt lizenziert | E3 und Exchange Online gleichzeitig |
| Ungenutztes Zusatzprodukt | Copilot zugewiesen, seit dem Rollout nie benutzt |
| Zu großer Plan | Business Premium, aber nur E-Mail und Teams in Gebrauch |

Jeder Befund hat eine Begründung, eine Empfehlung und einen Betrag je Monat
und Jahr. Die Summe wird **getrennt ausgewiesen**: was ohne Rückfrage zu heben
ist, und was erst zu prüfen ist. Die erste Zahl geht in den Bericht an die
Geschäftsführung — sie muss halten.

## Loslegen

```bash
cd lizenzlotse
npm install
npm run dev            # Server auf :4001, Oberfläche auf :5174
```

Konto anlegen, dann entweder Beispielbestand auswerten oder drei Ausgaben aus
dem Adminportal einlesen:

1. **Benutzerliste** — `Benutzer → Aktive Benutzer → Benutzer exportieren`
2. **Nutzungsbericht** — `Berichte → Nutzung → Microsoft 365 → Aktive Benutzer`
3. **Abonnements** — `Abrechnung → Ihre Produkte`

Für den Dauerbetrieb:

```bash
npm run build && npm start    # ein Prozess, liefert auch die Oberfläche aus
```

### Einstellungen

| Variable | Bedeutung |
|---|---|
| `PORT`, `HOST` | wo der Server lauscht (Vorgabe `127.0.0.1:4001`) |
| `DATENBANK` | Pfad der SQLite-Datei (Vorgabe `daten/lotse.sqlite`) |
| `BASIS_ADRESSE` | öffentliche Adresse der Oberfläche |
| `SITZUNGSDAUER_TAGE` | Gültigkeit einer Anmeldung (Vorgabe 14) |
| `MAX_DATEIGROESSE_MB` | Obergrenze je hochgeladener Datei (Vorgabe 20) |

## Warum ohne Zugriff auf den Mandanten

Der Einstieg über CSV ist keine Notlösung, sondern Absicht. Ein Global Admin
soll einer unbekannten Anwendung keinen Zugriff auf seinen Mandanten geben
müssen, um zu sehen, ob sich das Werkzeug lohnt. Die spätere Anbindung über
Microsoft Graph (`Reports.Read.All`, `User.Read.All`,
`Organization.Read.All` — ausschließlich lesend) ersetzt nur die Beschaffung
der Daten; gerechnet wird identisch.

Technisch wichtig dabei: Nutzungsdaten kommen aus dem Bericht
`getOffice365ActiveUserDetail`, der **ohne Entra ID P1** funktioniert. Die
naheliegendere Eigenschaft `signInActivity` verlangt P1 und liefert sonst
`null` — damit wäre der halbe Mittelstand ausgeschlossen.

## Wie gerechnet wird

Die Regeln stehen in `src/fachlogik/analyse.ts`, ohne Datenbank- und Netzbezug.
Zwei Grundsätze ziehen sich durch:

**Kein Befund zählt doppelt.** Ein gesperrtes Konto ist nicht zusätzlich
inaktiv; ein doppelt lizenziertes Konto bekommt keine Abstufungsempfehlung
obendrauf.

**Lieber zu wenig ausweisen als zu viel.** Eine Abstufung wird nur
vorgeschlagen, wenn mindestens ein Dienst des laufenden Plans nachweislich
ungenutzt ist. Business Premium und Business Standard schalten dieselben
Dienste frei und unterscheiden sich in Verwaltung und Sicherheit — davon weiß
kein Nutzungsbericht etwas, also wird dort auch nichts empfohlen. Ohne diese
Bedingung hätte die erste Fassung 46 statt 9 Abstufungen gemeldet und den
größten Teil der Ersparnis erfunden.

Preise sind Richtwerte (Listenpreise, Stand siehe `PREISSTAND` in
`src/fachlogik/skus.ts`) und je Mandant überschreibbar. Kaum ein Unternehmen
zahlt Listenpreis; ein Bericht mit fremden Preisen ist wertlos.

## Aufbau

```
src/fachlogik/   Analyse, SKU-Katalog, CSV-Import — reine Funktionen
src/server/      Fastify, SQLite, Sitzungen, Rollen, Verlauf
src/web/         React-Oberfläche
```

Ein **Mandant** ist die Microsoft-365-Umgebung, die überwacht wird. Eine
**Organisation** ist der Kunde des Lotsen und kann beliebig viele Mandanten
haben — so arbeiten Systemhäuser mit einem Konto für alle ihre Kunden.

Der Bearbeitungsstand eines Befundes hängt am Befundschlüssel, nicht an der
Auswertung. Ein „bewusst behalten" überlebt deshalb den nächsten Import — sonst
wäre das Werkzeug ein Berichtsgenerator und keine Arbeitsliste.

## Sicherheit

- Kennwörter mit scrypt, mindestens zwölf Zeichen
- Sitzungen als zufällige Marke, gespeichert wird nur ihr SHA-256-Hash;
  Keks httpOnly, SameSite=Lax, `Secure` außerhalb der Entwicklung
- Rollen: Inhaber ändert Mandanten, Preise und Zugänge; Mitglied liest und
  hakt Befunde ab
- Mandantentrennung durch die Abfrage selbst — jede Anweisung filtert nach der
  Organisation aus der Sitzung, fremde Daten werden gar nicht erst gefunden
- Alle SQL-Anweisungen vorbereitet, alle Eingaben durch Zod geprüft
- Ratenbremse auf Anmeldung und Registrierung
- Verlauf protokolliert, wer was geändert hat
- Beim Anmelden wird auch ohne Treffer gehasht, damit die Antwortzeit nicht
  verrät, ob es die Adresse gibt

Offen für die Produktion: Verschlüsselung der Datenbankdatei im Ruhezustand,
Sicherungskonzept, Zwei-Faktor-Anmeldung, Auftragsverarbeitungsvertrag.

## Tests

```bash
npm test          # 66 Tests
npm run pruefen   # zusätzlich Typprüfung
```

Abgedeckt sind alle sieben Regeln samt Doppelzählungs-Sperren, die
Grenzfälle des CSV-Imports (deutsche und englische Ausgaben, Semikolon und
Komma, Anführungszeichen, BOM), Rollentrennung, Mandantentrennung und der
Nachweis, dass der Bearbeitungsstand eine neue Auswertung überlebt.

## Was noch fehlt

- Anbindung über Microsoft Graph statt CSV-Upload
- Monatlicher Bericht per E-Mail und Verlaufskurve über mehrere Monate
- Schreibende Aktionen (Lizenz direkt entziehen) — bewusst zuletzt
- Weitere Anbieter: Google Workspace, Adobe, Atlassian
