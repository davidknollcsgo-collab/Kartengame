/* Tests der ARKANWETT-Engine: node --test tests/ */
const test = require('node:test');
const assert = require('node:assert');

const Elemente = require('../web/js/elements.js');
const Karten = require('../web/js/cards.js');
const Haende = require('../web/js/hands.js');
const Spiel = require('../web/js/game.js');
const KI = require('../web/js/ai.js');

// ------------------------------------------------------------------ Elemente

test('Elementkreislauf: jedes Element schlägt das nächste', () => {
  assert.ok(Elemente.schlaegt('Feuer', 'Erde'));
  assert.ok(Elemente.schlaegt('Erde', 'Luft'));
  assert.ok(Elemente.schlaegt('Luft', 'Wasser'));
  assert.ok(Elemente.schlaegt('Wasser', 'Feuer'), 'Beispielrunde aus der README');
  assert.ok(!Elemente.schlaegt('Feuer', 'Wasser'));
  assert.ok(!Elemente.schlaegt('Feuer', 'Feuer'));
});

test('Licht und Schatten neutralisieren sich, dominieren sonst alle', () => {
  assert.ok(!Elemente.schlaegt('Licht', 'Schatten'));
  assert.ok(!Elemente.schlaegt('Schatten', 'Licht'));
  assert.ok(Elemente.schlaegt('Licht', 'Feuer'));
  assert.ok(Elemente.schlaegt('Schatten', 'Wasser'));
  assert.ok(!Elemente.schlaegt('Feuer', 'Licht'));
});

test('Konterelement liefert den Vorgänger im Kreislauf', () => {
  assert.strictEqual(Elemente.konterElement('Feuer'), 'Wasser');
  assert.strictEqual(Elemente.konterElement('Licht'), null);
});

// ------------------------------------------------------------------ Karten

test('Standarddeck umfasst 40 Karten in der vorgesehenen Verteilung', () => {
  const deck = Karten.baueDeck();
  assert.strictEqual(deck.length, 40);
  const nachArt = deck.reduce((m, k) => ((m[k.art] = (m[k.art] || 0) + 1), m), {});
  assert.strictEqual(nachArt.wesen, 22);
  assert.strictEqual(nachArt.zauber, 10);
  assert.strictEqual(nachArt.falle, 6);
  assert.strictEqual(nachArt.schicksal, 2);
});

test('Karteninstanzen haben eindeutige uids', () => {
  const deck = Karten.baueDeck();
  assert.strictEqual(new Set(deck.map((k) => k.uid)).size, deck.length);
});

// ------------------------------------------------------------------ Schicksalshände

const w = (id) => Karten.instanz(id);

test('Elementar-Paar bei zwei Wesen gleichen Elements', () => {
  const treffer = Haende.bewerte([w('glutkobold'), w('aschewolf'), null]);
  assert.deepStrictEqual(treffer.map((h) => h.key), ['elementarPaar']);
  assert.strictEqual(treffer[0].element, 'Feuer');
});

test('Stufen-Straße bei drei aufeinanderfolgenden Stufen', () => {
  // Stufen 1, 2, 3
  const treffer = Haende.bewerte([w('funkengeist'), w('nebelkoi'), w('windlaeufer')]);
  assert.ok(treffer.some((h) => h.key === 'stufenStrasse'));
});

test('Element-Flush nur, wenn alle drei Feldwesen ein Element teilen', () => {
  const flush = Haende.bewerte([w('glutkobold'), w('aschewolf'), w('flammenritter')]);
  assert.ok(flush.some((h) => h.key === 'elementFlush'));
  const keinFlush = Haende.bewerte([w('glutkobold'), w('aschewolf'), w('nebelkoi')]);
  assert.ok(!keinFlush.some((h) => h.key === 'elementFlush'));
});

test('Vollbund: Drilling gleicher Stufe mit Elementpaar', () => {
  // Stufe 2: Glutkobold (Feuer), Glutkobold (Feuer), Steinbeißer (Erde)
  const treffer = Haende.bewerte([w('glutkobold'), w('glutkobold'), w('steinbeisser')]);
  assert.ok(treffer.some((h) => h.key === 'vollbund'));
  // Drilling ohne Elementpaar zählt nicht
  const ohne = Haende.bewerte([w('glutkobold'), w('steinbeisser'), w('sturmfalke')]);
  assert.ok(!ohne.some((h) => h.key === 'vollbund'));
});

