import { describe, expect, test } from "vitest";
import { STANDARD_REGELWERK, werteAus, type Preis } from "./analyse.ts";
import { plusTage } from "./datum.ts";
import { preisliste } from "./skus.ts";
import type { Abonnement, Konto } from "./typen.ts";

const HEUTE = "2026-09-03";
const preis: Preis = preisliste();

function konto(teil: Partial<Konto> = {}): Konto {
    return {
        id: teil.upn ?? "k1",
        upn: "anna@beispiel.de",
        anzeigename: "Anna Beispiel",
        abteilung: "Vertrieb",
        gesperrt: false,
        erstelltAm: "2023-01-01",
        letzteAktivitaet: { exchange: plusTage(HEUTE, -1) },
        skus: ["ENTERPRISEPACK"],
        ...teil,
    };
}

function abo(teil: Partial<Abonnement> = {}): Abonnement {
    return { sku: "ENTERPRISEPACK", gekauft: 10, zugewiesen: 10, laufzeitEnde: null, ...teil };
}

function werte(konten: Konto[], abonnements: Abonnement[] = []) {
    return werteAus({ stichtag: HEUTE, konten, abonnements }, preis);
}

describe("Gesperrte Konten", () => {
    test("werden mit voller Lizenzsumme gemeldet", () => {
        const ergebnis = werte([konto({ gesperrt: true, skus: ["ENTERPRISEPACK", "VISIOCLIENT"] })]);
        expect(ergebnis.befunde).toHaveLength(1);
        const befund = ergebnis.befunde[0]!;
        expect(befund.art).toBe("gesperrt_lizenziert");
        expect(befund.sicherheit).toBe("sicher");
        expect(befund.ersparnisCentMonat).toBe(2550 + 1640);
        expect(befund.anzahl).toBe(2);
    });

    test("zählen nicht zusätzlich als inaktiv", () => {
        const ergebnis = werte([
            konto({ gesperrt: true, letzteAktivitaet: { exchange: "2020-01-01" } }),
        ]);
        expect(ergebnis.befunde.map((b) => b.art)).toEqual(["gesperrt_lizenziert"]);
    });

    test("ohne Lizenz kosten sie nichts und fallen nicht auf", () => {
        expect(werte([konto({ gesperrt: true, skus: [] })]).befunde).toHaveLength(0);
    });
});

describe("Ungenutzte Konten", () => {
    test("nie aktiv und alt genug fällt auf", () => {
        const ergebnis = werte([
            konto({ letzteAktivitaet: {}, erstelltAm: plusTage(HEUTE, -60) }),
        ]);
        expect(ergebnis.befunde[0]!.art).toBe("nie_aktiv");
        expect(ergebnis.befunde[0]!.sicherheit).toBe("pruefen");
    });

    test("frisch angelegte Konten bekommen Zeit", () => {
        const ergebnis = werte([
            konto({ letzteAktivitaet: {}, erstelltAm: plusTage(HEUTE, -10) }),
        ]);
        expect(ergebnis.befunde).toHaveLength(0);
    });

    test("lange Inaktivität fällt auf, kurze nicht", () => {
        const lange = werte([konto({ letzteAktivitaet: { exchange: plusTage(HEUTE, -200) } })]);
        expect(lange.befunde[0]!.art).toBe("inaktiv");
        expect(lange.befunde[0]!.ersparnisCentMonat).toBe(2550);

        // Aktiv genug: der Abstufungsbefund bleibt, der Inaktivitätsbefund nicht.
        const kurz = werte([konto({ letzteAktivitaet: { exchange: plusTage(HEUTE, -30) } })]);
        expect(kurz.befunde.filter((b) => b.art === "inaktiv")).toHaveLength(0);
    });

    test("die jüngste Aktivität über alle Dienste zählt", () => {
        const ergebnis = werte([
            konto({
                letzteAktivitaet: {
                    exchange: plusTage(HEUTE, -300),
                    teams: plusTage(HEUTE, -2),
                },
            }),
        ]);
        expect(ergebnis.befunde.filter((b) => b.art === "inaktiv")).toHaveLength(0);
    });

    test("genau an der Schwelle gilt das Konto noch als aktiv", () => {
        const ergebnis = werte([
            konto({
                letzteAktivitaet: { exchange: plusTage(HEUTE, -STANDARD_REGELWERK.inaktivTage) },
            }),
        ]);
        expect(ergebnis.befunde.filter((b) => b.art === "inaktiv")).toHaveLength(0);
    });
});

