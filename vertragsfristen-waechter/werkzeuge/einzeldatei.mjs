// Fasst den Demo-Build zu einer einzigen HTML-Datei zusammen.
//
// Vite legt Skript und Stil getrennt ab; für eine Datei, die sich irgendwo
// öffnen oder veröffentlichen lässt, wandern beide in die Seite hinein.
// Ausgegeben wird ein Seitenrumpf ohne <html>, <head> und <body>: so
// erwartet es die Artefakt-Veröffentlichung, und ein Browser stellt es
// trotzdem dar.

import { readFile, readdir, writeFile } from "node:fs/promises";
import { join } from "node:path";

const ordner = "bau/demo";
const ziel = join(ordner, "vertragsfristen-waechter.html");

const seite = await readFile(join(ordner, "index.html"), "utf8");
const dateien = await readdir(join(ordner, "assets"));

async function lies(endung) {
    const treffer = dateien.find((datei) => datei.endsWith(endung));
    if (!treffer) throw new Error(`Keine ${endung}-Datei im Demo-Build gefunden`);
    return await readFile(join(ordner, "assets", treffer), "utf8");
}

const stil = await lies(".css");
const skript = await lies(".js");

const schriften = /<link rel="stylesheet" href="https:\/\/fonts\.googleapis\.com[^>]*>/.exec(seite);

const inhalt = `<title>Vertragsfristen-Wächter</title>
<meta name="description" content="Überwacht Kündigungsfristen von Versicherungen, Software-Abos, Miet- und Wartungsverträgen." />
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
${schriften ? schriften[0] : ""}
<style>
${stil}
</style>
<div id="wurzel"></div>
<script type="module">
${skript.replaceAll("</script", "<\\/script")}
</script>
`;

await writeFile(ziel, inhalt, "utf8");
const groesse = (Buffer.byteLength(inhalt) / 1024).toFixed(0);
console.log(`${ziel} geschrieben (${groesse} kB)`);
