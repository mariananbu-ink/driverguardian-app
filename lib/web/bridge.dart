// DriverGuardian — browser (PWA) helpers. On Android/iOS builds the stub is
// used; the web build talks to web/dg-pwa.js through dart:js_interop.
// Developed & Powered by Marian Anbu Juwan
export 'bridge_stub.dart' if (dart.library.js_interop) 'bridge_web.dart';