describe("Regallizenzen", () => {
    test("nicht zugewiesene Plätze werden beziffert", () => {
        const ergebnis = werte([], [abo({ gekauft: 10, zugewiesen: 6 })]);
        const befund = ergebnis.befunde[0]!;
        expect(befund.art).toBe("regallizenz");
        expect(befund.anzahl).toBe(4);
        expect(befund.ersparnisCentMonat).toBe(4 * 2550);
        expect(befund.sicherheit).toBe("sicher");
    });

    test("eine kleine Reserve gilt als erklärungsbedürftig, nicht als sicher", () => {
        const ergebnis = werte([], [abo({ gekauft: 10, zugewiesen: 8 })]);
        expect(ergebnis.befunde[0]!.sicherheit).toBe("pruefen");
    });

    test("voll zugewiesene Abonnements erzeugen keinen Befund", () => {
        expect(werte([], [abo({ gekauft: 10, zugewiesen: 10 })]).befunde).toHaveLength(0);
    });

    test("der Verlängerungstermin steht in der Empfehlung", () => {
        const ergebnis = werte([], [abo({ gekauft: 10, zugewiesen: 3, laufzeitEnde: "2027-03-31" })]);
        expect(ergebnis.befunde[0]!.empfehlung).toContain("31.03.2027");
    });
});

describe("Doppelte Lizenzen", () => {
    test("der günstigere Basisplan gilt als überzählig", () => {
        const ergebnis = werte([konto({ skus: ["ENTERPRISEPACK", "EXCHANGESTANDARD"] })]);
        const befund = ergebnis.befunde.find((b) => b.art === "doppelte_lizenz")!;
        expect(befund.ersparnisCentMonat).toBe(440);
        expect(befund.zielSku).toBe("ENTERPRISEPACK");
        expect(befund.sicherheit).toBe("sicher");
    });

    test("verdrängt die Abstufungsempfehlung, damit nichts doppelt zählt", () => {
        const ergebnis = werte([konto({ skus: ["ENTERPRISEPACK", "EXCHANGESTANDARD"] })]);
        expect(ergebnis.befunde.map((b) => b.art)).toEqual(["doppelte_lizenz"]);
    });

    test("ein einzelner Basisplan plus Zusatzprodukt ist kein Doppel", () => {
        const ergebnis = werte([konto({ skus: ["ENTERPRISEPACK", "POWER_BI_PRO"] })]);
        expect(ergebnis.befunde.filter((b) => b.art === "doppelte_lizenz")).toHaveLength(0);
    });
});

describe("Zusatzprodukte", () => {
    test("nie genutztes Copilot gilt als sicher", () => {
        const ergebnis = werte([konto({ skus: ["ENTERPRISEPACK", "Microsoft_365_Copilot"] })]);
        const befund = ergebnis.befunde.find((b) => b.art === "ungenutztes_zusatzprodukt")!;
        expect(befund.sicherheit).toBe("sicher");
        expect(befund.ersparnisCentMonat).toBe(3150);
        expect(befund.begruendung).toContain("keinerlei Nutzung");
    });

    test("kürzlich genutztes Copilot erzeugt keinen Befund", () => {
        const ergebnis = werte([
            konto({
                skus: ["ENTERPRISEPACK", "Microsoft_365_Copilot"],
                letzteAktivitaet: { exchange: plusTage(HEUTE, -1), copilot: plusTage(HEUTE, -3) },
            }),
        ]);
        expect(ergebnis.befunde.filter((b) => b.art === "ungenutztes_zusatzprodukt")).toHaveLength(0);
    });

    test("lange nicht genutztes Copilot will geprüft werden", () => {
        const ergebnis = werte([
            konto({
                skus: ["ENTERPRISEPACK", "Microsoft_365_Copilot"],
                letzteAktivitaet: { exchange: plusTage(HEUTE, -1), copilot: plusTage(HEUTE, -120) },
            }),
        ]);
        expect(ergebnis.befunde.find((b) => b.art === "ungenutztes_zusatzprodukt")!.sicherheit).toBe(
            "pruefen",
        );
    });
});

describe("Abstufungen", () => {
    test("wer nur E-Mail nutzt, braucht kein E3", () => {
        const ergebnis = werte([konto({ letzteAktivitaet: { exchange: plusTage(HEUTE, -1) } })]);
        const befund = ergebnis.befunde.find((b) => b.art === "ueberdimensioniert")!;
        expect(befund.zielSku).toBe("EXCHANGESTANDARD");
        expect(befund.ersparnisCentMonat).toBe(2550 - 440);
        expect(befund.sicherheit).toBe("pruefen");
    });

    test("wer Office-Anwendungen nutzt, behält seinen Plan", () => {
        const ergebnis = werte([
            konto({
                letzteAktivitaet: {
                    exchange: plusTage(HEUTE, -1),
                    office: plusTage(HEUTE, -2),
                    teams: plusTage(HEUTE, -1),
                    onedrive: plusTage(HEUTE, -1),
                    sharepoint: plusTage(HEUTE, -1),
                },
            }),
        ]);
        expect(ergebnis.befunde.filter((b) => b.art === "ueberdimensioniert")).toHaveLength(0);
    });

    test("Business Premium wird auf Business Basic abgestuft, wenn Office fehlt", () => {
        const ergebnis = werte([
            konto({
                skus: ["SPB"],
                letzteAktivitaet: { exchange: plusTage(HEUTE, -1), teams: plusTage(HEUTE, -1) },
            }),
        ]);
        const befund = ergebnis.befunde.find((b) => b.art === "ueberdimensioniert")!;
        expect(befund.zielSku).toBe("O365_BUSINESS_ESSENTIALS");
        expect(befund.ersparnisCentMonat).toBe(2610 - 750);
    });
});