test('Schattenlicht bei Licht- und Schattenwesen im Feld', () => {
  const treffer = Haende.bewerte([w('sonnenwaechterin'), w('schattenpirscher'), null]);
  assert.ok(treffer.some((h) => h.key === 'schattenlicht'));
});

test('Zwillingsschicksal lässt jedes Element als Paar zählen', () => {
  const feld = [w('glutkobold'), w('nebelkoi'), w('sturmfalke')];
  assert.ok(!Haende.bewerte(feld).some((h) => h.key === 'elementarPaar'));
  const wild = Haende.bewerte(feld, { wildElemente: true });
  assert.ok(wild.some((h) => h.key === 'elementarPaar'));
  assert.ok(wild.some((h) => h.key === 'elementFlush'));
});

// ------------------------------------------------------------------ Einsatzphase

test('Multiplikator wächst mit dem Einsatz und ist bei ×4 gedeckelt', () => {
  assert.strictEqual(Spiel.multiplikatorFuer(0), 1);
  assert.strictEqual(Spiel.multiplikatorFuer(5), 2, 'Beispielrunde: Einsatz 5 → ×2');
  assert.strictEqual(Spiel.multiplikatorFuer(6), 3);
  assert.strictEqual(Spiel.multiplikatorFuer(30), 4);
});

test('Setzen, Erhöhen, Mitgehen schließt die Einsatzphase mit gleichem Einsatz', () => {
  const s = Spiel.erstelleSpiel({ seed: 7 });
  const eroeffner = s.startspieler;
  Spiel.einsatzAktion(s, eroeffner, 'setzen', 3);
  Spiel.einsatzAktion(s, 1 - eroeffner, 'erhoehen', 2); // gesamt 5
  Spiel.einsatzAktion(s, eroeffner, 'mitgehen');
  assert.strictEqual(s.phase, 'beschwoerung');
  assert.deepStrictEqual(s.einsatz.betraege, [5, 5]);
  assert.strictEqual(s.multiplikator, 2);
  assert.strictEqual(s.pot, 10);
  assert.strictEqual(s.spieler[0].chips, 15);
});

test('Aussteigen gibt dem Gegner den Pot und kostet 2 LP', () => {
  const s = Spiel.erstelleSpiel({ seed: 11 });
  const eroeffner = s.startspieler;
  Spiel.einsatzAktion(s, eroeffner, 'setzen', 4);
  Spiel.einsatzAktion(s, 1 - eroeffner, 'aussteigen');
  assert.strictEqual(s.phase, 'auswertung');
  assert.strictEqual(s.spieler[1 - eroeffner].lp, 18);
  assert.strictEqual(s.spieler[eroeffner].chips, 20, 'Einsatz kommt über den Pot zurück');
});

test('All-in gibt nicht gedeckte Chips zurück', () => {
  const s = Spiel.erstelleSpiel({ seed: 3 });
  s.spieler[1].chips = 2;
  const p0 = 0;
  s.einsatz.toAct = p0;
  Spiel.einsatzAktion(s, 0, 'setzen', 6);
  Spiel.einsatzAktion(s, 1, 'mitgehen');
  assert.deepStrictEqual(s.einsatz.betraege, [2, 2]);
  assert.strictEqual(s.spieler[0].chips, 18);
  assert.strictEqual(s.spieler[1].chips, 0);
  assert.strictEqual(s.pot, 4);
});

test('Ohne Chips ist die Einsatzphase verloren', () => {
  const s = Spiel.erstelleSpiel({ seed: 5 });
  s.spieler[1].chips = 0;
  s.phase = 'auswertung';
  Spiel.weiter(s);
  assert.strictEqual(s.phase, 'ende');
  assert.strictEqual(s.sieger, 0);
});

// ------------------------------------------------------------------ Kampfphase

