import { describe, expect, test } from "vitest";
import { berechneFristen, bestimmeAmpel, bewerteVertrag, stichtagFuer } from "./fristen.ts";
import type { Vertrag, Vertragsbedingungen } from "./typen.ts";

function bedingungen(teil: Partial<Vertragsbedingungen> = {}): Vertragsbedingungen {
    return {
        beginn: "2024-01-01",
        laufzeitmodell: "befristet_mit_verlaengerung",
        erstlaufzeitMonate: 12,
        verlaengerungMonate: 12,
        kuendigungsfristWert: 3,
        kuendigungsfristEinheit: "monate",
        kuendigungsfristBezug: "zum_laufzeitende",
        ...teil,
    };
}

function vertrag(teil: Partial<Vertrag> = {}): Vertrag {
    return {
        ...bedingungen(),
        id: "v1",
        organisationId: "o1",
        bezeichnung: "Betriebshaftpflicht",
        anbieter: "Beispiel Versicherung",
        kategorie: "versicherung",
        vertragsnummer: "BH-4711",
        abteilung: "Verwaltung",
        ansprechpartner: "",
        betragCent: 120_00,
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

describe("stichtagFuer", () => {
    test("zieht Monate, Wochen und Tage ab", () => {
        expect(stichtagFuer("2026-12-31", 3, "monate")).toBe("2026-09-30");
        expect(stichtagFuer("2026-12-31", 6, "wochen")).toBe("2026-11-19");
        expect(stichtagFuer("2026-12-31", 30, "tage")).toBe("2026-12-01");
    });

    test("ohne Frist ist der Beendigungstermin selbst der Stichtag", () => {
        expect(stichtagFuer("2026-12-31", 0, "monate")).toBe("2026-12-31");
    });
});

describe("Jahresvertrag mit automatischer Verlängerung", () => {
    test("findet den Stichtag der laufenden Periode", () => {
        const f = berechneFristen(bedingungen(), "2026-08-25");
        expect(f.art).toBe("kuendigungsstichtag");
        expect(f.laufzeitende).toBe("2026-12-31");
        expect(f.stichtag).toBe("2026-09-30");
        expect(f.tageBisStichtag).toBe(36);
        expect(f.wirksamesVertragsende).toBe("2026-12-31");
        expect(f.verlaengerungenBisher).toBe(2);
        expect(f.fristVerstrichen).toBe(false);
    });

    test("am Stichtag selbst ist die Kündigung noch möglich", () => {
        const f = berechneFristen(bedingungen(), "2026-09-30");
        expect(f.stichtag).toBe("2026-09-30");
        expect(f.tageBisStichtag).toBe(0);
        expect(f.fristVerstrichen).toBe(false);
    });

    test("einen Tag später greift die Verlängerung", () => {
        const f = berechneFristen(bedingungen(), "2026-10-01");
        expect(f.fristVerstrichen).toBe(true);
        expect(f.laufzeitende).toBe("2026-12-31");
        expect(f.stichtag).toBe("2027-09-30");
        expect(f.wirksamesVertragsende).toBe("2027-12-31");
        expect(f.hinweis).toContain("verstrichen");
    });

    test("rechnet auch am ersten Tag der neuen Periode richtig", () => {
        const f = berechneFristen(bedingungen(), "2027-01-01");
        expect(f.laufzeitende).toBe("2027-12-31");
        expect(f.stichtag).toBe("2027-09-30");
        expect(f.verlaengerungenBisher).toBe(3);
    });

    test("kurze Verlängerungen springen mehrere Perioden weiter", () => {
        // Dreimonatsvertrag mit vier Monaten Frist: die nächste erreichbare
        // Kündigung liegt zwangsläufig zwei Perioden voraus.
        const f = berechneFristen(
            bedingungen({
                erstlaufzeitMonate: 3,
                verlaengerungMonate: 3,
                kuendigungsfristWert: 4,
            }),
            "2026-08-25",
        );
        expect(f.laufzeitende).toBe("2026-09-30");
        expect(f.stichtag).toBe("2026-08-31");
        expect(f.wirksamesVertragsende).toBe("2026-12-31");
        // Für das laufende Quartal war die Frist schon im Mai abgelaufen.
        expect(f.fristVerstrichen).toBe(true);
    });

    test("Laufzeit ab Monatsende kappt korrekt", () => {
        const f = berechneFristen(
            bedingungen({
                beginn: "2024-01-31",
                erstlaufzeitMonate: 1,
                verlaengerungMonate: 1,
                kuendigungsfristWert: 14,
                kuendigungsfristEinheit: "tage",
            }),
            "2026-08-25",
        );
        // Alle Perioden hängen am 31.01.2024: das Ende bleibt der Tag vor dem
        // Monatsstichtag und driftet über kurze Monate nicht weg.
        expect(f.laufzeitende).toBe("2026-08-30");
        expect(f.stichtag).toBe("2026-09-15");
        expect(f.wirksamesVertragsende).toBe("2026-09-29");
        expect(f.fristVerstrichen).toBe(true);
    });
});

describe("Feste Laufzeit ohne Verlängerung", () => {
    test("meldet das Auslaufdatum statt eines Stichtags", () => {
        const f = berechneFristen(
            bedingungen({ laufzeitmodell: "befristet_ohne_verlaengerung", erstlaufzeitMonate: 36 }),
            "2026-08-25",
        );
        expect(f.art).toBe("vertragsende");
        expect(f.stichtag).toBe("2026-12-31");
        expect(f.wirksamesVertragsende).toBe("2026-12-31");
        expect(f.hinweis).toContain("Anschlussvertrag");
    });

    test("nach dem Ablauf gibt es nichts mehr zu überwachen", () => {
        const f = berechneFristen(
            bedingungen({ laufzeitmodell: "befristet_ohne_verlaengerung", erstlaufzeitMonate: 12 }),
            "2026-08-25",
        );
        expect(f.art).toBe("keine");
        expect(f.stichtag).toBeNull();
        expect(f.laufzeitende).toBe("2024-12-31");
    });

    test("eine Verlängerung von null Monaten zählt als Auslaufvertrag", () => {
        const f = berechneFristen(
            bedingungen({ erstlaufzeitMonate: 36, verlaengerungMonate: 0 }),
            "2026-08-25",
        );
        expect(f.art).toBe("vertragsende");
        expect(f.stichtag).toBe("2026-12-31");
    });
});

describe("Unbefristete Verträge", () => {
    test("Software monatlich, 30 Tage zum Monatsende", () => {
        const f = berechneFristen(
            bedingungen({
                laufzeitmodell: "unbefristet",
                erstlaufzeitMonate: 0,
                verlaengerungMonate: 0,
                kuendigungsfristWert: 30,
                kuendigungsfristEinheit: "tage",
                kuendigungsfristBezug: "zum_monatsende",
            }),
            "2026-08-25",
        );
        // Der 31.08. wäre nur mit Kündigung bis zum 01.08. erreichbar gewesen.
        expect(f.wirksamesVertragsende).toBe("2026-09-30");
        expect(f.stichtag).toBe("2026-08-31");
        expect(f.tageBisStichtag).toBe(6);
    });

    test("Gewerbemiete, 6 Monate zum Quartalsende", () => {
        const f = berechneFristen(
            bedingungen({
                laufzeitmodell: "unbefristet",
                erstlaufzeitMonate: 0,
                verlaengerungMonate: 0,
                kuendigungsfristWert: 6,
                kuendigungsfristEinheit: "monate",
                kuendigungsfristBezug: "zum_quartalsende",
            }),
            "2026-08-25",
        );
        expect(f.wirksamesVertragsende).toBe("2027-03-31");
        expect(f.stichtag).toBe("2026-09-30");
    });

    test("Kündigung zum Jahresende", () => {
        const f = berechneFristen(
            bedingungen({
                laufzeitmodell: "unbefristet",
                erstlaufzeitMonate: 0,
                kuendigungsfristWert: 3,
                kuendigungsfristBezug: "zum_jahresende",
            }),
            "2026-10-01",
        );
        expect(f.stichtag).toBe("2027-09-30");
        expect(f.wirksamesVertragsende).toBe("2027-12-31");
    });

    test("Mindestlaufzeit verschiebt den frühesten Schluss", () => {
        const f = berechneFristen(
            bedingungen({
                beginn: "2026-05-01",
                laufzeitmodell: "unbefristet",
                erstlaufzeitMonate: 24,
                verlaengerungMonate: 0,
                kuendigungsfristWert: 3,
                kuendigungsfristEinheit: "monate",
                kuendigungsfristBezug: "zum_monatsende",
            }),
            "2026-08-25",
        );
        expect(f.laufzeitende).toBe("2028-04-30");
        expect(f.wirksamesVertragsende).toBe("2028-04-30");
        // Rückwärts gerechnet: drei Monate vor dem 30.04. ist der 30.01.
        expect(f.stichtag).toBe("2028-01-30");
        expect(f.hinweis).toContain("Mindestlaufzeit");
    });
});

describe("Jederzeit kündbar", () => {
    test("nennt das Vertragsende statt eines Stichtags", () => {
        const f = berechneFristen(
            bedingungen({
                laufzeitmodell: "unbefristet",
                erstlaufzeitMonate: 0,
                kuendigungsfristWert: 14,
                kuendigungsfristEinheit: "tage",
                kuendigungsfristBezug: "jederzeit",
            }),
            "2026-08-25",
        );
        expect(f.art).toBe("jederzeit_kuendbar");
        expect(f.stichtag).toBeNull();
        expect(f.tageBisStichtag).toBeNull();
        expect(f.wirksamesVertragsende).toBe("2026-09-08");
    });

    test("wartet eine laufende Mindestlaufzeit ab", () => {
        const f = berechneFristen(
            bedingungen({
                beginn: "2026-01-01",
                laufzeitmodell: "unbefristet",
                erstlaufzeitMonate: 12,
                kuendigungsfristWert: 1,
                kuendigungsfristEinheit: "monate",
                kuendigungsfristBezug: "jederzeit",
            }),
            "2026-08-25",
        );
        expect(f.wirksamesVertragsende).toBe("2026-12-31");
        expect(f.laufzeitende).toBe("2026-12-31");
    });
});

describe("Ampel", () => {
    const stufen = (tage: number) =>
        bestimmeAmpel(
            {
                art: "kuendigungsstichtag",
                stichtag: "2026-01-01",
                tageBisStichtag: tage,
                laufzeitende: null,
                wirksamesVertragsende: null,
                verlaengerungenBisher: 0,
                fristVerstrichen: false,
                hinweis: "",
            },
            "aktiv",
        );

    test("staffelt nach verbleibenden Tagen", () => {
        expect(stufen(400)).toBe("ok");
        expect(stufen(90)).toBe("hinweis");
        expect(stufen(45)).toBe("warnung");
        expect(stufen(14)).toBe("kritisch");
        expect(stufen(0)).toBe("kritisch");
    });
});

describe("bewerteVertrag", () => {
    test("aktive Verträge werden überwacht", () => {
        const b = bewerteVertrag(vertrag(), "2026-08-25");
        expect(b.ampel).toBe("warnung");
        expect(b.ueberwachungsdatum).toBe("2026-09-30");
    });

    test("gekündigte Verträge lösen keine Erinnerung mehr aus", () => {
        const b = bewerteVertrag(
            vertrag({ status: "gekuendigt", gekuendigtZum: "2026-12-31" }),
            "2026-08-25",
        );
        expect(b.ampel).toBe("gekuendigt");
        expect(b.ueberwachungsdatum).toBeNull();
        expect(b.fristen.stichtag).toBe("2026-12-31");
        expect(b.fristen.hinweis).toContain("läuft noch bis");
    });

    test("beendete Verträge fallen aus der Überwachung", () => {
        const b = bewerteVertrag(
            vertrag({ status: "beendet", gekuendigtZum: "2025-12-31" }),
            "2026-08-25",
        );
        expect(b.ampel).toBe("beendet");
        expect(b.ueberwachungsdatum).toBeNull();
        expect(b.fristen.art).toBe("keine");
    });

    test("jederzeit kündbare Verträge erzeugen keine Fristwarnung", () => {
        const b = bewerteVertrag(
            vertrag({ kuendigungsfristBezug: "jederzeit", laufzeitmodell: "unbefristet" }),
            "2026-08-25",
        );
        expect(b.ampel).toBe("jederzeit");
        expect(b.ueberwachungsdatum).toBeNull();
    });
});
