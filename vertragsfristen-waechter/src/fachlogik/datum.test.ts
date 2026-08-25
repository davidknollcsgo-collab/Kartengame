import { describe, expect, test } from "vitest";
import {
    heute,
    istIsoDatum,
    jahresEnde,
    letzterTagImMonat,
    monatsEnde,
    plusMonate,
    plusTage,
    quartalsEnde,
    tageBis,
} from "./datum.ts";

describe("istIsoDatum", () => {
    test("nimmt gültige Kalendertage an", () => {
        expect(istIsoDatum("2026-02-28")).toBe(true);
        expect(istIsoDatum("2024-02-29")).toBe(true);
    });

    test("weist Unfug ab", () => {
        expect(istIsoDatum("2026-02-30")).toBe(false);
        expect(istIsoDatum("2025-02-29")).toBe(false);
        expect(istIsoDatum("2026-13-01")).toBe(false);
        expect(istIsoDatum("26-01-01")).toBe(false);
        expect(istIsoDatum("")).toBe(false);
        expect(istIsoDatum(null)).toBe(false);
    });
});

describe("plusMonate", () => {
    test("hält den Tag im Monat", () => {
        expect(plusMonate("2026-01-15", 3)).toBe("2026-04-15");
        expect(plusMonate("2026-01-15", -1)).toBe("2025-12-15");
    });

    test("kappt auf den letzten Tag des Zielmonats", () => {
        expect(plusMonate("2026-01-31", 1)).toBe("2026-02-28");
        expect(plusMonate("2024-01-31", 1)).toBe("2024-02-29");
        expect(plusMonate("2026-03-31", -1)).toBe("2026-02-28");
    });

    test("rechnet über Jahresgrenzen", () => {
        expect(plusMonate("2026-11-30", 14)).toBe("2028-01-30");
        expect(plusMonate("2026-01-01", -13)).toBe("2024-12-01");
    });

    test("drei Monate vor Silvester ist der 30. September", () => {
        expect(plusMonate("2026-12-31", -3)).toBe("2026-09-30");
    });
});

describe("Periodenenden", () => {
    test("Monatsende", () => {
        expect(monatsEnde("2026-02-01")).toBe("2026-02-28");
        expect(monatsEnde("2024-02-13")).toBe("2024-02-29");
    });

    test("Quartalsende", () => {
        expect(quartalsEnde("2026-01-01")).toBe("2026-03-31");
        expect(quartalsEnde("2026-04-30")).toBe("2026-06-30");
        expect(quartalsEnde("2026-11-02")).toBe("2026-12-31");
    });

    test("Jahresende", () => {
        expect(jahresEnde("2026-05-05")).toBe("2026-12-31");
    });

    test("letzterTagImMonat kennt Schaltjahre", () => {
        expect(letzterTagImMonat(2024, 2)).toBe(29);
        expect(letzterTagImMonat(2100, 2)).toBe(28);
        expect(letzterTagImMonat(2026, 12)).toBe(31);
    });
});

describe("tageBis", () => {
    test("zählt ganze Kalendertage", () => {
        expect(tageBis("2026-01-01", "2026-01-31")).toBe(30);
        expect(tageBis("2026-01-31", "2026-01-01")).toBe(-30);
        expect(tageBis("2026-01-01", "2026-01-01")).toBe(0);
    });

    test("ist von der Sommerzeitumstellung unbeeindruckt", () => {
        // Die Nacht zum 29.03.2026 hat in Berlin nur 23 Stunden.
        expect(tageBis("2026-03-28", "2026-03-30")).toBe(2);
        expect(plusTage("2026-03-28", 2)).toBe("2026-03-30");
    });
});

describe("heute", () => {
    test("richtet sich nach deutscher Ortszeit, nicht nach UTC", () => {
        // 22:30 UTC ist in Berlin bereits der Folgetag.
        const jetzt = new Date("2026-06-30T22:30:00Z");
        expect(heute(jetzt, "Europe/Berlin")).toBe("2026-07-01");
        expect(heute(jetzt, "UTC")).toBe("2026-06-30");
    });
});
