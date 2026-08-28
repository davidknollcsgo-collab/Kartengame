// Der eigentliche Wächter: sieht täglich nach, welche Kündigungsfristen in
// Sichtweite sind, legt Erinnerungen an und verschickt eine Sammelmail.

import { heute, plusTage, istVor, tageBis } from "../fachlogik/datum.ts";
import { bewerteVertrag } from "../fachlogik/fristen.ts";
import type { Vertrag } from "../fachlogik/typen.ts";
import { zuOrganisation, zuVertrag, type Db, type OrganisationZeile, type VertragZeile } from "./datenbank.ts";
import type { Umgebung } from "./umgebung.ts";
import { baueSammelmail } from "../fachlogik/mailtext.ts";
import { versende } from "./versand.ts";

export interface Planungsergebnis {
    geprueft: number;
    neueErinnerungen: number;
    versendeteMails: number;
}

interface NeueErinnerung {
    id: string;
    vertrag: Vertrag;
    stichtag: string;
    vorlaufTage: number;
    tageBisStichtag: number;
}

/**
 * Legt für alle fälligen Vorlaufstufen Erinnerungen an und verschickt je
 * Organisation höchstens eine Sammelmail pro Lauf. Der Lauf ist idempotent:
 * ein zweiter Aufruf am selben Tag erzeugt nichts Neues.
 */
export async function planeErinnerungen(
    db: Db,
    umgebung: Umgebung,
    basis: string = heute(),
    protokoll?: { info(n: string): void; warn(n: string): void },
): Promise<Planungsergebnis> {
    const organisationen = db
        .prepare(`SELECT * FROM organisationen`)
        .all() as OrganisationZeile[];
    let geprueft = 0;
    let neue = 0;
    let mails = 0;

    for (const zeile of organisationen) {
        const organisation = zuOrganisation(zeile);
        const vorlauf = organisation.erinnerungsvorlauf.length
            ? organisation.erinnerungsvorlauf
            : [90, 30, 14, 3];
        const vertraege = (
            db
                .prepare(`SELECT * FROM vertraege WHERE organisation_id = ? AND status = 'aktiv'`)
                .all(organisation.id) as VertragZeile[]
        ).map(zuVertrag);
        geprueft += vertraege.length;

        const erzeugt: NeueErinnerung[] = [];
        const einfuegen = db.prepare(
            `INSERT OR IGNORE INTO erinnerungen
                (id, organisation_id, vertrag_id, stichtag, vorlauf_tage, faellig_am, erzeugt_am)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
        );

        for (const vertrag of vertraege) {
            const bewertung = bewerteVertrag(vertrag, basis);
            const stichtag = bewertung.ueberwachungsdatum;
            if (!stichtag || istVor(stichtag, basis)) continue;
            for (const tage of vorlauf) {
                const faellig = plusTage(stichtag, -tage);
                if (istVor(basis, faellig)) continue; // noch nicht so weit
                const id = crypto.randomUUID();
                const ergebnis = einfuegen.run(
                    id,
                    organisation.id,
                    vertrag.id,
                    stichtag,
                    tage,
                    faellig,
                    new Date().toISOString(),
                );
                if (ergebnis.changes > 0) {
                    erzeugt.push({
                        id,
                        vertrag,
                        stichtag,
                        vorlaufTage: tage,
                        tageBisStichtag: tageBis(basis, stichtag),
                    });
                }
            }
        }

        if (erzeugt.length === 0) continue;
        neue += erzeugt.length;

        // Mehrere Vorlaufstufen desselben Vertrags ergeben nur einen Eintrag
        // in der Mail — sonst steht ein frisch angelegter Vertrag viermal drin.
        const jeVertrag = new Map<string, NeueErinnerung>();
        for (const eintrag of erzeugt) {
            const bisher = jeVertrag.get(eintrag.vertrag.id);
            if (!bisher || eintrag.vorlaufTage < bisher.vorlaufTage) {
                jeVertrag.set(eintrag.vertrag.id, eintrag);
            }
        }
        const eintraege = [...jeVertrag.values()].sort(
            (a, b) => a.tageBisStichtag - b.tageBisStichtag,
        );

        const empfaenger = [
            ...(db
                .prepare(`SELECT email FROM benutzer WHERE organisation_id = ?`)
                .all(organisation.id) as { email: string }[]).map((b) => b.email),
            ...organisation.verteiler,
        ];
        const nachricht = baueSammelmail(organisation.name, eintraege, umgebung.basisAdresse);
        const ergebnis = await versende(
            db,
            organisation.id,
            { empfaenger: [...new Set(empfaenger)], betreff: nachricht.betreff, inhalt: nachricht.inhalt },
            umgebung,
            protokoll,
        );
        if (ergebnis.versendet) mails += 1;

        const jetzt = new Date().toISOString();
        const markieren = db.prepare(`UPDATE erinnerungen SET versendet_am = ? WHERE id = ?`);
        for (const eintrag of erzeugt) markieren.run(jetzt, eintrag.id);
        ueberholteSchliessen(db, organisation.id, jetzt);
    }

    protokoll?.info(
        `Fristenlauf für ${basis}: ${geprueft} Verträge geprüft, ${neue} Erinnerungen, ${mails} Mails.`,
    );
    return { geprueft, neueErinnerungen: neue, versendeteMails: mails };
}

/**
 * Schließt Erinnerungen, die von einer dringlicheren zum selben Stichtag
 * überholt wurden. Sonst stehen für einen Vertrag vier offene Einträge —
 * 90, 30, 14 und 3 Tage Vorlauf —, obwohl es nur eine Frist zu erledigen gibt.
 */
export function ueberholteSchliessen(db: Db, organisationId: string, jetzt: string): void {
    db.prepare(
        `UPDATE erinnerungen SET erledigt_am = ?
         WHERE organisation_id = ? AND erledigt_am IS NULL AND EXISTS (
             SELECT 1 FROM erinnerungen juenger
             WHERE juenger.vertrag_id = erinnerungen.vertrag_id
               AND juenger.stichtag = erinnerungen.stichtag
               AND juenger.erledigt_am IS NULL
               AND juenger.vorlauf_tage < erinnerungen.vorlauf_tage
         )`,
    ).run(jetzt, organisationId);
}
