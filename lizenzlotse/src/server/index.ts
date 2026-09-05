import { baueApp } from "./app.ts";
import { oeffneDatenbank } from "./datenbank.ts";
import { leseUmgebung } from "./umgebung.ts";

const umgebung = leseUmgebung();
const db = oeffneDatenbank(umgebung.datenbankDatei);
const app = baueApp({ db, umgebung, protokoll: true });

app.listen({ port: umgebung.hafen, host: umgebung.adresse })
    .then((adresse) => app.log.info(`Lizenzlotse läuft auf ${adresse}`))
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
