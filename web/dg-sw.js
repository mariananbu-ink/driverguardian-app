/* DriverGuardian web app — service worker: shows push notifications sent by the
 * server through Firebase Cloud Messaging and opens the app when one is tapped.
 * Network first: the app always loads fresh; the last copy is only used when offline.
 * Developed & Powered by Marian Anbu Juwan */
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

// Network first — the app always loads fresh; the last copy is used only when offline.
// (A real fetch handler also lets Chrome offer “Install app”.)
var CACHE = 'dg-app-v1';
self.addEventListener('fetch', function (e) {
  var r = e.request;
  if (r.method !== 'GET' || r.url.indexOf(self.registration.scope) !== 0) return;
  e.respondWith(fetch(r).then(function (res) {
    if (res && res.ok && (r.mode === 'navigate' || /\.(js|json|wasm|png|html)$/.test(new URL(r.url).pathname))) {
      var copy = res.clone();
      caches.open(CACHE).then(function (c) { c.put(r, copy); }).catch(function () {});
    }
    return res;
  }).catch(function () {
    return caches.match(r).then(function (m) { return m || caches.match(self.registration.scope); });
  }));
});

self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { notification: { body: e.data ? e.data.text() : '' } }; }
  var n = d.notification || {};
  var data = d.data || {};
  var title = n.title || data.title || 'DriverGuardian';
  var body = n.body || data.body || '';
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      list.forEach(function (c) { c.postMessage({ dgPush: { title: title, body: body } }); });
      return self.registration.showNotification(title, {
        body: body,
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-maskable-192.png',
        tag: data.type || undefined,
        renotify: !!data.type,
        data: { type: data.type || '' }
      });
    })
  );
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var scope = self.registration.scope;
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].url.indexOf(scope) === 0 && 'focus' in list[i]) return list[i].focus();
      }
      return self.clients.openWindow(scope);
    })
  );
});
