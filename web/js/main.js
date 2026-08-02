/* ARKANWETT – Steuerung
 *
 * Haelt den Spielzustand, leitet Spielereingaben an die Engine weiter und
 * laesst die KI ihre Zuege mit kurzer Verzoegerung spielen, damit sie sichtbar sind.
 */
(function (root) {
  'use strict';
  var A = root.ARKANWETT;
  var Spiel = A.spiel;
  var KI = A.ki;
  var UI = A.ui;

  var KI_PAUSE = 750;
  var state = null;
  var kiTimer = null;

  function neu() {
    clearTimeout(kiTimer);
    UI.zielAbbrechen();
    state = Spiel.erstelleSpiel({ name: 'Du', gegnerName: 'Arkanmeister' });
    zeichne();
  }

  function zeichne() {
    UI.render(state);
    planeKi();
  }

  function geschuetzt(fn) {
    try {
      fn();
    } catch (fehler) {
      UI.toast(fehler.message || String(fehler));
    }
    zeichne();
  }

  function planeKi() {
    clearTimeout(kiTimer);
    if (state.phase === 'ende' || !Spiel.istKiAmZug(state)) return;
    kiTimer = setTimeout(function () {
      try {
        if (state.phase === 'einsatz') {
          var zug = KI.einsatzZug(state);
          Spiel.einsatzAktion(state, state.einsatz.toAct, zug.aktion, zug.betrag);
        } else if (state.phase === 'beschwoerung') {
          var pIdx = state.aktiverSpieler;
          var aktion = KI.naechsteBeschwoerung(state);
          if (aktion.typ === 'karte') Spiel.karteSpielen(state, pIdx, aktion.uid, aktion.zielSlot);
          else Spiel.beschwoerungBeenden(state, pIdx);
        }
      } catch (fehler) {
        // Die KI darf das Spiel nicht blockieren: im Zweifel Zug beenden.
        try {
          if (state.phase === 'einsatz') Spiel.einsatzAktion(state, state.einsatz.toAct, 'passen');
          else if (state.phase === 'beschwoerung') Spiel.beschwoerungBeenden(state, state.aktiverSpieler);
        } catch (e) { /* aufgeben, Zustand bleibt bedienbar */ }
      }
      zeichne();
    }, KI_PAUSE);
  }

  var steuerung = {
    zustand: function () { return state; },
    einsatz: function (aktion, betrag) {
      geschuetzt(function () { Spiel.einsatzAktion(state, 0, aktion, betrag); });
    },
    spielen: function (uid, zielSlot) {
      geschuetzt(function () { Spiel.karteSpielen(state, 0, uid, zielSlot); });
    },
    fertig: function () {
      geschuetzt(function () { Spiel.beschwoerungBeenden(state, 0); });
    },
    weiter: function () {
      geschuetzt(function () { Spiel.weiter(state); });
    },
    neu: neu
  };

  document.addEventListener('DOMContentLoaded', function () {
    UI.init(steuerung);
    neu();
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
