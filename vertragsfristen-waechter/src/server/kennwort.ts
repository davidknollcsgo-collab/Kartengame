// Kennwörter werden mit scrypt gehasht — bewusst kein externes Paket, die
// Bausteine dafür bringt Node mit.

import { createHash, randomBytes, scrypt, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";

const scryptAsync = promisify(scrypt) as (
    kennwort: string,
    salz: Buffer,
    laenge: number,
    optionen: { N: number; r: number; p: number },
) => Promise<Buffer>;

const PARAMETER = { N: 16_384, r: 8, p: 1 };
const LAENGE = 64;

export async function hashe(kennwort: string): Promise<string> {
    const salz = randomBytes(16);
    const abgeleitet = await scryptAsync(kennwort.normalize("NFKC"), salz, LAENGE, PARAMETER);
    return `scrypt$${PARAMETER.N}$${PARAMETER.r}$${PARAMETER.p}$${salz.toString("base64")}$${abgeleitet.toString("base64")}`;
}

export async function stimmt(kennwort: string, gespeichert: string): Promise<boolean> {
    const teile = gespeichert.split("$");
    if (teile.length !== 6 || teile[0] !== "scrypt") return false;
    const [, n, r, p, salz, hash] = teile as [string, string, string, string, string, string];
    const erwartet = Buffer.from(hash, "base64");
    const abgeleitet = await scryptAsync(kennwort.normalize("NFKC"), Buffer.from(salz, "base64"), erwartet.length, {
        N: Number(n),
        r: Number(r),
        p: Number(p),
    });
    return abgeleitet.length === erwartet.length && timingSafeEqual(abgeleitet, erwartet);
}

/** Sitzungsmarken werden nur als Hash gespeichert. */
export function markenHash(marke: string): string {
    return createHash("sha256").update(marke).digest("hex");
}