/** Baut einen Zustand mit festgelegtem Feld und Multiplikator. */
function aufbau(feld0, feld1, multiplikator) {
  const s = Spiel.erstelleSpiel({ seed: 42 });
  s.spieler.forEach((p) => {
    p.hand = [];
    p.feld = [null, null, null];
    p.fallen = [null, null];
  });
  feld0.forEach((id, i) => { if (id) s.spieler[0].feld[i] = w(id); });
  feld1.forEach((id, i) => { if (id) s.spieler[1].feld[i] = w(id); });
  s.multiplikator = multiplikator || 1;
  s.pot = 0;
  s.phase = 'beschwoerung';
  s.beschwoerungFertig = [true, true];
  Spiel.schicksalsPhase(s);
  return s;
}

test('Beispielrunde: Wasser schlägt Feuer und gewinnt den Schlagabtausch', () => {
  // Flammenritter (Feuer, Stufe 4, 1600/1200) gegen Gezeitenwächter (Wasser, Stufe 5, 1800/1500)
  const s = aufbau(['flammenritter'], ['gezeitenwaechter'], 2);
  assert.strictEqual(Spiel.effektiveAng(s, 1, 0, s.spieler[0].feld[0]), 2200, '1800 + 400 Elementvorteil');
  Spiel.kampfPhase(s);
  // Gegner: (2200 - 1200) / 400 = 2 -> x2 = 4 LP; Spieler: (1600 - 1500) / 400 = 0
  assert.strictEqual(s.kampfBericht.lp[1], 4);
  assert.strictEqual(s.kampfBericht.lp[0], 0);
  assert.strictEqual(s.spieler[0].lp, 16);
  // Beide ANG übersteigen die gegnerische VER: der Schlagabtausch fällt beidseitig,
  // aber nur B setzt genug Überschuss für Lebenspunkte-Schaden um.
  assert.strictEqual(s.spieler[0].feld[0], null, 'Flammenritter wird zerstört');
  assert.strictEqual(s.spieler[1].feld[0], null, 'Gezeitenwächter fällt mit');
  assert.strictEqual(s.spieler[1].lp, 20, 'Feuer bringt kein LP durch');
});

test('Elementbann nimmt dem Gegner den Elementvorteil', () => {
  const s = aufbau(['flammenritter'], ['gezeitenwaechter'], 1);
  s.spieler[0].fallen[0] = w('elementbann');
  Spiel.kampfPhase(s);
  // ohne Bonus: (1800 - 1200) / 400 = 1 LP
  assert.strictEqual(s.kampfBericht.lp[1], 1);
});

test('Unverteidigte Wesen greifen direkt an', () => {
  const s = aufbau(['flammenritter'], [], 2);
  Spiel.kampfPhase(s);
  assert.strictEqual(s.kampfBericht.lp[0], 4, '1600 halbiert = 800 → 2 Rohstufen, ×2');
  assert.strictEqual(s.spieler[1].lp, 16);
});

test('Spiegelschild halbiert erlittenen Kampfschaden', () => {
  const s = aufbau(['flammenritter'], [], 2);
  s.spieler[1].fallen[0] = w('spiegelschild');
  Spiel.kampfPhase(s);
  assert.strictEqual(s.kampfBericht.lp[0], 2);
});

test('Zeitfalle senkt den Multiplikator des Gegners um 1', () => {
  const s = aufbau(['flammenritter'], [], 3);
  s.spieler[1].fallen[0] = w('zeitfalle');
  Spiel.kampfPhase(s);
  assert.strictEqual(s.kampfBericht.lp[0], 4, '2 Rohstufen × (3 − 1)');
});

test('Element-Flush deaktiviert die gegnerischen Fallen', () => {
  const s = aufbau(['glutkobold', 'aschewolf', 'flammenritter'], [], 1);
  s.spieler[1].fallen[0] = w('spiegelschild');
  assert.ok(s.schicksalsHaende[0].some((h) => h.key === 'elementFlush'));
  Spiel.kampfPhase(s);
  assert.ok(s.spieler[1].fallen[0], 'Falle bleibt ungenutzt liegen');
  // Voller Direktschaden trotz Spiegelschild: (1000 + 1400 + 1800) halbiert = 2100 -> 5 LP
  assert.strictEqual(s.kampfBericht.lp[0], 5);
});

