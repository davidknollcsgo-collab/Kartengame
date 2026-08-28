import { useState, type FormEvent } from "react";
import { api } from "../api.ts";
import type { Fehler } from "../typen.ts";

export function Anmeldung({ fertig }: { fertig: () => Promise<void> }) {
    const [modus, setModus] = useState<"anmelden" | "registrieren">("registrieren");
    const [laeuft, setLaeuft] = useState(false);
    const [fehler, setFehler] = useState<string | null>(null);
    const [felder, setFelder] = useState<Record<string, string>>({});

    async function absenden(ereignis: FormEvent<HTMLFormElement>) {
        ereignis.preventDefault();
        const formular = new FormData(ereignis.currentTarget);
        setLaeuft(true);
        setFehler(null);
        setFelder({});
        try {
            if (modus === "anmelden") {
                await api.anmelden(
                    String(formular.get("email") ?? ""),
                    String(formular.get("kennwort") ?? ""),
                );
            } else {
                await api.registrieren({
                    organisation: String(formular.get("organisation") ?? ""),
                    name: String(formular.get("name") ?? ""),
                    email: String(formular.get("email") ?? ""),
                    kennwort: String(formular.get("kennwort") ?? ""),
                });
            }
            await fertig();
        } catch (problem) {
            const f = problem as Fehler;
            setFehler(f.message);
            setFelder(f.felder ?? {});
        } finally {
            setLaeuft(false);
        }
    }

    return (
        <div className="anmeldeseite">
            <div className="schild">
                <h1>Keine Frist mehr verpassen.</h1>
                <p>
                    Versicherungen, Software-Abos, Miet- und Wartungsverträge verlängern sich still
                    weiter, wenn niemand rechtzeitig kündigt. Der Wächter rechnet aus jedem Vertrag
                    den Stichtag aus und meldet sich, bevor er verstreicht.
                </p>
                <ul>
                    <li>Kündigungsstichtag aus Laufzeit, Verlängerung und Frist — auch bei Quartals- und Jahresterminen</li>
                    <li>Erinnerung 90, 30, 14 und 3 Tage vorher, per Mail an das ganze Team</li>
                    <li>Alle Fristen als Kalender-Abo in Outlook, Google oder Thunderbird</li>
                    <li>Jahreskosten je Kategorie — sichtbar, was an den fälligen Verträgen hängt</li>
                </ul>
            </div>
            <div className="formularseite">
                <form onSubmit={absenden}>
                    <div className="umschalter">
                        <button
                            type="button"
                            aria-pressed={modus === "registrieren"}
                            onClick={() => setModus("registrieren")}
                        >
                            Konto anlegen
                        </button>
                        <button
                            type="button"
                            aria-pressed={modus === "anmelden"}
                            onClick={() => setModus("anmelden")}
                        >
                            Anmelden
                        </button>
                    </div>

                    {fehler ? <p className="fehlerleiste">{fehler}</p> : null}

                    {modus === "registrieren" ? (
                        <>
                            <Feld
                                name="organisation"
                                beschriftung="Organisation"
                                platzhalter="Beispiel GmbH"
                                meldung={felder["organisation"]}
                                autoFocus
                            />
                            <Feld
                                name="name"
                                beschriftung="Ihr Name"
                                platzhalter="Anna Beispiel"
                                meldung={felder["name"]}
                            />
                        </>
                    ) : null}

                    <Feld
                        name="email"
                        art="email"
                        beschriftung="E-Mail-Adresse"
                        platzhalter="anna@beispiel.de"
                        meldung={felder["email"]}
                        autoFocus={modus === "anmelden"}
                    />
                    <Feld
                        name="kennwort"
                        art="password"
                        beschriftung="Kennwort"
                        hilfe={modus === "registrieren" ? "Mindestens 10 Zeichen." : undefined}
                        meldung={felder["kennwort"]}
                    />

                    <button type="submit" className="knopf haupt" disabled={laeuft}>
                        {laeuft
                            ? "Einen Moment …"
                            : modus === "registrieren"
                              ? "Konto anlegen"
                              : "Anmelden"}
                    </button>
                </form>
            </div>
        </div>
    );
}

function Feld({
    name,
    beschriftung,
    art = "text",
    platzhalter,
    hilfe,
    meldung,
    autoFocus,
}: {
    name: string;
    beschriftung: string;
    art?: string;
    platzhalter?: string;
    hilfe?: string;
    meldung?: string;
    autoFocus?: boolean;
}) {
    return (
        <div className={`feld${meldung ? " falsch" : ""}`}>
            <label htmlFor={`anmelde-${name}`}>{beschriftung}</label>
            <input
                id={`anmelde-${name}`}
                name={name}
                type={art}
                placeholder={platzhalter}
                autoFocus={autoFocus}
                autoComplete={art === "password" ? "current-password" : "on"}
                required
            />
            {hilfe && !meldung ? <span className="hilfe">{hilfe}</span> : null}
            {meldung ? <span className="meldung">{meldung}</span> : null}
        </div>
    );
}
