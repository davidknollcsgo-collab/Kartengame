import type { IsoDatum } from "./datum.ts";

export const KATEGORIEN = [
    "versicherung",
    "software",
    "miete",
    "telekommunikation",
    "leasing",
    "wartung",
    "energie",
    "dienstleistung",
    "mitgliedschaft",
    "sonstiges",
] as const;
export type Kategorie = (typeof KATEGORIEN)[number];

export const KATEGORIE_TEXT: Record<Kategorie, string> = {
    versicherung: "Versicherung",
    software: "Software / SaaS",
    miete: "Miete & Pacht",
    telekommunikation: "Telekommunikation",
    leasing: "Leasing & Fuhrpark",
    wartung: "Wartung & Service",
    energie: "Energie",
    dienstleistung: "Dienstleistung",
    mitgliedschaft: "Mitgliedschaft & Beitrag",
    sonstiges: "Sonstiges",
};

export const LAUFZEITMODELLE = [
    "befristet_mit_verlaengerung",
    "befristet_ohne_verlaengerung",
    "unbefristet",
] as const;
export type Laufzeitmodell = (typeof LAUFZEITMODELLE)[number];

export const LAUFZEITMODELL_TEXT: Record<Laufzeitmodell, string> = {
    befristet_mit_verlaengerung: "Feste Laufzeit, verlängert sich automatisch",
    befristet_ohne_verlaengerung: "Feste Laufzeit, endet automatisch",
    unbefristet: "Unbefristet",
};

export const FRISTEINHEITEN = ["tage", "wochen", "monate"] as const;
export type Fristeinheit = (typeof FRISTEINHEITEN)[number];

export const FRISTEINHEIT_TEXT: Record<Fristeinheit, string> = {
    tage: "Tage",
    wochen: "Wochen",
    monate: "Monate",
};

export const FRISTBEZUEGE = [
    "zum_laufzeitende",
    "zum_monatsende",
    "zum_quartalsende",
    "zum_jahresende",
    "jederzeit",
] as const;
export type Fristbezug = (typeof FRISTBEZUEGE)[number];

export const FRISTBEZUG_TEXT: Record<Fristbezug, string> = {
    zum_laufzeitende: "zum Laufzeitende",
    zum_monatsende: "zum Monatsende",
    zum_quartalsende: "zum Quartalsende",
    zum_jahresende: "zum Jahresende",
    jederzeit: "jederzeit (ohne festen Termin)",
};

export const ZAHLUNGSINTERVALLE = [
    "monatlich",
    "vierteljaehrlich",
    "halbjaehrlich",
    "jaehrlich",
    "einmalig",
] as const;
export type Zahlungsintervall = (typeof ZAHLUNGSINTERVALLE)[number];

export const ZAHLUNGSINTERVALL_TEXT: Record<Zahlungsintervall, string> = {
    monatlich: "monatlich",
    vierteljaehrlich: "vierteljährlich",
    halbjaehrlich: "halbjährlich",
    jaehrlich: "jährlich",
    einmalig: "einmalig",
};

/** Zahlungen pro Jahr; `einmalig` fließt nicht in die Jahreskosten ein. */
export const ZAHLUNGEN_PRO_JAHR: Record<Zahlungsintervall, number> = {
    monatlich: 12,
    vierteljaehrlich: 4,
    halbjaehrlich: 2,
    jaehrlich: 1,
    einmalig: 0,
};

export const VERTRAGSSTATUS = ["aktiv", "gekuendigt", "beendet"] as const;
export type Vertragsstatus = (typeof VERTRAGSSTATUS)[number];

export const VERTRAGSSTATUS_TEXT: Record<Vertragsstatus, string> = {
    aktiv: "Aktiv",
    gekuendigt: "Gekündigt",
    beendet: "Beendet",
};

/**
 * Die Angaben, aus denen sich der Kündigungsstichtag berechnen lässt — der
 * eigentliche Kern des Wächters. Alles andere am Vertrag ist Verwaltung.
 */
export interface Vertragsbedingungen {
    beginn: IsoDatum;
    laufzeitmodell: Laufzeitmodell;
    /** Erst- bzw. Mindestlaufzeit in Monaten; 0 = keine. */
    erstlaufzeitMonate: number;
    /** Dauer einer automatischen Verlängerung in Monaten. */
    verlaengerungMonate: number;
    kuendigungsfristWert: number;
    kuendigungsfristEinheit: Fristeinheit;
    kuendigungsfristBezug: Fristbezug;
}

export interface Vertrag extends Vertragsbedingungen {
    id: string;
    organisationId: string;
    bezeichnung: string;
    anbieter: string;
    kategorie: Kategorie;
    vertragsnummer: string;
    abteilung: string;
    ansprechpartner: string;
    /** Betrag in Cent, damit nichts an Rundung verloren geht. */
    betragCent: number;
    zahlungsintervall: Zahlungsintervall;
    status: Vertragsstatus;
    /** Gesetzt, sobald gekündigt wurde: Tag, zu dem der Vertrag endet. */
    gekuendigtZum: IsoDatum | null;
    dokumentLink: string;
    notizen: string;
    erstelltAm: string;
    geaendertAm: string;
}

export interface Organisation {
    id: string;
    name: string;
    /** Tage vor dem Stichtag, an denen erinnert wird, absteigend sortiert. */
    erinnerungsvorlauf: number[];
    /** Zusätzliche Empfänger für Erinnerungen (neben allen Mitgliedern). */
    verteiler: string[];
    kalenderSchluessel: string;
    erstelltAm: string;
}

export interface Benutzer {
    id: string;
    organisationId: string;
    name: string;
    email: string;
    rolle: "inhaber" | "mitglied";
    erstelltAm: string;
}
