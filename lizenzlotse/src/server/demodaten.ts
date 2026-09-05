// Beispielausgaben eines erfundenen Mandanten.
//
// Bewusst als CSV-Text erzeugt und nicht als fertiger Bestand: So läuft die
// Vorführung durch denselben Import wie echte Daten. Was hier funktioniert,
// funktioniert auch beim Kunden — und ein Fehler im Import fällt schon in der
// Demo auf.

import { plusTage, type IsoDatum } from "../fachlogik/datum.ts";
import type { Quelldatei } from "../fachlogik/import.ts";

const VORNAMEN = [
    "Anna", "Bernd", "Carla", "David", "Elena", "Frank", "Greta", "Hakan", "Inga", "Jonas",
    "Katrin", "Lars", "Maike", "Nils", "Olga", "Peter", "Quirin", "Rita", "Sven", "Tanja",
    "Ulrich", "Vera", "Walter", "Xenia", "Yusuf", "Zoe",
];
const NACHNAMEN = [
    "Albrecht", "Böhm", "Clausen", "Dietrich", "Engel", "Fischer", "Gerber", "Hoffmann",
    "Iversen", "Jansen", "Krüger", "Lehmann", "Möller", "Neumann", "Ortmann", "Peters",
    "Quandt", "Richter", "Schulze", "Thiele", "Ulrich", "Vogel", "Wagner", "Zimmer",
];
const ABTEILUNGEN = ["Vertrieb", "Produktion", "Verwaltung", "IT", "Einkauf", "Lager", "Technik"];

/** Kleiner, wiederholbarer Zufall — dieselbe Demo bei jedem Aufruf. */
function zufall(saat: number): () => number {
    let zustand = saat >>> 0;
    return () => {
        zustand = (zustand * 1_664_525 + 1_013_904_223) >>> 0;
        return zustand / 4_294_967_296;
    };
}

interface Person {
    upn: string;
    name: string;
    abteilung: string;
    gesperrt: boolean;
    lizenzen: string[];
    erstellt: IsoDatum;
    aktivitaet: Partial<Record<"exchange" | "sharepoint" | "onedrive" | "teams" | "office" | "copilot", IsoDatum | null>>;
}

function baueBelegschaft(stichtag: IsoDatum): Person[] {
    const wuerfel = zufall(20260903);
    const personen: Person[] = [];
    const verwendet = new Set<string>();

    const naechsterName = () => {
        for (let versuch = 0; versuch < 200; versuch += 1) {
            const vorname = VORNAMEN[Math.floor(wuerfel() * VORNAMEN.length)]!;
            const nachname = NACHNAMEN[Math.floor(wuerfel() * NACHNAMEN.length)]!;
            const upn = `${vorname}.${nachname}`
                .toLowerCase()
                .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss");
            if (verwendet.has(upn)) continue;
            verwendet.add(upn);
            return { name: `${vorname} ${nachname}`, upn: `${upn}@nordwerk.de` };
        }
        const ersatz = `person${verwendet.size}`;
        verwendet.add(ersatz);
        return { name: `Person ${verwendet.size}`, upn: `${ersatz}@nordwerk.de` };
    };

    const tageHer = (tage: number) => plusTage(stichtag, -tage);
    const abteilung = () => ABTEILUNGEN[Math.floor(wuerfel() * ABTEILUNGEN.length)]!;
    const kuerzlich = () => tageHer(Math.floor(wuerfel() * 5) + 1);

    // 32 unauffällige Vollnutzer.
    for (let i = 0; i < 32; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: abteilung(), gesperrt: false,
            lizenzen: ["Microsoft 365 Business Premium"],
            erstellt: tageHer(400 + Math.floor(wuerfel() * 900)),
            aktivitaet: {
                exchange: kuerzlich(), teams: kuerzlich(), onedrive: kuerzlich(),
                sharepoint: kuerzlich(), office: kuerzlich(),
            },
        });
    }

    // 9 Kolleginnen, die nur E-Mail und Teams brauchen, aber den großen Plan haben.
    for (let i = 0; i < 9; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: "Lager", gesperrt: false,
            lizenzen: ["Microsoft 365 Business Premium"],
            erstellt: tageHer(500 + Math.floor(wuerfel() * 600)),
            aktivitaet: { exchange: kuerzlich(), teams: kuerzlich() },
        });
    }

    // 5 ausgeschiedene, aber noch lizenzierte Konten.
    for (let i = 0; i < 5; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: abteilung(), gesperrt: true,
            lizenzen: i < 2
                ? ["Microsoft 365 Business Premium", "Microsoft 365 Copilot"]
                : ["Microsoft 365 Business Premium"],
            erstellt: tageHer(800 + Math.floor(wuerfel() * 700)),
            aktivitaet: { exchange: tageHer(60 + Math.floor(wuerfel() * 200)) },
        });
    }

    // 4 seit Monaten inaktive Konten, die niemand angefasst hat.
    for (let i = 0; i < 4; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: abteilung(), gesperrt: false,
            lizenzen: ["Microsoft 365 Business Premium"],
            erstellt: tageHer(700 + Math.floor(wuerfel() * 500)),
            aktivitaet: { exchange: tageHer(140 + Math.floor(wuerfel() * 200)) },
        });
    }

    // 3 nie benutzte Konten aus abgebrochenen Einstellungen.
    for (let i = 0; i < 3; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: abteilung(), gesperrt: false,
            lizenzen: ["Microsoft 365 Business Standard"],
            erstellt: tageHer(90 + Math.floor(wuerfel() * 120)),
            aktivitaet: {},
        });
    }

    // 6 Copilot-Lizenzen, von denen nur zwei benutzt werden.
    for (let i = 0; i < 6; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: i < 3 ? "Vertrieb" : "Verwaltung", gesperrt: false,
            lizenzen: ["Microsoft 365 Business Premium", "Microsoft 365 Copilot"],
            erstellt: tageHer(200 + Math.floor(wuerfel() * 300)),
            aktivitaet: {
                exchange: kuerzlich(), teams: kuerzlich(), office: kuerzlich(),
                onedrive: kuerzlich(), sharepoint: kuerzlich(),
                copilot: i < 2 ? kuerzlich() : i < 4 ? tageHer(120 + Math.floor(wuerfel() * 90)) : null,
            },
        });
    }

    // 2 doppelt lizenzierte Konten aus einer Migration.
    for (let i = 0; i < 2; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: "IT", gesperrt: false,
            lizenzen: ["Office 365 E3", "Exchange Online Plan 1"],
            erstellt: tageHer(1100 + Math.floor(wuerfel() * 400)),
            aktivitaet: {
                exchange: kuerzlich(), teams: kuerzlich(), office: kuerzlich(),
                onedrive: kuerzlich(), sharepoint: kuerzlich(),
            },
        });
    }

    // 3 Visio- und Project-Lizenzen aus einem alten Projekt.
    for (let i = 0; i < 3; i += 1) {
        const { name, upn } = naechsterName();
        personen.push({
            upn, name, abteilung: "Technik", gesperrt: false,
            lizenzen: ["Microsoft 365 Business Premium", i === 0 ? "Project Plan 3" : "Visio Plan 2"],
            erstellt: tageHer(600 + Math.floor(wuerfel() * 400)),
            aktivitaet: {
                exchange: kuerzlich(), teams: kuerzlich(), office: kuerzlich(),
                onedrive: kuerzlich(), sharepoint: kuerzlich(),
            },
        });
    }

    return personen;
}

