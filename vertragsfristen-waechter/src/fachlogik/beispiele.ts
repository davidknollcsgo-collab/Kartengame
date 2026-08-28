// Beispielbestand einer kleinen Firma. Die Vertragsdaten sind so gerechnet,
// dass sie zum heutigen Tag passen: eine Frist läuft in wenigen Tagen ab, eine
// weitere in einigen Wochen — sonst zeigt die Übersicht beim Ausprobieren
// nichts als Grün.
//
// Liegt in der Fachlogik, weil Server und Browser-Demo denselben Bestand
// aufsetzen.

import { plusMonate, plusTage, tageBis, type IsoDatum } from "./datum.ts";
import { fristAufschlagen, stichtagFuer } from "./fristen.ts";
import type {
    Fristbezug,
    Fristeinheit,
    Kategorie,
    Laufzeitmodell,
    Vertrag,
    Vertragsstatus,
    Zahlungsintervall,
} from "./typen.ts";

export interface Muster {
    bezeichnung: string;
    anbieter: string;
    kategorie: Kategorie;
    vertragsnummer: string;
    abteilung: string;
    ansprechpartner: string;
    betragCent: number;
    zahlungsintervall: Zahlungsintervall;
    laufzeitmodell: Laufzeitmodell;
    erstlaufzeitMonate: number;
    verlaengerungMonate: number;
    kuendigungsfristWert: number;
    kuendigungsfristEinheit: Fristeinheit;
    kuendigungsfristBezug: Fristbezug;
    /** Gewünschter Abstand des nächsten Stichtags in Tagen. */
    stichtagInTagen?: number;
    /** Alter des Vertrags in vollen Verlängerungsperioden. */
    perioden?: number;
    status?: Vertragsstatus;
    gekuendigtZum?: IsoDatum;
    notizen?: string;
}

export const MUSTER: Muster[] = [
    {
        bezeichnung: "Betriebshaftpflicht",
        anbieter: "Allianz Versicherungs-AG",
        kategorie: "versicherung",
        vertragsnummer: "BHV-2019-44821",
        abteilung: "Verwaltung",
        ansprechpartner: "Frau Behrens, Makler Nord",
        betragCent: 248_400,
        zahlungsintervall: "jaehrlich",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 3,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 9,
        perioden: 6,
        notizen: "Deckungssumme 5 Mio. €. Vergleichsangebot der Gothaer liegt vor.",
    },
    {
        bezeichnung: "Microsoft 365 Business Premium (45 Plätze)",
        anbieter: "Microsoft Ireland",
        kategorie: "software",
        vertragsnummer: "MS-8827341",
        abteilung: "IT",
        ansprechpartner: "Herr Özdemir",
        betragCent: 92_475,
        zahlungsintervall: "monatlich",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 30,
        kuendigungsfristEinheit: "tage",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 26,
        perioden: 3,
        notizen: "Vor der Verlängerung Lizenzzahl prüfen — sechs Plätze sind ungenutzt.",
    },
    {
        bezeichnung: "Büroflächen Ostring 12, 340 m²",
        anbieter: "Ostring Immobilien GmbH & Co. KG",
        kategorie: "miete",
        vertragsnummer: "MV-2021-07",
        abteilung: "Geschäftsführung",
        ansprechpartner: "Herr Lambert",
        betragCent: 486_000,
        zahlungsintervall: "monatlich",
        laufzeitmodell: "unbefristet",
        erstlaufzeitMonate: 0,
        verlaengerungMonate: 0,
        kuendigungsfristWert: 6,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_quartalsende",
        perioden: 0,
        notizen: "Staffelmiete, nächste Anpassung im Januar. Kündigung nur schriftlich per Einschreiben.",
    },
    {
        bezeichnung: "CRM-System, 20 Nutzer",
        anbieter: "Pipedrive OÜ",
        kategorie: "software",
        vertragsnummer: "PD-556-2024",
        abteilung: "Vertrieb",
        ansprechpartner: "Frau Krüger",
        betragCent: 118_800,
        zahlungsintervall: "jaehrlich",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 1,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 74,
        perioden: 2,
    },
    {
        bezeichnung: "Firmenwagen VW Passat, Leasing",
        anbieter: "VW Leasing GmbH",
        kategorie: "leasing",
        vertragsnummer: "LS-9930221",
        abteilung: "Vertrieb",
        ansprechpartner: "Frau Krüger",
        betragCent: 43_900,
        zahlungsintervall: "monatlich",
        laufzeitmodell: "befristet_ohne_verlaengerung",
        erstlaufzeitMonate: 36,
        verlaengerungMonate: 0,
        kuendigungsfristWert: 0,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 132,
        notizen: "Rückgabe mit Gutachten. Anschlussfahrzeug bis dahin bestellen.",
    },
    {
        bezeichnung: "Geschäftsanschluss Glasfaser 1000",
        anbieter: "Deutsche Telekom AG",
        kategorie: "telekommunikation",
        vertragsnummer: "TK-4471-9",
        abteilung: "IT",
        ansprechpartner: "Herr Özdemir",
        betragCent: 14_990,
        zahlungsintervall: "monatlich",
        laufzeitmodell: "unbefristet",
        erstlaufzeitMonate: 24,
        verlaengerungMonate: 0,
        kuendigungsfristWert: 1,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_monatsende",
        perioden: 0,
    },
    {
        bezeichnung: "Wartung Heizungs- und Lüftungsanlage",
        anbieter: "Kessler Haustechnik GmbH",
        kategorie: "wartung",
        vertragsnummer: "W-2022-118",
        abteilung: "Verwaltung",
        ansprechpartner: "Herr Lambert",
        betragCent: 168_000,
        zahlungsintervall: "jaehrlich",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 3,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 212,
        perioden: 3,
    },
    {
        bezeichnung: "Rechtsschutz für Unternehmen",
        anbieter: "ARAG SE",
        kategorie: "versicherung",
        vertragsnummer: "RS-77120",
        abteilung: "Geschäftsführung",
        ansprechpartner: "Frau Behrens, Makler Nord",
        betragCent: 96_000,
        zahlungsintervall: "jaehrlich",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 36,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 3,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 288,
        perioden: 1,
    },
    {
        bezeichnung: "Reinigungsdienst, zweimal wöchentlich",
        anbieter: "Sauber & Partner Gebäudeservice",
        kategorie: "dienstleistung",
        vertragsnummer: "RG-4",
        abteilung: "Verwaltung",
        ansprechpartner: "Herr Lambert",
        betragCent: 89_000,
        zahlungsintervall: "monatlich",
        laufzeitmodell: "unbefristet",
        erstlaufzeitMonate: 0,
        verlaengerungMonate: 0,
        kuendigungsfristWert: 14,
        kuendigungsfristEinheit: "tage",
        kuendigungsfristBezug: "jederzeit",
    },
    {
        bezeichnung: "Projektmanagement-Software (abgelöst)",
        anbieter: "Asana Inc.",
        kategorie: "software",
        vertragsnummer: "AS-2023-88",
        abteilung: "IT",
        ansprechpartner: "Herr Özdemir",
        betragCent: 58_800,
        zahlungsintervall: "jaehrlich",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 30,
        kuendigungsfristEinheit: "tage",
        kuendigungsfristBezug: "zum_laufzeitende",
        stichtagInTagen: 41,
        perioden: 2,
        status: "gekuendigt",
        notizen: "Gekündigt zum Laufzeitende, Ablösung durch das CRM-Board.",
    },
];

