// Der eigentliche Wächter: sieht täglich nach, welche Kündigungsfristen in
// Sichtweite sind, legt Erinnerungen an und verschickt eine Sammelmail.

import { heute, plusTage, istVor, tageBis } from "../fachlogik/datum.ts";
import { bewerteVertrag } from "../fachlogik/fristen.ts";
import { datumKurz, euro, tageInWorten } from "../fachlogik/formate.ts";
import type { Vertrag } from "../fachlogik/typen.ts";
import { zuOrganisation, zuVertrag, type Db, type OrganisationZeile, type VertragZeile } from "./datenbank.ts";
import type { Umgebung } from "./umgebung.ts";
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
    }

    protokoll?.info(
        `Fristenlauf für ${basis}: ${geprueft} Verträge geprüft, ${neue} Erinnerungen, ${mails} Mails.`,
    );
    return { geprueft, neueErinnerungen: neue, versendeteMails: mails };
}

export function baueSammelmail(
    organisation: string,
    eintraege: { vertrag: Vertrag; stichtag: string; tageBisStichtag: number }[],
    basisAdresse: string,
): { betreff: string; inhalt: string } {
    const dringendste = eintraege[0];
    const betreff =
        eintraege.length === 1 && dringendste
            ? `Kündigungsfrist: ${dringendste.vertrag.bezeichnung} — Stichtag ${datumKurz(dringendste.stichtag)}`
            : `${eintraege.length} Kündigungsfristen im Blick behalten`;

    const zeilen = eintraege.map((e) => {
        const kosten = e.vertrag.betragCent > 0 ? ` — ${euro(e.vertrag.betragCent)}` : "";
        const anbieter = e.vertrag.anbieter ? ` (${e.vertrag.anbieter})` : "";
        return [
            `• ${e.vertrag.bezeichnung}${anbieter}${kosten}`,
            `  Kündigung muss bis ${datumKurz(e.stichtag)} zugehen — ${tageInWorten(e.tageBisStichtag)}.`,
            `  ${basisAdresse}/vertraege/${e.vertrag.id}`,
        ].join("\n");
    });

    const inhalt = [
        `Guten Tag,`,
        ``,
        `für ${organisation} stehen folgende Kündigungsfristen an:`,
        ``,
        ...zeilen,
        ``,
        `Wer nichts unternimmt, verlängert die betroffenen Verträge automatisch.`,
        ``,
        `Übersicht: ${basisAdresse}`,
        ``,
        `— Vertragsfristen-Wächter`,
    ].join("\n");

    return { betreff, inhalt };
}
