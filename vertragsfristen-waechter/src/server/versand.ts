// Mailversand. Jede Nachricht landet zuerst im Postausgang der Datenbank und
// wird erst dann verschickt. Ohne SMTP-Zugang bleibt sie dort liegen und ist
// in der Oberfläche einsehbar — so lässt sich der Wächter vollständig
// ausprobieren, bevor irgendwo Zugangsdaten hinterlegt sind.

import type { Db } from "./datenbank.ts";
import type { Umgebung } from "./umgebung.ts";

export interface Nachricht {
    empfaenger: string[];
    betreff: string;
    inhalt: string;
}

export interface Versandergebnis {
    id: string;
    versendet: boolean;
    fehler: string | null;
}

let transportZwischenspeicher: unknown | null = null;

async function holeTransport(umgebung: Umgebung): Promise<{
    sendMail(optionen: Record<string, unknown>): Promise<unknown>;
} | null> {
    if (!umgebung.smtpUrl) return null;
    if (transportZwischenspeicher) {
        return transportZwischenspeicher as { sendMail(o: Record<string, unknown>): Promise<unknown> };
    }
    const nodemailer = await import("nodemailer");
    const transport = nodemailer.createTransport(umgebung.smtpUrl);
    transportZwischenspeicher = transport;
    return transport as unknown as { sendMail(o: Record<string, unknown>): Promise<unknown> };
}

export async function versende(
    db: Db,
    organisationId: string,
    nachricht: Nachricht,
    umgebung: Umgebung,
    protokoll?: { warn(nachricht: string): void },
): Promise<Versandergebnis> {
    const id = crypto.randomUUID();
    const jetzt = new Date().toISOString();
    db.prepare(
        `INSERT INTO postausgang (id, organisation_id, empfaenger, betreff, inhalt, erzeugt_am)
         VALUES (?, ?, ?, ?, ?, ?)`,
    ).run(id, organisationId, nachricht.empfaenger.join(", "), nachricht.betreff, nachricht.inhalt, jetzt);

    const transport = await holeTransport(umgebung);
    if (!transport || nachricht.empfaenger.length === 0) {
        return { id, versendet: false, fehler: null };
    }
    try {
        await transport.sendMail({
            from: umgebung.absender,
            to: nachricht.empfaenger.join(", "),
            subject: nachricht.betreff,
            text: nachricht.inhalt,
        });
        db.prepare(`UPDATE postausgang SET versendet_am = ? WHERE id = ?`).run(
            new Date().toISOString(),
            id,
        );
        return { id, versendet: true, fehler: null };
    } catch (fehler) {
        const meldung = fehler instanceof Error ? fehler.message : String(fehler);
        db.prepare(`UPDATE postausgang SET fehler = ? WHERE id = ?`).run(meldung, id);
        protokoll?.warn(`Erinnerung konnte nicht versendet werden: ${meldung}`);
        return { id, versendet: false, fehler: meldung };
    }
}

/** Nur für Tests: erzwingt beim nächsten Versand einen frischen Transport. */
export function transportZuruecksetzen(): void {
    transportZwischenspeicher = null;
}