test('Schattenlicht verdoppelt den Kampfschaden', () => {
  const s = aufbau(['sonnenwaechterin', 'schattenpirscher'], [], 1);
  assert.ok(s.schicksalsHaende[0].some((h) => h.key === 'schattenlicht'));
  Spiel.kampfPhase(s);
  // (750 + 650) / 400 = 3 -> verdoppelt 6
  assert.strictEqual(s.kampfBericht.lp[0], 6);
});

test('Gegenschlag trifft zurück', () => {
  const s = aufbau([], ['flammenritter'], 1);
  s.spieler[0].fallen[0] = w('gegenschlag');
  Spiel.kampfPhase(s);
  assert.strictEqual(s.spieler[1].lp, 18);
});

test('Bollwerk gewinnt Verteidigung je weiterem eigenen Wesen', () => {
  const s = aufbau(['wurzelgolem', 'steinbeisser', 'lehmspaeher'], [], 1);
  assert.strictEqual(Spiel.effektiveVer(s, 0, 0), 1800 + 400);
});

test('Jäger erhält Bonus gegen niedrigere Stufen', () => {
  const s = aufbau(['aschewolf'], ['glutkobold'], 1);
  // Aschewolf Stufe 3 gegen Glutkobold Stufe 2: 1200 + 300 Jäger + 200 (kein Paar) ...
  const ang = Spiel.effektiveAng(s, 0, 0, s.spieler[1].feld[0]);
  assert.strictEqual(ang, 1500, 'kein Elementvorteil im Spiegel, aber +300 Jäger');
});

// ------------------------------------------------------------------ Beschwörung

test('Beschwören kostet Chips und belegt einen Feldplatz', () => {
  const s = Spiel.erstelleSpiel({ seed: 9 });
  s.phase = 'beschwoerung';
  s.aktiverSpieler = 0;
  const karte = w('flammenritter');
  s.spieler[0].hand = [karte];
  const chips = s.spieler[0].chips;
  Spiel.karteSpielen(s, 0, karte.uid);
  assert.strictEqual(s.spieler[0].chips, chips - 2, 'Stufe 4 → 2 Chips');
  assert.strictEqual(s.spieler[0].feld[0].name, 'Flammenritter');
});

test('Zoll verteuert gegnerische Beschwörungen', () => {
  const s = Spiel.erstelleSpiel({ seed: 9 });
  s.phase = 'beschwoerung';
  s.aktiverSpieler = 0;
  s.spieler[1].feld[0] = w('bergvogt');
  const karte = w('glutkobold');
  assert.strictEqual(Spiel.beschwoerungskosten(s, 0, karte), 2, '1 Chip Grundkosten + 1 Zoll');
});

test('Freie Beschwörung der Stufen-Straße kostet nichts', () => {
  const s = Spiel.erstelleSpiel({ seed: 9 });
  s.phase = 'beschwoerung';
  s.aktiverSpieler = 0;
  s.spieler[0].freieBeschwoerung = true;
  const karte = w('magmatitan');
  s.spieler[0].hand = [karte];
  const chips = s.spieler[0].chips;
  Spiel.karteSpielen(s, 0, karte.uid);
  assert.strictEqual(s.spieler[0].chips, chips);
  assert.strictEqual(s.spieler[0].freieBeschwoerung, false);
});

test('Volle Wesen-Zone blockiert weitere Beschwörungen', () => {
  const s = Spiel.erstelleSpiel({ seed: 9 });
  s.phase = 'beschwoerung';
  s.aktiverSpieler = 0;
  s.spieler[0].feld = [w('glutkobold'), w('nebelkoi'), w('sturmfalke')];
  const karte = w('flammenritter');
  s.spieler[0].hand = [karte];
  assert.match(Spiel.spielHindernis(s, 0, karte), /Wesen-Zone/);
  assert.throws(() => Spiel.karteSpielen(s, 0, karte.uid), /Wesen-Zone/);
});

