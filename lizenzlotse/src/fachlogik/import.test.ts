import { describe, expect, test } from "vitest";
import { werteAus } from "./analyse.ts";
import {
    alsDatum,
    baueBestand,
    erkenneSku,
    erkenneTabellenart,
    zerlegeCsv,
} from "./import.ts";
import { preisliste } from "./skus.ts";

const STICHTAG = "2026-09-03";

const BENUTZER_ENGLISCH = `User principal name,Display name,Department,Sign-in blocked,Licenses,Created date time
anna@beispiel.de,Anna Beispiel,Vertrieb,false,Office 365 E3+Microsoft 365 Copilot,2021-04-01T08:00:00Z
bert@beispiel.de,Bert Beispiel,Lager,true,Office 365 E3,2019-02-11T08:00:00Z
`;

const BENUTZER_DEUTSCH = `Benutzerprinzipalname;Anzeigename;Abteilung;Anmeldung blockiert;Lizenzen;Erstellungsdatum
carla@beispiel.de;Carla Beispiel;Buchhaltung;Nein;Microsoft 365 Business Premium;01.03.2020
`;

const NUTZUNG = `User Principal Name,Display Name,Is Deleted,Exchange Last Activity Date,SharePoint Last Activity Date,OneDrive Last Activity Date,Teams Last Activity Date,Office 365 Last Activity Date,Copilot Last Activity Date
anna@beispiel.de,Anna Beispiel,False,2026-09-02,2026-08-30,2026-08-30,2026-09-01,2026-09-01,
bert@beispiel.de,Bert Beispiel,False,2025-01-04,,,,,
carla@beispiel.de,Carla Beispiel,False,2026-09-01,,,2026-09-01,,
`;

const ABONNEMENTS = `Product name,Purchased quantity,Assigned quantity,Next lifecycle date
Office 365 E3,12,2,2027-04-30
Microsoft 365 Copilot,3,1,2027-04-30
Microsoft 365 Business Premium,5,1,2027-04-30
`;

function importiere(...dateien: { name: string; inhalt: string }[]) {
    return baueBestand(dateien, STICHTAG);
}

describe("CSV-Zerlegung", () => {
    test("erkennt Komma und Semikolon", () => {
        expect(zerlegeCsv("a,b\n1,2\n").kopf).toEqual(["a", "b"]);
        expect(zerlegeCsv("a;b\n1;2\n").zeilen).toEqual([["1", "2"]]);
    });

    test("versteht Anführungszeichen und eingebettete Trenner", () => {
        const tabelle = zerlegeCsv('name,ort\n"Meier, Anna","Köln"\n');
        expect(tabelle.zeilen[0]).toEqual(["Meier, Anna", "Köln"]);
    });

    test("verdoppelte Anführungszeichen bleiben ein Zeichen", () => {
        expect(zerlegeCsv('a\n"sagte ""hallo"""\n').zeilen[0]).toEqual(['sagte "hallo"']);
    });

    test("verträgt BOM, CRLF und Leerzeilen", () => {
        const tabelle = zerlegeCsv('﻿a,b\r\n1,2\r\n\r\n3,4\r\n');
        expect(tabelle.kopf).toEqual(["a", "b"]);
        expect(tabelle.zeilen).toHaveLength(2);
    });
});

describe("Datumserkennung", () => {
    test("nimmt ISO, Zeitstempel und deutsches Format", () => {
        expect(alsDatum("2026-09-03")).toBe("2026-09-03");
        expect(alsDatum("2026-09-03T14:22:01Z")).toBe("2026-09-03");
        expect(alsDatum("3.9.2026")).toBe("2026-09-03");
        expect(alsDatum("03.09.2026")).toBe("2026-09-03");
    });

    test("gibt bei Unsinn null zurück statt zu raten", () => {
        expect(alsDatum("")).toBeNull();
        expect(alsDatum("nie")).toBeNull();
        expect(alsDatum("31.02.2026")).toBeNull();
    });
});

describe("Produkterkennung", () => {
    test("übersetzt Klarnamen und Kennungen", () => {
        expect(erkenneSku("Office 365 E3")).toBe("ENTERPRISEPACK");
        expect(erkenneSku("ENTERPRISEPACK")).toBe("ENTERPRISEPACK");
        expect(erkenneSku("Microsoft 365 Business Standard")).toBe("O365_BUSINESS_PREMIUM");
        expect(erkenneSku("  microsoft 365 copilot ")).toBe("Microsoft_365_Copilot");
    });

    test("behält Unbekanntes bei, statt es wegzuwerfen", () => {
        expect(erkenneSku("Irgendein neues Produkt")).toBe("Irgendein neues Produkt");
    });
});

describe("Dateierkennung", () => {
    test("unterscheidet die drei Ausgaben", () => {
        expect(erkenneTabellenart(zerlegeCsv(BENUTZER_ENGLISCH).kopf)).toBe("konten");
        expect(erkenneTabellenart(zerlegeCsv(NUTZUNG).kopf)).toBe("nutzung");
        expect(erkenneTabellenart(zerlegeCsv(ABONNEMENTS).kopf)).toBe("abonnements");
        expect(erkenneTabellenart(zerlegeCsv("foo,bar\n1,2\n").kopf)).toBe("unbekannt");
    });
});

