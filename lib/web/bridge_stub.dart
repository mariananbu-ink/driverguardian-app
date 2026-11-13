// Non-web builds: browser features are not available.
// Developed & Powered by Marian Anbu Juwan

/// True when the browser can receive push notifications (service worker + Push API + Notification).
bool webPushSupported() => false;

/// 'granted', 'denied', 'default' or 'unsupported'.
String webPushPermission() => 'unsupported';

/// Asks for permission (with an in-page button, a real tap for Safari) and returns an FCM token.
Future<String?> webPushEnable(String configJson) async => null;

/// Foreground notifications forwarded by the service worker.
void webOnPush(void Function(String title, String body) cb) {}

/// Running from the home screen (installed) rather than a browser tab.
bool webIsStandalone() => false;

/// iPhone / iPad Safari.
bool webIsIos() => false;

/// Android browser (Chrome).
bool webIsAndroid() => false;

/// Shows the "Add to Home Screen" help sheet.
void webShowInstallHelp() {}
