import type { Kategorie, Vertragsbedingungen, Zahlungsintervall } from "./typen.ts";

/**
 * Vorlagen für die häufigsten Vertragsarten. Sie ersparen beim Anlegen das
 * Nachschlagen im Vertrag: Laufzeit und Frist sind vorbelegt und lassen sich
 * anschließend überschreiben.
 */
export interface Vertragsvorlage {
    schluessel: string;
    name: string;
    beschreibung: string;
    kategorie: Kategorie;
    zahlungsintervall: Zahlungsintervall;
    bedingungen: Omit<Vertragsbedingungen, "beginn">;
}

export const VORLAGEN: Vertragsvorlage[] = [
    {
        schluessel: "software_monatlich",
        name: "Software-Abo, monatlich",
        beschreibung: "Monatlich kündbares SaaS-Abo, 30 Tage zum Monatsende.",
        kategorie: "software",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "unbefristet",
            erstlaufzeitMonate: 0,
            verlaengerungMonate: 0,
            kuendigungsfristWert: 30,
            kuendigungsfristEinheit: "tage",
            kuendigungsfristBezug: "zum_monatsende",
        },
    },
    {
        schluessel: "software_jaehrlich",
        name: "Software-Abo, Jahreslizenz",
        beschreibung: "Jahreslizenz, verlängert sich um ein Jahr, 30 Tage Frist.",
        kategorie: "software",
        zahlungsintervall: "jaehrlich",
        bedingungen: {
            laufzeitmodell: "befristet_mit_verlaengerung",
            erstlaufzeitMonate: 12,
            verlaengerungMonate: 12,
            kuendigungsfristWert: 30,
            kuendigungsfristEinheit: "tage",
            kuendigungsfristBezug: "zum_laufzeitende",
        },
    },
    {
        schluessel: "versicherung_jahr",
        name: "Gewerbeversicherung",
        beschreibung: "Jahresvertrag mit stiller Verlängerung, 3 Monate Frist.",
        kategorie: "versicherung",
        zahlungsintervall: "jaehrlich",
        bedingungen: {
            laufzeitmodell: "befristet_mit_verlaengerung",
            erstlaufzeitMonate: 12,
            verlaengerungMonate: 12,
            kuendigungsfristWert: 3,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_laufzeitende",
        },
    },
    {
        schluessel: "versicherung_mehrjahr",
        name: "Versicherung mit Mehrjahresrabatt",
        beschreibung: "Fünf Jahre Laufzeit, danach jährliche Verlängerung.",
        kategorie: "versicherung",
        zahlungsintervall: "jaehrlich",
        bedingungen: {
            laufzeitmodell: "befristet_mit_verlaengerung",
            erstlaufzeitMonate: 60,
            verlaengerungMonate: 12,
            kuendigungsfristWert: 3,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_laufzeitende",
        },
    },
    {
        schluessel: "gewerbemiete",
        name: "Gewerbemietvertrag",
        beschreibung: "Unbefristet, 6 Monate zum Quartalsende (§ 580a BGB).",
        kategorie: "miete",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "unbefristet",
            erstlaufzeitMonate: 0,
            verlaengerungMonate: 0,
            kuendigungsfristWert: 6,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_quartalsende",
        },
    },
    {
        schluessel: "wohnraummiete",
        name: "Wohnraummiete",
        beschreibung: "Unbefristet, 3 Monate zum Monatsende.",
        kategorie: "miete",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "unbefristet",
            erstlaufzeitMonate: 0,
            verlaengerungMonate: 0,
            kuendigungsfristWert: 3,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_monatsende",
        },
    },
    {
        schluessel: "mobilfunk",
        name: "Mobilfunk / Internet",
        beschreibung: "24 Monate Mindestlaufzeit, danach monatlich kündbar.",
        kategorie: "telekommunikation",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "unbefristet",
            erstlaufzeitMonate: 24,
            verlaengerungMonate: 0,
            kuendigungsfristWert: 1,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_monatsende",
        },
    },
    {
        schluessel: "leasing",
        name: "Fahrzeug-Leasing",
        beschreibung: "36 Monate feste Laufzeit, endet ohne Kündigung.",
        kategorie: "leasing",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "befristet_ohne_verlaengerung",
            erstlaufzeitMonate: 36,
            verlaengerungMonate: 0,
            kuendigungsfristWert: 0,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_laufzeitende",
        },
    },
    {
        schluessel: "wartung",
        name: "Wartungs- / Servicevertrag",
        beschreibung: "Jahresvertrag mit Verlängerung, 3 Monate Frist.",
        kategorie: "wartung",
        zahlungsintervall: "jaehrlich",
        bedingungen: {
            laufzeitmodell: "befristet_mit_verlaengerung",
            erstlaufzeitMonate: 12,
            verlaengerungMonate: 12,
            kuendigungsfristWert: 3,
            kuendigungsfristEinheit: "monate",
            kuendigungsfristBezug: "zum_laufzeitende",
        },
    },
    {
        schluessel: "energie",
        name: "Strom / Gas",
        beschreibung: "12 Monate Preisgarantie, verlängert sich um 12 Monate.",
        kategorie: "energie",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "befristet_mit_verlaengerung",
            erstlaufzeitMonate: 12,
            verlaengerungMonate: 12,
            kuendigungsfristWert: 6,
            kuendigungsfristEinheit: "wochen",
            kuendigungsfristBezug: "zum_laufzeitende",
        },
    },
    {
        schluessel: "jederzeit",
        name: "Jederzeit kündbar",
        beschreibung: "Ohne festen Termin, 14 Tage Auslauffrist.",
        kategorie: "dienstleistung",
        zahlungsintervall: "monatlich",
        bedingungen: {
            laufzeitmodell: "unbefristet",
            erstlaufzeitMonate: 0,
            verlaengerungMonate: 0,
            kuendigungsfristWert: 14,
            kuendigungsfristEinheit: "tage",
            kuendigungsfristBezug: "jederzeit",
        },
    },
];

export function vorlage(schluessel: string): Vertragsvorlage | undefined {
    return VORLAGEN.find((v) => v.schluessel === schluessel);
}
