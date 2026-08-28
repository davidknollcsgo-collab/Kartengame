// Text der Erinnerungsmail. Reine Textbausteine, damit auch die Browser-Demo
// zeigen kann, was tatsächlich verschickt würde.

import { datumKurz, euro, tageInWorten } from "./formate.ts";
import type { Vertrag } from "./typen.ts";

export function baueSammelmail(
    organisation: string,
    eintraege: { vertrag: Vertrag; stichtag: string; tageBisStichtag: number }[],
    basisAdresse: string,
): { betreff: string; inhalt: string } {
    const dringendste = eintraege[0];
    const betreff =
        eintraege.length === 1 && dringendste
            ? `Kündigungsfrist: ${dringendste.vertrag.bezeichnung} — Stichtag ${datumKurz(dringendste.stichtag)}`
            : `${eintraege.length} Kündigungsfristen im Blick behalten`;

    const zeilen = eintraege.map((e) => {
        const kosten = e.vertrag.betragCent > 0 ? ` — ${euro(e.vertrag.betragCent)}` : "";
        const anbieter = e.vertrag.anbieter ? ` (${e.vertrag.anbieter})` : "";
        return [
            `• ${e.vertrag.bezeichnung}${anbieter}${kosten}`,
            `  Kündigung muss bis ${datumKurz(e.stichtag)} zugehen — ${tageInWorten(e.tageBisStichtag)}.`,
            `  ${basisAdresse}/vertraege/${e.vertrag.id}`,
        ].join("\n");
    });

    const inhalt = [
        `Guten Tag,`,
        ``,
        `für ${organisation} stehen folgende Kündigungsfristen an:`,
        ``,
        ...zeilen,
        ``,
        `Wer nichts unternimmt, verlängert die betroffenen Verträge automatisch.`,
        ``,
        `Übersicht: ${basisAdresse}`,
        ``,
        `— Vertragsfristen-Wächter`,
    ].join("\n");

    return { betreff, inhalt };
}
