/* ARKANWETT – Spiel-Engine
 *
 * Reine Logik, kein DOM. Der Zustand ist ein einfaches Objekt; alle Funktionen
 * veraendern ihn und schreiben Ereignisse ins Log. Die Oberflaeche rendert danach neu.
 *
 * Phasen einer Runde:
 *   einsatz -> beschwoerung -> schicksal -> kampf -> auswertung -> (naechste Runde)
 */
(function (root, factory) {
  var mod = typeof module === 'object' && module.exports;
  var api = factory(
    mod ? require('./elements.js') : root.ARKANWETT.elemente,
    mod ? require('./cards.js') : root.ARKANWETT.karten,
    mod ? require('./hands.js') : root.ARKANWETT.haende
  );
  if (mod) module.exports = api;
  else (root.ARKANWETT = root.ARKANWETT || {}).spiel = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (Elemente, Karten, Haende) {
  'use strict';

  var K = {
    START_LP: 20,
    START_CHIPS: 20,
    STARTHAND: 5,
    HANDLIMIT: 7,
    NACHSCHUB: 2,
    FELD_PLAETZE: 3,
    FALLEN_PLAETZE: 2,
    MAX_MULTIPLIKATOR: 4,
    SCHADEN_TEILER: 400,
    DIREKT_ANTEIL: 0.5, // ungeblockte Wesen richten nur den halben ANG-Wert aus
    MIN_EINSATZ: 1,
    FOLD_STRAFE: 2,
    PAAR_BONUS: 200
  };

  // ---------------------------------------------------------------- Zufall

  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function mische(liste, rnd) {
    for (var i = liste.length - 1; i > 0; i--) {
      var j = Math.floor(rnd() * (i + 1));
      var t = liste[i]; liste[i] = liste[j]; liste[j] = t;
    }
    return liste;
  }

  // ---------------------------------------------------------------- Aufbau

  function neueFx() {
    return {
      angBonusAlle: 0,
      paarBonusElement: null,
      lpKostenEnde: 0,
      wildElemente: false,
      fallenDeaktiviert: false,
      elementbann: false,
      spiegelschild: false,
      gegenschlag: false,
      zeitfalle: false,
      doppelschaden: false
    };
  }

  function neuerSpieler(idx, name, ki, rnd) {
    return {
      idx: idx,
      name: name,
      ki: !!ki,
      lp: K.START_LP,
      chips: K.START_CHIPS,
      deck: mische(Karten.baueDeck(), rnd),
      hand: [],
      feld: new Array(K.FELD_PLAETZE).fill(null),
      fallen: new Array(K.FALLEN_PLAETZE).fill(null),
      ablage: [],
      fx: neueFx(),
      freieBeschwoerung: false,
      schadenDieseRunde: 0
    };
  }

  function erstelleSpiel(opts) {
    opts = opts || {};
    var seed = typeof opts.seed === 'number' ? opts.seed : Math.floor(Math.random() * 1e9);
    var rnd = mulberry32(seed);
    var state = {
      seed: seed,
      rnd: rnd,
      runde: 0,
      phase: 'start',
      startspieler: 0,
      spieler: [
        neuerSpieler(0, opts.name || 'Du', false, rnd),
        neuerSpieler(1, opts.gegnerName || 'Arkanmeister', true, rnd)
      ],
      einsatz: null,
      multiplikator: 1,
      pot: 0,
      beschwoerungFertig: [false, false],
      aktiverSpieler: 0,
      schicksalsHaende: [[], []],
      kampfBericht: null,
      rundenBericht: null,
      log: [],
      sieger: null,
      siegGrund: null
    };
    state.spieler.forEach(function (p) { ziehe(state, p.idx, K.STARTHAND, true); });
    protokoll(state, 'Beide Duellanten ziehen ' + K.STARTHAND + ' Karten. Das Duell beginnt.', 'system');
    neueRunde(state);
    return state;
  }

  // ---------------------------------------------------------------- Hilfen

  function gegnerVon(state, p) { return state.spieler[1 - p]; }

  function protokoll(state, text, typ, spieler) {
    state.log.push({ runde: state.runde, text: text, typ: typ || 'info', spieler: spieler });
    if (state.log.length > 400) state.log.shift();
  }

  function ziehe(state, pIdx, anzahl, still) {
    var p = state.spieler[pIdx];
    var gezogen = 0;
    for (var i = 0; i < anzahl; i++) {
      if (p.hand.length >= K.HANDLIMIT) {
        if (!still) protokoll(state, p.name + ' hat das Handlimit erreicht und zieht nicht.', 'info', pIdx);
        break;
      }
      if (!p.deck.length) {
        if (!p.ablage.length) break;
        p.deck = mische(p.ablage, state.rnd);
        p.ablage = [];
        if (!still) protokoll(state, p.name + ' mischt die Ablage zurück ins Deck.', 'info', pIdx);
      }
      p.hand.push(p.deck.pop());
      gezogen++;
    }
    return gezogen;
  }

  function ablegen(state, pIdx, karte) {
    var p = state.spieler[pIdx];
    if (karte.art === 'wesen') {
      karte.tempAng = 0;
      karte.tempVer = 0;
      karte.element = karte.elementOriginal;
    }
    p.ablage.push(karte);
  }

  function feldWesen(p) { return p.feld.filter(Boolean); }

  function schaden(state, pIdx, betrag, grund) {
    if (betrag <= 0) return;
    var p = state.spieler[pIdx];
    p.lp = Math.max(0, p.lp - betrag);
    protokoll(state, p.name + ' verliert ' + betrag + ' LP (' + grund + '). Rest: ' + p.lp + ' LP.', 'schaden', pIdx);
  }

  // ---------------------------------------------------------------- Runde

  function neueRunde(state) {
    if (state.phase === 'ende') return state;
    state.runde++;
    state.kampfBericht = null;
    state.rundenBericht = null;
    state.schicksalsHaende = [[], []];
    state.multiplikator = 1;
    state.pot = 0;
    state.beschwoerungFertig = [false, false];
    if (state.runde > 1) state.startspieler = 1 - state.startspieler;

    // Gewinnbedingung: wer die Einsatzphase nicht mehr bestreiten kann, verliert.
    // Wird vor dem Nachschub geprueft, sonst waere niemand je ausgeblutet.
    var leer = state.spieler.filter(function (p) { return p.chips <= 0; });
    if (leer.length === 1) {
      return beendeSpiel(state, 1 - leer[0].idx, leer[0].name + ' hat keine Chips mehr und kann nicht mitgehen.');
    }

    state.spieler.forEach(function (p) {
      p.fx = neueFx();
      p.schadenDieseRunde = 0;
      if (state.runde > 1) {
        p.chips += K.NACHSCHUB;
        ziehe(state, p.idx, 1);
      }
    });

    protokoll(state, '— Runde ' + state.runde + ' — ' + state.spieler[state.startspieler].name + ' eröffnet die Einsatzphase.', 'runde');

    state.phase = 'einsatz';
    state.einsatz = {
      betraege: [0, 0],
      toAct: state.startspieler,
      gehandelt: [false, false],
      geschlossen: false
    };
    state.aktiverSpieler = state.startspieler;
    return state;
  }

  // ---------------------------------------------------------------- Einsatzphase

  /** Welche Einsatz-Aktionen stehen dem Spieler gerade offen? */
  function einsatzOptionen(state, pIdx) {
    if (state.phase !== 'einsatz' || state.einsatz.toAct !== pIdx) return [];
    var e = state.einsatz;
    var p = state.spieler[pIdx];
    var hoch = Math.max(e.betraege[0], e.betraege[1]);
    var offen = hoch - e.betraege[pIdx];
    var opt = [];
    if (offen === 0) {
      opt.push({ aktion: 'passen', label: 'Schieben' });
      if (p.chips >= K.MIN_EINSATZ) opt.push({ aktion: 'setzen', label: 'Setzen', min: K.MIN_EINSATZ, max: p.chips });
    } else {
      opt.push({ aktion: 'mitgehen', label: 'Mitgehen (' + Math.min(offen, p.chips) + ')', kosten: Math.min(offen, p.chips) });
      if (p.chips > offen) opt.push({ aktion: 'erhoehen', label: 'Erhöhen', min: K.MIN_EINSATZ, max: p.chips - offen });
      opt.push({ aktion: 'aussteigen', label: 'Aussteigen' });
    }
    return opt;
  }

  function einsatzAktion(state, pIdx, aktion, betrag) {
    if (state.phase !== 'einsatz') throw new Error('Keine Einsatzphase.');
    var e = state.einsatz;
    if (e.toAct !== pIdx) throw new Error('Der andere Duellant ist am Zug.');
    var p = state.spieler[pIdx];
    var hoch = Math.max(e.betraege[0], e.betraege[1]);
    var offen = hoch - e.betraege[pIdx];

    if (aktion === 'aussteigen') {
      protokoll(state, p.name + ' steigt aus.', 'einsatz', pIdx);
      return rundeAbschliessen(state, { grund: 'aussteigen', aussteiger: pIdx });
    }

    if (aktion === 'passen') {
      if (offen > 0) throw new Error('Es steht ein Einsatz offen.');
      protokoll(state, p.name + ' schiebt.', 'einsatz', pIdx);
      e.gehandelt[pIdx] = true;
      if (e.gehandelt[0] && e.gehandelt[1]) return einsatzSchliessen(state);
      e.toAct = 1 - pIdx;
      state.aktiverSpieler = e.toAct;
      return state;
    }

    if (aktion === 'mitgehen') {
      var zahlung = Math.min(offen, p.chips);
      p.chips -= zahlung;
      e.betraege[pIdx] += zahlung;
      protokoll(state, p.name + ' geht mit (' + zahlung + ' Chips' + (p.chips === 0 ? ', All-in' : '') + ').', 'einsatz', pIdx);
      e.gehandelt[pIdx] = true;
      return einsatzSchliessen(state);
    }

    if (aktion === 'setzen' || aktion === 'erhoehen') {
      var erhoehung = Math.max(K.MIN_EINSATZ, Math.floor(betrag || K.MIN_EINSATZ));
      var kosten = offen + erhoehung;
      if (kosten > p.chips) throw new Error('Nicht genug Chips.');
      p.chips -= kosten;
      e.betraege[pIdx] += kosten;
      protokoll(state, p.name + (aktion === 'setzen' ? ' setzt ' : ' erhöht um ') + erhoehung +
        ' (Einsatz: ' + e.betraege[pIdx] + ').', 'einsatz', pIdx);
      e.gehandelt = [false, false];
      e.gehandelt[pIdx] = true;
      e.toAct = 1 - pIdx;
      state.aktiverSpieler = e.toAct;
      return state;
    }

    throw new Error('Unbekannte Einsatz-Aktion: ' + aktion);
  }

  function einsatzSchliessen(state) {
    var e = state.einsatz;
    // All-in-Ausgleich: ueberzahlte Chips gehen zurueck.
    var min = Math.min(e.betraege[0], e.betraege[1]);
    for (var i = 0; i < 2; i++) {
      if (e.betraege[i] > min) {
        var rueck = e.betraege[i] - min;
        state.spieler[i].chips += rueck;
        e.betraege[i] = min;
        protokoll(state, state.spieler[i].name + ' erhält ' + rueck + ' nicht gedeckte Chips zurück.', 'einsatz', i);
      }
    }
    e.geschlossen = true;
    state.pot = e.betraege[0] + e.betraege[1];
    state.multiplikator = multiplikatorFuer(min);
    protokoll(state, 'Einsatz steht bei ' + min + ' — Kampf-Multiplikator ×' + state.multiplikator +
      ' (Pot: ' + state.pot + ' Chips).', 'einsatz');
    state.phase = 'beschwoerung';
    state.aktiverSpieler = state.startspieler;
    state.beschwoerungFertig = [false, false];
    return state;
  }

  function multiplikatorFuer(einsatz) {
    return Math.min(K.MAX_MULTIPLIKATOR, 1 + Math.floor(einsatz / 3));
  }

  // ---------------------------------------------------------------- Beschwoerungsphase

  function beschwoerungskosten(state, pIdx, karte) {
    var p = state.spieler[pIdx];
    if (karte.art !== 'wesen') return karte.kosten;
    if (p.freieBeschwoerung) return 0;
    var zoll = feldWesen(gegnerVon(state, pIdx)).some(function (w) { return w.faehigkeit === 'zoll'; }) ? 1 : 0;
    return karte.kosten + zoll;
  }

  /** Kann die Karte gerade gespielt werden? Gibt null oder einen Grund zurueck. */
  function spielHindernis(state, pIdx, karte) {
    if (state.phase !== 'beschwoerung') return 'Keine Beschwörungsphase.';
    if (state.aktiverSpieler !== pIdx) return 'Der Gegner ist am Zug.';
    var p = state.spieler[pIdx];
    if (beschwoerungskosten(state, pIdx, karte) > p.chips) return 'Zu wenig Chips.';
    if (karte.art === 'wesen' && p.feld.indexOf(null) < 0) return 'Wesen-Zone ist voll.';
    if (karte.art === 'falle' && p.fallen.indexOf(null) < 0) return 'Fallen-Zone ist voll.';
    if (karte.ziel === 'eigenesWesen' && !feldWesen(p).length) return 'Kein eigenes Wesen im Feld.';
    if (karte.id === 'bannwelle' && !feldWesen(gegnerVon(state, pIdx)).length) return 'Kein gegnerisches Wesen im Feld.';
    return null;
  }

  /**
   * Spielt eine Handkarte.
   * @param {number} zielSlot Index in der eigenen Wesen-Zone (fuer ziel === 'eigenesWesen')
   */
  function karteSpielen(state, pIdx, uid, zielSlot) {
    var p = state.spieler[pIdx];
    var idx = p.hand.findIndex(function (k) { return k.uid === uid; });
    if (idx < 0) throw new Error('Karte nicht auf der Hand.');
    var karte = p.hand[idx];
    var hindernis = spielHindernis(state, pIdx, karte);
    if (hindernis) throw new Error(hindernis);

    var kosten = beschwoerungskosten(state, pIdx, karte);
    if (karte.art === 'wesen' && p.freieBeschwoerung) {
      p.freieBeschwoerung = false;
      protokoll(state, p.name + ' nutzt die freie Beschwörung der Stufen-Straße.', 'schicksal', pIdx);
    }
    p.chips -= kosten;
    p.hand.splice(idx, 1);

    if (karte.art === 'wesen') {
      var slot = p.feld.indexOf(null);
      p.feld[slot] = karte;
      protokoll(state, p.name + ' beschwört ' + karte.name + ' (Stufe ' + karte.stufe + ', ' +
        karte.element + ', ANG ' + karte.ang + '/VER ' + karte.ver + ') für ' + kosten + ' Chips.', 'beschwoerung', pIdx);
      wesenFaehigkeit(state, pIdx, karte);
    } else if (karte.art === 'falle') {
      var fslot = p.fallen.indexOf(null);
      p.fallen[fslot] = karte;
      protokoll(state, p.name + ' legt eine Karte verdeckt.', 'beschwoerung', pIdx);
    } else {
      protokoll(state, p.name + ' wirkt ' + karte.name + ' für ' + kosten + ' Chips.',
        karte.art === 'schicksal' ? 'schicksal' : 'zauber', pIdx);
      aktionsEffekt(state, pIdx, karte, zielSlot);
      ablegen(state, pIdx, karte);
    }
    pruefeLebenspunkte(state);
    return state;
  }

  function wesenFaehigkeit(state, pIdx, karte) {
    var p = state.spieler[pIdx];
    switch (karte.faehigkeit) {
      case 'zug1':
        if (ziehe(state, pIdx, 1)) protokoll(state, karte.name + ': ' + p.name + ' zieht 1 Karte.', 'effekt', pIdx);
        break;
      case 'chip2':
        p.chips += 2;
        protokoll(state, karte.name + ': ' + p.name + ' erhält 2 Chips.', 'effekt', pIdx);
        break;
      case 'brand':
        protokoll(state, karte.name + ': Glutschlag!', 'effekt', pIdx);
        schaden(state, 1 - pIdx, 1, karte.name);
        break;
      default:
        break;
    }
  }

  function aktionsEffekt(state, pIdx, karte, zielSlot) {
    var p = state.spieler[pIdx];
    var g = gegnerVon(state, pIdx);
    var ziel = typeof zielSlot === 'number' ? p.feld[zielSlot] : null;
    if (karte.ziel === 'eigenesWesen' && !ziel) {
      ziel = feldWesen(p)[0];
      zielSlot = p.feld.indexOf(ziel);
    }

    switch (karte.id) {
      case 'flammenstoss':
        ziel.tempAng += 500;
        protokoll(state, ziel.name + ' lodert auf: +500 ANG.', 'effekt', pIdx);
        break;
      case 'steinhaut':
        ziel.tempVer += 500;
        protokoll(state, ziel.name + ' versteinert: +500 VER.', 'effekt', pIdx);
        break;
      case 'elementwandel':
        var stark = feldWesen(g).sort(function (a, b) { return b.ang - a.ang; })[0];
        var neu = stark ? Elemente.konterElement(stark.element) : null;
        if (neu) {
          ziel.element = neu;
          protokoll(state, ziel.name + ' wechselt zu ' + neu + '.', 'effekt', pIdx);
        } else {
          protokoll(state, 'Elementwandel verpufft — kein Element ist im Vorteil.', 'effekt', pIdx);
        }
        break;
      case 'aderlass':
        schaden(state, g.idx, 2, 'Aderlass');
        break;
      case 'energiefluss':
        p.chips += 3;
        protokoll(state, p.name + ' erhält 3 Chips.', 'effekt', pIdx);
        break;
      case 'kartenzug':
        var n = ziehe(state, pIdx, 2);
        protokoll(state, p.name + ' zieht ' + n + ' Karte(n).', 'effekt', pIdx);
        break;
      case 'bannwelle':
        var schwach = feldWesen(g).sort(function (a, b) { return a.ang - b.ang; })[0];
        if (schwach) {
          zerstoere(state, g.idx, g.feld.indexOf(schwach), 'Bannwelle');
        }
        break;
      case 'paktdesabgrunds':
        p.fx.angBonusAlle += 1000;
        p.fx.lpKostenEnde += 3;
        protokoll(state, 'Der Abgrund antwortet: alle Wesen von ' + p.name + ' erhalten +1000 ANG (Preis: 3 LP).', 'effekt', pIdx);
        break;
      case 'orakelderwende':
        state.multiplikator = 4;
        protokoll(state, 'Das Orakel dreht die Runde: Multiplikator ×4.', 'effekt', pIdx);
        break;
      case 'seelenopfer':
        var opfer = ziel;
        var lp = Math.floor(opfer.ang / 600);
        zerstoere(state, pIdx, zielSlot, 'Seelenopfer');
        schaden(state, g.idx, lp, 'Seelenopfer');
        break;
      case 'zwillingsschicksal':
        p.fx.wildElemente = true;
        protokoll(state, 'Zwillingsschicksal: Elemente von ' + p.name + ' zählen als jedes Element.', 'effekt', pIdx);
        break;
      case 'letzteslicht':
        p.lp += 5;
        protokoll(state, p.name + ' heilt 5 LP (jetzt ' + p.lp + ').', 'effekt', pIdx);
        break;
      default:
        break;
    }
  }

  function zerstoere(state, pIdx, slot, grund) {
    var p = state.spieler[pIdx];
    var w = p.feld[slot];
    if (!w) return;
    p.feld[slot] = null;
    ablegen(state, pIdx, w);
    protokoll(state, w.name + ' von ' + p.name + ' wird zerstört (' + grund + ').', 'kampf', pIdx);
  }

  function beschwoerungBeenden(state, pIdx) {
    if (state.phase !== 'beschwoerung') throw new Error('Keine Beschwörungsphase.');
    if (state.aktiverSpieler !== pIdx) throw new Error('Der Gegner ist am Zug.');
    state.beschwoerungFertig[pIdx] = true;
    protokoll(state, state.spieler[pIdx].name + ' beendet die Beschwörung.', 'beschwoerung', pIdx);
    if (state.beschwoerungFertig[0] && state.beschwoerungFertig[1]) return schicksalsPhase(state);
    state.aktiverSpieler = 1 - pIdx;
    return state;
  }

  // ---------------------------------------------------------------- Schicksalsphase

  function schicksalsPhase(state) {
    state.phase = 'schicksal';
    for (var i = 0; i < 2; i++) {
      var p = state.spieler[i];
      var haende = Haende.bewerte(p.feld, { wildElemente: p.fx.wildElemente });
      state.schicksalsHaende[i] = haende;
      haende.forEach(function (h) { wendeHandAn(state, i, h); });
    }
    if (!state.schicksalsHaende[0].length && !state.schicksalsHaende[1].length) {
      protokoll(state, 'Keine Schicksalshand bildet sich.', 'schicksal');
    }
    return state;
  }

  function wendeHandAn(state, pIdx, hand) {
    var p = state.spieler[pIdx];
    var g = gegnerVon(state, pIdx);
    protokoll(state, 'Schicksalshand für ' + p.name + ': ' + hand.name + ' — ' + hand.effekt + '.', 'schicksal', pIdx);
    switch (hand.key) {
      case 'elementarPaar':
        p.fx.paarBonusElement = hand.element || 'alle';
        break;
      case 'stufenStrasse':
        p.freieBeschwoerung = true;
        break;
      case 'elementFlush':
        g.fx.fallenDeaktiviert = true;
        break;
      case 'vollbund':
        var raub = Math.min(5, g.chips);
        g.chips -= raub;
        p.chips += raub;
        protokoll(state, p.name + ' zieht ' + raub + ' Chips aus dem Pool von ' + g.name + '.', 'schicksal', pIdx);
        break;
      case 'schattenlicht':
        p.fx.doppelschaden = true;
        break;
      default:
        break;
    }
  }

  // ---------------------------------------------------------------- Kampfphase

  function effektiveVer(state, pIdx, slot) {
    var p = state.spieler[pIdx];
    var w = p.feld[slot];
    if (!w) return 0;
    var ver = w.ver + w.tempVer;
    if (w.faehigkeit === 'bollwerk') ver += 200 * (feldWesen(p).length - 1);
    return ver;
  }

  function effektiveAng(state, pIdx, slot, gegnerWesen) {
    var p = state.spieler[pIdx];
    var g = gegnerVon(state, pIdx);
    var w = p.feld[slot];
    if (!w) return 0;
    var ang = w.ang + w.tempAng + p.fx.angBonusAlle;
    if (p.fx.paarBonusElement && (p.fx.paarBonusElement === 'alle' || p.fx.paarBonusElement === w.element)) {
      ang += K.PAAR_BONUS;
    }
    if (w.faehigkeit === 'jaeger' && gegnerWesen && gegnerWesen.stufe < w.stufe) ang += 300;
    if (gegnerWesen && !g.fx.elementbann && Elemente.schlaegt(w.element, gegnerWesen.element)) {
      ang += Elemente.VORTEIL_BONUS;
    }
    return ang;
  }

  function fallenAusloesen(state, pIdx) {
    var p = state.spieler[pIdx];
    var g = gegnerVon(state, pIdx);
    if (p.fx.fallenDeaktiviert) {
      if (p.fallen.some(Boolean)) {
        protokoll(state, 'Die Fallen von ' + p.name + ' sind durch den Element-Flush deaktiviert.', 'kampf', pIdx);
      }
      return;
    }
    p.fallen.forEach(function (falle, i) {
      if (!falle) return;
      protokoll(state, 'Falle offen: ' + falle.name + ' — ' + falle.text, 'kampf', pIdx);
      switch (falle.id) {
        case 'elementbann': p.fx.elementbann = true; break;
        case 'spiegelschild': p.fx.spiegelschild = true; break;
        case 'gegenschlag': p.fx.gegenschlag = true; break;
        case 'zeitfalle': p.fx.zeitfalle = true; break;
        case 'energiediebstahl':
          var raub = Math.min(2, g.chips);
          g.chips -= raub;
          p.chips += raub;
          protokoll(state, p.name + ' stiehlt ' + raub + ' Chips.', 'kampf', pIdx);
          break;
        default: break;
      }
      p.fallen[i] = null;
      ablegen(state, pIdx, falle);
    });
  }

  function kampfPhase(state) {
    if (state.phase !== 'schicksal') throw new Error('Kampf nur nach der Schicksalsphase.');
    state.phase = 'kampf';
    fallenAusloesen(state, state.startspieler);
    fallenAusloesen(state, 1 - state.startspieler);

    var bericht = { schlagabtausche: [], roh: [0, 0], lp: [0, 0], zerstoert: [[], []] };

    for (var slot = 0; slot < K.FELD_PLAETZE; slot++) {
      var a = state.spieler[0].feld[slot];
      var b = state.spieler[1].feld[slot];
      if (!a && !b) continue;
      var angA = a ? effektiveAng(state, 0, slot, b) : 0;
      var angB = b ? effektiveAng(state, 1, slot, a) : 0;
      var verA = a ? effektiveVer(state, 0, slot) : 0;
      var verB = b ? effektiveVer(state, 1, slot) : 0;

      var eintrag = { slot: slot, a: a && { name: a.name, ang: angA, ver: verA, element: a.element },
                      b: b && { name: b.name, ang: angB, ver: verB, element: b.element },
                      rohA: 0, rohB: 0, zerstoertA: false, zerstoertB: false };

      if (a && b) {
        eintrag.rohA = Math.max(0, angA - verB);
        eintrag.rohB = Math.max(0, angB - verA);
        eintrag.zerstoertB = angA > verB;
        eintrag.zerstoertA = angB > verA;
      } else if (a) {
        eintrag.rohA = Math.floor(angA * K.DIREKT_ANTEIL); // Direktangriff auf die Lebenspunkte
        eintrag.direktA = true;
      } else if (b) {
        eintrag.rohB = Math.floor(angB * K.DIREKT_ANTEIL);
        eintrag.direktB = true;
      }
      bericht.roh[0] += eintrag.rohA;
      bericht.roh[1] += eintrag.rohB;
      bericht.schlagabtausche.push(eintrag);
    }

    // Schaden umrechnen
    for (var i = 0; i < 2; i++) {
      var p = state.spieler[i];
      var g = state.spieler[1 - i];
      var mult = Math.max(1, state.multiplikator - (g.fx.zeitfalle ? 1 : 0));
      var lp = Math.floor(bericht.roh[i] / K.SCHADEN_TEILER) * mult;
      if (p.fx.doppelschaden) lp *= 2;
      if (g.fx.spiegelschild) lp = Math.ceil(lp / 2);
      bericht.lp[i] = lp;
      p.schadenDieseRunde = lp;
    }

    // Zerstoerungen anwenden (nach der Schadensberechnung, damit beide Seiten gleichzeitig schlagen)
    bericht.schlagabtausche.forEach(function (e) {
      if (e.zerstoertA) bericht.zerstoert[0].push(e.slot);
      if (e.zerstoertB) bericht.zerstoert[1].push(e.slot);
    });
    bericht.zerstoert.forEach(function (slots, pIdx) {
      slots.forEach(function (slot) { zerstoere(state, pIdx, slot, 'Schlagabtausch'); });
    });

    protokoll(state, 'Kampfphase (×' + state.multiplikator + '): ' + state.spieler[0].name + ' verursacht ' +
      bericht.lp[0] + ' LP, ' + state.spieler[1].name + ' verursacht ' + bericht.lp[1] + ' LP.', 'kampf');
    schaden(state, 1, bericht.lp[0], 'Kampfphase');
    schaden(state, 0, bericht.lp[1], 'Kampfphase');

    // Gegenschlag
    for (var j = 0; j < 2; j++) {
      if (state.spieler[j].fx.gegenschlag && bericht.lp[1 - j] > 0) {
        protokoll(state, 'Gegenschlag von ' + state.spieler[j].name + '!', 'kampf', j);
        schaden(state, 1 - j, 2, 'Gegenschlag');
      }
    }

    state.kampfBericht = bericht;
    pruefeLebenspunkte(state);
    return state;
  }

  // ---------------------------------------------------------------- Auswertung

  function rundeAbschliessen(state, opts) {
    opts = opts || {};
    var bericht = { grund: opts.grund || 'kampf', potAn: null, pot: state.pot, lp: [0, 0] };

    if (opts.grund === 'aussteigen') {
      var aus = opts.aussteiger;
      var sieger = 1 - aus;
      // Beim Aussteigen ist die Einsatzphase nie geschlossen worden – Pot hier bilden.
      state.pot = state.einsatz.betraege[0] + state.einsatz.betraege[1];
      bericht.pot = state.pot;
      state.spieler[sieger].chips += state.pot;
      bericht.potAn = sieger;
      protokoll(state, state.spieler[sieger].name + ' erhält den Pot (' + state.pot + ' Chips).', 'auswertung', sieger);
      schaden(state, aus, K.FOLD_STRAFE, 'Aufgabe der Runde');
      state.pot = 0;
    } else {
      bericht.lp = state.kampfBericht ? state.kampfBericht.lp.slice() : [0, 0];
      // Schicksalskosten (z. B. Pakt des Abgrunds)
      state.spieler.forEach(function (p) {
        if (p.fx.lpKostenEnde > 0) schaden(state, p.idx, p.fx.lpKostenEnde, 'Preis des Schicksals');
      });
      if (state.pot > 0) {
        if (bericht.lp[0] > bericht.lp[1]) {
          state.spieler[0].chips += state.pot;
          bericht.potAn = 0;
        } else if (bericht.lp[1] > bericht.lp[0]) {
          state.spieler[1].chips += state.pot;
          bericht.potAn = 1;
        } else {
          state.spieler[0].chips += state.einsatz.betraege[0];
          state.spieler[1].chips += state.einsatz.betraege[1];
          bericht.potAn = null;
        }
        if (bericht.potAn === null) {
          protokoll(state, 'Unentschieden im Schlagabtausch — die Einsätze wandern zurück.', 'auswertung');
        } else {
          protokoll(state, state.spieler[bericht.potAn].name + ' gewinnt den Pot (' + state.pot + ' Chips).',
            'auswertung', bericht.potAn);
        }
        state.pot = 0;
      }
    }

    // Rundenende: temporaere Werte zuruecksetzen
    state.spieler.forEach(function (p) {
      p.feld.forEach(function (w) {
        if (!w) return;
        w.tempAng = 0;
        w.tempVer = 0;
        w.element = w.elementOriginal;
      });
    });

    state.rundenBericht = bericht;
    state.phase = 'auswertung';
    pruefeLebenspunkte(state);
    if (state.phase !== 'ende') {
      var leer = state.spieler.filter(function (p) { return p.chips <= 0; });
      if (leer.length === 1) {
        beendeSpiel(state, 1 - leer[0].idx, leer[0].name + ' hat keine Chips mehr für die Einsatzphase.');
      }
    }
    return state;
  }

  function pruefeLebenspunkte(state) {
    if (state.phase === 'ende') return state;
    var a = state.spieler[0].lp <= 0;
    var b = state.spieler[1].lp <= 0;
    if (a && b) return beendeSpiel(state, null, 'Beide Duellanten fallen gleichzeitig.');
    if (a) return beendeSpiel(state, 1, state.spieler[0].name + ' hat keine Lebenspunkte mehr.');
    if (b) return beendeSpiel(state, 0, state.spieler[1].name + ' hat keine Lebenspunkte mehr.');
    return state;
  }

  function beendeSpiel(state, siegerIdx, grund) {
    state.phase = 'ende';
    state.sieger = siegerIdx;
    state.siegGrund = grund;
    protokoll(state, (siegerIdx === null ? 'Unentschieden. ' : state.spieler[siegerIdx].name + ' gewinnt! ') + grund, 'ende');
    return state;
  }

  /** Bringt das Spiel von einer Anzeige-Phase zur naechsten. */
  function weiter(state) {
    switch (state.phase) {
      case 'schicksal': return kampfPhase(state);
      case 'kampf': return rundeAbschliessen(state, { grund: 'kampf' });
      case 'auswertung': return neueRunde(state);
      default: return state;
    }
  }

  function istKiAmZug(state) {
    if (state.phase === 'einsatz') return state.spieler[state.einsatz.toAct].ki;
    if (state.phase === 'beschwoerung') return state.spieler[state.aktiverSpieler].ki;
    return false;
  }

  return {
    K: K,
    erstelleSpiel: erstelleSpiel,
    neueRunde: neueRunde,
    einsatzOptionen: einsatzOptionen,
    einsatzAktion: einsatzAktion,
    multiplikatorFuer: multiplikatorFuer,
    beschwoerungskosten: beschwoerungskosten,
    spielHindernis: spielHindernis,
    karteSpielen: karteSpielen,
    beschwoerungBeenden: beschwoerungBeenden,
    schicksalsPhase: schicksalsPhase,
    kampfPhase: kampfPhase,
    rundeAbschliessen: rundeAbschliessen,
    weiter: weiter,
    effektiveAng: effektiveAng,
    effektiveVer: effektiveVer,
    feldWesen: feldWesen,
    gegnerVon: gegnerVon,
    istKiAmZug: istKiAmZug,
    ziehe: ziehe,
    mische: mische,
    mulberry32: mulberry32
  };
});
