// Kleine, wiederverwendete Bausteine der Oberfläche.

import type { ReactNode } from "react";
import { AMPEL_TEXT, type Ampel, type Fristberechnung } from "../../fachlogik/fristen.ts";
import { datumKurz, euro, tageInWorten } from "../../fachlogik/formate.ts";

export function Plakette({ ampel, text }: { ampel: Ampel; text?: string }) {
    return <span className={`plakette ampel-${ampel}`}>{text ?? AMPEL_TEXT[ampel]}</span>;
}

export function Kennzahl({
    beschriftung,
    wert,
    fussnote,
    dringend = false,
}: {
    beschriftung: string;
    wert: ReactNode;
    fussnote?: ReactNode;
    dringend?: boolean;
}) {
    return (
        <div className={`kennzahl${dringend ? " dringend" : ""}`}>
            <span className="beschriftung">{beschriftung}</span>
            <span className="wert">{wert}</span>
            {fussnote ? <span className="fussnote">{fussnote}</span> : null}
        </div>
    );
}

export function Karte({
    titel,
    aktion,
    children,
    ohnePolster = false,
}: {
    titel: string;
    aktion?: ReactNode;
    children: ReactNode;
    ohnePolster?: boolean;
}) {
    return (
        <section className="karte">
            <header className="karte-kopf">
                <h2>{titel}</h2>
                {aktion}
            </header>
            <div className={ohnePolster ? "" : "karte-koerper"}>{children}</div>
        </section>
    );
}

export function Leerzustand({
    titel,
    text,
    aktion,
}: {
    titel: string;
    text: string;
    aktion?: ReactNode;
}) {
    return (
        <div className="leerzustand">
            <h3>{titel}</h3>
            <p style={{ margin: 0, maxWidth: "48ch" }}>{text}</p>
            {aktion}
        </div>
    );
}

export function Laedt({ was = "Wird geladen" }: { was?: string }) {
    return <p className="lade">{was} …</p>;
}

/** Der Stichtag als Karte: Datum, Countdown und Klartext, was passiert. */
export function Fristkarte({ fristen, ampel }: { fristen: Fristberechnung; ampel: Ampel }) {
    return (
        <div className={`fristkarte ampel-${ampel}`}>
            <div>
                <span className="beschriftung" style={{ fontSize: 11, letterSpacing: "0.07em", textTransform: "uppercase" }}>
                    {fristen.art === "vertragsende"
                        ? "Vertrag endet am"
                        : fristen.art === "jederzeit_kuendbar"
                          ? "Jederzeit kündbar"
                          : "Kündigung muss zugehen bis"}
                </span>
                <div className="stichtag">
                    {fristen.stichtag ? datumKurz(fristen.stichtag) : "ohne festen Termin"}
                </div>
                {fristen.tageBisStichtag !== null ? (
                    <span className="nebenzeile">{tageInWorten(fristen.tageBisStichtag)}</span>
                ) : null}
            </div>
            <dl>
                {fristen.laufzeitende ? (
                    <>
                        <dt>Laufzeit bis</dt>
                        <dd>{datumKurz(fristen.laufzeitende)}</dd>
                    </>
                ) : null}
                {fristen.wirksamesVertragsende ? (
                    <>
                        <dt>Endet dann am</dt>
                        <dd>{datumKurz(fristen.wirksamesVertragsende)}</dd>
                    </>
                ) : null}
                {fristen.verlaengerungenBisher > 0 ? (
                    <>
                        <dt>Bisher verlängert</dt>
                        <dd>{fristen.verlaengerungenBisher}×</dd>
                    </>
                ) : null}
            </dl>
            <p className="erklaerung">{fristen.hinweis}</p>
        </div>
    );
}

export function Geld({ cent }: { cent: number }) {
    return <span className="zahl">{euro(cent)}</span>;
}