describe("Zusammenbau des Bestands", () => {
    test("führt Benutzer- und Nutzungsliste über die Adresse zusammen", () => {
        const { bestand } = importiere(
            { name: "benutzer.csv", inhalt: BENUTZER_ENGLISCH },
            { name: "nutzung.csv", inhalt: NUTZUNG },
        );
        const anna = bestand.konten.find((k) => k.upn === "anna@beispiel.de")!;
        expect(anna.skus).toEqual(["ENTERPRISEPACK", "Microsoft_365_Copilot"]);
        expect(anna.letzteAktivitaet.exchange).toBe("2026-09-02");
        expect(anna.letzteAktivitaet.copilot).toBeUndefined();
        expect(anna.erstelltAm).toBe("2021-04-01");
        expect(anna.abteilung).toBe("Vertrieb");
    });

    test("die Reihenfolge der Dateien spielt keine Rolle", () => {
        const a = importiere(
            { name: "benutzer.csv", inhalt: BENUTZER_ENGLISCH },
            { name: "nutzung.csv", inhalt: NUTZUNG },
        );
        const b = importiere(
            { name: "nutzung.csv", inhalt: NUTZUNG },
            { name: "benutzer.csv", inhalt: BENUTZER_ENGLISCH },
        );
        const skus = (e: typeof a) =>
            e.bestand.konten.find((k) => k.upn === "anna@beispiel.de")!.skus;
        const aktivitaet = (e: typeof a) =>
            e.bestand.konten.find((k) => k.upn === "anna@beispiel.de")!.letzteAktivitaet.exchange;
        expect(skus(a)).toEqual(skus(b));
        expect(aktivitaet(a)).toEqual(aktivitaet(b));
    });

    test("versteht die deutsche Ausgabe mit Semikolon und Ja/Nein", () => {
        const { bestand } = importiere({ name: "benutzer.csv", inhalt: BENUTZER_DEUTSCH });
        const carla = bestand.konten[0]!;
        expect(carla.anzeigename).toBe("Carla Beispiel");
        expect(carla.gesperrt).toBe(false);
        expect(carla.skus).toEqual(["SPB"]);
        expect(carla.erstelltAm).toBe("2020-03-01");
    });

    test("erkennt gesperrte Konten", () => {
        const { bestand } = importiere({ name: "benutzer.csv", inhalt: BENUTZER_ENGLISCH });
        expect(bestand.konten.find((k) => k.upn === "bert@beispiel.de")!.gesperrt).toBe(true);
    });

    test("liest Abonnements samt Verlängerungstermin", () => {
        const { bestand } = importiere({ name: "abos.csv", inhalt: ABONNEMENTS });
        expect(bestand.abonnements).toHaveLength(3);
        const e3 = bestand.abonnements.find((a) => a.sku === "ENTERPRISEPACK")!;
        expect(e3).toMatchObject({ gekauft: 12, zugewiesen: 2, laufzeitEnde: "2027-04-30" });
    });

    test("warnt, wenn Nutzungsdaten oder Abonnements fehlen", () => {
        const nurBenutzer = importiere({ name: "benutzer.csv", inhalt: BENUTZER_ENGLISCH });
        expect(nurBenutzer.warnungen.join(" ")).toContain("Nutzung");
        expect(nurBenutzer.warnungen.join(" ")).toContain("Abonnement");
    });

    test("meldet unbekannte Dateien, statt sie stillschweigend zu verschlucken", () => {
        const ergebnis = importiere({ name: "urlaub.csv", inhalt: "foo,bar\n1,2\n" });
        expect(ergebnis.dateien[0]!.art).toBe("unbekannt");
        expect(ergebnis.warnungen.join(" ")).toContain("urlaub.csv");
    });
});

describe("Import und Auswertung zusammen", () => {
    test("aus drei Ausgaben wird ein Bericht mit Beträgen", () => {
        const { bestand } = importiere(
            { name: "benutzer.csv", inhalt: BENUTZER_ENGLISCH },
            { name: "nutzung.csv", inhalt: NUTZUNG },
            { name: "abos.csv", inhalt: ABONNEMENTS },
        );
        const ergebnis = werteAus(bestand, preisliste());
        const arten = ergebnis.befunde.map((b) => b.art);

        // Bert ist gesperrt und hat noch E3.
        expect(arten).toContain("gesperrt_lizenziert");
        // Anna hat Copilot, nutzt es aber nie.
        expect(arten).toContain("ungenutztes_zusatzprodukt");
        // Zehn E3-Plätze liegen im Regal.
        const regal = ergebnis.befunde.find(
            (b) => b.art === "regallizenz" && b.sku === "ENTERPRISEPACK",
        )!;
        expect(regal.anzahl).toBe(10);

        expect(ergebnis.ersparnisCentMonat).toBeGreaterThan(0);
        expect(ergebnis.ersparnisSicherCentMonat + ergebnis.ersparnisPruefenCentMonat).toBe(
            ergebnis.ersparnisCentMonat,
        );
    });
});
