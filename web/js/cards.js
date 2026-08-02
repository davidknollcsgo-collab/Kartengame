/* ARKANWETT – Kartenpool und Deckbau
 *
 * Kartenarten:
 *   wesen     – Stufe, Element, ANG/VER, optionale Faehigkeit
 *   zauber    – sofortiger Effekt, offen gespielt
 *   falle     – verdeckt gelegt, loest zu Beginn der Kampfphase aus
 *   schicksal – starker Effekt, kostet zusaetzlich Chips (teurer Bluff)
 *
 * Faehigkeiten (Wesen):
 *   zug1     – Bei Beschwoerung: ziehe 1 Karte
 *   chip2    – Bei Beschwoerung: +2 Chips
 *   brand    – Bei Beschwoerung: 1 LP direkter Schaden
 *   bollwerk – +200 VER je weiterem eigenen Wesen im Feld
 *   jaeger   – +300 ANG gegen Wesen niedrigerer Stufe
 *   zoll     – Gegner zahlt 1 Chip extra je Beschwoerung
 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else (root.ARKANWETT = root.ARKANWETT || {}).karten = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  function wesen(id, name, element, stufe, ang, ver, faehigkeit, text) {
    return {
      id: id, name: name, art: 'wesen', element: element, stufe: stufe,
      ang: ang, ver: ver, kosten: Math.ceil(stufe / 2),
      faehigkeit: faehigkeit || null, text: text || ''
    };
  }

  var WESEN = [
    // Feuer
    wesen('funkengeist', 'Funkengeist', 'Feuer', 1, 500, 400, 'zug1', 'Bei Beschwörung: ziehe 1 Karte.'),
    wesen('glutkobold', 'Glutkobold', 'Feuer', 2, 800, 600, null, ''),
    wesen('aschewolf', 'Aschewolf', 'Feuer', 3, 1200, 800, 'jaeger', '+300 ANG gegen Wesen niedrigerer Stufe.'),
    wesen('flammenritter', 'Flammenritter', 'Feuer', 4, 1600, 1200, null, ''),
    wesen('magmatitan', 'Magmatitan', 'Feuer', 7, 2400, 2100, 'brand', 'Bei Beschwörung: 1 LP direkter Schaden.'),
    // Wasser
    wesen('quellnymphe', 'Quellnymphe', 'Wasser', 1, 400, 700, 'zug1', 'Bei Beschwörung: ziehe 1 Karte.'),
    wesen('nebelkoi', 'Nebelkoi', 'Wasser', 2, 700, 900, 'chip2', 'Bei Beschwörung: +2 Chips.'),
    wesen('tiefenlauerer', 'Tiefenlauerer', 'Wasser', 3, 1100, 1000, null, ''),
    wesen('gezeitenwaechter', 'Gezeitenwächter', 'Wasser', 5, 1800, 1500, null, ''),
    wesen('abyssalschlange', 'Abyssalschlange', 'Wasser', 6, 2100, 1600, 'jaeger', '+300 ANG gegen Wesen niedrigerer Stufe.'),
    // Erde
    wesen('lehmspaeher', 'Lehmspäher', 'Erde', 1, 500, 500, 'chip2', 'Bei Beschwörung: +2 Chips.'),
    wesen('steinbeisser', 'Steinbeißer', 'Erde', 2, 900, 1000, null, ''),
    wesen('wurzelgolem', 'Wurzelgolem', 'Erde', 4, 1300, 1800, 'bollwerk', '+200 VER je weiterem eigenen Wesen.'),
    wesen('bergvogt', 'Bergvogt', 'Erde', 5, 1700, 1700, 'zoll', 'Gegner zahlt 1 Chip extra je Beschwörung.'),
    wesen('erzkoloss', 'Erzkoloss', 'Erde', 8, 2600, 2400, 'bollwerk', '+200 VER je weiterem eigenen Wesen.'),
    // Luft
    wesen('boeengeist', 'Böengeist', 'Luft', 1, 600, 300, null, ''),
    wesen('sturmfalke', 'Sturmfalke', 'Luft', 2, 1000, 500, null, ''),
    wesen('windlaeufer', 'Windläufer', 'Luft', 3, 1200, 700, 'zug1', 'Bei Beschwörung: ziehe 1 Karte.'),
    wesen('wolkenschmied', 'Wolkenschmied', 'Luft', 5, 1700, 1300, 'chip2', 'Bei Beschwörung: +2 Chips.'),
    wesen('orkanserpent', 'Orkanserpent', 'Luft', 7, 2300, 1800, 'jaeger', '+300 ANG gegen Wesen niedrigerer Stufe.'),
    // Licht
    wesen('sonnenwaechterin', 'Sonnenwächterin', 'Licht', 4, 1500, 1500, null, ''),
    wesen('lichtherold', 'Lichtherold', 'Licht', 6, 2000, 1900, 'zug1', 'Bei Beschwörung: ziehe 1 Karte.'),
    wesen('aurorafuerst', 'Aurorafürst', 'Licht', 9, 2800, 2500, 'brand', 'Bei Beschwörung: 1 LP direkter Schaden.'),
    // Schatten
    wesen('schattenpirscher', 'Schattenpirscher', 'Schatten', 3, 1300, 600, 'jaeger', '+300 ANG gegen Wesen niedrigerer Stufe.'),
    wesen('nachtmahr', 'Nachtmahr', 'Schatten', 6, 2000, 1500, 'brand', 'Bei Beschwörung: 1 LP direkter Schaden.'),
    wesen('leerenfuerst', 'Leerenfürst', 'Schatten', 9, 2900, 2300, 'zoll', 'Gegner zahlt 1 Chip extra je Beschwörung.')
  ];

  var AKTIONEN = [
    // Zauber – sofort, offen
    { id: 'flammenstoss', name: 'Flammenstoß', art: 'zauber', kosten: 2, ziel: 'eigenesWesen',
      text: 'Ein eigenes Wesen erhält +500 ANG für diese Runde.' },
    { id: 'steinhaut', name: 'Steinhaut', art: 'zauber', kosten: 2, ziel: 'eigenesWesen',
      text: 'Ein eigenes Wesen erhält +500 VER für diese Runde.' },
    { id: 'elementwandel', name: 'Elementwandel', art: 'zauber', kosten: 2, ziel: 'eigenesWesen',
      text: 'Ein eigenes Wesen nimmt das Element an, das dem stärksten gegnerischen Wesen überlegen ist.' },
    { id: 'aderlass', name: 'Aderlass', art: 'zauber', kosten: 3, ziel: 'keins',
      text: 'Der Gegner verliert 2 LP.' },
    { id: 'energiefluss', name: 'Energiefluss', art: 'zauber', kosten: 1, ziel: 'keins',
      text: 'Erhalte 3 Chips.' },
    { id: 'kartenzug', name: 'Kartenzug', art: 'zauber', kosten: 2, ziel: 'keins',
      text: 'Ziehe 2 Karten.' },
    { id: 'bannwelle', name: 'Bannwelle', art: 'zauber', kosten: 4, ziel: 'keins',
      text: 'Zerstöre das schwächste gegnerische Wesen (nach ANG).' },

    // Fallen – verdeckt, loesen zu Beginn der Kampfphase aus
    { id: 'elementbann', name: 'Elementbann', art: 'falle', kosten: 2, ziel: 'keins',
      text: 'Gegnerische Wesen erhalten diese Runde keinen Elementvorteil.' },
    { id: 'spiegelschild', name: 'Spiegelschild', art: 'falle', kosten: 2, ziel: 'keins',
      text: 'Halbiert den Kampfschaden, den du diese Runde erleidest.' },
    { id: 'energiediebstahl', name: 'Energiediebstahl', art: 'falle', kosten: 1, ziel: 'keins',
      text: 'Stiehl dem Gegner 2 Chips.' },
    { id: 'gegenschlag', name: 'Gegenschlag', art: 'falle', kosten: 2, ziel: 'keins',
      text: 'Erleidest du Kampfschaden, verliert der Gegner 2 LP.' },
    { id: 'zeitfalle', name: 'Zeitfalle', art: 'falle', kosten: 3, ziel: 'keins',
      text: 'Der Einsatz-Multiplikator des Gegners sinkt diese Runde um 1.' },

    // Schicksalskarten – teuer, stark, riskant
    { id: 'paktdesabgrunds', name: 'Pakt des Abgrunds', art: 'schicksal', kosten: 4, ziel: 'keins',
      text: 'Alle eigenen Wesen: +1000 ANG. Am Rundenende verlierst du 3 LP.' },
    { id: 'orakelderwende', name: 'Orakel der Wende', art: 'schicksal', kosten: 5, ziel: 'keins',
      text: 'Der Kampf-Multiplikator dieser Runde wird auf ×4 gesetzt.' },
    { id: 'seelenopfer', name: 'Seelenopfer', art: 'schicksal', kosten: 3, ziel: 'eigenesWesen',
      text: 'Zerstöre ein eigenes Wesen: Der Gegner verliert ANG ÷ 600 LP.' },
    { id: 'zwillingsschicksal', name: 'Zwillingsschicksal', art: 'schicksal', kosten: 4, ziel: 'keins',
      text: 'Deine Wesen gelten diese Runde für Schicksalshände als jedes Element.' },
    { id: 'letzteslicht', name: 'Letztes Licht', art: 'schicksal', kosten: 6, ziel: 'keins',
      text: 'Heile 5 LP.' }
  ];

  var POOL = {};
  WESEN.concat(AKTIONEN).forEach(function (k) { POOL[k.id] = k; });

  /** Standarddeck: 40 Karten (22 Wesen, 10 Zauber, 6 Fallen, 2 Schicksalskarten). */
  var STANDARDDECK = [
    // Wesen (22)
    ['funkengeist', 1], ['glutkobold', 2], ['aschewolf', 1], ['flammenritter', 1], ['magmatitan', 1],
    ['quellnymphe', 1], ['nebelkoi', 1], ['tiefenlauerer', 1], ['gezeitenwaechter', 1],
    ['lehmspaeher', 1], ['steinbeisser', 1], ['wurzelgolem', 1], ['bergvogt', 1],
    ['boeengeist', 1], ['sturmfalke', 1], ['windlaeufer', 1], ['wolkenschmied', 1],
    ['sonnenwaechterin', 1], ['lichtherold', 1],
    ['schattenpirscher', 1], ['nachtmahr', 1],
    // Zauber (10)
    ['flammenstoss', 2], ['steinhaut', 2], ['elementwandel', 1], ['aderlass', 2],
    ['energiefluss', 1], ['kartenzug', 1], ['bannwelle', 1],
    // Fallen (6)
    ['elementbann', 2], ['spiegelschild', 1], ['energiediebstahl', 1], ['gegenschlag', 1], ['zeitfalle', 1],
    // Schicksal (2)
    ['paktdesabgrunds', 1], ['orakelderwende', 1]
  ];

  var uidZaehler = 0;

  /** Erzeugt eine spielbare Karteninstanz mit eindeutiger uid. */
  function instanz(id) {
    var vorlage = POOL[id];
    if (!vorlage) throw new Error('Unbekannte Karte: ' + id);
    var k = {};
    for (var key in vorlage) if (Object.prototype.hasOwnProperty.call(vorlage, key)) k[key] = vorlage[key];
    k.uid = ++uidZaehler;
    if (k.art === 'wesen') {
      k.tempAng = 0;
      k.tempVer = 0;
      k.elementOriginal = k.element;
    }
    return k;
  }

  /** Baut ein vollstaendiges 40-Karten-Deck (unsortiert). */
  function baueDeck() {
    var deck = [];
    STANDARDDECK.forEach(function (eintrag) {
      for (var i = 0; i < eintrag[1]; i++) deck.push(instanz(eintrag[0]));
    });
    return deck;
  }

  return {
    WESEN: WESEN,
    AKTIONEN: AKTIONEN,
    POOL: POOL,
    STANDARDDECK: STANDARDDECK,
    instanz: instanz,
    baueDeck: baueDeck
  };
});
