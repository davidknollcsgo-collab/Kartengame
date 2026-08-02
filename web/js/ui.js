/* ARKANWETT – Oberflaeche
 *
 * Rendert den Spielzustand in das Markup aus index.html und meldet
 * Spielereingaben an die Steuerung (main.js) zurueck.
 */
(function (root) {
  'use strict';
  var A = root.ARKANWETT;
  var Elemente = A.elemente;
  var Spiel = A.spiel;

  var steuerung = null;
  var zielModus = null;      // { uid, karte } waehrend der Zielauswahl
  var letzteLp = [null, null];
  var toastTimer = null;
  var endeGezeigt = false;

  var $ = function (id) { return document.getElementById(id); };

  var PHASENNAME = {
    einsatz: 'Einsatzphase',
    beschwoerung: 'Beschwörungsphase',
    schicksal: 'Schicksalsphase',
    kampf: 'Kampfphase',
    auswertung: 'Auswertung',
    ende: 'Duell beendet'
  };

  var ARTNAME = { wesen: 'Wesen', zauber: 'Zauber', falle: 'Falle', schicksal: 'Schicksal' };

  // ------------------------------------------------------------ Aufbau

  function init(s) {
    steuerung = s;
    $('btn-regeln').addEventListener('click', zeigeRegeln);
    $('btn-log').addEventListener('click', zeigeChronik);
    $('overlay').addEventListener('click', function (e) {
      if (e.target === $('overlay')) schliesseBlatt();
    });
  }

  // ------------------------------------------------------------ Rendern

  function render(state) {
    var ich = state.spieler[0];
    var gegner = state.spieler[1];

    text('gegner-name', gegner.name);
    wert('gegner-lp', gegner.lp, 1);
    wert('gegner-chips', gegner.chips);
    wert('gegner-hand', gegner.hand.length);
    text('eigen-name', ich.name);
    wert('eigen-lp', ich.lp, 0);
    wert('eigen-chips', ich.chips);
    wert('eigen-deck', ich.deck.length);

    text('runden-anzeige', 'Runde ' + state.runde);
    text('phasen-anzeige', PHASENNAME[state.phase] || state.phase);
    text('pot-anzeige', 'Pot ' + state.pot + ' ◈ · ×' + state.multiplikator);

    var letzte = state.log[state.log.length - 1];
    text('ticker', letzte ? letzte.text : '');

    feld(state, 1, $('gegner-feld'), false);
    feld(state, 0, $('eigen-feld'), true);
    fallen(state, 1, $('gegner-fallen'));
    fallen(state, 0, $('eigen-fallen'));
    schicksalsBand(state, 1, $('gegner-haende'));
    schicksalsBand(state, 0, $('eigen-haende'));

    hand(state);
    kampfbericht(state);
    aktionen(state);
    hinweis(state);

    if (state.phase === 'ende') {
      if (!endeGezeigt) { endeGezeigt = true; zeigeEnde(state); }
    } else {
      endeGezeigt = false;
    }
  }

  function text(id, t) { var el = $(id); if (el.textContent !== t) el.textContent = t; }

  function wert(id, zahl, lpIdx) {
    var el = $(id).querySelector('b');
    if (typeof lpIdx === 'number') {
      if (letzteLp[lpIdx] !== null && zahl < letzteLp[lpIdx]) {
        $(id).classList.remove('blitz');
        void $(id).offsetWidth;
        $(id).classList.add('blitz');
      }
      letzteLp[lpIdx] = zahl;
    }
    el.textContent = zahl;
  }

  function feld(state, pIdx, container, eigen) {
    var p = state.spieler[pIdx];
    container.innerHTML = '';
    p.feld.forEach(function (w, slot) {
      var el = document.createElement('div');
      el.className = 'slot';
      if (w) {
        el.appendChild(feldkarte(state, pIdx, slot, w));
        el.addEventListener('click', function () { zeigeKarte(w, null, state, pIdx, slot); });
      }
      if (eigen && zielModus && w) {
        el.classList.add('zielbar');
        el.addEventListener('click', function (e) {
          e.stopPropagation();
          var uid = zielModus.uid;
          zielModus = null;
          steuerung.spielen(uid, slot);
        }, { once: true, capture: true });
      }
      container.appendChild(el);
    });
  }

  function feldkarte(state, pIdx, slot, w) {
    var ang = Spiel.effektiveAng(state, pIdx, slot, null);
    var ver = Spiel.effektiveVer(state, pIdx, slot);
    var el = document.createElement('div');
    el.className = 'karte' + (ang !== w.ang || ver !== w.ver ? ' gebufft' : '');
    el.dataset.element = w.element;
    el.innerHTML =
      '<div class="kopf"><span class="stufe">★' + w.stufe + '</span>' +
      '<span class="el">' + Elemente.symbol(w.element) + '</span></div>' +
      '<div class="titel">' + w.name + '</div>' +
      '<div class="werte"><span class="ang">' + ang + '</span><span class="ver">' + ver + '</span></div>';
    return el;
  }

  function fallen(state, pIdx, container) {
    var p = state.spieler[pIdx];
    container.innerHTML = '';
    p.fallen.forEach(function (f) {
      var el = document.createElement('div');
      el.className = 'slot slot--falle';
      if (f) {
        var k = document.createElement('div');
        k.className = 'karte karte--rueckseite';
        if (pIdx === 0) {
          k.textContent = '🜃';
          k.title = f.name;
          el.addEventListener('click', function () { zeigeKarte(f); });
        } else {
          k.textContent = '?';
        }
        el.appendChild(k);
      }
      container.appendChild(el);
    });
  }

  function schicksalsBand(state, pIdx, container) {
    container.innerHTML = '';
    (state.schicksalsHaende[pIdx] || []).forEach(function (h) {
      var el = document.createElement('span');
      el.className = 'hand-chip';
      el.textContent = h.name;
      el.addEventListener('click', function () {
        zeigeBlatt('<h2>' + h.name + '</h2><p class="meta">' + h.bedingung + '</p><p>' + h.effekt + '</p>' +
          '<div class="knopfreihe"><button class="knopf" data-schliessen>Schließen</button></div>');
      });
      container.appendChild(el);
    });
  }

  function hand(state) {
    var p = state.spieler[0];
    var container = $('hand');
    container.innerHTML = '';
    if (!p.hand.length) {
      var leer = document.createElement('div');
      leer.className = 'ticker';
      leer.textContent = 'Keine Karten auf der Hand.';
      container.appendChild(leer);
      return;
    }
    p.hand.forEach(function (k) {
      var hindernis = Spiel.spielHindernis(state, 0, k);
      var kosten = Spiel.beschwoerungskosten(state, 0, k);
      var el = document.createElement('div');
      el.className = 'handkarte ' + (hindernis ? 'gesperrt' : 'spielbar');
      el.dataset.art = k.art;
      if (k.art === 'wesen') el.dataset.element = k.element;
      el.innerHTML =
        '<div class="kosten">' + kosten + '</div>' +
        (k.art === 'wesen'
          ? '<div class="kopf"><span class="stufe">★' + k.stufe + '</span><span class="el">' + Elemente.symbol(k.element) + '</span></div>' +
            '<div class="titel">' + k.name + '</div>' +
            '<div class="werte"><span class="ang">' + k.ang + '</span><span class="ver">' + k.ver + '</span></div>'
          : '<div class="art">' + ARTNAME[k.art] + '</div>' +
            '<div class="titel">' + k.name + '</div>' +
            '<div class="art">' + (k.ziel === 'eigenesWesen' ? 'Ziel wählen' : '&nbsp;') + '</div>');
      el.addEventListener('click', function () { zeigeKarte(k, hindernis, state); });
      container.appendChild(el);
    });
  }

  function kampfbericht(state) {
    var box = $('kampfbericht');
    var b = state.kampfBericht;
    if (!b || (state.phase !== 'kampf' && state.phase !== 'auswertung')) {
      box.hidden = true;
      return;
    }
    var zeilen = b.schlagabtausche.map(function (e) {
      var links = e.a ? e.a.name + ' ' + e.a.ang : '—';
      var rechts = e.b ? e.b.name + ' ' + e.b.ang : '—';
      var mitte = e.direktA ? '→ direkt' : e.direktB ? 'direkt ←' : '⚔';
      return '<div class="zeile"><span' + (e.zerstoertA ? ' style="opacity:.5"' : '') + '>' + links + '</span>' +
        '<span class="treffer">' + mitte + '</span>' +
        '<span' + (e.zerstoertB ? ' style="opacity:.5"' : '') + '>' + rechts + '</span></div>';
    });
    zeilen.push('<div class="zeile"><span>Du: ' + b.lp[0] + ' LP Schaden</span><span class="treffer">×' +
      state.multiplikator + '</span><span>Gegner: ' + b.lp[1] + ' LP</span></div>');
    if (state.rundenBericht && state.rundenBericht.potAn !== null && state.rundenBericht.pot) {
      zeilen.push('<div class="zeile"><span>Pot ' + state.rundenBericht.pot + ' ◈ an</span><span class="treffer">' +
        state.spieler[state.rundenBericht.potAn].name + '</span></div>');
    }
    box.innerHTML = zeilen.join('');
    box.hidden = false;
  }

  function hinweis(state) {
    var el = $('hinweis');
    if (zielModus) {
      el.hidden = false;
      el.textContent = 'Ziel für ' + zielModus.karte.name + ' antippen';
      return;
    }
    if (state.phase === 'beschwoerung' && state.aktiverSpieler === 0) {
      var frei = state.spieler[0].freieBeschwoerung;
      el.hidden = !frei;
      if (frei) el.textContent = 'Stufen-Straße: nächste Beschwörung kostenlos';
      return;
    }
    el.hidden = true;
  }

  function aktionen(state) {
    var leiste = $('aktionen');
    leiste.innerHTML = '';

    if (zielModus) {
      leiste.appendChild(knopf('Abbrechen', function () { zielModus = null; render(state); }));
      return;
    }

    switch (state.phase) {
      case 'einsatz':
        if (state.einsatz.toAct !== 0) {
          leiste.appendChild(warten('Arkanmeister überlegt …'));
          return;
        }
        Spiel.einsatzOptionen(state, 0).forEach(function (o) {
          var haupt = o.aktion === 'mitgehen' || o.aktion === 'setzen';
          leiste.appendChild(knopf(o.label, function () {
            if (o.aktion === 'setzen' || o.aktion === 'erhoehen') zeigeStepper(state, o);
            else steuerung.einsatz(o.aktion);
          }, haupt, o.aktion === 'aussteigen'));
        });
        return;

      case 'beschwoerung':
        if (state.aktiverSpieler !== 0) {
          leiste.appendChild(warten('Arkanmeister beschwört …'));
          return;
        }
        leiste.appendChild(knopf('Karte antippen zum Spielen', null, false));
        leiste.appendChild(knopf('Fertig', function () { steuerung.fertig(); }, true));
        return;

      case 'schicksal':
        leiste.appendChild(knopf('Zum Kampf ⚔', function () { steuerung.weiter(); }, true));
        return;

      case 'kampf':
        leiste.appendChild(knopf('Runde auswerten', function () { steuerung.weiter(); }, true));
        return;

      case 'auswertung':
        leiste.appendChild(knopf('Nächste Runde', function () { steuerung.weiter(); }, true));
        return;

      case 'ende':
        leiste.appendChild(knopf('Neues Duell', function () { steuerung.neu(); }, true));
        return;

      default:
        return;
    }
  }

  function knopf(label, fn, haupt, gefahr) {
    var b = document.createElement('button');
    b.className = 'knopf' + (haupt ? ' knopf--haupt' : '') + (gefahr ? ' knopf--gefahr' : '');
    b.textContent = label;
    if (fn) b.addEventListener('click', fn);
    else b.disabled = true;
    return b;
  }

  function warten(label) {
    var b = knopf(label, null);
    b.classList.add('knopf--warten');
    return b;
  }

  // ------------------------------------------------------------ Blaetter

  function zeigeBlatt(html, nachRender) {
    var blatt = $('blatt');
    blatt.innerHTML = html;
    $('overlay').hidden = false;
    blatt.querySelectorAll('[data-schliessen]').forEach(function (b) {
      b.addEventListener('click', schliesseBlatt);
    });
    if (nachRender) nachRender(blatt);
  }

  function schliesseBlatt() { $('overlay').hidden = true; }

  function zeigeKarte(k, hindernis, state, feldSpieler, feldSlot) {
    var kopf = k.art === 'wesen'
      ? 'Stufe ' + k.stufe + ' · ' + Elemente.symbol(k.element) + ' ' + k.element +
        (k.elementOriginal && k.element !== k.elementOriginal ? ' (gewandelt)' : '')
      : ARTNAME[k.art];
    var werte = '';
    if (k.art === 'wesen') {
      var ang = k.ang, ver = k.ver;
      if (state && typeof feldSpieler === 'number') {
        ang = Spiel.effektiveAng(state, feldSpieler, feldSlot, null);
        ver = Spiel.effektiveVer(state, feldSpieler, feldSlot);
      }
      werte = '<div class="werteBlock"><span class="ang" style="color:var(--feuer)">ANG ' + ang + '</span>' +
        '<span class="ver" style="color:var(--blau)">VER ' + ver + '</span></div>';
    }
    var aufHand = state && state.spieler[0].hand.indexOf(k) >= 0;
    var knoepfe = '<div class="knopfreihe">';
    if (aufHand) {
      knoepfe += hindernis
        ? '<button class="knopf" disabled>' + hindernis + '</button>'
        : '<button class="knopf knopf--haupt" data-spielen>Spielen (' +
          Spiel.beschwoerungskosten(state, 0, k) + ' ◈)</button>';
    }
    knoepfe += '<button class="knopf" data-schliessen>Schließen</button></div>';

    zeigeBlatt(
      '<h2>' + k.name + '</h2><p class="meta">' + kopf + ' · Kosten ' + k.kosten + ' ◈</p>' +
      werte + (k.text ? '<p>' + k.text + '</p>' : '') + knoepfe,
      function (blatt) {
        var b = blatt.querySelector('[data-spielen]');
        if (!b) return;
        b.addEventListener('click', function () {
          schliesseBlatt();
          if (k.ziel === 'eigenesWesen') {
            zielModus = { uid: k.uid, karte: k };
            render(state);
          } else {
            steuerung.spielen(k.uid);
          }
        });
      }
    );
  }

  function zeigeStepper(state, option) {
    var betrag = Math.min(option.min, option.max);
    var maximum = option.max;
    zeigeBlatt(
      '<h2>' + (option.aktion === 'setzen' ? 'Einsatz setzen' : 'Erhöhen') + '</h2>' +
      '<p class="meta">Der finale Einsatz bestimmt den Kampf-Multiplikator.</p>' +
      '<div class="stepper"><button data-minus>−</button><span class="betrag" data-betrag>' + betrag +
      '</span><button data-plus>+</button></div>' +
      '<p class="meta" data-vorschau></p>' +
      '<div class="knopfreihe"><button class="knopf knopf--haupt" data-ok>Bestätigen</button>' +
      '<button class="knopf" data-schliessen>Zurück</button></div>',
      function (blatt) {
        var anzeige = blatt.querySelector('[data-betrag]');
        var vorschau = blatt.querySelector('[data-vorschau]');
        function aktualisiere() {
          anzeige.textContent = betrag;
          var gesamt = Math.max(state.einsatz.betraege[0], state.einsatz.betraege[1]) + betrag;
          vorschau.textContent = 'Einsatz danach: ' + gesamt + ' ◈ → Multiplikator ×' + Spiel.multiplikatorFuer(gesamt);
        }
        blatt.querySelector('[data-minus]').addEventListener('click', function () {
          betrag = Math.max(option.min, betrag - 1); aktualisiere();
        });
        blatt.querySelector('[data-plus]').addEventListener('click', function () {
          betrag = Math.min(maximum, betrag + 1); aktualisiere();
        });
        blatt.querySelector('[data-ok]').addEventListener('click', function () {
          schliesseBlatt();
          steuerung.einsatz(option.aktion, betrag);
        });
        aktualisiere();
      }
    );
  }

  function zeigeChronik() {
    var state = steuerung.zustand();
    var zeilen = state.log.slice(-60).reverse().map(function (e) {
      return '<div class="typ-' + e.typ + '">R' + e.runde + ' · ' + e.text + '</div>';
    }).join('');
    zeigeBlatt('<h2>Chronik</h2><div class="logliste">' + zeilen + '</div>' +
      '<div class="knopfreihe"><button class="knopf" data-schliessen>Schließen</button></div>');
  }

  function zeigeRegeln() {
    zeigeBlatt(
      '<h2>ARKANWETT</h2><p class="meta">Strategie trifft Bluff — 1 gegen 1.</p>' +
      '<h3>Ziel</h3><p>Bring die Lebenspunkte des Gegners auf 0 <b>oder</b> dränge ihn aus seinen Chips.</p>' +
      '<h3>Rundenablauf</h3><ul>' +
      '<li><b>Einsatzphase</b> – Setzen, Erhöhen, Mitgehen, Aussteigen. Der finale Einsatz bestimmt den Kampf-Multiplikator (×1 bis ×4).</li>' +
      '<li><b>Beschwörungsphase</b> – Wesen, Zauber, Fallen und Schicksalskarten kosten Chips aus demselben Pool.</li>' +
      '<li><b>Schicksalsphase</b> – offene Wesen bilden Schicksalshände mit Boni.</li>' +
      '<li><b>Kampfphase</b> – Wesen gleicher Spalte treffen aufeinander: Schaden = (ANG − VER) ÷ 400 × Multiplikator.</li>' +
      '<li><b>Auswertung</b> – der Pot geht an den Spieler mit mehr Schaden, dann +3 Chips Nachschub.</li>' +
      '</ul>' +
      '<h3>Elemente</h3><p>🔥 Feuer → 🪨 Erde → 🌪️ Luft → 💧 Wasser → 🔥 Feuer (je +400 ANG im Vorteil).<br>' +
      '✨ Licht ⇄ 🌑 Schatten neutralisieren sich, dominieren aber alle anderen.</p>' +
      '<h3>Schicksalshände</h3><ul>' +
      A.haende.DEFINITIONEN.map(function (d) {
        return '<li><b>' + d.name + '</b> – ' + d.bedingung + ': ' + d.effekt + '</li>';
      }).join('') + '</ul>' +
      '<div class="knopfreihe"><button class="knopf" data-schliessen>Schließen</button></div>');
  }

  function zeigeEnde(state) {
    var sieg = state.sieger === 0;
    zeigeBlatt(
      '<h2>' + (state.sieger === null ? 'Unentschieden' : sieg ? 'Sieg!' : 'Niederlage') + '</h2>' +
      '<p class="meta">' + state.siegGrund + '</p>' +
      '<p>Runden: ' + state.runde + ' · Deine LP: ' + state.spieler[0].lp + ' · Chips: ' + state.spieler[0].chips + '</p>' +
      '<div class="knopfreihe"><button class="knopf knopf--haupt" data-neu>Neues Duell</button>' +
      '<button class="knopf" data-schliessen>Brett ansehen</button></div>',
      function (blatt) {
        blatt.querySelector('[data-neu]').addEventListener('click', function () {
          schliesseBlatt();
          steuerung.neu();
        });
      });
  }

  function toast(nachricht) {
    var el = $('toast');
    el.textContent = nachricht;
    el.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { el.hidden = true; }, 2200);
  }

  /* Wird vom Android-Wrapper an der Zurück-Taste aufgerufen:
     schliesst zuerst Blatt bzw. Zielauswahl, sonst darf die App beendet werden. */
  root.ARKANWETT_ZURUECK = function () {
    if (!$('overlay').hidden) { schliesseBlatt(); return true; }
    if (zielModus) {
      zielModus = null;
      if (steuerung) render(steuerung.zustand());
      return true;
    }
    return false;
  };

  A.ui = {
    init: init,
    render: render,
    toast: toast,
    zielAbbrechen: function () { zielModus = null; }
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
