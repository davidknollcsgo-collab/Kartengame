// Zugriff auf den Server.

export interface Fehler extends Error {
    felder?: Record<string, string>;
    status?: number;
    daten?: Record<string, unknown>;
}

async function ruf<T>(pfad: string, optionen: RequestInit = {}): Promise<T> {
    const antwort = await fetch(pfad, {
        credentials: "same-origin",
        headers:
            optionen.body && typeof optionen.body === "string"
                ? { "content-type": "application/json" }
                : {},
        ...optionen,
    });
    const text = await antwort.text();
    const inhalt =
        text && antwort.headers.get("content-type")?.includes("json")
            ? (JSON.parse(text) as Record<string, unknown>)
            : { text };
    if (!antwort.ok) {
        const fehler = new Error(
            (inhalt["fehler"] as string) ?? `Der Server antwortete mit ${antwort.status}`,
        ) as Fehler;
        fehler.felder = inhalt["felder"] as Record<string, string> | undefined;
        fehler.status = antwort.status;
        fehler.daten = inhalt;
        throw fehler;
    }
    return inhalt as T;
}

export interface Anmeldedaten {
    benutzer: { id: string; name: string; email: string; rolle: "inhaber" | "mitglied" };
    organisation: { id: string; name: string };
    heute: string;
}

export interface Mandant {
    id: string;
    name: string;
    notiz: string;
    erstellt_am: string;
    letzte_auswertung: string | null;
    ersparnis_cent: number | null;
    lizenzkosten_cent: number | null;
}

export interface Befundzeile {
    id: string;
    schluessel: string;
    art: string;
    sicherheit: "sicher" | "pruefen";
    titel: string;
    begruendung: string;
    empfehlung: string;
    upn: string | null;
    anzeigename: string | null;
    sku: string | null;
    ziel_sku: string | null;
    anzahl: number;
    ersparnis_cent: number;
    status: "offen" | "erledigt" | "ignoriert";
    stand_notiz: string;
    stand_geaendert_am: string | null;
}

export interface Uebersicht {
    mandant: Mandant;
    auswertung: {
        id: string;
        stichtag: string;
        erstellt_am: string;
        quelle: string;
        anzahl_konten: number;
        anzahl_zuweisungen: number;
        lizenzkosten_cent: number;
        ersparnis_cent: number;
        ersparnis_sicher_cent: number;
        ersparnis_pruefen_cent: number;
        warnungen: string[];
    } | null;
    befunde: Befundzeile[];
    kennzahlen?: {
        offenCent: number;
        offenSicherCent: number;
        erledigtCent: number;
        anzahlOffen: number;
        anzahlErledigt: number;
    };
    verlauf?: {
        id: string;
        stichtag: string;
        erstellt_am: string;
        ersparnis_cent: number;
        ersparnis_sicher_cent: number;
        lizenzkosten_cent: number;
        anzahl_konten: number;
    }[];
}

export interface Preiszeile {
    sku: string;
    name: string;
    katalogCent: number;
    eigenCent: number | null;
}

export const api = {
    async ich(): Promise<Anmeldedaten | null> {
        try {
            return await ruf<Anmeldedaten>("/api/ich");
        } catch (fehler) {
            if ((fehler as Fehler).status === 401) return null;
            throw fehler;
        }
    },
    async anmelden(email: string, kennwort: string) {
        await ruf("/api/anmeldung", { method: "POST", body: JSON.stringify({ email, kennwort }) });
    },
    async registrieren(daten: { organisation: string; name: string; email: string; kennwort: string }) {
        await ruf("/api/registrierung", { method: "POST", body: JSON.stringify(daten) });
    },
    async abmelden() {
        await ruf("/api/abmeldung", { method: "POST" });
    },
    mandanten() {
        return ruf<{ mandanten: Mandant[] }>("/api/mandanten");
    },
    async mandantAnlegen(name: string, notiz = "") {
        return await ruf<{ id: string }>("/api/mandanten", {
            method: "POST",
            body: JSON.stringify({ name, notiz }),
        });
    },
    async mandantLoeschen(id: string) {
        await ruf(`/api/mandanten/${id}`, { method: "DELETE" });
    },
    uebersicht(mandantId: string) {
        return ruf<Uebersicht>(`/api/mandanten/${mandantId}/uebersicht`);
    },
    async auswerten(mandantId: string, dateien: File[]) {
        const formular = new FormData();
        for (const datei of dateien) formular.append("dateien", datei, datei.name);
        return await ruf<{ auswertungId: string; warnungen: string[]; dateien: { name: string; art: string; zeilen: number }[] }>(
            `/api/mandanten/${mandantId}/auswertung`,
            { method: "POST", body: formular },
        );
    },
    demodaten(mandantId: string) {
        return ruf<{ auswertungId: string; konten: number }>(
            `/api/mandanten/${mandantId}/demodaten`,
            { method: "POST" },
        );
    },
    async standSetzen(mandantId: string, schluessel: string, status: string, notiz = "") {
        await ruf(`/api/mandanten/${mandantId}/befunde/${encodeURIComponent(schluessel)}/stand`, {
            method: "POST",
            body: JSON.stringify({ status, notiz }),
        });
    },
    preise(mandantId: string) {
        return ruf<{ preise: Preiszeile[] }>(`/api/mandanten/${mandantId}/preise`);
    },
    async preiseSpeichern(mandantId: string, preise: { sku: string; cent: number }[]) {
        await ruf(`/api/mandanten/${mandantId}/preise`, {
            method: "PUT",
            body: JSON.stringify({ preise }),
        });
    },
    benutzer() {
        return ruf<{ benutzer: { id: string; name: string; email: string; rolle: string; erstellt_am: string }[] }>(
            "/api/benutzer",
        );
    },
    async benutzerAnlegen(daten: { name: string; email: string; kennwort: string; rolle: string }) {
        await ruf("/api/benutzer", { method: "POST", body: JSON.stringify(daten) });
    },
    verlauf() {
        return ruf<{ verlauf: { id: string; aktion: string; beschreibung: string; zeitpunkt: string; benutzer_name: string | null }[] }>(
            "/api/verlauf",
        );
    },
};
