import { describe, expect, test } from "vitest";
import { csvFeld } from "./csvfeld.ts";

describe("csvFeld", () => {
    test("lässt harmlosen Text unverändert", () => {
        expect(csvFeld("Anna Beispiel")).toBe("Anna Beispiel");
        expect(csvFeld(42)).toBe("42");
        expect(csvFeld(null)).toBe("");
    });

    test("klammert Trennzeichen und Zeilenumbrüche ein", () => {
        expect(csvFeld("Meier; Anna")).toBe('"Meier; Anna"');
        expect(csvFeld('sagte "hallo"')).toBe('"sagte ""hallo"""');
        expect(csvFeld("erste\nzweite")).toBe('"erste\nzweite"');
    });

    test("entschärft Formeln, die Excel sonst ausführt", () => {
        expect(csvFeld("=1+1")).toBe("'=1+1");
        // Ohne Trennzeichen im Text genügt das vorangestellte Hochkomma.
        expect(csvFeld("=cmd|'/c calc'!A1")).toBe("'=cmd|'/c calc'!A1");
        expect(csvFeld("=HYPERLINK(\"http://boes\";\"Rechnung\")")).toBe(
            '"\'=HYPERLINK(""http://boes"";""Rechnung"")"',
        );
        expect(csvFeld("+49 40 123456")).toBe("'+49 40 123456");
        expect(csvFeld("-15,00")).toBe("'-15,00");
        expect(csvFeld("@sonderzeichen")).toBe("'@sonderzeichen");
    });

    test("ein Minus mitten im Text ist harmlos", () => {
        expect(csvFeld("Nord-Werk GmbH")).toBe("Nord-Werk GmbH");
    });
});
