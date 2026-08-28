// Zugriff auf den Server. Im Demo-Modus (npm run demo) übernimmt derselbe
// Vertrag eine Ablage im Browser, damit sich die Oberfläche ohne Server und
// ohne Konto ausprobieren lässt.

import type { Organisation } from "../fachlogik/typen.ts";
import { demoApi } from "./demo.ts";
import type {
    Anmeldedaten,
    Erinnerung,
    Fehler,
    Nachricht,
    Uebersicht,
    Verlaufseintrag,
    VertragEingabe,
    VertragMitFristen,
} from "./typen.ts";

export interface Filter {
    suche?: string;
    kategorie?: string;
    status?: string;
    ampel?: string;
}

export interface Api {
    demo: boolean;
    ich(): Promise<Anmeldedaten | null>;
    anmelden(email: string, kennwort: string): Promise<void>;
    registrieren(daten: {
        organisation: string;
        name: string;
        email: string;
        kennwort: string;
    }): Promise<void>;
    abmelden(): Promise<void>;
    vertraege(filter?: Filter): Promise<{ vertraege: VertragMitFristen[]; heute: string }>;
    vertrag(id: string): Promise<{
        vertrag: VertragMitFristen;
        verlauf: Verlaufseintrag[];
        erinnerungen: Erinnerung[];
    }>;
    anlegen(eingabe: VertragEingabe): Promise<VertragMitFristen>;
    aendern(id: string, eingabe: VertragEingabe): Promise<VertragMitFristen>;
    loeschen(id: string): Promise<void>;
    kuendigen(
        id: string,
        daten: { gekuendigtZum: string | null; notiz: string },
    ): Promise<VertragMitFristen>;
    reaktivieren(id: string): Promise<VertragMitFristen>;
    uebersicht(): Promise<Uebersicht>;
    erinnerungen(): Promise<{ erinnerungen: Erinnerung[]; heute: string }>;
    erinnerungErledigt(id: string): Promise<void>;
    postausgang(): Promise<{ nachrichten: Nachricht[]; smtpEingerichtet: boolean }>;
    fristenlauf(): Promise<{ geprueft: number; neueErinnerungen: number; versendeteMails: number }>;
    organisationSpeichern(daten: {
        name: string;
        erinnerungsvorlauf: number[];
        verteiler: string[];
    }): Promise<Organisation>;
    kalenderErneuern(): Promise<{ kalenderAdresse: string }>;
    demodaten(): Promise<{ angelegt: number }>;
    csv(): Promise<string>;
}

async function ruf<T>(pfad: string, optionen: RequestInit = {}): Promise<T> {
    const antwort = await fetch(pfad, {
        credentials: "same-origin",
        headers: optionen.body ? { "content-type": "application/json" } : {},
        ...optionen,
    });
    const text = await antwort.text();
    const inhalt = text && antwort.headers.get("content-type")?.includes("json")
        ? (JSON.parse(text) as Record<string, unknown>)
        : { text };
    if (!antwort.ok) {
        const fehler = new Error(
            (inhalt["fehler"] as string) ?? `Der Server antwortete mit ${antwort.status}`,
        ) as Fehler;
        fehler.felder = inhalt["felder"] as Record<string, string> | undefined;
        fehler.status = antwort.status;
        throw fehler;
    }
    return inhalt as T;
}

const serverApi: Api = {
    demo: false,
    async ich() {
        try {
            return await ruf<Anmeldedaten>("/api/ich");
        } catch (fehler) {
            if ((fehler as Fehler).status === 401) return null;
            throw fehler;
        }
    },
    async anmelden(email, kennwort) {
        await ruf("/api/anmeldung", { method: "POST", body: JSON.stringify({ email, kennwort }) });
    },
    async registrieren(daten) {
        await ruf("/api/registrierung", { method: "POST", body: JSON.stringify(daten) });
    },
    async abmelden() {
        await ruf("/api/abmeldung", { method: "POST" });
    },
    vertraege(filter = {}) {
        const suchteil = new URLSearchParams(
            Object.entries(filter).filter(([, wert]) => wert) as [string, string][],
        ).toString();
        return ruf(`/api/vertraege${suchteil ? `?${suchteil}` : ""}`);
    },
    vertrag(id) {
        return ruf(`/api/vertraege/${id}`);
    },
    async anlegen(eingabe) {
        const { vertrag } = await ruf<{ vertrag: VertragMitFristen }>("/api/vertraege", {
            method: "POST",
            body: JSON.stringify(eingabe),
        });
        return vertrag;
    },
    async aendern(id, eingabe) {
        const { vertrag } = await ruf<{ vertrag: VertragMitFristen }>(`/api/vertraege/${id}`, {
            method: "PUT",
            body: JSON.stringify(eingabe),
        });
        return vertrag;
    },
    async loeschen(id) {
        await ruf(`/api/vertraege/${id}`, { method: "DELETE" });
    },
    async kuendigen(id, daten) {
        const { vertrag } = await ruf<{ vertrag: VertragMitFristen }>(
            `/api/vertraege/${id}/kuendigung`,
            { method: "POST", body: JSON.stringify(daten) },
        );
        return vertrag;
    },
    async reaktivieren(id) {
        const { vertrag } = await ruf<{ vertrag: VertragMitFristen }>(
            `/api/vertraege/${id}/reaktivierung`,
            { method: "POST" },
        );
        return vertrag;
    },
    uebersicht() {
        return ruf("/api/uebersicht");
    },
    erinnerungen() {
        return ruf("/api/erinnerungen");
    },
    async erinnerungErledigt(id) {
        await ruf(`/api/erinnerungen/${id}/erledigt`, { method: "POST" });
    },
    postausgang() {
        return ruf("/api/postausgang");
    },
    fristenlauf() {
        return ruf("/api/fristenlauf", { method: "POST" });
    },
    async organisationSpeichern(daten) {
        const { organisation } = await ruf<{ organisation: Organisation }>("/api/organisation", {
            method: "PUT",
            body: JSON.stringify(daten),
        });
        return organisation;
    },
    kalenderErneuern() {
        return ruf("/api/kalenderschluessel", { method: "POST" });
    },
    demodaten() {
        return ruf("/api/demodaten", { method: "POST" });
    },
    async csv() {
        const antwort = await fetch("/api/export/vertraege.csv", { credentials: "same-origin" });
        return await antwort.text();
    },
};

export const api: Api = __DEMO__ ? demoApi : serverApi;
