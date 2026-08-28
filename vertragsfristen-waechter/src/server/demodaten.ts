// Setzt den Beispielbestand aus der Fachlogik in die Datenbank.

import { beispielvertraege } from "../fachlogik/beispiele.ts";
import type { IsoDatum } from "../fachlogik/datum.ts";
import { protokolliere, type Db } from "./datenbank.ts";

/** Legt den Beispielbestand an und liefert die Anzahl neuer Verträge. */
export function setzeDemodaten(db: Db, organisationId: string, basis: IsoDatum): number {
    const einfuegen = db.prepare(
        `INSERT INTO vertraege (
            id, organisation_id, bezeichnung, anbieter, kategorie, vertragsnummer, abteilung,
            ansprechpartner, beginn, laufzeitmodell, erstlaufzeit_monate, verlaengerung_monate,
            kuendigungsfrist_wert, kuendigungsfrist_einheit, kuendigungsfrist_bezug, betrag_cent,
            zahlungsintervall, status, gekuendigt_zum, dokument_link, notizen, erstellt_am, geaendert_am
         ) VALUES (
            @id, @organisationId, @bezeichnung, @anbieter, @kategorie, @vertragsnummer, @abteilung,
            @ansprechpartner, @beginn, @laufzeitmodell, @erstlaufzeitMonate, @verlaengerungMonate,
            @kuendigungsfristWert, @kuendigungsfristEinheit, @kuendigungsfristBezug, @betragCent,
            @zahlungsintervall, @status, @gekuendigtZum, @dokumentLink, @notizen, @jetzt, @jetzt
         )`,
    );
    const jetzt = new Date().toISOString();
    const bestand = beispielvertraege(basis);

    db.transaction(() => {
        for (const vertrag of bestand) {
            einfuegen.run({ ...vertrag, id: crypto.randomUUID(), organisationId, jetzt });
        }
    })();

    protokolliere(db, {
        organisationId,
        aktion: "demodaten",
        beschreibung: `${bestand.length} Beispielverträge angelegt`,
    });
    return bestand.length;
}
