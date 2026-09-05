// Katalog der gängigen Microsoft-365-Produkte.
//
// Die Preise sind **Richtwerte** in Cent je Platz und Monat (Listenpreis,
// Jahresbindung, Stand siehe PREISSTAND). Jeder Kunde zahlt andere Preise —
// über Partner, Mengenrabatt oder Altverträge —, deshalb lässt sich jeder
// Preis in den Einstellungen überschreiben. Der Katalog liefert nur den
// Ausgangswert, damit der erste Bericht sofort eine Hausnummer zeigt.

import type { Dienst } from "./typen.ts";

export const PREISSTAND = "2026-07";

export type Produktart = "basisplan" | "zusatz" | "sicherheit" | "sonstiges";

export interface SkuDefinition {
    /** Kennung wie im Mandanten, z. B. "SPE_E3". */
    id: string;
    name: string;
    /** Richtwert in Cent je Platz und Monat. */
    listenpreisCent: number;
    art: Produktart;
    /** Dienste, die der Plan freischaltet — Grundlage der Abstufung. */
    dienste: Dienst[];
    /**
     * Günstigere Pläne, die als Ersatz infrage kommen, teuerster zuerst.
     * Nur für Basispläne gepflegt.
     */
    abstufungen?: string[];
    /**
     * Dienst, dessen Nutzung dieses Zusatzprodukt rechtfertigt. Fehlt er,
     * lässt sich das Produkt nicht automatisch als ungenutzt erkennen.
     */
    belegtDurch?: Dienst;
}

const K = (euro: number) => Math.round(euro * 100);

