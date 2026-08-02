/* ARKANWETT – Service Worker: haelt das Spiel offline spielbar.
 * Nur fuer die Web-/PWA-Variante relevant; im Android-WebView laeuft alles ohnehin lokal.
 */
var CACHE = 'arkanwett-v1';
var DATEIEN = [
  './',
  './index.html',
  './styles.css',
  './manifest.webmanifest',
  './js/elements.js',
  './js/cards.js',
  './js/hands.js',
  './js/game.js',
  './js/ai.js',
  './js/ui.js',
  './js/main.js',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(DATEIEN); }).then(function () {
    return self.skipWaiting();
  }));
});

self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (namen) {
    return Promise.all(namen.filter(function (n) { return n !== CACHE; })
      .map(function (n) { return caches.delete(n); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener('fetch', function (e) {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(function (treffer) {
      return treffer || fetch(e.request).then(function (antwort) {
        var kopie = antwort.clone();
        caches.open(CACHE).then(function (c) { c.put(e.request, kopie); });
        return antwort;
      }).catch(function () { return caches.match('./index.html'); });
    })
  );
});
