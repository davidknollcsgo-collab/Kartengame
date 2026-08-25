// Einstellungen kommen aus Umgebungsvariablen; ohne gesetzte Werte läuft der
// Wächter mit vernünftigen Vorgaben lokal los.

import { randomBytes } from "node:crypto";

function zahl(wert: string | undefined, vorgabe: number): number {
    const n = Number(wert);
    return Number.isFinite(n) && n > 0 ? n : vorgabe;
}

export interface Umgebung {
    hafen: number;
    adresse: string;
    datenbankDatei: string;
    /** Basisadresse für Links in Erinnerungsmails. */
    basisAdresse: string;
    /** SMTP-Verbindung, z. B. smtps://nutzer:kennwort@mail.example:465 */
    smtpUrl: string | null;
    absender: string;
    /** Wie oft der Planer nach fälligen Erinnerungen sieht (Minuten). */
    planerTaktMinuten: number;
    sitzungsdauerTage: number;
    /** Setzt beim Start Demo-Daten auf, wenn die Datenbank leer ist. */
    demodaten: boolean;
    entwicklung: boolean;
}

export function leseUmgebung(quelle: NodeJS.ProcessEnv = process.env): Umgebung {
    return {
        hafen: zahl(quelle.PORT, 4000),
        adresse: quelle.HOST ?? "127.0.0.1",
        datenbankDatei: quelle.DATENBANK ?? "daten/waechter.sqlite",
        basisAdresse: (quelle.BASIS_ADRESSE ?? "http://localhost:5173").replace(/\/+$/, ""),
        smtpUrl: quelle.SMTP_URL ?? null,
        absender: quelle.ABSENDER ?? "Vertragsfristen-Wächter <waechter@localhost>",
        planerTaktMinuten: zahl(quelle.PLANER_TAKT_MINUTEN, 60),
        sitzungsdauerTage: zahl(quelle.SITZUNGSDAUER_TAGE, 30),
        demodaten: quelle.DEMODATEN === "1" || quelle.DEMODATEN === "true",
        entwicklung: (quelle.NODE_ENV ?? "development") !== "production",
    };
}

/** Kennung für Kalenderadressen und Sitzungen. */
export function schluessel(bytes = 24): string {
    return randomBytes(bytes).toString("base64url");
}
