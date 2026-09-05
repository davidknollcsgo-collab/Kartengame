import { describe, expect, test } from "vitest";
import { baueCsv } from "./csv.ts";
import type { Vertrag } from "./typen.ts";

function vertrag(teil: Partial<Vertrag> = {}): Vertrag {
    return {
        id: "v1",
        organisationId: "o1",
        bezeichnung: "Betriebshaftpflicht",
        anbieter: "Allianz",
        kategorie: "versicherung",
        vertragsnummer: "",
        abteilung: "",
        ansprechpartner: "",
        beginn: "2024-01-01",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 3,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        betragCent: 12_000,
        zahlungsintervall: "jaehrlich",
        status: "aktiv",
        gekuendigtZum: null,
        dokumentLink: "",
        notizen: "",
        erstelltAm: "2024-01-01T00:00:00.000Z",
        geaendertAm: "2024-01-01T00:00:00.000Z",
        ...teil,
    };
}

describe("CSV-Ausgabe", () => {
    test("enthält Kopfzeile und Werte", () => {
        const csv = baueCsv([vertrag()], "2026-08-25");
        expect(csv).toContain("Bezeichnung;Anbieter");
        expect(csv).toContain("Betriebshaftpflicht;Allianz");
    });

    test("entschärft Formeln, die Excel sonst ausführt", () => {
        // Bezeichnungen tippt jemand ein — sie sind damit Eingaben von außen.
        const csv = baueCsv([vertrag({ bezeichnung: "=1+1", anbieter: "@Allianz" })], "2026-08-25");
        expect(csv).toContain("\'=1+1");
        expect(csv).toContain("\'@Allianz");
        expect(csv).not.toMatch(/(^|;)=1\+1/m);
    });

    test("klammert Semikolon und Anführungszeichen ein", () => {
        const csv = baueCsv([vertrag({ bezeichnung: 'Miete "Nord"; Halle 2' })], "2026-08-25");
        expect(csv).toContain('"Miete ""Nord""; Halle 2"');
    });
});