/**
 * Rechnet vom gewünschten Stichtag auf den Vertragsbeginn zurück, damit die
 * Beispieldaten unabhängig vom Kalendertag dieselbe Dringlichkeit zeigen.
 */
export function beginnFuerStichtag(muster: Muster, basis: IsoDatum): IsoDatum {
    const perioden = muster.perioden ?? 0;
    if (muster.stichtagInTagen === undefined) {
        // Unbefristete Verträge haben keinen abgeleiteten Stichtag; sie
        // beginnen einfach ein paar Jahre in der Vergangenheit.
        return plusMonate(basis, -(perioden > 0 ? perioden * 12 : 30));
    }
    const zielStichtag = plusTage(basis, muster.stichtagInTagen);
    // Das Laufzeitende ergibt sich, indem die Frist wieder aufgeschlagen wird.
    // Wegen der Monatskappung trifft das nicht immer auf den Tag genau — die
    // Abweichung wird nachgeführt, bis Hin- und Rückweg zusammenpassen.
    let ende = fristAufschlagen(
        zielStichtag,
        muster.kuendigungsfristWert,
        muster.kuendigungsfristEinheit,
    );
    for (let versuch = 0; versuch < 4; versuch += 1) {
        const zurueck = stichtagFuer(ende, muster.kuendigungsfristWert, muster.kuendigungsfristEinheit);
        const abweichung = tageBis(zurueck, zielStichtag);
        if (abweichung === 0) break;
        ende = plusTage(ende, abweichung);
    }
    const monateGesamt =
        muster.erstlaufzeitMonate + perioden * (muster.verlaengerungMonate || muster.erstlaufzeitMonate);
    return plusMonate(plusTage(ende, 1), -monateGesamt);
}


/** Der Beispielbestand als fertige Verträge, bezogen auf den Tag `basis`. */
export function beispielvertraege(
    basis: IsoDatum,
): Omit<Vertrag, "id" | "organisationId" | "erstelltAm" | "geaendertAm">[] {
    return MUSTER.map((muster) => {
        const beginn = beginnFuerStichtag(muster, basis);
        const laufzeitEnde = plusTage(
            plusMonate(
                beginn,
                muster.erstlaufzeitMonate + (muster.perioden ?? 0) * muster.verlaengerungMonate,
            ),
            -1,
        );
        return {
            bezeichnung: muster.bezeichnung,
            anbieter: muster.anbieter,
            kategorie: muster.kategorie,
            vertragsnummer: muster.vertragsnummer,
            abteilung: muster.abteilung,
            ansprechpartner: muster.ansprechpartner,
            beginn,
            laufzeitmodell: muster.laufzeitmodell,
            erstlaufzeitMonate: muster.erstlaufzeitMonate,
            verlaengerungMonate: muster.verlaengerungMonate,
            kuendigungsfristWert: muster.kuendigungsfristWert,
            kuendigungsfristEinheit: muster.kuendigungsfristEinheit,
            kuendigungsfristBezug: muster.kuendigungsfristBezug,
            betragCent: muster.betragCent,
            zahlungsintervall: muster.zahlungsintervall,
            status: muster.status ?? "aktiv",
            gekuendigtZum:
                muster.status === "gekuendigt" ? (muster.gekuendigtZum ?? laufzeitEnde) : null,
            dokumentLink: "",
            notizen: muster.notizen ?? "",
        };
    });
}
