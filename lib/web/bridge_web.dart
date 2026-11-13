// Web build: calls window.dgPwa from web/dg-pwa.js.
// Developed & Powered by Marian Anbu Juwan
import 'dart:js_interop';

@JS('dgPwa')
external _DgPwa? get _dg;

extension type _DgPwa._(JSObject _) implements JSObject {
  external JSBoolean pushSupported();
  external JSString permission();
  external JSPromise<JSString?> enablePush(JSString config);
  external void onPush(JSFunction cb);
  external JSBoolean isStandalone();
  external JSBoolean isIos();
  external JSBoolean isAndroid();
  external void showInstallHelp();
}

bool webPushSupported() => _dg?.pushSupported().toDart ?? false;

String webPushPermission() => _dg?.permission().toDart ?? 'unsupported';

Future<String?> webPushEnable(String configJson) async {
  final d = _dg;
  if (d == null) return null;
  final t = await d.enablePush(configJson.toJS).toDart;
  return t?.toDart;
}

void webOnPush(void Function(String title, String body) cb) {
  _dg?.onPush(((JSString t, JSString b) => cb(t.toDart, b.toDart)).toJS);
}

bool webIsStandalone() => _dg?.isStandalone().toDart ?? false;

bool webIsIos() => _dg?.isIos().toDart ?? false;

bool webIsAndroid() => _dg?.isAndroid().toDart ?? false;

void webShowInstallHelp() => _dg?.showInstallHelp();
