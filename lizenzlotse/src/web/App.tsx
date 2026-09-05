import { useCallback, useEffect, useState } from "react";
import { NavLink, Route, Routes, useNavigate } from "react-router-dom";
import { api, type Anmeldedaten, type Mandant } from "./api.ts";
import { Anmeldung } from "./seiten/Anmeldung.tsx";
import { Import } from "./seiten/Import.tsx";
import { Preise } from "./seiten/Preise.tsx";
import { Uebersicht } from "./seiten/Uebersicht.tsx";
import { Verwaltung } from "./seiten/Verwaltung.tsx";

const GEMERKTER_MANDANT = "lizenzlotse.mandant";

function Zeichen() {
    // Kompassrose: der Lotse zeigt die Richtung.
    return (
        <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
            <circle cx="11" cy="11" r="9" fill="none" stroke="var(--lotse)" strokeWidth="1.7" />
            <path d="M11 3.6l2.4 5.9 5.9 2.4-5.9 2.4L11 20l-2.4-5.7L2.7 11.9l5.9-2.4z" fill="var(--lotse)" />
        </svg>
    );
}

export interface Werkzeug {
    anmeldung: Anmeldedaten;
    mandant: Mandant;
    mandantenNeuLaden: () => Promise<void>;
}

export function App() {
    const [anmeldung, setAnmeldung] = useState<Anmeldedaten | null>(null);
    const [geprueft, setGeprueft] = useState(false);
    const [mandanten, setMandanten] = useState<Mandant[]>([]);
    const [mandantId, setMandantId] = useState<string>(
        () => localStorage.getItem(GEMERKTER_MANDANT) ?? "",
    );

    const pruefen = useCallback(async () => {
        setAnmeldung(await api.ich());
        setGeprueft(true);
    }, []);

    const mandantenLaden = useCallback(async () => {
        const { mandanten: liste } = await api.mandanten();
        setMandanten(liste);
        setMandantId((bisher) => {
            const gueltig = liste.some((m) => m.id === bisher);
            return gueltig ? bisher : (liste[0]?.id ?? "");
        });
    }, []);

    useEffect(() => {
        void pruefen();
    }, [pruefen]);

    useEffect(() => {
        if (anmeldung) void mandantenLaden();
    }, [anmeldung, mandantenLaden]);

    useEffect(() => {
        if (mandantId) localStorage.setItem(GEMERKTER_MANDANT, mandantId);
    }, [mandantId]);

    if (!geprueft) return <p className="lade">Lotse startet …</p>;
    if (!anmeldung) return <Anmeldung fertig={pruefen} />;

    const mandant = mandanten.find((m) => m.id === mandantId) ?? null;
    const werkzeug: Werkzeug | null = mandant
        ? { anmeldung, mandant, mandantenNeuLaden: mandantenLaden }
        : null;

    return (
        <>
            <header className="kopfleiste">
                <div className="innen">
                    <NavLink to="/" className="wortmarke">
                        <Zeichen />
                        Lizenzlotse
                    </NavLink>
                    <nav className="hauptnavigation">
                        <NavLink to="/" end>
                            Übersicht
                        </NavLink>
                        <NavLink to="/import">Daten einlesen</NavLink>
                        <NavLink to="/preise">Preise</NavLink>
                        <NavLink to="/verwaltung">Verwaltung</NavLink>
                    </nav>
                    <div className="kopf-rechts">
                        {mandanten.length > 0 ? (
                            <div className="mandantenwahl">
                                <label htmlFor="mandant">Mandant</label>
                                <select
                                    id="mandant"
                                    value={mandantId}
                                    onChange={(e) => setMandantId(e.target.value)}
                                >
                                    {mandanten.map((m) => (
                                        <option key={m.id} value={m.id}>
                                            {m.name}
                                        </option>
                                    ))}
                                </select>
                            </div>
                        ) : null}
                        <button
                            type="button"
                            className="knopf leise"
                            onClick={async () => {
                                await api.abmelden();
                                setAnmeldung(null);
                            }}
                        >
                            Abmelden
                        </button>
                    </div>
                </div>
            </header>
            <main className="inhalt">
                {!werkzeug ? (
                    <KeinMandant neuLaden={mandantenLaden} />
                ) : (
                    <Routes>
                        <Route path="/" element={<Uebersicht werkzeug={werkzeug} />} />
                        <Route path="/import" element={<Import werkzeug={werkzeug} />} />
                        <Route path="/preise" element={<Preise werkzeug={werkzeug} />} />
                        <Route
                            path="/verwaltung"
                            element={<Verwaltung werkzeug={werkzeug} mandanten={mandanten} />}
                        />
                        <Route path="*" element={<NichtGefunden />} />
                    </Routes>
                )}
            </main>
        </>
    );
}

function KeinMandant({ neuLaden }: { neuLaden: () => Promise<void> }) {
    const [name, setName] = useState("");
    return (
        <div className="karte">
            <div className="leerzustand">
                <h3>Noch kein Mandant angelegt</h3>
                <p>
                    Ein Mandant ist die Microsoft-365-Umgebung, die überwacht werden soll.
                    Systemhäuser legen je Kunde einen an.
                </p>
                <form
                    className="knopfreihe"
                    onSubmit={async (e) => {
                        e.preventDefault();
                        if (!name.trim()) return;
                        await api.mandantAnlegen(name.trim());
                        await neuLaden();
                    }}
                >
                    <input
                        className="feld"
                        style={{ padding: "8px 10px", border: "1px solid var(--linie-stark)", borderRadius: 5 }}
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        placeholder="Name des Mandanten"
                    />
                    <button type="submit" className="knopf haupt">
                        Anlegen
                    </button>
                </form>
            </div>
        </div>
    );
}

function NichtGefunden() {
    const navigate = useNavigate();
    return (
        <div className="karte">
            <div className="leerzustand">
                <h3>Diese Seite gibt es nicht</h3>
                <button type="button" className="knopf" onClick={() => navigate("/")}>
                    Zur Übersicht
                </button>
            </div>
        </div>
    );
}