test('Pakt des Abgrunds stärkt alle Wesen und kostet am Rundenende 3 LP', () => {
  const s = aufbau(['glutkobold'], [], 1);
  s.phase = 'beschwoerung';
  s.aktiverSpieler = 0;
  const karte = w('paktdesabgrunds');
  s.spieler[0].hand = [karte];
  Spiel.karteSpielen(s, 0, karte.uid);
  assert.strictEqual(Spiel.effektiveAng(s, 0, 0, null), 1800);
  s.phase = 'schicksal';
  Spiel.kampfPhase(s);
  const lpVorher = s.spieler[0].lp;
  Spiel.weiter(s);
  assert.strictEqual(s.spieler[0].lp, lpVorher - 3);
});

// ------------------------------------------------------------------ Rundenauswertung

test('Der Pot geht an den Spieler mit mehr Kampfschaden', () => {
  const s = aufbau(['flammenritter'], [], 1);
  s.pot = 6;
  s.einsatz.betraege = [3, 3];
  const chips = s.spieler[0].chips;
  Spiel.kampfPhase(s);
  Spiel.weiter(s);
  assert.strictEqual(s.rundenBericht.potAn, 0);
  assert.strictEqual(s.spieler[0].chips, chips + 6);
});

test('Bei gleichem Schaden wandern die Einsätze zurück', () => {
  const s = aufbau([], [], 1);
  s.pot = 6;
  s.einsatz.betraege = [3, 3];
  const chips = [s.spieler[0].chips, s.spieler[1].chips];
  Spiel.kampfPhase(s);
  Spiel.weiter(s);
  assert.strictEqual(s.rundenBericht.potAn, null);
  assert.strictEqual(s.spieler[0].chips, chips[0] + 3);
  assert.strictEqual(s.spieler[1].chips, chips[1] + 3);
});

test('Neue Runde bringt Nachschub und dreht den Startspieler', () => {
  const s = aufbau([], [], 1);
  const start = s.startspieler;
  const chips = s.spieler[0].chips;
  Spiel.kampfPhase(s);
  Spiel.weiter(s); // Auswertung
  Spiel.weiter(s); // neue Runde
  assert.strictEqual(s.phase, 'einsatz');
  assert.strictEqual(s.startspieler, 1 - start);
  assert.strictEqual(s.spieler[0].chips, chips + Spiel.K.NACHSCHUB);
});

test('Temporäre Kampfwerte verfallen am Rundenende', () => {
  const s = aufbau(['glutkobold'], [], 1);
  s.phase = 'beschwoerung';
  s.aktiverSpieler = 0;
  const zauber = w('flammenstoss');
  s.spieler[0].hand = [zauber];
  Spiel.karteSpielen(s, 0, zauber.uid, 0);
  assert.strictEqual(Spiel.effektiveAng(s, 0, 0, null), 1300);
  s.phase = 'schicksal';
  Spiel.kampfPhase(s);
  Spiel.weiter(s);
  assert.strictEqual(s.spieler[0].feld[0].tempAng, 0);
});

// ------------------------------------------------------------------ Gesamtlauf

test('Ein vollständiges KI-Duell endet mit einem Sieger', () => {
  for (let seed = 1; seed <= 25; seed++) {
    const s = Spiel.erstelleSpiel({ seed });
    let schritte = 0;
    while (s.phase !== 'ende' && schritte < 4000) {
      schritte++;
      if (s.phase === 'einsatz') {
        const zug = KI.einsatzZug(s);
        Spiel.einsatzAktion(s, s.einsatz.toAct, zug.aktion, zug.betrag);
      } else if (s.phase === 'beschwoerung') {
        const pIdx = s.aktiverSpieler;
        const aktion = KI.naechsteBeschwoerung(s);
        if (aktion.typ === 'karte') Spiel.karteSpielen(s, pIdx, aktion.uid, aktion.zielSlot);
        else Spiel.beschwoerungBeenden(s, pIdx);
      } else {
        Spiel.weiter(s);
      }
    }
    assert.strictEqual(s.phase, 'ende', `Seed ${seed} endet nicht (Runde ${s.runde}, ${schritte} Schritte)`);
    assert.ok(s.sieger === null || s.sieger === 0 || s.sieger === 1);
    assert.ok(s.runde < 200, `Seed ${seed} braucht ${s.runde} Runden`);
  }
});
