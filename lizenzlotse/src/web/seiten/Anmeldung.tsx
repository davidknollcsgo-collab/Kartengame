import { useState, type FormEvent } from "react";
import { api, type Fehler } from "../api.ts";

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
                <h1>Was zahlen Sie für Lizenzen, die niemand benutzt?</h1>
                <p>
                    In Microsoft 365 stehen Lizenzzuweisung und tatsächliche Nutzung in zwei
                    getrennten Listen — deshalb fällt niemandem auf, wenn ein ausgeschiedener
                    Kollege noch lizenziert ist oder eine Copilot-Lizenz seit Monaten ruht.
                    Der Lotse führt beide Listen zusammen und rechnet das Ergebnis in Euro um.
                </p>
                <ul>
                    <li>Erster Bericht ohne Zugriff auf Ihren Mandanten — drei Ausgaben genügen</li>
                    <li>Jeder Befund mit Begründung, Empfehlung und Betrag je Monat und Jahr</li>
                    <li>Getrennt ausgewiesen: sicher zu heben und erst zu prüfen</li>
                    <li>Für Systemhäuser: beliebig viele Mandanten unter einem Konto</li>
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
                            <Feld name="organisation" beschriftung="Firma" platzhalter="Nordwerk GmbH" meldung={felder["organisation"]} autoFocus />
                            <Feld name="name" beschriftung="Ihr Name" platzhalter="Anna Nord" meldung={felder["name"]} />
                        </>
                    ) : null}
                    <Feld
                        name="email"
                        art="email"
                        beschriftung="E-Mail-Adresse"
                        platzhalter="anna@nordwerk.de"
                        meldung={felder["email"]}
                        autoFocus={modus === "anmelden"}
                    />
                    <Feld
                        name="kennwort"
                        art="password"
                        beschriftung="Kennwort"
                        hilfe={modus === "registrieren" ? "Mindestens 12 Zeichen." : undefined}
                        meldung={felder["kennwort"]}
                    />
                    <button type="submit" className="knopf haupt" disabled={laeuft}>
                        {laeuft ? "Einen Moment …" : modus === "registrieren" ? "Konto anlegen" : "Anmelden"}
                    </button>
                </form>
            </div>
        </div>
    );
}

function Feld({
    name, beschriftung, art = "text", platzhalter, hilfe, meldung, autoFocus,
}: {
    name: string; beschriftung: string; art?: string; platzhalter?: string;
    hilfe?: string; meldung?: string; autoFocus?: boolean;
}) {
    return (
        <div className={`feld${meldung ? " falsch" : ""}`}>
            <label htmlFor={`an-${name}`}>{beschriftung}</label>
            <input
                id={`an-${name}`}
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