function feld(wert: string | null | undefined): string {
    const text = wert ?? "";
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** Die drei Ausgaben, wie sie aus dem Adminportal kämen. */
export function beispielausgaben(stichtag: IsoDatum): Quelldatei[] {
    const personen = baueBelegschaft(stichtag);

    const benutzer = [
        "User principal name,Display name,Department,Sign-in blocked,Licenses,Created date time",
        ...personen.map((p) =>
            [
                p.upn, p.name, p.abteilung, p.gesperrt ? "true" : "false",
                p.lizenzen.join("+"), `${p.erstellt}T08:00:00Z`,
            ].map(feld).join(","),
        ),
    ].join("\n");

    const nutzung = [
        "User Principal Name,Display Name,Is Deleted,Exchange Last Activity Date," +
        "SharePoint Last Activity Date,OneDrive Last Activity Date,Teams Last Activity Date," +
        "Office 365 Last Activity Date,Copilot Last Activity Date",
        ...personen.map((p) =>
            [
                p.upn, p.name, "False",
                p.aktivitaet.exchange ?? "", p.aktivitaet.sharepoint ?? "", p.aktivitaet.onedrive ?? "",
                p.aktivitaet.teams ?? "", p.aktivitaet.office ?? "", p.aktivitaet.copilot ?? "",
            ].map((wert) => feld(String(wert))).join(","),
        ),
    ].join("\n");

    const zaehle = (produkt: string) =>
        personen.filter((p) => p.lizenzen.includes(produkt)).length;

    const abonnements = [
        "Product name,Purchased quantity,Assigned quantity,Next lifecycle date",
        ...[
            ["Microsoft 365 Business Premium", zaehle("Microsoft 365 Business Premium") + 7],
            ["Microsoft 365 Business Standard", zaehle("Microsoft 365 Business Standard") + 2],
            ["Microsoft 365 Copilot", zaehle("Microsoft 365 Copilot") + 4],
            ["Office 365 E3", zaehle("Office 365 E3")],
            ["Exchange Online Plan 1", zaehle("Exchange Online Plan 1")],
            ["Visio Plan 2", zaehle("Visio Plan 2") + 1],
            ["Project Plan 3", zaehle("Project Plan 3")],
        ].map(([produkt, gekauft]) =>
            [
                String(produkt), String(gekauft), String(zaehle(String(produkt))),
                plusTage(stichtag, 210),
            ].map(feld).join(","),
        ),
    ].join("\n");

    return [
        { name: "benutzer.csv", inhalt: benutzer },
        { name: "nutzung.csv", inhalt: nutzung },
        { name: "abonnements.csv", inhalt: abonnements },
    ];
}
