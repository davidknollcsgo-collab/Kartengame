import { describe, expect, test } from "vitest";
import { beispielvertraege, MUSTER } from "./beispiele.ts";
import { tageBis } from "./datum.ts";
import { bestimmeAmpel, berechneFristen } from "./fristen.ts";

const TAGE = ["2026-08-25", "2027-02-28", "2027-03-01", "2028-02-29", "2029-12-31"];

describe("Beispielbestand", () => {
    test.for(TAGE)("trifft an %s die vorgesehenen Stichtage", (basis) => {
        const bestand = beispielvertraege(basis);
        for (const [nummer, muster] of MUSTER.entries()) {
            if (muster.stichtagInTagen === undefined) continue;
            const vertrag = bestand[nummer]!;
            const fristen = berechneFristen(vertrag, basis);
            expect(
                { name: muster.bezeichnung, tage: fristen.tageBisStichtag },
                `${muster.bezeichnung} (Beginn ${vertrag.beginn})`,
            ).toEqual({ name: muster.bezeichnung, tage: muster.stichtagInTagen });
        }
    });

    test.for(TAGE)("zeigt an %s alle Dringlichkeitsstufen", (basis) => {
        const stufen = new Set(
            beispielvertraege(basis).map((vertrag) =>
                bestimmeAmpel(berechneFristen(vertrag, basis), vertrag.status),
            ),
        );
        for (const erwartet of ["kritisch", "warnung", "hinweis", "ok", "jederzeit"]) {
            expect(stufen, `Stufe ${erwartet} fehlt`).toContain(erwartet);
        }
    });

    test("beginnt in der Vergangenheit, wie ein gewachsener Bestand", () => {
        const basis = "2026-08-25";
        for (const vertrag of beispielvertraege(basis)) {
            expect(tageBis(vertrag.beginn, basis), vertrag.bezeichnung).toBeGreaterThan(0);
        }
    });
});
