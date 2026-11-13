// DriverGuardian web app — starts the Flutter engine and hides the loading screen
// on the first frame. The two placeholder lines below are filled in by `flutter build web`.
// Developed & Powered by Marian Anbu Juwan
{{flutter_js}}
{{flutter_build_config}}

(function () {
  var started = false;
  function msg(html) { var m = document.getElementById('dg-splash-msg'); if (m) m.innerHTML = html; }

  window.addEventListener('flutter-first-frame', function () {
    started = true;
    var s = document.getElementById('dg-splash');
    if (s) { s.classList.add('gone'); setTimeout(function () { s.remove(); }, 450); }
  });

  setTimeout(function () {
    if (!started) msg('Still loading — slow connection? <a href="javascript:location.reload()">Tap to reload</a>');
  }, 25000);

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      var appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    }
  }).catch(function (e) {
    console.error(e);
    msg('Could not start the app. Check your internet connection and <a href="javascript:location.reload()">reload</a>.<br>' +
        'iPhone needs iOS 15 or newer.');
  });
})();
