// DriverGuardian mobile — push notifications via Firebase Cloud Messaging.
// Android/iOS: the Firebase plugin (needs google-services.json in the build;
// without it init fails quietly and the app relies on in-app notifications).
// Web app (PWA, iPhone): web/dg-pwa.js + dg-sw.js using the Firebase web
// config the platform owner saves in System → Mobile push.
// Developed & Powered by Marian Anbu Juwan
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'web/bridge.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // System tray shows notification messages automatically; nothing else to do.
}

class Push {
  Push._();
  static bool available = false;
  static String? token;
  static void Function(String title, String body)? onForeground;

  /// Web: server has a Firebase web config (null until checked).
  static Map<String, dynamic>? webConfig;

  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  static Future<void> init() async {
    if (kIsWeb) {
      available = webPushSupported();
      webOnPush((t, b) => onForeground?.call(t, b));
      return;
    }
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      available = true;
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground?.call(n.title ?? 'DriverGuardian', n.body ?? '');
      });
    } catch (e) {
      available = false;
      debugPrint('Push disabled (no Firebase config): $e');
    }
  }

  /// Web: what the "Notifications" row should say.
  static String webStatus() {
    if (!webPushSupported()) {
      return webIsIos() && !webIsStandalone()
          ? 'Add DriverGuardian to your Home Screen first (Share → Add to Home Screen), then open it from there.'
          : 'This browser cannot receive notifications — alerts appear inside the app.';
    }
    final p = webPushPermission();
    if (p == 'granted' && token != null) return 'On for this device.';
    if (p == 'denied') return 'Blocked. Allow notifications for this site in the browser / iPhone Settings → Notifications.';
    return 'Off — tap “Turn on notifications”.';
  }

  static Future<Map<String, dynamic>?> _loadWebConfig() async {
    if (webConfig != null) return webConfig;
    try {
      final c = await Api.I.get('/push/web-config');
      if (c['enabled'] == true) webConfig = c;
    } catch (_) {}
    return webConfig;
  }

  /// Web: ask permission (shows an in-page "Allow" button, a real tap for Safari),
  /// get a token and register it. Returns a message for the user.
  static Future<String> enableWeb() async {
    if (!webPushSupported()) return webStatus();
    final cfg = await _loadWebConfig();
    if (cfg == null) return 'Notifications are not set up on this server yet — alerts appear inside the app.';
    try {
      final t = await webPushEnable(jsonEncode(cfg));
      if (t == null || t.isEmpty) return webPushPermission() == 'denied' ? webStatus() : 'Notifications were not turned on.';
      token = t;
      await Api.I.post('/devices', {'token': t, 'platform': 'web'});
      return 'Notifications are on for this device.';
    } catch (e) {
      return 'Could not turn on notifications: $e';
    }
  }

  /// Ask permission (Android 13+/iOS) and register this device with the server.
  /// Web: only re-registers silently when permission was already granted.
  static Future<void> register() async {
    if (!available || Api.I.token == null) return;
    if (kIsWeb) {
      if (webPushPermission() == 'granted') await enableWeb();
      return;
    }
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      token = await fm.getToken();
      if (token != null) {
        await Api.I.post('/devices', {'token': token, 'platform': _platform});
      }
      fm.onTokenRefresh.listen((t) {
        token = t;
        Api.I.post('/devices', {'token': t, 'platform': _platform}).catchError((_) => <String, dynamic>{});
      });
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }
}
