// iCalendar-Ausgabe. Damit landen die Stichtage in Outlook, Google Kalender
// oder Thunderbird, ohne dass jemand sie abtippt.

import { plusTage, teile, type IsoDatum } from "../fachlogik/datum.ts";
import { bewerteVertrag } from "../fachlogik/fristen.ts";
import { datumKurz, euro, kuendigungsregel } from "../fachlogik/formate.ts";
import { KATEGORIE_TEXT, type Vertrag } from "../fachlogik/typen.ts";

function alsIcsDatum(datum: IsoDatum): string {
    const { jahr, monat, tag } = teile(datum);
    return `${jahr}${String(monat).padStart(2, "0")}${String(tag).padStart(2, "0")}`;
}

function maskiere(text: string): string {
    return text
        .replace(/\\/g, "\\\\")
        .replace(/;/g, "\\;")
        .replace(/,/g, "\\,")
        .replace(/\r?\n/g, "\\n");
}

/** iCalendar erlaubt höchstens 75 Oktette je Zeile. */
function falte(zeile: string): string {
    const bytes = Buffer.from(zeile, "utf8");
    if (bytes.length <= 75) return zeile;
    const teile: string[] = [];
    let rest = bytes;
    let grenze = 75;
    while (rest.length > grenze) {
        // Nicht mitten in ein Mehrbyte-Zeichen schneiden.
        let schnitt = grenze;
        while (schnitt > 0 && (rest[schnitt]! & 0b1100_0000) === 0b1000_0000) schnitt -= 1;
        teile.push(rest.subarray(0, schnitt).toString("utf8"));
        rest = rest.subarray(schnitt);
        grenze = 74;
    }
    teile.push(rest.toString("utf8"));
    return teile.join("\r\n ");
}

export function baueKalender(
    organisationsname: string,
    vertraege: Vertrag[],
    basis: IsoDatum,
    basisAdresse: string,
): string {
    const jetzt = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
    const zeilen: string[] = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Vertragsfristen-Waechter//DE",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        `X-WR-CALNAME:${maskiere(`Kündigungsfristen — ${organisationsname}`)}`,
        "X-WR-TIMEZONE:Europe/Berlin",
    ];

    for (const vertrag of vertraege) {
        const { fristen } = bewerteVertrag(vertrag, basis);
        if (!fristen.stichtag || fristen.art === "keine") continue;
        const kuendigung = fristen.art === "kuendigungsstichtag";
        const titel = kuendigung
            ? `Kündigungsfrist: ${vertrag.bezeichnung}`
            : `Vertragsende: ${vertrag.bezeichnung}`;
        const beschreibung = [
            vertrag.anbieter ? `Anbieter: ${vertrag.anbieter}` : null,
            `Kategorie: ${KATEGORIE_TEXT[vertrag.kategorie]}`,
            vertrag.vertragsnummer ? `Vertragsnummer: ${vertrag.vertragsnummer}` : null,
            vertrag.betragCent > 0 ? `Betrag: ${euro(vertrag.betragCent)}` : null,
            `Frist: ${kuendigungsregel(vertrag)}`,
            fristen.wirksamesVertragsende
                ? `Vertragsende bei Kündigung: ${datumKurz(fristen.wirksamesVertragsende)}`
                : null,
            fristen.hinweis,
            `${basisAdresse}/vertraege/${vertrag.id}`,
        ]
            .filter(Boolean)
            .join("\n");

        zeilen.push(
            "BEGIN:VEVENT",
            `UID:${vertrag.id}-${fristen.stichtag}@vertragsfristen-waechter`,
            `DTSTAMP:${jetzt}`,
            `DTSTART;VALUE=DATE:${alsIcsDatum(fristen.stichtag)}`,
            `DTEND;VALUE=DATE:${alsIcsDatum(plusTage(fristen.stichtag, 1))}`,
            `SUMMARY:${maskiere(titel)}`,
            `DESCRIPTION:${maskiere(beschreibung)}`,
            `URL:${maskiere(`${basisAdresse}/vertraege/${vertrag.id}`)}`,
            "TRANSP:TRANSPARENT",
            "BEGIN:VALARM",
            "TRIGGER:-P14D",
            "ACTION:DISPLAY",
            `DESCRIPTION:${maskiere(titel)}`,
            "END:VALARM",
            "END:VEVENT",
        );
    }

    zeilen.push("END:VCALENDAR");
    return zeilen.map(falte).join("\r\n") + "\r\n";
}
