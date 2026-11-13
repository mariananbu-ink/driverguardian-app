/* DriverGuardian web app (PWA) bridge — used by the Flutter app through dart:js_interop (lib/web/bridge_web.dart).
 * - registers dg-sw.js (receives push messages, opens the app on tap)
 * - web push via Firebase Cloud Messaging (config comes from the server: System → Mobile push → Web app)
 * - "Allow notifications" and "Add to Home Screen" sheets drawn in HTML, so Safari sees a real tap
 * Developed & Powered by Marian Anbu Juwan */
(function () {
  'use strict';
  var FIREBASE = 'https://www.gstatic.com/firebasejs/10.14.1/';
  var ua = navigator.userAgent || '';
  var ios = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var android = /Android/i.test(ua);
  var installEvent = null;
  var listeners = [];
  var reg = null;

  function standalone() {
    return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
  }

  function registerWorker() {
    if (!('serviceWorker' in navigator)) return Promise.resolve(null);
    if (reg) return Promise.resolve(reg);
    return navigator.serviceWorker.register('dg-sw.js')
      .then(function () { return navigator.serviceWorker.ready; })
      .then(function (r) { reg = r; return r; })
      .catch(function (e) { console.warn('DriverGuardian: service worker not registered', e); return null; });
  }

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (e) {
      var d = e.data && e.data.dgPush;
      if (!d) return;
      listeners.forEach(function (cb) { try { cb(String(d.title || 'DriverGuardian'), String(d.body || '')); } catch (_) {} });
    });
    registerWorker();
  }

  window.addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); installEvent = e; });
  window.addEventListener('appinstalled', function () { installEvent = null; var p = document.getElementById('dgInstall'); if (p) p.remove(); countInstall(); });

  /* install counter for the platform owner (System → Apps): once per phone — on Android's "installed"
     event, or the first time the app is opened from the Home Screen icon (iPhone has no install event) */
  function countInstall() {
    try { if (localStorage.getItem('dg_pwa_counted')) return; localStorage.setItem('dg_pwa_counted', '1'); } catch (e) { return; }
    var p = ios ? 'ios' : (android ? 'android' : 'desktop');
    try { fetch('../app-installed', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'platform=' + p, keepalive: true }); } catch (e) {}
  }
  if (standalone()) countInstall();

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src; s.async = true;
      s.onload = resolve;
      s.onerror = function () { reject(new Error('could not load ' + src)); };
      document.head.appendChild(s);
    });
  }

  /* ---------- bottom sheet (HTML, above the Flutter canvas) */
  var css = false;
  function sheet(html, buttons) {
    if (!css) {
      css = true;
      var st = document.createElement('style');
      st.textContent =
        '.dgx{position:fixed;inset:0;z-index:2147483600;background:rgba(8,12,40,.55);display:flex;align-items:flex-end;justify-content:center;' +
        'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;animation:dgxIn .2s ease}' +
        '.dgx .c{background:#fff;color:#141B3D;width:100%;max-width:480px;border-radius:24px 24px 0 0;padding:22px 22px calc(18px + env(safe-area-inset-bottom));box-shadow:0 -10px 40px rgba(0,0,0,.25);animation:dgxUp .25s ease}' +
        '.dgx h3{margin:0 0 6px;font-size:18px;font-weight:700}.dgx p{margin:0 0 10px;font-size:14px;line-height:1.45;color:#4B5563}' +
        '.dgx ol{margin:6px 0 12px;padding-left:22px;font-size:14px;line-height:1.7;color:#141B3D}.dgx ol svg{vertical-align:-4px}' +
        '.dgx .b{display:flex;gap:10px;margin-top:8px}.dgx button{flex:1;border:0;border-radius:14px;padding:13px 10px;font-size:15px;font-weight:600;cursor:pointer}' +
        '.dgx .p{background:#4F46E5;color:#fff}.dgx .s{background:#EEF2FF;color:#3730A3}' +
        '.dgx .hd{display:flex;align-items:center;gap:12px;margin-bottom:8px}.dgx .hd img{width:44px;height:44px;border-radius:12px}' +
        '@keyframes dgxIn{from{opacity:0}}@keyframes dgxUp{from{transform:translateY(40px)}}';
      document.head.appendChild(st);
    }
    var o = document.createElement('div');
    o.className = 'dgx';
    o.innerHTML = '<div class="c">' + html + '<div class="b"></div></div>';
    var row = o.querySelector('.b');
    buttons.forEach(function (b) {
      var el = document.createElement('button');
      el.className = b.primary ? 'p' : 's';
      el.textContent = b.label;
      el.addEventListener('click', function () { o.remove(); if (b.onClick) b.onClick(); });
      row.appendChild(el);
    });
    o.addEventListener('click', function (e) { if (e.target === o) { o.remove(); var c = buttons.filter(function (b) { return !b.primary; })[0]; if (c && c.onClick) c.onClick(); } });
    document.body.appendChild(o);
    return o;
  }

  var SHARE = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#0A84FF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="M8 7l4-4 4 4"/><path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/></svg>';
  var PLUS = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#141B3D" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="18" height="18" rx="4"/><path d="M12 8v8M8 12h8"/></svg>';

  function inAppBrowser() { return /; wv\)|FBAN|FBAV|Instagram|WhatsApp|Line\/|GSA\//.test(ua); }
  function copyLink() {
    var u = location.href.split('#')[0];
    try { navigator.clipboard.writeText(u); } catch (e) {}
  }

  /** Android Chrome: is this web app already installed on the phone? (manifest related_applications → webapp) */
  function installed() {
    if (!navigator.getInstalledRelatedApps) return Promise.resolve(false);
    return navigator.getInstalledRelatedApps().then(function (l) { return !!(l && l.length); }, function () { return false; });
  }

  function showInstalled() {
    sheet('<div class="hd"><img src="icons/seal-192.png" alt="" onerror="this.onerror=null;this.src=\'icons/Icon-192.png\'"><div><h3>Driver Guardian is installed</h3></div></div>' +
      '<p>Open <b>DriverGuardian</b> from your home screen or app drawer — it opens full screen, signed in.</p>', [
      { label: 'Use in browser' }, { label: 'OK', primary: true }]);
  }

  function showInstallHelp() {
    if (standalone()) {
      sheet('<h3>Already installed</h3><p>You are using DriverGuardian from your Home Screen.</p>', [{ label: 'OK', primary: true }]);
      return;
    }
    if (installEvent) {
      var ev = installEvent;
      installEvent = null;
      ev.prompt();
      return;
    }
    var head = '<div class="hd"><img src="icons/seal-192.png" alt="" onerror="this.onerror=null;this.src=\'icons/Icon-192.png\'"><div><h3>Install Driver Guardian</h3></div></div>';
    if (ios) {
      sheet(head + '<p>Works like an app: full screen, its own icon, and bus alerts as notifications.</p><ol>' +
        '<li>Open this page in <b>Safari</b>.</li>' +
        '<li>Tap <b>Share</b> ' + SHARE + ' (bottom bar, or top right on iPad).</li>' +
        '<li>Scroll and tap <b>Add to Home Screen</b> ' + PLUS + ' → <b>Add</b>.</li>' +
        '<li>Open <b>DriverGuardian</b> from the Home Screen and sign in.</li></ol>' +
        '<p style="font-size:12.5px">Notifications need iOS 16.4 or newer and work only from the Home Screen icon.</p>', [{ label: 'Got it', primary: true }]);
    } else if (android && inAppBrowser()) {
      sheet(head + '<p>This page is open inside another app, which cannot install apps.</p><ol>' +
        '<li>Tap <b>⋮</b> (top right) → <b>Open in Chrome</b>.</li><li>Tap <b>Install Driver Guardian</b> again.</li></ol>', [
        { label: 'Copy link', onClick: copyLink }, { label: 'Got it', primary: true }]);
    } else if (android) {
      sheet(head + '<p>Your browser did not offer the one-tap install yet. Add it from the menu:</p><ol>' +
        '<li>Tap the browser menu <b>⋮</b> (top right).</li><li>Tap <b>Install app</b> or <b>Add to Home screen</b> → <b>Install</b>.</li>' +
        '<li>Open <b>DriverGuardian</b> from the home screen and sign in.</li></ol>' +
        '<p style="font-size:12.5px">Already installed? Open it from the home screen or app drawer. Drivers: use the Android app (GPS keeps running with the screen off).</p>', [{ label: 'Got it', primary: true }]);
    } else {
      sheet(head + '<p>In Chrome or Edge use the <b>Install</b> icon in the address bar. In Safari on Mac: <b>File → Add to Dock</b>.</p>', [{ label: 'Got it', primary: true }]);
    }
  }

  function pushSupported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  function permission() {
    return 'Notification' in window ? Notification.permission : 'unsupported';
  }

  /** Our own sheet first: Safari only allows the permission prompt from a real tap. */
  function askPermission() {
    if (!('Notification' in window)) return Promise.resolve('unsupported');
    if (Notification.permission !== 'default') return Promise.resolve(Notification.permission);
    return new Promise(function (resolve) {
      sheet('<div class="hd"><img src="icons/seal-192.png" alt="" onerror="this.onerror=null;this.src=\'icons/Icon-192.png\'"><h3>Allow notifications?</h3></div>' +
        '<p>Get boarding, drop, delay and SOS alerts from DriverGuardian even when the app is closed.</p>', [
        { label: 'Not now', onClick: function () { resolve('default'); } },
        { label: 'Allow', primary: true, onClick: function () {
          try {
            var r = Notification.requestPermission(function (p) { resolve(p); });
            if (r && r.then) r.then(resolve, function () { resolve(Notification.permission); });
          } catch (e) { resolve(Notification.permission); }
        } }
      ]);
    });
  }

  /** Returns a Firebase Cloud Messaging token (or null when not allowed). */
  function enablePush(configJson) {
    var cfg = JSON.parse(configJson || '{}');
    if (!pushSupported()) return Promise.resolve(null);
    return askPermission().then(function (p) {
      if (p !== 'granted') return null;
      return registerWorker().then(function (r) {
        if (!r) throw new Error('service worker unavailable');
        return loadScript(FIREBASE + 'firebase-app-compat.js')
          .then(function () { return loadScript(FIREBASE + 'firebase-messaging-compat.js'); })
          .then(function () {
            var fb = window.firebase;
            if (!fb.apps.length) {
              fb.initializeApp({ apiKey: cfg.apiKey, projectId: cfg.projectId, messagingSenderId: cfg.messagingSenderId, appId: cfg.appId, authDomain: cfg.projectId + '.firebaseapp.com' });
            }
            return fb.messaging().getToken({ vapidKey: cfg.vapidKey, serviceWorkerRegistration: r });
          });
      });
    });
  }

  /* ---------- "Install Driver Guardian" pop-up (Android: Chrome install prompt · iPhone: Add to Home Screen steps) */
  function snoozed() { try { return Date.now() < parseInt(localStorage.getItem('dg_install_snooze') || '0', 10); } catch (e) { return false; } }
  function installPopup(force) {
    if (standalone() || document.getElementById('dgInstall') || (!force && snoozed()) || !document.body) return;
    var st = document.createElement('style');
    st.textContent = '#dgInstall{position:fixed;left:50%;bottom:calc(18px + env(safe-area-inset-bottom));transform:translate(-50%,140%);z-index:2147483500;display:flex;align-items:center;gap:10px;' +
      'background:#fff;border-radius:20px;padding:10px 10px 10px 12px;box-shadow:0 18px 40px rgba(11,16,51,.35);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;transition:transform .35s cubic-bezier(.2,.8,.2,1);max-width:calc(100vw - 24px)}' +
      '#dgInstall.in{transform:translate(-50%,0)}#dgInstall img{width:42px;height:42px;border-radius:12px}' +
      '#dgInstall .go:disabled{opacity:.75}#dgInstall .go{border:0;border-radius:14px;padding:12px 18px;font-size:15px;font-weight:700;color:#fff;background:linear-gradient(120deg,#4f46e5,#7c3aed);white-space:nowrap;cursor:pointer;animation:dgPulse2 1.8s ease-in-out infinite}' +
      '#dgInstall .x{border:0;background:#f1f3f9;color:#6b7280;width:32px;height:32px;border-radius:10px;font-size:18px;line-height:1;cursor:pointer}' +
      '@keyframes dgPulse2{0%,100%{box-shadow:0 0 0 0 rgba(124,58,237,.5)}50%{box-shadow:0 0 0 8px rgba(124,58,237,0)}}';
    document.head.appendChild(st);
    var p = document.createElement('div');
    p.id = 'dgInstall';
    p.setAttribute('role', 'dialog');
    p.innerHTML = '<img src="icons/seal-192.png" alt="" onerror="this.onerror=null;this.src=\'icons/Icon-192.png\'"><button type="button" class="go">Install Driver Guardian</button><button type="button" class="x" aria-label="Close">×</button>';
    document.body.appendChild(p);
    requestAnimationFrame(function () { requestAnimationFrame(function () { p.classList.add('in'); }); });
    var go = p.querySelector('.go');
    go.addEventListener('click', function () {
      // Chrome may need a moment after the page opens to offer the install — wait up to 2.5 s
      var t0 = Date.now();
      go.disabled = true;
      (function tryInstall() {
        if (installEvent) {
          go.disabled = false;
          var ev = installEvent; installEvent = null;
          ev.prompt();
          if (ev.userChoice) ev.userChoice.then(function (c) { if (c && c.outcome === 'accepted') p.remove(); });
          return;
        }
        if (!ios && !inAppBrowser() && Date.now() - t0 < 2500) { setTimeout(tryInstall, 250); return; }
        go.disabled = false;
        installed().then(function (yes) { yes ? showInstalled() : showInstallHelp(); });
      })();
    });
    p.querySelector('.x').addEventListener('click', function () {
      try { localStorage.setItem('dg_install_snooze', String(Date.now() + 3 * 86400000)); } catch (e) {}
      p.classList.remove('in'); setTimeout(function () { p.remove(); }, 400);
    });
  }
  function startPopup() {
    if (standalone()) return;
    var forced = /[?&]install=1\b/.test(location.search);
    installed().then(function (yes) {
      if (yes) { if (forced) showInstalled(); return; }   // already on the phone — nothing to install
      // opened from "Install Driver Guardian" on the website: show it at once; otherwise give Chrome up to 3 s to offer the install
      var wait = forced ? 0 : (ios ? 1200 : 3000), t0 = Date.now();
      (function check() {
        if (installEvent || Date.now() - t0 >= wait) installPopup(forced);
        else setTimeout(check, 300);
      })();
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', startPopup); else startPopup();

  window.dgPwa = {
    pushSupported: pushSupported,
    permission: permission,
    enablePush: enablePush,
    onPush: function (cb) { listeners.push(cb); },
    isStandalone: standalone,
    isIos: function () { return ios; },
    isAndroid: function () { return android; },
    canInstall: function () { return !!installEvent; },
    showInstallHelp: showInstallHelp
  };
})();
