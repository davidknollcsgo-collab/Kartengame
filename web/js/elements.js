/* ARKANWETT – Elementsystem
 *
 * Feuer -> Erde -> Luft -> Wasser -> Feuer   (jedes ist stark gegen das naechste)
 * Licht <-> Schatten                          (neutralisieren sich, dominieren sonst alle)
 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else (root.ARKANWETT = root.ARKANWETT || {}).elemente = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var KREISLAUF = ['Feuer', 'Erde', 'Luft', 'Wasser'];
  var DUAL = ['Licht', 'Schatten'];
  var ALLE = KREISLAUF.concat(DUAL);

  var SYMBOL = {
    Feuer: '🔥',
    Erde: '🪨',
    Luft: '🌪️',
    Wasser: '💧',
    Licht: '☀️',
    Schatten: '🌙'
  };

  /** Bonus in ANG-Punkten, den ein Elementvorteil im Schlagabtausch gewaehrt. */
  var VORTEIL_BONUS = 400;

  /** Ist Element a im Vorteil gegenueber Element b? */
  function schlaegt(a, b) {
    if (!a || !b || a === b) return false;
    var aDual = DUAL.indexOf(a) >= 0;
    var bDual = DUAL.indexOf(b) >= 0;
    if (aDual && bDual) return false; // Licht und Schatten neutralisieren sich
    if (aDual) return true; // Licht/Schatten dominieren alle anderen
    if (bDual) return false;
    var i = KREISLAUF.indexOf(a);
    return i >= 0 && KREISLAUF[(i + 1) % KREISLAUF.length] === b;
  }

  /** Welches Element schlaegt das uebergebene Element? (fuer "Elementwandel") */
  function konterElement(b) {
    if (DUAL.indexOf(b) >= 0) return null; // gegen Licht/Schatten hilft kein Kreislauf
    var i = KREISLAUF.indexOf(b);
    if (i < 0) return null;
    return KREISLAUF[(i + KREISLAUF.length - 1) % KREISLAUF.length];
  }

  return {
    KREISLAUF: KREISLAUF,
    DUAL: DUAL,
    ALLE: ALLE,
    SYMBOL: SYMBOL,
    VORTEIL_BONUS: VORTEIL_BONUS,
    schlaegt: schlaegt,
    konterElement: konterElement,
    symbol: function (el) { return SYMBOL[el] || '·'; }
  };
});
