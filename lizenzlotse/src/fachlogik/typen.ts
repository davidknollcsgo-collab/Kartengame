import type { IsoDatum } from "./datum.ts";

/** Dienste, für die Microsoft 365 Nutzungsdaten liefert. */
export const DIENSTE = [
    "exchange",
    "sharepoint",
    "onedrive",
    "teams",
    "office",
    "copilot",
] as const;
export type Dienst = (typeof DIENSTE)[number];

export const DIENST_TEXT: Record<Dienst, string> = {
    exchange: "E-Mail",
    sharepoint: "SharePoint",
    onedrive: "OneDrive",
    teams: "Teams",
    office: "Office-Anwendungen",
    copilot: "Copilot",
};

/**
 * Ein Konto im Mandanten des Kunden. Enthält bewusst keine Inhalte, nur
 * Verwaltungsdaten: der Lotse liest nie Postfächer oder Dateien.
 */
export interface Konto {
    /** Stabile Kennung aus dem Mandanten (Objekt-ID, sonst UPN). */
    id: string;
    upn: string;
    anzeigename: string;
    abteilung: string;
    /** Anmeldung blockiert — meist ausgeschiedene Mitarbeiter. */
    gesperrt: boolean;
    erstelltAm: IsoDatum | null;
    /** Letzte Aktivität je Dienst; fehlender Eintrag heißt "nie". */
    letzteAktivitaet: Partial<Record<Dienst, IsoDatum | null>>;
    /** Zugewiesene Lizenzen als SKU-Kennungen. */
    skus: string[];
}

/** Eine gekaufte Lizenzmenge im Mandanten. */
export interface Abonnement {
    sku: string;
    gekauft: number;
    zugewiesen: number;
    /** Ende der laufenden Vertragsperiode, falls bekannt. */
    laufzeitEnde: IsoDatum | null;
}

/** Der ausgewertete Bestand eines Mandanten zu einem Stichtag. */
export interface Bestand {
    stichtag: IsoDatum;
    konten: Konto[];
    abonnements: Abonnement[];
}

export const BEFUNDARTEN = [
    "gesperrt_lizenziert",
    "nie_aktiv",
    "inaktiv",
    "regallizenz",
    "doppelte_lizenz",
    "ungenutztes_zusatzprodukt",
    "ueberdimensioniert",
] as const;
export type Befundart = (typeof BEFUNDARTEN)[number];

export const BEFUNDART_TEXT: Record<Befundart, string> = {
    gesperrt_lizenziert: "Gesperrtes Konto mit Lizenz",
    nie_aktiv: "Nie genutzte Lizenz",
    inaktiv: "Seit Langem inaktiv",
    regallizenz: "Gekauft, nicht zugewiesen",
    doppelte_lizenz: "Doppelt lizenziert",
    ungenutztes_zusatzprodukt: "Ungenutztes Zusatzprodukt",
    ueberdimensioniert: "Zu großer Plan",
};

/**
 * Wie sicher der Befund ist. "sicher" heißt: die Lizenz kostet nachweislich
 * Geld ohne Gegenwert. "pruefen" heißt: sehr wahrscheinlich, aber es kann
 * einen Grund geben — ein Konto in Elternzeit etwa.
 */
export type Sicherheit = "sicher" | "pruefen";

export interface Befund {
    /**
     * Aus Art, Konto und SKU gebildet und damit über Auswertungen hinweg
     * stabil — nur so überlebt ein "ignoriert" den nächsten Import.
     */
    id: string;
    art: Befundart;
    sicherheit: Sicherheit;
    titel: string;
    begruendung: string;
    empfehlung: string;
    kontoId: string | null;
    upn: string | null;
    anzeigename: string | null;
    sku: string | null;
    /** Bei Abstufungen der günstigere Plan. */
    zielSku: string | null;
    /** Betroffene Plätze (bei Regallizenzen mehr als einer). */
    anzahl: number;
    ersparnisCentMonat: number;
}

export const BEFUND_STATUS = ["offen", "erledigt", "ignoriert"] as const;
export type Befundstatus = (typeof BEFUND_STATUS)[number];

export const BEFUND_STATUS_TEXT: Record<Befundstatus, string> = {
    offen: "Offen",
    erledigt: "Erledigt",
    ignoriert: "Ignoriert",
};
