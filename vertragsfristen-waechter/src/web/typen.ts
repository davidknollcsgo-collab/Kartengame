import type { Ampel, Fristberechnung } from "../fachlogik/fristen.ts";
import type { Benutzer, Organisation, Vertrag } from "../fachlogik/typen.ts";

export interface VertragMitFristen extends Vertrag {
    fristen: Fristberechnung;
    ampel: Ampel;
    jahreskostenCent: number;
}

export interface Anmeldedaten {
    benutzer: Benutzer;
    organisation: Organisation;
    heute: string;
    kalenderAdresse: string;
}

export interface Uebersicht {
    heute: string;
    anzahlGesamt: number;
    anzahlAktiv: number;
    jahreskostenCent: number;
    gefaehrdeteKostenCent: number;
    nachAmpel: Record<Ampel, number>;
    nachKategorie: Record<string, { anzahl: number; jahreskostenCent: number }>;
    fristenIn30: number;
    fristenIn90: number;
    naechsteFristen: VertragMitFristen[];
    offeneErinnerungen: { anzahl: number };
}

export interface Erinnerung {
    id: string;
    vertrag_id: string;
    stichtag: string;
    vorlauf_tage: number;
    faellig_am: string;
    erzeugt_am: string;
    versendet_am: string | null;
    erledigt_am: string | null;
    bezeichnung: string;
    anbieter: string;
    kategorie: string;
}

export interface Nachricht {
    id: string;
    empfaenger: string;
    betreff: string;
    inhalt: string;
    erzeugt_am: string;
    versendet_am: string | null;
    fehler: string | null;
}

export interface Verlaufseintrag {
    id: string;
    aktion: string;
    beschreibung: string;
    zeitpunkt: string;
}

/** Eingabewerte des Vertragsformulars — die Form, die die Schnittstelle erwartet. */
export type VertragEingabe = Omit<
    Vertrag,
    "id" | "organisationId" | "erstelltAm" | "geaendertAm"
>;

export interface Fehler extends Error {
    felder?: Record<string, string>;
    status?: number;
}