export const SKUS: SkuDefinition[] = [
    // --- Basispläne für kleine Unternehmen (bis 300 Plätze) ---
    {
        id: "O365_BUSINESS_ESSENTIALS",
        name: "Microsoft 365 Business Basic",
        listenpreisCent: K(7.5),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams"],
    },
    {
        id: "O365_BUSINESS_PREMIUM",
        name: "Microsoft 365 Business Standard",
        listenpreisCent: K(14.8),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams", "office"],
        abstufungen: ["O365_BUSINESS_ESSENTIALS", "EXCHANGESTANDARD"],
    },
    {
        id: "SPB",
        name: "Microsoft 365 Business Premium",
        listenpreisCent: K(26.1),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams", "office"],
        abstufungen: ["O365_BUSINESS_PREMIUM", "O365_BUSINESS_ESSENTIALS", "EXCHANGESTANDARD"],
    },

    // --- Basispläne für größere Umgebungen ---
    {
        id: "STANDARDPACK",
        name: "Office 365 E1",
        listenpreisCent: K(10.4),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams"],
        abstufungen: ["EXCHANGESTANDARD"],
    },
    {
        id: "ENTERPRISEPACK",
        name: "Office 365 E3",
        listenpreisCent: K(25.5),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams", "office"],
        abstufungen: ["STANDARDPACK", "EXCHANGESTANDARD"],
    },
    {
        id: "ENTERPRISEPREMIUM",
        name: "Office 365 E5",
        listenpreisCent: K(43.8),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams", "office"],
        abstufungen: ["ENTERPRISEPACK", "STANDARDPACK"],
    },
    {
        id: "SPE_E3",
        name: "Microsoft 365 E3",
        listenpreisCent: K(40.2),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams", "office"],
        abstufungen: ["ENTERPRISEPACK", "STANDARDPACK"],
    },
    {
        id: "SPE_E5",
        name: "Microsoft 365 E5",
        listenpreisCent: K(62.5),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams", "office"],
        abstufungen: ["SPE_E3", "ENTERPRISEPACK"],
    },
    {
        id: "SPE_F1",
        name: "Microsoft 365 F1",
        listenpreisCent: K(2.3),
        art: "basisplan",
        dienste: ["sharepoint", "teams"],
    },
    {
        id: "SPE_F3",
        name: "Microsoft 365 F3",
        listenpreisCent: K(8.4),
        art: "basisplan",
        dienste: ["exchange", "sharepoint", "onedrive", "teams"],
        abstufungen: ["SPE_F1"],
    },
    {
        id: "EXCHANGESTANDARD",
        name: "Exchange Online Plan 1",
        listenpreisCent: K(4.4),
        art: "basisplan",
        dienste: ["exchange"],
    },
    {
        id: "EXCHANGEENTERPRISE",
        name: "Exchange Online Plan 2",
        listenpreisCent: K(8.8),
        art: "basisplan",
        dienste: ["exchange"],
        abstufungen: ["EXCHANGESTANDARD"],
    },

    // --- Zusatzprodukte: hier sitzt das meiste stille Geld ---
    {
        id: "Microsoft_365_Copilot",
        name: "Microsoft 365 Copilot",
        listenpreisCent: K(31.5),
        art: "zusatz",
        dienste: ["copilot"],
        belegtDurch: "copilot",
    },
    {
        id: "VISIOCLIENT",
        name: "Visio Plan 2",
        listenpreisCent: K(16.4),
        art: "zusatz",
        dienste: [],
    },
    {
        id: "VISIO_PLAN1_DEPT",
        name: "Visio Plan 1",
        listenpreisCent: K(5.4),
        art: "zusatz",
        dienste: [],
    },
    {
        id: "PROJECTPROFESSIONAL",
        name: "Project Plan 3",
        listenpreisCent: K(32.8),
        art: "zusatz",
        dienste: [],
    },
    {
        id: "PROJECT_P1",
        name: "Project Plan 1",
        listenpreisCent: K(10.9),
        art: "zusatz",
        dienste: [],
    },
    {
        id: "POWER_BI_PRO",
        name: "Power BI Pro",
        listenpreisCent: K(13.1),
        art: "zusatz",
        dienste: [],
    },
    {
        id: "MCOEV",
        name: "Teams Phone Standard",
        listenpreisCent: K(8.7),
        art: "zusatz",
        dienste: [],
    },
    {
        id: "Teams_Premium",
        name: "Teams Premium",
        listenpreisCent: K(10.5),
        art: "zusatz",
        dienste: ["teams"],
        belegtDurch: "teams",
    },

    // --- Sicherheit und Verwaltung ---
    {
        id: "AAD_PREMIUM",
        name: "Microsoft Entra ID P1",
        listenpreisCent: K(6.5),
        art: "sicherheit",
        dienste: [],
    },
    {
        id: "AAD_PREMIUM_P2",
        name: "Microsoft Entra ID P2",
        listenpreisCent: K(10.8),
        art: "sicherheit",
        dienste: [],
        abstufungen: ["AAD_PREMIUM"],
    },
    {
        id: "INTUNE_A",
        name: "Microsoft Intune Plan 1",
        listenpreisCent: K(9.0),
        art: "sicherheit",
        dienste: [],
    },
    {
        id: "ATP_ENTERPRISE",
        name: "Defender für Office 365 P1",
        listenpreisCent: K(2.2),
        art: "sicherheit",
        dienste: [],
    },
    {
        id: "EMS",
        name: "Enterprise Mobility + Security E3",
        listenpreisCent: K(11.6),
        art: "sicherheit",
        dienste: [],
    },
];

const NACH_ID = new Map(SKUS.map((sku) => [sku.id.toLowerCase(), sku]));

export function sku(id: string): SkuDefinition | undefined {
    return NACH_ID.get(id.trim().toLowerCase());
}

/** Anzeigename, auch für unbekannte Kennungen — dann eben die Kennung selbst. */
export function skuName(id: string): string {
    return sku(id)?.name ?? id;
}

export function istBasisplan(id: string): boolean {
    return sku(id)?.art === "basisplan";
}

/**
 * Preisliste eines Mandanten: Katalogwerte, überschrieben durch die eigenen
 * Preise des Kunden. Unbekannte Produkte ohne eigenen Preis zählen mit 0 —
 * lieber zu wenig Ersparnis ausweisen als eine erfundene Zahl.
 */
export function preisliste(eigenePreise: Record<string, number> = {}): (id: string) => number {
    const eigene = new Map(
        Object.entries(eigenePreise).map(([id, cent]) => [id.trim().toLowerCase(), cent]),
    );
    return (id: string) => {
        const schluessel = id.trim().toLowerCase();
        const eigener = eigene.get(schluessel);
        if (eigener !== undefined) return eigener;
        return NACH_ID.get(schluessel)?.listenpreisCent ?? 0;
    };
}
