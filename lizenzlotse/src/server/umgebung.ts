import { randomBytes } from "node:crypto";

function zahl(wert: string | undefined, vorgabe: number): number {
    const n = Number(wert);
    return Number.isFinite(n) && n > 0 ? n : vorgabe;
}

export interface Umgebung {
    hafen: number;
    adresse: string;
    datenbankDatei: string;
    basisAdresse: string;
    sitzungsdauerTage: number;
    /** Obergrenze für hochgeladene Ausgaben. */
    maxDateigroesseMb: number;
    entwicklung: boolean;
}

export function leseUmgebung(quelle: NodeJS.ProcessEnv = process.env): Umgebung {
    return {
        hafen: zahl(quelle.PORT, 4001),
        adresse: quelle.HOST ?? "127.0.0.1",
        datenbankDatei: quelle.DATENBANK ?? "daten/lotse.sqlite",
        basisAdresse: (quelle.BASIS_ADRESSE ?? "http://localhost:5174").replace(/\/+$/, ""),
        sitzungsdauerTage: zahl(quelle.SITZUNGSDAUER_TAGE, 14),
        maxDateigroesseMb: zahl(quelle.MAX_DATEIGROESSE_MB, 20),
        entwicklung: (quelle.NODE_ENV ?? "development") !== "production",
    };
}

export function schluessel(bytes = 24): string {
    return randomBytes(bytes).toString("base64url");
}
