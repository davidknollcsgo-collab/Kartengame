/* ARKANWETT – Schicksalshaende
 *
 * Werden am Ende der Beschwoerungsphase auf den offenen Wesen im eigenen Feld
 * ermittelt und wirken auf die anschliessende Kampfphase.
 *
 * Da die Wesen-Zone in dieser Umsetzung 3 Plaetze hat (Poker-Blaetter brauchen 5
 * Karten), ist "Vollbund" an das Format angepasst: Drilling gleicher Stufe, in dem
 * mindestens zwei Wesen dasselbe Element teilen. Siehe docs/REGELN.md.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else (root.ARKANWETT = root.ARKANWETT || {}).haende = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var DEFINITIONEN = [
    { key: 'elementarPaar', name: 'Elementar-Paar', bedingung: '2 Wesen gleichen Elements im Feld',
      effekt: '+200 ANG auf die Wesen dieses Elements' },
    { key: 'stufenStrasse', name: 'Stufen-Straße', bedingung: '3 Wesen mit aufsteigenden Stufen',
      effekt: 'Nächste Wesen-Beschwörung ist kostenlos' },
    { key: 'elementFlush', name: 'Element-Flush', bedingung: 'Alle 3 Feldwesen teilen ein Element',
      effekt: 'Gegnerische Fallen sind diese Runde deaktiviert' },
    { key: 'vollbund', name: 'Vollbund', bedingung: 'Drilling gleicher Stufe mit mindestens einem Elementpaar',
      effekt: '5 Chips vom Gegner-Pool abziehen' },
    { key: 'schattenlicht', name: 'Schattenlicht', bedingung: 'Licht- und Schattenwesen gleichzeitig im Feld',
      effekt: 'Doppelter Schaden in der Kampfphase' }
  ];

  var NACH_KEY = {};
  DEFINITIONEN.forEach(function (d) { NACH_KEY[d.key] = d; });

  function zaehle(liste) {
    var m = {};
    liste.forEach(function (x) { m[x] = (m[x] || 0) + 1; });
    return m;
  }

  /**
   * Ermittelt alle Schicksalshaende eines Feldes.
   * @param {Array} feld     Wesen-Zone (Array mit Wesen oder null)
   * @param {Object} [opts]  { wildElemente: true } – Zwillingsschicksal aktiv
   * @returns {Array} Liste von { key, name, bedingung, effekt, element? }
   */
  function bewerte(feld, opts) {
    opts = opts || {};
    var wesen = (feld || []).filter(Boolean);
    var treffer = [];
    if (wesen.length < 2) return treffer;

    var elemente = wesen.map(function (w) { return w.element; });
    var stufen = wesen.map(function (w) { return w.stufe; });
    var elCount = zaehle(elemente);
    var stCount = zaehle(stufen);

    // Elementar-Paar
    var paarElement = null;
    if (opts.wildElemente) {
      paarElement = elemente[0];
    } else {
      Object.keys(elCount).forEach(function (el) {
        if (elCount[el] >= 2 && !paarElement) paarElement = el;
      });
    }
    if (paarElement) {
      treffer.push(mit('elementarPaar', { element: opts.wildElemente ? null : paarElement }));
    }

    // Stufen-Strasse: 3 Wesen mit aufsteigenden, aufeinanderfolgenden Stufen
    if (wesen.length >= 3) {
      var sortiert = stufen.slice().sort(function (a, b) { return a - b; });
      var luecken = true;
      for (var i = 1; i < sortiert.length; i++) {
        if (sortiert[i] !== sortiert[i - 1] + 1) luecken = false;
      }
      if (luecken) treffer.push(mit('stufenStrasse'));
    }

    // Element-Flush: alle Feldwesen (mind. 3) teilen ein Element
    if (wesen.length >= 3 && (opts.wildElemente || elCount[elemente[0]] === wesen.length)) {
      treffer.push(mit('elementFlush'));
    }

    // Vollbund: Drilling gleicher Stufe + mindestens ein Elementpaar darin
    if (wesen.length >= 3) {
      var drilling = Object.keys(stCount).some(function (s) { return stCount[s] >= 3; });
      var hatPaar = opts.wildElemente || Object.keys(elCount).some(function (el) { return elCount[el] >= 2; });
      if (drilling && hatPaar) treffer.push(mit('vollbund'));
    }

    // Schattenlicht
    if (elemente.indexOf('Licht') >= 0 && elemente.indexOf('Schatten') >= 0) {
      treffer.push(mit('schattenlicht'));
    }

    return treffer;
  }

  function mit(key, extra) {
    var d = NACH_KEY[key];
    var o = { key: d.key, name: d.name, bedingung: d.bedingung, effekt: d.effekt };
    if (extra) for (var k in extra) if (Object.prototype.hasOwnProperty.call(extra, k)) o[k] = extra[k];
    return o;
  }

  return { DEFINITIONEN: DEFINITIONEN, bewerte: bewerte };
});
