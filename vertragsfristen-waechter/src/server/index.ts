// Startpunkt des Servers.

import { oeffneDatenbank } from "./datenbank.ts";
import { baueApp, startePlaner } from "./app.ts";
import { leseUmgebung } from "./umgebung.ts";

const umgebung = leseUmgebung();
const db = oeffneDatenbank(umgebung.datenbankDatei);
const app = baueApp({ db, umgebung, protokoll: true });

startePlaner(db, umgebung, app.log);

app.listen({ port: umgebung.hafen, host: umgebung.adresse })
    .then((adresse) => {
        app.log.info(`Vertragsfristen-Wächter läuft auf ${adresse}`);
        if (!umgebung.smtpUrl) {
            app.log.info(
                "Kein SMTP_URL gesetzt — Erinnerungen bleiben im Postausgang und werden nicht versendet.",
            );
        }
    })
    .catch((fehler: unknown) => {
        app.log.error(fehler);
        process.exit(1);
    });

for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
        app.close().finally(() => {
            db.close();
            process.exit(0);
        });
    });
}
