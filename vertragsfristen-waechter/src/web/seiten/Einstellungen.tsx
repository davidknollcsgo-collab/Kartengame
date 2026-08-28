import { useState, type FormEvent } from "react";
import { api } from "../api.ts";
import { Karte } from "../teile/bausteine.tsx";
import type { Anmeldedaten, Fehler } from "../typen.ts";

export function Einstellungen({
    anmeldung,
    neuLaden,
}: {
    anmeldung: Anmeldedaten;
    neuLaden: () => Promise<void>;
}) {
    const [name, setName] = useState(anmeldung.organisation.name);
    const [vorlauf, setVorlauf] = useState(anmeldung.organisation.erinnerungsvorlauf.join(", "));
    const [verteiler, setVerteiler] = useState(anmeldung.organisation.verteiler.join(", "));
    const [kalender, setKalender] = useState(anmeldung.kalenderAdresse);
    const [meldung, setMeldung] = useState<string | null>(null);
    const [fehler, setFehler] = useState<string | null>(null);

    async function speichern(ereignis: FormEvent) {
        ereignis.preventDefault();
        setFehler(null);
        setMeldung(null);
        try {
            await api.organisationSpeichern({
                name,
                erinnerungsvorlauf: vorlauf
                    .split(/[,\s]+/)
                    .map((teil) => Number(teil.trim()))
                    .filter((zahl) => Number.isFinite(zahl) && zahl >= 0),
                verteiler: verteiler
                    .split(/[,\s]+/)
                    .map((teil) => teil.trim())
                    .filter(Boolean),
            });
            await neuLaden();
            setMeldung("Gespeichert.");
        } catch (problem) {
            setFehler((problem as Fehler).message);
        }
    }

    return (
        <>
            <header className="seitenkopf">
                <div>
                    <h1>Einstellungen</h1>
                    <p>Wann der Wächter sich meldet und wer die Erinnerungen bekommt.</p>
                </div>
            </header>

            {meldung ? (
                <div className="hinweisleiste">
                    <p>{meldung}</p>
                </div>
            ) : null}
            {fehler ? <p className="fehlerleiste">{fehler}</p> : null}

            <div className="stapel">
                <Karte titel="Organisation und Erinnerungen">
                    <form onSubmit={speichern} className="stapel">
                        <div className="feldgruppe">
                            <div className="feld">
                                <label htmlFor="org-name">Name der Organisation</label>
                                <input
                                    id="org-name"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    required
                                />
                            </div>
                            <div className="feld">
                                <label htmlFor="org-vorlauf">Erinnern (Tage vor dem Stichtag)</label>
                                <input
                                    id="org-vorlauf"
                                    value={vorlauf}
                                    onChange={(e) => setVorlauf(e.target.value)}
                                    placeholder="90, 30, 14, 3"
                                />
                                <span className="hilfe">
                                    Mehrere Stufen mit Komma trennen. Fallen mehrere Stufen auf
                                    denselben Tag, geht trotzdem nur eine Mail hinaus.
                                </span>
                            </div>
                            <div className="feld" style={{ gridColumn: "1 / -1" }}>
                                <label htmlFor="org-verteiler">Zusätzliche Empfänger</label>
                                <input
                                    id="org-verteiler"
                                    value={verteiler}
                                    onChange={(e) => setVerteiler(e.target.value)}
                                    placeholder="buchhaltung@beispiel.de, einkauf@beispiel.de"
                                />
                                <span className="hilfe">
                                    Alle Mitglieder der Organisation bekommen die Erinnerungen
                                    ohnehin.
                                </span>
                            </div>
                        </div>
                        <div className="knopfreihe">
                            <button type="submit" className="knopf haupt">
                                Speichern
                            </button>
                        </div>
                    </form>
                </Karte>

                {api.demo ? (
                    <Karte titel="Demo">
                        <p style={{ marginTop: 0 }}>
                            Diese Fassung läuft vollständig im Browser. Alle Verträge liegen im
                            lokalen Speicher dieses Geräts, es gibt keinen Server, keine Anmeldung
                            und keinen Mailversand — die Erinnerungsmails landen im Postausgang, wo
                            sich ihr Wortlaut ansehen lässt.
                        </p>
                        <p style={{ marginBottom: 0 }}>
                            Für den echten Betrieb gehört der Server dazu: er führt den Fristenlauf
                            auch dann aus, wenn niemand die Seite offen hat, verschickt die Mails
                            und liefert das Kalender-Abo.
                        </p>
                    </Karte>
                ) : (
                    <Karte titel="Kalender-Abo">
                        <p style={{ marginTop: 0 }}>
                            Diese Adresse in Outlook, Google Kalender oder Thunderbird als Abo
                            eintragen — jeder Stichtag erscheint dann als ganztägiger Termin mit
                            Erinnerung zwei Wochen vorher.
                        </p>
                        <div className="feld">
                            <input readOnly value={kalender} onFocus={(e) => e.target.select()} />
                        </div>
                        <div className="knopfreihe" style={{ marginTop: 12 }}>
                            <button
                                type="button"
                                className="knopf"
                                onClick={() => void navigator.clipboard?.writeText(kalender)}
                            >
                                Adresse kopieren
                            </button>
                            <button
                                type="button"
                                className="knopf leise"
                                onClick={async () => {
                                    const { kalenderAdresse } = await api.kalenderErneuern();
                                    setKalender(kalenderAdresse);
                                    setMeldung(
                                        "Neue Adresse erzeugt. Bestehende Abos müssen umgestellt werden.",
                                    );
                                }}
                            >
                                Adresse erneuern
                            </button>
                        </div>
                        <p className="nebenzeile" style={{ marginBottom: 0 }}>
                            Wer die Adresse kennt, sieht die Fristen. Bei Verdacht auf Weitergabe
                            erneuern.
                        </p>
                    </Karte>
                )}

                <Karte titel="Beispieldaten">
                    <p style={{ marginTop: 0 }}>
                        Legt einen Bestand typischer Verträge an — nützlich, um die Übersicht mit
                        Leben zu füllen.
                    </p>
                    <button
                        type="button"
                        className="knopf"
                        onClick={async () => {
                            const { angelegt } = await api.demodaten();
                            setMeldung(`${angelegt} Beispielverträge angelegt.`);
                        }}
                    >
                        Beispieldaten anlegen
                    </button>
                </Karte>
            </div>
        </>
    );
}
