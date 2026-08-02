/* ARKANWETT – Gegner-KI ("Arkanmeister")
 *
 * Bewusst lesbar statt optimal: eine Lagebewertung, daraus abgeleitet ein
 * Einsatzverhalten (inklusive gelegentlichem Bluff) und eine Prioritaetenliste
 * fuer die Beschwoerungsphase.
 */
(function (root, factory) {
  var mod = typeof module === 'object' && module.exports;
  var api = factory(mod ? require('./game.js') : root.ARKANWETT.spiel);
  if (mod) module.exports = api;
  else (root.ARKANWETT = root.ARKANWETT || {}).ki = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (Spiel) {
  'use strict';

  var RESERVE = 2; // Chips, die die KI fuer die naechste Einsatzphase zuruecklegt

  function feldstaerke(state, pIdx) {
    var p = state.spieler[pIdx];
    return p.feld.reduce(function (summe, w, slot) {
      return summe + (w ? Spiel.effektiveAng(state, pIdx, slot, null) + Spiel.effektiveVer(state, pIdx, slot) : 0);
    }, 0);
  }

  /** Lagebewertung zwischen 0 (aussichtslos) und 1 (dominant). */
  function lage(state, pIdx) {
    var p = state.spieler[pIdx];
    var g = state.spieler[1 - pIdx];
    var diff = feldstaerke(state, pIdx) - feldstaerke(state, 1 - pIdx);
    var handWesen = p.hand.filter(function (k) { return k.art === 'wesen' && k.kosten <= p.chips; });
    var bestes = handWesen.reduce(function (m, k) { return Math.max(m, k.ang); }, 0);
    var wert = 0.45
      + diff / 8000
      + bestes / 12000
      + (p.lp - g.lp) / 120
      + (p.chips - g.chips) / 200;
    return Math.max(0, Math.min(1, wert));
  }

  // ---------------------------------------------------------------- Einsatzphase

  function einsatzZug(state) {
    var pIdx = state.einsatz.toAct;
    var p = state.spieler[pIdx];
    var e = state.einsatz;
    var hoch = Math.max(e.betraege[0], e.betraege[1]);
    var offen = hoch - e.betraege[pIdx];
    var s = lage(state, pIdx);
    var zufall = state.rnd();

    // Ein sicherer Sieg per Chip-Aushungerung ist die Erhoehung wert.
    var gegner = state.spieler[1 - pIdx];
    var druck = gegner.chips <= 3 && p.chips > gegner.chips + 3;

    if (offen === 0) {
      if ((s > 0.62 || druck || zufall < 0.12) && p.chips >= 2 && e.betraege[pIdx] < 8) {
        return { aktion: 'setzen', betrag: s > 0.8 || druck ? 3 : 2 };
      }
      return { aktion: 'passen' };
    }

    if (offen >= p.chips) {
      // All-in-Entscheidung
      return s > 0.45 ? { aktion: 'mitgehen' } : { aktion: 'aussteigen' };
    }
    if (s > 0.75 && p.chips > offen + 3 && e.betraege[pIdx] < 8) {
      return { aktion: 'erhoehen', betrag: 2 };
    }
    if (s > 0.34 || offen <= 2 || zufall < 0.1) {
      return { aktion: 'mitgehen' };
    }
    return { aktion: 'aussteigen' };
  }

  // ---------------------------------------------------------------- Beschwoerungsphase

  function bezahlbar(state, pIdx, karte) {
    return !Spiel.spielHindernis(state, pIdx, karte);
  }

  /** Liefert die naechste Aktion der KI in der Beschwoerungsphase. */
  function naechsteBeschwoerung(state) {
    var pIdx = state.aktiverSpieler;
    var p = state.spieler[pIdx];
    var g = state.spieler[1 - pIdx];
    var frei = function (art) { return p.hand.filter(function (k) { return k.art === art && bezahlbar(state, pIdx, k); }); };
    var puffer = p.freieBeschwoerung ? 0 : RESERVE;

    // 1. Toedlicher Direktschaden zuerst
    var aderlass = p.hand.find(function (k) { return k.id === 'aderlass' && bezahlbar(state, pIdx, k); });
    if (aderlass && g.lp <= 2) return { typ: 'karte', uid: aderlass.uid };

    // 2. Wesen-Zone fuellen – das staerkste bezahlbare Wesen zuerst
    if (p.feld.indexOf(null) >= 0) {
      var wesen = frei('wesen')
        .filter(function (k) { return Spiel.beschwoerungskosten(state, pIdx, k) <= p.chips - puffer || p.freieBeschwoerung; })
        .sort(function (a, b) { return (b.ang + b.ver) - (a.ang + a.ver); });
      if (wesen.length) return { typ: 'karte', uid: wesen[0].uid };
    }

    // 3. Gegnerisches Wesen entfernen, wenn es unsere Seite dominiert
    var bannwelle = p.hand.find(function (k) { return k.id === 'bannwelle' && bezahlbar(state, pIdx, k); });
    if (bannwelle && Spiel.feldWesen(g).length >= 2 && p.chips >= 4 + puffer) {
      return { typ: 'karte', uid: bannwelle.uid };
    }

    // 4. Kampfbuffs, wenn ein Schlagabtausch dadurch kippt
    var buff = p.hand.find(function (k) {
      return (k.id === 'flammenstoss' || k.id === 'steinhaut') && bezahlbar(state, pIdx, k) && p.chips >= k.kosten + puffer;
    });
    if (buff) {
      var slot = besterBuffSlot(state, pIdx, buff.id);
      if (slot >= 0) return { typ: 'karte', uid: buff.uid, zielSlot: slot };
    }

    // 5. Falle legen, solange Chips uebrig sind
    if (p.fallen.indexOf(null) >= 0) {
      var falle = frei('falle')
        .filter(function (k) { return p.chips >= k.kosten + puffer + 1; })
        .sort(function (a, b) { return a.kosten - b.kosten; })[0];
      if (falle && state.rnd() < 0.7) return { typ: 'karte', uid: falle.uid };
    }

    // 6. Schicksalskarte als Ueberraschung, wenn die Runde gross ist
    var schicksal = frei('schicksal').filter(function (k) { return p.chips >= k.kosten + puffer; })[0];
    if (schicksal && state.multiplikator >= 2 && Spiel.feldWesen(p).length >= 2) {
      return { typ: 'karte', uid: schicksal.uid };
    }

    // 7. Ressourcen nachladen
    var nachschub = p.hand.find(function (k) {
      return (k.id === 'energiefluss' && p.chips <= 4) || (k.id === 'kartenzug' && p.hand.length <= 3);
    });
    if (nachschub && bezahlbar(state, pIdx, nachschub)) return { typ: 'karte', uid: nachschub.uid };

    if (aderlass && p.chips >= 3 + puffer && g.lp <= 6) return { typ: 'karte', uid: aderlass.uid };

    return { typ: 'fertig' };
  }

  /** Slot, dessen Schlagabtausch der Buff tatsaechlich dreht (sonst -1). */
  function besterBuffSlot(state, pIdx, buffId) {
    var p = state.spieler[pIdx];
    var g = state.spieler[1 - pIdx];
    var treffer = -1;
    p.feld.forEach(function (w, slot) {
      if (!w || treffer >= 0) return;
      var feind = g.feld[slot];
      if (!feind) return;
      var meinAng = Spiel.effektiveAng(state, pIdx, slot, feind);
      var meinVer = Spiel.effektiveVer(state, pIdx, slot);
      var feindAng = Spiel.effektiveAng(state, 1 - pIdx, slot, w);
      var feindVer = Spiel.effektiveVer(state, 1 - pIdx, slot);
      if (buffId === 'flammenstoss' && meinAng <= feindVer && meinAng + 500 > feindVer) treffer = slot;
      if (buffId === 'steinhaut' && feindAng > meinVer && feindAng <= meinVer + 500) treffer = slot;
    });
    return treffer;
  }

  return {
    lage: lage,
    feldstaerke: feldstaerke,
    einsatzZug: einsatzZug,
    naechsteBeschwoerung: naechsteBeschwoerung
  };
});