describe("Summen und Vorsicht", () => {
    test("sichere und zu prüfende Ersparnis werden getrennt ausgewiesen", () => {
        const ergebnis = werte(
            [
                konto({ id: "a", upn: "a@b.de", gesperrt: true }),
                konto({ id: "b", upn: "b@b.de", letzteAktivitaet: { exchange: plusTage(HEUTE, -1) } }),
            ],
            [],
        );
        expect(ergebnis.ersparnisSicherCentMonat).toBe(2550);
        expect(ergebnis.ersparnisPruefenCentMonat).toBe(2550 - 440);
        expect(ergebnis.ersparnisCentMonat).toBe(
            ergebnis.ersparnisSicherCentMonat + ergebnis.ersparnisPruefenCentMonat,
        );
    });

    test("unbekannte Produkte werden nicht mit erfundenen Preisen bewertet", () => {
        const ergebnis = werte([konto({ gesperrt: true, skus: ["IRGENDWAS_NEUES"] })]);
        expect(ergebnis.befunde[0]?.ersparnisCentMonat ?? 0).toBe(0);
    });

    test("eigene Preise überschreiben den Katalog", () => {
        const eigen = preisliste({ ENTERPRISEPACK: 1000 });
        const ergebnis = werteAus(
            { stichtag: HEUTE, konten: [konto({ gesperrt: true })], abonnements: [] },
            eigen,
        );
        expect(ergebnis.befunde[0]!.ersparnisCentMonat).toBe(1000);
    });

    test("Befund-Kennungen bleiben über Läufe hinweg gleich", () => {
        const erste = werte([konto({ gesperrt: true })]).befunde[0]!.id;
        const zweite = werte([konto({ gesperrt: true })]).befunde[0]!.id;
        expect(erste).toBe(zweite);
        expect(erste).toContain("gesperrt_lizenziert");
    });

    test("Befunde stehen nach Ersparnis sortiert", () => {
        const ergebnis = werte(
            [
                konto({ id: "klein", upn: "k@b.de", gesperrt: true, skus: ["EXCHANGESTANDARD"] }),
                konto({ id: "gross", upn: "g@b.de", gesperrt: true, skus: ["SPE_E5"] }),
            ],
            [],
        );
        expect(ergebnis.befunde.map((b) => b.ersparnisCentMonat)).toEqual([6250, 440]);
    });

    test("laufende Lizenzkosten rechnen mit gekauften, nicht zugewiesenen Plätzen", () => {
        const ergebnis = werte([], [abo({ gekauft: 10, zugewiesen: 6 })]);
        expect(ergebnis.lizenzkostenCentMonat).toBe(10 * 2550);
    });
});

describe("Grenzen der Abstufung", () => {
    test("gleicher Dienstumfang ist kein Grund für eine Abstufung", () => {
        // Business Premium und Business Standard schalten dieselben Dienste
        // frei; der Preisunterschied steckt in Sicherheit und Verwaltung.
        const ergebnis = werte([
            konto({
                skus: ["SPB"],
                letzteAktivitaet: {
                    exchange: plusTage(HEUTE, -1),
                    teams: plusTage(HEUTE, -1),
                    onedrive: plusTage(HEUTE, -1),
                    sharepoint: plusTage(HEUTE, -1),
                    office: plusTage(HEUTE, -1),
                },
            }),
        ]);
        expect(ergebnis.befunde).toHaveLength(0);
    });

    test("ein nachweislich ungenutzter Dienst rechtfertigt sie sehr wohl", () => {
        const ergebnis = werte([
            konto({
                skus: ["SPB"],
                letzteAktivitaet: { exchange: plusTage(HEUTE, -1), teams: plusTage(HEUTE, -1) },
            }),
        ]);
        const befund = ergebnis.befunde.find((b) => b.art === "ueberdimensioniert")!;
        expect(befund.zielSku).toBe("O365_BUSINESS_ESSENTIALS");
        expect(befund.begruendung).toContain("Office-Anwendungen");
    });
});

describe("Sprache", () => {
    test("ein einzelner Platz steht nicht im Plural", () => {
        const ergebnis = werte([], [abo({ gekauft: 11, zugewiesen: 10 })]);
        expect(ergebnis.befunde[0]!.titel).toContain("1 Platz unbenutzt");
        expect(ergebnis.befunde[0]!.titel).not.toContain("1 Plätze");
    });
});
